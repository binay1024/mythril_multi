// SPDX-License-Identifier: GPL-3.0
pragma solidity <= 0.5.1;

contract ManagedAccountInterface {
    // The only address with permission to withdraw from this account
    address public owner;
    // If true, only the owner of the account can receive ether from it
    bool public payOwnerOnly;
    // The sum of ether (in wei) which has been sent to this contract
    uint public accumulatedInput;

    /// @notice Sends `_amount` of wei to _recipient
    /// @param _amount The amount of wei to send to `_recipient`
    /// @param _recipient The address to receive `_amount` of wei
    /// @return True if the send completed
    function payOut(address _recipient, uint _amount) public payable returns (bool);

    event PayOut(address indexed _recipient, uint _amount);
}


contract ManagedAccount is ManagedAccountInterface{

    // The constructor sets the owner of the account
    constructor (address _owner, bool _payOwnerOnly) public {
        owner = _owner;
        payOwnerOnly = _payOwnerOnly;
    }
  
    // When the contract receives a transaction without data this is called. 
    // It counts the amount of ether it receives and stores it in 
    // accumulatedInput.
    function() external payable {
        accumulatedInput += msg.value;
    }

    function payOut(address _recipient, uint _amount) public payable returns (bool) {
        
        // msg.sender 是 DAO，payOwnerOnly是 关于 rewardAccount和 DAOrewardAccount都是 false， 只有 extraBalance设置的是 true
        // 所以才可以通过验证
        
        if (msg.sender != owner || msg.value > 0 || (payOwnerOnly && _recipient != owner))
            revert();
        // 打完钱之后 进入黑客账户， 他会利用地址 获取 DAO合约对象，而这个时候这个对象的 状态变量还是没有变更的 状态变量，因为当前的 tx并没有结束
        // 所以在 原有的状态下 继续调用 splitDAO, 这是个 默认的 public函数，检查
        (bool success, bytes memory data)  = _recipient.call.value(_amount)("");
        if (success) {
            
            // 事件
            
            return true;
        } else {
            return false;
        }
    }
}


contract TokenInterface {
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;

    /// Total amount of tokens
    uint256 public totalSupply;

    /// @param _owner The address from which the balance will be retrieved
    /// 
    /// @return The balance
    function balanceOf(address _owner) public view returns (uint256 balance);

    /// @notice Send `_amount` tokens to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _amount) public payable returns (bool success);

    /// @notice Send `_amount` tokens to `_to` from `_from` on the condition it
    /// is approved by `_from`
    /// @param _from The address of the origin of the transfer
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return Whether the transfer was successful or not
    function transferFrom(address _from, address _to, uint256 _amount) public payable returns (bool success);

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
    function allowance(
        address _owner,
        address _spender
    ) public view returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _amount
    );
}


contract Token is TokenInterface {
    // Protects users by preventing the execution of method calls that
    // inadvertently also transferred ether
    modifier noEther() {if (msg.value > 0) {revert();} _;}

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _amount) noEther public payable returns (bool success) {
        if (balances[msg.sender] >= _amount && _amount > 0) {
            balances[msg.sender] -= _amount;
            balances[_to] += _amount;

            return true;
        } else {
           return false;
        }
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) noEther public payable returns (bool success) {

        if (balances[_from] >= _amount
            && allowed[_from][msg.sender] >= _amount
            && _amount > 0) {

            balances[_to] += _amount;
            balances[_from] -= _amount;
            allowed[_from][msg.sender] -= _amount;
            // Transfer(_from, _to, _amount);
            return true;
        } else {
            return false;
        }
    }

    function approve(address _spender, uint256 _amount) public returns (bool success) {
        allowed[msg.sender][_spender] = _amount;
        // Approval(msg.sender, _spender, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) public  view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
}


contract TokenCreationInterface {

    // End of token creation, in Unix time
    uint public closingTime;
    // Minimum fueling goal of the token creation, denominated in tokens to
    // be created
    uint public minTokensToCreate;
    // True if the DAO reached its minimum fueling goal, false otherwise
    bool public isFueled;
    // For DAO splits - if privateCreation is 0, then it is a public token
    // creation, otherwise only the address stored in privateCreation is
    // allowed to create tokens
    address public privateCreation;
    // hold extra ether which has been sent after the DAO token
    // creation rate has increased
    ManagedAccount public extraBalance;
    // tracks the amount of wei given from each contributor (used for refund)
    mapping (address => uint256) weiGiven;

    /// @dev Constructor setting the minimum fueling goal and the
    /// end of the Token Creation
    /// @param _minTokensToCreate Minimum fueling goal in number of
    ///        Tokens to be created
    /// @param _closingTime Date (in Unix time) of the end of the Token Creation
    /// @param _privateCreation Zero means that the creation is public.  A
    /// non-zero address represents the only address that can create Tokens
    /// (the address can also create Tokens on behalf of other accounts)
    // This is the constructor: it can not be overloaded so it is commented out
    //  function TokenCreation(
        //  uint _minTokensTocreate,
        //  uint _closingTime,
        //  address _privateCreation
    //  );

    /// @notice Create Token with `_tokenHolder` as the initial owner of the Token
    /// @param _tokenHolder The address of the Tokens's recipient
    /// @return Whether the token creation was successful
    function createTokenProxy(address _tokenHolder) public payable returns (bool success);

    /// @notice Refund `msg.sender` in the case the Token Creation did
    /// not reach its minimum fueling goal
    function refund() public payable ;

    /// @return The divisor used to calculate the token creation rate during
    /// the creation phase
    function divisor() view public returns (uint );

    event FuelingToDate(uint value);
    event CreatedToken(address indexed to, uint amount);
    event Refund(address indexed to, uint value);
}


