pragma solidity ^0.4.24;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}

/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
    function totalSupply() public view returns (uint256);
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}


/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Owned {

    address public owner;

    address public newOwner;

    constructor() public payable {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(owner == msg.sender);
        _;
    }

    function changeOwner(address _owner) onlyOwner public {
        require(_owner != 0);
        newOwner = _owner;
    }

    function confirmOwner() public {
        require(newOwner == msg.sender);
        owner = newOwner;
        delete newOwner;
    }
}

contract BidFactory is Owned {

	function createBid(uint8 direction, address new_counterparty, address bidder, uint end, uint8 margin) public payable returns (uint256);

}

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

    function isAuthorized(address adrs) public view returns (bool) {
        return authorized[adrs];
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

    uint public defaultPhaseTime = 1800;

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
		} else if (phase == Phase.FOURTH) {
			phase = Phase.NO_PHASE;
		} else if (phase == Phase.NO_PHASE) {
      phase = Phase.FIRST;
    }
    phaseTill = getCurrentTime() + defaultPhaseTime;
		startedNewPhase();
	}

	function switchOff() public onlyOwner isPhase(Phase.FOURTH) {
		phase = Phase.NO_PHASE;
		startedNewPhase();
	}

	function getCurrentTime() internal view returns (uint) {
		return now;
	}

    function startNextPhase(uint time) external onlyOwner {
        if (phase == Phase.NO_PHASE) {
          require(false);
        }
        nextPhase();
        phaseTill = getCurrentTime() + time;
    }

	function startFirstPhase(uint time, uint8 roundMultiplier) public onlyOwner {
		nextPhase();
        phaseTill = getCurrentTime() + time;
		if (phase == Phase.FIRST) {
		    startNextRound(roundMultiplier);
		}
	}

	function isPhaseTill() public view returns (bool) {
		return ((phase == Phase.NO_PHASE) || (phase == Phase.THIRD) || (phase == Phase.FOURTH) || (phaseTill > getCurrentTime()));
	}

    function phaseTimeLeft() public view returns (uint) {
        uint time = getCurrentTime();
        if (time > phaseTill) {
          return 0;
        }
        return phaseTill - time;
    }

	function startNextRound(uint8 roundMultiplier) internal;
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
	    uint8 multiplierInPercentForETH;
		mapping (address => Bid) bids;
		address[] bidConfirmAddresses;
		address[] sellers;
		address[] buyers;
		mapping (address => uint8) investorStatus;
	}

	mapping (uint256 => Round) public rounds;

    function getSellersAddresses(uint256 rNum) public view returns (address[]) {
        return rounds[rNum].sellers;
    }

    function getBuyersAddresses(uint256 rNum) public view returns (address[]) {
        return rounds[rNum].buyers;
    }

    function getBidConfirmAddresses(uint256 rNum) public view returns (address[]) {
        return rounds[rNum].bidConfirmAddresses;
    }

    function getInvestorStatus(uint256 rNum, address investor) public view returns (uint8) {
        return rounds[rNum].investorStatus[investor];
    }

	function startNewRound() internal {
		emit RoundStart(roundNumber);
	}

	function startNextRound(uint8 roundMultiplier) internal {
		roundNumber += 1;
		rounds[roundNumber].multiplierInPercentForETH = roundMultiplier;
		startNewRound();
	}

	function hashCode(bool isBuy, uint256 etherAmount, uint256 avaAmount, address eFWallet, uint256 etherPrice) public pure returns (bytes32) {
		return keccak256(abi.encode(isBuy, etherAmount, avaAmount, eFWallet, etherPrice));
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

	uint public bidTime;

    mapping (uint256 => uint256[]) public bidsNumbersByRounds;

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

	function setFuturesTime(uint newTime) external onlyOwner {
	    bidTime = newTime;
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
		token.transfer(investor, avaAmount);
		investor.transfer(etherAmount);
	}

	function withdrawAVAandEtherAll() external onlyAuthorized canWithdraw {
		address investor = msg.sender;
		uint256 etherAmount = allowedEther[investor];
		uint256 avaAmount = allowedAva[investor];
		allowedAva[investor] -= avaAmount;
		allowedEther[investor] -= etherAmount;
		token.transfer(investor, avaAmount);
		investor.transfer(etherAmount);
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
    		rounds[roundNumber].bidConfirmAddresses.push(investor);
    		rounds[roundNumber].investorStatus[investor] = 2;
		}
		return result;
	}

  function getInvestorData(address investor) public view returns (
        bool isAuthorized,
        uint256 etherBalance,
    		uint256 avaBalance) {
		return (authorized[investor], allowedEther[investor], allowedAva[investor]);
	}

	function sortResults() external isPhase(Phase.THIRD) {
		uint256 bidNumber = rounds[roundNumber].bidConfirmAddresses.length;
        uint256 count = 0;
		while (count < bidNumber) {
		    address currentSeller = 0;
		    address currentBuyer = 0;
		    uint256 currentSellAmount = 0;
		    uint256 currentBuyAmount = 0;
		    for (uint8 i = 0; i < bidNumber; ++i) {
		        address investor = rounds[roundNumber].bidConfirmAddresses[i];
		        if (rounds[roundNumber].investorStatus[investor] != 3) {
    		        Bid storage bid = rounds[roundNumber].bids[investor];
    		        if (bid.isBuy) {
    		            if (bid.avaAmount > currentBuyAmount) {
    		                currentBuyer = investor;
    		                currentBuyAmount = rounds[roundNumber].bids[currentBuyer].avaAmount;
    		            }
    		        } else {
    		            if (bid.avaAmount > currentSellAmount) {
    		                currentSeller = investor;
    		                currentSellAmount = rounds[roundNumber].bids[currentSeller].avaAmount;
    		            }
    		        }
		        }
		    }
		    if (currentBuyer != 0){
		        rounds[roundNumber].buyers.push(currentBuyer);
            rounds[roundNumber].investorStatus[currentBuyer] = 3;
            count = count + 1;
		    }
		    if (currentSeller != 0){
		        rounds[roundNumber].sellers.push(currentSeller);
            rounds[roundNumber].investorStatus[currentSeller] = 3;
            count = count + 1;
		    }
		}
		nextPhase();
	}

	function createBids() public isPhase(Phase.FOURTH) {
	    uint8 buyersNumber = 0;
  		uint8 sellersNumber = 0;
  		Round storage round = rounds[roundNumber];
  		uint256 sellLeft = 0;
	    uint256 buyLeft = 0;

	    while (sellersNumber < round.sellers.length  && buyersNumber < round.buyers.length)  {
		    address currentSeller = round.sellers[sellersNumber];
		    address currentBuyer = round.buyers[buyersNumber];
		    if (sellLeft == 0) {
		        sellLeft = round.bids[currentSeller].etherAmount;
		    }
		    if (buyLeft == 0) {
		        buyLeft = round.bids[currentBuyer].etherAmount;
		    }
		    uint8 direction = 0;
		    uint256 eAmount = 0;
            if (buyLeft > sellLeft) {
                eAmount = sellLeft;
            } else {
                direction = 1;
                eAmount = buyLeft;
            }
            bidsNumbersByRounds[roundNumber]
                .push(bidder.createBid.value((eAmount.mul(2).mul(round.multiplierInPercentForETH).div(100)))(direction, round.bids[currentSeller].eFWallet, round.bids[currentBuyer].eFWallet, getCurrentTime() + bidTime, round.multiplierInPercentForETH))

            // take ava and ether from buuyer and sellers
            allowedAva[currentBuyer] = allowedAva[currentBuyer].sub(eAmount.div(round.bids[currentBuyer].etherAmount).mul(round.bids[currentBuyer].avaAmount));
            allowedAva[currentSeller] = allowedAva[currentSeller].sub(eAmount.div(round.bids[currentSeller].etherAmount).mul(round.bids[currentSeller].avaAmount));
            // TODO: need to do something with AVA.
            //take ether from accounts
            allowedEther[currentSeller] = allowedEther[currentSeller].sub(eAmount.mul(round.multiplierInPercentForETH).div(100));
            allowedEther[currentBuyer] = allowedEther[currentBuyer].sub(eAmount.mul(round.multiplierInPercentForETH).div(100));
            if (sellLeft == buyLeft) {
		        sellLeft == 0;
		        buyLeft == 0;
		        sellersNumber++;
		        buyersNumber++;
		    } else if (sellLeft > buyLeft) {
		        sellLeft -= buyLeft;
		        buyLeft = 0;
		        buyersNumber++;
		    } else {
		        buyLeft -= sellLeft;
		        sellLeft = 0;
		        sellersNumber++;
		    }
		}
		nextPhase();
	}
}

