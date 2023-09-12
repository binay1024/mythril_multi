pragma solidity 0.5.0;

contract TokenInterface {
 mapping (address => uint256) public balances;
 mapping (address => mapping (address => uint256)) public allowed;

 /// Total amount of tokens
 uint256 public totalSupply;

 /// @param _owner The address from which the balance will be retrieved
 /// @return The balance
 function balanceOf(address _owner) public view returns (uint256 balance);

 /// @notice Send `_amount` tokens to `_to` from `msg.sender`
 /// @param _to The address of the recipient
 /// @param _amount The amount of tokens to be transferred
 /// @return Whether the transfer was successful or not
 function transfer(address _to, uint256 _amount) public returns (bool success);

 /// @notice Send `_amount` tokens to `_to` from `_from` on the condition it
 /// is approved by `_from`
 /// @param _from The address of the origin of the transfer
 /// @param _to The address of the recipient
 /// @param _amount The amount of tokens to be transferred
 /// @return Whether the transfer was successful or not
 function transferFrom(address _from, address _to, uint256 _amount) public returns (bool success);

 /// @notice `msg.sender` approves `_spender` to spend `_amount` tokens on
 /// its behalf
 /// @param _spender The address of the account able to transfer the tokens
 /// @param _amount The amount of tokens to be approved for transfer
 /// @return Whether the approval was successful or not
 function approve(address _spender, uint256 _amount) public returns (bool success);

 /// @param _owner The address of the account owning tokens
 /// @param _spender The address of the account able to transfer the tokens
 /// @return Amount of remaining tokens of _owner that _spender is allowed
 /// to spend
 function allowance(address _owner, address _spender) public view returns (uint256 remaining);

 event Transfer(address indexed _from, address indexed _to, uint256 _amount);
 event Approval(address indexed _owner, address indexed _spender, uint256 _amount);
}

contract Token is TokenInterface {
 mapping(address => uint256) private balances;
 mapping(address => mapping(address => uint256)) private allowed;

 function balanceOf(address _owner) public view returns (uint256 balance) {
 return balances[_owner];
 }

 function transfer(address _to, uint256 _amount) public returns (bool success) {
 require(balances[msg.sender] >= _amount && _amount > 0, "Insufficient balance or invalid amount");

 balances[msg.sender] -= _amount;
 balances[_to] += _amount;
 emit Transfer(msg.sender, _to, _amount);
 return true;
 }

 function transferFrom(
 address _from,
 address _to,
 uint256 _amount
 ) public returns (bool success) {
 require(
 balances[_from] >= _amount && allowed[_from][msg.sender] >= _amount && _amount > 0,
 "Insufficient balance or invalid amount or allowance"
 );

 balances[_to] += _amount;
 balances[_from] -= _amount;
 allowed[_from][msg.sender] -= _amount;
 emit Transfer(_from, _to, _amount);
 return true;
 }

 function approve(address _spender, uint256 _amount) public returns (bool success) {
 allowed[msg.sender][_spender] = _amount;
 emit Approval(msg.sender, _spender, _amount);
 return true;
 }

 function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
 return allowed[_owner][_spender];
 }
}


contract ManagedAccountInterface {
 // The only address with permission to withdraw from this account
 address public owner;
 // If true, only the owner of the account can receive ether from it
 bool public payOwnerOnly;
 // The sum of ether (in wei) which has been sent to this contract
 uint public accumulatedInput;

 /// @notice Sends `_amount` of wei to `_recipient`
 /// @param _amount The amount of wei to send to `_recipient`
 /// @param _recipient The address to receive `_amount` of wei
 /// @return True if the send completed
 function payOut(address payable _recipient, uint _amount) public payable returns (bool);

 event PayOut(address indexed _recipient, uint _amount);
}


