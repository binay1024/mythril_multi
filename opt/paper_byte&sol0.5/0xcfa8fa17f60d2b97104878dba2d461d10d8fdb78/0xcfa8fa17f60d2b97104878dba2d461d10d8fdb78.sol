pragma solidity ^0.5.8;

pragma solidity ^0.5.8;

import "./SafeMath.sol";
import "./BaseToken.sol";

contract EggToken is BaseToken
{
    using SafeMath for uint256;

    // MARK: strings for error message.
    string constant public ERROR_NOT_MANDATED = 'Reason: Not mandated.';

    // MARK: for token information.
    string constant public name    = 'Egg';
    string constant public symbol  = 'EGG';
    string constant public version = '1.0.0';

    mapping (address => bool) public mandates;

    // MARK: events
    event TransferByMandate(address indexed from, address indexed to, uint256 value);
    event ReferralDrop(address indexed from, address indexed to1, uint256 value1, address indexed to2, uint256 value2);
    event UpdatedMandate(address indexed from, bool mandate);

    constructor() public
    {
        totalSupply = 3000000000 * E18;
        balances[msg.sender] = totalSupply;
    }

    // MARK: functions for view data
    function transferByMandate(address _from, address _to, uint256 _value, address _sale, uint256 _fee) external onlyWhenNotStopped onlyOwner returns (bool)
    {
        require(_from != address(0), ERROR_ADDRESS_NOT_VALID);
        require(_sale != address(0), ERROR_ADDRESS_NOT_VALID);
        require(_value > 0, ERROR_VALUE_NOT_VALID);
        require(balances[_from] >= _value + _fee, ERROR_BALANCE_NOT_ENOUGH);
        require(mandates[_from], ERROR_NOT_MANDATED);
        require(!isLocked(_from, _value), ERROR_LOCKED);

        balances[_from] = balances[_from].sub(_value + _fee);
        balances[_to]  = balances[_to].add(_value);

        if(_fee > 0)
        {
            balances[_sale] = balances[_sale].add(_fee);
        }

        emit TransferByMandate(_from, _to, _value);
        return true;
    }

    function referralDrop(address _to1, uint256 _value1, address _to2, uint256 _value2, address _sale, uint256 _fee) external onlyWhenNotStopped returns (bool)
    {
        require(_to1 != address(0), ERROR_ADDRESS_NOT_VALID);
        require(_to2 != address(0), ERROR_ADDRESS_NOT_VALID);
        require(_sale != address(0), ERROR_ADDRESS_NOT_VALID);
        require(balances[msg.sender] >= _value1 + _value2 + _fee);
        require(!isLocked(msg.sender, _value1 + _value2 + _fee), ERROR_LOCKED);

        balances[msg.sender] = balances[msg.sender].sub(_value1 + _value2 + _fee);

        if(_value1 > 0)
        {
            balances[_to1] = balances[_to1].add(_value1);
        }

        if(_value2 > 0)
        {
            balances[_to2] = balances[_to2].add(_value2);
        }

        if(_fee > 0)
        {
            balances[_sale] = balances[_sale].add(_fee);
        }

        emit ReferralDrop(msg.sender, _to1, _value1, _to2, _value2);
        return true;
    }

    // MARK: utils for transfer authentication
    function updateMandate(bool _value) external onlyWhenNotStopped returns (bool)
    {
        mandates[msg.sender] = _value;
        emit UpdatedMandate(msg.sender, _value);
        return true;
    }
}pragma solidity ^0.5.8;

import "./SafeMath.sol";
import "./Ownable.sol";

