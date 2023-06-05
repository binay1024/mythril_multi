// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

abstract contract ManagedAccountInterface {
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
    // function payOut(address _recipient, uint _amount) public returns (bool);

    event PayOut(address indexed _recipient, uint _amount);
}

// 所以这个合约的 用法就是 我可以生成这个合约的人可以指定 管理者地址 
// 只有 管理者 可以负责 取钱 存钱则是 一开始 初始化的时候定义好的. 

contract ManagedAccount is ManagedAccountInterface{

    // The constructor sets the owner of the account
    constructor (address _owner, bool _payOwnerOnly) payable {
        owner = _owner;
        payOwnerOnly = _payOwnerOnly;
    }

    // When the contract receives a transaction without data this is called. 
    // It counts the amount of ether it receives and stores it in 
    // accumulatedInput.
    // fallback 函数用于 将 msg.value 也就是 收到的钱 存入 accumulatedInput变量里 
    fallback() external payable{
        accumulatedInput += msg.value;
    }
    // 将 _amount 大小的 eth 发给 _recipient 地址账户
    function payOut(address _recipient, uint _amount) public payable returns (bool) {
        // 消息发送方 得是 合约拥有者 并且 value 得是 0 并且 收款方也得是 onwer
        if (msg.sender != owner || msg.value > 0 || (payOwnerOnly && _recipient != owner))
            // throw;
            revert();
        //给 收款方 发钱 address(extraBalance).call{value:msg.value - token}("");
        (bool a, bytes memory r) = _recipient.call{value:_amount}("");
        if (a) {
            // 记录事件 没有意义.
            emit PayOut(_recipient, _amount);
            return true;
        } else {
            return false;
        }
    }
}


contract Test{

    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;

    /// Total amount of tokens
    uint256 public totalSupply;
    ManagedAccount public rewardAccount;
    // Amount of rewards (in wei) already paid out to a certain address
    mapping (address => uint) public paidOut;

    modifier noEther() {if (msg.value > 0) revert(); _;}

    constructor () payable {
        rewardAccount = new ManagedAccount(address(this), false);
        totalSupply += msg.value;
        address(rewardAccount).call{value:msg.value-5}("");
        totalSupply -= msg.value-5;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }
    //  cc91ae3f6
    function getMyReward() noEther public payable returns (bool _success) {
        return withdrawRewardFor(msg.sender);
    }

    // 测试的时候发现因为除上一个 0 的值所以引发了 error 然后 revert 了
    function withdrawRewardFor(address _account) noEther internal returns (bool _success) {
        // 尽管是 0 这个路径也进不去, 因为 0 == 0, 
        if ((balanceOf(_account) * rewardAccount.accumulatedInput()) / totalSupply < paidOut[_account])
            // throw;
            revert();

        uint reward =
            (balanceOf(_account) * rewardAccount.accumulatedInput()) / totalSupply - paidOut[_account];
        if (!rewardAccount.payOut(_account, reward))
            // throw;
            revert();
        paidOut[_account] += reward;
        return true;
    }
    
    function test(address _account) noEther external payable returns (uint a, uint b, bool c){
        uint a = (balanceOf(_account) * rewardAccount.accumulatedInput());
        uint b = paidOut[_account];
        bool c = a < b;
        return (a, b, c);

        // paidOut[_account] += 16;
        // return false;
    }

}
