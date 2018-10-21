pragma solidity ^0.4.21;

import "./Owned.sol";
import "./BidFactory.sol";
import "./AVACoin.sol";
import "./SafeMath.sol";

//----------------------------------------------------------------
contract AuthorizedContract is Owned {
  	mapping (address => bool) authorized;
  	mapping (address => uint256) allowedAva;
  	mapping (address => uint256) allowedEther;

  	modifier onlyAuthorized() {
  		  require(authorized[msg.sender]);
        _;
  	}

  	function addAddress(address _new) external onlyOwner {
  		  authorized[_new] = true;
  	}

  	function removeAddress(address _old) external onlyOwner {
  		  authorized[_old] = false;
  	}
}

contract PhasedContract is AuthorizedContract {

	enum Phase {
		NO_PHASE,
		FIRST,
		SECOND,
		THIRD,
		FOURTH
	}
	Phase public phase;

	uint public phaseTill;

	event PhaseStart(Phase phase);

	modifier isPhase(Phase ph) {
		require(phase == ph);
		_;
	}

	constructor() public {
    	phase = Phase.NO_PHASE;
		startedNewPhase();
	}

	function startedNewPhase() private {
		emit PhaseStart(phase);
	}

	function nextPhase() internal {
		if (phase == Phase.FIRST) {
			phase = Phase.SECOND;
		} else if (phase == Phase.SECOND) {
			phase = Phase.THIRD;
		} else if (phase == Phase.THIRD) {
			phase = Phase.FOURTH;
		} else if (phase == Phase.NO_PHASE || phase == Phase.FOURTH) {
			phase = Phase.FIRST;
		}
		startedNewPhase();
	}

	function switchOff() public onlyOwner isPhase(Phase.FOURTH) {
		phase = Phase.NO_PHASE;
		startedNewPhase();
	}

	function getCurrentTime() internal view returns (uint) {
		return now;
	}

	function startNextPhase(uint time, uint32 roundMultiplier) external onlyOwner {
		phaseTill = getCurrentTime() + time;
		nextPhase();
		if (phase == Phase.FIRST) {
		    startNextRound(roundMultiplier);
		}
	}

	function isPhaseTill() public view returns (bool) {
		return ((phase == Phase.NO_PHASE) || (phase == Phase.THIRD) || (phase == Phase.FOURTH) || (phaseTill > getCurrentTime()));
	}

	function startNextRound(uint32 roundMultiplier) internal;
}

contract RoundContract is PhasedContract{

	event RoundStart(uint256 number);

	uint256 public roundNumber = 0;

	struct Bid {
		bytes32 hash;
		bool isBuy;
		uint256 etherAmount;
		uint256 avaAmount;
		uint256 etherPrice;
		address eFWallet;
		bool approved;
	}

	struct Round {
	    uint256 multiplierInPercentForETH;
		mapping (address => Bid) bids;
		mapping (uint8 => address) bidNumbers;
		mapping (uint8 => address) sells;
		mapping (uint8 => address) buys;
		mapping (address => uint8) investorStatus;
		uint8 bidNumber;
		uint8 sellNumber;
		uint8 buyNumber;
	}


	mapping (uint256 => Round)  rounds;

	function startNewRound() internal {
		emit RoundStart(roundNumber);
	}

	function startNextRound(uint32 roundMultiplier) internal {
		roundNumber += 1;
		rounds[roundNumber].multiplierInPercentForETH = roundMultiplier;
		startNewRound();
	}

	function hashCode(bool isBuy, uint256 etherAmount, uint256 avaAmount, address eFWallet, uint256 etherPrice) public pure returns (bytes32) {
		return keccak256(isBuy, etherAmount, avaAmount, eFWallet, etherPrice);
	}

	function getBidInfo(uint256 _roundNumber, address investor) external view returns (
    	    bytes32 hash,
    	    bool isBuy,
    		uint256 etherAmount,
    		uint256 avaAmount,
    		uint256 etherPrice,
    		address eFWallet,
    		bool approved)
    {

		Bid memory bid =  rounds[_roundNumber].bids[investor];
	    return (bid.hash, bid.isBuy, bid.etherAmount, bid.avaAmount, bid.etherPrice, bid.eFWallet, bid.approved);
	}

}