contract BaseToken is Ownable
{
    using SafeMath for uint256;

    // MARK: strings for error message.
    string constant public ERROR_APPROVED_BALANCE_NOT_ENOUGH = 'Reason: Approved balance is not enough.';
    string constant public ERROR_BALANCE_NOT_ENOUGH          = 'Reason: Balance is not enough.';
    string constant public ERROR_LOCKED                      = 'Reason: Locked';
    string constant public ERROR_ADDRESS_NOT_VALID           = 'Reason: Address is not valid.';
    string constant public ERROR_ADDRESS_IS_SAME             = 'Reason: Address is same.';
    string constant public ERROR_VALUE_NOT_VALID             = 'Reason: Value must be greater than 0.';
    string constant public ERROR_NO_LOCKUP                   = 'Reason: There is no lockup.';
    string constant public ERROR_DATE_TIME_NOT_VALID         = 'Reason: Datetime must grater or equals than zero.';

    // MARK: for token information.
    uint256 constant public E18                  = 1000000000000000000;
    uint256 constant public decimals             = 18;
    uint256 public totalSupply;

    struct Lock {
        uint256 amount;
        uint256 expiresAt;
    }

    mapping (address => uint256) public balances;
    mapping (address => mapping ( address => uint256 )) public approvals;
    mapping (address => Lock[]) public lockup;


    // MARK: events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event Locked(address _who, uint256 _amount, uint256 _time);
    event Unlocked(address _who);
    event Burn(address indexed from, uint256 indexed value);

    constructor() public
    {
        balances[msg.sender] = totalSupply;
    }

    // MARK: functions for view data
    function balanceOf(address _who) view public returns (uint256)
    {
        return balances[_who];
    }

    function lockedBalanceOf(address _who) view public returns (uint256)
    {
        require(_who != address(0), ERROR_ADDRESS_NOT_VALID);

        uint256 lockedBalance = 0;
        if(lockup[_who].length > 0)
        {
            Lock[] storage locks = lockup[_who];

            uint256 length = locks.length;
            for (uint i = 0; i < length; i++)
            {
                if (now < locks[i].expiresAt)
                {
                    lockedBalance = lockedBalance.add(locks[i].amount);
                }
            }
        }

        return lockedBalance;
    }

    function allowance(address _owner, address _spender) view external returns (uint256)
    {
        return approvals[_owner][_spender];
    }

    // true: _who can transfer token
    // false: _who can't transfer token
    function isLocked(address _who, uint256 _value) view public returns(bool)
    {
        uint256 lockedBalance = lockedBalanceOf(_who);
        uint256 balance = balanceOf(_who);

        if(lockedBalance <= 0)
        {
            return false;
        }
        else
        {
            return !(balance > lockedBalance && balance.sub(lockedBalance) >= _value);
        }
    }

    // MARK: functions for token transfer
    // For holder registration, the first transaction by each address will probably consume about 2.5 times more gas.
    function transfer(address _to, uint256 _value) external onlyWhenNotStopped returns (bool)
    {
        require(_to != address(0));
        require(balances[msg.sender] >= _value, ERROR_BALANCE_NOT_ENOUGH);
        require(!isLocked(msg.sender, _value), ERROR_LOCKED);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) external onlyWhenNotStopped returns (bool)
    {
        require(_from != address(0), ERROR_ADDRESS_NOT_VALID);
        require(_to != address(0), ERROR_ADDRESS_NOT_VALID);
        require(_value > 0, ERROR_VALUE_NOT_VALID);
        require(balances[_from] >= _value, ERROR_BALANCE_NOT_ENOUGH);
        require(approvals[_from][msg.sender] >= _value, ERROR_APPROVED_BALANCE_NOT_ENOUGH);
        require(!isLocked(_from, _value), ERROR_LOCKED);

        approvals[_from][msg.sender] = approvals[_from][msg.sender].sub(_value);
        balances[_from] = balances[_from].sub(_value);
        balances[_to]  = balances[_to].add(_value);

        emit Transfer(_from, _to, _value);
        return true;
    }

    function transferWithLock(address _to, uint256 _value, uint256 _time) onlyOwner external returns (bool)
    {
        require(balances[msg.sender] >= _value, ERROR_BALANCE_NOT_ENOUGH);

        lock(_to, _value, _time);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    // MARK: utils for transfer authentication
    function approve(address _spender, uint256 _value) external onlyWhenNotStopped returns (bool)
    {
        require(_spender != address(0), ERROR_VALUE_NOT_VALID);
        require(balances[msg.sender] >= _value, ERROR_BALANCE_NOT_ENOUGH);
        require(msg.sender != _spender, ERROR_ADDRESS_IS_SAME);

        approvals[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    // MARK: utils for amount of token
    // Lock up token until specific date time.
    function lock(address _who, uint256 _value, uint256 _dateTime) onlyOwner public
    {
        require(_who != address (0), ERROR_VALUE_NOT_VALID);
        require(_value > 0, ERROR_VALUE_NOT_VALID);

        lockup[_who].push(Lock(_value, _dateTime));
        emit Locked(_who, _value, _dateTime);
    }

    function unlock(address _who) onlyOwner external
    {
        require(lockup[_who].length > 0, ERROR_NO_LOCKUP);
        delete lockup[_who];
        emit Unlocked(_who);
    }

    function burn(uint256 _value) external
    {
        require(balances[msg.sender] >= _value, ERROR_BALANCE_NOT_ENOUGH);
        require(_value > 0, ERROR_VALUE_NOT_VALID);

        balances[msg.sender] = balances[msg.sender].sub(_value);

        totalSupply = totalSupply.sub(_value);

        emit Burn(msg.sender, _value);
    }

    // destruct for only after token upgrade
    function close() onlyOwner public
    {
        selfdestruct(msg.sender);
    }
}pragma solidity ^0.5.8;

contract Ownable
{
    string constant public ERROR_NO_HAVE_PERMISSION = 'Reason: No have permission.';
    string constant public ERROR_IS_STOPPED         = 'Reason: Is stopped.';
    string constant public ERROR_ADDRESS_NOT_VALID  = 'Reason: Address is not valid.';

    bool private stopped;
    address private _owner;
    address[] public _allowed;

    event Stopped();
    event Started();
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Allowed(address indexed _address);
    event RemoveAllowed(address indexed _address);

    constructor () internal
    {
        stopped = false;
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view returns (address)
    {
        return _owner;
    }

    modifier onlyOwner()
    {
        require(isOwner(), ERROR_NO_HAVE_PERMISSION);
        _;
    }

    modifier onlyAllowed()
    {
        require(isAllowed() || isOwner(), ERROR_NO_HAVE_PERMISSION);
        _;
    }

    modifier onlyWhenNotStopped()
    {
        require(!isStopped(), ERROR_IS_STOPPED);
        _;
    }

    function isOwner() public view returns (bool)
    {
        return msg.sender == _owner;
    }

    function isAllowed() public view returns (bool)
    {
        uint256 length = _allowed.length;

        for(uint256 i=0; i<length; i++)
        {
            if(_allowed[i] == msg.sender)
            {
                return true;
            }
        }

        return false;
    }

    function transferOwnership(address newOwner) external onlyOwner
    {
        _transferOwnership(newOwner);
    }

    function allow(address _target) external onlyOwner returns (bool)
    {
        uint256 length = _allowed.length;

        for(uint256 i=0; i<length; i++)
        {
            if(_allowed[i] == _target)
            {
                return true;
            }
        }

        _allowed.push(_target);

        emit Allowed(_target);

        return true;
    }

    function removeAllowed(address _target) external onlyOwner returns (bool)
    {
        uint256 length = _allowed.length;

        for(uint256 i=0; i<length; i++)
        {
            if(_allowed[i] == _target)
            {
                if(i < length - 1)
                {
                    _allowed[i] = _allowed[length-1];
                    delete _allowed[length-1];
                }
                else
                {
                    delete _allowed[i];
                }

                _allowed.length--;

                emit RemoveAllowed(_target);

                return true;
            }
        }

        return true;
    }

    function isStopped() public view returns (bool)
    {
        if(isOwner() || isAllowed())
        {
            return false;
        }
        else
        {
            return stopped;
        }
    }

    function stop() public onlyOwner
    {
        _stop();
    }

    function start() public onlyOwner
    {
        _start();
    }

    function _transferOwnership(address newOwner) internal
    {
        require(newOwner != address(0), ERROR_ADDRESS_NOT_VALID);
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function _stop() internal
    {
        emit Stopped();
        stopped = true;
    }

    function _start() internal
    {
        emit Started();
        stopped = false;
    }
}pragma solidity ^0.5.8;

/**
 * @title SafeMath
 * @dev Unsigned math operations with safety checks that revert on error
 */
library SafeMath {
    /**
    * @dev Multiplies two unsigned integers, reverts on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
    * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
    * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
    * @dev Adds two unsigned integers, reverts on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
    * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}