pragma solidity ^0.6.12;

/*
@website https://boogie.finance
@authors Boogie
*/
pragma solidity ^0.6.12;

import './SafeMath.sol';
import './SafeERC20.sol';
import './IERC20.sol';
import './BOOGIE.sol';
import './Bar.sol';

//250k tokens are trustlessly minted at Bar and then sent here to be distributed as referral/recruitment incentives
contract Referral {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // The BOOGIE TOKEN!
    BOOGIE public boogie;
     // The Bar contract
    Bar public bar;

    // Max number of people that can be referred
    // Referral rewards are limited by the # of tokens sent to this contract anyway
    // Also, not having a max referral # prevents people from signing up and never claiming to prevent others from claiming rewards
    // It is possible that the contract could run dry, but the website will have a check for that
    //uint256 internal constant MAX_REFERRALS = 2500;
    // Reward for being referred by someone
    uint256 internal constant REFERRAL_REWARD = 50 * 10**18;
    // Commission reward for recruiting people
    uint256 internal constant COMMISSION_REWARD = 50 * 10**18;
    // Min amount of tokens that need to be claimed in order to claim REFERRAL_REWARD
    uint256 internal constant MIN_CLAIM_FOR_REFERRAL = 500 * 10**18;


    // Mapping of address -> person who referred that address
    mapping(address => address) public referredBy;
    // Whether an address has referred anyone
    mapping(address => bool) public hasReferred;
    // Whether an address has claimed the tokens from being referred
    mapping(address => bool) public claimedReferredTokens;
    // Number of pending referral rewards from recruiting people that have claimed tokens with claimTokensFromBeingReferred() 
    mapping(address => uint256) public pendingReferralRewards;
    // Number of people an address has recruited
    mapping(address => uint256) public numRecruited;
    // Total number of people recruited
    uint256 numPeopleReferred = 0;

    constructor(
        BOOGIE _boogie,
        Bar _bar
    ) public {
        boogie = _boogie;
        bar = _bar;
    }

    // Internal function to safely transfer BOOGIE in case there is a rounding error
    function _safeBoogieTransfer(address _to, uint256 _amount) internal {
        uint256 boogieBalance = boogie.balanceOf(address(this));
        if (_amount > boogieBalance) _amount = boogieBalance;
        boogie.transfer(_to, _amount);
    }

    function getNumPeopleRecruitedBy(address _user) public view returns(uint256) {
        return numRecruited[_user];
    }

    // Returns whether the user has any pending rewards from recruiting users that farmed enough tokens to claim tokens from claimTokensFromBeingReferred() 
    function getNumPendingReferralRewards(address _user) public view returns(uint256) {
        return pendingReferralRewards[_user];
    }

    // Returns whether the user has claimed the one-time reward for being referred
    function hasClaimedTokensFromBeingReferred(address _user) public view returns(bool) {
        return claimedReferredTokens[_user];
    }

    // Returns the person who recruited the sender
    function getReferrer(address _user) public view returns(address) {
        return referredBy[_user];
    }

    function getReferralDataFor(address _user) public view returns (address, bool, uint256, uint256, uint256) {
        return (referredBy[_user], claimedReferredTokens[_user], numRecruited[_user], pendingReferralRewards[_user], numPeopleReferred);
    }

    // Claims the one-time reward for being referred after farming enough tokens
    function claimTokensFromBeingReferred() public {
        require(msg.sender == tx.origin, "no contracts");
        require(referredBy[msg.sender] != address(0), "not referred by anyone");
        require(claimedReferredTokens[msg.sender] == false, "already claimed");

        uint256 totalClaimedAmount = bar.getTotalNumTokensClaimed(msg.sender);

        require(totalClaimedAmount >= MIN_CLAIM_FOR_REFERRAL, "insufficient tokens claimed");

        address referrer = referredBy[msg.sender];
        claimedReferredTokens[msg.sender] = true;
        pendingReferralRewards[referrer] += 1;
        _safeBoogieTransfer(msg.sender, REFERRAL_REWARD);
    }

    function claimRecruitmentRewards() public {
        require(msg.sender == tx.origin, "no contracts");
        require(pendingReferralRewards[msg.sender] > 0, "no rewards to claim");
        uint256 numPending = pendingReferralRewards[msg.sender];
        uint256 rewardAmt = numPending.mul(COMMISSION_REWARD);

        pendingReferralRewards[msg.sender] = 0;
        _safeBoogieTransfer(msg.sender, rewardAmt);
    }

    // Records that _referrer recruited msg.sender, and that _referrer has recruited someone
    // Any user that has recruited someone cannot be referred by someone else
    function refer(address _referrer) public {
        require(msg.sender == tx.origin, "no contracts");
        require(referredBy[msg.sender] == address(0), "already referred by someone");
        require(!hasReferred[msg.sender], "already referred someone"); //to prevent person A from referring person B and then person B referring person A
        require(_referrer != msg.sender, "cannot refer self");
        require(_referrer != address(0), "cannot refer null address");
        //require(numPeopleReferred < MAX_REFERRALS, "referral limit reached");
        
        numPeopleReferred.add(1);
        numRecruited[_referrer] += 1;
        referredBy[msg.sender] = _referrer;
        hasReferred[_referrer] = true;
    }
}pragma solidity ^0.6.12;

// File: @openzeppelin/contracts/utils/Address.sol

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}pragma solidity ^0.6.12;

import './IUniswapV2Router02.sol';
import './IUniswapV2Pair.sol';
import './SafeERC20.sol';
import './IERC20.sol';
import './Bar.sol';
import './Rave.sol';

contract AutoDeposit {
    using SafeERC20 for IERC20;
    
    IUniswapV2Router02 internal uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    Bar internal bar;
    Rave internal rave;
    
    constructor(Bar _bar, Rave _rave) public {
        bar = _bar;
        rave = _rave;
    }

    receive() external payable {
        require(msg.sender != tx.origin);
    }
    
    function depositInto(uint256 _pid) external payable returns (uint256 lpReceived) {
        require(msg.value > 0 && _pid < bar.poolLength());
        
        (IERC20 _token, IERC20 _pool, , , , , ) = bar.poolInfo(_pid);
        
        lpReceived = _convertToLP(_token, _pool, msg.value);
        _pool.safeApprove(address(bar), 0);
        _pool.safeApprove(address(bar), lpReceived);
        bar.depositFor(_pid, msg.sender, lpReceived);
    }
    
    function giveFor(uint256 _pid) external payable returns (uint256 lpReceived) {
        require(msg.value > 0 && _pid < bar.poolLength());

        (IERC20 _token, IERC20 _pool, , , , , ) = bar.poolInfo(_pid);

        lpReceived = _convertToLP(_token, _pool, msg.value);
        _pool.transfer(msg.sender, lpReceived);
    }
    
    function stake() external payable returns (uint256 lpReceived) {
        require(msg.value > 0 && rave.active());
        
        lpReceived = _convertToLP(IERC20(rave.boogie()), rave.boogiePool(), msg.value);
        rave.boogiePool().safeApprove(address(rave), 0);
        rave.boogiePool().safeApprove(address(rave), lpReceived);
        rave.stakeFor(msg.sender, lpReceived);
    }

    
    function _convertToLP(IERC20 _token, IERC20 _pool, uint256 _amount) internal returns (uint256) {
        require(_amount > 0);

        address[] memory _poolPath = new address[](2);
        _poolPath[0] = uniswapRouter.WETH();
        _poolPath[1] = address(_token);
        uniswapRouter.swapExactETHForTokens{value: _amount / 2}(0, _poolPath, address(this), block.timestamp + 5 minutes);

        return _addLP(_token, _pool, _token.balanceOf(address(this)), address(this).balance);
    }

    function _addLP(IERC20 _token, IERC20 _pool, uint256 _tokens, uint256 _eth) internal returns (uint256 liquidityAdded) {
        require(_tokens > 0 && _eth > 0);

        IUniswapV2Pair _pair = IUniswapV2Pair(address(_pool));
        (uint256 _reserve0, uint256 _reserve1, ) = _pair.getReserves();
        bool _isToken0 = _pair.token0() == address(_token);
        uint256 _tokensPerETH = 1e18 * (_isToken0 ? _reserve0 : _reserve1) / (_isToken0 ? _reserve1 : _reserve0);

        _token.safeApprove(address(uniswapRouter), 0);
        if (_tokensPerETH > 1e18 * _tokens / _eth) {
            uint256 _ethValue = 1e18 * _tokens / _tokensPerETH;
            _token.safeApprove(address(uniswapRouter), _tokens);
            ( , , liquidityAdded) = uniswapRouter.addLiquidityETH{value: _ethValue}(address(_token), _tokens, 0, 0, address(this), block.timestamp + 5 minutes);
        } else {
            uint256 _tokenValue = 1e18 * _tokensPerETH / _eth;
            _token.safeApprove(address(uniswapRouter), _tokenValue);
            ( , , liquidityAdded) = uniswapRouter.addLiquidityETH{value: _eth}(address(_token), _tokenValue, 0, 0, address(this), block.timestamp + 5 minutes);
        }

        uint256 _remainingETH = address(this).balance;
        uint256 _remainingTokens = _token.balanceOf(address(this));
        if (_remainingETH > 0) {
            msg.sender.transfer(_remainingETH);
        }
        if (_remainingTokens > 0) {
            _token.transfer(msg.sender, _remainingTokens);
        }
    }
}/*
@website https://boogie.finance
@authors Proof, sol_dev, Zoma, Mr Fahrenheit, Boogie
@auditors Aegis DAO, Sherlock Security
*/

pragma solidity ^0.6.12;

import './Ownable.sol';
import './SafeMath.sol';
import './SafeERC20.sol';
import './IERC20.sol';
import './IUniswapV2Router02.sol';
import './BOOGIE.sol';
import './Rave.sol';


