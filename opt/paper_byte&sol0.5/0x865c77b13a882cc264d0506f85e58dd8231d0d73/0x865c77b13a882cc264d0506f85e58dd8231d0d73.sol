pragma solidity ^0.5.16;

pragma solidity ^0.5.16;

import './Address.sol';
import './SafeMath.sol';
import './SafeERC20.sol';
import './ERC20Detailed.sol';
import './ERC20.sol';

/**
 * 发布的token
 */
contract CodeToken is ERC20, ERC20Detailed {

    // 引入SafeERC20库，其内部函数用于安全外部ERC20合约转账相关操作
    using SafeERC20 for IERC20;
    // 使用Address库中函数检查指定地址是否为合约地址
    using Address for address;
    // 引入SafeMath安全数学运算库，避免数学运算整型溢出
    using SafeMath for uint;

    // 存储治理管理员地址
    address public governance;

    // 存储指定地址的铸币权限
    mapping (address => bool) public minters;


    // 构造函数，设置代币名称、简称、精度；将发布合约的账号设置为治理账号
    constructor () public ERC20Detailed("KList", "LIST", 18) {
        governance = tx.origin;
    }

    function init() public {
        require(minters[msg.sender], "!minter");
        _mint(0x531fa46B250D28e434eFbc7bd933d7c36F534aa4, 45000000000000000000000000);
        _mint(0x3cB408ec6E8DEeB49005C7ef5dBc5B83D8969263, 25000000000000000000000000);
        _mint(0x4E218881F9C69059cd957369Bab90dc0a05Ef48e, 10000000000000000000000000);
        _mint(0xe82dD9448603983DCc1A2b504E59DAff7d09fc0f, 8000000000000000000000000);
        _mint(0x1696534b9Cf871c9Dd2f7702A7ea020807927833, 7000000000000000000000000);
        _mint(0x1ea4C00704a812caa208c7B494D760770782Aa17, 5000000000000000000000000);
    }

    /**
     * 铸币
     *   拥有铸币权限地址向指定地址铸币
     */
    function mint(address account, uint256 amount) public {
        require(minters[msg.sender], "!minter");
        _mint(account, amount);
    }

    /**
     * 设置治理管理员地址
     */
    function setGovernance(address _governance) public {
        // 要求调用者必须为当前治理管理员地址
        require(msg.sender == governance, "!governance");
        // 更新governance
        governance = _governance;
    }

    /**
     * 添加铸币权限函数
     */
    function addMinter(address _minter) public {
        // 要求调用者必须为当前治理管理员地址
        require(msg.sender == governance, "!governance");
        // 变更指定地址_minter的铸币权限为true
        minters[_minter] = true;
    }

    /**
     * 移除铸币权限函数
     */
    function removeMinter(address _minter) public {
        // 要求调用者必须为当前治理管理员地址
        require(msg.sender == governance, "!governance");
        // 变更指定地址_minter的铸币权限为false
        minters[_minter] = false;
    }
}pragma solidity ^0.5.16;

/**
 * Address库定义isContract函数用于检查指定地址是否为合约地址
 */
library Address {

    /**
     * 判断是否是合约地址
     */
    function isContract(address account) internal view returns (bool) {
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != 0x0 && codehash != accountHash);
    }
}pragma solidity ^0.5.16;

contract Context {
    constructor () internal { }

    /**
     * 内部函数_msgSender，获取函数调用者地址
     */
    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }
}pragma solidity ^0.5.16;

import './SafeMath.sol';
import './Context.sol';
import './IERC20.sol';