contract TokenCreationInterface {

 // End of token creation, in Unix time
 uint256 public closingTime;
 // Minimum fueling goal of the token creation, denominated in tokens to
 // be created
 uint256 public minTokensToCreate;
 // True if the DAO reached its minimum fueling goal, false otherwise
 bool public isFueled;
 // For DAO splits - if privateCreation is 0, then it is a public token
 // creation, otherwise only the address stored in privateCreation is
 // allowed to create tokens
 address public privateCreation;
 // Hold extra ether which has been sent after the DAO token
 // creation rate has increased
 
 // Tracks the amount of wei given from each contributor (used for refund)
 mapping(address => uint256) public weiGiven;

 function createTokenProxy(address _tokenHolder) public payable returns (bool success);

 /// @notice Refund `msg.sender` in the case the Token Creation did
 /// not reach its minimum fueling goal
 function refund() public payable;

 /// @return The divisor used to calculate the token creation rate during
 /// the creation phase
 function divisor() public view returns (uint256);

 event FuelingToDate(uint256 value);
 event CreatedToken(address indexed to, uint256 amount);
 event Refund(address indexed to, uint256 value);
}


contract ManagedAccount is ManagedAccountInterface {


 constructor(address _owner, bool _payOwnerOnly) public {
 owner = _owner;
 payOwnerOnly = _payOwnerOnly;
 }
 function() external payable {
 accumulatedInput += msg.value;
 }
 function payOut(address payable _recipient, uint _amount) public payable returns (bool) {
 require(msg.sender == owner && msg.value > 0 && (payOwnerOnly && _recipient != owner), "Invalid condition");
 (bool success, ) = _recipient.call.value(_amount).gas(2300)("");
 if (success) {
 emit PayOut(_recipient, _amount);
 return true;
 } else {
 return false;
 }
 }
}

contract TokenCreation is TokenCreationInterface, Token {
 ManagedAccount public extraBalance;

 constructor(uint _minTokensToCreate, uint _closingTime, address _privateCreation) public {
 closingTime = _closingTime;
 minTokensToCreate = _minTokensToCreate;
 privateCreation = _privateCreation;
 extraBalance = new ManagedAccount(address(this), true);
 //address a = address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
 }
 function createTokenProxy(address _tokenHolder) public payable returns (bool success){
 if(now < closingTime && msg.value > 0
 && (privateCreation == address(0)|| privateCreation == msg.sender)){
 uint token = (msg.value * 20) / divisor();
 address(extraBalance).call.value(msg.value - token)("");
 balances[_tokenHolder] += token;
 totalSupply += token;
 weiGiven[_tokenHolder] += msg.value;
 emit CreatedToken(_tokenHolder, token);
 if (totalSupply >= minTokensToCreate && !isFueled) {
 isFueled = true;
 emit FuelingToDate(totalSupply);
 }
 return true;
 }
 revert();
 }
 function refund() public payable {
 if (now > closingTime && !isFueled) {
 // Get extraBalance - will only succeed when called for the first time
 if (address(extraBalance).balance >= extraBalance.accumulatedInput())
 extraBalance.payOut(address(uint160(address(this))), extraBalance.accumulatedInput());

 // Execute refund
 (bool success, ) = msg.sender.call.value(weiGiven[msg.sender])("");
 if (success) {
 emit Refund(msg.sender, weiGiven[msg.sender]);
 totalSupply -= balances[msg.sender];
 balances[msg.sender] = 0;
 weiGiven[msg.sender] = 0;
 }
 }
 }


 function divisor() public view returns (uint256) {
 // The number of (base unit) tokens per wei is calculated
 // as `msg.value` * 20 / `divisor`
 // The fueling period starts with a 1:1 ratio
 if (closingTime - 2 weeks > now) {
 return 20;
 // Followed by 10 days with a daily creation rate increase of 5%
 } else if (closingTime - 4 days > now) {
 return (20 + (now - (closingTime - 2 weeks)) / (1 days));
 // The last 4 days there is a constant creation rate ratio of 1:1.5
 } else {
 return 30;
 }
 }
}











