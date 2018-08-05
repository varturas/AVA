pragma solidity ^0.4.21;

import "./Owned.sol";

contract BidFactory is Owned {

	function createBid(uint32 price, uint8 direction, address bidder, uint end) public payable onlyOwner;
}