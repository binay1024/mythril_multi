pragma solidity ^0.5.7;

pragma solidity ^0.5.7;

import "./IERC20.sol";
import "./Ownable.sol";
import "./Managed.sol";
import "./BlobCoin.sol";
import "./AllowanceChecker.sol";
import "./ERC20Burnable.sol";
import "./IDissolve.sol";

contract Dissolve is IDissolve, Managed, AllowanceChecker {

    struct Request {
        uint256 totalAmount; //100 blobs
        uint256 dissolvedAmount; //10 blobs
        address requesterAddress;
        RequestState dissolveRequestState;
    }

    Request[] public allDissolvesRequests;

    mapping(address => uint256[]) public holderToDissolveRequestId;
    mapping(uint256  => address) public dissolveRequestIdToHolder;

    event DissolveRequestCreated(
        uint256 _dissolveId,
        uint256 coinsAmount,
        address requesterAddress
    );

    event DissolveRequestRemoved(
        uint256 _dissolveId,
        uint256 coinsAmountUnlocked,
        address requesterAddress
    );

    event CoinsDissolve(
        uint256 _dissolveId,
        uint256 requestedAmount,
        uint256 dissolvedAmount
    );

    modifier requireDissolveIdExisting(uint256 _dissolveId) {
        require(
            _dissolveId < allDissolvesRequests.length,
            ERROR_ACCESS_DENIED
        );
        _;
    }

    modifier requireHasEnoughBlobs(uint256 _amount) {
        BlobCoin blobCoin = BlobCoin(
            management.contractRegistry(CONTRACT_TOKEN)
        );
        uint256 requesterBalance = blobCoin.balanceOf(msg.sender);
        require(
            requesterBalance >= _amount &&
            blobCoin.allowedBalance(msg.sender, requesterBalance) >= _amount,
            ERROR_ACCESS_DENIED
        );
        _;
    }

    constructor(address _managementAddress)
    public
    Managed(_managementAddress)
    {}

    function externalDissolve(
        uint256 _dissolveId,
        uint256 _maxAmount
    )
    external
    requirePermission(CAN_EXCHANGE_COINS)
    returns (bool)
    {
        internalDissolve(
            _dissolveId,
            _maxAmount
        );
        return true;
    }

    function externalMultiDissolve(
        uint256[] calldata _dissolveIds,
        uint256 _maxAmount
    )
    external
    requirePermission(CAN_EXCHANGE_COINS)
    {
        for (uint256 i = 0; i < _dissolveIds.length; i++) {
            if (
                allDissolvesRequests[_dissolveIds[i]].dissolveRequestState != RequestState.PaidPartially &&
                allDissolvesRequests[_dissolveIds[i]].dissolveRequestState != RequestState.Pending
            ) {
                continue;
            }
            internalDissolve(
                _dissolveIds[i],
                _maxAmount
            );
        }

    }

    function removeDissolveRequest(
        uint256 _dissolveId
    )
    public
    requireContractExistsInRegistry(CONTRACT_TOKEN)
    returns (bool)
    {
        Request storage request = allDissolvesRequests[
        _dissolveId
        ];
        require(
            msg.sender == request.requesterAddress,
            ERROR_ACCESS_DENIED
        );
        require(
            request.dissolveRequestState == RequestState.PaidPartially ||
            request.dissolveRequestState == RequestState.Pending,
            ERROR_NOT_AVAILABLE
        );
        request.dissolveRequestState = RequestState.Refunded;
        uint256 amountToUnlock = request.totalAmount
        .sub(request.dissolvedAmount);
        request.totalAmount = request.dissolvedAmount;
        BlobCoin(management.contractRegistry(CONTRACT_TOKEN)).unlock(
            msg.sender,
            amountToUnlock
        );
        emit DissolveRequestRemoved(
            _dissolveId,
            amountToUnlock,
            msg.sender
        );
        return true;
    }

    function createDissolveRequest(uint256 _value)
    public
    requireContractExistsInRegistry(CONTRACT_TOKEN)
    requireHasEnoughBlobs(_value)
    returns (bool)
    {
        holderToDissolveRequestId[msg.sender].push(
            allDissolvesRequests.length
        );
        dissolveRequestIdToHolder[
        allDissolvesRequests.length
        ] = msg.sender;
        emit DissolveRequestCreated(
            allDissolvesRequests.length,
            _value,
            msg.sender
        );
        allDissolvesRequests.push(
            Request(
                _value,
                0,
                msg.sender,
                RequestState.Pending
            )
        );

        BlobCoin(management.contractRegistry(CONTRACT_TOKEN)).lock(
            msg.sender,
            _value
        );
        return true;
    }

    function internalDissolve(
        uint256 _dissolveId,
        uint256 _maxAmount
    )
    internal
    requireDissolveIdExisting(_dissolveId)
    {
        Request storage request = allDissolvesRequests[
        _dissolveId
        ];
        require(
            request.dissolveRequestState == RequestState.PaidPartially ||
            request.dissolveRequestState == RequestState.Pending,
            ERROR_NOT_AVAILABLE
        );
        uint256 amountToWithdraw = request.totalAmount
        .sub(request.dissolvedAmount);
        if (_maxAmount < amountToWithdraw) {
            amountToWithdraw = _maxAmount;
        }

        request.dissolvedAmount = request.dissolvedAmount
        .add(amountToWithdraw);

        if (request.totalAmount > request.dissolvedAmount) {
            request.dissolveRequestState = RequestState.PaidPartially;
        } else {
            request.dissolveRequestState = RequestState.FullyPaid;
        }
        internalBurnCoins(
            request.requesterAddress,
            amountToWithdraw
        );

        internalTransferCoinsBack(
            amountToWithdraw,
            request.requesterAddress
        );

        emit CoinsDissolve(
            _dissolveId,
            request.totalAmount,
            amountToWithdraw
        );
    }

    function internalBurnCoins(address _address, uint256 _amount) internal {
        ERC20Burnable(
            management.contractRegistry(CONTRACT_TOKEN)
        ).burnFrom(_address, _amount);
    }

    function internalTransferCoinsBack(
        uint256 _blobsAmountToWithdraw,
        address _coinsReceiver
    )
    internal
    {
        BlobCoin blobCoin = BlobCoin(
            management.contractRegistry(CONTRACT_TOKEN)
        );
        address[] memory permittedCoinsAddresses;
        uint256[] memory coinsAmount;
        (
        permittedCoinsAddresses,
        coinsAmount
        ) = management.calculateCoinsAmountByUSD(
            management.calculateUSDByBlobs(_blobsAmountToWithdraw).div(10**uint256(blobCoin.decimals()))
        );
        for (uint256 i = 1; i < permittedCoinsAddresses.length; i++) {
            if (
                coinsAmount[i] == 0 ||
                permittedCoinsAddresses[i] == address(0)
            ) {
                continue;
            }
            require(
                getCoinAllowance(
                    permittedCoinsAddresses[i],
                    management.coinsHolder()
                ) >= coinsAmount[i],
                ERROR_BALANCE_IS_NOT_ALLOWED
            );
            IERC20(permittedCoinsAddresses[i]).transferFrom(
                management.coinsHolder(),
                _coinsReceiver,
                coinsAmount[i]
            );
        }
    }
}pragma solidity ^0.5.7;

