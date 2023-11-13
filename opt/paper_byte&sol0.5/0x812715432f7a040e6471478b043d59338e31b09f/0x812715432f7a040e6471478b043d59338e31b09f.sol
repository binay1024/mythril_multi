pragma solidity ^0.5.1;

/**
uCNY is a Renminbi Fiat Token developed and released by uFiats,
a UCASH Network initiative.  uCNY and other uFiats are used as
tokenized gift certificate currency units which are purchasable
and sellable through a global converter network.

UCASH Network partners, smart-contract Dapps, services,
initiatives and other 3rd parties can use uFiats to provide
a range of digital financial services.
*/

pragma solidity ^0.5.1;

import './IERC20.sol';
import './SafeMath.sol';
import './Ownable.sol';
import './Blacklistable.sol';
import './Pausable.sol';
import './ECDSA.sol';

/**
 * @title uCNY Fiat Token
 * @dev ERC20 Token backed by fiat reserves
 */


contract uCNY is IERC20, Ownable, Pausable, Blacklistable {
    using SafeMath for uint256;

    string public name = "uCNY Fiat Token";
    string public symbol = "uCNY";
    uint8 public decimals = 18;
    string public currency = "CNY";
    address public masterCreator;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowed;
    uint256 public totalSupply = 0;

    mapping(address => bool) internal creators;
    mapping(address => uint256) internal creatorAllowed;

    mapping(address=> uint256) internal metaNonces;

    event Create(address indexed creator, address indexed to, uint256 amount);
    event Destroy(address indexed destroyer, uint256 amount);
    event CreatorConfigured(address indexed creator, uint256 creatorAllowedAmount);
    event CreatorRemoved(address indexed oldCreator);
    event MasterCreatorChanged(address indexed newMasterCreator);

    constructor() public {
        masterCreator = msg.sender;
        pauser = msg.sender;
        blacklister = msg.sender;
    }

    /**
     * @dev Throws if called by any account other than a creator
    */
    modifier onlyCreators() {
        require(creators[msg.sender] == true);
        _;
    }

    /**
     * @dev Function to create tokens
     * @param _to The address that will receive the createed tokens.
     * @param _amount The amount of tokens to create. Must be less than or equal to the creatorAllowance of the caller.
     * @return A boolean that indicates if the operation was successful.
    */
    function create(address _to, uint256 _amount) whenNotPaused onlyCreators notBlacklisted(msg.sender) notBlacklisted(_to) public returns (bool) {
        require(_to != address(0));
        require(_amount > 0);

        uint256 creatingAllowedAmount = creatorAllowed[msg.sender];
        require(_amount <= creatingAllowedAmount);

        totalSupply = totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);
        creatorAllowed[msg.sender] = creatingAllowedAmount.sub(_amount);
        emit Create(msg.sender, _to, _amount);
        emit Transfer(address(0x0), _to, _amount);
        return true;
    }

    /**
     * @dev Throws if called by any account other than the masterCreator
    */
    modifier onlyMasterCreator() {
        require(msg.sender == masterCreator);
        _;
    }

    /**
     * @dev Get creator allowance for an account
     * @param creator The address of the creator
    */
    function creatorAllowance(address creator) public view returns (uint256) {
        return creatorAllowed[creator];
    }

    /**
     * @dev Checks if account is a creator
     * @param account The address to check
    */
    function isCreator(address account) public view returns (bool) {
        return creators[account];
    }

    /**
     * @dev Function to add/update a new creator
     * @param creator The address of the creator
     * @param creatorAllowedAmount The reatingc amount allowed for the creator
     * @return True if the operation was successful.
    */
    function configureCreator(address creator, uint256 creatorAllowedAmount) whenNotPaused onlyMasterCreator public returns (bool) {
        creators[creator] = true;
        creatorAllowed[creator] = creatorAllowedAmount;
        emit CreatorConfigured(creator, creatorAllowedAmount);
        return true;
    }

    /**
     * @dev Function to remove a creator
     * @param creator The address of the creator to remove
     * @return True if the operation was successful.
    */
    function removeCreator(address creator) onlyMasterCreator public returns (bool) {
        creators[creator] = false;
        creatorAllowed[creator] = 0;
        emit CreatorRemoved(creator);
        return true;
    }

    /**
     * @dev allows a creator to destroy some of its own tokens
     * Validates that caller is a creator and that sender is not blacklisted
     * amount is less than or equal to the creator's account balance
     * @param _amount uint256 the amount of tokens to be destroyed
    */
    function destroy(uint256 _amount) whenNotPaused onlyCreators notBlacklisted(msg.sender) public {
        uint256 balance = balances[msg.sender];
        require(_amount > 0);
        require(balance >= _amount);

        totalSupply = totalSupply.sub(_amount);
        balances[msg.sender] = balance.sub(_amount);
        emit Destroy(msg.sender, _amount);
        emit Transfer(msg.sender, address(0), _amount);
    }

  /**
     * @dev allows masterCreator to allocate role to another address
     * Validates that caller is the current masterCreator
     * @param _newMasterCreator address the address to allocate role to
   */

    function updateMasterCreator(address _newMasterCreator) onlyOwner public {
        require(_newMasterCreator != address(0));
        masterCreator = _newMasterCreator;
        emit MasterCreatorChanged(masterCreator);
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param owner The address to query the balance of.
     * @return A uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address owner) public view returns (uint256) {
        return balances[owner];
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return allowed[owner][spender];
    }

    /**
     * @dev Transfer token to a specified address.
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
        _approve(msg.sender, spender, value);
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
        _transfer(from, to, value);
        _approve(from, msg.sender, allowed[from][msg.sender].sub(value));
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner allowed to a spender.
     * approve should be called when _allowed[msg.sender][spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, allowed[msg.sender][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner allowed to a spender.
     * approve should be called when _allowed[msg.sender][spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, allowed[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    /**
     * @dev gets the payload to sign when a user wants to do a metaTransfer
     * @param _from uint256 address of the transferer
     * @param _to uint256 address of the recipient
     * @param value uint256 the amount of tokens to be transferred
     * @param fee uint256 the fee paid to the relayer in uCNY
     * @param nonce uint256 the metaNonce of the usere's metatransaction
    */
  function getTransferPayload(
        address _from,
        address _to,
        uint256 value,
        uint256 fee,
        uint256 nonce
    ) public
    view
    returns (bytes32 payload)
  {
    return ECDSA.toEthSignedMessageHash(
      keccak256(abi.encodePacked(
        "transfer",     // function specfic text
        _from,          // transferer.
        _to,            // recipient
        address(this),  // Token address (replay protection).
        value,          // Number of tokens.
        fee,            // fee paid to metaTransfer relayer, in uCNY
        nonce           // Local sender specific nonce (replay protection).
      ))
    );
  }


