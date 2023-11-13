pragma solidity ^0.5.16;

pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "../../libraries/LibOrder.sol";
import "../../interfaces/permissions/ISuperAdminRole.sol";
import "../../interfaces/trading/IFills.sol";
import "../../interfaces/trading/ICancelOrder.sol";
import "../Initializable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";


/// @title CancelOrder
/// @author Julian Wilson <[email protected]>
/// @notice Manages functionality to cancel orders
contract CancelOrder is ICancelOrder, Initializable {
    using LibOrder for LibOrder.Order;
    using SafeMath for uint256;

    ISuperAdminRole private superAdminRole;
    IFills private fills;

    event OrderCancel(
        address indexed maker,
        bytes32 orderHash,
        LibOrder.Order order
    );

    constructor(ISuperAdminRole _superAdminRole) public Initializable() {
        superAdminRole = _superAdminRole;
    }

    /// @notice Throws if the caller is not a super admin.
    /// @param operator The caller of the method.
    modifier onlySuperAdmin(address operator) {
        require(
            superAdminRole.isSuperAdmin(operator),
            "NOT_A_SUPER_ADMIN"
        );
        _;
    }

    /// @notice Initializes this contract with reference to other contracts
    ///         in the protocol.
    /// @param _fills The Fills contract.
    function initialize(IFills _fills)
        external
        notInitialized
        onlySuperAdmin(msg.sender)
    {
        fills = _fills;
        initialized = true;
    }

    /// @notice Cancels an order and prevents and further filling.
    ///         Uses the order hash to uniquely ID the order.
    /// @param order The order to cancel.
    function cancelOrder(LibOrder.Order memory order) public {
        assertCancelValid(order, msg.sender);
        fills.cancel(order);

        emit OrderCancel(
            order.maker,
            order.getOrderHash(),
            order
        );
    }

    /// @notice Cancels multiple orders and prevents further filling.
    /// @param makerOrders The orders to cancel.
    function batchCancelOrders(LibOrder.Order[] memory makerOrders) public {
        uint256 makerOrdersLength = makerOrders.length;
        for (uint256 i = 0; i < makerOrdersLength; i++) {
            cancelOrder(makerOrders[i]);
        }
    }

    /// @notice Checks if a cancel is valid by the canceller.
    /// @param order The order to cancel.
    /// @param canceller The canceller that must be the maker.
    function assertCancelValid(
        LibOrder.Order memory order,
        address canceller
    )
        private
        view
    {
        require(
            order.executor == address(0),
            "EXECUTOR_CANNOT_BE_SET"
        );
        order.assertValidAsMaker(canceller);
        require(
            fills.remainingSpace(order) > 0,
            "INSUFFICIENT_SPACE"
        );
    }
}pragma solidity 0.5.16;


contract Initializable {
    bool public initialized;

    /// @notice Throws if this contract has already been initialized.
    modifier notInitialized() {
        require(!initialized, "ALREADY_INITIALIZED");
        _;
    }
}pragma solidity 0.5.16;

contract ISuperAdminRole {
    function isSuperAdmin(address account) public view returns (bool);
    function addSuperAdmin(address account) public;
    function removeSuperAdmin(address account) public;
    function getSuperAdminCount() public view returns (uint256);
}pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "../../libraries/LibOrder.sol";

contract ICancelOrder {
    function cancelOrder(LibOrder.Order memory order) public;
    function batchCancelOrders(LibOrder.Order[] memory makerOrders) public;
}pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "../../libraries/LibOrder.sol";

contract IFills {
    function getFilled(bytes32) public view returns (uint256);
    function getCancelled(bytes32) public view returns (bool);
    function getFillHashSubmitted(bytes32) public view returns (bool);
    function orderHasSpace(LibOrder.Order memory, uint256)
        public
        view
        returns (bool);
    function remainingSpace(LibOrder.Order memory)
        public
        view
        returns (uint256);
    function isOrderCancelled(LibOrder.Order memory) public view returns (bool);
    function fill(LibOrder.Order memory, uint256) public returns (uint256);
    function cancel(LibOrder.Order memory) public;
    function setFillHashSubmitted(bytes32) public;
}pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";


