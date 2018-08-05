pragma solidity ^0.4.21;

import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";
import "./BidFactory.sol";
import "./Owned.sol";

contract AVABidder is usingOraclize, BidFactory {
	
    enum bidDirections {High, Low, None}
    enum currencies {USD, EUR, BTC}

    struct Bid {
        uint256 bidIndex;
        address highBidderAddress;
        uint highBidderBalance;
        address lowBidderAddress;
        uint lowBidderBalance;
        uint32 price;
        uint8 direction;
        bool hasQueryId;                    // to keep track of oraclize requests
        uint bidBalance;
        uint timestampEnd;
        bool isOver;
        uint8 margin;
    }

    Bid[] bids;

    struct Counterparty {
        address addr;
        uint balance;
    }

    Counterparty counterparty;

    // oraclize update price id's
    mapping(bytes32=>bool) updatePriceIds;

    // oraclize settle bid id's
    mapping(bytes32=>Bid) settleBidIds;

    event CreateBidEvent(uint256 bidIndex, address account);
    event SetupCounterpartyEvent(address account, uint balance);
    event SettleBidEvent(uint256 bidIndex, bool priceChanged, uint weiBalanceDiff, uint settledAt, uint8 bidWinner);
    event NewOraclizeEvent(string description, bytes32 myid);
    event UpdatePriceEvent(uint32 price);
    event CallbackErrorEvent(string description, bytes32 myid);
    event SettleBidErrorEvent(string description, uint256 bidIndex);

    constructor() public payable {

        // ALERT: this is only for testing on testrpc; remove for production
        // OAR = OraclizeAddrResolverI(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475);
        // oraclize_setCustomGasPrice(4000000000 wei);
    }


    function createBid(uint32 price, uint8 direction, address bidder, uint end, uint8 margin) public payable onlyOwner {
        
        Bid memory bid;

        if (counterparty.balance <= 0) {
            //TODO: add error event
            revert();
        }

        if (price <= 0) {
            //TODO: add error event
            revert();
        }

        if (direction == uint8(bidDirections.High)) {
            bid.highBidderAddress = bidder;
            bid.highBidderBalance = msg.value;
            bid.bidBalance = 2 * msg.value;

            // counterparty becomes the low bidder
            if (counterparty.balance < bid.highBidderBalance) {
                revert();
            } else {
                counterparty.balance = counterparty.balance - bid.highBidderBalance;
                bid.lowBidderAddress = counterparty.addr;
                bid.lowBidderBalance = bid.highBidderBalance;
            }
        } else if (direction == uint8(bidDirections.Low)) {
            bid.lowBidderAddress = bidder;
            bid.lowBidderBalance = msg.value;

            // counterparty becomes the high bidder
            if (counterparty.balance < bid.lowBidderBalance) {
                revert();
            } else {
                counterparty.balance = counterparty.balance - bid.lowBidderBalance;
                bid.highBidderAddress = counterparty.addr;
                bid.highBidderBalance = bid.lowBidderBalance;
            }
        } else {
            revert();
        }

        bid.bidIndex = bids.length;
        bid.price = price;
        bid.direction = direction;
        bid.timestampEnd = end;
        bid.isOver = false;
        bid.margin = margin;

        bids.push (bid);
        emit CreateBidEvent(bid.bidIndex, bidder);

        // initiate automatic bid settlement thru oraclize
        settleBidOraclize (bid.bidIndex);
    }

    function getBid(uint256 bidIndex) public constant returns (address addr, 
                                                            uint balance,
                                                            uint32 price,
                                                            uint8 direction,
                                                            address counterpartyAddress,
                                                            uint counterpartyBalance) 
                                                            {

        // check if bid exists at this bidIndex
        if (bids[bidIndex].price == 0) {
            //TODO: add error event
            revert();
        }

        if (bids[bidIndex].direction == uint8(bidDirections.High)) {
            addr = bids[bidIndex].highBidderAddress;
            balance = bids[bidIndex].highBidderBalance;
            counterpartyAddress = bids[bidIndex].lowBidderAddress;
            counterpartyBalance = bids[bidIndex].lowBidderBalance;
        } else {
            addr = bids[bidIndex].lowBidderAddress;
            balance = bids[bidIndex].lowBidderBalance;
            counterpartyAddress = bids[bidIndex].highBidderAddress;
            counterpartyBalance = bids[bidIndex].highBidderBalance;
        }
        
        price = bids[bidIndex].price;
        direction = bids[bidIndex].direction;
    }

    function setupCounterparty(address new_counterparty) payable public onlyOwner {
        counterparty = Counterparty(new_counterparty, msg.value);
        emit SetupCounterpartyEvent(counterparty.addr, counterparty.balance);
    }

    function settleBid(uint256 bidIndex, uint32 newPrice) public {
        uint priceDiff;
        uint weiBalanceDiff;
        uint8 bidWinner;

        // check if bid exists at this bidIndex
        if (bids[bidIndex].price == 0) {
            //TODO: add error event
            revert();
        }

        // check if new price is valid
        if (newPrice <= 0) {
            //TODO: add error event
            revert();
        }

        if (bids[bidIndex].price < newPrice) {
            // high bidder wins
            priceDiff = uint(newPrice - bids[bidIndex].price);
            weiBalanceDiff = priceDiff * bids[bidIndex].margin * 1 ether / newPrice / 100;

            // check if low bidder has enough balance to cover
            if (bids[bidIndex].lowBidderBalance < weiBalanceDiff) {
                // emit SettleBidErrorEvent ("Low bidder balance not enough to cover the difference", bidIndex);
                weiBalanceDiff = bids[bidIndex].lowBidderBalance;
                bids[bidIndex].isOver = true;
            }
            
            bids[bidIndex].highBidderBalance = bids[bidIndex].highBidderBalance + weiBalanceDiff;
            bids[bidIndex].lowBidderBalance = bids[bidIndex].lowBidderBalance - weiBalanceDiff;

            bidWinner = uint8(bidDirections.High);      
        } else if (bids[bidIndex].price > newPrice) {
            // low bidder wins
            priceDiff = uint(bids[bidIndex].price - newPrice);
            weiBalanceDiff = priceDiff * bids[bidIndex].margin * 1 ether / newPrice / 100;

            // check if high bidder has enough balance to cover
            if (bids[bidIndex].highBidderBalance < weiBalanceDiff) {
                weiBalanceDiff = bids[bidIndex].highBidderBalance;
                // emit SettleBidErrorEvent ("High bidder balance not enough to cover the difference", bidIndex);
                bids[bidIndex].isOver = true;
            }

            bids[bidIndex].lowBidderBalance = bids[bidIndex].lowBidderBalance + weiBalanceDiff;
            bids[bidIndex].highBidderBalance = bids[bidIndex].highBidderBalance - weiBalanceDiff;

            bidWinner = uint8(bidDirections.Low);      
        } else {
            bidWinner = uint8(bidDirections.None);
            emit SettleBidEvent(bidIndex, false, 0, now, bidWinner);
            return; 
        }

        // save new price
        bids[bidIndex].price = newPrice;

        emit SettleBidEvent(bidIndex, true, weiBalanceDiff, now, bidWinner);
    }

    
    function devideMoney(uint256 bidIndex) public {
        require(bids[bidIndex].isOver || bids[bidIndex].timestampEnd > getCurrentTime());
        if (bids[bidIndex].lowBidderBalance == 0) {
            bids[bidIndex].highBidderAddress.call.value(bids[bidIndex].bidBalance).gas(20317);
            return;
        } if (bids[bidIndex].highBidderBalance != 0) {
            bids[bidIndex].lowBidderAddress.call.value(bids[bidIndex].bidBalance).gas(20317);
            return;
        } 
        // TODO: Add math library;
        uint256 highValue = bids[bidIndex].bidBalance * bids[bidIndex].highBidderBalance / (bids[bidIndex].highBidderBalance + bids[bidIndex].lowBidderBalance);
        bids[bidIndex].highBidderAddress.call.value(highValue).gas(20317);
        bids[bidIndex].lowBidderAddress.call.value(bids[bidIndex].bidBalance - highValue).gas(20317);
    }
    
    // oraclize
    function __callback(bytes32 myid, string result) public {
        uint price;
        uint256 foundBidIndex;
        
        // if (msg.sender != oraclize_cbAddress()) {
        //   emit CallbackErrorEvent ("Oraclize address doesnot match", myid);
        //   revert();
        // }

        if (updatePriceIds[myid] == true) {
            // callback is called as a result to update price thru oraclize
            price = parseInt(result, 2);
            emit UpdatePriceEvent (uint32(price));
            delete updatePriceIds[myid];
        } else if (settleBidIds[myid].hasQueryId == true) {
            // callback is called as a result of settle bid thru orcalize
            foundBidIndex = settleBidIds[myid].bidIndex;
            price = parseInt(result, 2);

            settleBid (foundBidIndex, uint32 (price));

            bids[foundBidIndex].hasQueryId = false;
            uint oraclizePrice = oraclize_getPrice("URL");
            if (bids[foundBidIndex].isOver == false && bids[foundBidIndex].bidBalance > oraclize_getPrice("URL")) {
                // call settle bid thru oraclize again for recursion
                settleBidOraclize (bids[foundBidIndex].bidIndex);
                bids[foundBidIndex].bidBalance = bids[foundBidIndex].bidBalance - oraclizePrice;
            }

            delete settleBidIds[myid];

        } else {
            emit CallbackErrorEvent ("Could not find oraclize id", myid);
            revert();
        }
    }

    function updatePrice() payable public {
        if (oraclize_getPrice("URL") > address(this).balance) {
            emit NewOraclizeEvent("Oraclize query was NOT sent, please add some ETH to cover for the query fee", "");
        } else {
            bytes32 queryId = oraclize_query("URL", "json(https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD).USD");
            updatePriceIds[queryId] = true;
            emit NewOraclizeEvent("Oraclize query was sent, standing by for the answer..", queryId);
        }
    }

    function settleBidOraclize(uint256 bidIndex) payable public {
        if (oraclize_getPrice("URL") > address(this).balance) {
            emit NewOraclizeEvent("Oraclize query was NOT sent, please add some ETH to cover for the query fee", "");
        } else {
            bytes32 queryId = oraclize_query(30, "URL", "json(https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD).USD", 500000);
            bids[bidIndex].hasQueryId = true;
            settleBidIds[queryId] = bids[bidIndex];
            emit NewOraclizeEvent("Oraclize query was sent, standing by for the answer..", queryId);
        }
    }
    
    function getCurrentTime() internal view returns (uint) {
		return now;
	}
}

contract AVABidderTest is AVABidder {
    uint public currentTime = now;

    function getCurrentTime() internal view returns (uint) {
		return currentTime;
    }

    function setCurrentTime(uint newCurrentTime) external {
		currentTime = newCurrentTime;
    }
}