/**
     * @dev gets the payload to sign when a user wants to do a metaApprove
     * @param _from uint256 address of the approver
     * @param _to uint256 address of the approvee
     * @param value uint256 the amount of tokens to be approved
     * @param fee uint256 the fee paid to the relayer in uCNY
     * @param metaNonce uint256 the metaNonce of the usere's metatransaction
    */
    function getApprovePayload(
        address _from,
        address _to,
        uint256 value,
        uint256 fee,
        uint256 metaNonce
    ) public
    view
    returns (bytes32 payload)
  {
    return ECDSA.toEthSignedMessageHash(
      keccak256(abi.encodePacked(
        "approve",      // function specfic text
        _from,          // Approver.
        _to,            // Approvee
        address(this),  // Token address (replay protection).
        value,          // Number of tokens.
        fee,            // Local sender specific nonce (replay protection).
        metaNonce       // fee paid to metaApprove relayer, in uCNY
      ))
    );
  }


/**
     * @dev gets the payload to sign when a user wants to do a metaTransferFrom
     * @param _from uint256 the from address of the approver
     * @param _to uint256 address of the recipient
     * @param _by uint256 by address of the approvee
     * @param value uint256 the amount of tokens to be transferred
     * @param fee uint256 the fee paid to the relayer in uCNY
     * @param metaNonce uint256 the metaNonce of the usere's metatransaction
    */
    function getTransferFromPayload(
        address _from,
        address _to,
        address _by,
        uint256 value,
        uint256 fee,
        uint256 metaNonce
    ) public
    view
    returns (bytes32 payload)
  {
    return ECDSA.toEthSignedMessageHash(
      keccak256(abi.encodePacked(
        "transferFrom",     // function specfic text
        _from,              // Approver
        _to,                // Recipient
        _by,                // Approvee
        address(this),      // Token address (replay protection).
        value,              // Number of tokens.
        fee,                // fee paid to metaApprove relayer, in uCNY
        metaNonce           // Local sender specific nonce (replay protection).
      ))
    );
  }

  /**
     * @dev gets the current metaNonce of an address
     * @param sender address of the metaTransaction sender
 **/
  function getMetaNonce(address sender) public view returns (uint256) {
    return metaNonces[sender];
  }

   /**
     * @dev extra getter function to potentially satisfy ERC1776
     * @param _from address of the metaTransaction sender
 **/

  function meta_nonce(address _from) external view returns (uint256 nonce) {
        return metaNonces[_from];
    }


  /**
     * @dev function to validate a signiture with a given address and payload that has been signed
 **/
  function isValidSignature(
    address _signer,
    bytes32 payload,
    bytes memory signature
  )
    public
    pure
    returns (bool)
  {
    return (_signer == ECDSA.recover(
      ECDSA.toEthSignedMessageHash(payload),
      signature
    ));
  }
 /**
     * @dev Emitted when metaTransfer is successfully executed
     */
      event MetaTransfer(address indexed relayer, address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when metaApprove is successfully executed
     */
    event MetaApproval(address indexed relayer, address indexed owner, address indexed spender, uint256 value);


    /**
     * @dev metaTransfer function called by relayer which executes a token transfer
     * on behalf of the original sender who provided a vaild signature.
     * @param _from address of the original sender
     * @param _to address of the  recipient
     * @param value uint256 amount of uCNY being sent
     * @param fee uint256 uCNY fee rewarded to the relayer
     * @param metaNonce uint256 metaNonce of the original sender
     * @param signature bytes signature provided by original sender
     */
  function metaTransfer(
        address _from,
        address _to,
        uint256 value,
        uint256 fee,
        uint256 metaNonce,
        bytes memory signature
  ) public returns (bool success) {


    // Verify and increment nonce.
    require(getMetaNonce(_from) == metaNonce);
    metaNonces[_from] = metaNonces[_from].add(1);
    // Verify signature.
    bytes32 payload = getTransferPayload(_from,_to, value, fee, metaNonce);
    require(isValidSignature(_from,payload,signature));

    require(_from != address(0));

    //_transfer(sender,receiver,value);
    _transfer(_from,_to,value);
    //send Fee to metaTx miner
    _transfer(_from,msg.sender,fee);

    emit MetaTransfer(msg.sender, _from,_to,value);
    return true;
  }

/**
     * @dev metaApprove function called by relayer which executes a token approval
     * on behalf of the original sender who provided a vaild signature.
     * @param _from address of the original approver
     * @param _to address of the  recipient
     * @param value uint256 amount of uCNY being sent
     * @param fee uint256 uCNY fee rewarded to the relayer
     * @param metaNonce uint256 metaNonce of the original approver
     * @param signature bytes signature provided by original approver
     */
    function metaApprove(
        address _from,
        address _to,
        uint256 value,
        uint256 fee,
        uint256 metaNonce,
        bytes memory signature
    ) public returns (bool success) {
    // Verify and increment nonce.
    require(getMetaNonce(_from) == metaNonce);
    metaNonces[_from] = metaNonces[_from].add(1);

    // Verify signature.
    bytes32 payload = getApprovePayload(_from,_to, value, fee,metaNonce);
    require(isValidSignature(_from, payload, signature));

    require(_from != address(0));

    //_approve(sender,receiver,value);
    _approve(_from,_to,value);

    //send Fee to metaTx miner
    _transfer(_from,msg.sender,fee);

    emit MetaApproval(msg.sender,_from,_to,value);
    return true;
    }


/**
     * @dev metaTransferFrom function called by relayer which executes a token transferFrom
     * on behalf of the original sender who provided a vaild signature.
     * @param _from address of the original sender
     * @param _to address of the  recipient
     * @param value uint256 amount of uCNY being sent
     * @param fee uint256 uCNY fee rewarded to the relayer
     * @param metaNonce uint256 metaNonce of the original sender
     * @param signature bytes signature provided by original sender
     */
    function metaTransferFrom(
        address _from,
        address _to,
        address _by,
        uint256 value,
        uint256 fee,
        uint256 metaNonce,
        bytes memory signature
        ) public returns(bool){
    // Verify and increment nonce.
    require(getMetaNonce(_by) == metaNonce);
    metaNonces[_by] = metaNonces[_by].add(1);

    // Verify signature.
    bytes32 payload = getTransferFromPayload(_from,_to,_by, value,fee, metaNonce);
    require(isValidSignature(_by, payload, signature));

    require(_by != address(0));

    //_transfer(sender,receiver,value);
    _transfer(_from,_to,value);

      //send Fee to metaTx miner
    _transfer(_by,msg.sender,fee);

    //subtract approved amount by value+fee
    _approve(_from, _by, allowed[_from][_by].sub(value));

    emit MetaTransfer(msg.sender, _from,_to,value);

    return true;
    }

       /**
     * @dev Transfer token for a specified addresses.
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0));

        balances[from] = balances[from].sub(value);
        balances[to] = balances[to].add(value);
        emit Transfer(from, to, value);
    }

    /**
     * @dev Approve an address to spend another addresses' tokens.
     * @param owner The address that owns the tokens.
     * @param spender The address that will spend the tokens.
     * @param value The number of tokens that can be spent.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        require(spender != address(0));
        require(owner != address(0));

        allowed[owner][spender] = value;
        emit Approval(owner, spender, value);
    }
}pragma solidity ^0.5.1;

import "./Ownable.sol";

/**
 * @title Blacklistable Token
 * @dev Allows accounts to be blacklisted by a "blacklister" role
*/
contract Blacklistable is Ownable {

    address public blacklister;
    mapping(address => bool) internal blacklisted;

    event Blacklisted(address indexed _account);
    event UnBlacklisted(address indexed _account);
    event BlacklisterChanged(address indexed newBlacklister);

    /**
     * @dev Throws if called by any account other than the blacklister
    */
    modifier onlyBlacklister() {
        require(msg.sender == blacklister);
        _;
    }

    /**
     * @dev Throws if argument account is blacklisted
     * @param _account The address to check
    */
    modifier notBlacklisted(address _account) {
        require(blacklisted[_account] == false);
        _;
    }

    /**
     * @dev Checks if account is blacklisted
     * @param _account The address to check
    */
    function isBlacklisted(address _account) public view returns (bool) {
        return blacklisted[_account];
    }

    /**
     * @dev Adds account to blacklist
     * @param _account The address to blacklist
    */
    function blacklist(address _account) public onlyBlacklister {
        blacklisted[_account] = true;
        emit Blacklisted(_account);
    }

    /**
     * @dev Removes account from blacklist
     * @param _account The address to remove from the blacklist
    */
    function unBlacklist(address _account) public onlyBlacklister {
        blacklisted[_account] = false;
        emit UnBlacklisted(_account);
    }

    function updateBlacklister(address _newBlacklister) public onlyOwner {
        require(_newBlacklister != address(0));
        blacklister = _newBlacklister;
        emit BlacklisterChanged(blacklister);
    }
}pragma solidity ^0.5.0;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * (.note) This call _does not revert_ if the signature is invalid, or
     * if the signer is otherwise unable to be retrieved. In those scenarios,
     * the zero address is returned.
     *
     * (.warning) `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise)
     * be too long), and then calling `toEthSignedMessageHash` on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        // Check the signature length
        if (signature.length != 65) {
            return (address(0));
        }

        // Divide the signature in r, s and v variables
        bytes32 r;
        bytes32 s;
        uint8 v;

        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (281): 0 < s < secp256k1n ÷ 2 + 1, and for v in (282): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return address(0);
        }

        if (v != 27 && v != 28) {
            return address(0);
        }

        // If the signature is valid (and not malleable), return the signer address
        return ecrecover(hash, v, r, s);
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * replicates the behavior of the
     * [`eth_sign`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_sign)
     * JSON-RPC method.
     *
     * See `recover`.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
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
}pragma solidity ^0.5.1;

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
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}pragma solidity ^0.5.1;

import "./Ownable.sol";

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 * Based on openzeppelin tag v1.10.0 commit: feb665136c0dae9912e08397c1a21c4af3651ef3
 * Modifications:
 * 1) Added pauser role, switched pause/unpause to be onlyPauser (6/14/2018)
 * 2) Removed whenNotPause/whenPaused from pause/unpause (6/14/2018)
 * 3) Removed whenPaused (6/14/2018)
 * 4) Switches ownable library to use zeppelinos (7/12/18)
 * 5) Remove constructor (7/13/18)
 */
contract Pausable is Ownable {
  event Pause();
  event Unpause();
  event PauserChanged(address indexed newAddress);


  address public pauser;
  bool public paused = false;

  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  /**
   * @dev throws if called by any account other than the pauser
   */
  modifier onlyPauser() {
    require(msg.sender == pauser);
    _;
  }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
  function pause() onlyPauser public {
    paused = true;
    emit Pause();
  }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
  function unpause() onlyPauser public {
    paused = false;
    emit Unpause();
  }

  /**
   * @dev update the pauser role
   */
  function updatePauser(address _newPauser) onlyOwner public {
    require(_newPauser != address(0));
    pauser = _newPauser;
    emit PauserChanged(pauser);
  }

}pragma solidity ^0.5.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * lopiddyuirt
 * Math` restores this intuition by reverting the transaction when an
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