import "./IERC20.sol";
import "./Constants.sol";
import "./IAllowanceChecker.sol";


contract AllowanceChecker is Constants {

    modifier requireAllowance(
        address _coinAddress,
        address _coinHolder,
        uint256 _expectedBalance
    ) {
        require(
            getCoinAllowance(
                _coinAddress,
                _coinHolder
            ) >= _expectedBalance,
            ERROR_BALANCE_IS_NOT_ALLOWED
        );
        _;
    }

    function getCoinAllowance(
        address _coinAddress,
        address _coinHolder
    )
    internal
    view
    returns (uint256)
    {
        return IERC20(_coinAddress).allowance(
            _coinHolder,
            address(this)
        );
    }
}pragma solidity ^0.5.7;

import "./ERC20Detailed.sol";
import "./ERC20Burnable.sol";
import "./Ownable.sol";
import "./LockupContract.sol";
import "./IERC20Mintable.sol";

/*solium-disable-next-line*/
contract BlobCoin is LockupContract, IERC20Mintable, ERC20Detailed("Blob Coin", "BLOB", 18), ERC20Burnable {

    event Burn(address indexed burner, uint256 amount);

    constructor(address _management)
    public
    LockupContract(_management)
    {}

    /**
    * @dev Function to mint coins
    * @param to The address that will receive the minted tokens.
    * @param value The amount of tokens to mint.
    * @return A boolean that indicates if the operation was successful.
    */
    function mint(address to, uint256 value)
    public
    requirePermission(CAN_MINT_COINS)
    returns (bool)
    {
        _mint(to, value);
        return true;
    }

    /**
    * @dev Internal function that burns an amount of the token of a given
    * account, deducting from the sender's allowance for said account
    * or by address with permission CAN_BURN_COINS. Uses the
    * internal burn function.
    * Emits an Burn event (reflecting the burned amount).
    * Emits an Approval event (reflecting the reduced allowance).
    * @param account The account whose tokens will be burnt.
    * @param value The amount that will be burned.
    */
    function _burnFrom(address account, uint256 value) internal {
        emit Burn(msg.sender, value);
        if (
            false == hasPermission(msg.sender, CAN_BURN_COINS)
        ) {
            super._burnFrom(account, value);
        } else {
            _burn(account, value);
        }
    }

    /**
    * @dev  Overridden Transfer token for a specified addresses
    * @param from The address to transfer from.
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
    function _transfer(address from, address to, uint256 value) internal {
        require(
            isTransferAllowed(from, value, balanceOf(from)) == true,
            ERROR_WRONG_AMOUNT
        );
        return super._transfer(from, to, value);
    }
}pragma solidity ^0.5.6;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./IManagement.sol";
import "./Constants.sol";
import "./ICoinExchangeRates.sol";


/*solium-disable-next-line*/
contract CoinExchangeRates is ICoinExchangeRates, IManagement, Constants, Ownable {
    using SafeMath for uint256;

    uint256 private blobCoinPrice_;

    address[] private permittedCoinsAddresses_;

    mapping(address => uint256) public stableCoinsPrices;
    mapping(address => uint256) public stableCoinsDecimals;
    mapping(address => uint256) public priceUpdatedAt;
    mapping(address => uint256) public stableCoinsToProportion;

    mapping(address => uint256) public permittedTokensToId;

    modifier requirePermission(uint256 _permissionBit) {
        require(
            hasPermission(msg.sender, _permissionBit),
            ERROR_ACCESS_DENIED
        );
        _;
    }

    event PriceUpdated(uint256 newPrice);

    constructor(uint256 _blobCoinPrice)
    public
    {
        blobCoinPrice_ = _blobCoinPrice;
        permittedCoinsAddresses_.push(address(0));
    }

    // 5 00000
    function setBlobCoinPrice(uint256 _blobCoinPrice)
    public
    requirePermission(CAN_REGISTER_COINS)
    {
        blobCoinPrice_ = _blobCoinPrice;
        emit PriceUpdated(_blobCoinPrice);
    }

    function setCoinsPricesInUSD(
        address[] memory _coinsAddresses,
        uint256[] memory _prices
    )
    public
    requirePermission(CAN_REGISTER_COINS)
    returns(bool)
    {
        require(
            _coinsAddresses.length == _prices.length,
            ERROR_WRONG_AMOUNT
        );

        for (uint256 i = 0; i < _coinsAddresses.length; i++) {
            setCoinPrice(_coinsAddresses[i], _prices[i]);
        }
        return true;
    }

    function setCoinsCoverageProportion(
        address[] memory _coinsAddresses,
        uint256[] memory _percentageProportion
    )
    public
    requirePermission(CAN_REGISTER_COINS)
    returns(bool)
    {
        require(
            _coinsAddresses.length == _percentageProportion.length,
            ERROR_WRONG_AMOUNT
        );
        uint256 totalProportion;
        for (uint256 i = 0; i < _coinsAddresses.length; i++) {
            require(
                hasPermission(_coinsAddresses[i], PERMITTED_COINS),
                ERROR_ACCESS_DENIED
            );
            stableCoinsToProportion[
            _coinsAddresses[i]
            ] = _percentageProportion[i];
            totalProportion = totalProportion.add(_percentageProportion[i]);
        }
        require(totalProportion == PERCENTS_ABS_MAX, ERROR_WRONG_AMOUNT);
        return true;
    }

    function calculateUSDByBlobs(uint256 _blobsAmount)
    public
    view
    returns(uint256)
    {
        uint256 coefficientWithoutFee = PERCENTS_ABS_MAX
        .sub(getFeePercentage());

        return _blobsAmount
        .mul(blobCoinPrice())
        .mul(coefficientWithoutFee)
        .div(PERCENTS_ABS_MAX);
    }

    function calculateUsdByCoin(
        address _stableCoinAddress,
        uint256 _coinsAmount
    )
    public
    view
    returns (uint256)
    {
        uint256 coinDecimals = stableCoinsDecimals[_stableCoinAddress];
        uint256 coinsAmount = _coinsAmount;
        if (coinDecimals < 18) {
            coinsAmount = _coinsAmount.mul(1e18).div(10 ** coinDecimals);
        }
        return getCoinPrice(_stableCoinAddress).mul(coinsAmount);
    }

    function calculateCoinsAmountByUSD(
        uint256 _usdAmount
    )
    public
    view
    returns (address[] memory, uint256[] memory)
    {
        uint256[] memory coinsAmount = new uint[](
            permittedCoinsAddresses_.length
        );
        for (uint256 i = 1; i < permittedCoinsAddresses_.length; i++) {
            coinsAmount[i] = _usdAmount
            .mul(10**stableCoinsDecimals[permittedCoinsAddresses_[i]])
            .mul(stableCoinsToProportion[permittedCoinsAddresses_[i]])
            .div(getCoinPrice(permittedCoinsAddresses_[i]))
            .div(PERCENTS_ABS_MAX);
        }
        return (permittedCoinsAddresses_, coinsAmount);
    }

    function calculateBlobsAmount(
        address _stableCoinAddress,
        uint256 _coinsAmount
    )
    public
    view
    returns (uint256)
    {

        return calculateUsdByCoin(_stableCoinAddress, _coinsAmount)
        .div(blobCoinPrice());
    }

    function coinPriceUpdatedAt(address _stableCoinAddress)
    public
    view
    returns(uint256)
    {
        return priceUpdatedAt[_stableCoinAddress];
    }

    function getCoinPrice(address _stableCoinAddress)
    public
    view
    returns(uint256)
    {
        return stableCoinsPrices[_stableCoinAddress];
    }

    function permittedCoinsAddresses()
    public
    view
    returns (address[] memory)
    {
        return permittedCoinsAddresses_;
    }

    function blobCoinPrice()
    public
    view
    returns (uint256)
    {
        return blobCoinPrice_;
    }

    function setCoinPrice(address _stableCoinAddress, uint256 _price)
    internal
    {
        require(
            hasPermission(_stableCoinAddress, PERMITTED_COINS),
            ERROR_ACCESS_DENIED
        );
        stableCoinsPrices[_stableCoinAddress] = _price;
        priceUpdatedAt[_stableCoinAddress] = block.timestamp;
    }

    function internalSetPermissionsForCoins(
        address _address,
        bool _value,
        uint256 _decimals
    )
    internal
    {
        stableCoinsDecimals[_address] = _decimals;
        if (true == _value) {
            require(permittedTokensToId[_address] == 0, ERROR_COIN_REGISTERED);
            permittedTokensToId[_address] = permittedCoinsAddresses_.length;
            permittedCoinsAddresses_.push(_address);
        }
        if (false == _value) {
            uint256 coinIndex = permittedTokensToId[_address];
            require(coinIndex != 0, ERROR_NO_CONTRACT);
            uint256 lastCoinIndex = permittedCoinsAddresses_.length.sub(1);
            permittedCoinsAddresses_[coinIndex] = permittedCoinsAddresses_[
            lastCoinIndex
            ];
            permittedTokensToId[permittedCoinsAddresses_[coinIndex]] = coinIndex;
            delete permittedCoinsAddresses_[lastCoinIndex];
            permittedTokensToId[_address] = 0;
            permittedCoinsAddresses_.length = permittedCoinsAddresses_.length.sub(1);
        }
    }

    function hasPermission(
        address _subject,
        uint256 _permissionBit
    )
    internal
    view
    returns (bool)
    {
        return permissions(_subject, _permissionBit);
    }
}pragma solidity ^0.5.7;


contract Constants {

    // Permissions constants
    uint256 public constant CAN_EXCHANGE_COINS = 1;
    uint256 public constant CAN_REGISTER_COINS = 2;
    uint256 public constant CAN_MINT_COINS = 3;
    uint256 public constant CAN_BURN_COINS = 4;
    uint256 public constant CAN_LOCK_COINS = 5;
    uint256 public constant PERMITTED_COINS = 6;

    // Contract Registry keys

    //public block-chain
    uint256 public constant CONTRACT_TOKEN = 1;
    uint256 public constant CONTRACT_EXCHANGE = 2;
    uint256 public constant CONTRACT_WITHDRAW = 3;
    uint256 public constant COIN_HOLDER = 4;



    uint256 public constant PERCENTS_ABS_MAX = 1e4;
    uint256 public constant USD_PRECISION = 1e5;

    string public constant ERROR_ACCESS_DENIED = "ERROR_ACCESS_DENIED";
    string public constant ERROR_NO_CONTRACT = "ERROR_NO_CONTRACT";
    string public constant ERROR_NOT_AVAILABLE = "ERROR_NOT_AVAILABLE";
    string public constant ERROR_WRONG_AMOUNT = "ERROR_WRONG_AMOUNT";
    /*solium-disable-next-line*/
    string public constant ERROR_NOT_PERMITTED_COIN = "ERROR_NOT_PERMITTED_COIN";
    /*solium-disable-next-line*/
    string public constant ERROR_BALANCE_IS_NOT_ALLOWED = "BALANCE_IS_NOT_ALLOWED";
    string public constant ERROR_COIN_REGISTERED = "ERROR_COIN_REGISTERED";

    // Campaign Sates
    enum RequestState{
        Pending,
        PaidPartially,
        FullyPaid,
        Rejected,
        Refunded,
        Undefined,
        Canceled
    }
}pragma solidity ^0.5.0;

import "./IERC20.sol";
import "./SafeMath.sol";

/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
 * Originally based on code by FirstBlood:
 * https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 *
 * This implementation emits additional Approval events, allowing applications to reconstruct the allowance status for
 * all accounts just by listening to said events. Note that this isn't required by the specification, and other
 * compliant implementations may not do it.
 */
contract ERC20 is IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowed;

    uint256 private _totalSupply;

    /**
    * @dev Total number of tokens in existence
    */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
    * @dev Gets the balance of the specified address.
    * @param owner The address to query the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowed[owner][spender];
    }

    /**
    * @dev Transfer token for a specified address
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another.
     * Note that while this function emits an Approval event, this is not required as per the specification,
     * and other compliant implementations may not emit the event.
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
        _transfer(from, to, value);
        emit Approval(from, msg.sender, _allowed[from][msg.sender]);
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner allowed to a spender.
     * approve should be called when allowed_[_spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = _allowed[msg.sender][spender].add(addedValue);
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner allowed to a spender.
     * approve should be called when allowed_[_spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = _allowed[msg.sender][spender].sub(subtractedValue);
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    /**
    * @dev Transfer token for a specified addresses
    * @param from The address to transfer from.
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0));

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(from, to, value);
    }

    /**
     * @dev Internal function that mints an amount of the token and assigns it to
     * an account. This encapsulates the modification of balances such that the
     * proper events are emitted.
     * @param account The account that will receive the created tokens.
     * @param value The amount that will be created.
     */
    function _mint(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.add(value);
        _balances[account] = _balances[account].add(value);
        emit Transfer(address(0), account, value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account.
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account, deducting from the sender's allowance for said account. Uses the
     * internal burn function.
     * Emits an Approval event (reflecting the reduced allowance).
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burnFrom(address account, uint256 value) internal {
        _allowed[account][msg.sender] = _allowed[account][msg.sender].sub(value);
        _burn(account, value);
        emit Approval(account, msg.sender, _allowed[account][msg.sender]);
    }
}pragma solidity ^0.5.0;

import "./ERC20.sol";

/**
 * @title Burnable Token
 * @dev Token that can be irreversibly burned (destroyed).
 */
contract ERC20Burnable is ERC20 {
    /**
     * @dev Burns a specific amount of tokens.
     * @param value The amount of token to be burned.
     */
    function burn(uint256 value) public {
        _burn(msg.sender, value);
    }

    /**
     * @dev Burns a specific amount of tokens from the target address and decrements allowance
     * @param from address The address which you want to send tokens from
     * @param value uint256 The amount of token to be burned
     */
    function burnFrom(address from, uint256 value) public {
        _burnFrom(from, value);
    }
}pragma solidity ^0.5.0;

import "./IERC20.sol";

/**
 * @title ERC20Detailed token
 * @dev The decimals are only for visualization purposes.
 * All the operations are done using the smallest and indivisible token unit,
 * just as on Ethereum all the operations are done in wei.
 */
contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor (string memory name, string memory symbol, uint8 decimals) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
    }

    /**
     * @return the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @return the symbol of the token.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @return the number of decimals of the token.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}pragma solidity ^0.5.6;


contract IAllowanceChecker {

    /**
    * @dev Function to get stable coin allowed amount for originater
    * @param _coinAddress address of stable coin
    * @param _coinHolderAddress address of coin holder
    * @return uint256 that indicates amount of allowed amount for originate address
    */
    function getCoinAllowance(
        address _coinAddress,
        address _coinHolderAddress
    )
    internal
    view
    returns (uint256);

}pragma solidity ^0.5.6;