/*
    This contract only for testing. for production it doesn't need to be.
*/
contract AuctionTest is Auction {

    uint public currentTime = now;

    constructor() public {
    	startFirstPhase(3600, 10);
    	phase = Phase.THIRD;

    	rounds[roundNumber].bids[0xeE897700589874b14ca61d003Bbf199a4A38ec86].hash = "asfafaf";
    	Bid storage bidS = rounds[roundNumber].bids[0xeE897700589874b14ca61d003Bbf199a4A38ec86];
    	bidS.isBuy = true;
    	bidS.etherAmount = 6 ether;
    	bidS.avaAmount = 10E19;
    	bidS.eFWallet = 0xeE897700589874b14ca61d003Bbf199a4A38ec86;
    	bidS.etherPrice = 11600;
    	bidS.approved = true;
    	rounds[roundNumber].bidConfirmAddresses.push(0xeE897700589874b14ca61d003Bbf199a4A38ec86);
    	allowedEther[0xeE897700589874b14ca61d003Bbf199a4A38ec86] = 10 ether;
        allowedAva[0xeE897700589874b14ca61d003Bbf199a4A38ec86] = 5E20;

    	rounds[roundNumber].bids[0xb6a2220f066d75A08654deAeb25F79c06cfE3Fa5].hash = "asasfas";
    	Bid storage bidS2 = rounds[roundNumber].bids[0xb6a2220f066d75A08654deAeb25F79c06cfE3Fa5];
    	bidS2.isBuy = false;
    	bidS2.etherAmount = 4 ether;
    	bidS2.avaAmount = 4E19;
    	bidS2.eFWallet = 0xb6a2220f066d75A08654deAeb25F79c06cfE3Fa5;
    	bidS2.etherPrice = 11600;
    	bidS2.approved = true;
    	rounds[roundNumber].bidConfirmAddresses.push(0xb6a2220f066d75A08654deAeb25F79c06cfE3Fa5);
    	allowedEther[0xb6a2220f066d75A08654deAeb25F79c06cfE3Fa5] = 10 ether;
        allowedAva[0xb6a2220f066d75A08654deAeb25F79c06cfE3Fa5] = 5E20;
    }

    function donate() external payable {
    }

    function createBids() public isPhase(Phase.FOURTH) {
        super.createBids();
    }

    function getCurrentTime() internal view returns (uint) {
  	    return currentTime;
    }

    function setCurrentTime(uint newCurrentTime) external {
  	    currentTime = newCurrentTime;
    }
}
