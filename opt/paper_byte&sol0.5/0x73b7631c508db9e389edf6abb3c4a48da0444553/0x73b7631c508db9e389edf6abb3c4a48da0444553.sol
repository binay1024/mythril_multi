pragma solidity ^0.5.16;

pragma solidity 0.5.16;

import "./Ownable.sol";
import "./MorpherTradeEngine.sol";
import "./MorpherState.sol";
import "./SafeMath.sol";

// ----------------------------------------------------------------------------------
// Morpher Oracle contract v 2.0
// The oracle initates a new trade by calling trade engine and requesting a new orderId.
// An event is fired by the contract notifying the oracle operator to query a price/liquidation unchecked
// for a market/user and return the information via the callback function. Since calling
// the callback function requires gas, the user must send a fixed amount of Ether when
// creating their order.
// ----------------------------------------------------------------------------------

contract MorpherOracle is Ownable {

    MorpherTradeEngine tradeEngine;
    MorpherState state; // read only, Oracle doesn't need writing access to state

    using SafeMath for uint256;

    bool public paused;
    bool public useWhiteList; //always false at the moment

    uint256 public gasForCallback;

    address payable public callBackCollectionAddress;

    mapping(address => bool) public callBackAddress;
    mapping(address => bool) public whiteList;
    
    mapping(bytes32 => uint256) public priceBelow;
    mapping(bytes32 => uint256) public priceAbove;
    mapping(bytes32 => uint256) public goodFrom;
    mapping(bytes32 => uint256) public goodUntil;

    mapping(bytes32 => bool) public orderCancellationRequested;

    mapping(bytes32 => address) public orderIdTradeEngineAddress;
    address public previousTradeEngineAddress;
    address public skipPreviousTradeEngineAddress; //skips a trade engine address, e.g. typos
    address public previousOracleAddress;

// ----------------------------------------------------------------------------------
// Events
// ----------------------------------------------------------------------------------
    event OrderCreated(
        bytes32 indexed _orderId,
        address indexed _address,
        bytes32 indexed _marketId,
        uint256 _closeSharesAmount,
        uint256 _openMPHTokenAmount,
        bool _tradeDirection,
        uint256 _orderLeverage,
        uint256 _onlyIfPriceBelow,
        uint256 _onlyIfPriceAbove,
        uint256 _goodFrom,
        uint256 _goodUntil
        );

    event LiquidationOrderCreated(
        bytes32 indexed _orderId,
        address _sender,
        address indexed _address,
        bytes32 indexed _marketId

        );

    event OrderProcessed(
        bytes32 indexed _orderId,
        uint256 _price,
        uint256 _unadjustedMarketPrice,
        uint256 _spread,
        uint256 _positionLiquidationTimestamp,
        uint256 _timeStamp,
        uint256 _newLongShares,
        uint256 _newShortShares,
        uint256 _newMeanEntry,
        uint256 _newMeanSprad,
        uint256 _newMeanLeverage,
        uint256 _liquidationPrice
        );

    event OrderFailed(
        bytes32 indexed _orderId,
        address indexed _address,
        bytes32 indexed _marketId,
        uint256 _closeSharesAmount,
        uint256 _openMPHTokenAmount,
        bool _tradeDirection,
        uint256 _orderLeverage,
        uint256 _onlyIfPriceBelow,
        uint256 _onlyIfPriceAbove,
        uint256 _goodFrom,
        uint256 _goodUntil
        );

    event OrderCancelled(
        bytes32 indexed _orderId,
        address indexed _sender,
        address indexed _oracleAddress
        );
    
    event AdminOrderCancelled(
        bytes32 indexed _orderId,
        address indexed _sender,
        address indexed _oracleAddress
        );

    event OrderCancellationRequestedEvent(
        bytes32 indexed _orderId,
        address indexed _sender
        );

    event CallbackAddressEnabled(
        address indexed _address
        );

    event CallbackAddressDisabled(
        address indexed _address
        );

    event OraclePaused(
        bool _paused
        );
        
    event CallBackCollectionAddressChange(
        address _address
        );

    event SetGasForCallback(
        uint256 _gasForCallback
        );

    event LinkTradeEngine(
        address _address
        );

    event LinkMorpherState(
        address _address
        );

    event SetUseWhiteList(
        bool _useWhiteList
        );

    event AddressWhiteListed(
        address _address
        );

    event AddressBlackListed(
        address _address
        );

    event AdminLiquidationOrderCreated(
        bytes32 indexed _orderId,
        address indexed _address,
        bytes32 indexed _marketId,
        uint256 _closeSharesAmount,
        uint256 _openMPHTokenAmount,
        bool _tradeDirection,
        uint256 _orderLeverage
        );

    /**
     * Delisting markets is a function that stops when gas is running low
     * if it reached all positions it will emit "DelistMarketComplete"
     * otherwise it needs to be re-run.
     */
    event DelistMarketIncomplete(bytes32 _marketId, uint256 _processedUntilIndex);
    event DelistMarketComplete(bytes32 _marketId);
    event LockedPriceForClosingPositions(bytes32 _marketId, uint256 _price);


    event FallbackOracleUpdated(address _oldFallbackOracle, address _newFallbackOracle);
    event FallbackTradeEngineUpdated(address _oldFallbackTradeEngine, address _newFallbackTradeEngine);
    event UpdateSkipPreviousTradeEngineAddress(address _oldAddress, address _newAddress);

    modifier onlyOracleOperator {
        require(isCallbackAddress(msg.sender), "MorpherOracle: Only the oracle operator can call this function.");
        _;
    }

    modifier onlyAdministrator {
        require(msg.sender == state.getAdministrator(), "Function can only be called by the Administrator.");
        _;
    }

    modifier notPaused {
        require(paused == false, "MorpherOracle: Oracle paused, aborting");
        _;
    }

   constructor(address _tradeEngineAddress, address _morpherState, address _callBackAddress, address payable _gasCollectionAddress, uint256 _gasForCallback, address _coldStorageOwnerAddress, address _previousTradeEngineAddress, address _previousOracleAddress) public {
        setTradeEngineAddress(_tradeEngineAddress);
        setStateAddress(_morpherState);
        enableCallbackAddress(_callBackAddress);
        setCallbackCollectionAddress(_gasCollectionAddress);
        setGasForCallback(_gasForCallback);
        transferOwnership(_coldStorageOwnerAddress);
        previousTradeEngineAddress = _previousTradeEngineAddress; //that is the address before updating the trade engine. Can set to 0x0000 if a completely new deployment happens. It is only valid when mid-term updating the tradeengine
        previousOracleAddress = _previousOracleAddress; //if we are updating the oracle, then this is the previous oracle address. Can be set to 0x00 if a completely new deployment happens.
    }

// ----------------------------------------------------------------------------------
// Setter/getter functions for trade engine address, oracle operator (callback) address,
// and prepaid gas limit for callback function
// ----------------------------------------------------------------------------------
    function setTradeEngineAddress(address _address) public onlyOwner {
        tradeEngine = MorpherTradeEngine(_address);
        emit LinkTradeEngine(_address);
    }

    function setStateAddress(address _address) public onlyOwner {
        state = MorpherState(_address);
        emit LinkMorpherState(_address);
    }

    function overrideGasForCallback(uint256 _gasForCallback) public onlyOwner {
        gasForCallback = _gasForCallback;
        emit SetGasForCallback(_gasForCallback);
    }
    
    function setGasForCallback(uint256 _gasForCallback) private {
        gasForCallback = _gasForCallback;
        emit SetGasForCallback(_gasForCallback);
    }

    function enableCallbackAddress(address _address) public onlyOwner {
        callBackAddress[_address] = true;
        emit CallbackAddressEnabled(_address);
    }

    function disableCallbackAddress(address _address) public onlyOwner {
        callBackAddress[_address] = false;
        emit CallbackAddressDisabled(_address);
    }

    function isCallbackAddress(address _address) public view returns (bool _isCallBackAddress) {
        return callBackAddress[_address];
    }

    function setCallbackCollectionAddress(address payable _address) public onlyOwner {
        callBackCollectionAddress = _address;
        emit CallBackCollectionAddressChange(_address);
    }

    function getAdministrator() public view returns(address _administrator) {
        return state.getAdministrator();
    }

// ----------------------------------------------------------------------------------
// Oracle Owner can use a whitelist and authorize individual addresses
// ----------------------------------------------------------------------------------
    function setUseWhiteList(bool _useWhiteList) public onlyOracleOperator {
        require(false, "MorpherOracle: Cannot use this functionality in the oracle at the moment");
        useWhiteList = _useWhiteList;
        emit SetUseWhiteList(_useWhiteList);
    }

    function setWhiteList(address _whiteList) public onlyOracleOperator {
        whiteList[_whiteList] = true;
        emit AddressWhiteListed(_whiteList);
    }

    function setBlackList(address _blackList) public onlyOracleOperator {
        whiteList[_blackList] = false;
        emit AddressBlackListed(_blackList);
    }

    function isWhiteListed(address _address) public view returns (bool _whiteListed) {
        if (useWhiteList == false ||  whiteList[_address] == true) {
            _whiteListed = true;
        }
        return(_whiteListed);
    }

// ----------------------------------------------------------------------------------
// emitOrderFailed
// Can be called by Oracle Operator to notifiy user of failed order
// ----------------------------------------------------------------------------------
    function emitOrderFailed(
        bytes32 _orderId,
        address _address,
        bytes32 _marketId,
        uint256 _closeSharesAmount,
        uint256 _openMPHTokenAmount,
        bool _tradeDirection,
        uint256 _orderLeverage,
        uint256 _onlyIfPriceBelow,
        uint256 _onlyIfPriceAbove,
        uint256 _goodFrom,
        uint256 _goodUntil
    ) public onlyOracleOperator {
        emit OrderFailed(
            _orderId,
            _address,
            _marketId,
            _closeSharesAmount,
            _openMPHTokenAmount,
            _tradeDirection,
            _orderLeverage,
            _onlyIfPriceBelow,
            _onlyIfPriceAbove,
            _goodFrom,
            _goodUntil);
    }

// ----------------------------------------------------------------------------------
// createOrder(bytes32  _marketId, bool _tradeAmountGivenInShares, uint256 _tradeAmount, bool _tradeDirection, uint256 _orderLeverage)
// Request a new orderId from trade engine and fires event for price/liquidation check request.
// ----------------------------------------------------------------------------------
    function createOrder(
        bytes32 _marketId,
        uint256 _closeSharesAmount,
        uint256 _openMPHTokenAmount,
        bool _tradeDirection,
        uint256 _orderLeverage,
        uint256 _onlyIfPriceAbove,
        uint256 _onlyIfPriceBelow,
        uint256 _goodUntil,
        uint256 _goodFrom
        ) public payable notPaused returns (bytes32 _orderId) {
        require(isWhiteListed(msg.sender),"MorpherOracle: Address not eligible to create an order.");
        if (gasForCallback > 0) {
            require(msg.value >= gasForCallback, "MorpherOracle: Must transfer gas costs for Oracle Callback function.");
            callBackCollectionAddress.transfer(msg.value);
        }
        _orderId = tradeEngine.requestOrderId(msg.sender, _marketId, _closeSharesAmount, _openMPHTokenAmount, _tradeDirection, _orderLeverage);
        orderIdTradeEngineAddress[_orderId] = address(tradeEngine);

        //if the market was deactivated, and the trader didn't fail yet, then we got an orderId to close the position with a locked in price
        if(state.getMarketActive(_marketId) == false) {

            //price will come from the position where price is stored forever
            tradeEngine.processOrder(_orderId, tradeEngine.getDeactivatedMarketPrice(_marketId), 0, 0, now.mul(1000));
            
            emit OrderProcessed(
                _orderId,
                tradeEngine.getDeactivatedMarketPrice(_marketId),
                0,
                0,
                0,
                now.mul(1000),
                0,
                0,
                0,
                0,
                0,
                0
                );
        } else {
            priceAbove[_orderId] = _onlyIfPriceAbove;
            priceBelow[_orderId] = _onlyIfPriceBelow;
            goodFrom[_orderId]   = _goodFrom;
            goodUntil[_orderId]  = _goodUntil;
            emit OrderCreated(
                _orderId,
                msg.sender,
                _marketId,
                _closeSharesAmount,
                _openMPHTokenAmount,
                _tradeDirection,
                _orderLeverage,
                _onlyIfPriceBelow,
                _onlyIfPriceAbove,
                _goodFrom,
                _goodUntil
                );
        }

        return _orderId;
    }

    function getTradeEngineFromOrderId(bytes32 _orderId) public view returns (address) {
        //get the current trade engine
        if(orderIdTradeEngineAddress[_orderId] != address(0)){
            return orderIdTradeEngineAddress[_orderId];
        }

        if(previousOracleAddress != address(0)) {
            MorpherOracle _oracle = MorpherOracle(previousOracleAddress);
            address _previousTradeEngine = _oracle.getTradeEngineFromOrderId(_orderId);
            if(_previousTradeEngine != skipPreviousTradeEngineAddress) { //fixing a typo
                return _previousTradeEngine;
            }
        }

        //nothing in there, take the previous tradeEngine then.
        return previousTradeEngineAddress;
    }

    function updateSkipTradeEngineAddress(address _skipTradeEngineAddress) public onlyAdministrator {
        emit UpdateSkipPreviousTradeEngineAddress(skipPreviousTradeEngineAddress, _skipTradeEngineAddress);
        skipPreviousTradeEngineAddress = _skipTradeEngineAddress;
    }


    function updateFallbackTradeEngineAddress(address _tradeEngineFallbackAddress) public onlyAdministrator {
        emit FallbackTradeEngineUpdated(previousTradeEngineAddress, _tradeEngineFallbackAddress);
        previousTradeEngineAddress = _tradeEngineFallbackAddress;
    }


    function updateFallbackOracleAddress(address _oracleFallbackAddress) public onlyAdministrator {
        emit FallbackOracleUpdated(previousOracleAddress, _oracleFallbackAddress);
        previousOracleAddress = _oracleFallbackAddress;
    }

    function initiateCancelOrder(bytes32 _orderId) public {
        MorpherTradeEngine _tradeEngine = MorpherTradeEngine(getTradeEngineFromOrderId(_orderId));
        require(orderCancellationRequested[_orderId] == false, "MorpherOracle: Order was already canceled.");
        (address userId, , , , , , ) = _tradeEngine.getOrder(_orderId);
        require(userId == msg.sender, "MorpherOracle: Only the user can request an order cancellation.");
        orderCancellationRequested[_orderId] = true;
        emit OrderCancellationRequestedEvent(_orderId, msg.sender);

    }
    // ----------------------------------------------------------------------------------
    // cancelOrder(bytes32  _orderId)
    // User or Administrator can cancel their own orders before the _callback has been executed
    // ----------------------------------------------------------------------------------
    function cancelOrder(bytes32 _orderId) public onlyOracleOperator {
        require(orderCancellationRequested[_orderId] == true, "MorpherOracle: Order-Cancellation was not requested.");
        MorpherTradeEngine _tradeEngine = MorpherTradeEngine(getTradeEngineFromOrderId(_orderId));
        (address userId, , , , , , ) = _tradeEngine.getOrder(_orderId);
        _tradeEngine.cancelOrder(_orderId, userId);
        clearOrderConditions(_orderId);
        emit OrderCancelled(
            _orderId,
            userId,
            msg.sender
            );
    }
    
    // ----------------------------------------------------------------------------------
    // adminCancelOrder(bytes32  _orderId)
    // Administrator can cancel before the _callback has been executed to provide an updateOrder functionality
    // ----------------------------------------------------------------------------------
    function adminCancelOrder(bytes32 _orderId) public onlyOracleOperator {
        MorpherTradeEngine _tradeEngine = MorpherTradeEngine(getTradeEngineFromOrderId(_orderId));
        (address userId, , , , , , ) = _tradeEngine.getOrder(_orderId);
        _tradeEngine.cancelOrder(_orderId, userId);
        clearOrderConditions(_orderId);
        emit AdminOrderCancelled(
            _orderId,
            userId,
            msg.sender
            );
    }

    function getGoodUntil(bytes32 _orderId) public view returns(uint) {
        if(goodUntil[_orderId] > 0) {
            return goodUntil[_orderId];
        }

        //just return the old one
        if(previousOracleAddress != address(0)) {
            MorpherOracle _oldOracle = MorpherOracle(previousOracleAddress);
            return _oldOracle.goodUntil(_orderId);
        }

        return 0;
    }
    function getGoodFrom(bytes32 _orderId) public view returns(uint) {
        if(goodFrom[_orderId] > 0) {
            return goodFrom[_orderId];
        }

        //just return the old one
        if(previousOracleAddress != address(0)) {
            MorpherOracle _oldOracle = MorpherOracle(previousOracleAddress);
            return _oldOracle.goodFrom(_orderId);
        }
        return 0;
    }
    function getPriceAbove(bytes32 _orderId) public view returns(uint) {
        if(priceAbove[_orderId] > 0) {
            return priceAbove[_orderId];
        }

        //just return the old one
        if(previousOracleAddress != address(0)) {
            MorpherOracle _oldOracle = MorpherOracle(previousOracleAddress);
            return _oldOracle.priceAbove(_orderId);
        }
        return 0;
    }
    function getPriceBelow(bytes32 _orderId) public view returns(uint) {
        if(priceBelow[_orderId] > 0) {
            return priceBelow[_orderId];
        }

        //just return the old one
        if(previousOracleAddress != address(0)) {
            MorpherOracle _oldOracle = MorpherOracle(previousOracleAddress);
            return _oldOracle.priceBelow(_orderId);
        }
        return 0;
    }

// ------------------------------------------------------------------------
// checkOrderConditions(bytes32 _orderId, uint256 _price)
// Checks if callback satisfies the order conditions
// ------------------------------------------------------------------------
    function checkOrderConditions(bytes32 _orderId, uint256 _price) public view returns (bool _conditionsMet) {
        _conditionsMet = true;
        if (now > getGoodUntil(_orderId) && getGoodUntil(_orderId) > 0) {
            _conditionsMet = false;
        }
        if (now < getGoodFrom(_orderId) && getGoodFrom(_orderId) > 0) {
            _conditionsMet = false;
        }

        if(getPriceAbove(_orderId) > 0 && getPriceBelow(_orderId) > 0) {
            if(_price < getPriceAbove(_orderId) && _price > getPriceBelow(_orderId)) {
                _conditionsMet = false;
            }
        } else {
            if (_price < getPriceAbove(_orderId) && getPriceAbove(_orderId) > 0) {
                _conditionsMet = false;
            }
            if (_price > getPriceBelow(_orderId) && getPriceBelow(_orderId) > 0) {
                _conditionsMet = false;
            }
        }
        
        return _conditionsMet;
    }

// ----------------------------------------------------------------------------------
// Deletes parameters of cancelled or processed orders
// ----------------------------------------------------------------------------------
    function clearOrderConditions(bytes32 _orderId) internal {
        priceAbove[_orderId] = 0;
        priceBelow[_orderId] = 0;
        goodFrom[_orderId]   = 0;
        goodUntil[_orderId]  = 0;
    }

// ----------------------------------------------------------------------------------
// Pausing/unpausing the Oracle contract
// ----------------------------------------------------------------------------------
    function pauseOracle() public onlyOwner {
        paused = true;
        emit OraclePaused(true);
    }

    function unpauseOracle() public onlyOwner {
        paused = false;
        emit OraclePaused(false);
    }

// ----------------------------------------------------------------------------------
// createLiquidationOrder(address _address, bytes32 _marketId)
// Checks if position has been liquidated since last check. Requires gas for callback
// function. Anyone can issue a liquidation order for any other address and market.
// ----------------------------------------------------------------------------------
    function createLiquidationOrder(
        address _address,
        bytes32 _marketId
        ) public notPaused onlyOracleOperator payable returns (bytes32 _orderId) {
        if (gasForCallback > 0) {
            require(msg.value >= gasForCallback, "MorpherOracle: Must transfer gas costs for Oracle Callback function.");
            callBackCollectionAddress.transfer(msg.value);
        }
        _orderId = tradeEngine.requestOrderId(_address, _marketId, 0, 0, true, 10**8);
        orderIdTradeEngineAddress[_orderId] = address(tradeEngine);
        emit LiquidationOrderCreated(_orderId, msg.sender, _address, _marketId);
        return _orderId;
    }

// ----------------------------------------------------------------------------------
// __callback(bytes32 _orderId, uint256 _price, uint256 _spread, uint256 _liquidationTimestamp, uint256 _timeStamp)
// Called by the oracle operator. Writes price/spread/liquidiation check to the blockchain.
// Trade engine processes the order and updates the portfolio in state if successful.
// ----------------------------------------------------------------------------------
    function __callback(
        bytes32 _orderId,
        uint256 _price,
        uint256 _unadjustedMarketPrice,
        uint256 _spread,
        uint256 _liquidationTimestamp,
        uint256 _timeStamp,
        uint256 _gasForNextCallback
        ) public onlyOracleOperator notPaused returns (uint256 _newLongShares, uint256 _newShortShares, uint256 _newMeanEntry, uint256 _newMeanSpread, uint256 _newMeanLeverage, uint256 _liquidationPrice)  {
        
        require(checkOrderConditions(_orderId, _price), 'MorpherOracle Error: Order Conditions are not met');
       
       MorpherTradeEngine _tradeEngine = MorpherTradeEngine(getTradeEngineFromOrderId(_orderId));
        (
            _newLongShares,
            _newShortShares,
            _newMeanEntry,
            _newMeanSpread,
            _newMeanLeverage,
            _liquidationPrice
        ) = _tradeEngine.processOrder(_orderId, _price, _spread, _liquidationTimestamp, _timeStamp);
        
        clearOrderConditions(_orderId);
        emit OrderProcessed(
            _orderId,
            _price,
            _unadjustedMarketPrice,
            _spread,
            _liquidationTimestamp,
            _timeStamp,
            _newLongShares,
            _newShortShares,
            _newMeanEntry,
            _newMeanSpread,
            _newMeanLeverage,
            _liquidationPrice
            );
        setGasForCallback(_gasForNextCallback);
        return (_newLongShares, _newShortShares, _newMeanEntry, _newMeanSpread, _newMeanLeverage, _liquidationPrice);
    }

// ----------------------------------------------------------------------------------
// delistMarket(bytes32 _marketId)
// Administrator closes out all existing positions on _marketId market at current prices
// ----------------------------------------------------------------------------------

    uint delistMarketFromIx = 0;
    function delistMarket(bytes32 _marketId, bool _startFromScratch) public onlyAdministrator {
        require(state.getMarketActive(_marketId) == true, "Market must be active to process position liquidations.");
        // If no _fromIx and _toIx specified, do entire _list
        if (_startFromScratch) {
            delistMarketFromIx = 0;
        }
        
        uint _toIx = state.getMaxMappingIndex(_marketId);
        
        address _address;
        for (uint256 i = delistMarketFromIx; i <= _toIx; i++) {
             if(gasleft() < 250000 && i != _toIx) { //stop if there's not enough gas to write the next transaction
                delistMarketFromIx = i;
                emit DelistMarketIncomplete(_marketId, _toIx);
                return;
            } 
            
            _address = state.getExposureMappingAddress(_marketId, i);
            adminLiquidationOrder(_address, _marketId);
            
        }
        emit DelistMarketComplete(_marketId);
    }

    /**
     * Course of action would be:
     * 1. de-activate market through state
     * 2. set the Deactivated Market Price
     * 3. let users still close their positions
     */
    function setDeactivatedMarketPrice(bytes32 _marketId, uint256 _price) public onlyAdministrator {
        //todo updateable tradeEngine
        tradeEngine.setDeactivatedMarketPrice(_marketId, _price);
        emit LockedPriceForClosingPositions(_marketId, _price);

    }

// ----------------------------------------------------------------------------------
// adminLiquidationOrder(address _address, bytes32 _marketId)
// Administrator closes out an existing position of _address on _marketId market at current price
// ----------------------------------------------------------------------------------
    function adminLiquidationOrder(
        address _address,
        bytes32 _marketId
        ) public onlyAdministrator returns (bytes32 _orderId) {
            uint256 _positionLongShares = state.getLongShares(_address, _marketId);
            uint256 _positionShortShares = state.getShortShares(_address, _marketId);
            if (_positionLongShares > 0) {
                _orderId = tradeEngine.requestOrderId(_address, _marketId, _positionLongShares, 0, false, 10**8);
                emit AdminLiquidationOrderCreated(_orderId, _address, _marketId, _positionLongShares, 0, false, 10**8);
            }
            if (_positionShortShares > 0) {
                _orderId = tradeEngine.requestOrderId(_address, _marketId, _positionShortShares, 0, true, 10**8);
                emit AdminLiquidationOrderCreated(_orderId, _address, _marketId, _positionShortShares, 0, true, 10**8);
            }
            orderIdTradeEngineAddress[_orderId] = address(tradeEngine);
            return _orderId;
    }
    
// ----------------------------------------------------------------------------------
// Auxiliary function to hash a string market name i.e.
// "CRYPTO_BTC" => 0x0bc89e95f9fdaab7e8a11719155f2fd638cb0f665623f3d12aab71d1a125daf9;
// ----------------------------------------------------------------------------------
    function stringToHash(string memory _source) public pure returns (bytes32 _result) {
        return keccak256(abi.encodePacked(_source));
    }
}pragma solidity 0.5.16;

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
}pragma solidity 0.5.16;
contract IMorpherStaking {
    
    function lastReward() public view returns (uint256);

    function totalShares() public view returns (uint256);

    function interestRate() public view returns (uint256);

    function lockupPeriod() public view returns (uint256);
    
    function minimumStake() public view returns (uint256);

    function stakingAdmin() public view returns (address);

    function updatePoolShareValue() public returns (uint256 _newPoolShareValue) ;

    function stake(uint256 _amount) public returns (uint256 _poolShares);

    function unStake(uint256 _numOfShares) public returns (uint256 _amount);

}pragma solidity 0.5.16;

