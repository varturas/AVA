pragma solidity ^0.4.21;

import "./Owned.sol";
import "./BidFactory.sol";

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

/**
 * @title ERC827 interface, an extension of ERC20 token standard
 *
 * @dev Interface of a ERC827 token, following the ERC20 standard with extra
 * @dev methods to transfer value and data and execute calls in transfers and
 * @dev approvals.
 */
contract ERC827 is ERC20 {
  function approve(address _spender, uint256 _value, bytes _data) public returns (bool);
  function transfer(address _to, uint256 _value, bytes _data) public returns (bool);
  function transferFrom(
    address _from,
    address _to,
    uint256 _value,
    bytes _data
  )
    public
    returns (bool);
}

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure.
 * To use this library you can add a `using SafeERC20 for ERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
  function safeTransfer(ERC20Basic token, address to, uint256 value) internal {
    assert(token.transfer(to, value));
  }

  function safeTransferFrom(
    ERC20 token,
    address from,
    address to,
    uint256 value
  )
    internal
  {
    assert(token.transferFrom(from, to, value));
  }

  function safeApprove(ERC20 token, address spender, uint256 value) internal {
    assert(token.approve(spender, value));
  }
}

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
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances.
 */
contract BasicToken is ERC20Basic {
  using SafeMath for uint256;

  mapping(address => uint256) balances;

  uint256 totalSupply_;

  /**
  * @dev total number of tokens in existence
  */
  function totalSupply() public view returns (uint256) {
    return totalSupply_;
  }

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[msg.sender]);

    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    emit Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balances[_owner];
  }

}

/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * @dev https://github.com/ethereum/EIPs/issues/20
 * @dev Based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
contract StandardToken is ERC20, BasicToken {

  mapping (address => mapping (address => uint256)) internal allowed;


  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    emit Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   *
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public returns (bool) {
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender) public view returns (uint256) {
    return allowed[_owner][_spender];
  }

  /**
   * @dev Increase the amount of tokens that an owner allowed to a spender.
   *
   * approve should be called when allowed[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _addedValue The amount of tokens to increase the allowance by.
   */
  function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  /**
   * @dev Decrease the amount of tokens that an owner allowed to a spender.
   *
   * approve should be called when allowed[_spender] == 0. To decrement
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _subtractedValue The amount of tokens to decrease the allowance by.
   */
  function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

}

/**
 * @title ERC827, an extension of ERC20 token standard
 *
 * @dev Implementation the ERC827, following the ERC20 standard with extra
 * @dev methods to transfer value and data and execute calls in transfers and
 * @dev approvals.
 *
 * @dev Uses OpenZeppelin StandardToken.
 */
contract ERC827Token is ERC827, StandardToken {

  /**
   * @dev Addition to ERC20 token methods. It allows to
   * @dev approve the transfer of value and execute a call with the sent data.
   *
   * @dev Beware that changing an allowance with this method brings the risk that
   * @dev someone may use both the old and the new allowance by unfortunate
   * @dev transaction ordering. One possible solution to mitigate this race condition
   * @dev is to first reduce the spender's allowance to 0 and set the desired value
   * @dev afterwards:
   * @dev https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   *
   * @param _spender The address that will spend the funds.
   * @param _value The amount of tokens to be spent.
   * @param _data ABI-encoded contract call to call `_to` address.
   *
   * @return true if the call function was executed successfully
   */
  function approve(address _spender, uint256 _value, bytes _data) public returns (bool) {
    require(_spender != address(this));

    super.approve(_spender, _value);

    require(_spender.call(_data));

    return true;
  }

  /**
   * @dev Addition to ERC20 token methods. Transfer tokens to a specified
   * @dev address and execute a call with the sent data on the same transaction
   *
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amout of tokens to be transfered
   * @param _data ABI-encoded contract call to call `_to` address.
   *
   * @return true if the call function was executed successfully
   */
  function transfer(address _to, uint256 _value, bytes _data) public returns (bool) {
    require(_to != address(this));

    super.transfer(_to, _value);

    require(_to.call(_data));
    return true;
  }

  /**
   * @dev Addition to ERC20 token methods. Transfer tokens from one address to
   * @dev another and make a contract call on the same transaction
   *
   * @param _from The address which you want to send tokens from
   * @param _to The address which you want to transfer to
   * @param _value The amout of tokens to be transferred
   * @param _data ABI-encoded contract call to call `_to` address.
   *
   * @return true if the call function was executed successfully
   */
  function transferFrom(
    address _from,
    address _to,
    uint256 _value,
    bytes _data
  )
    public returns (bool)
  {
    require(_to != address(this));

    super.transferFrom(_from, _to, _value);

    require(_to.call(_data));
    return true;
  }

  /**
   * @dev Addition to StandardToken methods. Increase the amount of tokens that
   * @dev an owner allowed to a spender and execute a call with the sent data.
   *
   * @dev approve should be called when allowed[_spender] == 0. To increment
   * @dev allowed value is better to use this function to avoid 2 calls (and wait until
   * @dev the first transaction is mined)
   * @dev From MonolithDAO Token.sol
   *
   * @param _spender The address which will spend the funds.
   * @param _addedValue The amount of tokens to increase the allowance by.
   * @param _data ABI-encoded contract call to call `_spender` address.
   */
  function increaseApproval(address _spender, uint _addedValue, bytes _data) public returns (bool) {
    require(_spender != address(this));

    super.increaseApproval(_spender, _addedValue);

    require(_spender.call(_data));

    return true;
  }

  /**
   * @dev Addition to StandardToken methods. Decrease the amount of tokens that
   * @dev an owner allowed to a spender and execute a call with the sent data.
   *
   * @dev approve should be called when allowed[_spender] == 0. To decrement
   * @dev allowed value is better to use this function to avoid 2 calls (and wait until
   * @dev the first transaction is mined)
   * @dev From MonolithDAO Token.sol
   *
   * @param _spender The address which will spend the funds.
   * @param _subtractedValue The amount of tokens to decrease the allowance by.
   * @param _data ABI-encoded contract call to call `_spender` address.
   */
  function decreaseApproval(address _spender, uint _subtractedValue, bytes _data) public returns (bool) {
    require(_spender != address(this));

    super.decreaseApproval(_spender, _subtractedValue);

    require(_spender.call(_data));

    return true;
  }

}

contract AVACoin is ERC827Token, Owned {

    string public constant name = "AVA Coin";

    string public constant symbol = "AVA";

    uint32 public constant decimals = 18;

  	constructor(uint256 initialSupply) public {
          totalSupply_ = initialSupply;
          balances[msg.sender] = totalSupply_;
		  emit Transfer(this, msg.sender, totalSupply_);
    }
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
		BidFactory oldBidder = bidder;
		bidder = BidFactory (newBidder);
		bidder.confirmOwner();
		require(bidder.owner == address (this));
		if (address (oldBidder) != 0) {
			oldBidder.changeOwner(msg.sender);
		}
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
	
	function createBids() external isPhase(Phase.Fourth) {
	
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