contract ICoinExchangeRates {

    /**
    * @dev Function to set CoinsPrices In USD
    * @param _coinsAddresses The array of addresses of stablecoins.
    * @param _prices The array of prices for stablecoins.
    * @return A boolean that indicates if the operation was successful.
    */
    function setCoinsPricesInUSD(
        address[] memory _coinsAddresses,
        uint256[] memory _prices
    )
    public
    returns(bool);

    /**
    * @dev Function to set backed up proportions for permitted coins
    * @param _coinsAddresses The array of addresses of stablecoins.
    * @param _percentageProportion percents proportions
    * @return A boolean that indicates if the operation was successful.
    */
    function setCoinsCoverageProportion(
        address[] memory _coinsAddresses,
        uint256[] memory _percentageProportion
    )
    public
    returns(bool);

    /**
       * @dev sets or unset permissions to make some actions
       * @param _address address stablecoin which is allowed/disalwed
       * @param _decimals adecimals value of stablecoin
       * @param _value bool sets/unsets _permission
    */
    function setPermissionsForCoins(
        address _address,
        bool _value,
        uint256 _decimals
    )
    public;

    /**
    * @dev Function to get USD amount from converting blobs
    * @param _blobsAmount the amount of blobs to be converted
    * @return A number of coins you can receive by converting blobs
    */
    function calculateUSDByBlobs(uint256 _blobsAmount)
    public
    view
    returns(uint256);

    /**
    * @dev Function to get amount of each stable coin based on proportion and price
    * which user can receive by blobs dissolveing
    * @param _usdAmount the amount to get stable coins
    * @return two arrays: stable coins and appropriate balances
    */
    function calculateCoinsAmountByUSD(
        uint256 _usdAmount
    )
    public
    view
    returns (address[] memory, uint256[] memory);

    /**
    * @dev Function to get amount of usd by converting stable coins
    * @param _stableCoinAddress stable coin address
    * @param _coinsAmount amount of coins to exchange
    * @return A usd amount you can receive by exchanging coin
    */
    function calculateUsdByCoin(
        address _stableCoinAddress,
        uint256 _coinsAmount
    )
    public
    view
    returns(uint256);

    /**
    * @dev Function to get amount of blobs by converting stable coins
    * @param _stableCoinAddress stable coin address
    * @param _coinsAmount amount of coins to exchange
    * @return A usd amount you can receive by exchanging coin
    */
    function calculateBlobsAmount(
        address _stableCoinAddress,
        uint256 _coinsAmount
    )
    public
    view
    returns (uint256);

    /**
    * @dev Function to get timestamp of last price update
    * @param _stableCoinAddress stable coin address
    * @return A timestamp of last update
    */
    function coinPriceUpdatedAt(address _stableCoinAddress)
    public
    view
    returns(uint256);

    /**
    * @dev Function to get price of stablecoin
    * @param _stableCoinAddress stable coin address
    * @return A price in usd
    */
    function getCoinPrice(address _stableCoinAddress)
    public
    view
    returns(uint256);

    /**
    * @dev Function to return permitted coins List
    * @return An array of coins addresses
    */
    function permittedCoinsAddresses()
    public
    view
    returns (address[] memory);

    /**
    * @dev Function to get price of blob coin
    * @return A price in usd
    */
    function blobCoinPrice()
    public
    view
    returns (uint256);

    /**
    * @dev Function to set price in usd for exact stable coin
    * @param _stableCoinAddress stable coin address
    * @param _price coin price in usd
    */
    function setCoinPrice(address _stableCoinAddress, uint256 _price) internal;

}pragma solidity ^0.5.7;


