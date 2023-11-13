pragma solidity ^0.5.11;

pragma solidity ^0.5.11;

import "./ERC20.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

contract Token is Ownable, ERC20 {

    using SafeMath for uint;

    string public constant name = "Illuminat token";
    string public constant symbol = "LUM";
    uint public constant decimals = 18;

    uint public advisorsAmount;
    uint public bountyAmount;
    uint public teamAmount;

    address public depositAddress;
    uint private deployTime;
    uint private lockTime = 2 * 365 days;

    event PayService(string indexed _service, uint indexed _toDepositAddress);

    constructor() public {
        deployTime = now;

        advisorsAmount = 1000000 * 10 ** decimals;
        bountyAmount = 2000000 * 10 ** decimals;
        teamAmount = 15000000 * 10 ** decimals;

        _mint(address(this), 100000000 * 10 ** decimals);
    }

    function() external {
        revert();
    }

    function setDepositAddress(address _depositAddress) public onlyOwner {
        depositAddress = _depositAddress;
    }

    function payService(string memory service, address _to, uint amount) public {
        uint tenPercents = amount.div(10);
        transfer(depositAddress, tenPercents);
        _burn(msg.sender, tenPercents);
        transfer(_to, amount.sub(tenPercents.mul(2)));

        emit PayService(service, tenPercents);
    }

    function sendTokens(address[] memory _receivers, uint[] memory _amounts) public onlyOwner {
        require(_receivers.length == _amounts.length, "The length of the arrays must be equal");

        for (uint i = 0; i < _receivers.length; i++) {
            _transfer(address(this), _receivers[i], _amounts[i]);
        }
    }

    function transferTokens(address to, uint amount) public onlyOwner {
        _transfer(address(this), to, amount);
    }

    function sendTeamTokens(address teamAddress, uint amount) public onlyOwner {
        if(now < deployTime.add(lockTime)){
            require(teamAmount.sub(10000000*10**decimals) >= amount, "Not enough unlocked tokens amount");
        } else {
            require(teamAmount >= amount, "Not enough tokens amount");
        }
        teamAmount = teamAmount.sub(amount);
        _transfer(address(this), teamAddress, amount);
    }

    function sendAdvisorsTokens(address advisorsAddress, uint amount) public onlyOwner {
        if(now < deployTime.add(lockTime)){
            require(advisorsAmount.sub(650000*10**decimals) >= amount, "Not enough unlocked tokens amount");
        } else {
            require(advisorsAmount >= amount, "Not enough tokens amount");
        }
        advisorsAmount = advisorsAmount.sub(amount);
        _transfer(address(this), advisorsAddress, amount);
    }

    function sendBountyTokens(address bountyAddress, uint amount) public onlyOwner {
        require(bountyAmount >= amount, "Not enough tokens amount");
        bountyAmount = bountyAmount.sub(amount);
        _transfer(address(this), bountyAddress, amount);
    }
}pragma solidity ^0.5.11;

import "./IERC20.sol";
import "./SafeMath.sol";


contract ERC20 is IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 value) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, msg.sender, _allowances[account][msg.sender].sub(amount));
    }
}pragma solidity ^0.5.11;

interface IERC20 {

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}pragma solidity ^0.5.11;

contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}pragma solidity ^0.5.11;

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}