contract Bar is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 staked; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 uniRewardDebt; // UNI staking reward debt. See explanation below.
        uint256 claimed; // Tracks the amount of BOOGIE claimed by the user.
        uint256 uniClaimed; // Tracks the amount of UNI claimed by the user.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 token; // Address of token contract.
        IERC20 lpToken; // Address of LP token contract.
        uint256 apr; // Fixed APR for the pool. Determines how many BOOGIEs to distribute per block.
        uint256 lastBoogieRewardBlock; // Last block number that BOOGIE rewards were distributed.
        uint256 accBoogiePerShare; // Accumulated BOOGIEs per share, times 1e12. See below.
        uint256 accUniPerShare; // Accumulated UNIs per share, times 1e12. See below.
        address uniStakeContract; // Address of UNI staking contract (if applicable).
    }

    // We do some fancy math here. Basically, any point in time, the amount of BOOGIEs
    // entitled to a user but is pending to be distributed is:
    //
    //   pending reward = (user.staked * pool.accBoogiePerShare) - user.rewardDebt
    //
    // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
    //   1. The pool's `accBoogiePerShare` (and `lastBoogieRewardBlock`) gets updated.
    //   2. User receives the pending reward sent to his/her address.
    //   3. User's `staked` amount gets updated.
    //   4. User's `rewardDebt` gets updated.

    // The BOOGIE TOKEN!
    BOOGIE public boogie;
    // The address of the BOOGIE-ETH Uniswap pool
    address public boogiePoolAddress;
     // The Rave staking contract
    Rave public rave;
    // The Uniswap v2 Router
    IUniswapV2Router02 internal uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    // The UNI Staking Rewards Factory
    // Most code related to UNI staking was removed due to the end of UNI staking
    // I was planning on implementing SUSHI staking at one point, but decided not to because income would be fairly minimal
    //StakingRewardsFactory internal uniStakingFactory = StakingRewardsFactory(0x3032Ab3Fa8C01d786D29dAdE018d7f2017918e12);
    // The UNI Token
    //IERC20 internal uniToken = IERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);

    // The WETH Token
    IERC20 internal weth;

    // Dev address, commented out since the dev cut for staking was removed
    //address payable public devAddress;

    // Contract where the tokens allocated for the referral bonus will be sent
    address public referralAddress;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    mapping(address => bool) public existingPools;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Mapping of whitelisted contracts so that certain contracts like the Aegis pool can interact with the Bar contract
    mapping(address => bool) public contractWhitelist;
    // The block number when BOOGIE mining starts.
    uint256 public startBlock;
    // Becomes true once the BOOGIE-ETH Uniswap is created (no sooner than 500 blocks after launch)
    bool public boogiePoolActive = false;
    // The staking fees collected during the first 500 blocks will seed the BOOGIE-ETH Uniswap pool
    uint256 public initialBoogiePoolETH  = 0;
    // 10% of every deposit into any secondary pool (not BOOGIE-ETH) will be converted to BOOGIE (on Uniswap) and sent to the Rave staking contract which becomes active and starts distributing the accumulated BOOGIE to stakers once the max supply is hit
    uint256 public boogieSentToRave = 0;

    //Removed donation stuff
    //uint256 public donatedETH = 0;
    //uint256 internal constant minimumDonationAmount = 25 * 10**18;
    //mapping(address => address) internal donaters;
    //mapping(address => uint256) internal donations;

    // Approximate number of blocks per year - assumes 13 second blocks
    uint256 internal constant APPROX_BLOCKS_PER_YEAR  = uint256(uint256(365 days) / uint256(13 seconds));
    // The default APR for each pool will be 1,000%
    uint256 internal constant DEFAULT_APR = 1000;
    // There will be a 1000 block Soft Launch in which BOOGIE is minted to each pool at a static rate to make the start as fair as possible
    uint256 internal constant SOFT_LAUNCH_DURATION = 1000;
    // During the Soft Launch, all pools except for the BOOGIE-ETH pool will mint 20 BOOGIE per block. Once it's activated, the BOOGIE-ETH pool will mint the same amount of BOOGIE per block as all of the other pools combined until the end of the Soft Launch
    uint256 internal constant SOFT_LAUNCH_BOOGIE_PER_BLOCK = 20 * 10**18;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Claim(address indexed user, uint256 indexed pid, uint256 boogieAmount, uint256 uniAmount);
    event ClaimAll(address indexed user, uint256 boogieAmount, uint256 uniAmount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event BoogieBuyback(address indexed user, uint256 ethSpentOnBoogie, uint256 boogieBought);
    event BoogiePoolActive(address indexed user, uint256 boogieLiquidity, uint256 ethLiquidity);

    constructor(
        BOOGIE _boogie,
        //address payable _devAddress,
        uint256 _startBlock
    ) public {
        boogie = _boogie;
        //devAddress = _devAddress;
        startBlock = _startBlock;
        weth = IERC20(uniswapRouter.WETH());

        // Calculate the address the BOOGIE-ETH Uniswap pool will exist at
        address uniswapfactoryAddress = uniswapRouter.factory();
        address boogieAddress = address(boogie);
        address wethAddress = address(weth);

        // token0 must be strictly less than token1 by sort order to determine the correct address
        (address token0, address token1) = boogieAddress < wethAddress ? (boogieAddress, wethAddress) : (wethAddress, boogieAddress);

        boogiePoolAddress = address(uint(keccak256(abi.encodePacked(
            hex'ff',
            uniswapfactoryAddress,
            keccak256(abi.encodePacked(token0, token1)),
            hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f'
        ))));

        _addInitialPools();
    }
    
    receive() external payable {}

    // Internal function to add a new LP Token pool
    function _addPool(address _token, address _lpToken) internal {

        uint256 apr = DEFAULT_APR;
        if (_token == address(boogie)) apr = apr * 5;

        uint256 lastBoogieRewardBlock = block.number > startBlock ? block.number : startBlock;

        poolInfo.push(
            PoolInfo({
                token: IERC20(_token),
                lpToken: IERC20(_lpToken),
                apr: apr,
                lastBoogieRewardBlock: lastBoogieRewardBlock,
                accBoogiePerShare: 0,
                accUniPerShare: 0,
                uniStakeContract: address(0)
            })
        );

        existingPools[_lpToken] = true;
    }

    // Internal function that adds all of the pools that will be available at launch. Called by the constructor
    function _addInitialPools() internal {

        _addPool(address(boogie), boogiePoolAddress); // BOOGIE-ETH

        //Removed 6 pools due to their low liquidity (or getting hacked, in the case of PICKLE)
        _addPool(0xdAC17F958D2ee523a2206206994597C13D831ec7, 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852); // ETH-USDT
        _addPool(0x6B175474E89094C44Da98b954EedeAC495271d0F, 0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11); // DAI-ETH
        _addPool(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc); // USDC-ETH
        _addPool(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, 0xBb2b8038a1640196FbE3e38816F3e67Cba72D940); // WBTC-ETH
        _addPool(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984, 0xd3d2E2692501A5c9Ca623199D38826e513033a17); // UNI-ETH
        _addPool(0x514910771AF9Ca656af840dff83E8264EcF986CA, 0xa2107FA5B38d9bbd2C461D6EDf11B11A50F6b974); // LINK-ETH
        _addPool(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9, 0xDFC14d2Af169B0D36C4EFF567Ada9b2E0CAE044f); // AAVE-ETH
        _addPool(0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F, 0x43AE24960e5534731Fc831386c07755A2dc33D47); // SNX-ETH
        _addPool(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2, 0xC2aDdA861F89bBB333c90c492cB837741916A225); // MKR-ETH
        _addPool(0xc00e94Cb662C3520282E6f5717214004A7f26888, 0xCFfDdeD873554F362Ac02f8Fb1f02E5ada10516f); // COMP-ETH
        _addPool(0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e, 0x2fDbAdf3C4D5A8666Bc06645B8358ab803996E28); // YFI-ETH
        _addPool(0xba100000625a3754423978a60c9317c58a424e3D, 0xA70d458A4d9Bc0e6571565faee18a48dA5c0D593); // BAL-ETH
        _addPool(0x1494CA1F11D487c2bBe4543E90080AeBa4BA3C2b, 0x4d5ef58aAc27d99935E5b6B4A6778ff292059991); // DPI-ETH
        _addPool(0xD46bA6D942050d489DBd938a2C909A5d5039A161, 0xc5be99A02C6857f9Eac67BbCE58DF5572498F40c); // AMPL-ETH
        _addPool(0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39, 0x55D5c232D921B9eAA6b37b5845E439aCD04b4DBa); // HEX-ETH
        _addPool(0x93ED3FBe21207Ec2E8f2d3c3de6e058Cb73Bc04d, 0x343FD171caf4F0287aE6b87D75A8964Dc44516Ab); // PNK-ETH
        //_addPool(0x429881672B9AE42b8EbA0E26cD9C73711b891Ca5, 0xdc98556Ce24f007A5eF6dC1CE96322d65832A819); // PICKLE-ETH
        _addPool(0x84294FC9710e1252d407d3D80A84bC39001bd4A8, 0x0C5136B5d184379fa15bcA330784f2d5c226Fe96); // NUTS-ETH
        //_addPool(0x821144518dfE9e7b44fCF4d0824e15e8390d4637, 0x490B5B2489eeFC4106C69743F657e3c4A2870aC5); // ATIS-ETH
        //_addPool(0xB9464ef80880c5aeA54C7324c0b8Dd6ca6d05A90, 0xa8D0f6769AB020877f262D8Cd747c188D9097d7E); // LOCK-ETH
        //_addPool(0x926dbD499d701C61eABe2d576e770ECCF9c7F4F3, 0xC7c0EDf0b5f89eff96aF0E31643Bd588ad63Ea23); // aDAO-ETH
        //_addPool(0x3A9FfF453d50D4Ac52A6890647b823379ba36B9E, 0x260E069deAd76baAC587B5141bB606Ef8b9Bab6c); // SHUF-ETH
        //_addPool(0x9720Bcf5a92542D4e286792fc978B63a09731CF0, 0x08538213596fB2c392e9c5d4935ad37645600a57); // OTBC-ETH
        _addPool(0xEEF9f339514298C6A857EfCfC1A762aF84438dEE, 0x23d15EDceb5B5B3A23347Fa425846DE80a2E8e5C); // HEZ-ETH
        
    }

    // Get the pending BOOGIEs for a user from 1 pool
    function _pendingBoogie(uint256 _pid, address _user) internal view returns (uint256) {
        if (_pid == 0 && boogiePoolActive != true) return 0;

        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint256 accBoogiePerShare = pool.accBoogiePerShare;
        uint256 lpSupply = _getPoolSupply(_pid);

        if (block.number > pool.lastBoogieRewardBlock && lpSupply != 0) {
            uint256 boogieReward = _calculateBoogieReward(_pid, lpSupply);

            // Make sure that boogieReward won't push the total supply of BOOGIE past boogie.MAX_SUPPLY()
            uint256 boogieTotalSupply = boogie.totalSupply();
            if (boogieTotalSupply.add(boogieReward) >= boogie.MAX_SUPPLY()) {
                boogieReward = boogie.MAX_SUPPLY().sub(boogieTotalSupply);
            }

            accBoogiePerShare = accBoogiePerShare.add(boogieReward.mul(1e12).div(lpSupply));
        }

        return user.staked.mul(accBoogiePerShare).div(1e12).sub(user.rewardDebt);
    }

    // Calculate the current boogieReward for a specific pool
    function _calculateBoogieReward(uint256 _pid, uint256 _lpSupply) internal view returns (uint256 boogieReward) {
        
        if (boogie.maxSupplyHit() != true) {

            PoolInfo memory pool = poolInfo[_pid];

            uint256 multiplier = block.number - pool.lastBoogieRewardBlock;
                
            // There will be a 1000 block Soft Launch where BOOGIE is minted at a static rate to make things as fair as possible
            if (block.number < startBlock + SOFT_LAUNCH_DURATION) {

                // The BOOGIE-ETH pool isn't active until the Uniswap pool is created, which can't happen until at least 500 blocks have passed. Once active, it mints 500 BOOGIE per block (the same amount of BOOGIE per block as all of the other pools combined) until the Soft Launch ends
                if (_pid != 0) {
                    // For the first 1000 blocks, give 20 BOOGIE per block to all other pools that have staked LP tokens
                    boogieReward = multiplier * SOFT_LAUNCH_BOOGIE_PER_BLOCK;
                } else if (boogiePoolActive == true) {
                    boogieReward = multiplier * 25 * SOFT_LAUNCH_BOOGIE_PER_BLOCK;
                }
            
            } else if (_pid != 0 && boogiePoolActive != true) {
                // Keep minting 20 tokens per block since the Soft Launch is over but the BOOGIE-ETH pool still isn't active (would only be due to no one calling the activateBoogiePool function)
                boogieReward = multiplier * SOFT_LAUNCH_BOOGIE_PER_BLOCK;
            } else if (boogiePoolActive == true) { 
                // Afterwards, give boogieReward based on the pool's fixed APR.
                // Fast low gas cost way of calculating prices since this can be called every block.
                uint256 boogiePrice = _getBoogiePrice();
                uint256 lpTokenPrice = 10**18 * 2 * weth.balanceOf(address(pool.lpToken)) / pool.lpToken.totalSupply(); 
                uint256 scaledTotalLiquidityValue = _lpSupply * lpTokenPrice;
                boogieReward = multiplier * ((pool.apr * scaledTotalLiquidityValue / boogiePrice) / APPROX_BLOCKS_PER_YEAR) / 100;
            }

        }

    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Internal view function to get all of the stored data for a single pool
    function _getPoolData(uint256 _pid) internal view returns (address, address, bool, uint256, uint256, uint256, uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        return (address(pool.token), address(pool.lpToken), pool.uniStakeContract != address(0), pool.apr, pool.lastBoogieRewardBlock, pool.accBoogiePerShare, pool.accUniPerShare);
    }

    // View function to see all of the stored data for every pool on the frontend
    function _getAllPoolData() internal view returns (address[] memory, address[] memory, bool[] memory, uint[] memory, uint[] memory, uint[2][] memory) {
        uint256 length = poolInfo.length;
        address[] memory tokenData = new address[](length);
        address[] memory lpTokenData = new address[](length);
        bool[] memory isUniData = new bool[](length);
        uint[] memory aprData = new uint[](length);
        uint[] memory lastBoogieRewardBlockData = new uint[](length);
        uint[2][] memory accTokensPerShareData = new uint[2][](length);

        for (uint256 pid = 0; pid < length; ++pid) {
            (tokenData[pid], lpTokenData[pid], isUniData[pid], aprData[pid], lastBoogieRewardBlockData[pid], accTokensPerShareData[pid][0], accTokensPerShareData[pid][1]) = _getPoolData(pid);
        }

        return (tokenData, lpTokenData, isUniData, aprData, lastBoogieRewardBlockData, accTokensPerShareData);
    }

    // Internal view function to get all of the extra data for a single pool
    function _getPoolMetadataFor(uint256 _pid, address _user, uint256 _boogiePrice) internal view returns (uint[17] memory poolMetadata) {
        PoolInfo memory pool = poolInfo[_pid];

        uint256 totalSupply;
        uint256 totalLPSupply;
        uint256 stakedLPSupply;
        uint256 tokenPrice;
        uint256 lpTokenPrice;
        uint256 totalLiquidityValue;
        uint256 boogiePerBlock;

        if (_pid != 0 || boogiePoolActive == true) {
            totalSupply = pool.token.totalSupply();
            totalLPSupply = pool.lpToken.totalSupply();
            stakedLPSupply = _getPoolSupply(_pid);

            tokenPrice = 10**uint256(pool.token.decimals()) * weth.balanceOf(address(pool.lpToken)) / pool.token.balanceOf(address(pool.lpToken));
            lpTokenPrice = 10**18 * 2 * weth.balanceOf(address(pool.lpToken)) / totalLPSupply; 
            totalLiquidityValue = stakedLPSupply * lpTokenPrice / 1e18;
        }

        // Only calculate with fixed apr after the Soft Launch
        if (block.number >= startBlock + SOFT_LAUNCH_DURATION) {
            boogiePerBlock = ((pool.apr * 1e18 * totalLiquidityValue / _boogiePrice) / APPROX_BLOCKS_PER_YEAR) / 100;
        } else {
            if (_pid != 0) {
                boogiePerBlock = SOFT_LAUNCH_BOOGIE_PER_BLOCK;
            } else if (boogiePoolActive == true) {
                boogiePerBlock = 25 * SOFT_LAUNCH_BOOGIE_PER_BLOCK;
            }
        }

        // Global pool information
        poolMetadata[0] = totalSupply;
        poolMetadata[1] = totalLPSupply;
        poolMetadata[2] = stakedLPSupply;
        poolMetadata[3] = tokenPrice;
        poolMetadata[4] = lpTokenPrice;
        poolMetadata[5] = totalLiquidityValue;
        poolMetadata[6] = boogiePerBlock;
        poolMetadata[7] = pool.token.decimals();

        // User pool information
        if (_pid != 0 || boogiePoolActive == true) {
            UserInfo memory _userInfo = userInfo[_pid][_user];
            poolMetadata[8] = pool.token.balanceOf(_user);
            poolMetadata[9] = pool.token.allowance(_user, address(this));
            poolMetadata[10] = pool.lpToken.balanceOf(_user);
            poolMetadata[11] = pool.lpToken.allowance(_user, address(this));
            poolMetadata[12] = _userInfo.staked;
            poolMetadata[13] = _pendingBoogie(_pid, _user);
            //poolMetadata[14] = _pendingUni(_pid, _user);
            poolMetadata[15] = _userInfo.claimed;
            //poolMetadata[16] = _userInfo.uniClaimed;
        }
    }

    // View function to see all of the extra pool data (token prices, total staked supply, total liquidity value, etc) on the frontend
    function _getAllPoolMetadataFor(address _user) internal view returns (uint[17][] memory allMetadata) {
        uint256 length = poolInfo.length;

        // Extra data for the frontend
        allMetadata = new uint[17][](length);

        // We'll need the current BOOGIE price to make our calculations
        uint256 boogiePrice = _getBoogiePrice();

        for (uint256 pid = 0; pid < length; ++pid) {
            allMetadata[pid] = _getPoolMetadataFor(pid, _user, boogiePrice);
        }
    }

    // View function to see all of the data for all pools on the frontend
    function getAllPoolInfoFor(address _user) external view returns (address[] memory tokens, address[] memory lpTokens, bool[] memory isUnis, uint[] memory aprs, uint[] memory lastBoogieRewardBlocks, uint[2][] memory accTokensPerShares, uint[17][] memory metadatas) {
        (tokens, lpTokens, isUnis, aprs, lastBoogieRewardBlocks, accTokensPerShares) = _getAllPoolData();
        metadatas = _getAllPoolMetadataFor(_user);
    }

    // Internal view function to get the current price of BOOGIE on Uniswap
    function _getBoogiePrice() internal view returns (uint256 boogiePrice) {
        uint256 boogieBalance = boogie.balanceOf(boogiePoolAddress);
        if (boogieBalance > 0) {
            boogiePrice = 10**18 * weth.balanceOf(boogiePoolAddress) / boogieBalance;
        }
    }

    // View function to show all relevant platform info on the frontend
    function getAllInfoFor(address _user) external view returns (bool poolActive, uint256[8] memory info) {
        poolActive = boogiePoolActive;
        info[0] = blocksUntilLaunch();
        info[1] = blocksUntilBoogiePoolCanBeActivated();
        info[2] = blocksUntilSoftLaunchEnds();
        info[3] = boogie.totalSupply();
        info[4] = _getBoogiePrice();
        if (boogiePoolActive) {
            info[5] = IERC20(boogiePoolAddress).balanceOf(address(boogie));
        }
        info[6] = boogieSentToRave;
        info[7] = boogie.balanceOf(_user);
    }
    
    // View function to see the total number of tokens claimed from all pools for a particular user, used by Referral.sol
    function getTotalNumTokensClaimed(address _user) external view returns (uint256 numTokensClaimed) {
        uint256 length = poolInfo.length;

        for (uint256 pid = 0; pid < length; ++pid) {
            UserInfo memory user = userInfo[pid][_user];
            numTokensClaimed += user.claimed;
        }
    }

    // View function to see the number of blocks remaining until launch on the frontend
    function blocksUntilLaunch() public view returns (uint256) {
        if (block.number >= startBlock) return 0;
        else return startBlock.sub(block.number);
    }

    // View function to see the number of blocks remaining until the BOOGIE pool can be activated on the frontend
    function blocksUntilBoogiePoolCanBeActivated() public view returns (uint256) {
        uint256 boogiePoolActivationBlock = startBlock + SOFT_LAUNCH_DURATION.div(2);
        if (block.number >= boogiePoolActivationBlock) return 0;
        else return boogiePoolActivationBlock.sub(block.number);
    }

    // View function to see the number of blocks remaining until the Soft Launch ends on the frontend
    function blocksUntilSoftLaunchEnds() public view returns (uint256) {
        uint256 softLaunchEndBlock = startBlock + SOFT_LAUNCH_DURATION;
        if (block.number >= softLaunchEndBlock) return 0;
        else return softLaunchEndBlock.sub(block.number);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = (boogiePoolActive == true ? 0 : 1); pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    // Removed code for the UNI staking rewards contract due to the end of UNI staking
    function updatePool(uint256 _pid) public {
        require(msg.sender == tx.origin || msg.sender == owner() || contractWhitelist[msg.sender] == true, "no contracts"); // Prevent flash loan attacks that manipulate prices.
        
        PoolInfo storage pool = poolInfo[_pid];
        uint256 lpSupply = _getPoolSupply(_pid);

        // Only update the pool if the max BOOGIE supply hasn't been hit
        if (boogie.maxSupplyHit() != true) {
            
            if ((block.number <= pool.lastBoogieRewardBlock) || (_pid == 0 && boogiePoolActive != true)) {
                return;
            }
            if (lpSupply == 0) {
                pool.lastBoogieRewardBlock = block.number;
                return;
            }

            uint256 boogieReward = _calculateBoogieReward(_pid, lpSupply);

            // Make sure that boogieReward won't push the total supply of BOOGIE past boogie.MAX_SUPPLY()
            uint256 boogieTotalSupply = boogie.totalSupply();
            if (boogieTotalSupply.add(boogieReward) >= boogie.MAX_SUPPLY()) {
                boogieReward = boogie.MAX_SUPPLY().sub(boogieTotalSupply);
            }

            // boogie.mint(devAddress, boogieReward.div(10)); Not minting 10% to the devs like Sushi, Sashimi, and Takeout do

            if (boogieReward > 0) {
                boogie.mint(address(this), boogieReward);
                pool.accBoogiePerShare = pool.accBoogiePerShare.add(boogieReward.mul(1e12).div(lpSupply));
                pool.lastBoogieRewardBlock = block.number;
            }

            if (boogie.maxSupplyHit() == true) {
                rave.activate();
            }
        }
    }

    // Internal view function to get the amount of LP tokens staked in the specified pool
    function _getPoolSupply(uint256 _pid) internal view returns (uint256 lpSupply) {
        PoolInfo memory pool = poolInfo[_pid];
        lpSupply = pool.lpToken.balanceOf(address(this));
    }

    // Deposits LP tokens in the specified pool to start earning the user BOOGIE
    function deposit(uint256 _pid, uint256 _amount) external {
        depositFor(_pid, msg.sender, _amount);
    }

    // Deposits LP tokens in the specified pool on behalf of another user
    function depositFor(uint256 _pid, address _user, uint256 _amount) public {
        require(msg.sender == tx.origin || contractWhitelist[msg.sender] == true, "no contracts");
        require(boogie.maxSupplyHit() != true, "pools closed");
        require(_pid != 0 || boogiePoolActive == true, "boogie pool not active");
        require(_amount > 0, "deposit something");

        updatePool(_pid);

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        // The sender needs to give approval to the Bar contract for the specified amount of the LP token first
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);

        // Claim any pending BOOGIE and UNI
        _claimRewardsFromPool(_pid, _user);
        
        // Each pool has a 10% staking fee. If staking in the BOOGIE-ETH pool, 100% of the fee gets permanently locked in the BOOGIE contract (gives BOOGIE liquidity forever).
        // If staking in any other pool, 100% of the fee is used to buyback BOOGIE which is sent to the Rave staking contract where it will start getting distributed to stakers after the max supply is hit
        // The team is never minted or rewarded BOOGIE for any reason to keep things as fair as possible.
        uint256 stakingFeeAmount = _amount.div(10);
        uint256 remainingUserAmount = _amount.sub(stakingFeeAmount);

        // The user is depositing to the BOOGIE-ETH pool so permanently lock all of the LP tokens from the staking fee in the BOOGIE contract
        if (_pid == 0) {
            pool.lpToken.transfer(address(boogie), stakingFeeAmount);
        } else {
            // Remove the liquidity from the pool
            uint256 deadline = block.timestamp + 5 minutes;
            pool.lpToken.safeApprove(address(uniswapRouter), 0);
            pool.lpToken.safeApprove(address(uniswapRouter), stakingFeeAmount);
            uniswapRouter.removeLiquidityETHSupportingFeeOnTransferTokens(address(pool.token), stakingFeeAmount, 0, 0, address(this), deadline);

            // Swap the ERC-20 token for ETH
            uint256 tokensToSwap = pool.token.balanceOf(address(this));
            require(tokensToSwap > 0, "bad token swap");
            address[] memory poolPath = new address[](2);
            poolPath[0] = address(pool.token);
            poolPath[1] = address(weth);
            pool.token.safeApprove(address(uniswapRouter), 0);
            pool.token.safeApprove(address(uniswapRouter), tokensToSwap);
            uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(tokensToSwap, 0, poolPath, address(this), deadline);

            uint256 ethBalanceAfterSwap = address(this).balance;
            //uint256 teamFeeAmount; //No dev fee, unlike Surf

            // If boogiePoolActive == true then perform a buyback of BOOGIE using all of the ETH in the contract and then send it to the Rave staking contract. 
            // Otherwise, the ETH will be used to seed the initial liquidity in the BOOGIE-ETH Uniswap pool when activateBoogiePool is called
            if (boogiePoolActive == true) {
                require(ethBalanceAfterSwap > 0, "bad eth swap");

                // The BOOGIE-ETH pool is active, so let's use the ETH to buyback BOOGIE and send it to the Rave staking contract
                uint256 boogieBought = _buyBoogie(ethBalanceAfterSwap);

                // Send the BOOGIE rewards to the Rave staking contract
                boogieSentToRave += boogieBought;
                _safeBoogieTransfer(address(rave), boogieBought);
            }
        }

        // Add the remaining amount to the user's staked balance
        uint256 _currentRewardDebt = 0;
        if (boogiePoolActive != true) {
            _currentRewardDebt = user.staked.mul(pool.accBoogiePerShare).div(1e12).sub(user.rewardDebt);
        }
        user.staked = user.staked.add(remainingUserAmount);
        user.rewardDebt = user.staked.mul(pool.accBoogiePerShare).div(1e12).sub(_currentRewardDebt);

        emit Deposit(_user, _pid, _amount);
    }

    // Internal function that buys back BOOGIE with the amount of ETH specified
    function _buyBoogie(uint256 _amount) internal returns (uint256 boogieBought) {
        uint256 ethBalance = address(this).balance;
        if (_amount > ethBalance) _amount = ethBalance;
        if (_amount > 0) {
            uint256 deadline = block.timestamp + 5 minutes;
            address[] memory boogiePath = new address[](2);
            boogiePath[0] = address(weth);
            boogiePath[1] = address(boogie);
            uint256[] memory amounts = uniswapRouter.swapExactETHForTokens{value: _amount}(0, boogiePath, address(this), deadline);
            boogieBought = amounts[1];
        }
        if (boogieBought > 0) emit BoogieBuyback(msg.sender, _amount, boogieBought);
    }

    // Internal function to claim earned BOOGIE and UNI from Bar. Claiming won't work until boogiePoolActive == true
    function _claimRewardsFromPool(uint256 _pid, address _user) internal {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        if (boogiePoolActive != true || user.staked == 0) return;

        uint256 userBoogiePending = user.staked.mul(pool.accBoogiePerShare).div(1e12).sub(user.rewardDebt);
        if (userBoogiePending > 0) {
            user.claimed += userBoogiePending;
            _safeBoogieTransfer(_user, userBoogiePending);
        }

        if (userBoogiePending > 0) {
            emit Claim(_user, _pid, userBoogiePending, 0); //userUniPending
        }
    }

    // Claim all earned BOOGIE and UNI from a single pool. Claiming won't work until boogiePoolActive == true
    function claim(uint256 _pid) public {
        require(boogiePoolActive == true, "boogie pool not active");
        updatePool(_pid);
        _claimRewardsFromPool(_pid, msg.sender);
        UserInfo storage user = userInfo[_pid][msg.sender];
        PoolInfo memory pool = poolInfo[_pid];
        user.rewardDebt = user.staked.mul(pool.accBoogiePerShare).div(1e12);
    }

    // Claim all earned BOOGIE and UNI from all pools. Claiming won't work until boogiePoolActive == true
    function claimAll() public {
        require(boogiePoolActive == true, "boogie pool not active");

        uint256 totalPendingBoogieAmount = 0;
        
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            UserInfo storage user = userInfo[pid][msg.sender];

            if (user.staked > 0) {
                updatePool(pid);

                PoolInfo storage pool = poolInfo[pid];
                uint256 accBoogiePerShare = pool.accBoogiePerShare;

                uint256 pendingPoolBoogieRewards = user.staked.mul(accBoogiePerShare).div(1e12).sub(user.rewardDebt);
                user.claimed += pendingPoolBoogieRewards;
                totalPendingBoogieAmount = totalPendingBoogieAmount.add(pendingPoolBoogieRewards);
                user.rewardDebt = user.staked.mul(accBoogiePerShare).div(1e12);
            }
        }
        require(totalPendingBoogieAmount > 0, "nothing to claim"); 

        if (totalPendingBoogieAmount > 0) _safeBoogieTransfer(msg.sender, totalPendingBoogieAmount);
        emit ClaimAll(msg.sender, totalPendingBoogieAmount, 0); //totalPendingUniAmount
    }

    // Withdraw LP tokens and earned BOOGIE from Bar. Withdrawing won't work until boogiePoolActive == true
    function withdraw(uint256 _pid, uint256 _amount) public {
        require(boogiePoolActive == true, "boogie pool not active");
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(_amount > 0 && user.staked >= _amount, "withdraw: not good");
        
        updatePool(_pid);

        // Claim any pending BOOGIE
        _claimRewardsFromPool(_pid, msg.sender);
        PoolInfo memory pool = poolInfo[_pid];

        user.staked = user.staked.sub(_amount);
        user.rewardDebt = user.staked.mul(pool.accBoogiePerShare).div(1e12);

        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Convenience function to allow users to migrate all of their staked BOOGIE-ETH LP tokens from Bar to the Rave staking contract after the max supply is hit. Migrating won't work until rave.active() == true
    function migrateBOOGIELPtoRave() public {
        require(rave.active() == true, "rave not active");
        UserInfo storage user = userInfo[0][msg.sender];
        uint256 amountToMigrate = user.staked;
        require(amountToMigrate > 0, "migrate: not good");
        
        updatePool(0);

        // Claim any pending BOOGIE
        _claimRewardsFromPool(0, msg.sender);

        user.staked = 0;
        user.rewardDebt = 0;

        poolInfo[0].lpToken.safeApprove(address(rave), 0);
        poolInfo[0].lpToken.safeApprove(address(rave), amountToMigrate);
        rave.stakeFor(msg.sender, amountToMigrate);
        emit Withdraw(msg.sender, 0, amountToMigrate);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 staked = user.staked;
        require(staked > 0, "no tokens");

        PoolInfo memory pool = poolInfo[_pid];
        
        user.staked = 0;
        user.rewardDebt = 0;

        pool.lpToken.safeTransfer(address(msg.sender), staked);
        emit EmergencyWithdraw(msg.sender, _pid, staked);
    }

    // Internal function to safely transfer BOOGIE in case there is a rounding error
    function _safeBoogieTransfer(address _to, uint256 _amount) internal {
        uint256 boogieBalance = boogie.balanceOf(address(this));
        if (_amount > boogieBalance) _amount = boogieBalance;
        boogie.transfer(_to, _amount);
    }

    // Creates the BOOGIE-ETH Uniswap pool and adds the initial liqudity that will be permanently locked. Can be called by anyone, but no sooner than 500 blocks after launch. 
    function activateBoogiePool() public {
        require(boogiePoolActive == false, "already active");
        require(msg.sender == tx.origin, "no contracts");
        require(block.number > startBlock + SOFT_LAUNCH_DURATION.div(2), "too soon");
        uint256 initialEthLiquidity = address(this).balance;
        require(initialEthLiquidity > 0, "need ETH");

        massUpdatePools();

        // The ETH raised from the staking fees collected before boogiePoolActive == true is used to seed the ETH side of the BOOGIE-ETH Uniswap pool.
        // Mint 500,000 new BOOGIE to seed the BOOGIE liquidity in the BOOGIE-ETH Uniswap pool + referral bonus
        uint256 initialMintAmount = 500000 * 10**18;
        boogie.mint(address(this), initialMintAmount);

        uint256 initialBoogieLiquidity = initialMintAmount.div(2); //Allocate 250k tokens to seed the BOOGIE liquidity in the BOOGIE-ETH Uniswap pool
        uint256 referralBonusAmount = initialMintAmount.div(2); //Allocate 250k tokens for referral bonus

        // Add the liquidity to the BOOGIE-ETH Uniswap pool
        boogie.approve(address(uniswapRouter), initialBoogieLiquidity);
        ( , , uint256 lpTokensReceived) = uniswapRouter.addLiquidityETH{value: initialEthLiquidity}(address(boogie), initialBoogieLiquidity, 0, 0, address(this), block.timestamp + 5 minutes);

        // Activate the BOOGIE-ETH pool
        initialBoogiePoolETH = initialEthLiquidity;
        boogiePoolActive = true;

        // Permanently lock the LP tokens in the BOOGIE contract
        IERC20(boogiePoolAddress).transfer(address(boogie), lpTokensReceived);
        //Send the other half of the tokens to the referral bonus contract
        _safeBoogieTransfer(referralAddress, referralBonusAmount);

        emit BoogiePoolActive(msg.sender, initialBoogieLiquidity, initialEthLiquidity);
    }

    //////////////////////////
    // Governance Functions //
    //////////////////////////
    // The following functions can only be called by the owner (the BOOGIE token holder governance contract)

    // Sets the address of the Rave staking contract that bought BOOGIE gets sent to for distribution to stakers once the max supply is hit
    function setRaveContract(Rave _rave) public onlyOwner {
        rave = _rave;
    }

    // Sets the address of the referral contract that 250k tokens are sent to once activateBoogiePool() is called 
    function setReferralAddress(address _address) public onlyOwner {
        referralAddress = _address;
    }

    // Sets the new starting block, used for if I need to delay the launch since I don't want to launch in the middle of a BTC correction
    //function setStartingBlock(uint256 _startBlock) public onlyOwner {
    //    require(_startBlock > block.number); //The starting block must be after the current block
    //    startBlock = _startBlock;
    //}

    // Add a new LP Token pool
    function addPool(address _token, address _lpToken, uint256 _apr) public onlyOwner {
        require(boogie.maxSupplyHit() != true);
        require(existingPools[_lpToken] != true, "pool exists");

        _addPool(_token, _lpToken);
        if (_apr != DEFAULT_APR) poolInfo[poolInfo.length-1].apr = _apr;
    }

    // Update the given pool's APR
    function setApr(uint256 _pid, uint256 _apr) public onlyOwner {
        require(boogie.maxSupplyHit() != true);
        updatePool(_pid);
        poolInfo[_pid].apr = _apr;
    }

    // Add a contract to the whitelist so that it can interact with Bar. This is needed for the Aegis pool contract to be able to stake on behalf of everyone in the pool.
    // We want limited interaction from contracts due to the growing "flash loan" trend that can be used to dramatically manipulate a token's price in a single block.
    function addToWhitelist(address _contractAddress) public onlyOwner {
        contractWhitelist[_contractAddress] = true;
    }

    // Remove a contract from the whitelist
    function removeFromWhitelist(address _contractAddress) public onlyOwner {
        contractWhitelist[_contractAddress] = false;
    }
}/*
@website https://boogie.finance
@authors Proof, sol_dev, Zoma, Mr Fahrenheit
@auditors Aegis DAO, Sherlock Security
*/

pragma solidity ^0.6.12;

import './ERC20.sol';
import './IERC20.sol';
import './Ownable.sol';
import './Rave.sol';

interface Callable {
    function tokenCallback(address _from, uint256 _tokens, bytes calldata _data) external returns (bool);
    function receiveApproval(address _from, uint256 _tokens, address _token, bytes calldata _data) external;
}

// BOOGIE Token with Governance. The governance contract will own the BOOGIE, Bar, and Rave contracts,
// allowing BOOGIE token holders to make and vote on proposals that can modify many parts of the protocol.
contract BOOGIE is ERC20("BOOGIE.Finance", "BOOGIE"), Ownable {

    // There will be a max supply of 5,000,000 BOOGIE tokens
    uint256 public constant MAX_SUPPLY = 5000000 * 10**18;
    bool public maxSupplyHit = false;

    // The BOOGIE transfer fee that gets rewarded to Rave stakers (1 = 0.1%). Defaults to 1%
    uint256 public transferFee = 10;

    // Mapping of whitelisted sender and recipient addresses that don't pay the transfer fee. Allows BOOGIE token holders to whitelist future contracts
    mapping(address => bool) public senderWhitelist;
    mapping(address => bool) public recipientWhitelist;

    // The Bar contract
    address public barAddress;

    // The Rave contract
    address payable public raveAddress;

    // The Uniswap BOOGIE-ETH LP token address
    address public boogiePoolAddress;

    // Creates `_amount` token to `_to`. Can only be called by the Bar contract.
    function mint(address _to, uint256 _amount) public {
        require(maxSupplyHit != true, "max supply hit");
        require(msg.sender == barAddress, "not Bar");
        uint256 supply = totalSupply();
        if (supply.add(_amount) >= MAX_SUPPLY) {
            _amount = MAX_SUPPLY.sub(supply);
            maxSupplyHit = true;
        }

        if (_amount > 0) {
            _mint(_to, _amount);
            _moveDelegates(address(0), _delegates[_to], _amount);
        }
    }

    // Sets the addresses of the Bar farming contract, the Rave staking contract, and the Uniswap BOOGIE-ETH LP token
    function setContractAddresses(address _barAddress, address payable _raveAddress, address _boogiePoolAddress) public onlyOwner {
        if (_barAddress != address(0)) barAddress = _barAddress;
        if (_raveAddress != address(0)) raveAddress = _raveAddress;
        if (_boogiePoolAddress != address(0)) boogiePoolAddress = _boogiePoolAddress;
    }

    // Sets the BOOGIE transfer fee that gets rewarded to Rave stakers. Can't be higher than 10%.
    function setTransferFee(uint256 _transferFee) public onlyOwner {
        require(_transferFee <= 100, "over 10%");
        transferFee = _transferFee;
    }

    // Add an address to the sender or recipient transfer whitelist
    function addToTransferWhitelist(bool _addToSenderWhitelist, address _address) public onlyOwner {
        if (_addToSenderWhitelist == true) senderWhitelist[_address] = true;
        else recipientWhitelist[_address] = true;
    }

    // Remove an address from the sender or recipient transfer whitelist
    function removeFromTransferWhitelist(bool _removeFromSenderWhitelist, address _address) public onlyOwner {
        if (_removeFromSenderWhitelist == true) senderWhitelist[_address] = false;
        else recipientWhitelist[_address] = false;
    }

    // Both the Bar and Rave contracts will lock the BOOGIE-ETH LP tokens they receive from their staking/unstaking fees here (ensuring liquidity forever).
    // This function allows BOOGIE token holders to decide what to do with the locked LP tokens in the future
    function migrateLockedLPTokens(address _to, uint256 _amount) public onlyOwner {
        IERC20 poolAddress = IERC20(boogiePoolAddress);
        require(_amount > 0 && _amount <= poolAddress.balanceOf(address(this)), "bad amount");
        poolAddress.transfer(_to, _amount);
    }

    function approveAndCall(address _spender, uint256 _tokens, bytes calldata _data) external returns (bool) {
        approve(_spender, _tokens);
        Callable(_spender).receiveApproval(msg.sender, _tokens, address(this), _data);
        return true;
    }

    function transferAndCall(address _to, uint256 _tokens, bytes calldata _data) external returns (bool) {
        uint256 _balanceBefore = balanceOf(_to);
        transfer(_to, _tokens);
        uint256 _tokensReceived = balanceOf(_to) - _balanceBefore;
        uint32 _size;
        assembly {
            _size := extcodesize(_to)
        }
        if (_size > 0) {
            require(Callable(_to).tokenCallback(msg.sender, _tokensReceived, _data));
        }
        return true;
    }

    // There's a fee on every BOOGIE transfer that gets sent to the Rave staking contract which will start getting rewarded to stakers after the max supply is hit.
    // The transfer fee will reduce the front-running of Uniswap trades and will provide a major incentive to hold and stake BOOGIE long-term.
    // Transfers to/from the Bar or Rave contracts will not pay a fee.
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 transferFeeAmount;
        uint256 tokensToTransfer;

        if (amount > 0) {

            // Send a fee to the Rave staking contract if this isn't a whitelisted transfer
            if (_isWhitelistedTransfer(sender, recipient) != true) {
                transferFeeAmount = amount.mul(transferFee).div(1000);
                _balances[raveAddress] = _balances[raveAddress].add(transferFeeAmount);
                _moveDelegates(_delegates[sender], _delegates[raveAddress], transferFeeAmount);
                Rave(raveAddress).addBoogieReward(sender, transferFeeAmount);
                emit Transfer(sender, raveAddress, transferFeeAmount);
            }

            tokensToTransfer = amount.sub(transferFeeAmount);

            _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");

            if (tokensToTransfer > 0) {
                _balances[recipient] = _balances[recipient].add(tokensToTransfer);
                _moveDelegates(_delegates[sender], _delegates[recipient], tokensToTransfer);

                // If the Rave staking contract is the transfer recipient, addBoogieReward gets called to keep things in sync
                if (recipient == raveAddress) Rave(raveAddress).addBoogieReward(sender, tokensToTransfer);
            }

        }

        emit Transfer(sender, recipient, tokensToTransfer);
    }

    // Internal function to determine if a BOOGIE transfer is being sent or received by a whitelisted address
    function _isWhitelistedTransfer(address _sender, address _recipient) internal view returns (bool) {
        // The Rave and Bar contracts are always whitelisted
        return
            _sender == raveAddress || _recipient == raveAddress ||
            _sender == barAddress || _recipient == barAddress ||
            senderWhitelist[_sender] == true || recipientWhitelist[_recipient] == true;
    }

    // Copied and modified from YAM code:
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernanceStorage.sol
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernance.sol
    // Which is copied and modified from COMPOUND:
    // https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol

    /// @dev A record of each accounts delegate
    mapping (address => address) internal _delegates;

    /// @dev A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    /// @dev A record of votes checkpoints for each account, by index
    mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;

    /// @dev The number of checkpoints for each account
    mapping (address => uint32) public numCheckpoints;

    /// @dev The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @dev The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @dev A record of states for signing / validating signatures
    mapping (address => uint) public nonces;

      /// @dev An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @dev An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

    /**
     * @dev Delegate votes from `msg.sender` to `delegatee`
     * @param delegator The address to get delegatee for
     */
    function delegates(address delegator) external view returns (address) {
        return _delegates[delegator];
    }

   /**
    * @dev Delegate votes from `msg.sender` to `delegatee`
    * @param delegatee The address to delegate votes to
    */
    function delegate(address delegatee) external {
        return _delegate(msg.sender, delegatee);
    }

    /**
     * @dev Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(address delegatee, uint nonce, uint expiry, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name())),
                getChainId(),
                address(this)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                DELEGATION_TYPEHASH,
                delegatee,
                nonce,
                expiry
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );

        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "BOOGIE::delegateBySig: invalid signature");
        require(nonce == nonces[signatory]++, "BOOGIE::delegateBySig: invalid nonce");
        require(now <= expiry, "BOOGIE::delegateBySig: signature expired");
        return _delegate(signatory, delegatee);
    }

    /**
     * @dev Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account) external view returns (uint256) {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @dev Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber) external view returns (uint256) {
        require(blockNumber < block.number, "BOOGIE::getPriorVotes: not yet determined");

        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator); // balance of underlying BOOGIEs (not scaled);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegates(address srcRep, address dstRep, uint256 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                // decrease old representative
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint256 srcRepNew = srcRepOld.sub(amount);
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                // increase new representative
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint256 dstRepNew = dstRepOld.add(amount);
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(address delegatee, uint32 nCheckpoints, uint256 oldVotes, uint256 newVotes) internal {
        uint32 blockNumber = safe32(block.number, "BOOGIE::_writeCheckpoint: block number exceeds 32 bits");

        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function getChainId() internal pure returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}pragma solidity ^0.6.12;

// File: @openzeppelin/contracts/GSN/Context.sol

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
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}pragma solidity ^0.6.12;

import './Context.sol';
import './IERC20.sol';
import './SafeMath.sol';

// File: @openzeppelin/contracts/token/ERC20/ERC20.sol

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) internal _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name, string memory symbol) public {
        _name = name;
        _symbol = symbol;
        _decimals = 18;
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
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
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
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
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
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
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
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
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
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
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
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

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
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
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
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
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
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}// COPIED FROM https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorAlpha.sol
// Copyright 2020 Compound Labs, Inc.
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Ctrl+f for XXX to see all the modifications.
// uint96s are changed to uint256s for simplicity and safety.

// XXX: pragma solidity ^0.5.16;
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import './BOOGIE.sol';

contract Governor {
    /// @notice The name of this contract
    // XXX: string public constant name = "Compound Governor Alpha";
    string public constant name = "BOOGIE Governor";

    /// @notice The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
    // XXX: function quorumVotes() public pure returns (uint) { return 400000e18; } // 400,000 = 4% of Comp
    function quorumVotes() public view returns (uint) { return boogie.totalSupply() / 3; } // 33.33% of Supply

    /// @notice The number of votes required in order for a voter to become a proposer
    // function proposalThreshold() public pure returns (uint) { return 100000e18; } // 100,000 = 1% of Comp
    function proposalThreshold() public pure returns (uint) { return 1000e18; } // 1000 BOOGIE

    /// @notice The maximum number of actions that can be included in a proposal
    function proposalMaxOperations() public pure returns (uint) { return 10; } // 10 actions

    /// @notice The delay before voting on a proposal may take place, once proposed
    function votingDelay() public pure returns (uint) { return 1; } // 1 block

    /// @notice The duration of voting on a proposal, in blocks
    function votingPeriod() public pure returns (uint) { return 17280; } // ~3 days in blocks (assuming 15s blocks)

    /// @notice The address of the Compound Protocol Timelock
    TimelockInterface public timelock;

    /// @notice The address of the Compound governance token
    // XXX: CompInterface public comp;
    BOOGIE public boogie;

    /// @notice The address of the Governor Guardian
    address public guardian;

    /// @notice The total number of proposals
    uint public proposalCount;

    struct Proposal {
        // Unique id for looking up a proposal
        uint id;

        // Creator of the proposal
        address proposer;

        // The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint eta;

        // the ordered list of target addresses for calls to be made
        address[] targets;

        // The ordered list of values (i.e. msg.value) to be passed to the calls to be made
        uint[] values;

        // The ordered list of function signatures to be called
        string[] signatures;

        // The ordered list of calldata to be passed to each call
        bytes[] calldatas;

        // The block at which voting begins: holders must delegate their votes prior to this block
        uint startBlock;

        // The block at which voting ends: votes must be cast prior to this block
        uint endBlock;

        // Current number of votes in favor of this proposal
        uint forVotes;

        // Current number of votes in opposition to this proposal
        uint againstVotes;

        // Flag marking whether the proposal has been canceled
        bool canceled;

        // Flag marking whether the proposal has been executed
        bool executed;

        // Receipts of ballots for the entire set of voters
        mapping (address => Receipt) receipts;
    }

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        // Whether or not a vote has been cast
        bool hasVoted;

        // Whether or not the voter supports the proposal
        bool support;

        // The number of votes the voter had, which were cast
        uint256 votes;
    }

    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    /// @notice The official record of all proposals ever proposed
    mapping (uint => Proposal) public proposals;

    /// @notice The latest proposal for each proposer
    mapping (address => uint) public latestProposalIds;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,bool support)");

    /// @notice An event emitted when a new proposal is created
    event ProposalCreated(uint id, address proposer, address[] targets, uint[] values, string[] signatures, bytes[] calldatas, uint startBlock, uint endBlock, string description);

    /// @notice An event emitted when a vote has been cast on a proposal
    event VoteCast(address voter, uint proposalId, bool support, uint votes);

    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint id);

    /// @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint id, uint eta);

    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint id);

    constructor(address timelock_, address boogie_, address guardian_) public {
        timelock = TimelockInterface(timelock_);
        boogie = BOOGIE(boogie_);
        guardian = guardian_;
    }

    function propose(address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas, string memory description) public returns (uint) {
        require(boogie.getPriorVotes(msg.sender, sub256(block.number, 1)) > proposalThreshold(), "Governor::propose: proposer votes below proposal threshold");
        require(targets.length == values.length && targets.length == signatures.length && targets.length == calldatas.length, "Governor::propose: proposal function information arity mismatch");
        require(targets.length != 0, "Governor::propose: must provide actions");
        require(targets.length <= proposalMaxOperations(), "Governor::propose: too many actions");

        uint latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
          ProposalState proposersLatestProposalState = state(latestProposalId);
          require(proposersLatestProposalState != ProposalState.Active, "Governor::propose: one live proposal per proposer, found an already active proposal");
          require(proposersLatestProposalState != ProposalState.Pending, "Governor::propose: one live proposal per proposer, found an already pending proposal");
        }

        uint startBlock = add256(block.number, votingDelay());
        uint endBlock = add256(startBlock, votingPeriod());

        proposalCount++;
        Proposal memory newProposal = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            eta: 0,
            targets: targets,
            values: values,
            signatures: signatures,
            calldatas: calldatas,
            startBlock: startBlock,
            endBlock: endBlock,
            forVotes: 0,
            againstVotes: 0,
            canceled: false,
            executed: false
        });

        proposals[newProposal.id] = newProposal;
        latestProposalIds[newProposal.proposer] = newProposal.id;

        emit ProposalCreated(newProposal.id, msg.sender, targets, values, signatures, calldatas, startBlock, endBlock, description);
        return newProposal.id;
    }

    function queue(uint proposalId) public {
        require(state(proposalId) == ProposalState.Succeeded, "Governor::queue: proposal can only be queued if it is succeeded");
        Proposal storage proposal = proposals[proposalId];
        uint eta = add256(block.timestamp, timelock.delay());
        for (uint i = 0; i < proposal.targets.length; i++) {
            _queueOrRevert(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], eta);
        }
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    function _queueOrRevert(address target, uint value, string memory signature, bytes memory data, uint eta) internal {
        require(!timelock.queuedTransactions(keccak256(abi.encode(target, value, signature, data, eta))), "Governor::_queueOrRevert: proposal action already queued at eta");
        timelock.queueTransaction(target, value, signature, data, eta);
    }

    function execute(uint proposalId) public payable {
        require(state(proposalId) == ProposalState.Queued, "Governor::execute: proposal can only be executed if it is queued");
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction{value: proposal.values[i]}(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], proposal.eta);
        }
        emit ProposalExecuted(proposalId);
    }

    function cancel(uint proposalId) public {
        ProposalState state = state(proposalId);
        require(state != ProposalState.Executed, "Governor::cancel: cannot cancel executed proposal");

        Proposal storage proposal = proposals[proposalId];
        require(msg.sender == guardian || boogie.getPriorVotes(proposal.proposer, sub256(block.number, 1)) < proposalThreshold(), "Governor::cancel: proposer above threshold");

        proposal.canceled = true;
        for (uint i = 0; i < proposal.targets.length; i++) {
            timelock.cancelTransaction(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], proposal.eta);
        }

        emit ProposalCanceled(proposalId);
    }

    function getActions(uint proposalId) public view returns (address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas) {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    function getReceipt(uint proposalId, address voter) public view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    function state(uint proposalId) public view returns (ProposalState) {
        require(proposalCount >= proposalId && proposalId > 0, "Governor::state: invalid proposal id");
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes()) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= add256(proposal.eta, timelock.GRACE_PERIOD())) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    function castVote(uint proposalId, bool support) public {
        return _castVote(msg.sender, proposalId, support);
    }

    function castVoteBySig(uint proposalId, bool support, uint8 v, bytes32 r, bytes32 s) public {
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainId(), address(this)));
        bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "Governor::castVoteBySig: invalid signature");
        return _castVote(signatory, proposalId, support);
    }

    function _castVote(address voter, uint proposalId, bool support) internal {
        require(state(proposalId) == ProposalState.Active, "Governor::_castVote: voting is closed");
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(receipt.hasVoted == false, "Governor::_castVote: voter already voted");
        uint256 votes = boogie.getPriorVotes(voter, proposal.startBlock);

        if (support) {
            proposal.forVotes = add256(proposal.forVotes, votes);
        } else {
            proposal.againstVotes = add256(proposal.againstVotes, votes);
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        emit VoteCast(voter, proposalId, support, votes);
    }

    function __acceptAdmin() public {
        require(msg.sender == guardian, "Governor::__acceptAdmin: sender must be gov guardian");
        timelock.acceptAdmin();
    }

    function __abdicate() public {
        require(msg.sender == guardian, "Governor::__abdicate: sender must be gov guardian");
        guardian = address(0);
    }

    function __queueSetTimelockPendingAdmin(address newPendingAdmin, uint eta) public {
        require(msg.sender == guardian, "Governor::__queueSetTimelockPendingAdmin: sender must be gov guardian");
        timelock.queueTransaction(address(timelock), 0, "setPendingAdmin(address)", abi.encode(newPendingAdmin), eta);
    }

    function __executeSetTimelockPendingAdmin(address newPendingAdmin, uint eta) public {
        require(msg.sender == guardian, "Governor::__executeSetTimelockPendingAdmin: sender must be gov guardian");
        timelock.executeTransaction(address(timelock), 0, "setPendingAdmin(address)", abi.encode(newPendingAdmin), eta);
    }

    function add256(uint256 a, uint256 b) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, "addition overflow");
        return c;
    }

    function sub256(uint256 a, uint256 b) internal pure returns (uint) {
        require(b <= a, "subtraction underflow");
        return a - b;
    }

    function getChainId() internal pure returns (uint) {
        uint chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}

interface TimelockInterface {
    function delay() external view returns (uint);
    function GRACE_PERIOD() external view returns (uint);
    function acceptAdmin() external;
    function queuedTransactions(bytes32 hash) external view returns (bool);
    function queueTransaction(address target, uint value, string calldata signature, bytes calldata data, uint eta) external returns (bytes32);
    function cancelTransaction(address target, uint value, string calldata signature, bytes calldata data, uint eta) external;
    function executeTransaction(address target, uint value, string calldata signature, bytes calldata data, uint eta) external payable returns (bytes memory);
}pragma solidity ^0.6.12;

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the number of decimal places.
     */
    function decimals() external view returns (uint8);

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
}pragma solidity ^0.6.12;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}pragma solidity ^0.6.12;