contract IDissolve {

    /**
      * @dev Function to perform dissolve and burn Blobs
      * @param _dissolveId The id of Dissolve request
      * @param _maxAmount of blob coins can be covered by stable coins
      * @return A boolean that indicates if the operation was successful.
   */
    function externalDissolve(
        uint256 _dissolveId,
        uint256 _maxAmount
    )
    external
    returns (bool);

    /**
    * @dev Function to get stable coins and burn blobcoins
    * @param _value The amount of blobcoins to return .
    * @return A boolean that indicates if the operation was successful.
    */
    function createDissolveRequest(uint256 _value)
    public
    returns (bool);

    /**
      * @dev Function to perform dissolve and burn Blobs
      * @param _dissolveId The id of Dissolve request
      * @param _maxAmount of blob coins can be covered by stable coins
    */
    function internalDissolve(
        uint256 _dissolveId,
        uint256 _maxAmount
    )
    internal;
}pragma solidity ^0.5.0;

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}pragma solidity ^0.5.7;

/**
 * @title ERC20Mintable
 * @dev ERC20 minting logic
 */
contract IERC20Mintable{
    /**
     * @dev Function to mint coins
     * @param to The address that will receive the minted tokens.
     * @param value The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mint(address to, uint256 value)
    public
    returns (bool);
}pragma solidity ^0.5.7;


contract ILockupContract {

    /**
    * @dev Function to lock blob amount
    * @param _address the coin holder address
    * @param _amount the coins amount to be locked
    */
    function lock(
        address _address,
        uint256 _amount
    )
    public;

    /**
    * @dev Function to unlock blob amount
    * @param _address the coin holder address
    * @param _amount the coins amount to be unlocked
    */
    function unlock(
        address _address,
        uint256 _amount
    )
    public;

    /**
    * @dev Function to check if the specified balance is allowed to transfer
    * @param _address the coin holder address
    * @param _value the coins amount to be checked
    * @param _holderBalance total holder balance
    * @return bool true in case there is enough unlocked coins
    */
    function isTransferAllowed(
        address _address,
        uint256 _value,
        uint256 _holderBalance
    )
    public
    view
    returns(bool);

    /**
    * @dev Function to get unlocked amount
    * @param _address the coin holder address
    * @param _holderBalance total holder balance
    * @return number of unlocked coins
    */
    function allowedBalance(
        address _address,
        uint256 _holderBalance
    )
    public
    view
    returns(uint256);
}pragma solidity ^0.5.6;


