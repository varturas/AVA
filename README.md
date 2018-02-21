# ava
Blind auction smart contract

There is 2 contracts:
1. AVAToken - contract which is define ERC20 token;
2. Auction - contract of blind auction;
All other contracts is like part of functionality and they don't need to deploy.

What tool do you use?
1. Mist (M) - use original Solidity code;
2. MyEtherWallet or other online tool(E) - use bytecode functionality;

For deploy need to:
1. need to deploy AVAToken or used another ERC20 token (now AVAToken is common ERC20 token);
2. need to deploy Auction contract
3. set to Auction correct AVAToken (or another ERC20 token) address; // it can be done only by Owner function setToken(address newToken);

#Function description:

Life cycle:
After deploy contract ready to work next steps will help with it;
1. need to call startNextPhase(uint time, uint32 rooundMultiplier) - need to provide time for this phase (time works only for the first and the second one) and roundMultiplier defined only in the first phase otherwise will be ignored;
2. before making some bids need to authorized wallet addAddress(address investor);
3. for making bid person can call function makeBid(bytes32 hashValue) in the first phase;
4. to make a deposit in ETH and AVA need to do next (deposit can be done in any phase):
	a. in AVAToken contract call method approve() with address of Auction contract and amount of AVA tokens;
	b. just transfer ETH to Auction contract (in this function all ETH which you transfer and AVA which you approved will be moved to Auction contract);
5. for switching to next phase owner should call startNextPhase(uint time);
6. for confirm your bid investor should call provideBidInfo(uint256 etherAmount, uint256 avaAmount, address eFWallet, uint256 etherPrice) in the second phase (if etherprice is not used need to put "0" value);
7. after that you will call startNextPhase(uint time) three times and get the new Round.

Getting info from previous rounds use method getBidInfo(uint256 _roundNumber, address investor).