contract IMorpherState {
    function setPosition(
        address _address,
        bytes32 _marketId,
        uint256 _timeStamp,
        uint256 _longShares,
        uint256 _shortShares,
        uint256 _meanEntryPrice,
        uint256 _meanEntrySpread,
        uint256 _meanEntryLeverage,
        uint256 _liquidationPrice
    ) public; 

    function getPosition(
        address _address,
        bytes32 _marketId
    ) public view returns (
        uint256 _longShares,
        uint256 _shortShares,
        uint256 _meanEntryPrice,
        uint256 _meanEntrySpread,
        uint256 _meanEntryLeverage,
        uint256 _liquidationPrice
    );

    function getLastUpdated(address _address, bytes32 _marketId) public view returns (uint256 _lastUpdated);

    function transfer(address _from, address _to, uint256 _token) public;
    
    function balanceOf(address _tokenOwner) public view returns (uint256 balance);

    function mint(address _address, uint256 _token) public;

    function burn(address _address, uint256 _token) public;

     function getSideChainOperator() public view returns (address _address);

    function inactivityPeriod() public view returns (uint256);

    function getSideChainMerkleRootWrittenAtTime() public view returns(uint256 _sideChainMerkleRoot);

    function fastTransfersEnabled() public view returns(bool);

    function mainChain() public view returns(bool);

    function setInactivityPeriod(uint256 _periodLength) public;

    function disableFastWithdraws() public;

    function setSideChainMerkleRoot(bytes32 _sideChainMerkleRoot) public;

    function resetLast24HoursAmountWithdrawn() public;

    function set24HourWithdrawLimit(uint256 _limit) public;

    function getTokenSentToLinkedChain(address _address) public view returns (uint256 _token);

    function getTokenClaimedOnThisChain(address _address) public view returns (uint256 _token);

    function getTokenSentToLinkedChainTime(address _address) public view returns (uint256 _timeStamp);

    function lastWithdrawLimitReductionTime() public view returns (uint256);

    function withdrawLimit24Hours() public view returns (uint256);

    function update24HoursWithdrawLimit(uint256 _amount) public;

    function last24HoursAmountWithdrawn() public view returns (uint256);

    function setTokenSentToLinkedChain(address _address, uint256 _token) public;

    function setTokenClaimedOnThisChain(address _address, uint256 _token) public;

    function add24HoursWithdrawn(uint256 _amount) public;

    function getPositionHash(
        address _address,
        bytes32 _marketId,
        uint256 _timeStamp,
        uint256 _longShares,
        uint256 _shortShares,
        uint256 _meanEntryPrice,
        uint256 _meanEntrySpread,
        uint256 _meanEntryLeverage,
        uint256 _liquidationPrice
    ) public pure returns (bytes32 _hash);

    function getPositionClaimedOnMainChain(bytes32 _positionHash) public view returns (bool _alreadyClaimed);

    function setPositionClaimedOnMainChain(bytes32 _positionHash) public;

     function getBalanceHash(address _address, uint256 _balance) public pure returns (bytes32 _hash);

     function getSideChainMerkleRoot() public view returns(bytes32 _sideChainMerkleRoot);

     function getBridgeNonce() public returns (uint256 _nonce);
}pragma solidity 0.5.16;

interface IMorpherToken {
    /**
     * Emits a {Transfer} event in ERC-20 token contract.
     */
    function emitTransfer(address _from, address _to, uint256 _amount) external;
}pragma solidity 0.5.16;