// File: @uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}pragma solidity ^0.6.12;

import './Context.sol';

// File: @openzeppelin/contracts/access/Ownable.sol

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
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
    constructor () internal {
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
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}/*
@website https://boogie.finance
@authors Proof, sol_dev, Zoma, Mr Fahrenheit, Boogie
@auditors Aegis DAO, Sherlock Security
*/

pragma solidity ^0.6.12;

import './Ownable.sol';
import './SafeMath.sol';
import './SafeERC20.sol';
import './IERC20.sol';
import './IUniswapV2Router02.sol';
import './BOOGIE.sol';
import './Bar.sol';

// The Rave staking contract becomes active after the max supply it hit, and is where BOOGIE-ETH LP token stakers will continue to receive dividends from other projects in the BOOGIE ecosystem
contract Rave is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user
    struct UserInfo {
        uint256 staked; // How many BOOGIE-ETH LP tokens the user has staked
        uint256 rewardDebt; // Reward debt. Works the same as in the Bar contract
        uint256 claimed; // Tracks the amount of BOOGIE claimed by the user
    }

    // The BOOGIE TOKEN!
    BOOGIE public boogie;
    // The Bar contract
    Bar public bar;
    // The BOOGIE-ETH Uniswap LP token
    IERC20 public boogiePool;
    // The Uniswap v2 Router
    IUniswapV2Router02 public uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    // WETH
    IERC20 public weth;

    // Info of each user that stakes BOOGIE-ETH LP tokens
    mapping (address => UserInfo) public userInfo;
    // The amount of BOOGIE sent to this contract before it became active
    uint256 public initialBoogieReward = 0;
    // 5% of the initialBoogieReward will be rewarded to stakers per day for 100 days
    uint256 public initialBoogieRewardPerDay;
    // How often the initial 5% payouts can be processed
    uint256 public constant INITIAL_PAYOUT_INTERVAL = 24 hours;
    // Number of days over which the initial payouts will be distributed
    uint256 public constant NUM_PAYOUT_DAYS = 20;
    // The unstaking fee that is used to increase locked liquidity and reward Rave stakers (1 = 0.1%). Defaults to 10%
    uint256 public unstakingFee = 100;
    // The amount of BOOGIE-ETH LP tokens kept by the unstaking fee that will be converted to BOOGIE and distributed to stakers (1 = 0.1%). Defaults to 50%
    uint256 public unstakingFeeConvertToBoogieAmount = 500;
    // When the first 1% payout can be processed (timestamp). It will be 24 hours after the Rave contract is activated
    uint256 public startTime;
    // When the last 1% payout was processed (timestamp)
    uint256 public lastPayout;
    // The total amount of pending BOOGIE available for stakers to claim
    uint256 public totalPendingBoogie;
    // Accumulated BOOGIEs per share, times 1e12.
    uint256 public accBoogiePerShare;
    // The total amount of BOOGIE-ETH LP tokens staked in the contract
    uint256 public totalStaked;
    // Becomes true once the 'activate' function called by the Bar contract when the max BOOGIE supply is hit
    bool public active = false;

    event Stake(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 boogieAmount);
    event Withdraw(address indexed user, uint256 amount);
    event BoogieRewardAdded(address indexed user, uint256 boogieReward);
    event EthRewardAdded(address indexed user, uint256 ethReward);

    constructor(BOOGIE _boogie, Bar _bar) public {
        bar = _bar;
        boogie = _boogie;
        boogiePool = IERC20(bar.boogiePoolAddress());
        weth = IERC20(uniswapRouter.WETH());
    }

    receive() external payable {
        emit EthRewardAdded(msg.sender, msg.value);
    }

    function activate() public {
        require(active != true, "already active");
        require(boogie.maxSupplyHit() == true, "too soon");

        active = true;

        // Now that the Rave staking contract is active, reward 5% of the initialBoogieReward per day for 20 days
        startTime = block.timestamp + INITIAL_PAYOUT_INTERVAL; // The first payout can be processed 24 hours after activation
        lastPayout = startTime;
        initialBoogieRewardPerDay = initialBoogieReward.div(NUM_PAYOUT_DAYS);
    }

    // The _transfer function in the BOOGIE contract calls this to let the Rave contract know that it received the specified amount of BOOGIE to be distributed to stakers 
    function addBoogieReward(address _from, uint256 _amount) public {
        require(msg.sender == address(boogie), "not boogie contract");
        require(bar.boogiePoolActive() == true, "no boogie pool");
        require(_amount > 0, "no boogie");

        if (active != true || totalStaked == 0) {
            initialBoogieReward = initialBoogieReward.add(_amount);
        } else {
            totalPendingBoogie = totalPendingBoogie.add(_amount);
            accBoogiePerShare = accBoogiePerShare.add(_amount.mul(1e12).div(totalStaked));
        }

        emit BoogieRewardAdded(_from, _amount);
    }

    // Allows external sources to add ETH to the contract which is used to buy and then distribute BOOGIE to stakers
    function addEthReward() public payable {
        require(bar.boogiePoolActive() == true, "no boogie pool");

        // We will purchase BOOGIE with all of the ETH in the contract in case some was sent directly to the contract instead of using addEthReward
        uint256 ethBalance = address(this).balance;
        require(ethBalance > 0, "no eth");

        // Use the ETH to buyback BOOGIE which will be distributed to stakers
        _buyBoogie(ethBalance);

        // The _transfer function in the BOOGIE contract calls the Rave contract's updateBoogieReward function so we don't need to update the balances after buying the BOOGIE
        emit EthRewardAdded(msg.sender, msg.value);
    }

    // Internal function to buy back BOOGIE with the amount of ETH specified
    function _buyBoogie(uint256 _amount) internal {
        uint256 deadline = block.timestamp + 5 minutes;
        address[] memory boogiePath = new address[](2);
        boogiePath[0] = address(weth);
        boogiePath[1] = address(boogie);
        uniswapRouter.swapExactETHForTokens{value: _amount}(0, boogiePath, address(this), deadline);
    }

    // Handles paying out the initialBoogieReward over 20 days
    function _processInitialPayouts() internal {
        if (active != true || block.timestamp < startTime || initialBoogieReward == 0 || totalStaked == 0) return;

        // How many days since last payout?
        uint256 daysSinceLastPayout = (block.timestamp - lastPayout) / INITIAL_PAYOUT_INTERVAL;

        // If less than 1, don't do anything
        if (daysSinceLastPayout == 0) return;

        // Work out how many payouts have been missed
        uint256 nextPayoutNumber = (block.timestamp - startTime) / INITIAL_PAYOUT_INTERVAL;
        uint256 previousPayoutNumber = nextPayoutNumber - daysSinceLastPayout;

        // Calculate how much additional reward we have to hand out
        uint256 boogieReward = rewardAtPayout(nextPayoutNumber) - rewardAtPayout(previousPayoutNumber);
        if (boogieReward > initialBoogieReward) boogieReward = initialBoogieReward;
        initialBoogieReward = initialBoogieReward.sub(boogieReward);

        // Payout the boogieReward to the stakers
        totalPendingBoogie = totalPendingBoogie.add(boogieReward);
        accBoogiePerShare = accBoogiePerShare.add(boogieReward.mul(1e12).div(totalStaked));

        // Update lastPayout time
        lastPayout += (daysSinceLastPayout * INITIAL_PAYOUT_INTERVAL);
    }

    // Handles claiming the user's pending BOOGIE rewards
    function _claimReward(address _user) internal {
        UserInfo storage user = userInfo[_user];
        if (user.staked > 0) {
            uint256 pendingBoogieReward = user.staked.mul(accBoogiePerShare).div(1e12).sub(user.rewardDebt);
            if (pendingBoogieReward > 0) {
                totalPendingBoogie = totalPendingBoogie.sub(pendingBoogieReward);
                user.claimed += pendingBoogieReward;
                _safeBoogieTransfer(_user, pendingBoogieReward);
                emit Claim(_user, pendingBoogieReward);
            }
        }
    }

    // Stake BOOGIE-ETH LP tokens to get rewarded with more BOOGIE
    function stake(uint256 _amount) public {
        stakeFor(msg.sender, _amount);
    }

    // Stake BOOGIE-ETH LP tokens on behalf of another address
    function stakeFor(address _user, uint256 _amount) public {
        require(active == true, "not active");
        require(_amount > 0, "stake something");

        _processInitialPayouts();

        // Claim any pending BOOGIE
        _claimReward(_user);

        boogiePool.safeTransferFrom(address(msg.sender), address(this), _amount);

        UserInfo storage user = userInfo[_user];
        totalStaked = totalStaked.add(_amount);
        user.staked = user.staked.add(_amount);
        user.rewardDebt = user.staked.mul(accBoogiePerShare).div(1e12);
        emit Stake(_user, _amount);
    }

    // Claim earned BOOGIE. Claiming won't work until active == true
    function claim() public {
        require(active == true, "not active");
        UserInfo storage user = userInfo[msg.sender];
        require(user.staked > 0, "no stake");
        
        _processInitialPayouts();

        // Claim any pending BOOGIE
        _claimReward(msg.sender);

        user.rewardDebt = user.staked.mul(accBoogiePerShare).div(1e12);
    }

    // Unstake and withdraw BOOGIE-ETH LP tokens and any pending BOOGIE rewards. There is a 10% unstaking fee, meaning the user will only receive 90% of their LP tokens back.
    // For the LP tokens kept by the unstaking fee, 50% will get locked forever in the BOOGIE contract, and 50% will get converted to BOOGIE and distributed to stakers.
    function withdraw(uint256 _amount) public {
        require(active == true, "not active");
        UserInfo storage user = userInfo[msg.sender];
        require(_amount > 0 && user.staked >= _amount, "withdraw: not good");
        
        _processInitialPayouts();

        uint256 unstakingFeeAmount = _amount.mul(unstakingFee).div(1000);
        uint256 remainingUserAmount = _amount.sub(unstakingFeeAmount);

        // Half of the LP tokens kept by the unstaking fee will be locked forever in the BOOGIE contract, the other half will be converted to BOOGIE and distributed to stakers
        uint256 lpTokensToConvertToBoogie = unstakingFeeAmount.mul(unstakingFeeConvertToBoogieAmount).div(1000);
        uint256 lpTokensToLock = unstakingFeeAmount.sub(lpTokensToConvertToBoogie);

        // Remove the liquidity from the Uniswap BOOGIE-ETH pool and buy BOOGIE with the ETH received
        // The _transfer function in the BOOGIE.sol contract automatically calls rave.addBoogieReward() so we don't have to in this function
        if (lpTokensToConvertToBoogie > 0) {
            boogiePool.safeApprove(address(uniswapRouter), lpTokensToConvertToBoogie);
            uniswapRouter.removeLiquidityETHSupportingFeeOnTransferTokens(address(boogie), lpTokensToConvertToBoogie, 0, 0, address(this), block.timestamp + 5 minutes);
            addEthReward();
        }

        // Permanently lock the LP tokens in the BOOGIE contract
        if (lpTokensToLock > 0) boogiePool.transfer(address(boogie), lpTokensToLock);

        // Claim any pending BOOGIE
        _claimReward(msg.sender);

        totalStaked = totalStaked.sub(_amount);
        user.staked = user.staked.sub(_amount);
        boogiePool.safeTransfer(address(msg.sender), remainingUserAmount);
        user.rewardDebt = user.staked.mul(accBoogiePerShare).div(1e12);
        emit Withdraw(msg.sender, remainingUserAmount);
    }

    // Internal function to safely transfer BOOGIE in case there is a rounding error
    function _safeBoogieTransfer(address _to, uint256 _amount) internal {
        uint256 boogieBal = boogie.balanceOf(address(this));
        if (_amount > boogieBal) {
            boogie.transfer(_to, boogieBal);
        } else {
            boogie.transfer(_to, _amount);
        }
    }

    // Sets the unstaking fee. Can't be higher than 10%. _convertToBoogieAmount is the % of the LP tokens from the unstaking fee that will be converted to BOOGIE and distributed to stakers.
    // unstakingFee - unstakingFeeConvertToBoogieAmount = The % of the LP tokens from the unstaking fee that will be permanently locked in the BOOGIE contract
    function setUnstakingFee(uint256 _unstakingFee, uint256 _convertToBoogieAmount) public onlyOwner {
        require(_unstakingFee <= 100, "over 10%");
        require(_convertToBoogieAmount <= 1000, "bad amount");
        unstakingFee = _unstakingFee;
        unstakingFeeConvertToBoogieAmount = _convertToBoogieAmount;
    }

    // Function to recover ERC20 tokens accidentally sent to the contract.
    // BOOGIE and BOOGIE-ETH LP tokens (the only 2 ERC2O's that should be in this contract) can't be withdrawn this way.
    function recoverERC20(address _tokenAddress) public onlyOwner {
        require(_tokenAddress != address(boogie) && _tokenAddress != address(boogiePool));
        IERC20 token = IERC20(_tokenAddress);
        uint256 tokenBalance = token.balanceOf(address(this));
        token.transfer(msg.sender, tokenBalance);
    }

    function payoutNumber() public view returns (uint256) {
        if (block.timestamp < startTime) return 0;

        uint256 payout = (block.timestamp - startTime).div(INITIAL_PAYOUT_INTERVAL);
        if (payout > NUM_PAYOUT_DAYS) return NUM_PAYOUT_DAYS;
        else return payout;
    }

    function timeUntilNextPayout() public view returns (uint256) {
        if (initialBoogieReward == 0) return 0;
        else {
            uint256 payout = payoutNumber();
            uint256 nextPayout = startTime.add((payout + 1).mul(INITIAL_PAYOUT_INTERVAL));
            return nextPayout - block.timestamp;
        }
    }

    function rewardAtPayout(uint256 _payoutNumber) public view returns (uint256) {
        if (_payoutNumber == 0) return 0;
        return initialBoogieRewardPerDay * _payoutNumber;
    }

    function getAllInfoFor(address _user) external view returns (bool isActive, uint256[12] memory info) {
        isActive = active;
        info[0] = boogie.balanceOf(address(this));
        info[1] = initialBoogieReward;
        info[2] = totalPendingBoogie;
        info[3] = startTime;
        info[4] = lastPayout;
        info[5] = totalStaked;
        info[6] = boogie.balanceOf(_user);
        if (bar.boogiePoolActive()) {
            info[7] = boogiePool.balanceOf(_user);
            info[8] = boogiePool.allowance(_user, address(this));
        }
        info[9] = userInfo[_user].staked;
        info[10] = userInfo[_user].staked.mul(accBoogiePerShare).div(1e12).sub(userInfo[_user].rewardDebt);
        info[11] = userInfo[_user].claimed;
    }
}pragma solidity ^0.6.12;

