pragma solidity ^0.5.0;

pragma solidity ^0.5.0;

import "./EtheleToken.sol";

/**
 * Generator of all 7 Etherem Elements (Ethele) ERC20 Token Contracts.
 * There are 5 Ethele Elements Tokens: Fire, Earth, Metal, Water, Wood.
 * There are 2 Ethele YinYang Tokens: Yin, Yang.
 */
contract EtheleGenerator {
    address private _fire;
    address private _earth;
    address private _metal;
    address private _water;
    address private _wood;
    address private _yin;
    address private _yang;

    uint256 private _step; // The deploy process has to be completed in steps, because the gas needed is too large.

    uint256 private constant LAUNCH_TIME = 1565438400; // Ethele Token address will only be able to be created after mainnet launch.

    // Set step to 0. Step function can be called after launch time for creation of all 7 Ethele Tokens
    // and assignment of Ethele token transmuteSources and allowBurnsFrom for interaction between the contracts.
    constructor() public {
        _step = 0;
    }

    function getLaunchTime() public pure returns (uint256) {
        return LAUNCH_TIME;
    }

    function step() public {
        require(_step <= 3 && LAUNCH_TIME < block.timestamp);

        if (_step == 0) {
            _fire = address(new EtheleToken("Ethele Fire", "EEFI"));
            _earth = address(new EtheleToken("Ethele Earth", "EEEA"));
        } else if (_step == 1) {
            _metal = address(new EtheleToken("Ethele Metal", "EEME"));
            _water = address(new EtheleToken("Ethele Water", "EEWA"));
        } else if (_step == 2) {
            _wood = address(new EtheleToken("Ethele Wood", "EEWO"));
            _yin = address(new EtheleToken("Ethele Yin", "EEYI"));
        } else if (_step == 3) {
            _yang = address(new EtheleToken("Ethele Yang", "EEYA"));
            // Each of the 5 elements has 2 elements which create it. 
            EtheleToken(_fire).setTransmuteSources12(_metal, _wood);
            EtheleToken(_earth).setTransmuteSources12(_water, _fire);
            EtheleToken(_metal).setTransmuteSources12(_wood, _earth);
            EtheleToken(_water).setTransmuteSources12(_fire, _metal);
            EtheleToken(_wood).setTransmuteSources12(_earth, _water);
            
            // 1 Yin and 1 Yang creates 1 of any element of choice.
            EtheleToken(_fire).setTransmuteSources34(_yin, _yang);
            EtheleToken(_earth).setTransmuteSources34(_yin, _yang);
            EtheleToken(_metal).setTransmuteSources34(_yin, _yang);
            EtheleToken(_water).setTransmuteSources34(_yin, _yang);
            EtheleToken(_wood).setTransmuteSources34(_yin, _yang);

            // Allow each element to burn the components that are transmuted to it.
            EtheleToken(_metal).allowBurnsFrom(_fire);
            EtheleToken(_wood).allowBurnsFrom(_fire);
            EtheleToken(_water).allowBurnsFrom(_earth);
            EtheleToken(_fire).allowBurnsFrom(_earth);
            EtheleToken(_wood).allowBurnsFrom(_metal);
            EtheleToken(_earth).allowBurnsFrom(_metal);
            EtheleToken(_fire).allowBurnsFrom(_water);
            EtheleToken(_metal).allowBurnsFrom(_water);
            EtheleToken(_earth).allowBurnsFrom(_wood);
            EtheleToken(_water).allowBurnsFrom(_wood);

            // All 5 elements are allowed to burn yin and yang.
            // Because Yin + Yang can transmute to any of the 5 elements. 
            EtheleToken(_yin).allowBurnsFrom(_fire);
            EtheleToken(_yin).allowBurnsFrom(_earth);
            EtheleToken(_yin).allowBurnsFrom(_metal);
            EtheleToken(_yin).allowBurnsFrom(_water);
            EtheleToken(_yin).allowBurnsFrom(_wood);
            EtheleToken(_yang).allowBurnsFrom(_fire);
            EtheleToken(_yang).allowBurnsFrom(_earth);
            EtheleToken(_yang).allowBurnsFrom(_metal);
            EtheleToken(_yang).allowBurnsFrom(_water);
            EtheleToken(_yang).allowBurnsFrom(_wood);
        }

        _step += 1;
    }

    function getStep() public view returns (uint256) {
        return _step;
    }
    function fire() public view returns (address) {
        return _fire;
    }
    function earth() public view returns (address) {
        return _earth;
    }
    function metal() public view returns (address) {
        return _metal;
    }
    function water() public view returns (address) {
        return _water;
    }
    function wood() public view returns (address) {
        return _wood;
    }
    function yin() public view returns (address) {
        return _yin;
    }
    function yang() public view returns (address) {
        return _yang;
    }
}pragma solidity ^0.5.0;