/**
 * @dev These functions deal with verification of Merkle trees (hash trees),
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        require(proof.length < 100, "MerkleProof: proof too long. Use only sibling hashes.");
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash < proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}// ------------------------------------------------------------------------
// MorpherBridge
// Handles deposit to and withdraws from the side chain, writing of the merkle
// root to the main chain by the side chain operator, and enforces a rolling 24 hours
// token withdraw limit from side chain to main chain.
// If side chain operator doesn't write a merkle root hash to main chain for more than
// 72 hours positions and balaces from side chain can be transferred to main chain.
// ------------------------------------------------------------------------

pragma solidity 0.5.16;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./IMorpherState.sol";
import "./MerkleProof.sol";

contract MorpherBridge is Ownable {

    IMorpherState state;
    using SafeMath for uint256;

    mapping(address => mapping(uint256 => uint256)) withdrawalPerDay; //[address][day] = withdrawalAmount
    mapping(address => mapping(uint256 => uint256)) withdrawalPerMonth; //[address][month] = withdrawalAmount

    uint256 public withdrawalLimitDaily = 200000 * (10**18); //200k MPH per day
    uint256 public withdrawalLimitMonthly = 1000000 * (10 ** 18); //1M MPH per month

    event TransferToLinkedChain(
        address indexed from,
        uint256 tokens,
        uint256 totalTokenSent,
        uint256 timeStamp,
        uint256 transferNonce,
        bytes32 indexed transferHash
    );
    event TrustlessWithdrawFromSideChain(address indexed from, uint256 tokens);
    event OperatorChainTransfer(address indexed from, uint256 tokens, bytes32 sidechainTransactionHash);
    event ClaimFailedTransferToSidechain(address indexed from, uint256 tokens);
    event PositionRecoveryFromSideChain(address indexed from, bytes32 positionHash);
    event TokenRecoveryFromSideChain(address indexed from, bytes32 positionHash);
    event SideChainMerkleRootUpdated(bytes32 _rootHash);
    event WithdrawLimitReset();
    event WithdrawLimitChanged(uint256 _withdrawLimit);
    event WithdrawLimitDailyChanged(uint256 _oldLimit, uint256 _newLimit);
    event WithdrawLimitMonthlyChanged(uint256 _oldLimit, uint256 _newLimit);
    event LinkState(address _address);

    constructor(address _stateAddress, address _coldStorageOwnerAddress) public {
        setMorpherState(_stateAddress);
        transferOwnership(_coldStorageOwnerAddress);
    }

    modifier onlySideChainOperator {
        require(msg.sender == state.getSideChainOperator(), "MorpherBridge: Function can only be called by Sidechain Operator.");
        _;
    }

    modifier sideChainInactive {
        require(now - state.inactivityPeriod() > state.getSideChainMerkleRootWrittenAtTime(), "MorpherBridge: Function can only be called if sidechain is inactive.");
        _;
    }
    
    modifier fastTransfers {
        require(state.fastTransfersEnabled() == true, "MorpherBridge: Fast transfers have been disabled permanently.");
        _;
    }

    modifier onlyMainchain {
        require(state.mainChain() == true, "MorpherBridge: Function can only be executed on Ethereum." );
        _;
    }
    
    // ------------------------------------------------------------------------
    // Links Token Contract with State
    // ------------------------------------------------------------------------
    function setMorpherState(address _stateAddress) public onlyOwner {
        state = IMorpherState(_stateAddress);
        emit LinkState(_stateAddress);
    }

    function setInactivityPeriod(uint256 _periodInSeconds) private {
        state.setInactivityPeriod(_periodInSeconds);
    }

    function disableFastTransfers() public onlyOwner  {
        state.disableFastWithdraws();
    }

    function updateSideChainMerkleRoot(bytes32 _rootHash) public onlySideChainOperator {
        state.setSideChainMerkleRoot(_rootHash);
        emit SideChainMerkleRootUpdated(_rootHash);
    }

    function resetLast24HoursAmountWithdrawn() public onlySideChainOperator {
        state.resetLast24HoursAmountWithdrawn();
        emit WithdrawLimitReset();
    }

    function set24HourWithdrawLimit(uint256 _withdrawLimit) public onlySideChainOperator {
        state.set24HourWithdrawLimit(_withdrawLimit);
        emit WithdrawLimitChanged(_withdrawLimit);
    }

    function updateWithdrawLimitDaily(uint256 _withdrawLimit) public onlySideChainOperator {
        emit WithdrawLimitDailyChanged(withdrawalLimitDaily, _withdrawLimit);
        withdrawalLimitDaily = _withdrawLimit;
    }

    function updateWithdrawLimitMonthly(uint256 _withdrawLimit) public onlySideChainOperator {
        emit WithdrawLimitMonthlyChanged(withdrawalLimitMonthly, _withdrawLimit);
        withdrawalLimitMonthly = _withdrawLimit;
    }

    function getTokenSentToLinkedChain(address _address) public view returns (uint256 _token) {
        return state.getTokenSentToLinkedChain(_address);
    }

    function getTokenClaimedOnThisChain(address _address) public view returns (uint256 _token)  {
        return state.getTokenClaimedOnThisChain(_address);
    }

    function getTokenSentToLinkedChainTime(address _address) public view returns (uint256 _time)  {
        return state.getTokenSentToLinkedChainTime(_address);
    }

    // ------------------------------------------------------------------------
    // verifyWithdrawOk(uint256 _amount)
    // Checks if creating _amount token on main chain does not violate the 24 hour transfer limit
    // ------------------------------------------------------------------------
    function verifyWithdrawOk(uint256 _amount) public returns (bool _authorized) {
        uint256 _lastWithdrawLimitReductionTime = state.lastWithdrawLimitReductionTime();
        uint256 _withdrawLimit24Hours = state.withdrawLimit24Hours();
        
        if (now > _lastWithdrawLimitReductionTime) {
            uint256 _timePassed = now.sub(_lastWithdrawLimitReductionTime);
            state.update24HoursWithdrawLimit(_timePassed.mul(_withdrawLimit24Hours).div(1 days));
        }
        
        if (state.last24HoursAmountWithdrawn().add(_amount) <= _withdrawLimit24Hours) {
            return true;
        } else {
            return false;
        }
    }

    function isNotDailyLimitExceeding(uint256 _amount) public view returns(bool) {
        return (withdrawalPerDay[msg.sender][block.timestamp / 1 days].add(_amount) <= withdrawalLimitDaily);
    }
    function isNotMonthlyLimitExceeding(uint256 _amount) public view returns(bool) {
        return (withdrawalPerMonth[msg.sender][block.timestamp / 30 days].add(_amount) <= withdrawalLimitMonthly);
    }

    function verifyUpdateDailyLimit(uint256 _amount) public {
        require(isNotDailyLimitExceeding(_amount), "MorpherBridge: Withdrawal Amount exceeds daily limit");
        withdrawalPerDay[msg.sender][block.timestamp / 1 days] = withdrawalPerDay[msg.sender][block.timestamp / 1 days].add(_amount);
    }

    function verifyUpdateMonthlyLimit(uint256 _amount) public {
        require(isNotMonthlyLimitExceeding(_amount), "MorpherBridge: Withdrawal Amount exceeds monthly limit");
        withdrawalPerMonth[msg.sender][block.timestamp / 30 days] = withdrawalPerMonth[msg.sender][block.timestamp / 30 days].add(_amount);
    }

    // ------------------------------------------------------------------------
    // transferToSideChain(uint256 _tokens)
    // Transfer token to Morpher's side chain to trade without fees and near instant
    // settlement.
    // - Owner's account must have sufficient balance to transfer
    // - 0 value transfers are not supported
    // Token are burned on the main chain and are created and credited to msg.sender
    //  on the side chain
    // ------------------------------------------------------------------------
    function transferToSideChain(uint256 _tokens) public {
        require(_tokens >= 0, "MorpherBridge: Amount of tokens must be positive.");
        require(state.balanceOf(msg.sender) >= _tokens, "MorpherBridge: Insufficient balance.");
        state.burn(msg.sender, _tokens);
        uint256 _newTokenSentToLinkedChain = getTokenSentToLinkedChain(msg.sender).add(_tokens);
        uint256 _transferNonce = state.getBridgeNonce();
        uint256 _timeStamp = now;
        bytes32 _transferHash = keccak256(
            abi.encodePacked(
                msg.sender,
                _tokens,
                _newTokenSentToLinkedChain,
                _timeStamp,
                _transferNonce
            )
        );
        state.setTokenSentToLinkedChain(msg.sender, _newTokenSentToLinkedChain);
        emit TransferToLinkedChain(msg.sender, _tokens, _newTokenSentToLinkedChain, _timeStamp, _transferNonce, _transferHash);
    }

    // ------------------------------------------------------------------------
    // fastTransferFromSideChain(uint256 _numOfToken, uint256 _tokenBurnedOnLinkedChain, bytes32[] memory _proof)
    // The sidechain operator can credit users with token they burend on the sidechain. Transfers
    // happen immediately. To be removed after Beta.
    // ------------------------------------------------------------------------
    function fastTransferFromSideChain(address _address, uint256 _numOfToken, uint256 _tokenBurnedOnLinkedChain, bytes32 _sidechainTransactionHash) public onlySideChainOperator fastTransfers {
        uint256 _tokenClaimed = state.getTokenClaimedOnThisChain(_address);
        require(verifyWithdrawOk(_numOfToken), "MorpherBridge: Withdraw amount exceeds permitted 24 hour limit. Please try again in a few hours.");
        require(_tokenClaimed.add(_numOfToken) <= _tokenBurnedOnLinkedChain, "MorpherBridge: Token amount exceeds token deleted on linked chain.");
        _chainTransfer(_address, _tokenClaimed, _numOfToken);
        emit OperatorChainTransfer(_address, _numOfToken, _sidechainTransactionHash);
    }
    
    // ------------------------------------------------------------------------
    // trustlessTransferFromSideChain(uint256 _numOfToken, uint256 _claimLimit, bytes32[] memory _proof)
    // Performs a merkle proof on the number of token that have been burned by the user on the side chain.
    // If the number of token claimed on the main chain is less than the number of burned token on the side chain
    // the difference (or less) can be claimed on the main chain.
    // ------------------------------------------------------------------------
    function trustlessTransferFromLinkedChain(uint256 _numOfToken, uint256 _claimLimit, bytes32[] memory _proof) public {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, _claimLimit));
        uint256 _tokenClaimed = state.getTokenClaimedOnThisChain(msg.sender);        
        require(mProof(_proof, leaf), "MorpherBridge: Merkle Proof failed. Please make sure you entered the correct claim limit.");
        require(verifyWithdrawOk(_numOfToken), "MorpherBridge: Withdraw amount exceeds permitted 24 hour limit. Please try again in a few hours.");
        verifyUpdateDailyLimit(_numOfToken);
        verifyUpdateMonthlyLimit(_numOfToken);
        require(_tokenClaimed.add(_numOfToken) <= _claimLimit, "MorpherBridge: Token amount exceeds token deleted on linked chain.");     
        _chainTransfer(msg.sender, _tokenClaimed, _numOfToken);   
        emit TrustlessWithdrawFromSideChain(msg.sender, _numOfToken);
    }
    
    // ------------------------------------------------------------------------
    // _chainTransfer(address _address, uint256 _tokenClaimed, uint256 _numOfToken)
    // Creates token on the chain for the user after proving their distruction on the 
    // linked chain has been proven before 
    // ------------------------------------------------------------------------
    function _chainTransfer(address _address, uint256 _tokenClaimed, uint256 _numOfToken) private {
        state.setTokenClaimedOnThisChain(_address, _tokenClaimed.add(_numOfToken));
        state.add24HoursWithdrawn(_numOfToken);
        state.mint(_address, _numOfToken);
    }
        
    // ------------------------------------------------------------------------
    // claimFailedTransferToSidechain(uint256 _wrongSideChainBalance, bytes32[] memory _proof)
    // If token sent to side chain were not credited to the user on the side chain within inactivityPeriod
    // they can reclaim the token on the main chain by submitting the proof that their
    // side chain balance is less than the number of token sent from main chain.
    // ------------------------------------------------------------------------
    function claimFailedTransferToSidechain(uint256 _wrongSideChainBalance, bytes32[] memory _proof) public {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, _wrongSideChainBalance));
        uint256 _tokenSentToLinkedChain = getTokenSentToLinkedChain(msg.sender);
        uint256 _tokenSentToLinkedChainTime = getTokenSentToLinkedChainTime(msg.sender);
        uint256 _inactivityPeriod = state.inactivityPeriod();
        
        require(now > _tokenSentToLinkedChainTime.add(_inactivityPeriod), "MorpherBridge: Failed deposits can only be claimed after inactivity period.");
        require(_wrongSideChainBalance < _tokenSentToLinkedChain, "MorpherBridge: Other chain credit is greater equal to wrongSideChainBalance.");
        require(verifyWithdrawOk(_tokenSentToLinkedChain.sub(_wrongSideChainBalance)), "MorpherBridge: Claim amount exceeds permitted 24 hour limit.");
        require(mProof(_proof, leaf), "MorpherBridge: Merkle Proof failed. Enter total amount of deposits on side chain.");
        
        uint256 _claimAmount = _tokenSentToLinkedChain.sub(_wrongSideChainBalance);
        state.setTokenSentToLinkedChain(msg.sender, _tokenSentToLinkedChain.sub(_claimAmount));
        state.add24HoursWithdrawn(_claimAmount);
        state.mint(msg.sender, _claimAmount);
        emit ClaimFailedTransferToSidechain(msg.sender, _claimAmount);
    }

    // ------------------------------------------------------------------------
    // recoverPositionFromSideChain(bytes32[] memory _proof, bytes32 _leaf, bytes32 _marketId, uint256 _timeStamp, uint256 _longShares, uint256 _shortShares, uint256 _meanEntryPrice, uint256 _meanEntrySpread, uint256 _meanEntryLeverage)
    // Failsafe against side chain operator becoming inactive or withholding Times (Time withhold attack).
    // After 72 hours of no update of the side chain merkle root users can withdraw their last recorded
    // positions from side chain to main chain. Overwrites eventually existing position on main chain.
    // ------------------------------------------------------------------------
    function recoverPositionFromSideChain(
        bytes32[] memory _proof,
        bytes32 _leaf,
        bytes32 _marketId,
        uint256 _timeStamp,
        uint256 _longShares,
        uint256 _shortShares,
        uint256 _meanEntryPrice,
        uint256 _meanEntrySpread,
        uint256 _meanEntryLeverage,
        uint256 _liquidationPrice
        ) public sideChainInactive onlyMainchain {
        require(_leaf == state.getPositionHash(msg.sender, _marketId, _timeStamp, _longShares, _shortShares, _meanEntryPrice, _meanEntrySpread, _meanEntryLeverage, _liquidationPrice), "MorpherBridge: leaf does not equal position hash.");
        require(state.getPositionClaimedOnMainChain(_leaf) == false, "MorpherBridge: Position already transferred.");
        require(mProof(_proof,_leaf) == true, "MorpherBridge: Merkle proof failed.");
        state.setPositionClaimedOnMainChain(_leaf);
        state.setPosition(msg.sender, _marketId, _timeStamp, _longShares, _shortShares, _meanEntryPrice, _meanEntrySpread, _meanEntryLeverage, _liquidationPrice);
        emit PositionRecoveryFromSideChain(msg.sender, _leaf);
        // Remark: After resuming operations side chain operator has 72 hours to sync and eliminate transferred positions on side chain to avoid double spend
    }

    // ------------------------------------------------------------------------
    // recoverTokenFromSideChain(bytes32[] memory _proof, bytes32 _leaf, bytes32 _marketId, uint256 _timeStamp, uint256 _longShares, uint256 _shortShares, uint256 _meanEntryPrice, uint256 _meanEntrySpread, uint256 _meanEntryLeverage)
    // Failsafe against side chain operator becoming inactive or withholding times (time withhold attack).
    // After 72 hours of no update of the side chain merkle root users can withdraw their last recorded
    // token balance from side chain to main chain.
    // ------------------------------------------------------------------------
    function recoverTokenFromSideChain(bytes32[] memory _proof, bytes32 _leaf, uint256 _balance) public sideChainInactive onlyMainchain {
        // Require side chain root hash not set on Mainchain for more than 72 hours (=3 days)
        require(_leaf == state.getBalanceHash(msg.sender, _balance), "MorpherBridge: Wrong balance.");
        require(state.getPositionClaimedOnMainChain(_leaf) == false, "MorpherBridge: Token already transferred.");
        require(mProof(_proof,_leaf) == true, "MorpherBridge: Merkle proof failed.");
        require(verifyWithdrawOk(_balance), "MorpherBridge: Withdraw amount exceeds permitted 24 hour limit.");
        state.setPositionClaimedOnMainChain(_leaf);
        _chainTransfer(msg.sender, state.getTokenClaimedOnThisChain(msg.sender), _balance);
        emit TokenRecoveryFromSideChain(msg.sender, _leaf);
        // Remark: Side chain operator must adjust side chain balances for token recoveries before restarting operations to avoid double spend
    }

    // ------------------------------------------------------------------------
    // mProof(bytes32[] memory _proof, bytes32 _leaf)
    // Computes merkle proof against the root hash of the sidechain stored in Morpher state
    // ------------------------------------------------------------------------
    function mProof(bytes32[] memory _proof, bytes32 _leaf) public view returns(bool _isTrue) {
        return MerkleProof.verify(_proof, state.getSideChainMerkleRoot(), _leaf);
    }
}pragma solidity 0.5.16;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./IERC20.sol";

// ----------------------------------------------------------------------------------
// Escrow contract to safely store and release the token allocated to Morpher at
// protocol inception
// ----------------------------------------------------------------------------------

contract MorpherEscrow is Ownable{
    using SafeMath for uint256;

    uint256 public lastEscrowTransferTime;
    address public recipient;
    address public morpherToken;

    uint256 public constant RELEASEAMOUNT = 10**25;
    uint256 public constant RELEASEPERIOD = 30 days;

    event EscrowReleased(uint256 _released, uint256 _leftInEscrow);

    constructor(address _recipientAddress, address _morpherToken, address _coldStorageOwnerAddress) public {
        setRecipientAddress(_recipientAddress);
        setMorpherTokenAddress(_morpherToken);
        lastEscrowTransferTime = now;
        transferOwnership(_coldStorageOwnerAddress);
    }

    // ----------------------------------------------------------------------------------
    // Owner can modify recipient address and update morpherToken adddress
    // ----------------------------------------------------------------------------------
    function setRecipientAddress(address _recipientAddress) public onlyOwner {
        recipient = _recipientAddress;
    }

    function setMorpherTokenAddress(address _address) public onlyOwner {
        morpherToken = _address;
    }

    // ----------------------------------------------------------------------------------
    // Anyone can release funds from escrow if enough time has elapsed
    // Every 30 days 1% of the total initial supply or 10m token are released to Morpher
    // ----------------------------------------------------------------------------------
    function releaseFromEscrow() public {
        require(IERC20(morpherToken).balanceOf(address(this)) > 0, "No funds left in escrow.");
        uint256 _releasedAmount;
        if (now > lastEscrowTransferTime.add(RELEASEPERIOD)) {
            if (IERC20(morpherToken).balanceOf(address(this)) > RELEASEAMOUNT) {
                _releasedAmount = RELEASEAMOUNT;
            } else {
                _releasedAmount = IERC20(morpherToken).balanceOf(address(this));
            }
            IERC20(morpherToken).transfer(recipient, _releasedAmount);
            lastEscrowTransferTime = lastEscrowTransferTime.add(RELEASEPERIOD);
            emit EscrowReleased(_releasedAmount, IERC20(morpherToken).balanceOf(address(this)));
        }
    }
}pragma solidity 0.5.16;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./MorpherToken.sol";

// ----------------------------------------------------------------------------------
// Holds the Faucet Token balance on contract addressrdrop.
// Users can topup to fillUpAmount
// ----------------------------------------------------------------------------------

contract MorpherFaucet is Ownable {
    using SafeMath for uint256;

    MorpherToken morpherToken;

    uint public fillUpAmount; //100 * 10**18; //fill up to 100 MPH.

    event MorpherFaucetTopUp(address indexed _receiver, uint _amount);
    event MorpherFaucetFillUpAmountChanged(uint _oldAmount, uint _newAmount);

    constructor(address payable _morpherToken, address _coldStorageOwnerAddress, uint _fillUpAmount) public {
        morpherToken = MorpherToken(_morpherToken);
        transferOwnership(_coldStorageOwnerAddress);
        setFillUpAmount(_fillUpAmount);
    }
  
    function setMorpherTokenAddress(address payable _address) public onlyOwner {
        morpherToken = MorpherToken(_address);
    }

    function setFillUpAmount(uint _newFillUpAmount) public onlyOwner {
        emit MorpherFaucetFillUpAmountChanged(fillUpAmount, _newFillUpAmount);
        fillUpAmount = _newFillUpAmount;
    }


    /**
     * Only important function: User can top-up to his max amount. Needs to have less than fillUpAmount, otherwise it will fail.
     */
    function topUpToken() public {
        require(morpherToken.balanceOf(msg.sender) < fillUpAmount, "FILLUP_AMOUNT_REACHED");
        morpherToken.transfer(msg.sender, fillUpAmount.sub(morpherToken.balanceOf(msg.sender)));
        emit MorpherFaucetTopUp(msg.sender, fillUpAmount.sub(morpherToken.balanceOf(msg.sender)));
    }

    function () external payable {
        revert("MorpherFaucet: you can't deposit Ether here");
    }


}pragma solidity 0.5.16;
// ------------------------------------------------------------------------
// Morpher Governance (MAIN CHAIN ONLY)
//
// Every user able and willig to lock up sufficient token can become a validator
// of the Morpher protocol. Validators function similiar to a board of directors
// and vote on the protocol Administrator and the Oracle contract.
// The Administrator (=Protocol CEO) has the power to add/delete markets and to
// pause the contracts to allow for updates.
// The Oracle contract is the address of the contract allowed to fetch prices
// from outside the smart contract.
//
// It becomes progressively harder to become a valdiator. Each new validator
// has to lock up (numberOfValidators + 1) * 10m Morpher token. Upon stepping
// down as validator only 99% of the locked up token are returned, the other 1%
// are burned.
//
// Governance is expected to become more sophisticated in the future
// ------------------------------------------------------------------------

import "./Ownable.sol";
import "./SafeMath.sol";
import "./MorpherState.sol";

contract MorpherGovernance is Ownable {

    using SafeMath for uint256;
    MorpherState state;
    
    event BecomeValidator(address indexed _sender, uint256 indexed _myValidatorIndex);
    event StepDownAsValidator(address indexed _sender, uint256 indexed _myValidatorIndex);
    event ElectedAdministrator(address indexed _administratorAddress, uint256 _votes);
    event ElectedOracle(address indexed _oracleAddress, uint256 _votes);

    uint256 public constant MINVALIDATORLOCKUP = 10**25;
    uint256 public constant MAXVALIDATORS = 21;
    uint256 public constant VALIDATORWARMUPPERIOD = 7 days;

    uint256 public numberOfValidators;
    uint256 public lastValidatorJoined;
    uint256 public rewardBasisPoints;

    address public morpherToken;

    mapping(address => uint256) private validatorIndex;
    mapping(address => uint256) private validatorJoinedAtTime;
    mapping(uint256 => address) private validatorAddress;
    mapping(address => address) private oracleVote;
    mapping(address => address) private administratorVote;
    mapping(address => uint256) private countVotes;

    constructor(address _stateAddress, address _coldStorageOwnerAddress) public {
        setMorpherState(_stateAddress);
        transferOwnership(_coldStorageOwnerAddress);        
    }
    
    modifier onlyValidator() {
        require(isValidator(msg.sender), "MorpherGovernance: Only Validators can invoke that function.");
        _;
    }

    function setMorpherState(address _stateAddress) private {
        state = MorpherState(_stateAddress);
    }

    function setMorpherTokenAddress(address _address) public onlyOwner {
        morpherToken = _address;
    }

    function getValidatorAddress(uint256 _index) public view returns (address _address) {
        return validatorAddress[_index];
    }

    function getValidatorIndex(address _address) public view returns (uint256 _index) {
        return validatorIndex[_address];
    }

    function isValidator(address _address) public view returns (bool) {
        return validatorIndex[_address] > 0;
    }

    function setOracle(address  _oracleAddress) private {
        state.setOracleContract(_oracleAddress);
    }

    function setAdministrator(address _administratorAddress) private {
        state.setAdministrator(_administratorAddress);
    }

    function getMorpherAdministrator() public view returns (address _address) {
        return state.getAdministrator();
    }

    function getMorpherOracle() public view returns (address _address)  {
        return state.getOracleContract();
    }

    function getOracleVote(address _address) public view returns (address _votedOracleAddress) {
        return oracleVote[_address];
    }

    function becomeValidator() public {
        // To become a validator you have to lock up 10m * (number of validators + 1) Morpher Token in escrow
        // After a warmup period of 7 days the new validator can vote on Oracle contract and protocol Administrator
        uint256 _requiredAmount = MINVALIDATORLOCKUP.mul(numberOfValidators.add(1));
        require(state.balanceOf(msg.sender) >= _requiredAmount, "MorpherGovernance: Insufficient balance to become Validator.");
        require(isValidator(msg.sender) == false, "MorpherGovernance: Address is already Validator.");
        require(numberOfValidators <= MAXVALIDATORS, "MorpherGovernance: number of Validators can not exceed Max Validators.");
        state.transfer(msg.sender, address(this), _requiredAmount);
        numberOfValidators = numberOfValidators.add(1);
        validatorIndex[msg.sender] = numberOfValidators;
        validatorJoinedAtTime[msg.sender] = now;
        lastValidatorJoined = now;
        validatorAddress[numberOfValidators] = msg.sender;
        emit BecomeValidator(msg.sender, numberOfValidators);
    }

    function stepDownValidator() public onlyValidator {
        // Stepping down as validator nullifies the validator's votes and releases his token
        // from escrow. If the validator stepping down is not the validator that joined last,
        // all validators who joined after the validator stepping down receive 10^7 * 0.99 token from
        // escrow, and their validator ordinal number is reduced by one. E.g. if validator 3 of 5 steps down
        // validator 4 becomes validator 3, and validator 5 becomes validator 4. Both receive 10^7 * 0.99 token
        // from escrow, as their new position requires fewer token in lockup. 1% of the token released from escrow 
        // are burned for every validator receiving a payout. 
        // Burning prevents vote delay attacks: validators stepping down and re-joining could
        // delay votes for VALIDATORWARMUPPERIOD.
        uint256 _myValidatorIndex = validatorIndex[msg.sender];
        require(state.balanceOf(address(this)) >= MINVALIDATORLOCKUP.mul(numberOfValidators), "MorpherGovernance: Escrow does not have enough funds. Should not happen.");
        // Stepping down as validator potentially releases token to the other validatorAddresses
        for (uint256 i = _myValidatorIndex; i < numberOfValidators; i++) {
            validatorAddress[i] = validatorAddress[i+1];
            validatorIndex[validatorAddress[i]] = i;
            // Release 9.9m of token to every validator moving up, burn 0.1m token
            state.transfer(address(this), validatorAddress[i], MINVALIDATORLOCKUP.div(100).mul(99));
            state.burn(address(this), MINVALIDATORLOCKUP.div(100));
        }
        // Release 99% of escrow token of validator dropping out, burn 1%
        validatorAddress[numberOfValidators] = address(0);
        validatorIndex[msg.sender] = 0;
        validatorJoinedAtTime[msg.sender] = 0;
        oracleVote[msg.sender] = address(0);
        administratorVote[msg.sender] = address(0);
        numberOfValidators = numberOfValidators.sub(1);
        countOracleVote();
        countAdministratorVote();
        state.transfer(address(this), msg.sender, MINVALIDATORLOCKUP.mul(_myValidatorIndex).div(100).mul(99));
        state.burn(address(this), MINVALIDATORLOCKUP.mul(_myValidatorIndex).div(100));
        emit StepDownAsValidator(msg.sender, validatorIndex[msg.sender]);
    }

    function voteOracle(address _oracleAddress) public onlyValidator {
        require(validatorJoinedAtTime[msg.sender].add(VALIDATORWARMUPPERIOD) < now, "MorpherGovernance: Validator was just appointed and is not eligible to vote yet.");
        require(lastValidatorJoined.add(VALIDATORWARMUPPERIOD) < now, "MorpherGovernance: New validator joined the board recently, please wait for the end of the warm up period.");
        oracleVote[msg.sender] = _oracleAddress;
        // Count Oracle Votes
        (address _votedOracleAddress, uint256 _votes) = countOracleVote();
        emit ElectedOracle(_votedOracleAddress, _votes);
    }

    function voteAdministrator(address _administratorAddress) public onlyValidator {
        require(validatorJoinedAtTime[msg.sender].add(VALIDATORWARMUPPERIOD) < now, "MorpherGovernance: Validator was just appointed and is not eligible to vote yet.");
        require(lastValidatorJoined.add(VALIDATORWARMUPPERIOD) < now, "MorpherGovernance: New validator joined the board recently, please wait for the end of the warm up period.");
        administratorVote[msg.sender] = _administratorAddress;
        // Count Administrator Votes
        (address _appointedAdministrator, uint256 _votes) = countAdministratorVote();
        emit ElectedAdministrator(_appointedAdministrator, _votes);
    }

    function countOracleVote() public returns (address _votedOracleAddress, uint256 _votes) {
        // Count oracle votes
        for (uint256 i = 1; i <= numberOfValidators; i++) {
            countVotes[oracleVote[validatorAddress[i]]]++;
            if (countVotes[oracleVote[validatorAddress[i]]] > _votes) {
                _votes = countVotes[oracleVote[validatorAddress[i]]];
                _votedOracleAddress = oracleVote[validatorAddress[i]];
            }
        }
        // Evaluate: Simple majority of Validators resets oracleAddress
        if (_votes > numberOfValidators.div(2)) {
            setOracle(_votedOracleAddress);
        }
        for (uint256 i = 1; i <= numberOfValidators; i++) {
            countVotes[administratorVote[validatorAddress[i]]] = 0;
        }
        return(_votedOracleAddress, _votes);
    }

    function countAdministratorVote() public returns (address _appointedAdministrator, uint256 _votes) {
        // Count Administrator votes
        for (uint256 i=1; i<=numberOfValidators; i++) {
            countVotes[administratorVote[validatorAddress[i]]]++;
            if (countVotes[administratorVote[validatorAddress[i]]] > _votes) {
                _votes = countVotes[administratorVote[validatorAddress[i]]];
                _appointedAdministrator = administratorVote[validatorAddress[i]];
            }
        }
        // Evaluate: Simple majority of Validators resets administratorAddress
        if (_votes > numberOfValidators / 2) {
            setAdministrator(_appointedAdministrator);
        }
        for (uint256 i = 1; i <= numberOfValidators; i++) {
            countVotes[administratorVote[validatorAddress[i]]] = 0;
        }
        return(_appointedAdministrator, _votes);
    }
}pragma solidity 0.5.16;