contract IManaged {

    /**
       * @dev updates managed contract address
       * @param _management address contract address
   */
    function setManagementContract(address _management) public;

    /**
       * @dev checks if address is permitted to  make an action
       * @param _subject address requested address
       * @param _permissionBit uint256 action constant value
       * @return true in case when address has a permision
   */
    function hasPermission(
        address _subject,
        uint256 _permissionBit
    )
    internal
    view
    returns (bool);

}pragma solidity ^0.5.7;


contract IManagement {

    /**
        * @dev sets or unset permissions to make some actions
        * @param _address address Address which  is allowed/disallowed to run function
        * @param _permission uint256 constant value describes one of the permission
        * @param _value bool sets/unsets _permission
    */
    function setPermission(
        address _address,
        uint256 _permission,
        bool _value
    )
    public;

    /**
      * @dev register contract with ID
      * @param _key uint256 constant value, indicates the contract
      * @param _target address Address of the contract
    */
    function registerContract(uint256 _key, address _target) public;

    /**
     * @dev updates the percentage fee amount for dissolve request
     * @param _valueInPercentage uint256 fee amount which  should receive Platform per each dissolve
    */
    function setFeePercentage(
        uint256 _valueInPercentage
    )
    public;

    /**
      * @dev gets the fee percentage value for dissolve
      * @return uint256 the fee percentage value for dissolve
    */
    function getFeePercentage()
    public
    view
    returns (uint256);

    /**
      * @dev checks if permissions is specified for exact address
      * @return bool identifier of permissions
    */
    function permissions(address _subject, uint256 _permissionBit)
    public
    view
    returns (bool);
}pragma solidity ^0.5.6;


