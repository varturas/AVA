pragma solidity ^0.4.21;

import "./Owned.sol";

contract BidFactory is Owned {
	
	function createBid(uint32 price, uint8 direction, address new_counterparty, address bidder, uint end, uint8 margin) public payable onlyOwner;
        
}