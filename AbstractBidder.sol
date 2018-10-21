pragma solidity ^0.4.21;

import "./BidFactory.sol";

contract AbstractBidder is BidFactory {
	
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
    
    address priceSetter;
    address bidCreator;
    
    modifier onlyPriceSetter {
        require(priceSetter == msg.sender);
        _;
    }
    
    modifier onlyBidCreator {
        require(bidCreator == msg.sender);
        _;
    }

    constructor() public payable {
    }
    
    function setPriceSetter(address new_PriceSetter) public onlyOwner {
        priceSetter = new_PriceSetter;
    }
    
    function setBidCreator(address new_BidCreator) public onlyOwner {
        bidCreator = new_BidCreator;
    }

    function createBid(uint32 price, uint8 direction, address new_counterparty, address bidder, uint end, uint8 margin) public payable onlyBidCreator {
        
        Bid memory bid;

        if (price <= 0) {
            //TODO: add error event
            revert();
        }

        bid.highBidderBalance = msg.value / 2;
        bid.lowBidderBalance = msg.value / 2;
        bid.bidBalance = msg.value;
        if (direction == uint8(bidDirections.High)) {
            bid.highBidderAddress = bidder;
            bid.lowBidderAddress = new_counterparty;
        } else if (direction == uint8(bidDirections.Low)) {
            bid.highBidderAddress = new_counterparty;
            bid.lowBidderAddress =  bidder;
        } else {
            revert();
        }

        bid.bidIndex = bids.length;
        bid.price = price;
        bid.direction = direction;
        bid.timestampEnd = end;
        bid.isOver = false;
        bid.margin = margin;

        bids.push(bid);
        emit CreateBidEvent(bid.bidIndex, bidder);
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

    function settleBid(uint256 bidIndex, uint32 newPrice) public onlyPriceSetter {
        settleBidInternal(bidIndex, newPrice);
    }
    
    function settleBidInternal(uint256 bidIndex, uint32 newPrice) internal {
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
    
    function getCurrentTime() internal view returns (uint) {
		return now;
	}
	
}