contract TokenCreation is TokenCreationInterface, Token {

    constructor (
        uint _minTokensToCreate,
        uint _closingTime,
        address _privateCreation) public {

        closingTime = _closingTime;
        minTokensToCreate = _minTokensToCreate;
        privateCreation = _privateCreation;
        extraBalance = new ManagedAccount(address(this), true);
    }

    function createTokenProxy(address _tokenHolder) public payable returns (bool success) {
        if (now < closingTime && msg.value > 0
            && (privateCreation == address(0) || privateCreation == msg.sender)) {

            uint token = (msg.value * 20) / divisor();
            address(extraBalance).call.value(msg.value - token)("");
            balances[_tokenHolder] += token;
            totalSupply += token;
            weiGiven[_tokenHolder] += msg.value;
            // CreatedToken(_tokenHolder, token);
            
            if (totalSupply >= minTokensToCreate && !isFueled) {
                isFueled = true;
                // FuelingToDate(totalSupply);
            }
            return true;
        }
        revert();
    }

    function refund() public payable noEther {
        if (now > closingTime && !isFueled) {
            // Get extraBalance - will only succeed when called for the first time
            if (address(extraBalance).balance >= extraBalance.accumulatedInput())
                extraBalance.payOut(address(this), extraBalance.accumulatedInput());

            // Execute refund
            (bool scuess, bytes memory data) = msg.sender.call.value(weiGiven[msg.sender])("");
            if (scuess) {
                // Refund(msg.sender, weiGiven[msg.sender]);
                totalSupply -= balances[msg.sender];
                balances[msg.sender] = 0;
                weiGiven[msg.sender] = 0;
            }
        }
    }

    function divisor() view public  returns (uint) {
        // The number of (base unit) tokens per wei is calculated
        // as `msg.value` * 20 / `divisor`
        // The fueling period starts with a 1:1 ratio
        if (closingTime - 2 weeks > now) {
            return 20;
        // Followed by 10 days with a daily creation rate increase of 5%
        } else if (closingTime - 4 days > now) {
            return (20 + (now - (closingTime - 2 weeks)) / (1 days));
        // The last 4 days there is a view creation rate ratio of 1:1.5
        } else {
            return 30;
        }
    }
}




