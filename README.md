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

After deploy contract ready to work next Steps will help with it;
1. need to call startNextPhase(uint time) - need to provide time for this phase (time works only for the first and the second one);
2. before making some bids need to authorized wallet (addAddress(address investor));
3. for making bid person can call makeBid in the first phase;
4. for switching to next phase owner should call startNextPhase(uint time);
5. for confirm your bid investor should call provideBidInfo(uint256 etherAmount, uint256 avaAmount, address eFWallet) or provideBidInfo(uint256 etherAmount, uint256 avaAmount, address eFWallet, uint256 etherPrice) in the second phase.
6. after that you will call startNextPhase(uint time) three times and get the new Round.

Getting info from previous rounds use method getBidInfo(uint256 _roundNumber, address investor).