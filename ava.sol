pragma solidity ^0.4.18;

library SafeMath {

    function mul(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal constant returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal constant returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }

}

contract ERC20Basic {
    uint256 public totalSupply;

    function balanceOf(address who) constant public returns (uint256);

    function transfer(address to, uint256 value) public returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) constant public returns (uint256);

    function transferFrom(address from, address to, uint256 value) public returns (bool);

    function approve(address spender, uint256 value) public returns (bool);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Owned {

    address public owner;

    address public newOwner;

    function Owned() public payable {
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

contract BasicToken is ERC20Basic {

    using SafeMath for uint256;

    mapping (address => uint256) balances;

    // Fix for the ERC20 short address attack
    modifier onlyPayloadSize(uint size) {
        require(msg.data.length >= size + 4);
        _;
    }

    function transfer(address _to, uint256 _value) onlyPayloadSize(2 * 32) public returns (bool) {
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        return true;
    }

    function balanceOf(address _owner) constant public returns (uint256 balance) {
        return balances[_owner];
    }

}

contract StandardToken is ERC20, BasicToken {

    mapping (address => mapping (address => uint256)) allowed;

    function transferFrom(address _from, address _to, uint256 _value) onlyPayloadSize(3 * 32) public returns (bool) {
        uint256 _allowance = allowed[_from][msg.sender];

        balances[_to] = balances[_to].add(_value);
        balances[_from] = balances[_from].sub(_value);
        allowed[_from][msg.sender] = _allowance.sub(_value);
        Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) onlyPayloadSize(2 * 32) public returns (bool) {

        require((_value == 0) || (allowed[msg.sender][_spender] == 0));

        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) onlyPayloadSize(2 * 32) constant public returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
}

contract AVACoin is StandardToken {

    string public constant name = "AVA Coin";

    string public constant symbol = "AVA";

    uint32 public constant decimals = 18;

  	function AVACoin(uint256 initialSupply) public {
          totalSupply = initialSupply;
          balances[msg.sender] = totalSupply;
		  Transfer(this, msg.sender, totalSupply);
    }
}

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

	modifier isFirstPhase() {
		require(phase == Phase.FIRST);
		_;
	}

	modifier isSecondPhase() {
		require(phase == Phase.SECOND);
		_;
	}

	modifier isThirdPhase() {
		require(phase == Phase.THIRD);
		_;
	}

	modifier isFourthPhase() {
		require(phase == Phase.FOURTH);
		_;
	}

	function PhasedContract() public {
    	phase = Phase.NO_PHASE;
		startedNewPhase();
	}

	function startedNewPhase() private {
		PhaseStart(phase);
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

	function switchOff() public onlyOwner isFourthPhase {
		phase = Phase.NO_PHASE;
		startedNewPhase();
	}

	function getCurrentTime() internal view returns (uint) {
		return now;
	}

	function startNextPhase(uint time, uint32 roundMultiplier) external onlyOwner {
		require(phase != Phase.FOURTH); // If it was the fourth need to call method for next round.
		phaseTill = getCurrentTime() + time;
		nextPhase();
		if (phase == Phase.FIRST) {
		    startNextRound(roundMultiplier);
		}
	}

	function isPhaseTill() public view returns (bool) {
		return ((phase == Phase.FIRST) || (phase == Phase.SECOND)) && (phaseTill > getCurrentTime());
	}
	
	function startNextRound(uint32 roundMultiplier) internal;
}

contract RoundContract is PhasedContract{

	event RoundStart(uint256 number);

	uint256 public roundNumber = 0;

	struct Bid {
		bytes32 hash;
		uint256 etherAmount;
		uint256 avaAmount;
		uint256 etherPrice;
		address eFWallet;
		bool approved;
	}

	struct Round {
	    uint256 multiplierInPercentForETH;
		mapping (address => Bid) bids;
	}

	Round currentRound;
	mapping (uint256 => Round)  rounds;
	
	function startNewRound() internal {
		RoundStart(roundNumber);
	}

	function startNextRound(uint32 roundMultiplier) internal {
		roundNumber += 1;
		currentRound = rounds[roundNumber];
		currentRound.multiplierInPercentForETH = roundMultiplier;
		startNewRound();
	}

	function hashCode(uint256 etherAmount, uint256 avaAmount, address eFWallet, uint256 etherPrice) public pure returns (bytes32) {
		return keccak256(etherAmount, avaAmount, eFWallet, etherPrice);
	}
	
	function getBidInfo(uint256 _roundNumber, address investor) external view returns (
    	    bytes32 hash,
    		uint256 etherAmount,
    		uint256 avaAmount,
    		uint256 etherPrice,
    		address eFWallet,
    		bool approved)
    {
		
		Bid memory bid =  rounds[_roundNumber].bids[investor];
	    return (bid.hash, bid.etherAmount, bid.avaAmount, bid.etherPrice, bid.eFWallet, bid.approved);
	}

}

contract Auction is RoundContract {
	using SafeMath for uint;
	
	ERC20 public token;
	
	uint256 public lowETHLimit;
	
	enum OrderValidationStatus {
		VALID, // 0
		NOT_ENOUGH_ETH, // 1
		NOT_ENOUGH_AVA, // 2
		INCORRECT_HASH  // 3
	}
	
	function Auction() public {
		lowETHLimit = 1e16; // 0.01 ETH.
	}
	
	function setLowETHLimit(uint256 newLowETHLimit) external onlyOwner {
		lowETHLimit = newLowETHLimit;
	}
	
	function setToken(address newToken) external onlyOwner {
		token = ERC20 (newToken);
	}
	
	function() external payable onlyAuthorized {
		address investor = msg.sender;
		uint256 amountAva = token.allowance(investor, this);
		require(token.transferFrom(investor, this, amountAva));
		allowedAva[investor] += amountAva;
		allowedEther[investor] += msg.value;
	}
	
	function withdrawAVAandEther(uint256 etherAmount, uint256 avaAmount) external onlyAuthorized {
		address investor = msg.sender;
		require(allowedAva[investor] >= avaAmount);
		require(allowedEther[investor] >= etherAmount);
		allowedAva[investor] -= avaAmount;
		allowedEther[investor] -= etherAmount;
		require(token.transfer(investor, avaAmount));
		require(investor.call.gas(3000000).value(etherAmount)());
	}	

	function makeBid(bytes32 hashValue) external onlyAuthorized isFirstPhase returns (bool) {
		require(!isPhaseTill());
		address investor = msg.sender;
		currentRound.bids[investor].hash = hashValue;
		return true;
	}
	
	function validateOrder(address investor, uint256 etherAmount, uint256 avaAmount, address eFWallet, uint256 etherPrice) internal view returns (OrderValidationStatus) {
		// Check hash bid with bid info.
		Bid memory bid = currentRound.bids[investor];
		if (bid.hash != hashCode(etherAmount, avaAmount, eFWallet, etherPrice)) {
		    return OrderValidationStatus.INCORRECT_HASH; // hascode is not valid.
		}
		// Have investor money for this.
		uint256 mustHaveEther = etherAmount.mul(currentRound.multiplierInPercentForETH).div(100); 
		if (mustHaveEther > allowedEther[investor]) {
		    return OrderValidationStatus.NOT_ENOUGH_ETH; // not enough ETH
		}
		if (avaAmount > allowedAva[investor]) {
			return OrderValidationStatus.NOT_ENOUGH_AVA; // not enough AVA
		}
		return OrderValidationStatus.VALID;
	}
	
	function provideBidInfo(uint256 etherAmount, uint256 avaAmount, address eFWallet, uint256 etherPrice) external onlyAuthorized returns (OrderValidationStatus) {
		require(!isPhaseTill());
		require(etherAmount >= lowETHLimit);
		address investor = msg.sender;
		OrderValidationStatus result = validateOrder(investor, etherAmount, avaAmount, eFWallet, etherPrice);	
		if (result == OrderValidationStatus.INCORRECT_HASH) {
			return result;
		}
		Bid storage bidS = currentRound.bids[investor];
		bidS.etherAmount = etherAmount;
		bidS.avaAmount = avaAmount;
		bidS.eFWallet = eFWallet;
		bidS.etherPrice = etherPrice;
		bidS.approved = OrderValidationStatus.VALID == result;
		return result;
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