import "./MorpherState.sol";
import "./MorpherTradeEngine.sol";
import "./SafeMath.sol";

contract MorpherMintingLimiter {
    using SafeMath for uint256; 

    uint256 public mintingLimitPerUser;
    uint256 public mintingLimitDaily;
    uint256 public timeLockingPeriod;

    mapping(address => uint256) public escrowedTokens;
    mapping(address => uint256) public lockedUntil;
    mapping(uint256 => uint256) public dailyMintedTokens;

    address tradeEngineAddress; 
    MorpherState state;

    event MintingEscrowed(address _user, uint256 _tokenAmount);
    event EscrowReleased(address _user, uint256 _tokenAmount);
    event MintingDenied(address _user, uint256 _tokenAmount);
    event MintingLimitUpdatedPerUser(uint256 _mintingLimitOld, uint256 _mintingLimitNew);
    event MintingLimitUpdatedDaily(uint256 _mintingLimitOld, uint256 _mintingLimitNew);
    event TimeLockPeriodUpdated(uint256 _timeLockPeriodOld, uint256 _timeLockPeriodNew);
    event TradeEngineAddressSet(address _tradeEngineAddress);
    event DailyMintedTokensReset();

    modifier onlyTradeEngine() {
        require(msg.sender == tradeEngineAddress, "MorpherMintingLimiter: Only Trade Engine is allowed to call this function");
        _;
    }

    modifier onlyAdministrator() {
        require(msg.sender == state.getAdministrator(), "MorpherMintingLimiter: Only Administrator can call this function");
        _;
    }

    constructor(address _stateAddress, uint256 _mintingLimitPerUser, uint256 _mintingLimitDaily, uint256 _timeLockingPeriodInSeconds) public {
        state = MorpherState(_stateAddress);
        mintingLimitPerUser = _mintingLimitPerUser;
        mintingLimitDaily = _mintingLimitDaily;
        timeLockingPeriod = _timeLockingPeriodInSeconds;
    }

    function setTradeEngineAddress(address _tradeEngineAddress) public onlyAdministrator {
        emit TradeEngineAddressSet(_tradeEngineAddress);
        tradeEngineAddress = _tradeEngineAddress;
    }
    

    function setMintingLimitDaily(uint256 _newMintingLimit) public onlyAdministrator {
        emit MintingLimitUpdatedDaily(mintingLimitDaily, _newMintingLimit);
        mintingLimitDaily = _newMintingLimit;
    }
    function setMintingLimitPerUser(uint256 _newMintingLimit) public onlyAdministrator {
        emit MintingLimitUpdatedPerUser(mintingLimitDaily, _newMintingLimit);
        mintingLimitPerUser = _newMintingLimit;
    }

    function setTimeLockingPeriod(uint256 _newTimeLockingPeriodInSeconds) public onlyAdministrator {
        emit TimeLockPeriodUpdated(timeLockingPeriod, _newTimeLockingPeriodInSeconds);
        timeLockingPeriod = _newTimeLockingPeriodInSeconds;
    }

    function mint(address _user, uint256 _tokenAmount) public onlyTradeEngine {
        uint256 mintingDay = block.timestamp / 1 days;
        if((mintingLimitDaily == 0 || dailyMintedTokens[mintingDay].add(_tokenAmount) <= mintingLimitDaily) && (mintingLimitPerUser == 0 || _tokenAmount <= mintingLimitPerUser )) {
            state.mint(_user, _tokenAmount);
            dailyMintedTokens[mintingDay] = dailyMintedTokens[mintingDay].add(_tokenAmount);
        } else {
            escrowedTokens[_user] = escrowedTokens[_user].add(_tokenAmount);
            lockedUntil[_user] = block.timestamp + timeLockingPeriod;
            emit MintingEscrowed(_user, _tokenAmount);
        }
    }

    function delayedMint(address _user) public {
        require(lockedUntil[_user] <= block.timestamp, "MorpherMintingLimiter: Funds are still time locked");
        uint256 sendAmount = escrowedTokens[_user];
        escrowedTokens[_user] = 0;
        state.mint(_user, sendAmount);
        emit EscrowReleased(_user, sendAmount);
    }

    function adminApprovedMint(address _user, uint256 _tokenAmount) public onlyAdministrator {
        escrowedTokens[_user] = escrowedTokens[_user].sub(_tokenAmount);
        state.mint(_user, _tokenAmount);
        emit EscrowReleased(_user, _tokenAmount);
    }

    function adminDisapproveMint(address _user, uint256 _tokenAmount) public onlyAdministrator {
        escrowedTokens[_user] = escrowedTokens[_user].sub(_tokenAmount);
        emit MintingDenied(_user, _tokenAmount);
    }

    function resetDailyMintedTokens() public onlyAdministrator {
        dailyMintedTokens[block.timestamp / 1 days] = 0;
        emit DailyMintedTokensReset();
    }

    function getDailyMintedTokens() public view returns(uint256) {
        return dailyMintedTokens[block.timestamp / 1 days];
    }
}pragma solidity 0.5.16;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./IMorpherState.sol";

// ----------------------------------------------------------------------------------
// Staking Morpher Token generates interest
// The interest is set to 0.015% a day or ~5.475% in the first year
// Stakers will be able to vote on all ProtocolDecisions in MorpherGovernance (soon...)
// There is a lockup after staking or topping up (30 days) and a minimum stake (100k MPH)
// ----------------------------------------------------------------------------------

contract MorpherStaking is Ownable {
    using SafeMath for uint256;
    IMorpherState state;

    uint256 constant PRECISION = 10**8;
    uint256 constant INTERVAL  = 1 days;

    //mapping(address => uint256) private poolShares;
    //mapping(address => uint256) private lockup;

    uint256 public poolShareValue = PRECISION;
    uint256 public lastReward;
    uint256 public totalShares;
    uint256 public interestRate = 15000; // 0.015% per day initially, diminishing returns over time
    uint256 public lockupPeriod = 30 days; // to prevent tactical staking and ensure smooth governance
    uint256 public minimumStake = 10**23; // 100k MPH minimum

    address public stakingAdmin;

    address public stakingAddress = 0x2222222222222222222222222222222222222222;
    bytes32 public marketIdStakingMPH = 0x9a31fdde7a3b1444b1befb10735dcc3b72cbd9dd604d2ff45144352bf0f359a6; //STAKING_MPH

// ----------------------------------------------------------------------------
// Events
// ----------------------------------------------------------------------------
    event SetInterestRate(uint256 newInterestRate);
    event SetLockupPeriod(uint256 newLockupPeriod);
    event SetMinimumStake(uint256 newMinimumStake);
    event LinkState(address stateAddress);
    event SetStakingAdmin(address stakingAdmin);
    
    event PoolShareValueUpdated(uint256 indexed lastReward, uint256 poolShareValue);
    event StakingRewardsMinted(uint256 indexed lastReward, uint256 delta);
    event Staked(address indexed userAddress, uint256 indexed amount, uint256 poolShares, uint256 lockedUntil);
    event Unstaked(address indexed userAddress, uint256 indexed amount, uint256 poolShares);
    
    modifier onlyStakingAdmin {
        require(msg.sender == stakingAdmin, "MorpherStaking: can only be called by Staking Administrator.");
        _;
    }
    
    constructor(address _morpherState, address _stakingAdmin) public {
        setStakingAdmin(_stakingAdmin);
        setMorpherStateAddress(_morpherState);
        emit SetLockupPeriod(lockupPeriod);
        emit SetMinimumStake(minimumStake);
        emit SetInterestRate(interestRate);
        lastReward = now;
        // missing: transferOwnership to Governance once deployed
    }

// ----------------------------------------------------------------------------
// updatePoolShareValue
// Updates the value of the Pool Shares and returns the new value.
// Staking rewards are linear, there is no compound interest.
// ----------------------------------------------------------------------------
    
    function updatePoolShareValue() public returns (uint256 _newPoolShareValue) {
        if (now >= lastReward.add(INTERVAL)) {
            uint256 _numOfIntervals = now.sub(lastReward).div(INTERVAL);
            poolShareValue = poolShareValue.add(_numOfIntervals.mul(interestRate));
            lastReward = lastReward.add(_numOfIntervals.mul(INTERVAL));
            emit PoolShareValueUpdated(lastReward, poolShareValue);
        }
        mintStakingRewards();
        return poolShareValue;        
    }

// ----------------------------------------------------------------------------
// Staking rewards are minted if necessary
// ----------------------------------------------------------------------------

    function mintStakingRewards() private {
        uint256 _targetBalance = poolShareValue.mul(totalShares);
        if (state.balanceOf(stakingAddress) < _targetBalance) {
            // If there are not enough token held by the contract, mint them
            uint256 _delta = _targetBalance.sub(state.balanceOf(stakingAddress));
            state.mint(stakingAddress, _delta);
            emit StakingRewardsMinted(lastReward, _delta);
        }
    }

// ----------------------------------------------------------------------------
// stake(uint256 _amount)
// User specifies an amount they intend to stake. Pool Shares are issued accordingly
// and the _amount is transferred to the staking contract
// ----------------------------------------------------------------------------

    function stake(uint256 _amount) public returns (uint256 _poolShares) {
        require(state.balanceOf(msg.sender) >= _amount, "MorpherStaking: insufficient MPH token balance");
        updatePoolShareValue();
        _poolShares = _amount.div(poolShareValue);
        (uint256 _numOfShares, , , , , ) = state.getPosition(msg.sender, marketIdStakingMPH);
        require(minimumStake <= _numOfShares.add(_poolShares).mul(poolShareValue), "MorpherStaking: stake amount lower than minimum stake");
        state.transfer(msg.sender, stakingAddress, _poolShares.mul(poolShareValue));
        totalShares = totalShares.add(_poolShares);
        state.setPosition(msg.sender, marketIdStakingMPH, now.add(lockupPeriod), _numOfShares.add(_poolShares), 0, 0, 0, 0, 0);
        emit Staked(msg.sender, _amount, _poolShares, now.add(lockupPeriod));
        return _poolShares;
    }

// ----------------------------------------------------------------------------
// unstake(uint256 _amount)
// User specifies number of Pool Shares they want to unstake. 
// Pool Shares get deleted and the user receives their MPH plus interest
// ----------------------------------------------------------------------------

    function unstake(uint256 _numOfShares) public returns (uint256 _amount) {
        (uint256 _numOfExistingShares, , , , , ) = state.getPosition(msg.sender, marketIdStakingMPH);
        require(_numOfShares <= _numOfExistingShares, "MorpherStaking: insufficient pool shares");

        uint256 lockedInUntil = state.getLastUpdated(msg.sender, marketIdStakingMPH);
        require(now >= lockedInUntil, "MorpherStaking: cannot unstake before lockup expiration");
        updatePoolShareValue();
        state.setPosition(msg.sender, marketIdStakingMPH, lockedInUntil, _numOfExistingShares.sub(_numOfShares), 0, 0, 0, 0, 0);
        totalShares = totalShares.sub(_numOfShares);
        _amount = _numOfShares.mul(poolShareValue);
        state.transfer(stakingAddress, msg.sender, _amount);
        emit Unstaked(msg.sender, _amount, _numOfShares);
        return _amount;
    }

// ----------------------------------------------------------------------------
// Administrative functions
// ----------------------------------------------------------------------------

    function setStakingAdmin(address _address) public onlyOwner {
        stakingAdmin = _address;
        emit SetStakingAdmin(_address);
    }

    function setMorpherStateAddress(address _stateAddress) public onlyOwner {
        state = IMorpherState(_stateAddress);
        emit LinkState(_stateAddress);
    }

    function setInterestRate(uint256 _interestRate) public onlyStakingAdmin {
        interestRate = _interestRate;
        emit SetInterestRate(_interestRate);
    }

    function setLockupPeriodRate(uint256 _lockupPeriod) public onlyStakingAdmin {
        lockupPeriod = _lockupPeriod;
        emit SetLockupPeriod(_lockupPeriod);
    }
    
    function setMinimumStake(uint256 _minimumStake) public onlyStakingAdmin {
        minimumStake = _minimumStake;
        emit SetMinimumStake(_minimumStake);
    }

// ----------------------------------------------------------------------------
// Getter functions
// ----------------------------------------------------------------------------

    function getTotalPooledValue() public view returns (uint256 _totalPooled) {
        // Only accurate if poolShareValue is up to date
        return poolShareValue.mul(totalShares);
    }

    function getStake(address _address) public view returns (uint256 _poolShares) {
        (uint256 _numOfShares, , , , , ) = state.getPosition(_address, marketIdStakingMPH);
        return _numOfShares;
    }

    function getStakeValue(address _address) public view returns(uint256 _value, uint256 _lastUpdate) {
        // Only accurate if poolShareValue is up to date
        
        (uint256 _numOfShares, , , , , ) = state.getPosition(_address, marketIdStakingMPH);

        return (_numOfShares.mul(poolShareValue), lastReward);
    }
    
// ------------------------------------------------------------------------
// Don't accept ETH
// ------------------------------------------------------------------------

    function () external payable {
        revert("MorpherStaking: you can't deposit Ether here");
    }
}pragma solidity 0.5.16;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./IMorpherToken.sol";

// ----------------------------------------------------------------------------------
// Data and token balance storage of the Morpher platform
// Writing access is only granted to platform contracts. The contract can be paused
// by an elected platform administrator (see MorpherGovernance) to perform protocol updates.
// ----------------------------------------------------------------------------------