import './SafeMath.sol';
import './Address.sol';
import './IERC20.sol';

// File: @openzeppelin/contracts/token/ERC20/SafeERC20.sol

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}pragma solidity ^0.6.12;

// File: @openzeppelin/contracts/math/SafeMath.sol

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
     *
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
     *
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
     *
     * - Subtraction cannot overflow.
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
     *
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
     *
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
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
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
     *
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
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}// COPIED FROM https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorAlpha.sol
// Copyright 2020 Compound Labs, Inc.
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Ctrl+f for XXX to see all the modifications.

// XXX: pragma solidity ^0.5.16;
pragma solidity ^0.6.12;

import './SafeMath.sol';

contract Timelock {
    using SafeMath for uint;

    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint indexed newDelay);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature,  bytes data, uint eta);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature,  bytes data, uint eta);
    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature, bytes data, uint eta);

    uint public constant GRACE_PERIOD = 14 days;
    uint public constant MINIMUM_DELAY = 12 hours;
    uint public constant MAXIMUM_DELAY = 30 days;

    address public admin;
    address public pendingAdmin;
    uint public delay;
    bool public admin_initialized;

    mapping (bytes32 => bool) public queuedTransactions;


    constructor(address admin_, uint delay_) public {
        require(delay_ >= MINIMUM_DELAY, "Timelock::constructor: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::constructor: Delay must not exceed maximum delay.");

        admin = admin_;
        delay = delay_;
        admin_initialized = false;
    }

    // XXX: function() external payable { }
    receive() external payable { }

    function setDelay(uint delay_) public {
        require(msg.sender == address(this), "Timelock::setDelay: Call must come from Timelock.");
        require(delay_ >= MINIMUM_DELAY, "Timelock::setDelay: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::setDelay: Delay must not exceed maximum delay.");
        delay = delay_;

        emit NewDelay(delay);
    }

    function acceptAdmin() public {
        require(msg.sender == pendingAdmin, "Timelock::acceptAdmin: Call must come from pendingAdmin.");
        admin = msg.sender;
        pendingAdmin = address(0);

        emit NewAdmin(admin);
    }

    function setPendingAdmin(address pendingAdmin_) public {
        // allows one time setting of admin for deployment purposes
        if (admin_initialized) {
            require(msg.sender == address(this), "Timelock::setPendingAdmin: Call must come from Timelock.");
        } else {
            require(msg.sender == admin, "Timelock::setPendingAdmin: First call must come from admin.");
            admin_initialized = true;
        }
        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(pendingAdmin);
    }

    function queueTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public returns (bytes32) {
        require(msg.sender == admin, "Timelock::queueTransaction: Call must come from admin.");
        require(eta >= getBlockTimestamp().add(delay), "Timelock::queueTransaction: Estimated execution block must satisfy delay.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public {
        require(msg.sender == admin, "Timelock::cancelTransaction: Call must come from admin.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public payable returns (bytes memory) {
        require(msg.sender == admin, "Timelock::executeTransaction: Call must come from admin.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "Timelock::executeTransaction: Transaction hasn't been queued.");
        require(getBlockTimestamp() >= eta, "Timelock::executeTransaction: Transaction hasn't surpassed time lock.");
        require(getBlockTimestamp() <= eta.add(GRACE_PERIOD), "Timelock::executeTransaction: Transaction is stale.");

        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "Timelock::executeTransaction: Transaction execution reverted.");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

    function getBlockTimestamp() internal view returns (uint) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }
}