contract Auction is RoundContract {
	using SafeMath for uint;

	ERC20 public token;

	uint256 public lowETHLimit;
	
	BidFactory public bidder;

	enum OrderValidationStatus {
		VALID, // 0
		NOT_ENOUGH_ETH, // 1
		NOT_ENOUGH_AVA, // 2
		INCORRECT_HASH  // 3
	}

	modifier canWithdraw() {
		require(phase == Phase.NO_PHASE || phase == Phase.FIRST);
		_;
	}

	constructor() public {
		lowETHLimit = 1e16; // 0.01 ETH.
	}

	function setLowETHLimit(uint256 newLowETHLimit) external onlyOwner {
		lowETHLimit = newLowETHLimit;
	}

	function setToken(address newToken) external onlyOwner {
		token = ERC20 (newToken);
	}
	
	function setBidder(address newBidder) external onlyOwner {
		bidder = BidFactory (newBidder);
	}

	function() external payable onlyAuthorized {
		address investor = msg.sender;
		uint256 amountAva = token.allowance(investor, this);
		require(token.transferFrom(investor, this, amountAva));
		allowedAva[investor] += amountAva;
		allowedEther[investor] += msg.value;
	}

	function withdrawAVAandEther(uint256 etherAmount, uint256 avaAmount) external onlyAuthorized canWithdraw {
		address investor = msg.sender;
		require(allowedAva[investor] >= avaAmount);
		require(allowedEther[investor] >= etherAmount);
		allowedAva[investor] -= avaAmount;
		allowedEther[investor] -= etherAmount;
		require(token.transfer(investor, avaAmount));
		require(investor.call.gas(3000000).value(etherAmount)());
	}

	function withdrawAVAandEtherAll() external onlyAuthorized  {
		address investor = msg.sender;
		uint256 etherAmount = allowedEther[investor];
		uint256 avaAmount = allowedAva[investor];
		allowedAva[investor] = 0;
		allowedEther[investor] = 0;
		require(token.transfer(investor, avaAmount));
		require(investor.call.gas(3000000).value(etherAmount)());
	}

	function makeBid(bytes32 hashValue) external onlyAuthorized isPhase(Phase.FIRST) returns (bool) {
		require(phaseTill > getCurrentTime());
		address investor = msg.sender;
		rounds[roundNumber].bids[investor].hash = hashValue;
		rounds[roundNumber].investorStatus[investor] = 1;
		return true;
	}

	function validateOrder(address investor, bool isBuy, uint256 etherAmount, uint256 avaAmount, address eFWallet, uint256 etherPrice) internal view returns (OrderValidationStatus) {
		// Check hash bid with bid info.
		Bid memory bid = rounds[roundNumber].bids[investor];
		if (bid.hash != hashCode(isBuy, etherAmount, avaAmount, eFWallet, etherPrice)) {
		    return OrderValidationStatus.INCORRECT_HASH; // hascode is not valid.
		}
		// Have investor money for this.
		uint256 mustHaveEther = etherAmount.mul(rounds[roundNumber].multiplierInPercentForETH).div(100);
		if (mustHaveEther > allowedEther[investor]) {
		    return OrderValidationStatus.NOT_ENOUGH_ETH; // not enough ETH
		}
		if (avaAmount > allowedAva[investor]) {
			return OrderValidationStatus.NOT_ENOUGH_AVA; // not enough AVA
		}
		return OrderValidationStatus.VALID;
	}
	
	function provideBidInfo(bool isBuy, uint256 etherAmount, uint256 avaAmount, address eFWallet, uint256 etherPrice) external onlyAuthorized isPhase(Phase.SECOND) returns (OrderValidationStatus) {
		require(phaseTill > getCurrentTime() );
		require(etherAmount >= lowETHLimit);
		address investor = msg.sender;
		OrderValidationStatus result = validateOrder(investor, isBuy, etherAmount, avaAmount, eFWallet, etherPrice);
		if (result == OrderValidationStatus.INCORRECT_HASH) {
			return result;
		}
		Bid storage bidS = rounds[roundNumber].bids[investor];
		bidS.isBuy = isBuy;
		bidS.etherAmount = etherAmount;
		bidS.avaAmount = avaAmount;
		bidS.eFWallet = eFWallet;
		bidS.etherPrice = etherPrice;
		bidS.approved = OrderValidationStatus.VALID == result;
		if (rounds[roundNumber].investorStatus[investor] != 2) {
    		rounds[roundNumber].bidNumber += 1;
    		rounds[roundNumber].bidNumbers[rounds[roundNumber].bidNumber] = investor;
    		rounds[roundNumber].investorStatus[investor] = 2;
		}
		return result;
	}
	
	function sortResults() external isPhase(Phase.THIRD) {
// 		require(phaseTill > getCurrentTime() );
		uint8 buysNumber = 0;
		uint8 sellsNumber = 0;
		Round storage round = rounds[roundNumber];
		uint8 bidNumber = round.bidNumber;
		while (buysNumber + sellsNumber < bidNumber) {
		    address currentSell = 0;
		    address currentBuy = 0;
		    uint256 currentSellAmount = 0;
		    uint256 currentBuyAmount = 0;
		    for (uint8 i = 1; i <= bidNumber; ++i) {
		        address investor = round.bidNumbers[i];
		        if (round.investorStatus[investor] != 3) {
    		        Bid storage bid = round.bids[investor];
    		        if (bid.isBuy) {
    		            if (bid.avaAmount > currentBuyAmount) {
    		                currentBuy = investor;
    		                currentBuyAmount = round.bids[currentBuy].avaAmount;
    		            }   
    		        } else {
    		            if (bid.avaAmount > currentSellAmount) {
    		                currentSell = investor;
    		                currentSellAmount = round.bids[currentSell].avaAmount;
    		            } 
    		        }
		        }
		    }
		    if (currentBuy != 0){
		        round.buys[i] = currentBuy;
		    } 
		    if (currentSell != 0){
		        round.sells[i] = currentSell;
		    } 
		}
		nextPhase();
	}
	
	function createBids() external isPhase(Phase.FOURTH) {
	    uint8 buysNumber = 0;
		uint8 sellsNumber = 0;
		Round storage round = rounds[roundNumber];
		uint256 sellLeft = 0;
	    uint256 buyLeft = 0;
	    while (sellsNumber < round.sellNumber && buysNumber < round.buyNumber) {
		    if (sellLeft == 0) {
		        address tempSell = round.sells[sellsNumber];
		        sellLeft = round.bids[tempSell].etherAmount;
		    }
		    if (buyLeft == 0) {
		        address tempBuy = round.buys[sellsNumber];
		        buyLeft = round.bids[tempBuy].etherAmount;
		    }
		    if (sellLeft == buyLeft) {
		        //function createBid(uint32 price, uint8 direction, address new_counterparty, address bidder, uint end, uint8 margin) public payable onlyOwner;
		        //bidder.createBid()
		        sellLeft == 0;
		        buyLeft == 0;
		        sellsNumber++;
		        buysNumber++;
		    } else if (sellLeft > buyLeft) {
		        //bidder.createBid()
		        sellLeft -= buyLeft;
		        buyLeft = 0;
		        buysNumber++;
		    } else {
		        //bidder.createBid()
		        buyLeft -= sellLeft;
		        sellLeft = 0;
		        sellsNumber++;
		    }
		     
		}
		nextPhase();
	}
}

contract AuctionTest is Auction {

    uint public currentTime = now;

    function getCurrentTime() internal view returns (uint) {
		return currentTime;
    }

    function setCurrentTime(uint newCurrentTime) external {
		currentTime = newCurrentTime;
    }
}