contract IOriginate {


    /**
       * @dev Function to perform originate and mint Blobs for requester
       * @param _originateId The id of Originate request
       * @param _stableCoinAddresses coins addresses list to exchange
       * @param _maxCoinsAmount max amounts for each coin allowed to exchange
       * @return A boolean that indicates if the operation was successful.
    */
    function externalOriginate(
        uint256 _originateId,
        address[] calldata _stableCoinAddresses,
        uint256[] calldata _maxCoinsAmount
    )
    external
    returns (bool);

    /**
    * @dev Function to receive stable coin and mint blobcoins
    * @param _stableCoinAddresses The addresses of the coins that will be exchanged to originate blobs.
    * @param _values The amounts of stable coins to contribute .
    * @return A boolean that indicates if the operation was successful.
    */
    function createOriginateRequest(
        address[] memory _stableCoinAddresses,
        uint256[] memory _values
    )
    public
    returns (bool);

    /**
   * @dev Function to get total and exchanged stable coin amounts per originate request
   * @param _originateId The id of Originate request
   * @param _stableCoin stable coin address to be checked
   * @return uint256[2] array where [0] element indicates total stablecoins to be exchanged
    [1] index shows the amount of already exchanged stable coin
   */
    function getStableCoinAmountsByRequestId(
        uint256 _originateId,
        address _stableCoin
    )
    public
    view
    returns (uint256[2] memory);

    /**
      * @dev Function to perform originate and mint Blobs for requester
       * @param _originateId The id of Originate request
       * @param _stableCoinAddresses coins addresses list to exchange
       * @param _maxCoinsAmount max amounts for each coin allowed to exchange
    */
    function internalOriginate(
        uint256 _originateId,
        address[] memory _stableCoinAddresses,
        uint256[] memory _maxCoinsAmount
    )
    internal;

    /**
    * @dev Function to validate stablecoin registry and balance allowance
    * @param _stableCoinAddress stable coin address to be checked
    * @param _value stable coin amount needs to be allowed
    */
    function internalValidateCoin(
        address _stableCoinAddress,
        uint256 _value
    )
    internal;
}pragma solidity ^0.5.7;

import "./SafeMath.sol";
import "./ILockupContract.sol";
import "./Managed.sol";

contract LockupContract is ILockupContract, Managed  {

    mapping (address => uint256) public lockedAmount;
    event Lock(address holderAddress, uint256 amount);
    event UnLock(address holderAddress, uint256 amount);

    constructor(address _management)
    public
    Managed(_management)
    {}

    function lock(
        address _address,
        uint256 _amount
    )
    public
    requirePermission(CAN_LOCK_COINS)
    {
        lockedAmount[_address] = lockedAmount[_address].add(_amount);
        emit Lock(_address, _amount);
    }

    function unlock(
        address _address,
        uint256 _amount
    )
    public
    requirePermission(CAN_LOCK_COINS)
    {
        require(
            lockedAmount[_address] >= _amount,
            ERROR_WRONG_AMOUNT
        );
        lockedAmount[_address] = lockedAmount[_address].sub(_amount);
        emit UnLock(_address, _amount);
    }

    function isTransferAllowed(
        address _address,
        uint256 _value,
        uint256 _holderBalance
    )
    public
    view
    returns (bool)
    {
        if (
            lockedAmount[_address] == 0 ||
        _holderBalance.sub(lockedAmount[_address]) >= _value
        ) {
            return true;
        }

        return false;
    }

    function allowedBalance(
        address _address,
        uint256 _holderBalance
    )
    public
    view
    returns (uint256)
    {
        if (lockedAmount[_address] == 0) {
            return _holderBalance;
        }
        return _holderBalance.sub(lockedAmount[_address]);
    }
}pragma solidity ^0.5.7;


import "./Ownable.sol";
import "./SafeMath.sol";
import "./IManaged.sol";
import "./Constants.sol";
import "./Management.sol";