contract DAOInterface {

 uint256 constant public creationGracePeriod = 40 days;
 uint256 constant public minProposalDebatePeriod = 2 weeks;
 uint256 constant public minSplitDebatePeriod = 1 weeks;
 uint256 constant public splitExecutionPeriod = 27 days;
 uint256 constant public quorumHalvingPeriod = 25 weeks;
 uint256 constant public executeProposalPeriod = 10 days;
 uint256 constant public maxDepositDivisor = 100;

 struct Proposal {
 address recipient;
 uint256 amount;
 string description;
 uint256 votingDeadline;
 bool open;
 bool proposalPassed;
 bytes32 proposalHash;
 uint256 proposalDeposit;
 bool newCurator;
 SplitData[] splitData;
 uint256 yea;
 uint256 nay;
 mapping(address => bool) votedYes;
 mapping(address => bool) votedNo;
 address creator;
 }

 struct SplitData {
 uint256 splitBalance;
 uint256 totalSupply;
 uint256 rewardToken;
 address newDAO;
 }

 Proposal[] public proposals;
 uint256 public minQuorumDivisor;
 uint256 public lastTimeMinQuorumMet;

 address public curator;
 mapping(address => bool) public allowedRecipients;

 mapping(address => uint256) public rewardToken;
 uint256 public totalRewardToken;

 ManagedAccount public rewardAccount;
 ManagedAccount public DAOrewardAccount;

 mapping(address => uint256) public DAOpaidOut;
 mapping(address => uint256) public paidOut;
 mapping(address => uint256) public blocked;

 uint256 public proposalDeposit;
 uint256 public sumOfProposalDeposits;

 DAO_Creator public daoCreator;

 modifier onlyTokenholders() {
 revert();
 _;
}


 function () external payable  {}
 function receiveEther() public returns(bool);
 function newProposal(
 address _recipient,
 uint256 _amount,
 string memory _description,
 bytes memory _transactionData,
 uint256 _debatingPeriod,
 bool _newCurator
 ) public payable returns (uint256 _proposalID);
 function checkProposalCode(
 uint256 _proposalID,
 address _recipient,
 uint256 _amount,
 bytes memory _transactionData
 ) public view returns (bool _codeChecksOut);
 function vote(
 uint256 _proposalID,
 bool _supportsProposal
 ) public returns (uint256 _voteID);

 function executeProposal(
 uint256 _proposalID,
 bytes memory _transactionData
 ) public returns (bool _success);
 function splitDAO(
 uint256 _proposalID,
 address _newCurator
 ) public returns (bool _success);
 function newContract(address _newContract) public;
 function changeAllowedRecipients(address _recipient, bool _allowed) public returns (bool _success);
 function changeProposalDeposit(uint256 _proposalDeposit) public;
 function retrieveDAOReward(bool _toMembers) public returns (bool _success);

 function getMyReward() public returns(bool _success);
 function withdrawRewardFor(address _account) internal returns (bool _success);
 function transferWithoutReward(address _to, uint256 _amount) public returns (bool success);
 function transferFromWithoutReward(
 address _from,
 address _to,
 uint256 _amount
 ) public returns (bool success);

 function halveMinQuorum() public returns (bool _success);

 function numberOfProposals() public view returns (uint256 _numberOfProposals);

 function getNewDAOAddress(uint256 _proposalID) public view returns (address _newDAO);
 function isBlocked(address _account) internal returns (bool);

 function unblockMe() public returns (bool);

 event ProposalAdded(
 uint256 indexed proposalID,
 address recipient,
 uint256 amount,
 bool newCurator,
 string description
 );
 event Voted(uint256 indexed proposalID, bool position, address indexed voter);
 event ProposalTallied(uint256 indexed proposalID, bool result, uint256 quorum);
 event NewCurator(address indexed _newCurator);
 event AllowedRecipientChanged(address indexed _recipient, bool _allowed);
}