contract DAOInterface {

    // The amount of days for which people who try to participate in the
    // creation by calling the fallback function will still get their ether back
    // 人们可以通过调用 fallback函数 拿回自己的eth的 最大天数
    uint constant creationGracePeriod = 40 days;

    // The minimum debate period that a generic proposal can have
    // 一般提案最短讨论期限
    uint constant minProposalDebatePeriod = 2 weeks;
    
    // 拆分提案最短讨论期限 
    // The minimum debate period that a split proposal can have
    uint constant minSplitDebatePeriod = 1 weeks;
    
    // Period of days inside which it's possible to execute a DAO split
    // 可以执行拆分DAo的 日期
    uint constant splitExecutionPeriod = 27 days;

    // Period of time after which the minimum Quorum is halved
    // 最小法定人数减半后的 时间周期 
    uint constant quorumHalvingPeriod = 25 weeks;

    // Period after which a proposal is closed
    // (used in the case `executeProposal` fails because it throws)
    // 当执行提案失败后，执行关闭提案的期间
    uint constant executeProposalPeriod = 10 days;

    // Denotes the maximum proposal deposit that can be given. It is given as
    // a fraction of total Ether spent plus balance of the DAO
    // 可以提供的 最大提案押金。它由 花费的以太币　+　DAO余额后 总和的 一部分组成
    uint constant maxDepositDivisor = 100;

    // Proposals to spend the DAO's ether or to choose a new Curator
    // 有关 花费DAO的 eth 或者 选择一个新的 监管人的 提案
    Proposal[] public proposals;


    // The quorum needed for each proposal is partially calculated by
    // totalSupply / minQuorumDivisor
    // 每个提案需要的 法定人数是由 总金额/最小法定人系数 计算的
    uint public minQuorumDivisor;


    // The unix time of the last time quorum was reached on a proposal
    // 上一次 达成了法定人数的提案的 unix时间
    uint  public lastTimeMinQuorumMet;

    // Address of the curator
    // 监管人地址
    address public curator;

    // The whitelist: List of addresses the DAO is allowed to send ether to
    // 白名单，允许从 dao 转账的 收款人地址
    mapping (address => bool) public allowedRecipients;

    // Tracks the addresses that own Reward Tokens. Those addresses can only be
    // DAOs that have split from the original DAO. Conceptually, Reward Tokens
    // represent the proportion of the rewards that the DAO has the right to
    // receive. These Reward Tokens are generated when the DAO spends ether.
    // 跟踪拥有奖励代币的地址。这些地址只能是从原始DAO分裂出来的DAO。
    // 在概念上，奖励代币代表 DAO有权获得的奖励比例。这些奖励代币是在DAO花费以太币时生成的。
    // 所以是 children DAO的地址 - token数量 结构的记录

    mapping (address => uint) public rewardToken;
    // Total supply of rewardToken
    uint public totalRewardToken;

    // The account used to manage the rewards which are to be distributed to the
    // DAO Token Holders of this DAO
    // 用于管理 用于分配给 该DAO token 持有者的奖励的账户。
    // 该账户用于管理奖励， 这些奖励是分配给 这个 children DAO的 token持有者的。 这个是奖励用户
    ManagedAccount public rewardAccount;

    // The account used to manage the rewards which are to be distributed to
    // any DAO that holds Reward Tokens
    // 这个账户用于管理奖励， 这些奖励是分配给 任意持有 奖励token的 DAO合约账户的。 这个是奖励合约。
    ManagedAccount public DAOrewardAccount;

    // Amount of rewards (in wei) already paid out to a certain DAO
    // 已支付给某个DAO的奖励金额（以wei为单位）
    // DAO地址 - 金额 
    mapping (address => uint) public DAOpaidOut;

    // Amount of rewards (in wei) already paid out to a certain address
    // 已经支付给 某个 用户的 奖励金额
    // 用户地址 - 金额
    mapping (address => uint) public paidOut;

    // Map of addresses blocked during a vote (not allowed to transfer DAO
    // tokens). The address points to the proposal ID.
    // 记录被 blocked 锁住的 信息，这个应该是由于 那个 转账保护期间，过了有效期就可以解锁转账了。
    // 账户 - 金额 
    mapping (address => uint) public blocked;

    // The minimum deposit (in wei) required to submit any proposal that is not
    // requesting a new Curator (no deposit is required for splits)
    // 提交任何 非请求新监管人 提案所需的最低押金（以wei为单位）（拆分操作不需要押金）
    uint public proposalDeposit;


    // the accumulated sum of all current proposal deposits
    // 当前所有提案押金的累积总和
    uint sumOfProposalDeposits;

    // Contract that is able to create a new DAO (with the same code as
    // this one), used for splits
    // 可以创建一个 新的 DAO的 合约账户（代码与此合约相同），用于拆分操作
    DAO_Creator public daoCreator;

    // A proposal with `newCurator == false` represents a transaction
    // to be issued by this DAO
    // 如果 newCurator是 false 代表 DAO 认可了的 提案 交易
    // A proposal with `newCurator == true` represents a DAO split
    // 代表 DAO 拆分 
    struct Proposal {
        // The address where the `amount` will go to if the proposal is accepted
        // or if `newCurator` is true, the proposed Curator of
        // the new DAO).
        // 如果该提案被接受，或者newCurator为真，则金额将流向的地址是 提案中提议的新DAO的监管人。
        address recipient;
        // The amount to transfer to `recipient` if the proposal is accepted.
        // 要发送给 收账人的金额
        uint amount;
        // A plain text description of the proposal
        string description;
        // A unix timestamp, denoting the end of the voting period
        uint votingDeadline;

        // True if the proposal's votes have yet to be counted, otherwise False
        bool open;

        // True if quorum has been reached, the votes have been counted, and
        // the majority said yes
        bool proposalPassed;

        // A hash to check validity of a proposal
        bytes32 proposalHash;

        // Deposit in wei the creator added when submitting their proposal. It
        // is taken from the msg.value of a newProposal call.
        // 提案创建者在提交提案时添加的以wei为单位的押金. 该押金来自于newProposal调用的msg.value
        uint proposalDeposit;

        // True if this proposal is to assign a new Curator
        bool newCurator;
        // Data needed for splitting the DAO
        SplitData[] splitData;
        // Number of Tokens in favor of the proposal
        // 赞成该 提案的 代币数量
        uint yea;
        // Number of Tokens opposed to the proposal
        // 反对的代币数量
        uint nay;
        // Simple mapping to check if a shareholder has voted for it
        mapping (address => bool) votedYes;
        // Simple mapping to check if a shareholder has voted against it
        mapping (address => bool) votedNo;
        // Address of the shareholder who created the proposal
        // 提案创建者
        address creator;
    }

    // Used only in the case of a newCurator proposal.
    // 用于 拆分DAO的时候的记录
    struct SplitData {
        // The balance of the current DAO minus the deposit at the time of split
        // 记录 当前 DAO - splitDAo 押金的 余额
        uint splitBalance;
        // The total amount of DAO Tokens in existence at the time of split.
        // 当前拆分时间 DAO代币的总额
        uint totalSupply;
        // Amount of Reward Tokens owned by the DAO at the time of split.
        // 拆分时间 DAO拥有的 奖励 Token
        uint rewardToken;
        // The new DAO contract created at the time of split.
        DAO newDAO;
    }

    // Used to restrict access to certain functions to only DAO Token Holders
    // 定义了一个修改器
    modifier onlyTokenholders {_;}

    /// @dev Constructor setting the Curator and the address
    /// for the contract able to create another DAO as well as the parameters
    /// for the DAO Token Creation
    /// @param _curator The Curator
    /// @param _daoCreator The contract able to (re)create this DAO
    /// @param _proposalDeposit The deposit to be paid for a regular proposal
    /// @param _minTokensToCreate Minimum required wei-equivalent tokens
    ///        to be created for a successful DAO Token Creation
    /// @param _closingTime Date (in Unix time) of the end of the DAO Token Creation
    /// @param _privateCreation If zero the DAO Token Creation is open to public, a
    /// non-zero address means that the DAO Token Creation is only for the address
    // This is the constructor: it can not be overloaded so it is commented out
    //  function DAO(
        //  address _curator,
        //  DAO_Creator _daoCreator,
        //  uint _proposalDeposit,
        //  uint _minTokensToCreate,
        //  uint _closingTime,
        //  address _privateCreation
    //  );

    /// @notice Create Token with `msg.sender` as the beneficiary
    /// @return Whether the token creation was successful
    // 使用msg.sender作为受益人创建代币
    // 返回代币创建是否成功
    function () external payable;


    /// @dev This function is used to send ether back
    /// to the DAO, it can also be used to receive payments that should not be
    /// counted as rewards (donations, grants, etc.)
    /// @return Whether the DAO received the ether successfully
    /// 用于将 以太币 发送回 DAO 也可以接受不应该看做奖励（比如 捐赠， 拨款）的付款。返回值表示 DAO是否成功收到钱
    function receiveEther() public returns(bool);

    /// @notice `msg.sender` creates a proposal to send `_amount` Wei to
    /// `_recipient` with the transaction data `_transactionData`. If
    /// `_newCurator` is true, then this is a proposal that splits the
    /// DAO and sets `_recipient` as the new DAO's Curator.
    /// msg.sender创建一个提案，将_amount Wei发送给_recipient，并附带交易数据_transactionData。
    /// 如果_newCurator为true，则这是一个将DAO拆分并将_recipient设置为新DAO的Curator的提案。

    /// @param _recipient Address of the recipient of the proposed transaction
    /// @param _amount Amount of wei to be sent with the proposed transaction
    /// @param _description String describing the proposal
    /// @param _transactionData Data of the proposed transaction
    /// 他还会将 tx数据 一起发过来 验证？ 

    /// @param _debatingPeriod Time used for debating a proposal, at least 2
    /// weeks for a regular proposal, 10 days for new Curator proposal
    /// @param _newCurator Bool defining whether this proposal is about
    /// a new Curator or not
    /// @return The proposal ID. Needed for voting on the proposal
    function newProposal(
        address _recipient,
        uint _amount,
        string memory _description,
        bytes memory _transactionData,
        uint _debatingPeriod,
        bool _newCurator
    ) public payable returns (uint _proposalID);

    /// @notice Check that the proposal with the ID `_proposalID` matches the
    /// transaction which sends `_amount` with data `_transactionData`
    /// to `_recipient`
    /// @param _proposalID The proposal ID
    /// @param _recipient The recipient of the proposed transaction
    /// @param _amount The amount of wei to be sent in the proposed transaction
    /// @param _transactionData The data of the proposed transaction
    /// @return Whether the proposal ID matches the transaction data or not
    function checkProposalCode(
        uint _proposalID,
        address _recipient,
        uint _amount,
        bytes memory _transactionData
    ) public payable returns (bool _codeChecksOut);

    /// @notice Vote on proposal `_proposalID` with `_supportsProposal`
    /// @param _proposalID The proposal ID
    /// @param _supportsProposal Yes/No - support of the proposal
    /// @return The vote ID.
    function vote(
        uint _proposalID,
        bool _supportsProposal
    ) public payable returns (uint _voteID);

    /// @notice Checks whether proposal `_proposalID` with transaction data
    /// `_transactionData` has been voted for or rejected, and executes the
    /// transaction in the case it has been voted for.
    /// @param _proposalID The proposal ID
    /// @param _transactionData The data of the proposed transaction
    /// @return Whether the proposed transaction has been executed or not
    function executeProposal(
        uint _proposalID,
        bytes memory _transactionData
    ) public payable returns (bool _success);

    /// @notice ATTENTION! I confirm to move my remaining ether to a new DAO
    /// with `_newCurator` as the new Curator, as has been
    /// proposed in proposal `_proposalID`. This will burn my tokens. This can
    /// not be undone and will split the DAO into two DAO's, with two
    /// different underlying tokens.
    /// 我确认将我的剩余以太移动到一个新的 DAO，该 DAO 以 _newCurator 作为新的 Curator，正如在提案 _proposalID 中所提出的那样。
    /// 这将会销毁我的代币。 此操作无法撤销，并将分裂 DAO 为两个 DAO，拥有两种不同的基础代币。

    /// @param _proposalID The proposal ID
    /// @param _newCurator The new Curator of the new DAO
    /// @dev This function, when called for the first time for this proposal,
    /// will create a new DAO and send the sender's portion of the remaining
    /// ether and Reward Tokens to the new DAO. It will also burn the DAO Tokens
    /// of the sender.
    function splitDAO(
        uint _proposalID,
        address _newCurator
    ) public payable returns (bool _success);

    /// @dev can only be called by the DAO itself through a proposal
    /// updates the contract of the DAO by sending all ether and rewardTokens
    /// to the new DAO. The new DAO needs to be approved by the Curator
    /// 只能由 DAO 自身通过提案调用，更新 DAO 的合约，通过发送所有以太币和奖励代币到新的 DAO。新 DAO 需要由管理者批准。

    /// @param _newContract the address of the new contract
    function newContract(address _newContract) public ;


    /// @notice Add a new possible recipient `_recipient` to the whitelist so
    /// that the DAO can send transactions to them (using proposals)
    /// 添加一个新的收款人 _recipient 到白名单中，这样 DAO 就可以通过提案向他们发送交易。

    /// @param _recipient New recipient address
    /// @dev Can only be called by the current Curator
    /// @return Whether successful or not
    function changeAllowedRecipients(address _recipient, bool _allowed) external payable returns (bool _success);


    /// @notice Change the minimum deposit required to submit a proposal
    /// 更改 提案的最小 存款

    /// @param _proposalDeposit The new proposal deposit
    /// @dev Can only be called by this DAO (through proposals with the
    /// recipient being this DAO itself)
    function changeProposalDeposit(uint _proposalDeposit) external payable ;

    /// @notice Move rewards from the DAORewards managed account
    /// 从 DAOrewards 管理账户中 移走 奖励， 如果member是 true 那么 奖励将会被转给 奖励账户，否则 转给dao自己

    /// @param _toMembers If true rewards are moved to the actual reward account
    ///                   for the DAO. If not then it's moved to the DAO itself
    /// @return Whether the call was successful
    function retrieveDAOReward(bool _toMembers) external payable returns (bool _success);

    /// @notice Get my portion of the reward that was sent to `rewardAccount`
    /// 获取 我拥有的 奖励 份额，该奖励 已经发到了 rewardAccount里面了

    /// @return Whether the call was successful
    function getMyReward() public payable returns(bool _success);

    /// @notice Withdraw `_account`'s portion of the reward from `rewardAccount`
    /// to `_account`'s balance
    /// 从rewardAccount中 提取 account的 奖励份额到 account的 余额当中

    /// @return Whether the call was successful
    function withdrawRewardFor(address _account) internal returns (bool _success);

    /// @notice Send `_amount` tokens to `_to` from `msg.sender`. Prior to this
    /// getMyReward() is called.
    /// 从 msgsender 发送 token 到 to, 发送前要调用 get_MyReward函数

    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transfered
    /// @return Whether the transfer was successful or not
    function transferWithoutReward(address _to, uint256 _amount) public returns (bool success);

    /// @notice Send `_amount` tokens to `_to` from `_from` on the condition it
    /// is approved by `_from`. Prior to this getMyReward() is called.
    /// 从 from 发送 token到 to 前提条件是 from 已经批准了。操作前 get_MyReward函数被调用

    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transfered
    /// @return Whether the transfer was successful or not
    function transferFromWithoutReward(
        address _from,
        address _to,
        uint256 _amount
    ) public returns (bool success);

    /// @notice Doubles the 'minQuorumDivisor' in the case quorum has not been
    /// achieved in 52 weeks
    /// 如果52周内未达成法定人数，则将“minQuorumDivisor”翻倍。

    /// @return Whether the change was successful or not
    function halveMinQuorum() public returns (bool _success);

    /// @return total number of proposals ever created
    /// 返回 曾创建了的 提案总数
    function numberOfProposals() public view returns (uint _numberOfProposals);

    /// @param _proposalID Id of the new curator proposal\
    /// 新创建的 监管人的 提案 id

    /// @return Address of the new DAO
    function getNewDAOAddress(uint _proposalID) public view returns (address _newDAO);

    /// @param _account The address of the account which is checked.
    /// 账户地址是否被锁住

    /// @return Whether the account is blocked (not allowed to transfer tokens) or not.
    function isBlocked(address _account) internal returns (bool);

    /// @notice If the caller is blocked by a proposal whose voting deadline
    /// has exprired then unblock him.
    ///如果调用者被一个投票期限已过的提案所阻塞，则解除其阻塞。

    /// @return Whether the account is blocked (not allowed to transfer tokens) or not.
    function unblockMe() public returns (bool);

    event ProposalAdded(
        uint indexed proposalID,
        address recipient,
        uint amount,
        bool newCurator,
        string description
    );
    event Voted(uint indexed proposalID, bool position, address indexed voter);
    event ProposalTallied(uint indexed proposalID, bool result, uint quorum);
    event NewCurator(address indexed _newCurator);
    event AllowedRecipientChanged(address indexed _recipient, bool _allowed);
}