import "./IERC20.sol";
import "./SafeMath.sol";

/**
 * @dev Implementation of the `IERC20` interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using `_mint`.
 * For a generic mechanism see `ERC20Mintable`.
 *
 * *For a detailed writeup see our guide [How to implement supply
 * mechanisms](https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226).*
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an `Approval` event is emitted on calls to `transferFrom`.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard `decreaseAllowance` and `increaseAllowance`
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See `IERC20.approve`.
 */
contract ERC20 is IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    /**
     * @dev See `IERC20.totalSupply`.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See `IERC20.balanceOf`.
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See `IERC20.transfer`.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev See `IERC20.allowance`.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See `IERC20.approve`.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev See `IERC20.transferFrom`.
     *
     * Emits an `Approval` event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of `ERC20`;
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `value`.
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in `IERC20.approve`.
     *
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in `IERC20.approve`.
     *
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to `transfer`, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a `Transfer` event.
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

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a `Transfer` event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

     /**
     * @dev Destoys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a `Transfer` event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an `Approval` event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev Destoys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     *
     * See `_burn` and `_approve`.
     */
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, msg.sender, _allowances[account][msg.sender].sub(amount));
    }
}pragma solidity ^0.5.0;

import "./ERC20.sol";
import "./SafeMath.sol";

/**
 * Implementation for Etherem Elements (Ethele) ERC20 Token.
 * Enables the token to be lock-harvested.
 * Contains the functions for Transmutation of other Ethele tokens to this token. (Only for 5 elements, not Yin and Yang)
 */