contract MorpherState is Ownable {
    using SafeMath for uint256;

    bool public mainChain;
    uint256 public totalSupply;
    uint256 public totalToken;
    uint256 public totalInPositions;
    uint256 public totalOnOtherChain;
    uint256 public maximumLeverage = 10**9; // Leverage precision is 1e8, maximum leverage set to 10 initially
    uint256 constant PRECISION = 10**8;
    uint256 constant DECIMALS = 18;
    uint256 constant REWARDPERIOD = 1 days;
    bool public paused = false;

    address public morpherGovernance;
    address public morpherRewards;
    address public administrator;
    address public oracleContract;
    address public sideChainOperator;
    address public morpherBridge;
    address public morpherToken;

    uint256 public rewardBasisPoints;
    uint256 public lastRewardTime;

    bytes32 public sideChainMerkleRoot;
    uint256 public sideChainMerkleRootWrittenAtTime;

    // Set initial withdraw limit from sidechain to 20m token or 2% of initial supply
    uint256 public mainChainWithdrawLimit24 = 2 * 10**25;

    mapping(address => bool) private stateAccess;
    mapping(address => bool) private transferAllowed;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowed;

    mapping(bytes32 => bool) private marketActive;

    // ----------------------------------------------------------------------------
    // Position struct records virtual futures
    // ----------------------------------------------------------------------------
    struct position {
        uint256 lastUpdated;
        uint256 longShares;
        uint256 shortShares;
        uint256 meanEntryPrice;
        uint256 meanEntrySpread;
        uint256 meanEntryLeverage;
        uint256 liquidationPrice;
        bytes32 positionHash;
    }

    // ----------------------------------------------------------------------------
    // A portfolio is an address specific collection of postions
    // ----------------------------------------------------------------------------
    mapping(address => mapping(bytes32 => position)) private portfolio;

    // ----------------------------------------------------------------------------
    // Record all addresses that hold a position of a market, needed for clean stock splits
    // ----------------------------------------------------------------------------
    struct hasExposure {
        uint256 maxMappingIndex;
        mapping(address => uint256) index;
        mapping(uint256 => address) addy;
    }

    mapping(bytes32 => hasExposure) private exposureByMarket;

    // ----------------------------------------------------------------------------
    // Bridge Variables
    // ----------------------------------------------------------------------------
    mapping (address => uint256) private tokenClaimedOnThisChain;
    mapping (address => uint256) private tokenSentToLinkedChain;
    mapping (address => uint256) private tokenSentToLinkedChainTime;
    mapping (bytes32 => bool) private positionClaimedOnMainChain;

    uint256 public lastWithdrawLimitReductionTime;
    uint256 public last24HoursAmountWithdrawn;
    uint256 public withdrawLimit24Hours;
    uint256 public inactivityPeriod = 3 days;
    uint256 public transferNonce;
    bool public fastTransfersEnabled;

    // ----------------------------------------------------------------------------
    // Sidechain spam protection
    // ----------------------------------------------------------------------------

    mapping(address => uint256) private lastRequestBlock;
    mapping(address => uint256) private numberOfRequests;
    uint256 public numberOfRequestsLimit;

    // ----------------------------------------------------------------------------
    // Events
    // ----------------------------------------------------------------------------
    event StateAccessGranted(address indexed whiteList, uint256 indexed blockNumber);
    event StateAccessDenied(address indexed blackList, uint256 indexed blockNumber);

    event TransfersEnabled(address indexed whiteList);
    event TransfersDisabled(address indexed blackList);

    event Transfer(address indexed sender, address indexed recipient, uint256 amount);
    event Mint(address indexed recipient, uint256 amount, uint256 totalToken);
    event Burn(address indexed recipient, uint256 amount, uint256 totalToken);
    event NewTotalSupply(uint256 newTotalSupply);
    event NewTotalOnOtherChain(uint256 newTotalOnOtherChain);
    event NewTotalInPositions(uint256 newTotalOnOtherChain);
    event OperatingRewardMinted(address indexed recipient, uint256 amount);

    event RewardsChange(address indexed rewardsAddress, uint256 indexed rewardsBasisPoints);
    event LastRewardTime(uint256 indexed rewardsTime);
    event GovernanceChange(address indexed governanceAddress);
    event TokenChange(address indexed tokenAddress);
    event AdministratorChange(address indexed administratorAddress);
    event OracleChange(address indexed oracleContract);
    event MaximumLeverageChange(uint256 maxLeverage);
    event MarketActivated(bytes32 indexed activateMarket);
    event MarketDeActivated(bytes32 indexed deActivateMarket);
    event BridgeChange(address _bridgeAddress);
    event SideChainMerkleRootUpdate(bytes32 indexed sideChainMerkleRoot);
    event NewSideChainOperator(address indexed sideChainOperator);
    event NumberOfRequestsLimitUpdate(uint256 _numberOfRequests);

    event MainChainWithdrawLimitUpdate(uint256 indexed mainChainWithdrawLimit24);
    event TokenSentToLinkedChain(address _address, uint256 _token, uint256 _totalTokenSent, bytes32 indexed _tokenSentToLinkedChainHash);
    event TransferredTokenClaimed(address _address, uint256 _token);
    event LastWithdrawAt();
    event RollingWithdrawnAmountUpdated(uint256 _last24HoursAmountWithdrawn, uint256 _lastWithdrawLimitReductionTime);
    event WithdrawLimitUpdated(uint256 _amount);
    event InactivityPeriodUpdated(uint256 _periodLength);
    event FastWithdrawsDisabled();
    event NewBridgeNonce(uint256 _transferNonce);
    event Last24HoursAmountWithdrawnReset();

    event StatePaused(address administrator, bool _paused);

    event SetAllowance(address indexed sender, address indexed spender, uint256 tokens);
    event SetPosition(bytes32 indexed positionHash,
        address indexed sender,
        bytes32 indexed marketId,
        uint256 timeStamp,
        uint256 longShares,
        uint256 shortShares,
        uint256 meanEntryPrice,
        uint256 meanEntrySpread,
        uint256 meanEntryLeverage,
        uint256 liquidationPrice
    );
    event SetBalance(address indexed account, uint256 balance, bytes32 indexed balanceHash);
    event TokenTransferredToOtherChain(address indexed account, uint256 tokenTransferredToOtherChain, bytes32 indexed transferHash);

    modifier notPaused {
        require(paused == false, "MorpherState: Contract paused, aborting");
        _;
    }

    modifier onlyPlatform {
        require(stateAccess[msg.sender] == true, "MorpherState: Only Platform is allowed to execute operation.");
        _;
    }

    modifier onlyGovernance {
        require(msg.sender == getGovernance(), "MorpherState: Calling contract not the Governance Contract. Aborting.");
        _;
    }

    modifier onlyAdministrator {
        require(msg.sender == getAdministrator(), "MorpherState: Caller is not the Administrator. Aborting.");
        _;
    }

    modifier onlySideChainOperator {
        require(msg.sender == sideChainOperator, "MorpherState: Caller is not the Sidechain Operator. Aborting.");
        _;
    }

    modifier canTransfer {
        require(getCanTransfer(msg.sender), "MorpherState: Caller may not transfer token. Aborting.");
        _;
    }

    modifier onlyBridge {
        require(msg.sender == getMorpherBridge(), "MorpherState: Caller is not the Bridge. Aborting.");
        _;
    }

    modifier onlyMainChain {
        require(mainChain == true, "MorpherState: Can only be called on mainchain.");
        _;
    }

    modifier onlySideChain {
        require(mainChain == false, "MorpherState: Can only be called on mainchain.");
        _;
    }

    constructor(bool _mainChain, address _sideChainOperator, address _morpherTreasury) public {
        // @Deployer: Transfer State Ownership to cold storage address after deploying protocol
        mainChain = _mainChain; // true for Ethereum, false for Morpher PoA sidechain
        setLastRewardTime(now);
        uint256 _sideChainMint = 575000000 * 10**(DECIMALS);
        uint256 _mainChainMint = 425000000 * 10**(DECIMALS);
        
        administrator = owner(); //first set the owner as administrator
        morpherGovernance = owner(); //first set the owner as governance
        
        grantAccess(owner());
        setSideChainOperator(owner());
        if (mainChain == false) { // Create token only on sidechain
            balances[owner()] = _sideChainMint; // Create airdrop and team token on sidechain
            totalToken = _sideChainMint;
            emit Mint(owner(), balanceOf(owner()), _sideChainMint);
            setRewardBasisPoints(0); // Reward is minted on mainchain
            setRewardAddress(address(0));
            setTotalOnOtherChain(_mainChainMint);
        } else {
            balances[owner()] = _mainChainMint; // Create treasury and investor token on mainchain
            totalToken = _mainChainMint;
            emit Mint(owner(), balanceOf(owner()), _mainChainMint);
            setRewardBasisPoints(15000); // 15000 / PRECISION = 0.00015
            setRewardAddress(_morpherTreasury);
            setTotalOnOtherChain(_sideChainMint);
        }
        fastTransfersEnabled = true;
        setNumberOfRequestsLimit(3);
        setMainChainWithdrawLimit(totalSupply / 50);
        setSideChainOperator(_sideChainOperator);
        denyAccess(owner());
    }

    // ----------------------------------------------------------------------------
    // Setter/Getter functions for market wise exposure
    // ----------------------------------------------------------------------------

    function getMaxMappingIndex(bytes32 _marketId) public view returns(uint256 _maxMappingIndex) {
        return exposureByMarket[_marketId].maxMappingIndex;
    }

    function getExposureMappingIndex(bytes32 _marketId, address _address) public view returns(uint256 _mappingIndex) {
        return exposureByMarket[_marketId].index[_address];
    }

    function getExposureMappingAddress(bytes32 _marketId, uint256 _mappingIndex) public view returns(address _address) {
        return exposureByMarket[_marketId].addy[_mappingIndex];
    }

    function setMaxMappingIndex(bytes32 _marketId, uint256 _maxMappingIndex) public onlyPlatform {
        exposureByMarket[_marketId].maxMappingIndex = _maxMappingIndex;
    }

    function setExposureMapping(bytes32 _marketId, address _address, uint256 _index) public onlyPlatform  {
        setExposureMappingIndex(_marketId, _address, _index);
        setExposureMappingAddress(_marketId, _address, _index);
    }

    function setExposureMappingIndex(bytes32 _marketId, address _address, uint256 _index) public onlyPlatform {
        exposureByMarket[_marketId].index[_address] = _index;
    }

    function setExposureMappingAddress(bytes32 _marketId, address _address, uint256 _index) public onlyPlatform {
        exposureByMarket[_marketId].addy[_index] = _address;
    }

    // ----------------------------------------------------------------------------
    // Setter/Getter functions for bridge variables
    // ----------------------------------------------------------------------------
    function setTokenClaimedOnThisChain(address _address, uint256 _token) public onlyBridge {
        tokenClaimedOnThisChain[_address] = _token;
        emit TransferredTokenClaimed(_address, _token);
    }

    function getTokenClaimedOnThisChain(address _address) public view returns (uint256 _token) {
        return tokenClaimedOnThisChain[_address];
    }

    function setTokenSentToLinkedChain(address _address, uint256 _token) public onlyBridge {
        tokenSentToLinkedChain[_address] = _token;
        tokenSentToLinkedChainTime[_address] = now;
        emit TokenSentToLinkedChain(_address, _token, tokenSentToLinkedChain[_address], getBalanceHash(_address, tokenSentToLinkedChain[_address]));
    }

    function getTokenSentToLinkedChain(address _address) public view returns (uint256 _token) {
        return tokenSentToLinkedChain[_address];
    }

    function getTokenSentToLinkedChainTime(address _address) public view returns (uint256 _timeStamp) {
        return tokenSentToLinkedChainTime[_address];
    }

    function add24HoursWithdrawn(uint256 _amount) public onlyBridge {
        last24HoursAmountWithdrawn = last24HoursAmountWithdrawn.add(_amount);
        emit RollingWithdrawnAmountUpdated(last24HoursAmountWithdrawn, lastWithdrawLimitReductionTime);
    }

    function update24HoursWithdrawLimit(uint256 _amount) public onlyBridge {
        if (last24HoursAmountWithdrawn > _amount) {
            last24HoursAmountWithdrawn = last24HoursAmountWithdrawn.sub(_amount);
        } else {
            last24HoursAmountWithdrawn = 0;
        }
        lastWithdrawLimitReductionTime = now;
        emit RollingWithdrawnAmountUpdated(last24HoursAmountWithdrawn, lastWithdrawLimitReductionTime);
    }

    function set24HourWithdrawLimit(uint256 _limit) public onlyBridge {
        withdrawLimit24Hours = _limit;
        emit WithdrawLimitUpdated(_limit);
    }

    function resetLast24HoursAmountWithdrawn() public onlyBridge {
        last24HoursAmountWithdrawn = 0;
        emit Last24HoursAmountWithdrawnReset();
    }

    function setInactivityPeriod(uint256 _periodLength) public onlyBridge {
        inactivityPeriod = _periodLength;
        emit InactivityPeriodUpdated(_periodLength);
    }

    function getBridgeNonce() public onlyBridge returns (uint256 _nonce) {
        transferNonce++;
        emit NewBridgeNonce(transferNonce);
        return transferNonce;
    }

    function disableFastWithdraws() public onlyBridge {
        fastTransfersEnabled = false;
        emit FastWithdrawsDisabled();
    }

    function setPositionClaimedOnMainChain(bytes32 _positionHash) public onlyBridge {
        positionClaimedOnMainChain[_positionHash] = true;
    }

    function getPositionClaimedOnMainChain(bytes32 _positionHash) public view returns (bool _alreadyClaimed) {
        return positionClaimedOnMainChain[_positionHash];
    }

    // ----------------------------------------------------------------------------
    // Setter/Getter functions for spam protection
    // ----------------------------------------------------------------------------

    function setLastRequestBlock(address _address) public onlyPlatform {
        lastRequestBlock[_address] = block.number;
    }

    function getLastRequestBlock(address _address) public view returns(uint256 _lastRequestBlock) {
        return lastRequestBlock[_address];
    }

    function setNumberOfRequests(address _address, uint256 _numberOfRequests) public onlyPlatform {
        numberOfRequests[_address] = _numberOfRequests;
    }

    function increaseNumberOfRequests(address _address) public onlyPlatform{
        numberOfRequests[_address]++;
    }

    function getNumberOfRequests(address _address) public view returns(uint256 _numberOfRequests) {
        return numberOfRequests[_address];
    }

    function setNumberOfRequestsLimit(uint256 _numberOfRequestsLimit) public onlyPlatform {
        numberOfRequestsLimit = _numberOfRequestsLimit;
        emit NumberOfRequestsLimitUpdate(_numberOfRequestsLimit);
    }

    function getNumberOfRequestsLimit() public view returns (uint256 _numberOfRequestsLimit) {
        return numberOfRequestsLimit;
    }

    function setMainChainWithdrawLimit(uint256 _mainChainWithdrawLimit24) public onlyGovernance {
        mainChainWithdrawLimit24 = _mainChainWithdrawLimit24;
        emit MainChainWithdrawLimitUpdate(_mainChainWithdrawLimit24);
    }

    function getMainChainWithdrawLimit() public view returns (uint256 _mainChainWithdrawLimit24) {
        return mainChainWithdrawLimit24;
    }

    // ----------------------------------------------------------------------------
    // Setter/Getter functions for state access
    // ----------------------------------------------------------------------------

    function grantAccess(address _address) public onlyAdministrator {
        stateAccess[_address] = true;
        emit StateAccessGranted(_address, block.number);
    }

    function denyAccess(address _address) public onlyAdministrator {
        stateAccess[_address] = false;
        emit StateAccessDenied(_address, block.number);
    }

    function getStateAccess(address _address) public view returns(bool _hasAccess) {
        return stateAccess[_address];
    }

    // ----------------------------------------------------------------------------
    // Setter/Getter functions for addresses that can transfer tokens (sidechain only)
    // ----------------------------------------------------------------------------

    function enableTransfers(address _address) public onlyAdministrator {
        transferAllowed[_address] = true;
        emit TransfersEnabled(_address);
    }

    function disableTransfers(address _address) public onlyAdministrator {
        transferAllowed[_address] = false;
        emit TransfersDisabled(_address);
    }

    function getCanTransfer(address _address) public view returns(bool _hasAccess) {
        return mainChain || transferAllowed[_address];
    }

    // ----------------------------------------------------------------------------
    // Minting/burning/transfer of token
    // ----------------------------------------------------------------------------

    function transfer(address _from, address _to, uint256 _token) public onlyPlatform notPaused {
        require(balances[_from] >= _token, "MorpherState: Not enough token.");
        balances[_from] = balances[_from].sub(_token);
        balances[_to] = balances[_to].add(_token);
        IMorpherToken(morpherToken).emitTransfer(_from, _to, _token);
        emit Transfer(_from, _to, _token);
        emit SetBalance(_from, balances[_from], getBalanceHash(_from, balances[_from]));
        emit SetBalance(_to, balances[_to], getBalanceHash(_to, balances[_to]));
    }

    function mint(address _address, uint256 _token) public onlyPlatform notPaused {
        balances[_address] = balances[_address].add(_token);
        totalToken = totalToken.add(_token);
        updateTotalSupply();
        IMorpherToken(morpherToken).emitTransfer(address(0), _address, _token);
        emit Mint(_address, _token, totalToken);
        emit SetBalance(_address, balances[_address], getBalanceHash(_address, balances[_address]));
    }

    function burn(address _address, uint256 _token) public onlyPlatform notPaused {
        require(balances[_address] >= _token, "MorpherState: Not enough token.");
        balances[_address] = balances[_address].sub(_token);
        totalToken = totalToken.sub(_token);
        updateTotalSupply();
        IMorpherToken(morpherToken).emitTransfer(_address, address(0), _token);
        emit Burn(_address, _token, totalToken);
        emit SetBalance(_address, balances[_address], getBalanceHash(_address, balances[_address]));
    }

    // ----------------------------------------------------------------------------
    // Setter/Getter functions for balance and token functions (ERC20)
    // ----------------------------------------------------------------------------
    function updateTotalSupply() private {
        totalSupply = totalToken.add(totalInPositions).add(totalOnOtherChain);
        emit NewTotalSupply(totalSupply);
    }

    function setTotalInPositions(uint256 _totalInPositions) public onlyAdministrator {
        totalInPositions = _totalInPositions;
        updateTotalSupply();
        emit NewTotalInPositions(_totalInPositions);
    }

    function setTotalOnOtherChain(uint256 _newTotalOnOtherChain) public onlySideChainOperator {
        totalOnOtherChain = _newTotalOnOtherChain;
        updateTotalSupply();
        emit NewTotalOnOtherChain(_newTotalOnOtherChain);
    }

    function balanceOf(address _tokenOwner) public view returns (uint256 balance) {
        return balances[_tokenOwner];
    }

    function setAllowance(address _from, address _spender, uint256 _tokens) public onlyPlatform {
        allowed[_from][_spender] = _tokens;
        emit SetAllowance(_from, _spender, _tokens);
    }

    function getAllowance(address _tokenOwner, address spender) public view returns (uint256 remaining) {
        return allowed[_tokenOwner][spender];
    }

    // ----------------------------------------------------------------------------
    // Setter/Getter functions for platform roles
    // ----------------------------------------------------------------------------

    function setGovernanceContract(address _newGovernanceContractAddress) public onlyGovernance {
        morpherGovernance = _newGovernanceContractAddress;
        emit GovernanceChange(_newGovernanceContractAddress);
    }

    function getGovernance() public view returns (address _governanceContract) {
        return morpherGovernance;
    }

    function setMorpherBridge(address _newBridge) public onlyGovernance {
        morpherBridge = _newBridge;
        emit BridgeChange(_newBridge);
    }

    function getMorpherBridge() public view returns (address _currentBridge) {
        return morpherBridge;
    }

    function setOracleContract(address _newOracleContract) public onlyGovernance {
        oracleContract = _newOracleContract;
        emit OracleChange(_newOracleContract);
    }

    function getOracleContract() public view returns(address) {
        return oracleContract;
    }

    function setTokenContract(address _newTokenContract) public onlyGovernance {
        morpherToken = _newTokenContract;
        emit TokenChange(_newTokenContract);
    }

    function getTokenContract() public view returns(address) {
        return morpherToken;
    }

    function setAdministrator(address _newAdministrator) public onlyGovernance {
        administrator = _newAdministrator;
        emit AdministratorChange(_newAdministrator);
    }

    function getAdministrator() public view returns(address) {
        return administrator;
    }

    // ----------------------------------------------------------------------------
    // Setter/Getter functions for platform operating rewards
    // ----------------------------------------------------------------------------

    function setRewardAddress(address _newRewardsAddress) public onlyGovernance {
        morpherRewards = _newRewardsAddress;
        emit RewardsChange(_newRewardsAddress, rewardBasisPoints);
    }

    function setRewardBasisPoints(uint256 _newRewardBasisPoints) public onlyGovernance {
        if (mainChain == true) {
            require(_newRewardBasisPoints <= 15000, "MorpherState: Reward basis points need to be less or equal to 15000.");
        } else {
            require(_newRewardBasisPoints == 0, "MorpherState: Reward basis points can only be set on Ethereum.");
        }
        rewardBasisPoints = _newRewardBasisPoints;
        emit RewardsChange(morpherRewards, _newRewardBasisPoints);
    }

    function setLastRewardTime(uint256 _lastRewardTime) private {
        lastRewardTime = _lastRewardTime;
        emit LastRewardTime(_lastRewardTime);
    }

    // ----------------------------------------------------------------------------
    // Setter/Getter functions for platform administration
    // ----------------------------------------------------------------------------

    function activateMarket(bytes32 _activateMarket) public onlyAdministrator {
        marketActive[_activateMarket] = true;
        emit MarketActivated(_activateMarket);
    }

    function deActivateMarket(bytes32 _deActivateMarket) public onlyAdministrator {
        marketActive[_deActivateMarket] = false;
        emit MarketDeActivated(_deActivateMarket);
    }

    function getMarketActive(bytes32 _marketId) public view returns(bool _active) {
        return marketActive[_marketId];
    }

    function setMaximumLeverage(uint256 _newMaximumLeverage) public onlyAdministrator {
        require(_newMaximumLeverage > PRECISION, "MorpherState: Leverage precision is 1e8");
        maximumLeverage = _newMaximumLeverage;
        emit MaximumLeverageChange(_newMaximumLeverage);
    }

    function getMaximumLeverage() public view returns(uint256 _maxLeverage) {
        return maximumLeverage;
    }

    function pauseState() public onlyAdministrator {
        paused = true;
        emit StatePaused(msg.sender, true);
    }

    function unPauseState() public onlyAdministrator {
        paused = false;
        emit StatePaused(msg.sender, false);
    }

    // ----------------------------------------------------------------------------
    // Setter/Getter for side chain state
    // ----------------------------------------------------------------------------

    function setSideChainMerkleRoot(bytes32 _sideChainMerkleRoot) public onlyBridge {
        sideChainMerkleRoot = _sideChainMerkleRoot;
        sideChainMerkleRootWrittenAtTime = now;
        payOperatingReward();
        emit SideChainMerkleRootUpdate(_sideChainMerkleRoot);
    }

    function getSideChainMerkleRoot() public view returns(bytes32 _sideChainMerkleRoot) {
        return sideChainMerkleRoot;
    }

    function setSideChainOperator(address _address) public onlyAdministrator {
        sideChainOperator = _address;
        emit NewSideChainOperator(_address);
    }

    function getSideChainOperator() public view returns (address _address) {
        return sideChainOperator;
    }

    function getSideChainMerkleRootWrittenAtTime() public view returns(uint256 _sideChainMerkleRoot) {
        return sideChainMerkleRootWrittenAtTime;
    }

    // ----------------------------------------------------------------------------
    // Setter/Getter functions for portfolio
    // ----------------------------------------------------------------------------

    function setPosition(
        address _address,
        bytes32 _marketId,
        uint256 _timeStamp,
        uint256 _longShares,
        uint256 _shortShares,
        uint256 _meanEntryPrice,
        uint256 _meanEntrySpread,
        uint256 _meanEntryLeverage,
        uint256 _liquidationPrice
    ) public onlyPlatform {
        portfolio[_address][_marketId].lastUpdated = _timeStamp;
        portfolio[_address][_marketId].longShares = _longShares;
        portfolio[_address][_marketId].shortShares = _shortShares;
        portfolio[_address][_marketId].meanEntryPrice = _meanEntryPrice;
        portfolio[_address][_marketId].meanEntrySpread = _meanEntrySpread;
        portfolio[_address][_marketId].meanEntryLeverage = _meanEntryLeverage;
        portfolio[_address][_marketId].liquidationPrice = _liquidationPrice;
        portfolio[_address][_marketId].positionHash = getPositionHash(
            _address,
            _marketId,
            _timeStamp,
            _longShares,
            _shortShares,
            _meanEntryPrice,
            _meanEntrySpread,
            _meanEntryLeverage,
            _liquidationPrice
        );
        if (_longShares > 0 || _shortShares > 0) {
            addExposureByMarket(_marketId, _address);
        } else {
            deleteExposureByMarket(_marketId, _address);
        }
        emit SetPosition(
            portfolio[_address][_marketId].positionHash,
            _address,
            _marketId,
            _timeStamp,
            _longShares,
            _shortShares,
            _meanEntryPrice,
            _meanEntrySpread,
            _meanEntryLeverage,
            _liquidationPrice
        );
    }

    function getPosition(
        address _address,
        bytes32 _marketId
    ) public view returns (
        uint256 _longShares,
        uint256 _shortShares,
        uint256 _meanEntryPrice,
        uint256 _meanEntrySpread,
        uint256 _meanEntryLeverage,
        uint256 _liquidationPrice
    ) {
        return(
        portfolio[_address][_marketId].longShares,
        portfolio[_address][_marketId].shortShares,
        portfolio[_address][_marketId].meanEntryPrice,
        portfolio[_address][_marketId].meanEntrySpread,
        portfolio[_address][_marketId].meanEntryLeverage,
        portfolio[_address][_marketId].liquidationPrice
        );
    }

    function getPositionHash(
        address _address,
        bytes32 _marketId,
        uint256 _timeStamp,
        uint256 _longShares,
        uint256 _shortShares,
        uint256 _meanEntryPrice,
        uint256 _meanEntrySpread,
        uint256 _meanEntryLeverage,
        uint256 _liquidationPrice
    ) public pure returns (bytes32 _hash) {
        return keccak256(
            abi.encodePacked(
                _address,
                _marketId,
                _timeStamp,
                _longShares,
                _shortShares,
                _meanEntryPrice,
                _meanEntrySpread,
                _meanEntryLeverage,
                _liquidationPrice
            )
        );
    }

    function getBalanceHash(address _address, uint256 _balance) public pure returns (bytes32 _hash) {
        return keccak256(abi.encodePacked(_address, _balance));
    }

    function getLastUpdated(address _address, bytes32 _marketId) public view returns (uint256 _lastUpdated) {
        return(portfolio[_address][_marketId].lastUpdated);
    }

    function getLongShares(address _address, bytes32 _marketId) public view returns (uint256 _longShares) {
        return(portfolio[_address][_marketId].longShares);
    }

    function getShortShares(address _address, bytes32 _marketId) public view returns (uint256 _shortShares) {
        return(portfolio[_address][_marketId].shortShares);
    }

    function getMeanEntryPrice(address _address, bytes32 _marketId) public view returns (uint256 _meanEntryPrice) {
        return(portfolio[_address][_marketId].meanEntryPrice);
    }

    function getMeanEntrySpread(address _address, bytes32 _marketId) public view returns (uint256 _meanEntrySpread) {
        return(portfolio[_address][_marketId].meanEntrySpread);
    }

    function getMeanEntryLeverage(address _address, bytes32 _marketId) public view returns (uint256 _meanEntryLeverage) {
        return(portfolio[_address][_marketId].meanEntryLeverage);
    }

    function getLiquidationPrice(address _address, bytes32 _marketId) public view returns (uint256 _liquidationPrice) {
        return(portfolio[_address][_marketId].liquidationPrice);
    }

    // ----------------------------------------------------------------------------
    // Record positions by market by address. Needed for exposure aggregations
    // and spits and dividends.
    // ----------------------------------------------------------------------------
    function addExposureByMarket(bytes32 _symbol, address _address) private {
        // Address must not be already recored
        uint256 _myExposureIndex = getExposureMappingIndex(_symbol, _address);
        if (_myExposureIndex == 0) {
            uint256 _maxMappingIndex = getMaxMappingIndex(_symbol).add(1);
            setMaxMappingIndex(_symbol, _maxMappingIndex);
            setExposureMapping(_symbol, _address, _maxMappingIndex);
        }
    }

    function deleteExposureByMarket(bytes32 _symbol, address _address) private {
        // Get my index in mapping
        uint256 _myExposureIndex = getExposureMappingIndex(_symbol, _address);
        // Get last element of mapping
        uint256 _lastIndex = getMaxMappingIndex(_symbol);
        address _lastAddress = getExposureMappingAddress(_symbol, _lastIndex);
        // If _myExposureIndex is greater than 0 (i.e. there is an exposure of that address on that market) delete it
        if (_myExposureIndex > 0) {
            // If _myExposureIndex is less than _lastIndex overwrite element at _myExposureIndex with element at _lastIndex in
            // deleted elements position.
            if (_myExposureIndex < _lastIndex) {
                setExposureMappingAddress(_symbol, _lastAddress, _myExposureIndex);
                setExposureMappingIndex(_symbol, _lastAddress, _myExposureIndex);
            }
            // Delete _lastIndex and _lastAddress element and reduce maxExposureIndex
            setExposureMappingAddress(_symbol, address(0), _lastIndex);
            setExposureMappingIndex(_symbol, _address, 0);
            // Shouldn't happen, but check that not empty
            if (_lastIndex > 0) {
                setMaxMappingIndex(_symbol, _lastIndex.sub(1));
            }
        }
    }

    // ----------------------------------------------------------------------------
    // Calculate and send operating reward
    // Every 24 hours the protocol mints rewardBasisPoints/(PRECISION) percent of the total
    // supply as reward for the protocol operator. The amount can not exceed 0.015% per
    // day.
    // ----------------------------------------------------------------------------

    function payOperatingReward() public onlyMainChain {
        if (now > lastRewardTime.add(REWARDPERIOD)) {
            uint256 _reward = totalSupply.mul(rewardBasisPoints).div(PRECISION);
            setLastRewardTime(lastRewardTime.add(REWARDPERIOD));
            mint(morpherRewards, _reward);
            emit OperatingRewardMinted(morpherRewards, _reward);
        }
    }
}pragma solidity 0.5.16;