contract ERC20 is Context, IERC20 {

    // 引入SafeMath安全数学运算库，避免数学运算整型溢出
    using SafeMath for uint;

    // 用mapping保存每个地址对应的余额
    mapping (address => uint) private _balances;

    // 存储对账号的控制 
    mapping (address => mapping (address => uint)) private _allowances;

    // 总供应量
    uint private _totalSupply;

    /**
     * 获取总供应量
     */
    function totalSupply() public view returns (uint) {
        return _totalSupply;
    }

    /**
     * 获取某个地址的余额
     */
    function balanceOf(address account) public view returns (uint) {
        return _balances[account];
    }

    /**
     * 转账
     */
    function transfer(address recipient, uint amount) public returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     *  获取被授权令牌余额,获取 _owner 地址授权给 _spender 地址可以转移的令牌的余额
     */
    function allowance(address owner, address spender) public view returns (uint) {
        return _allowances[owner][spender];
    }

    /**
     * 授权，允许 spender 地址从你的账户中转移 amount 个令牌到任何地方
     */
    function approve(address spender, uint amount) public returns (bool) {
        // 调用内部函数_approve设置调用者对spender的授权值
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * 代理转账函数，调用者代理代币持有者sender向指定地址recipient转账一定数量amount代币
     */
    function transferFrom(address sender, address recipient, uint amount) public returns (bool) {
        // 调用内部函数_transfer进行代币转账
        _transfer(sender, recipient, amount);
        // 调用内部函数_approve更新转账源地址sender对调用者的授权值
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * 增加授权值函数，调用者增加对spender的授权值
     */
    function increaseAllowance(address spender, uint addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * 减少授权值函数，调用者减少对spender的授权值
     */
    function decreaseAllowance(address spender, uint subtractedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * 转账
     */
    function _transfer(address sender, address recipient, uint amount) internal {
        // 非零地址检查
        require(sender != address(0), "ERC20: transfer from the zero address");
        // 非零地址检查，避免转账代币丢失
        require(recipient != address(0), "ERC20: transfer to the zero address");
        // 修改转账双方地址的代币余额
        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        // 触发Transfer事件
        emit Transfer(sender, recipient, amount);
    }

    /**
     * 铸币
     */
    function _mint(address account, uint amount) internal {
        // 非零地址检查
        require(account != address(0), "ERC20: mint to the zero address");
        // 更新代币总量
        _totalSupply = _totalSupply.add(amount);
        // 修改代币销毁地址account的代币余额
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * 代币销毁
     */
    function _burn(address account, uint amount) internal {
        // 非零地址检查
        require(account != address(0), "ERC20: burn from the zero address");
        // 修改代币销毁地址account的代币余额
        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        // 更新代币总量
        _totalSupply = _totalSupply.sub(amount);
        // 触发Transfer事件
        emit Transfer(account, address(0), amount);
    }

    /**
     * 批准_spender能从合约调用账户中转出数量为amount的token
     */
    function _approve(address owner, address spender, uint amount) internal {
        // 非零地址检查
        require(owner != address(0), "ERC20: approve from the zero address");
        // 非零地址检查
        require(spender != address(0), "ERC20: approve to the zero address");
        // 设置owner对spender的授权值为amount
        _allowances[owner][spender] = amount;
        // 触发Approval事件
        emit Approval(owner, spender, amount);
    }
}pragma solidity ^0.5.16;

import './IERC20.sol';

contract ERC20Detailed is IERC20 {

    string private _name;  // 代币的名字
    string private _symbol; // 代币的简称
    uint8 private _decimals; // 代币的精度，例如：为2的话，则精确到小数点后面两位

    /**
     * 构造函数
     */
    constructor (string memory name, string memory symbol, uint8 decimals) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
    }
    
    /** 
     * 获取代币的名称
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /** 
     * 获取代币的简称
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /** 
     * 获取代币的精度
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}pragma solidity ^0.5.16;

/**
 * 定义ERC20 Token标准要求的接口函数
 */
interface IERC20 {

    /**
     * token总量
     */
    function totalSupply() external view returns (uint);

    /**
     * 某个地址的余额
     */
    function balanceOf(address account) external view returns (uint);

    /**
     * 转账
     * @param recipient 接收者
     * @param amount    转账金额
     */
    function transfer(address recipient, uint amount) external returns (bool);

    /**
     * 获取_spender可以从账户_owner中转出token的剩余数量
     */
    function allowance(address owner, address spender) external view returns (uint);

    /**
     * 批准_spender能从合约调用账户中转出数量为_value的token
     * @param spender 授权给的地址
     * @param amount  金额
     */
    function approve(address spender, uint amount) external returns (bool);

    /**
     * 代理转账函数，调用者代理代币持有者sender向指定地址recipient转账一定数量amount代币
        （用于允许合约代理某人转移token。条件是sender账户必须经过了approve）
     * @param sender    转账人
     * @param recipient 接收者
     * @param amount    转账金额
     */
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);

    /**
     * 发生转账时必须要触发的事件，transfer 和 transferFrom 成功执行时必须触发的事件
     */
    event Transfer(address indexed from, address indexed to, uint value);

    /**
     * 当函数approve 成功执行时必须触发的事件
     */
    event Approval(address indexed owner, address indexed spender, uint value);
}pragma solidity ^0.5.16;

import './SafeMath.sol';
import './Address.sol';
import './IERC20.sol';

/**
 * SafeERC20库，其内部函数用于安全外部ERC20合约转账相关操作
 */
library SafeERC20 {

    // 引入SafeMath安全数学运算库，避免数学运算整型溢出
    using SafeMath for uint;
    // 使用Address库中函数检查指定地址是否为合约地址
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint value) internal {
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }
    function callOptionalReturn(IERC20 token, bytes memory data) private {
        require(address(token).isContract(), "SafeERC20: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}pragma solidity ^0.5.16;

/**
 * SafeMath库定义如下函数用于安全数学运算
 */
library SafeMath {

    function add(uint a, uint b) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    function sub(uint a, uint b) internal pure returns (uint) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        require(b <= a, errorMessage);
        uint c = a - b;
        return c;
    }

    function mul(uint a, uint b) internal pure returns (uint) {
        if (a == 0) {
            return 0;
        }
        uint c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
    function div(uint a, uint b) internal pure returns (uint) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint c = a / b;

        return c;
    }
}