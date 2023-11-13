pragma solidity ^0.5.8;

pragma solidity ^0.5.0;

import "./BloodToken.sol";

contract TestToken is BloodToken {

    constructor()
    BloodToken("BLOOD", "BLOOD", 8, 40e9)
    public
    {
        mint(msg.sender, 20e9 * (10 ** uint256(decimals())));
    }
}pragma solidity ^0.5.0;

import "./Ownable.sol";
import "./Math.sol";
import "./ERC20.sol";
import "./ERC20Detailed.sol";
import "./LockAmount.sol";

contract BloodToken is ERC20, ERC20Detailed, LockAmount {
    using Math for uint256;

    uint256 private _maxSupply;
    
    constructor(string memory name, string memory symbol, uint8 decimals, uint256 maximumSupply) public ERC20Detailed(name, symbol, decimals) {
        _maxSupply = maximumSupply * (10 ** uint256(decimals));
    }
    
    /**
     * @dev 최대 공급량
     */
    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }
    
    /**
     * @dev 사용가능 잔액조회
     */
    function availableBalanceOf(address account) public view returns (uint256) {
        require(account != address(0), "BloodToken: address is the zero address");

        uint256 lockedAmount = getLockedAmountOfLockTable(account);
        
        // 현재 잔액 락금액을 뺌, 락금액이 더 큰 경우 0
        if (_balances[account] < lockedAmount) return 0;
        
        return _balances[account].sub(lockedAmount);
    }
    
    /**
     * @dev ADMIN 발행
     */
    function mint(address account, uint256 amount) onlyOwner public returns (bool) { 
        require(_totalSupply.add(amount) <= _maxSupply, "BloodToken: Issued exceeds maximum supply");
        
        _mint(account, amount);
        return true;
    }
    
    /**
     * @dev ADMIN 소각
     */
    function burn(uint256 amount) onlyOwner public returns (bool){
        require(_balances[_msgSender()] >= amount, "BloodToken: destruction amount exceeds balance");
        
        _burn(_msgSender(), amount);
        return true;
    }

    /**
     * @dev ERC20 _transfer() 재정의
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "BloodToken: transfer from the zero address");
        require(recipient != address(0), "BloodToken: transfer to the zero address");
        
        uint256 lockedAmount = getLockedAmountOfLockTable(sender);
        require(_balances[sender].sub(amount) >= lockedAmount, "BloodToken: exceeded amount available");

        _balances[sender] = _balances[sender].sub(amount, "BloodToken: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }
    
    /**
     * @dev 락금액조회
     */
    function getLockedAmount(address account) public view returns (uint256) {
        require(account != address(0), "BloodToken: address is the zero address");

        uint256 lockedAmount = getLockedAmountOfLockTable(account);

        // 락금액과 현재 잔액을 비교하여 작은 값을 출력
        return Math.min(lockedAmount, _balances[account]);
    }
}pragma solidity ^0.5.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor () public { }
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}pragma solidity ^0.5.0;

import "./Context.sol";
import "./IERC20.sol";
import "./SafeMath.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 */
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) internal _balances;

    mapping (address => mapping (address => uint256)) internal _allowances;

    uint256 internal _totalSupply;

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Mint(account, amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
        emit Burn(account, amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     *
     * See {_burn} and {_approve}.
     */
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "ERC20: burn amount exceeds allowance"));
    }
}pragma solidity ^0.5.0;

import "./IERC20.sol";

/**
 * @dev Optional functions from the ERC20 standard.
 */
contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for `name`, `symbol`, and `decimals`. All three of
     * these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name, string memory symbol, uint8 decimals) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}pragma solidity ^0.5.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    event Burn(address account, uint256 amount);
    
    event Mint(address account, uint256 amount);
}pragma solidity ^0.5.0;

import "./Ownable.sol";