import "./IERC20.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./MorpherState.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20Mintable}.
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
contract MorpherToken is IERC20, Ownable {

    MorpherState state;
    using SafeMath for uint256;

    string public constant name     = "Morpher";
    string public constant symbol   = "MPH";
    uint8  public constant decimals = 18;
    
    modifier onlyState {
        require(msg.sender == address(state), "ERC20: caller must be MorpherState contract.");
        _;
    }

    modifier canTransfer {
        require(state.getCanTransfer(msg.sender), "ERC20: token transfers disabled on sidechain.");
        _;
    }
    
    event LinkState(address _address);

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    constructor(address _stateAddress, address _coldStorageOwnerAddress) public {
        setMorpherState(_stateAddress);
        transferOwnership(_coldStorageOwnerAddress);
    }

    // ------------------------------------------------------------------------
    // Links Token Contract with State
    // ------------------------------------------------------------------------
    function setMorpherState(address _stateAddress) public onlyOwner {
        state = MorpherState(_stateAddress);
        emit LinkState(_stateAddress);
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view returns (uint256) {
        return state.totalSupply();
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address _account) public view returns (uint256) {
        return state.balanceOf(_account);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     * 
     * Emits a {Transfer} event via emitTransfer called by MorpherState
     */
    function transfer(address _recipient, uint256 _amount) public returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

   /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address _owner, address _spender) public view returns (uint256) {
        return state.getAllowance(_owner, _spender);
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address _spender, uint256 _amount) public returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20};
     *
     * Requirements:
     * - `_sender` and `_recipient` cannot be the zero address.
     * - `_sender` must have a balance of at least `amount`.
     * - the caller must have allowance for `_sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(address _sender, address _recipient, uint256 amount) public returns (bool) {
        _transfer(_sender, _recipient, amount);
        _approve(_sender, msg.sender, state.getAllowance(_sender, msg.sender).sub(amount, "ERC20: transfer amount exceeds allowance"));
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
     * - `_spender` cannot be the zero address.
     */
    function increaseAllowance(address _spender, uint256 _addedValue) public returns (bool) {
        _approve(msg.sender, _spender, state.getAllowance(msg.sender, _spender).add(_addedValue));
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
    function decreaseAllowance(address _spender, uint256 _subtractedValue) public returns (bool) {
        _approve(msg.sender, _spender,  state.getAllowance(msg.sender, _spender).sub(_subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Caller destroys `_amount` tokens permanently
     *
     * Emits a {Transfer} event to zero address called by MorpherState via emitTransfer.
     *
     * Requirements:
     *
     * - Caller must have token balance of at least `_amount`
     * 
     */
     function burn(uint256 _amount) public returns (bool) {
        state.burn(msg.sender, _amount);
        return true;
    }

    /**
     * @dev Emits a {Transfer} event
     *
     * MorpherState emits a {Transfer} event.
     *
     * Requirements:
     *
     * - Caller must be MorpherState
     * 
     */
     function emitTransfer(address _from, address _to, uint256 _amount) public onlyState {
        emit Transfer(_from, _to, _amount);
    }

     /**
     * @dev Moves tokens `_amount` from `sender` to `_recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event via emitTransfer called by MorpherState
     *
     * Requirements:
     *
     * - `_sender` cannot be the zero address.
     * - `_recipient` cannot be the zero address.
     * - `_sender` must have a balance of at least `_amount`.
     */
    function _transfer(address _sender, address _recipient, uint256 _amount) canTransfer internal {
        require(_sender != address(0), "ERC20: transfer from the zero address");
        require(_recipient != address(0), "ERC20: transfer to the zero address");
        require(state.balanceOf(_sender) >= _amount, "ERC20: transfer amount exceeds balance");
        state.transfer(_sender, _recipient, _amount);
    }

    /**
     * @dev Sets `_amount` as the allowance of `spender` over the `owner`s tokens.
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
    function _approve(address _owner, address _spender, uint256 _amount) internal {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(_spender != address(0), "ERC20: approve to the zero address");
        state.setAllowance(_owner, _spender, _amount);
        emit Approval(_owner, _spender, _amount);
    }

    // ------------------------------------------------------------------------
    // Don't accept ETH
    // ------------------------------------------------------------------------
    function () external payable {
        revert("ERC20: You can't deposit Ether here");
    }
}pragma solidity 0.5.16;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./MorpherState.sol";
import "./IMorpherStaking.sol";
import "./MorpherMintingLimiter.sol";

// ----------------------------------------------------------------------------------
// Tradeengine of the Morpher platform
// Creates and processes orders, and computes the state change of portfolio.
// Needs writing/reading access to/from Morpher State. Order objects are stored locally,
// portfolios are stored in state.
// ----------------------------------------------------------------------------------

contract MorpherTradeEngine is Ownable {
    MorpherState state;
    IMorpherStaking staking;
    MorpherMintingLimiter mintingLimiter;
    using SafeMath for uint256;

// ----------------------------------------------------------------------------
// Precision of prices and leverage
// ----------------------------------------------------------------------------
    uint256 constant PRECISION = 10**8;
    uint256 public orderNonce;
    bytes32 public lastOrderId;
    uint256 public deployedTimeStamp;

    address public escrowOpenOrderAddress = 0x1111111111111111111111111111111111111111;
    bool public escrowOpenOrderEnabled;


    //we're locking positions in for this price at a market marketId;
    address public closedMarketPriceLock = 0x0000000000000000000000000000000000000001;


// ----------------------------------------------------------------------------
// Order struct contains all order specific varibles. Variables are completed
// during processing of trade. State changes are saved in the order struct as
// well, since local variables would lead to stack to deep errors *sigh*.
// ----------------------------------------------------------------------------
    struct order {
        address userId;
        bytes32 marketId;
        uint256 closeSharesAmount;
        uint256 openMPHTokenAmount;
        bool tradeDirection; // true = long, false = short
        uint256 liquidationTimestamp;
        uint256 marketPrice;
        uint256 marketSpread;
        uint256 orderLeverage;
        uint256 timeStamp;
        uint256 longSharesOrder;
        uint256 shortSharesOrder;
        uint256 balanceDown;
        uint256 balanceUp;
        uint256 newLongShares;
        uint256 newShortShares;
        uint256 newMeanEntryPrice;
        uint256 newMeanEntrySpread;
        uint256 newMeanEntryLeverage;
        uint256 newLiquidationPrice;
        uint256 orderEscrowAmount;
    }

    mapping(bytes32 => order) private orders;

// ----------------------------------------------------------------------------
// Events
// Order created/processed events are fired by MorpherOracle.
// ----------------------------------------------------------------------------

    event PositionLiquidated(
        address indexed _address,
        bytes32 indexed _marketId,
        bool _longPosition,
        uint256 _timeStamp,
        uint256 _marketPrice,
        uint256 _marketSpread
    );

    event OrderCancelled(
        bytes32 indexed _orderId,
        address indexed _address
    );

    event OrderIdRequested(
        bytes32 _orderId,
        address indexed _address,
        bytes32 indexed _marketId,
        uint256 _closeSharesAmount,
        uint256 _openMPHTokenAmount,
        bool _tradeDirection,
        uint256 _orderLeverage
    );

    event OrderProcessed(
        bytes32 _orderId,
        uint256 _marketPrice,
        uint256 _marketSpread,
        uint256 _liquidationTimestamp,
        uint256 _timeStamp,
        uint256 _newLongShares,
        uint256 _newShortShares,
        uint256 _newAverageEntry,
        uint256 _newAverageSpread,
        uint256 _newAverageLeverage,
        uint256 _liquidationPrice
    );

    event PositionUpdated(
        address _userId,
        bytes32 _marketId,
        uint256 _timeStamp,
        uint256 _newLongShares,
        uint256 _newShortShares,
        uint256 _newMeanEntryPrice,
        uint256 _newMeanEntrySpread,
        uint256 _newMeanEntryLeverage,
        uint256 _newLiquidationPrice,
        uint256 _mint,
        uint256 _burn
    );

    event LinkState(address _address);
    event LinkStaking(address _stakingAddress);
    event LinkMintingLimiter(address _mintingLimiterAddress);

    
    event LockedPriceForClosingPositions(bytes32 _marketId, uint256 _price);


    constructor(address _stateAddress, address _coldStorageOwnerAddress, address _stakingContractAddress, bool _escrowOpenOrderEnabled, uint256 _deployedTimestampOverride, address _mintingLimiterAddress) public {
        setMorpherState(_stateAddress);
        setMorpherStaking(_stakingContractAddress);
        setMorpherMintingLimiter(_mintingLimiterAddress);
        transferOwnership(_coldStorageOwnerAddress);
        escrowOpenOrderEnabled = _escrowOpenOrderEnabled;
        deployedTimeStamp = _deployedTimestampOverride > 0 ? _deployedTimestampOverride : block.timestamp;
    }

    modifier onlyOracle {
        require(msg.sender == state.getOracleContract(), "MorpherTradeEngine: function can only be called by Oracle Contract.");
        _;
    }

    modifier onlyAdministrator {
        require(msg.sender == getAdministrator(), "MorpherTradeEngine: function can only be called by the Administrator.");
        _;
    }

// ----------------------------------------------------------------------------
// Administrative functions
// Set state address, get administrator address
// ----------------------------------------------------------------------------

    function setMorpherState(address _stateAddress) public onlyOwner {
        state = MorpherState(_stateAddress);
        emit LinkState(_stateAddress);
    }

    function setMorpherStaking(address _stakingAddress) public onlyOwner {
        staking = IMorpherStaking(_stakingAddress);
        emit LinkStaking(_stakingAddress);
    }

    function setMorpherMintingLimiter(address _mintingLimiterAddress) public onlyOwner {
        mintingLimiter = MorpherMintingLimiter(_mintingLimiterAddress);
        emit LinkMintingLimiter(_mintingLimiterAddress);
    }

    function getAdministrator() public view returns(address _administrator) {
        return state.getAdministrator();
    }

    function setEscrowOpenOrderEnabled(bool _isEnabled) public onlyOwner {
        escrowOpenOrderEnabled = _isEnabled;
    }
    
    function paybackEscrow(bytes32 _orderId) private {
        //pay back the escrow to the user so he has it back on his balance/**
        if(orders[_orderId].orderEscrowAmount > 0) {
            //checks effects interaction
            uint256 paybackAmount = orders[_orderId].orderEscrowAmount;
            orders[_orderId].orderEscrowAmount = 0;
            state.transfer(escrowOpenOrderAddress, orders[_orderId].userId, paybackAmount);
        }
    }

    function buildupEscrow(bytes32 _orderId, uint256 _amountInMPH) private {
        if(escrowOpenOrderEnabled && _amountInMPH > 0) {
            state.transfer(orders[_orderId].userId, escrowOpenOrderAddress, _amountInMPH);
            orders[_orderId].orderEscrowAmount = _amountInMPH;
        }
    }


    function validateClosedMarketOrderConditions(address _address, bytes32 _marketId, uint256 _closeSharesAmount, uint256 _openMPHTokenAmount, bool _tradeDirection ) internal view {
        //markets active? Still tradeable?
        if(_openMPHTokenAmount > 0) {
            require(state.getMarketActive(_marketId) == true, "MorpherTradeEngine: market unknown or currently not enabled for trading.");
        } else {
            //we're just closing a position, but it needs a forever price locked in if market is not active
            //the user needs to close his complete position
            if(state.getMarketActive(_marketId) == false) {
                require(getDeactivatedMarketPrice(_marketId) > 0, "MorpherTradeEngine: Can't close a position, market not active and closing price not locked");
                if(_tradeDirection) {
                    //long
                    require(_closeSharesAmount == state.getShortShares(_address, _marketId), "MorpherTradeEngine: Deactivated market order needs all shares to be closed");
                } else {
                    //short
                    require(_closeSharesAmount == state.getLongShares(_address, _marketId), "MorpherTradeEngine: Deactivated market order needs all shares to be closed");
                }
            }
        }
    }

    //wrapper for stack too deep errors
    function validateClosedMarketOrder(bytes32 _orderId) internal view {
         validateClosedMarketOrderConditions(orders[_orderId].userId, orders[_orderId].marketId, orders[_orderId].closeSharesAmount, orders[_orderId].openMPHTokenAmount, orders[_orderId].tradeDirection);
    }

// ----------------------------------------------------------------------------
// requestOrderId(address _address, bytes32 _marketId, bool _closeSharesAmount, uint256 _openMPHTokenAmount, bool _tradeDirection, uint256 _orderLeverage)
// Creates a new order object with unique orderId and assigns order information.
// Must be called by MorpherOracle contract.
// ----------------------------------------------------------------------------

    function requestOrderId(
        address _address,
        bytes32 _marketId,
        uint256 _closeSharesAmount,
        uint256 _openMPHTokenAmount,
        bool _tradeDirection,
        uint256 _orderLeverage
        ) public onlyOracle returns (bytes32 _orderId) {
            
        require(_orderLeverage >= PRECISION, "MorpherTradeEngine: leverage too small. Leverage precision is 1e8");
        require(_orderLeverage <= state.getMaximumLeverage(), "MorpherTradeEngine: leverage exceeds maximum allowed leverage.");

        validateClosedMarketOrderConditions(_address, _marketId, _closeSharesAmount, _openMPHTokenAmount, _tradeDirection);

        //request limits
        require(state.getNumberOfRequests(_address) <= state.getNumberOfRequestsLimit() ||
            state.getLastRequestBlock(_address) < block.number,
            "MorpherTradeEngine: request exceeded maximum permitted requests per block."
        );

        /**
         * The user can't partially close a position and open another one with MPH
         */
        if(_openMPHTokenAmount > 0) {
            if(_tradeDirection) {
                //long
                require(_closeSharesAmount == state.getShortShares(_address, _marketId), "MorpherTradeEngine: Can't partially close a position and open another one in opposite direction");
            } else {
                //short
                require(_closeSharesAmount == state.getLongShares(_address, _marketId), "MorpherTradeEngine: Can't partially close a position and open another one in opposite direction");
            }
        }

        state.setLastRequestBlock(_address);
        state.increaseNumberOfRequests(_address);
        orderNonce++;
        _orderId = keccak256(
            abi.encodePacked(
                _address,
                block.number,
                _marketId,
                _closeSharesAmount,
                _openMPHTokenAmount,
                _tradeDirection,
                _orderLeverage,
                orderNonce
                )
            );
        lastOrderId = _orderId;
        orders[_orderId].userId = _address;
        orders[_orderId].marketId = _marketId;
        orders[_orderId].closeSharesAmount = _closeSharesAmount;
        orders[_orderId].openMPHTokenAmount = _openMPHTokenAmount;
        orders[_orderId].tradeDirection = _tradeDirection;
        orders[_orderId].orderLeverage = _orderLeverage;
        emit OrderIdRequested(
            _orderId,
            _address,
            _marketId,
            _closeSharesAmount,
            _openMPHTokenAmount,
            _tradeDirection,
            _orderLeverage
        );

        /**
         * put the money in escrow here if given MPH to open an order
         * - also, can only close positions if in shares, so it will
         * definitely trigger a mint there.
         * The money must be put in escrow even though we have an existing position
         */
        buildupEscrow(_orderId, _openMPHTokenAmount);

        return _orderId;
    }