/// @title LibOrder
/// @author Julian Wilson <[email protected]>
/// @notice Central definition for what an "order" is along with utilities for an order.
library LibOrder {
    using SafeMath for uint256;

    uint256 public constant ODDS_PRECISION = 10**20;

    struct Order {
        bytes32 marketHash;
        address baseToken;
        uint256 totalBetSize;
        uint256 percentageOdds;
        uint256 expiry;
        uint256 salt;
        address maker;
        address executor;
        bool isMakerBettingOutcomeOne;
    }

    struct FillObject {
        Order[] orders;
        bytes[] makerSigs;
        uint256[] takerAmounts;
        uint256 fillSalt;
    }

    struct FillDetails {
        string action;
        string market;
        string betting;
        string stake;
        string odds;
        string returning;
        FillObject fills;
    }

    /// @notice Checks the parameters of the given order to see if it conforms to the protocol.
    /// @param order The order to check.
    /// @return A status string in UPPER_SNAKE_CASE. It will return "OK" if everything checks out.
    // solhint-disable code-complexity
    function getParamValidity(Order memory order)
        internal
        view
        returns (string memory)
    {
        if (order.totalBetSize == 0) {return "TOTAL_BET_SIZE_ZERO";}
        if (order.percentageOdds == 0 || order.percentageOdds >= ODDS_PRECISION) {return "INVALID_PERCENTAGE_ODDS";}
        if (order.expiry < now) {return "ORDER_EXPIRED";}
        if (order.baseToken == address(0)) {return "BASE_TOKEN";}
        return "OK";
    }

    /// @notice Checks the signature of an order to see if
    ///         it was an order signed by the given maker.
    /// @param order The order to check.
    /// @param makerSig The signature to compare.
    /// @return true if the signature matches, false otherwise.
    function checkSignature(Order memory order, bytes memory makerSig)
        internal
        pure
        returns (bool)
    {
        bytes32 orderHash = getOrderHash(order);
        return ECDSA.recover(ECDSA.toEthSignedMessageHash(orderHash), makerSig) == order.maker;
    }

    /// @notice Checks if an order's parameters conforms to the protocol's specifications.
    /// @param order The order to check.
    function assertValidParams(Order memory order) internal view {
        require(
            order.totalBetSize > 0,
            "TOTAL_BET_SIZE_ZERO"
        );
        require(
            order.percentageOdds > 0 && order.percentageOdds < ODDS_PRECISION,
            "INVALID_PERCENTAGE_ODDS"
        );
        require(order.baseToken != address(0), "INVALID_BASE_TOKEN");
        require(order.expiry > now, "ORDER_EXPIRED");
    }

    /// @notice Checks if an order has valid parameters including
    ///         the signature and checks if the maker is not the taker.
    /// @param order The order to check.
    /// @param taker The hypothetical filler of this order, i.e., the taker.
    /// @param makerSig The signature to check.
    function assertValidAsTaker(Order memory order, address taker, bytes memory makerSig) internal view {
        assertValidParams(order);
        require(
            checkSignature(order, makerSig),
            "SIGNATURE_MISMATCH"
        );
        require(order.maker != taker, "TAKER_NOT_MAKER");
    }

    /// @notice Checks if the order has valid parameters
    ///         and checks if the sender is the maker.
    /// @param order The order to check.
    /// @param sender The address to compare the maker to.
    function assertValidAsMaker(Order memory order, address sender) internal view {
        assertValidParams(order);
        require(order.maker == sender, "CALLER_NOT_MAKER");
    }

    /// @notice Computes the hash of an order. Packs the arguments in order
    ///         of the Order struct.
    /// @param order The order to compute the hash of.
    function getOrderHash(Order memory order) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                order.marketHash,
                order.baseToken,
                order.totalBetSize,
                order.percentageOdds,
                order.expiry,
                order.salt,
                order.maker,
                order.executor,
                order.isMakerBettingOutcomeOne
            )
        );
    }

    function getOddsPrecision() internal pure returns (uint256) {
        return ODDS_PRECISION;
    }
}pragma solidity ^0.5.0;

/**
 * @title Elliptic curve signature operations
 * @dev Based on https://gist.github.com/axic/5b33912c6f61ae6fd96d6c4a47afde6d
 * TODO Remove this library once solidity supports passing a signature to ecrecover.
 * See https://github.com/ethereum/solidity/issues/864
 */

library ECDSA {
    /**
     * @dev Recover signer address from a message by using their signature
     * @param hash bytes32 message, the hash is the signed message. What is recovered is the signer address.
     * @param signature bytes signature, the signature is generated using web3.eth.sign()
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        // Check the signature length
        if (signature.length != 65) {
            return (address(0));
        }

        // Divide the signature in r, s and v variables
        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        // Version of signature should be 27 or 28, but 0 and 1 are also possible versions
        if (v < 27) {
            v += 27;
        }

        // If the version is correct return the signer address
        if (v != 27 && v != 28) {
            return (address(0));
        } else {
            return ecrecover(hash, v, r, s);
        }
    }

    /**
     * toEthSignedMessageHash
     * @dev prefix a bytes32 value with "\x19Ethereum Signed Message:"
     * and hash the result
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
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
}{
  "evmVersion": "istanbul",
  "libraries": {},
  "optimizer": {
    "details": {
      "constantOptimizer": true,
      "cse": true,
      "deduplicate": true,
      "jumpdestRemover": true,
      "orderLiterals": true,
      "peephole": true,
      "yul": true,
      "yulDetails": {
        "stackAllocation": true
      }
    },
    "runs": 200
  },
  "remappings": [],
  "outputSelection": {
    "*": {
      "*": [
        "evm.bytecode",
        "evm.deployedBytecode",
        "abi"
      ]
    }
  }
}