contract Managed is IManaged, Constants, Ownable {

    using SafeMath for uint256;

    Management public management;

    modifier requirePermission(uint256 _permissionBit) {
        require(
            hasPermission(msg.sender, _permissionBit),
            ERROR_ACCESS_DENIED
        );
        _;
    }

    modifier canCallOnlyRegisteredContract(uint256 _key) {
        require(
            msg.sender == management.contractRegistry(_key),
            ERROR_ACCESS_DENIED
        );
        _;
    }

    modifier requireContractExistsInRegistry(uint256 _key) {
        require(
            management.contractRegistry(_key) != address(0),
            ERROR_NO_CONTRACT
        );
        _;
    }

    constructor(address _managementAddress) public {
        management = Management(_managementAddress);
    }

    function setManagementContract(address _management) public onlyOwner {
        require(address(0) != _management, ERROR_ACCESS_DENIED);

        management = Management(_management);
    }

    function hasPermission(
        address _subject,
        uint256 _permissionBit
    )
    internal
    view
    returns (bool)
    {
        return management.permissions(_subject, _permissionBit);
    }

}pragma solidity ^0.5.7;


import "./Ownable.sol";
import "./SafeMath.sol";
import "./IManagement.sol";
import "./CoinExchangeRates.sol";
import "./Constants.sol";

contract Management is CoinExchangeRates{

    uint256 private feeValueInPercentage_;

    mapping(address => mapping(uint256 => bool)) private permissions_;

    mapping(uint256 => address) public contractRegistry;

    event PermissionsSet(address subject, uint256 permission, bool value);
    event ContractRegistered(uint256 key, address target);
    event FeeUpdated(uint256 valueInPercentage);

    constructor(uint256 _blobCoinPrice, uint256 _feeInPercentage)
    public
    CoinExchangeRates(_blobCoinPrice)
    {
        feeValueInPercentage_ = _feeInPercentage;
        permissions_[msg.sender][CAN_EXCHANGE_COINS] = true;
        permissions_[msg.sender][CAN_REGISTER_COINS] = true;
        permissions_[msg.sender][CAN_MINT_COINS] = true;
        permissions_[msg.sender][CAN_BURN_COINS] = true;
        permissions_[msg.sender][CAN_LOCK_COINS] = true;
    }

    function setPermission(
        address _address,
        uint256 _permission,
        bool _value
    )
    public
    onlyOwner
    {
        require(
            PERMITTED_COINS != _permission,
            ERROR_ACCESS_DENIED
        );
        permissions_[_address][_permission] = _value;
        emit PermissionsSet(_address, _permission, _value);
    }

    function setPermissionsForCoins(
        address _address,
        bool _value,
        uint256 _decimals
    )
    public
    onlyOwner
    {
        permissions_[_address][PERMITTED_COINS] = _value;
        internalSetPermissionsForCoins(_address, _value, _decimals);
        emit PermissionsSet(_address, PERMITTED_COINS, _value);
    }

    function registerContract(uint256 _key, address _target) public onlyOwner {
        contractRegistry[_key] = _target;
        emit ContractRegistered(_key, _target);
    }

    function setFeePercentage(
        uint256 _valueInPercentage
    )
    public
    onlyOwner
    {
        require(_valueInPercentage <= PERCENTS_ABS_MAX, ERROR_WRONG_AMOUNT);
        feeValueInPercentage_ = _valueInPercentage;
        emit FeeUpdated(_valueInPercentage);
    }

    function getFeePercentage()
    public
    view
    returns (uint256)
    {
        return feeValueInPercentage_;
    }

    function coinsHolder()
    public
    view
    returns (address)
    {
        if (contractRegistry[COIN_HOLDER] != address(0)) {
            return contractRegistry[COIN_HOLDER];
        }
        return owner();
    }

    function permissions(address _subject, uint256 _permissionBit)
    public
    view
    returns (bool)
    {
        return permissions_[_subject][_permissionBit];
    }
}pragma solidity ^0.5.7;

import "./IERC20.sol";
import "./Managed.sol";
import "./AllowanceChecker.sol";
import "./IERC20Mintable.sol";
import "./IOriginate.sol";