// The DAO contract itself
contract DAO is DAOInterface, Token, TokenCreation {

    // Modifier that allows only shareholders to vote and create new proposals
    modifier onlyTokenholders {
        if (balanceOf(msg.sender) == 0){revert();}
        _;
    }

    constructor(
        address _curator,
        DAO_Creator _daoCreator,
        uint _proposalDeposit,
        uint _minTokensToCreate,
        uint _closingTime,
        address _privateCreation
    ) TokenCreation(_minTokensToCreate, _closingTime, _privateCreation) public {
        //负责审核提案
        curator = _curator;
        // creator的地址
        daoCreator = _daoCreator;

        // 案的押金数量，必须为大于等于一定数量的 DAO 代币
        proposalDeposit = _proposalDeposit;

        // 创建一个新的 ManagedAccount 合约作为奖励账户，
        rewardAccount = new ManagedAccount(address(this), false);

        // 创建一个新的 ManagedAccount 合约作为 DAO 奖励账户

        DAOrewardAccount = new ManagedAccount(address(this), false);
        if (address(rewardAccount) == address(0))
            revert();
        if (address(DAOrewardAccount) == address(0))
            revert();

        lastTimeMinQuorumMet = now;
        minQuorumDivisor = 5; // sets the minimal quorum to 20% 初始化最小法定人数的分母为 5，即最小法定人数为所有 DAO 代币的 20%。
        proposals.length = 1; // avoids a proposal with ID 0 because it is used 初始化 proposals 数组的长度为 1，避免 ID 为 0 的提案
        
        // 初始化允许接收 DAO 代币的地址，包括 DAO 合约自身和策展人。
        allowedRecipients[address(this)] = true;
        allowedRecipients[curator] = true;
    }

    // 如果当前时间在 closingTime + creationGracePeriod 之前，并且发送者不是 extraBalance 地址，则调用 createTokenProxy 函数，并将调用者作为参数传递给它。
    // createTokenProxy 函数是一个TokenCreation里的 内部函数，它用于创建代币代理合约 将 收到的以太币给 extraBalance对应的 新建的 managedAccount。以及
    // 将token 增加到 账簿上
    // 代币代理合约是一个智能合约，它代表了 DAO 的股东，可以执行代币转移和投票等操作。
    // 如果当前时间晚于 closingTime + creationGracePeriod，或者发送者是 extraBalance 地址，则调用 receiveEther 函数。该函数用于确认是否收到了钱。
    function () external payable{
        // 这个函数如果 不是 extraBalance 调用 那么创建 creation
        if (now < closingTime + creationGracePeriod && msg.sender != address(extraBalance)){
            bool success = createTokenProxy(msg.sender);
            if (!success) {
                revert();
            }
        }
        else{
            bool success = receiveEther();
            if (!success) {
                revert();
            }
        }
            
    }


    function receiveEther() public returns (bool) {
        return true;
    }


    function newProposal(
        address _recipient,
        uint _amount,
        string memory _description,
        bytes memory _transactionData,
        uint _debatingPeriod,
        bool _newCurator
    ) onlyTokenholders public payable returns (uint _proposalID) {

        // Sanity check
        if (_newCurator && (
            _amount != 0
            || _transactionData.length != 0
            || _recipient == curator
            || msg.value > 0
            || _debatingPeriod < minSplitDebatePeriod)) {
            revert();
        } else if (
            !_newCurator
            && (!isRecipientAllowed(_recipient) || (_debatingPeriod <  minProposalDebatePeriod))
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
        // p.proposalHash = sha3(_recipient, _amount, _transactionData);
        p.proposalHash = keccak256(abi.encode(_recipient, _amount, _transactionData));
        p.votingDeadline = now + _debatingPeriod;
        p.open = true;
        //p.proposalPassed = False; // that's default
        p.newCurator = _newCurator;
        if (_newCurator){
            uint leng = p.splitData.length;
            p.splitData.length = leng + 1;
        }
            
        p.creator = msg.sender;
        p.proposalDeposit = msg.value;

        sumOfProposalDeposits += msg.value;

        // ProposalAdded(
        //     _proposalID,
        //     _recipient,
        //     _amount,
        //     _newCurator,
        //     _description
        // );
    }


    function checkProposalCode(
        uint _proposalID,
        address _recipient,
        uint _amount,
        bytes memory _transactionData
    ) noEther public payable returns (bool _codeChecksOut) {
        Proposal storage p = proposals[_proposalID];
        // return p.proposalHash == sha3(_recipient, _amount, _transactionData);
        return p.proposalHash == keccak256(abi.encodePacked(_recipient, _amount, _transactionData)); 
    }


    function vote(
        uint _proposalID,
        bool _supportsProposal
    ) onlyTokenholders noEther public payable returns (uint _voteID) {

        Proposal storage p = proposals[_proposalID];
        if (p.votedYes[msg.sender]
            || p.votedNo[msg.sender]
            || now >= p.votingDeadline) {

            revert();
        }
        // 这里修改的都是 提案 p 里面的账簿， 对于DAO上的账簿没有实际的修改
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

        // Voted(_proposalID, _supportsProposal, msg.sender);
    }


    function executeProposal(
        uint _proposalID,
        bytes memory _transactionData
    ) noEther public payable returns (bool _success) {

        Proposal storage p = proposals[_proposalID];

        uint waitPeriod = p.newCurator
            ? splitExecutionPeriod
            : executeProposalPeriod;
        // If we are over deadline and waiting period, assert proposal is closed
        if (p.open && now > p.votingDeadline + waitPeriod) {
            closeProposal(_proposalID);
            return true;
        }

        // Check if the proposal can be executed
        if (now < p.votingDeadline  // has the voting deadline arrived?
            // Have the votes been counted?
            || !p.open
            // Does the transaction code match the proposal?
            // || p.proposalHash != sha3(p.recipient, p.amount, _transactionData)) {
            || p.proposalHash != keccak256(abi.encodePacked(p.recipient, p.amount, _transactionData))) {

            revert();
        }

        // If the curator removed the recipient from the whitelist, close the proposal
        // in order to free the deposit and allow unblocking of voters
        if (!isRecipientAllowed(p.recipient)) {
            closeProposal(_proposalID);
            // p.creator.send(p.proposalDeposit);
            bool success = address(uint160(p.creator)).send(p.proposalDeposit);
            return success;
        }

        bool proposalCheck = true;

        if (p.amount > actualBalance())
            proposalCheck = false;

        uint quorum = p.yea + p.nay;

        // require 53% for calling newContract()
        // 这几个字节是 调用 函数newContract 的意思
        if (_transactionData.length >= 4 && _transactionData[0] == 0x68
            && _transactionData[1] == 0x37 && _transactionData[2] == 0xff
            && _transactionData[3] == 0x1e
            && quorum < minQuorum(actualBalance() + rewardToken[address(this)])) {

                proposalCheck = false;
        }

        if (quorum >= minQuorum(p.amount)) {
            bool scuess = address(uint160(p.creator)).send(p.proposalDeposit);
            if (!scuess)
                revert();

            lastTimeMinQuorumMet = now;
            // set the minQuorum to 20% again, in the case it has been reached
            if (quorum > totalSupply / 5)
                minQuorumDivisor = 5;
        }      

        // Execute result
        if (quorum >= minQuorum(p.amount) && p.yea > p.nay && proposalCheck) {
            (bool success, bytes memory data) = address(p.recipient).call.value(p.amount)(_transactionData);
            if (!success)
                revert();

            p.proposalPassed = true;
            _success = true;

            // only create reward tokens when ether is not sent to the DAO itself and
            // related addresses. Proxy addresses should be forbidden by the curator.
            // 只有當以太幣沒有被發送到 DAO 本身和相關地址時才創建獎勵代幣。 策展人應該禁止代理地址。
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
        // ProposalTallied(_proposalID, _success, quorum);
    }


    function closeProposal(uint _proposalID) internal {
        Proposal storage p = proposals[_proposalID];
        if (p.open)
            sumOfProposalDeposits -= p.proposalDeposit;
        p.open = false;
    }

    function splitDAO(
        uint _proposalID,
        address _newCurator
    ) noEther onlyTokenholders public payable returns (bool _success) {

        Proposal storage p = proposals[_proposalID];

        // Sanity check

        if (now < p.votingDeadline  // has the voting deadline arrived?
            //The request for a split expires XX days after the voting deadline
            || now > p.votingDeadline + splitExecutionPeriod
            // Does the new Curator address match?
            // 新管理者和 p.recipient 必须一致
            || p.recipient != _newCurator
            // Is it a new curator proposal?
            || !p.newCurator
            // Have you voted for this split?
            || !p.votedYes[msg.sender]
            // Did you already vote on another proposal?
            || (blocked[msg.sender] != _proposalID && blocked[msg.sender] != 0) )  {

            revert();
        }

        // If the new DAO doesn't exist yet, create the new DAO and store the
        // current split data
        if (address(p.splitData[0].newDAO) == address(0)) {
            p.splitData[0].newDAO = createNewDAO(_newCurator);
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

        // Move ether and assign new Tokens
        uint fundsToBeMoved =
            (balances[msg.sender] * p.splitData[0].splitBalance) /
            p.splitData[0].totalSupply;
        bool sucess = p.splitData[0].newDAO.createTokenProxy.value(fundsToBeMoved)(msg.sender);
        if (sucess == false){
            revert();
        }
            


        // Assign reward rights to new DAO
        uint rewardTokenToBeMoved =
            (balances[msg.sender] * p.splitData[0].rewardToken) /
            p.splitData[0].totalSupply;

        uint paidOutToBeMoved = DAOpaidOut[address(this)] * rewardTokenToBeMoved /
            rewardToken[address(this)];

        rewardToken[address(p.splitData[0].newDAO)] += rewardTokenToBeMoved;

        if (rewardToken[address(this)] < rewardTokenToBeMoved)
            revert();
        rewardToken[address(this)] -= rewardTokenToBeMoved;
        // 
        DAOpaidOut[address(p.splitData[0].newDAO)] += paidOutToBeMoved;
        if (DAOpaidOut[address(this)] < paidOutToBeMoved)
            revert();
        DAOpaidOut[address(this)] -= paidOutToBeMoved;

        // Burn DAO Tokens 这是个事件
        // Transfer(msg.sender, 0, balances[msg.sender]);

        // 撤回奖励 这是个函数执行
        withdrawRewardFor(msg.sender); // be nice, and get his rewards
        
        // 修改 balances 
        totalSupply -= balances[msg.sender];

        balances[msg.sender] = 0;

        paidOut[msg.sender] = 0;

        return true;
    }

    function newContract(address _newContract) public {
        if (msg.sender != address(this) || !allowedRecipients[_newContract]) return;
        // move all ether
        (bool scuess, bytes memory data) = _newContract.call.value(address(this).balance)("");
        if (!scuess) {
            revert();
        }

        //move all reward tokens
        rewardToken[_newContract] += rewardToken[address(this)];
        rewardToken[address(this)] = 0;
        DAOpaidOut[_newContract] += DAOpaidOut[address(this)];
        DAOpaidOut[address(this)] = 0;
    }


    function retrieveDAOReward(bool _toMembers) external noEther payable returns (bool _success) {
        DAO dao = DAO(msg.sender);

        if ((rewardToken[msg.sender] * DAOrewardAccount.accumulatedInput()) /
            totalRewardToken < DAOpaidOut[msg.sender])
            revert();

        uint reward =
            (rewardToken[msg.sender] * DAOrewardAccount.accumulatedInput()) /
            totalRewardToken - DAOpaidOut[msg.sender];

        if(_toMembers) {
            bool scuess = DAOrewardAccount.payOut(address(dao.rewardAccount()), reward);
            if (!scuess)
                revert();
            }
        else {
            bool scuess = DAOrewardAccount.payOut(address(dao), reward);
            if (!scuess)
                revert();
        }
        DAOpaidOut[msg.sender] += reward;
        return true;
    }

    function getMyReward() noEther public payable returns (bool _success) {
        return withdrawRewardFor(msg.sender);
    }

    // 内部函数
    function withdrawRewardFor(address _account) noEther internal returns (bool _success) {
        // balances[_account] 和 paidOut[_account] 会一致无法更新 
        if ((balanceOf(_account) * rewardAccount.accumulatedInput()) / totalSupply < paidOut[_account])
            revert();

        // 计算奖励
        // 由于 上面两个变量一致没有来得及更新 所以 计算出的 reward 每次也都一样
        uint reward =
            (balanceOf(_account) * rewardAccount.accumulatedInput()) / totalSupply - paidOut[_account];

        // 利用 payOut 
        if (!rewardAccount.payOut(_account, reward))
            revert();

        paidOut[_account] += reward;
        return true;
    }

    // 转移token
    function transfer(address _to, uint256 _value) public payable returns (bool success) {
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


    function transferFrom(address _from, address _to, uint256 _value) public payable returns (bool success) {
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
        uint256 _value
    ) public returns (bool success) {

        if (!withdrawRewardFor(_from))
            revert();
        return transferFrom(_from, _to, _value);
    }


    function transferPaidOut(
        address _from,
        address _to,
        uint256 _value
    ) internal returns (bool success) {

        uint transferPaidOut_ = paidOut[_from] * _value / balanceOf(_from);
        if (transferPaidOut_ > paidOut[_from])
            revert();
        paidOut[_from] -= transferPaidOut_;
        paidOut[_to] += transferPaidOut_;
        return true;
    }


    function changeProposalDeposit(uint _proposalDeposit) noEther external payable {
        if (msg.sender != address(this) || _proposalDeposit > (actualBalance() + rewardToken[address(this)])
            / maxDepositDivisor) {

            revert();
        }
        proposalDeposit = _proposalDeposit;
    }


    function changeAllowedRecipients(address _recipient, bool _allowed) noEther external payable returns (bool _success) {
        if (msg.sender != curator)
            revert();
        allowedRecipients[_recipient] = _allowed;
        // AllowedRecipientChanged(_recipient, _allowed);
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


    function halveMinQuorum() public returns (bool _success) {
        // this can only be called after `quorumHalvingPeriod` has passed or at anytime
        // by the curator with a delay of at least `minProposalDebatePeriod` between the calls
        if ((lastTimeMinQuorumMet < (now - quorumHalvingPeriod) || msg.sender == curator)
            && lastTimeMinQuorumMet < (now - minProposalDebatePeriod)) {
            lastTimeMinQuorumMet = now;
            minQuorumDivisor *= 2;
            return true;
        } else {
            return false;
        }
    }

    function createNewDAO(address _newCurator) internal returns (DAO _newDAO) {
        // NewCurator(_newCurator);
        return daoCreator.createDAO(_newCurator, 0, 0, now + splitExecutionPeriod);
    }

    function numberOfProposals() public view returns (uint _numberOfProposals) {
        // Don't count index 0. It's used by isBlocked() and exists from start
        return proposals.length - 1;
    }

    function getNewDAOAddress(uint _proposalID) public view returns (address _newDAO) {
        return address(proposals[_proposalID].splitData[0].newDAO);
    }

    function isBlocked(address _account) internal returns (bool) {
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

    function unblockMe() public returns (bool) {
        return isBlocked(msg.sender);
    }
}

// 由于 执行了 new， 所以他要求必须在存在 DAO的情况下才可以 new对吧，所以这个合约必须在DAO部署之后才可以生成。 

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