// ----------------------------------------------------------------------------
// Getter functions for orders, shares, and positions
// ----------------------------------------------------------------------------

    function getOrder(bytes32 _orderId) public view returns (
        address _userId,
        bytes32 _marketId,
        uint256 _closeSharesAmount,
        uint256 _openMPHTokenAmount,
        uint256 _marketPrice,
        uint256 _marketSpread,
        uint256 _orderLeverage
        ) {
        return(
            orders[_orderId].userId,
            orders[_orderId].marketId,
            orders[_orderId].closeSharesAmount,
            orders[_orderId].openMPHTokenAmount,
            orders[_orderId].marketPrice,
            orders[_orderId].marketSpread,
            orders[_orderId].orderLeverage
            );
    }

    function getPosition(address _address, bytes32 _marketId) public view returns (
        uint256 _positionLongShares,
        uint256 _positionShortShares,
        uint256 _positionAveragePrice,
        uint256 _positionAverageSpread,
        uint256 _positionAverageLeverage,
        uint256 _liquidationPrice
        ) {
        return(
            state.getLongShares(_address, _marketId),
            state.getShortShares(_address, _marketId),
            state.getMeanEntryPrice(_address,_marketId),
            state.getMeanEntrySpread(_address,_marketId),
            state.getMeanEntryLeverage(_address,_marketId),
            state.getLiquidationPrice(_address,_marketId)
        );
    }

    function setDeactivatedMarketPrice(bytes32 _marketId, uint256 _price) public onlyOracle {
         state.setPosition(
            closedMarketPriceLock,
            _marketId,
            now.mul(1000),
            0,
            0,
            _price,
            0,
            0,
            0
        );

        emit LockedPriceForClosingPositions(_marketId, _price);

    }

    function getDeactivatedMarketPrice(bytes32 _marketId) public view returns(uint256) {
        ( , , uint positionForeverClosingPrice, , ,) = state.getPosition(closedMarketPriceLock, _marketId);
        return positionForeverClosingPrice;
    }

// ----------------------------------------------------------------------------
// liquidate(bytes32 _orderId)
// Checks for bankruptcy of position between its last update and now
// Time check is necessary to avoid two consecutive / unorderded liquidations
// ----------------------------------------------------------------------------

    function liquidate(bytes32 _orderId) private {
        address _address = orders[_orderId].userId;
        bytes32 _marketId = orders[_orderId].marketId;
        uint256 _liquidationTimestamp = orders[_orderId].liquidationTimestamp;
        if (_liquidationTimestamp > state.getLastUpdated(_address, _marketId)) {
            if (state.getLongShares(_address,_marketId) > 0) {
                state.setPosition(
                    _address,
                    _marketId,
                    orders[_orderId].timeStamp,
                    0,
                    state.getShortShares(_address, _marketId),
                    0,
                    0,
                    PRECISION,
                    0);
                emit PositionLiquidated(
                    _address,
                    _marketId,
                    true,
                    orders[_orderId].timeStamp,
                    orders[_orderId].marketPrice,
                    orders[_orderId].marketSpread
                );
            }
            if (state.getShortShares(_address,_marketId) > 0) {
                state.setPosition(
                    _address,
                    _marketId,
                    orders[_orderId].timeStamp,
                    state.getLongShares(_address, _marketId),
                    0,
                    0,
                    0,
                    PRECISION,
                    0
                );
                emit PositionLiquidated(
                    _address,
                    _marketId,
                    false,
                    orders[_orderId].timeStamp,
                    orders[_orderId].marketPrice,
                    orders[_orderId].marketSpread
                );
            }
        }
    }

// ----------------------------------------------------------------------------
// processOrder(bytes32 _orderId, uint256 _marketPrice, uint256 _marketSpread, uint256 _liquidationTimestamp, uint256 _timeStamp)
// ProcessOrder receives the price/spread/liqidation information from the Oracle and
// triggers the processing of the order. If successful, processOrder updates the portfolio state.
// Liquidation time check is necessary to avoid two consecutive / unorderded liquidations
// ----------------------------------------------------------------------------

    function processOrder(
        bytes32 _orderId,
        uint256 _marketPrice,
        uint256 _marketSpread,
        uint256 _liquidationTimestamp,
        uint256 _timeStampInMS
        ) public onlyOracle returns (
            uint256 _newLongShares,
            uint256 _newShortShares,
            uint256 _newAverageEntry,
            uint256 _newAverageSpread,
            uint256 _newAverageLeverage,
            uint256 _liquidationPrice
        ) {
        require(orders[_orderId].userId != address(0), "MorpherTradeEngine: unable to process, order has been deleted.");
        require(_marketPrice > 0, "MorpherTradeEngine: market priced at zero. Buy order cannot be processed.");
        require(_marketPrice >= _marketSpread, "MorpherTradeEngine: market price lower then market spread. Order cannot be processed.");
        
        orders[_orderId].marketPrice = _marketPrice;
        orders[_orderId].marketSpread = _marketSpread;
        orders[_orderId].timeStamp = _timeStampInMS;
        orders[_orderId].liquidationTimestamp = _liquidationTimestamp;
        
        /**
        * If the market is deactivated, then override the price with the locked in market price
        * if the price wasn't locked in: error out.
        */
        if(state.getMarketActive(orders[_orderId].marketId) == false) {
            validateClosedMarketOrder(_orderId);
            orders[_orderId].marketPrice = getDeactivatedMarketPrice(orders[_orderId].marketId);
        }
        
        // Check if previous position on that market was liquidated
        if (_liquidationTimestamp > state.getLastUpdated(orders[_orderId].userId, orders[_orderId].marketId)) {
            liquidate(_orderId);
        }
    

        paybackEscrow(_orderId);

        if (orders[_orderId].tradeDirection) {
            processBuyOrder(_orderId);
        } else {
            processSellOrder(_orderId);
        }

        address _address = orders[_orderId].userId;
        bytes32 _marketId = orders[_orderId].marketId;
        delete orders[_orderId];
        emit OrderProcessed(
            _orderId,
            _marketPrice,
            _marketSpread,
            _liquidationTimestamp,
            _timeStampInMS,
            _newLongShares,
            _newShortShares,
            _newAverageEntry,
            _newAverageSpread,
            _newAverageLeverage,
            _liquidationPrice
        );

        return (
            state.getLongShares(_address, _marketId),
            state.getShortShares(_address, _marketId),
            state.getMeanEntryPrice(_address,_marketId),
            state.getMeanEntrySpread(_address,_marketId),
            state.getMeanEntryLeverage(_address,_marketId),
            state.getLiquidationPrice(_address,_marketId)
        );
    }

// ----------------------------------------------------------------------------
// function cancelOrder(bytes32 _orderId, address _address)
// Users or Administrator can delete pending orders before the callback went through
// ----------------------------------------------------------------------------
    function cancelOrder(bytes32 _orderId, address _address) public onlyOracle {
        require(_address == orders[_orderId].userId || _address == getAdministrator(), "MorpherTradeEngine: only Administrator or user can cancel an order.");
        require(orders[_orderId].userId != address(0), "MorpherTradeEngine: unable to process, order does not exist.");

        /**
         * Pay back any escrow there
         */
        paybackEscrow(_orderId);

        delete orders[_orderId];
        emit OrderCancelled(_orderId, _address);
    }

// ----------------------------------------------------------------------------
// shortShareValue / longShareValue compute the value of a virtual future
// given current price/spread/leverage of the market and mean price/spread/leverage
// at the beginning of the trade
// ----------------------------------------------------------------------------
    function shortShareValue(
        uint256 _positionAveragePrice,
        uint256 _positionAverageLeverage,
        uint256 _positionTimeStampInMs,
        uint256 _marketPrice,
        uint256 _marketSpread,
        uint256 _orderLeverage,
        bool _sell
        ) public view returns (uint256 _shareValue) {

        uint256 _averagePrice = _positionAveragePrice;
        uint256 _averageLeverage = _positionAverageLeverage;

        if (_positionAverageLeverage < PRECISION) {
            // Leverage can never be less than 1. Fail safe for empty positions, i.e. undefined _positionAverageLeverage
            _averageLeverage = PRECISION;
        }
        if (_sell == false) {
            // New short position
            // It costs marketPrice + marketSpread to build up a new short position
            _averagePrice = _marketPrice;
	        // This is the average Leverage
	        _averageLeverage = _orderLeverage;
        }
        if (
            getLiquidationPrice(_averagePrice, _averageLeverage, false, _positionTimeStampInMs) <= _marketPrice
            ) {
	        // Position is worthless
            _shareValue = 0;
        } else {
            // The regular share value is 2x the entry price minus the current price for short positions.
            _shareValue = _averagePrice.mul((PRECISION.add(_averageLeverage))).div(PRECISION);
            _shareValue = _shareValue.sub(_marketPrice.mul(_averageLeverage).div(PRECISION));
            if (_sell == true) {
                // We have to reduce the share value by the average spread (i.e. the average expense to build up the position)
                // and reduce the value further by the spread for selling.
                _shareValue = _shareValue.sub(_marketSpread.mul(_averageLeverage).div(PRECISION));
                uint256 _marginInterest = calculateMarginInterest(_averagePrice, _averageLeverage, _positionTimeStampInMs);
                if (_marginInterest <= _shareValue) {
                    _shareValue = _shareValue.sub(_marginInterest);
                } else {
                    _shareValue = 0;
                }
            } else {
                // If a new short position is built up each share costs value + spread
                _shareValue = _shareValue.add(_marketSpread.mul(_orderLeverage).div(PRECISION));
            }
        }
      
        return _shareValue;
    }

    function longShareValue(
        uint256 _positionAveragePrice,
        uint256 _positionAverageLeverage,
        uint256 _positionTimeStampInMs,
        uint256 _marketPrice,
        uint256 _marketSpread,
        uint256 _orderLeverage,
        bool _sell
        ) public view returns (uint256 _shareValue) {

        uint256 _averagePrice = _positionAveragePrice;
        uint256 _averageLeverage = _positionAverageLeverage;

        if (_positionAverageLeverage < PRECISION) {
            // Leverage can never be less than 1. Fail safe for empty positions, i.e. undefined _positionAverageLeverage
            _averageLeverage = PRECISION;
        }
        if (_sell == false) {
            // New long position
            // It costs marketPrice + marketSpread to build up a new long position
            _averagePrice = _marketPrice;
	        // This is the average Leverage
	        _averageLeverage = _orderLeverage;
        }
        if (
            _marketPrice <= getLiquidationPrice(_averagePrice, _averageLeverage, true, _positionTimeStampInMs)
            ) {
	        // Position is worthless
            _shareValue = 0;
        } else {
            _shareValue = _averagePrice.mul(_averageLeverage.sub(PRECISION)).div(PRECISION);
            // The regular share value is market price times leverage minus entry price times entry leverage minus one.
            _shareValue = (_marketPrice.mul(_averageLeverage).div(PRECISION)).sub(_shareValue);
            if (_sell == true) {
                // We sell a long and have to correct the shareValue with the averageSpread and the currentSpread for selling.
                _shareValue = _shareValue.sub(_marketSpread.mul(_averageLeverage).div(PRECISION));
                
                uint256 _marginInterest = calculateMarginInterest(_averagePrice, _averageLeverage, _positionTimeStampInMs);
                if (_marginInterest <= _shareValue) {
                    _shareValue = _shareValue.sub(_marginInterest);
                } else {
                    _shareValue = 0;
                }
            } else {
                // We buy a new long position and have to pay the spread
                _shareValue = _shareValue.add(_marketSpread.mul(_orderLeverage).div(PRECISION));
            }
        }
        return _shareValue;
    }

// ----------------------------------------------------------------------------
// calculateMarginInterest(uint256 _averagePrice, uint256 _averageLeverage, uint256 _positionTimeStamp)
// Calculates the interest for leveraged positions
// ----------------------------------------------------------------------------


    function calculateMarginInterest(uint256 _averagePrice, uint256 _averageLeverage, uint256 _positionTimeStampInMs) public view returns (uint256 _marginInterest) {
        if (_positionTimeStampInMs.div(1000) < deployedTimeStamp) {
            _positionTimeStampInMs = deployedTimeStamp.mul(1000);
        }
        _marginInterest = _averagePrice.mul(_averageLeverage.sub(PRECISION));
        _marginInterest = _marginInterest.mul((now.sub(_positionTimeStampInMs.div(1000)).div(86400)).add(1));
        _marginInterest = _marginInterest.mul(staking.interestRate()).div(PRECISION).div(PRECISION);
        return _marginInterest;
    }