/*solium-disable-next-line*/
contract Originate is Managed, IOriginate, AllowanceChecker {

    struct Request {
        address requesterAddress;
        mapping(address => uint256[2]) stableCoinAddressToAmount;
        address[] stableCoins;
        RequestState originateRequestState;
    }

    Request[] public allOriginatesRequests;

    event OriginateRequestCreated(
        uint256 _originateId,
        address requesterAddress,
        address[] stableCoins,
        uint256[] coinsAmount
    );

    event CoinsOriginated(
        uint256 _originateId,
        address[] stableCoins,
        uint256[] exchangedCoinsAmount
    );

    event OriginateRequestCanceled(
        uint256 _originateId,
        address requesterAddress
    );

    modifier requireOriginateIdExisting(uint256 _originateId) {
        require(
            _originateId < allOriginatesRequests.length,
            ERROR_ACCESS_DENIED
        );
        _;
    }

    modifier onlyPermittedCoin(address _stableCoinAddress) {
        require(
            true == hasPermission(
            _stableCoinAddress,
            PERMITTED_COINS
        ),
            ERROR_NOT_PERMITTED_COIN
        );
        _;
    }

    constructor(address _managementAddress)
    public
    Managed(_managementAddress)
    {}

    function externalOriginate(
        uint256 _originateId,
        address[] calldata _stableCoinAddresses,
        uint256[] calldata _maxCoinsAmount
    )
    external
    requirePermission(CAN_EXCHANGE_COINS)
    returns (bool)
    {
        internalOriginate(
            _originateId,
            _stableCoinAddresses,
            _maxCoinsAmount
        );
        return true;
    }

    function externalMultiOriginate(
        uint256[] calldata _originateIds,
        address[] calldata _stableCoinAddresses,
        uint256[] calldata _maxCoinsAmount
    )
    external
    requirePermission(CAN_EXCHANGE_COINS)
    {
        for (uint256 i = 0; i < _originateIds.length; i++) {
            if (
                allOriginatesRequests[_originateIds[i]].originateRequestState != RequestState.PaidPartially &&
                allOriginatesRequests[_originateIds[i]].originateRequestState != RequestState.Pending
            ) {
                continue;
            }
            internalOriginate(
                _originateIds[i],
                _stableCoinAddresses,
                _maxCoinsAmount
            );
        }
    }

    function createOriginateRequest(
        address[] memory _stableCoinAddresses,
        uint256[] memory _values
    )
    public
    requireContractExistsInRegistry(CONTRACT_TOKEN)
    returns (bool)
    {
        require(
            _stableCoinAddresses.length == _values.length,
            ERROR_WRONG_AMOUNT
        );
        allOriginatesRequests.push(
            Request(
                {
                requesterAddress : msg.sender,
                originateRequestState : RequestState.Pending,
                stableCoins : _stableCoinAddresses
                }
            )
        );
        Request storage request = allOriginatesRequests[
        allOriginatesRequests.length.sub(1)
        ];
        for (uint256 i = 0; i < _stableCoinAddresses.length; i++) {
            internalValidateCoin(_stableCoinAddresses[i], _values[i]);
            request.stableCoinAddressToAmount[
            _stableCoinAddresses[i]
            ] = [
            _values[i],
            0
            ];
        }
        emit OriginateRequestCreated(
            allOriginatesRequests.length.sub(1),
            msg.sender,
            _stableCoinAddresses,
            _values
        );
        for (uint256 i = 0; i < _stableCoinAddresses.length; i++) {
            IERC20(_stableCoinAddresses[i]).transferFrom(
                msg.sender,
                address(this),
                _values[i]
            );
        }
        return true;
    }

    function cancelOriginateRequest(
        uint256 _originateRequestId
    )
    public
    requireOriginateIdExisting(_originateRequestId)
    returns (bool)
    {
        Request storage request = allOriginatesRequests[_originateRequestId];
        require(request.requesterAddress == msg.sender, ERROR_ACCESS_DENIED);
        require(
            request.originateRequestState == RequestState.Pending,
            ERROR_ACCESS_DENIED
        );
        request.originateRequestState = RequestState.Canceled;

        emit OriginateRequestCanceled(
            _originateRequestId,
            msg.sender
        );
        for (uint256 i = 0; i < request.stableCoins.length; i++) {
            IERC20(request.stableCoins[i]).transfer(
                msg.sender,
                request.stableCoinAddressToAmount[request.stableCoins[i]][0]
            );
        }
        return true;
    }

    function getStableCoinAmountsByRequestId(
        uint256 _originateId,
        address _stableCoin
    )
    public
    view
    returns (uint256[2] memory)
    {
        Request storage request = allOriginatesRequests[_originateId];
        return request.stableCoinAddressToAmount[_stableCoin];
    }

    function getStableCoinsAddressesByRequestId(
        uint256 _originateId
    )
    public
    view
    returns (address[] memory)
    {
        Request storage request = allOriginatesRequests[_originateId];
        return request.stableCoins;
    }

    function internalOriginate(
        uint256 _originateId,
        address[] memory _stableCoinAddresses,
        uint256[] memory _maxCoinsAmount
    )
    internal
    requireOriginateIdExisting(_originateId)
    {
        require(
            _maxCoinsAmount.length == _stableCoinAddresses.length,
            ERROR_WRONG_AMOUNT
        );
        Request storage request = allOriginatesRequests[_originateId];
        bool originated;
        uint256 usdAmount;

        for (uint256 i = 0; i < _stableCoinAddresses.length; i++) {
            requirePermittedCoin(_stableCoinAddresses[i]);

            uint256[2] memory coinAmounts = request.stableCoinAddressToAmount[
            _stableCoinAddresses[i]
            ];
            uint256 amountToExchange = coinAmounts[0].sub(coinAmounts[1]);
            if (_maxCoinsAmount[i] < amountToExchange) {
                amountToExchange = _maxCoinsAmount[i];
            }
            coinAmounts[1] = coinAmounts[1].add(amountToExchange);
            if (
                coinAmounts[0] > coinAmounts[1] ||
                (i > 0 && false == originated)
            ) {
                originated = false;
            } else {
                originated = true;
            }

            usdAmount = usdAmount.add(
                management.calculateUsdByCoin(
                    _stableCoinAddresses[i],
                    amountToExchange
                )
            );
            IERC20(_stableCoinAddresses[i]).transfer(
                management.coinsHolder(),
                amountToExchange
            );
        }
        internalMintBlobsByUSD(
            request.requesterAddress,
            usdAmount
        );
        if (false == originated) {
            request.originateRequestState = RequestState.PaidPartially;
        } else {
            request.originateRequestState = RequestState.FullyPaid;
        }

        emit CoinsOriginated(
            _originateId,
            _stableCoinAddresses,
            _maxCoinsAmount
        );
    }

    function internalMintBlobsByUSD(
        address _holderAddress,
        uint256 _usdAmount
    )
    internal
    {
        IERC20Mintable(
            management.contractRegistry(CONTRACT_TOKEN)
        ).mint(
            _holderAddress,
            (_usdAmount).div(management.blobCoinPrice())
        );
    }

    function requirePermittedCoin(address _stableCoinAddress)
    internal
    onlyPermittedCoin(_stableCoinAddress)
    {

    }

    function internalValidateCoin(address _stableCoinAddress, uint256 _value)
    internal
    requireAllowance(
        _stableCoinAddress,
        msg.sender,
        _value
    )
    onlyPermittedCoin(_stableCoinAddress)
    {}
}pragma solidity ^0.5.0;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @return the address of the owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * @notice Renouncing to ownership will leave the contract without an owner.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}pragma solidity ^0.5.0;

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