contract EtheleToken is ERC20 {
    using SafeMath for uint256;

    string private _name;
    string private _symbol;

    address private _creator;
    // Ethele token Transmute process:
    // By burning one token each of transmuteSource1 and transmuteSource2, one token (of this contract) can be minted.
    // By burning one token each of transmuteSource3 and transmuteSource4, one token (of this contract) can be minted.
    // Only applies to the 5 elements, not Yin and Yang.
    address private _transmuteSource1;
    address private _transmuteSource2;
    address private _transmuteSource3;
    address private _transmuteSource4;
    mapping (address => bool) private _allowBurnsFrom; // Address mapped to true are allowed to burn this contract's tokens

    uint256 private _totalLocked;
    mapping (address => uint256) private _lockedBalance;
    mapping (address => uint256) private _harvestStartPeriod;
    mapping (address => uint256) private _unlockTime;

    uint256 private constant PERIOD_LENGTH = 1 days; 
    uint256 private constant MINT_AMOUNT = 100000 ether; // 'ether' is equivalent to 10^18. This is used since this token has same number of decimals as ETH.
    uint256 private _currentPeriod;
    uint256 private _contractStartTime;
    uint256[] private _cumulTokenPerEth; // Across periods, tracks cumulative harvestable amount of this token per each Eth locked.

    constructor(
        string memory name,
        string memory symbol
    ) public {
         // only creator is allowed to set transmuteSources and burner addresses. 
         // The creator is the EtheleGenerator contract.
        _creator = msg.sender;

        _name = name;
        _symbol = symbol;

        _currentPeriod = 1;
        _cumulTokenPerEth.push(0);
        _contractStartTime = block.timestamp;
    }


    function name() public view returns (string memory) {
        return _name;
    }
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    function decimals() public pure returns (uint8) {
        return 18;
    }
    function getCreator() public view returns (address) {
    	return _creator;
    }

    function getTransmuteSource1() public view returns (address) {
		return _transmuteSource1;
    }
    function getTransmuteSource2() public view returns (address) {
    	return _transmuteSource2;
    }
    function getTransmuteSource3() public view returns (address) {
    	return _transmuteSource3;
    }
    function getTransmuteSource4() public view returns (address) {
    	return _transmuteSource4;
    }
    function getAllowBurnsFrom(address addr) public view returns (bool) {
    	return _allowBurnsFrom[addr];
    }

    function getTotalLocked() public view returns (uint256) {
    	return _totalLocked;
    }
    function getLockedBalance(address addr) public view returns (uint256) {
    	return _lockedBalance[addr];
    }    
    function getHarvestStartPeriod(address addr) public view returns (uint256) {
    	return _harvestStartPeriod[addr];
    }    
    function getUnlockTime(address addr) public view returns (uint256) {
    	return _unlockTime[addr];
    }
    // convenience function for checking how many tokens an address can harvest.
    // some complexity comes from the fact that _currentPeriod may not reflect the intended current period at this point in time.
    function getHarvestableAmount(address addr) public view returns (uint256) {
        uint256 intendedPeriod = (block.timestamp).sub(_contractStartTime).div(PERIOD_LENGTH).add(1);
        uint256 harvestStartPeriod = _harvestStartPeriod[addr];
        uint256 lockedBalance = _lockedBalance[addr];

        if (harvestStartPeriod >= intendedPeriod.sub(1) ||
            lockedBalance == 0) {
            return 0;
        }
        else {
            uint256 harvestableTokenPerEth = MINT_AMOUNT.mul(1 ether).div(_totalLocked);
            uint256 harvestableAmount;
             // handle edge case where harvestStartPeriod == currentPeriod
            if (harvestStartPeriod == _currentPeriod) {
                // In this case we count the number of harvestable periods as the difference between harvestStartPeriod and (intendedPeriod-1).
                uint256 periodDiff = intendedPeriod.sub(1).sub(harvestStartPeriod);
                harvestableAmount = periodDiff
                                          .mul(harvestableTokenPerEth)
                                          .mul(lockedBalance)
                                          .div(1 ether);
            } else {
                // need to take into account the additional harvested amount for period that has not yet been updated.
                uint256 periodDiff = intendedPeriod.sub(_currentPeriod);
                uint256 tokenPerEthInPeriodDiff = harvestableTokenPerEth.mul(periodDiff);

                // compute harvestable amount
                harvestableAmount = tokenPerEthInPeriodDiff
                                            .add(_cumulTokenPerEth[_currentPeriod.sub(1)])
                                            .sub(_cumulTokenPerEth[harvestStartPeriod])
                                            .mul(lockedBalance)
                                            .div(1 ether);
            }

            return harvestableAmount;
        }
    }

    function getPeriodLength() public pure returns (uint256) {
        return PERIOD_LENGTH; 
    }
    function getMintAmount() public pure returns (uint256) {
        return MINT_AMOUNT; 
    }
    function getCurrentPeriod() public view returns (uint256) {
        return _currentPeriod; 
    }
    function getContractStartTime() public view returns (uint256) {
        return _contractStartTime; 
    }
    function getCumulTokenPerEth(uint256 period) public view returns (uint256) {
    	return _cumulTokenPerEth[period];
    }

    // any address can burn their own tokens.
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
    function burnFrom(address account, uint256 amount) public {
    	// special case for whitelisted burner addresses to bypass need for approval to burn.
        // this special right is only granted to other Ethele tokens.
    	if (_allowBurnsFrom[msg.sender]) {
    		_burn(account, amount);
    	} else {
        	_burnFrom(account, amount);
    	}
    }

    function setTransmuteSources12(address transmuteSource1, address transmuteSource2) public {
        require(msg.sender == _creator);
        _transmuteSource1 = transmuteSource1;
        _transmuteSource2 = transmuteSource2;
    } 

    function setTransmuteSources34(address transmuteSource3, address transmuteSource4) public {
        require(msg.sender == _creator);
        _transmuteSource3 = transmuteSource3;
        _transmuteSource4 = transmuteSource4;
    } 

    function allowBurnsFrom(address burner) public {
    	require(msg.sender == _creator);
    	_allowBurnsFrom[burner] = true;
    }


    // transmute will mint this token by consuming its transmuteSource tokens.
    function transmute(uint256 amount, uint256 transmuteType) public {
    	require(transmuteType == 0 || transmuteType == 1, "EtheleToken: Transmute type should be 0 or 1.");
    	if (transmuteType == 0) {
			require(_transmuteSource1 != address(0) && _transmuteSource2 != address(0), "EtheleToken: Cannot transmute this.");
    		EtheleToken(_transmuteSource1).burnFrom(msg.sender, amount);
    		EtheleToken(_transmuteSource2).burnFrom(msg.sender, amount);
    		_mint(msg.sender, amount);
		} else if (transmuteType == 1) {
			require(_transmuteSource3 != address(0) && _transmuteSource4 != address(0), "EtheleToken: Cannot transmute this.");
    		EtheleToken(_transmuteSource3).burnFrom(msg.sender, amount);
    		EtheleToken(_transmuteSource4).burnFrom(msg.sender, amount);
    		_mint(msg.sender, amount);
		}
    }

    // Updates the period of this token by 'steps' number of periods.
    // Put steps = -1 for unlimited steps
    function updatePeriod(int256 steps) public {
    	uint256 intendedPeriod = (block.timestamp).sub(_contractStartTime).div(PERIOD_LENGTH).add(1);
    	if (_currentPeriod < intendedPeriod) {
			uint256 harvestableTokenPerEth;
    		if (_totalLocked == 0) {
    			harvestableTokenPerEth = 0;
    		} else {
    			harvestableTokenPerEth = MINT_AMOUNT.mul(1 ether).div(_totalLocked);
    		}

    		// update for all periods
    		while (_currentPeriod < intendedPeriod && steps != 0) {
    			_cumulTokenPerEth.push(_cumulTokenPerEth[_currentPeriod-1].add(harvestableTokenPerEth));
    			_currentPeriod += 1;
    			steps -= 1;
    		}
    	}
    }

    // Lock up ETH so that you can harvest Ethele Tokens.
    // To lock, you must not have any ETH locked. 
    // This is because the computation for amount harvested cannot handle varying amounts 
    // of locked ETH across periods. 
    function lock() public payable {
    	require(_lockedBalance[msg.sender] == 0, "EtheleToken: To lock, you must not have any existing locked ETH.");
    	updatePeriod(-1);

    	_totalLocked = _totalLocked.add(msg.value);
    	_lockedBalance[msg.sender] = msg.value;
    	_harvestStartPeriod[msg.sender] = _currentPeriod;
    	_unlockTime[msg.sender] = block.timestamp.add(PERIOD_LENGTH);
    }

    function harvest() public {
    	require(_lockedBalance[msg.sender] > 0, "EtheleToken: Require locked balance to harvest.");
    	updatePeriod(-1);

    	require(_harvestStartPeriod[msg.sender] < _currentPeriod-1, "EtheleToken: Nothing to harvest - Lock start period should be before previous currentPeriod.");
    	uint256 amountHarvested = _cumulTokenPerEth[_currentPeriod-1]
    							.sub(_cumulTokenPerEth[_harvestStartPeriod[msg.sender]])
    							.mul(_lockedBalance[msg.sender])
    							.div(1 ether);
    	_harvestStartPeriod[msg.sender] = _currentPeriod-1;
    	_mint(msg.sender, amountHarvested);	
    }

    function unlock() public {
    	require(_lockedBalance[msg.sender] > 0, "EtheleToken: Require locked balance to unlock.");
    	updatePeriod(-1);

    	require(_unlockTime[msg.sender] < block.timestamp, "EtheleToken: Minimum lock time not yet reached.");
    	uint256 amount = _lockedBalance[msg.sender];
    	_lockedBalance[msg.sender] = 0;
    	_totalLocked = _totalLocked.sub(amount);
    	msg.sender.transfer(amount);
    }
}pragma solidity ^0.5.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see `ERC20Detailed`.
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
     * Emits a `Transfer` event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through `transferFrom`. This is
     * zero by default.
     *
     * This value changes when `approve` or `transferFrom` are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * > Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an `Approval` event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
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
     * a call to `approve`. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
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
        require(b <= a, "SafeMath: subtraction overflow");
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
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
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
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
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
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}