contract LockAmount is Ownable {
    /**
     * @dev 락정보 정의 (시간, 락금액)
     */
    struct LockInfo {
        uint256 timestamp;
        uint256 lockedAmount;
    }
    
    /**
     * @dev 락정보
     */
    mapping (address => string) internal _accountLockTypes;
    mapping (string => LockInfo[]) internal _lockInfoTable;
    
    /**
     * @dev 이벤트
     */
    event SetAccountLockType(address account, string lockType);
    event AddLockInfo(string  lockType, uint256 timestamp, uint256 lockAmount);
    event RemoveLockInfo(string lockType, uint256 timestamp);
    event ClearLockInfo(string lockType);
    
    /**
     * @dev 락테이블에서 현재시간의 락잔액조회
     */
    function getLockedAmountOfLockTable(address account) public view returns (uint256) {
        string memory lockType = _accountLockTypes[account];
        if (bytes(lockType).length != 0) {
            // 락금액 검색
            LockInfo[] memory array = _lockInfoTable[lockType];
            for (uint256 i = 0; i < array.length; i++) {
                if (array[i].timestamp >= block.timestamp) {
                    return array[i].lockedAmount;
                }
            }
        }
        return 0;
    }
    
    function getblockTimestamp() public view returns (uint256) {
        return block.timestamp;
    }
    
    /**
     * @dev ADMIN 락타입 설정
     */
    function setAccountLockType(address account, string memory lockType) onlyOwner public returns (bool) {
        _accountLockTypes[account] = lockType;
        emit SetAccountLockType(account, lockType);
        return true;
    }
    
    /**
     * @dev 락타입
     */
    function getAddressLockType (address account) public view returns (string memory) {
        return _accountLockTypes[account];
    }
    
    /**
     * @dev ADMIN 락정보 추가
     */
    function addLockInfo(string memory lockType, uint256 timestamp, uint256 lockAmount) onlyOwner public returns (bool) {
        require(bytes(lockType).length != 0, "lockType must be not empty");

        // 락정보 인덱스 검색
        uint256 index = 0;
        LockInfo[] storage array = _lockInfoTable[lockType];
        for (index = 0; index < array.length; index++) {
            if (array[index].timestamp < timestamp) continue;
            if (array[index].timestamp > timestamp) break;

            if (index - 1 < array.length && array[index - 1].lockedAmount < lockAmount) return false;          
            if (index + 1 < array.length && array[index + 1].lockedAmount > lockAmount) return false;
            
            array[index].lockedAmount = lockAmount;
            
            emit AddLockInfo(lockType, timestamp, lockAmount);
            return true;
        }
        
        if (index - 1 < array.length && array[index - 1].lockedAmount < lockAmount) return false;          
        if (index < array.length && array[index].lockedAmount > lockAmount) return false;
        
        // 락정보 삽입
        array.length++;
        for (uint256 i = array.length - 1; i > index; i--) {
            array[i] = array[i - 1];
        }
        array[index] = LockInfo(timestamp, lockAmount);
        
        emit AddLockInfo(lockType, timestamp, lockAmount);
        return true;
    }
    
    /**
     * @dev ADMIN 락정보 삭제
     */
    function removeLockInfo(string memory lockType, uint256 timestamp) onlyOwner public returns (bool) {
        require(bytes(lockType).length != 0, "lockType must be not empty");

        LockInfo[] storage array = _lockInfoTable[lockType];
        if (array.length == 0) return false;

        // 락정보 인덱스 검색
        uint256 index = 2 ** 256 - 1;
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i].timestamp == timestamp) {
                index = i;
                break;
            }
        }
        
        if (index == 2 ** 256 - 1) return false;

        // 락정보 삭제
        for (uint256 j = index; j < array.length - 1; j++) {
            array[j] = array[j + 1];
        }
        delete array[array.length - 1];
        array.length--;
        
        emit RemoveLockInfo(lockType, timestamp);
        return true;
    }

    /**
     * @dev ADMIN 락정보 클리어
     */
    function clearLockInfo(string memory lockType) onlyOwner public returns (bool) {
        require(bytes(lockType).length != 0, "lockType must be not empty");

        LockInfo[] storage array = _lockInfoTable[lockType];
        if (array.length == 0) return false;
        
        // 락정보 클리어
        for (uint256 i = 0; i < array.length; i++) {
            delete array[i];
        }
        array.length = 0;
        
        emit ClearLockInfo(lockType);
        return true;
    }

    /**
     * @dev 락타입별 정보 개수 조회
     */
    function getLockInfoCount(string memory lockType) public view returns (uint256) {
        return _lockInfoTable[lockType].length;
    }

    /**
     * @dev 락타입별 인덱스로 시간 조회
     */
    function getLockInfoAtIndex(string memory lockType, uint256 index) public view returns (uint256, uint256) {
        return (_lockInfoTable[lockType][index].timestamp, _lockInfoTable[lockType][index].lockedAmount);
    }
    
    /**
     * @dev 락타입별 시간, 락금액 조회
     */
    function getLockInfo(string memory lockType) public view returns (uint256[] memory, uint256[] memory) {
        uint256 index = 0;
        
        LockInfo[] memory array = _lockInfoTable[lockType];
        uint256[] memory timestamps = new uint256[](array.length);
        uint256[] memory lockedAmounts = new uint256[](array.length);
        
        for (index = 0; index < array.length; index++) {
            timestamps[index] = array[index].timestamp;
            lockedAmounts[index] = array[index].lockedAmount;
        }
        
        return (timestamps, lockedAmounts);
    }
}pragma solidity ^0.5.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}pragma solidity >=0.4.25 <0.6.0;

contract Migrations {
  address public owner;
  uint public last_completed_migration;

  modifier restricted() {
    if (msg.sender == owner) _;
  }

  constructor() public {
    owner = msg.sender;
  }

  function setCompleted(uint completed) public restricted {
    last_completed_migration = completed;
  }

  function upgrade(address new_address) public restricted {
    Migrations upgraded = Migrations(new_address);
    upgraded.setCompleted(last_completed_migration);
  }
}pragma solidity ^0.5.0;

import "./Context.sol";
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () public {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}pragma solidity ^0.5.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
     * @dev Get it via `npm install @openzeppelin/contracts@next`.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
     * @dev Get it via `npm install @openzeppelin/contracts@next`.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
     * @dev Get it via `npm install @openzeppelin/contracts@next`.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}