contract DAO is DAOInterface, Token, TokenCreation {
 modifier onlyTokenholders {
 if (balanceOf(msg.sender) == 0) revert();
 _;
 }
 constructor(
 address _curator,
 DAO_Creator _daoCreator,
 uint _proposalDeposit,
 uint _minTokensToCreate,
 uint _closingTime,
 address _privateCreation
 ) public TokenCreation(_minTokensToCreate, _closingTime, _privateCreation) {

 curator = _curator;
 daoCreator = _daoCreator;
 proposalDeposit = _proposalDeposit;
 rewardAccount = new ManagedAccount(address(this), false);
 DAOrewardAccount = new ManagedAccount(address(this), false);
 if (address(rewardAccount) == address(0))
 revert();
 if (address(DAOrewardAccount) == address(0))
 revert();
 lastTimeMinQuorumMet = now;
 minQuorumDivisor = 5; // sets the minimal quorum to 20%
 proposals.length = 1; // avoids a proposal with ID 0 because it is used

 allowedRecipients[address(this)] = true;
 allowedRecipients[curator] = true;
 }
 function ()external payable  {
 if (now < closingTime + creationGracePeriod && msg.sender != address(extraBalance))
 createTokenProxy(msg.sender);
 else
 receiveEther();
 }
 function receiveEther() public returns(bool){
 return true;
 }
 function newProposal(
 address _recipient,
 uint256 _amount,
 string memory _description,
 bytes memory _transactionData,
 uint256 _debatingPeriod,
 bool _newCurator
 ) public payable returns (uint256 _proposalID){
 if (_newCurator && (
 _amount != 0
 || _transactionData.length != 0
 || _recipient == curator
 || msg.value > 0
 || _debatingPeriod < minSplitDebatePeriod)) {
 revert();
 } else if (
 !_newCurator
 && (!isRecipientAllowed(_recipient) || (_debatingPeriod < minProposalDebatePeriod))
 ) {
 revert();
 }

 if (_debatingPeriod > 8 weeks)
 revert();

 if (!isFueled
 || now < closingTime
 || (msg.value < proposalDeposit && !_newCurator)) {

 revert();
 }

 if (now + _debatingPeriod < now) // prevents overflow
 revert();

 // to prevent a 51% attacker to convert the ether into deposit
 if (msg.sender == address(this))
 revert();
 _proposalID = proposals.length++;
 Proposal storage p = proposals[_proposalID];
 p.recipient = _recipient;
 p.amount = _amount;
 p.description = _description;
 p.proposalHash = keccak256(abi.encode(_recipient, _amount, _transactionData));
 p.votingDeadline = now + _debatingPeriod;
 p.open = true;
 //p.proposalPassed = False; // that's default
 p.newCurator = _newCurator;
 if (_newCurator)
 //p.splitData.length++;
 p.creator = msg.sender;
 p.proposalDeposit = msg.value;

 sumOfProposalDeposits += msg.value;

 emit ProposalAdded(
 _proposalID,
 _recipient,
 _amount,
 _newCurator,
 _description
 );
 }
 function checkProposalCode(
 uint256 _proposalID,
 address _recipient,
 uint256 _amount,
 bytes memory _transactionData
 ) public view returns (bool _codeChecksOut){
 Proposal memory p = proposals[_proposalID];
 return p.proposalHash == keccak256(abi.encodePacked(_recipient, _amount, _transactionData)); 
 }
 function vote(
 uint256 _proposalID,
 bool _supportsProposal
 ) public returns (uint256 _voteID){
 Proposal storage p = proposals[_proposalID];
 if (p.votedYes[msg.sender]
 || p.votedNo[msg.sender]
 || now >= p.votingDeadline) {

 revert();
 } 
 if (_supportsProposal) {
 p.yea += balances[msg.sender];
 p.votedYes[msg.sender] = true;
 } else {
 p.nay += balances[msg.sender];
 p.votedNo[msg.sender] = true;
 }
 if (blocked[msg.sender] == 0) {
 blocked[msg.sender] = _proposalID;
 } else if (p.votingDeadline > proposals[blocked[msg.sender]].votingDeadline) {
 // this proposal's voting deadline is further into the future than
 // the proposal that blocks the sender so make it the blocker
 blocked[msg.sender] = _proposalID;
 }

 emit Voted(_proposalID, _supportsProposal, msg.sender);
 }

 function executeProposal(
 uint256 _proposalID,
 bytes memory _transactionData
 ) public returns (bool _success){
 Proposal storage p = proposals[_proposalID];

 uint waitPeriod = p.newCurator
 ? splitExecutionPeriod
 : executeProposalPeriod;
 // If we are over deadline and waiting period, assert proposal is closed
 if (p.open && now > p.votingDeadline + waitPeriod) {
 closeProposal(_proposalID);
 //return;
 } 
 if (now < p.votingDeadline // has the voting deadline arrived?
 // Have the votes been counted?
 || !p.open
 // Does the transaction code match the proposal?
 || p.proposalHash != keccak256(abi.encodePacked(p.recipient, p.amount, _transactionData))) {

 revert();
 }
 if (!isRecipientAllowed(p.recipient)) {
 closeProposal(_proposalID);
 bool success = address(uint160(p.creator)).send(p.proposalDeposit);
 require(success, "Transfer failed");

 //return;
 } 
 bool proposalCheck = true;

 if (p.amount > actualBalance())
 proposalCheck = false;

 uint quorum = p.yea + p.nay;

 // require 53% for calling newContract()
 if (_transactionData.length >= 4 && _transactionData[0] == 0x68
 && _transactionData[1] == 0x37 && _transactionData[2] == 0xff
 && _transactionData[3] == 0x1e
 && quorum < minQuorum(actualBalance() + rewardToken[address(this)])) {

 proposalCheck = false;
 }
 if (quorum >= minQuorum(p.amount)) {
 bool success = address(uint160(p.creator)).send(p.proposalDeposit);
 require(success, "Transfer failed");


 lastTimeMinQuorumMet = now;
 // set the minQuorum to 20% again, in the case it has been reached
 if (quorum > totalSupply / 5)
 minQuorumDivisor = 5;
 }
 if (quorum >= minQuorum(p.amount) && p.yea > p.nay && proposalCheck) {
 // if (!p.recipient.call.value(p.amount)(_transactionData))
 // revert(); // if (!p.recipient.call.value(p.amount)(_transactionData))
 // revert();
 (bool success, bytes memory data) = p.recipient.call.value(p.amount)(_transactionData);
 if (!success) {
 // 处理调用失败的逻辑
 }


 p.proposalPassed = true;
 _success = true;

 // only create reward tokens when ether is not sent to the DAO itself and
 // related addresses. Proxy addresses should be forbidden by the curator.
 if (p.recipient != address(this) && p.recipient != address(rewardAccount)
 && p.recipient != address(DAOrewardAccount)
 && p.recipient != address(extraBalance)
 && p.recipient != address(curator)) {

 rewardToken[address(this)] += p.amount;
 totalRewardToken += p.amount;
 }
 }
 closeProposal(_proposalID);

 // Initiate event
 emit ProposalTallied(_proposalID, _success, quorum);
 }
 function closeProposal(uint _proposalID) internal {
 Proposal storage p = proposals[_proposalID];
 if (p.open)
 sumOfProposalDeposits -= p.proposalDeposit;
 p.open = false;
 }
 function splitDAO(
 uint256 _proposalID,
 address _newCurator
 ) public returns (bool _success){
 Proposal storage p = proposals[_proposalID];

 // Sanity check

 if (now < p.votingDeadline // has the voting deadline arrived?
 //The request for a split expires XX days after the voting deadline
 || now > p.votingDeadline + splitExecutionPeriod
 // Does the new Curator address match?
 || p.recipient != _newCurator
 // Is it a new curator proposal?
 || !p.newCurator
 // Have you voted for this split?
 || !p.votedYes[msg.sender]
 // Did you already vote on another proposal?
 || (blocked[msg.sender] != _proposalID && blocked[msg.sender] != 0) ) {

 revert();
 }
 if (address(p.splitData[0].newDAO) == address(0)) {
 p.splitData[0].newDAO = address(createNewDAO(_newCurator));
 // Call depth limit reached, etc.
 if (address(p.splitData[0].newDAO) == address(0))
 revert();
 // should never happen
 if (address(this).balance < sumOfProposalDeposits)
 revert();
 p.splitData[0].splitBalance = actualBalance();
 p.splitData[0].rewardToken = rewardToken[address(this)];
 p.splitData[0].totalSupply = totalSupply;
 p.proposalPassed = true;
 }
 uint fundsToBeMoved =
 (balances[msg.sender] * p.splitData[0].splitBalance) /
 p.splitData[0].totalSupply;
//  if (DAO(p.splitData[0].newDAO).createTokenProxy{value: fundsToBeMoved}(msg.sender))
//  revert(); 
 
 uint rewardTokenToBeMoved =
 (balances[msg.sender] * p.splitData[0].rewardToken) /
 p.splitData[0].totalSupply;

 uint paidOutToBeMoved = DAOpaidOut[address(this)] * rewardTokenToBeMoved /
 rewardToken[address(this)];

 rewardToken[address(p.splitData[0].newDAO)] += rewardTokenToBeMoved;
 if (rewardToken[address(this)] < rewardTokenToBeMoved)
 revert();
 rewardToken[address(this)] -= rewardTokenToBeMoved;

 DAOpaidOut[address(p.splitData[0].newDAO)] += paidOutToBeMoved;
 if (DAOpaidOut[address(this)] < paidOutToBeMoved)
 revert();
 DAOpaidOut[address(this)] -= paidOutToBeMoved;

 // Burn DAO Tokens
 emit Transfer(msg.sender, address(0), balances[msg.sender]);
 withdrawRewardFor(msg.sender); // be nice, and get his rewards
 totalSupply -= balances[msg.sender];
 balances[msg.sender] = 0;
 paidOut[msg.sender] = 0;
 return true; 
 }
 function newContract(address _newContract) public{
 if (msg.sender != address(this) || !allowedRecipients[_newContract]) return;
 // move all ether
 (bool success, ) = _newContract.call.value(address(this).balance)("");
 if (!success) {

 revert();
 }

 //move all reward tokens
 rewardToken[_newContract] += rewardToken[address(this)];
 rewardToken[address(this)] = 0;
 DAOpaidOut[_newContract] += DAOpaidOut[address(this)];
 DAOpaidOut[address(this)] = 0; 
 }
 function changeAllowedRecipients(address _recipient, bool _allowed) public returns (bool _success){
 if (msg.sender != curator)
 revert();
 allowedRecipients[_recipient] = _allowed;
 emit AllowedRecipientChanged(_recipient, _allowed);
 return true;
 }
 function changeProposalDeposit(uint256 _proposalDeposit) public{
 if (msg.sender != address(this) || _proposalDeposit > (actualBalance() + rewardToken[address(this)])
 / maxDepositDivisor) {

 revert();
 }
 proposalDeposit = _proposalDeposit; 
 }
 function retrieveDAOReward(bool _toMembers) public returns (bool _success){
 DAO dao = DAO(msg.sender);

 if ((rewardToken[msg.sender] * DAOrewardAccount.accumulatedInput()) /
 totalRewardToken < DAOpaidOut[msg.sender])
 revert();

 uint256 reward =
 (rewardToken[msg.sender] * DAOrewardAccount.accumulatedInput()) /
 totalRewardToken - DAOpaidOut[msg.sender];
 if(_toMembers) {
 if (!DAOrewardAccount.payOut(address(uint160(address(dao.rewardAccount()))), reward))
 revert();
 }
 else {
 if (!DAOrewardAccount.payOut(address(uint160(address(dao))), reward))
 revert();
 }
 DAOpaidOut[msg.sender] += reward;
 return true; 
 }

 function getMyReward() public returns(bool _success){
 return withdrawRewardFor(msg.sender);
 }
 function withdrawRewardFor(address _account) internal returns (bool _success){
//  if ((balanceOf(_account) * rewardAccount.accumulatedInput()) / totalSupply < paidOut[_account])
//  revert();

 uint reward = 1 ether;
//  (balanceOf(_account) * rewardAccount.accumulatedInput()) / totalSupply - paidOut[_account];
  if (!rewardAccount.payOut(address(uint160(address(_account))), reward))
  revert();
 paidOut[_account] += reward;
 return true;
 }

 function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
 if (isFueled
 && now > closingTime
 && !isBlocked(_from)
 && transferPaidOut(_from, _to, _value)
 && super.transferFrom(_from, _to, _value)) {

 return true;
 } else {
 revert();
 }
 }

 function transferFromWithoutReward(
 address _from,
 address _to,
 uint256 _amount
 ) public returns (bool success) {
 if (!withdrawRewardFor(_from))
 revert();
 return transferFrom(_from, _to, _amount);
 }



 function halveMinQuorum() public returns (bool _success){
 if ((lastTimeMinQuorumMet < (now - quorumHalvingPeriod) || msg.sender == curator)
 && lastTimeMinQuorumMet < (now - minProposalDebatePeriod)) {
 lastTimeMinQuorumMet = now;
 minQuorumDivisor *= 2;
 return true;
 } else {
 return false;
 }
 }

 function numberOfProposals() public view returns (uint256 _numberOfProposals){
 return proposals.length - 1;
 }

 function getNewDAOAddress(uint256 _proposalID) public view returns (address _newDAO){
 return proposals[_proposalID].splitData[0].newDAO;
 }
 function isBlocked(address _account) internal returns (bool){
 if (blocked[_account] == 0)
 return false;
 Proposal storage p = proposals[blocked[_account]];
 if (now > p.votingDeadline) {
 blocked[_account] = 0;
 return false;
 } else {
 return true;
 }
 }

 function unblockMe() public returns (bool){
 return isBlocked(msg.sender);
 }

 function transfer(address _to, uint256 _value) public returns (bool success) {
 if (isFueled
 && now > closingTime
 && !isBlocked(msg.sender)
 && transferPaidOut(msg.sender, _to, _value)
 && super.transfer(_to, _value)) {

 return true;
 } else {
 revert();
 }
 }
 function transferWithoutReward(address _to, uint256 _value) public returns (bool success) {
 if (!getMyReward())
 revert();
 return transfer(_to, _value);
 }

 function transferPaidOut(
 address _from,
 address _to,
 uint256 _value
 ) internal returns (bool success) {

 uint transferPaidOut = paidOut[_from] * _value / balanceOf(_from);
 if (transferPaidOut > paidOut[_from])
 revert();
 paidOut[_from] -= transferPaidOut;
 paidOut[_to] += transferPaidOut;
 return true;
 }

 function isRecipientAllowed(address _recipient) internal returns (bool _isAllowed) {
 if (allowedRecipients[_recipient]
 || (_recipient == address(extraBalance)
 // only allowed when at least the amount held in the
 // extraBalance account has been spent from the DAO
 && totalRewardToken > extraBalance.accumulatedInput()))
 return true;
 else
 return false;
 }

 function actualBalance() public view returns (uint _actualBalance) {
 return address(this).balance - sumOfProposalDeposits;

 }

 function minQuorum(uint _value) internal view returns (uint _minQuorum) {
 // minimum of 20% and maximum of 53.33%
 return totalSupply / minQuorumDivisor +
 (_value * totalSupply) / (3 * (actualBalance() + rewardToken[address(this)]));
 }

 function createNewDAO(address _newCurator) internal returns (DAO _newDAO) {
 emit NewCurator(_newCurator);
 return daoCreator.createDAO(_newCurator, 0, 0, now + splitExecutionPeriod);
 }

}

contract DAO_Creator {
 function createDAO(
 address _curator,
 uint _proposalDeposit,
 uint _minTokensToCreate,
 uint _closingTime
 ) public returns (DAO _newDAO) {
 return new DAO(
 _curator,
 DAO_Creator(this),
 _proposalDeposit,
 _minTokensToCreate,
 _closingTime,
 msg.sender
 );
 }
}