// ----------------------------------------------------------------------------
// processBuyOrder(bytes32 _orderId)
// Converts orders specified in virtual shares to orders specified in Morpher token
// and computes the number of short shares that are sold and long shares that are bought.
// long shares are bought only if the order amount exceeds all open short positions
// ----------------------------------------------------------------------------

    function processBuyOrder(bytes32 _orderId) private {
        if (orders[_orderId].closeSharesAmount > 0) {
            //calcualte the balanceUp/down first
            //then reopen the position with MPH amount

             // Investment was specified in shares
            if (orders[_orderId].closeSharesAmount <= state.getShortShares(orders[_orderId].userId, orders[_orderId].marketId)) {
                // Partial closing of short position
                orders[_orderId].shortSharesOrder = orders[_orderId].closeSharesAmount;
            } else {
                // Closing of entire short position
                orders[_orderId].shortSharesOrder = state.getShortShares(orders[_orderId].userId, orders[_orderId].marketId);
            }
        }

        //calculate the long shares, but only if the old position is completely closed out (if none exist shortSharesOrder = 0)
        if(
            orders[_orderId].shortSharesOrder == state.getShortShares(orders[_orderId].userId, orders[_orderId].marketId) && 
            orders[_orderId].openMPHTokenAmount > 0
        ) {
            orders[_orderId].longSharesOrder = orders[_orderId].openMPHTokenAmount.div(
                longShareValue(
                    orders[_orderId].marketPrice,
                    orders[_orderId].orderLeverage,
                    now.mul(1000),
                    orders[_orderId].marketPrice,
                    orders[_orderId].marketSpread,
                    orders[_orderId].orderLeverage,
                    false
            ));
        }

        // Investment equals number of shares now.
        if (orders[_orderId].shortSharesOrder > 0) {
            closeShort(_orderId);
        }
        if (orders[_orderId].longSharesOrder > 0) {
            openLong(_orderId);
        }
    }

// ----------------------------------------------------------------------------
// processSellOrder(bytes32 _orderId)
// Converts orders specified in virtual shares to orders specified in Morpher token
// and computes the number of long shares that are sold and short shares that are bought.
// short shares are bought only if the order amount exceeds all open long positions
// ----------------------------------------------------------------------------

    function processSellOrder(bytes32 _orderId) private {
        if (orders[_orderId].closeSharesAmount > 0) {
            //calcualte the balanceUp/down first
            //then reopen the position with MPH amount

            // Investment was specified in shares
            if (orders[_orderId].closeSharesAmount <= state.getLongShares(orders[_orderId].userId, orders[_orderId].marketId)) {
                // Partial closing of long position
                orders[_orderId].longSharesOrder = orders[_orderId].closeSharesAmount;
            } else {
                // Closing of entire long position
                orders[_orderId].longSharesOrder = state.getLongShares(orders[_orderId].userId, orders[_orderId].marketId);
            }
        }

        if(
            orders[_orderId].longSharesOrder == state.getLongShares(orders[_orderId].userId, orders[_orderId].marketId) && 
            orders[_orderId].openMPHTokenAmount > 0
        ) {
        orders[_orderId].shortSharesOrder = orders[_orderId].openMPHTokenAmount.div(
                    shortShareValue(
                        orders[_orderId].marketPrice,
                        orders[_orderId].orderLeverage,
                        now.mul(1000),
                        orders[_orderId].marketPrice,
                        orders[_orderId].marketSpread,
                        orders[_orderId].orderLeverage,
                        false
                ));
        }
        // Investment equals number of shares now.
        if (orders[_orderId].longSharesOrder > 0) {
            closeLong(_orderId);
        }
        if (orders[_orderId].shortSharesOrder > 0) {
            openShort(_orderId);
        }
    }

// ----------------------------------------------------------------------------
// openLong(bytes32 _orderId)
// Opens a new long position and computes the new resulting average entry price/spread/leverage.
// Computation is broken down to several instructions for readability.
// ----------------------------------------------------------------------------
    function openLong(bytes32 _orderId) private {
        address _userId = orders[_orderId].userId;
        bytes32 _marketId = orders[_orderId].marketId;

        uint256 _newMeanSpread;
        uint256 _newMeanLeverage;

        // Existing position is virtually liquidated and reopened with current marketPrice
        // orders[_orderId].newMeanEntryPrice = orders[_orderId].marketPrice;
        // _factorLongShares is a factor to adjust the existing longShares via virtual liqudiation and reopening at current market price

        uint256 _factorLongShares = state.getMeanEntryLeverage(_userId, _marketId);
        if (_factorLongShares < PRECISION) {
            _factorLongShares = PRECISION;
        }
        _factorLongShares = _factorLongShares.sub(PRECISION);
        _factorLongShares = _factorLongShares.mul(state.getMeanEntryPrice(_userId, _marketId)).div(orders[_orderId].marketPrice);
        if (state.getMeanEntryLeverage(_userId, _marketId) > _factorLongShares) {
            _factorLongShares = state.getMeanEntryLeverage(_userId, _marketId).sub(_factorLongShares);
        } else {
            _factorLongShares = 0;
        }

        uint256 _adjustedLongShares = _factorLongShares.mul(state.getLongShares(_userId, _marketId)).div(PRECISION);

        // _newMeanLeverage is the weighted leverage of the existing position and the new position
        _newMeanLeverage = state.getMeanEntryLeverage(_userId, _marketId).mul(_adjustedLongShares);
        _newMeanLeverage = _newMeanLeverage.add(orders[_orderId].orderLeverage.mul(orders[_orderId].longSharesOrder));
        _newMeanLeverage = _newMeanLeverage.div(_adjustedLongShares.add(orders[_orderId].longSharesOrder));

        // _newMeanSpread is the weighted spread of the existing position and the new position
        _newMeanSpread = state.getMeanEntrySpread(_userId, _marketId).mul(state.getLongShares(_userId, _marketId));
        _newMeanSpread = _newMeanSpread.add(orders[_orderId].marketSpread.mul(orders[_orderId].longSharesOrder));
        _newMeanSpread = _newMeanSpread.div(_adjustedLongShares.add(orders[_orderId].longSharesOrder));

        orders[_orderId].balanceDown = orders[_orderId].longSharesOrder.mul(orders[_orderId].marketPrice).add(
            orders[_orderId].longSharesOrder.mul(orders[_orderId].marketSpread).mul(orders[_orderId].orderLeverage).div(PRECISION)
        );
        orders[_orderId].balanceUp = 0;
        orders[_orderId].newLongShares = _adjustedLongShares.add(orders[_orderId].longSharesOrder);
        orders[_orderId].newShortShares = state.getShortShares(_userId, _marketId);
        orders[_orderId].newMeanEntryPrice = orders[_orderId].marketPrice;
        orders[_orderId].newMeanEntrySpread = _newMeanSpread;
        orders[_orderId].newMeanEntryLeverage = _newMeanLeverage;

        setPositionInState(_orderId);
    }
// ----------------------------------------------------------------------------
// closeLong(bytes32 _orderId)
// Closes an existing long position. Average entry price/spread/leverage do not change.
// ----------------------------------------------------------------------------
     function closeLong(bytes32 _orderId) private {
        address _userId = orders[_orderId].userId;
        bytes32 _marketId = orders[_orderId].marketId;
        uint256 _newLongShares  = state.getLongShares(_userId, _marketId).sub(orders[_orderId].longSharesOrder);
        uint256 _balanceUp = calculateBalanceUp(_orderId);
        uint256 _newMeanEntry;
        uint256 _newMeanSpread;
        uint256 _newMeanLeverage;

        if (orders[_orderId].longSharesOrder == state.getLongShares(_userId, _marketId)) {
            _newMeanEntry = 0;
            _newMeanSpread = 0;
            _newMeanLeverage = PRECISION;
        } else {
            _newMeanEntry = state.getMeanEntryPrice(_userId, _marketId);
	        _newMeanSpread = state.getMeanEntrySpread(_userId, _marketId);
	        _newMeanLeverage = state.getMeanEntryLeverage(_userId, _marketId);
            resetTimestampInOrderToLastUpdated(_orderId);
        }

        orders[_orderId].balanceDown = 0;
        orders[_orderId].balanceUp = _balanceUp;
        orders[_orderId].newLongShares = _newLongShares;
        orders[_orderId].newShortShares = state.getShortShares(_userId, _marketId);
        orders[_orderId].newMeanEntryPrice = _newMeanEntry;
        orders[_orderId].newMeanEntrySpread = _newMeanSpread;
        orders[_orderId].newMeanEntryLeverage = _newMeanLeverage;

        setPositionInState(_orderId);
    }

event ResetTimestampInOrder(bytes32 _orderId, uint oldTimestamp, uint newTimestamp);
function resetTimestampInOrderToLastUpdated(bytes32 _orderId) internal {
    address userId = orders[_orderId].userId;
    bytes32 marketId = orders[_orderId].marketId;
    uint lastUpdated = state.getLastUpdated(userId, marketId);
    emit ResetTimestampInOrder(_orderId, orders[_orderId].timeStamp, lastUpdated);
    orders[_orderId].timeStamp = lastUpdated;
}

// ----------------------------------------------------------------------------
// closeShort(bytes32 _orderId)
// Closes an existing short position. Average entry price/spread/leverage do not change.
// ----------------------------------------------------------------------------
function calculateBalanceUp(bytes32 _orderId) private view returns (uint256 _balanceUp) {
        address _userId = orders[_orderId].userId;
        bytes32 _marketId = orders[_orderId].marketId;
        uint256 _shareValue;

        if (orders[_orderId].tradeDirection == false) { //we are selling our long shares
            _balanceUp = orders[_orderId].longSharesOrder;
            _shareValue = longShareValue(
                state.getMeanEntryPrice(_userId, _marketId),
                state.getMeanEntryLeverage(_userId, _marketId),
                state.getLastUpdated(_userId, _marketId),
                orders[_orderId].marketPrice,
                orders[_orderId].marketSpread,
                state.getMeanEntryLeverage(_userId, _marketId),
                true
            );
        } else { //we are going long, we are selling our short shares
            _balanceUp = orders[_orderId].shortSharesOrder;
            _shareValue = shortShareValue(
                state.getMeanEntryPrice(_userId, _marketId),
                state.getMeanEntryLeverage(_userId, _marketId),
                state.getLastUpdated(_userId, _marketId),
                orders[_orderId].marketPrice,
                orders[_orderId].marketSpread,
                state.getMeanEntryLeverage(_userId, _marketId),
                true
            );
        }
        return _balanceUp.mul(_shareValue); 
    }

    function closeShort(bytes32 _orderId) private {
        address _userId = orders[_orderId].userId;
        bytes32 _marketId = orders[_orderId].marketId;
        uint256 _newMeanEntry;
        uint256 _newMeanSpread;
        uint256 _newMeanLeverage;
        uint256 _newShortShares = state.getShortShares(_userId, _marketId).sub(orders[_orderId].shortSharesOrder);
        uint256 _balanceUp = calculateBalanceUp(_orderId);
        
        if (orders[_orderId].shortSharesOrder == state.getShortShares(_userId, _marketId)) {
            _newMeanEntry = 0;
            _newMeanSpread = 0;
	        _newMeanLeverage = PRECISION;
        } else {
            _newMeanEntry = state.getMeanEntryPrice(_userId, _marketId);
	        _newMeanSpread = state.getMeanEntrySpread(_userId, _marketId);
	        _newMeanLeverage = state.getMeanEntryLeverage(_userId, _marketId);

            /**
             * we need the timestamp of the old order for partial closes, not the new one
             */
            resetTimestampInOrderToLastUpdated(_orderId);
        }

        orders[_orderId].balanceDown = 0;
        orders[_orderId].balanceUp = _balanceUp;
        orders[_orderId].newLongShares = state.getLongShares(orders[_orderId].userId, orders[_orderId].marketId);
        orders[_orderId].newShortShares = _newShortShares;
        orders[_orderId].newMeanEntryPrice = _newMeanEntry;
        orders[_orderId].newMeanEntrySpread = _newMeanSpread;
        orders[_orderId].newMeanEntryLeverage = _newMeanLeverage;

        setPositionInState(_orderId);
    }

// ----------------------------------------------------------------------------
// openShort(bytes32 _orderId)
// Opens a new short position and computes the new resulting average entry price/spread/leverage.
// Computation is broken down to several instructions for readability.
// ----------------------------------------------------------------------------
    function openShort(bytes32 _orderId) private {
        address _userId = orders[_orderId].userId;
        bytes32 _marketId = orders[_orderId].marketId;

        uint256 _newMeanSpread;
        uint256 _newMeanLeverage;
        //
        // Existing position is virtually liquidated and reopened with current marketPrice
        // orders[_orderId].newMeanEntryPrice = orders[_orderId].marketPrice;
        // _factorShortShares is a factor to adjust the existing shortShares via virtual liqudiation and reopening at current market price

        uint256 _factorShortShares = state.getMeanEntryLeverage(_userId, _marketId);
        if (_factorShortShares < PRECISION) {
            _factorShortShares = PRECISION;
        }
        _factorShortShares = _factorShortShares.add(PRECISION);
        _factorShortShares = _factorShortShares.mul(state.getMeanEntryPrice(_userId, _marketId)).div(orders[_orderId].marketPrice);
        if (state.getMeanEntryLeverage(_userId, _marketId) < _factorShortShares) {
            _factorShortShares = _factorShortShares.sub(state.getMeanEntryLeverage(_userId, _marketId));
        } else {
            _factorShortShares = 0;
        }

        uint256 _adjustedShortShares = _factorShortShares.mul(state.getShortShares(_userId, _marketId)).div(PRECISION);

        // _newMeanLeverage is the weighted leverage of the existing position and the new position
        _newMeanLeverage = state.getMeanEntryLeverage(_userId, _marketId).mul(_adjustedShortShares);
        _newMeanLeverage = _newMeanLeverage.add(orders[_orderId].orderLeverage.mul(orders[_orderId].shortSharesOrder));
        _newMeanLeverage = _newMeanLeverage.div(_adjustedShortShares.add(orders[_orderId].shortSharesOrder));

        // _newMeanSpread is the weighted spread of the existing position and the new position
        _newMeanSpread = state.getMeanEntrySpread(_userId, _marketId).mul(state.getShortShares(_userId, _marketId));
        _newMeanSpread = _newMeanSpread.add(orders[_orderId].marketSpread.mul(orders[_orderId].shortSharesOrder));
        _newMeanSpread = _newMeanSpread.div(_adjustedShortShares.add(orders[_orderId].shortSharesOrder));

        orders[_orderId].balanceDown = orders[_orderId].shortSharesOrder.mul(orders[_orderId].marketPrice).add(
            orders[_orderId].shortSharesOrder.mul(orders[_orderId].marketSpread).mul(orders[_orderId].orderLeverage).div(PRECISION)
        );
        orders[_orderId].balanceUp = 0;
        orders[_orderId].newLongShares = state.getLongShares(_userId, _marketId);
        orders[_orderId].newShortShares = _adjustedShortShares.add(orders[_orderId].shortSharesOrder);
        orders[_orderId].newMeanEntryPrice = orders[_orderId].marketPrice;
        orders[_orderId].newMeanEntrySpread = _newMeanSpread;
        orders[_orderId].newMeanEntryLeverage = _newMeanLeverage;

        setPositionInState(_orderId);
    }

    function computeLiquidationPrice(bytes32 _orderId) public returns(uint256 _liquidationPrice) {
        orders[_orderId].newLiquidationPrice = 0;
        if (orders[_orderId].newLongShares > 0) {
            orders[_orderId].newLiquidationPrice = getLiquidationPrice(orders[_orderId].newMeanEntryPrice, orders[_orderId].newMeanEntryLeverage, true, orders[_orderId].timeStamp);
        }
        if (orders[_orderId].newShortShares > 0) {
            orders[_orderId].newLiquidationPrice = getLiquidationPrice(orders[_orderId].newMeanEntryPrice, orders[_orderId].newMeanEntryLeverage, false, orders[_orderId].timeStamp);
        }
        return orders[_orderId].newLiquidationPrice;
    }

    function getLiquidationPrice(uint256 _newMeanEntryPrice, uint256 _newMeanEntryLeverage, bool _long, uint _positionTimestampInMs) public view returns (uint256 _liquidationPrice) {
        if (_long == true) {
            _liquidationPrice = _newMeanEntryPrice.mul(_newMeanEntryLeverage.sub(PRECISION)).div(_newMeanEntryLeverage);
            _liquidationPrice = _liquidationPrice.add(calculateMarginInterest(_newMeanEntryPrice, _newMeanEntryLeverage, _positionTimestampInMs));
        } else {
            _liquidationPrice = _newMeanEntryPrice.mul(_newMeanEntryLeverage.add(PRECISION)).div(_newMeanEntryLeverage);
            _liquidationPrice = _liquidationPrice.sub(calculateMarginInterest(_newMeanEntryPrice, _newMeanEntryLeverage, _positionTimestampInMs));
        }
        return _liquidationPrice;
    }

    
// ----------------------------------------------------------------------------
// setPositionInState(bytes32 _orderId)
// Updates the portfolio in Morpher State. Called by closeLong/closeShort/openLong/openShort
// ----------------------------------------------------------------------------
    function setPositionInState(bytes32 _orderId) private {
        require(state.balanceOf(orders[_orderId].userId).add(orders[_orderId].balanceUp) >= orders[_orderId].balanceDown, "MorpherTradeEngine: insufficient funds.");
        computeLiquidationPrice(_orderId);
        // Net balanceUp and balanceDown
        if (orders[_orderId].balanceUp > orders[_orderId].balanceDown) {
            orders[_orderId].balanceUp.sub(orders[_orderId].balanceDown);
            orders[_orderId].balanceDown = 0;
        } else {
            orders[_orderId].balanceDown.sub(orders[_orderId].balanceUp);
            orders[_orderId].balanceUp = 0;
        }
        if (orders[_orderId].balanceUp > 0) {
            mintingLimiter.mint(orders[_orderId].userId, orders[_orderId].balanceUp);
        }
        if (orders[_orderId].balanceDown > 0) {
            state.burn(orders[_orderId].userId, orders[_orderId].balanceDown);
        }
        state.setPosition(
            orders[_orderId].userId,
            orders[_orderId].marketId,
            orders[_orderId].timeStamp,
            orders[_orderId].newLongShares,
            orders[_orderId].newShortShares,
            orders[_orderId].newMeanEntryPrice,
            orders[_orderId].newMeanEntrySpread,
            orders[_orderId].newMeanEntryLeverage,
            orders[_orderId].newLiquidationPrice
        );
        emit PositionUpdated(
            orders[_orderId].userId,
            orders[_orderId].marketId,
            orders[_orderId].timeStamp,
            orders[_orderId].newLongShares,
            orders[_orderId].newShortShares,
            orders[_orderId].newMeanEntryPrice,
            orders[_orderId].newMeanEntrySpread,
            orders[_orderId].newMeanEntryLeverage,
            orders[_orderId].newLiquidationPrice,
            orders[_orderId].balanceUp,
            orders[_orderId].balanceDown
        );
    }
}pragma solidity 0.5.16;

import "./IERC20.sol";

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address public _owner;

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
        require(isOwner(), "Ownable: caller should be owner.");
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
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     * @notice Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
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
        require(newOwner != address(0), "Ownable: use renounce ownership instead.");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
    // ------------------------------------------------------------------------
    // Owner can transfer out any accidentally sent ERC20 tokens
    // ------------------------------------------------------------------------
    function transferAnyERC20Token(address _tokenAddress, uint256 _tokens) public onlyOwner returns (bool _success) {
        return IERC20(_tokenAddress).transfer(owner(), _tokens);
    }
}pragma solidity 0.5.16;

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
     * _Available since v2.4.0._
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
     *
     * _Available since v2.4.0._
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
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}