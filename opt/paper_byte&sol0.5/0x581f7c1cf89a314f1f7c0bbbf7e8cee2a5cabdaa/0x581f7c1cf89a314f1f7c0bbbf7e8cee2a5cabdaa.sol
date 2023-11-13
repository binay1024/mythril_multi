pragma solidity ^0.5.11;

pragma solidity ^0.5.1;
import "./ERC20_Token.sol";

/**
 * 
 * @title Drops (DRP)
 * @dev Drops crypto currency smart contract based upon the ERC20 standart token 
 *
 * Drops (DRP) Smart Contract v1.0 08.09.2019  (c) Mark R Rogers, 2019.
 * 
 **/
contract Drops is ERC20_Token {                                                     // Build on ERC20 standard contract 
    // Initalise variables and data
    string constant TOKEN_NAME = "Drops";                                           // Token description
    string constant TOKEN_SYMBOL = "DRP";                                           // Token symbol
    uint8  constant TOKEN_DECIMALS = 8;                                             // Token decimals

    // Initial contract deployment setup
    // @notice only run when the contract is created
    // @param initialMint_ The amount of coins to create
    constructor(uint256 initialMint_) public {
        name = TOKEN_NAME;                                                          // Set description
        symbol = TOKEN_SYMBOL;                                                      // Set symbol
        decimals = TOKEN_DECIMALS;                                                  // Set decimals
        coinOwner = msg.sender;                                                     // Set coin owner identity
        coinSupply = initialMint_.toklets(TOKEN_DECIMALS);                          // Set total supply in droplets
        balances[msg.sender] = coinSupply;                                          // Set owners balance
    }
}pragma solidity ^0.5.1;
import "../Genesis.sol";

/**
 * 
 * @title ERC20 Standard Token
 * 
 * Inherits events, modifiers & data from the genesis contract which complies with the ERC20 token Standard.
 * Inizalizes genesis functions & extra added functions
 * 
 **/
contract ERC20_Token is Genesis {                                                     // Build on genesis contract
    // Initalise global constants
    string constant ERR_INSUFFICENT_BALANCE = "Insufficent amount of DRP";          // Error message 102
    string constant ERR_INVALID_DELEGATE    = "Invalid delegate address";           // Error message 103
    string constant ERR_ALLOWANCE_EXCEEDED  = "Allowance exceeded!";                // Error message 104
    string constant ERR_INVALID_KILL_CODE   = "Invalid kill code!";                 // Error message 105
    string constant KILL_CODE               = "K-C102-473";                         // WARNING! Contracts kill code

    // Create new tokens
    // @para tokens_ number of new tokens to create
    function mintCoins(uint tokens_) ownerOnly public returns (uint balance) {
        tokens_ = tokens_.toklets(decimals);                                        // Convert tokens to toklets
        coinSupply = coinSupply.add(tokens_);                                       // Create new tokens
        balances[coinOwner] = balances[coinOwner].add(tokens_);                     // Update owners balace
      return coinSupply;
    }
    
    // Destroy tokens
    // @para tokens_ number of tokens to destroy
    function burnCoins(uint tokens_) ownerOnly public returns (uint balance) {      // Restricted to owner only
        tokens_ = tokens_.toklets(decimals);                                        // Convert tokens to toklets
        if (valid(tokens_ <= balances[coinOwner], 102)) {                           // Check enough tokens available
            coinSupply = coinSupply.sub(tokens_);                                   // Decrease total coin supply
            balances[coinOwner] = balances[coinOwner].sub(tokens_);                 // Update owners token balance
          return coinSupply;
        }
    }
    
    // Genesis: Transfer tokens to receiver
    function transfer(address receiver_,
                     uint tokens_) public returns (bool sucess) {
      super.transfer(receiver_, tokens_);
        if (valid(tokens_ <= balances[msg.sender] &&                                // Check enough tokens available
            tokens_ > 0, 102)) {                                                    // and amount greater than zero
            balances[msg.sender] = balances[msg.sender].sub(tokens_);               // Decrease senders token balance
            balances[receiver_] = balances[receiver_].add(tokens_);                 // Increase receivers token balance
            emit Transfer(msg.sender, receiver_, tokens_);                          // Transfer tokens
          return true;
        }
    }

    // Genesis: Approve token allowence for delegate
    function approve(address delegate_,
                    uint tokens_) public returns (bool sucess) {
      super.approve(delegate_, tokens_);
        if (valid(delegate_ != msg.sender, 103)) {                                  // Check not delegating to yourself
            if (tokens_ > coinSupply) { tokens_ = coinSupply; }                     // Limit allowance to total supply
            allowed[msg.sender][delegate_] = tokens_;                               // Update token allowence
            emit Approval(msg.sender, delegate_, tokens_);                          // Approve token allowance
          return true;
        }
    }

    // Genesis: Transfer token from delegated address
    function transferFrom(address owner_, address receiver_,
                         uint tokens_) public returns (bool sucess) {
      super.transferFrom(owner_ , receiver_, tokens_);
        if (valid(tokens_ > 0 && tokens_ <= balances[owner_], 102) &&               // Check amount greater than zero and enough tokens available
            valid(tokens_ <= allowed[owner_][msg.sender], 104)) {                   // Make sure smount is equal or less than token allowance
            balances[owner_] = balances[owner_].sub(tokens_);                       // Decrease owner of tokens balance
            allowed[owner_][msg.sender] = allowed[owner_][msg.sender].sub(tokens_); // Decrease senders tokens allowance
            balances[receiver_] = balances[receiver_].add(tokens_);                 // Increase receivers tokens balance
            emit Transfer(owner_, receiver_, tokens_);                              // Transfer tokens from the owner to the receiver
        return true;
        }
    }
    
    // Validation for autherisation and input error handler
    function valid(bool valid_, uint errorID_) internal pure returns (bool) {       // Check for fatal errors
        if (errorID_ == 101) {require(valid_, ERR_PERMISSION_DENIED);}              // Calling address doesn't have permission
          else if (errorID_ == 102) {require(valid_, ERR_INSUFFICENT_BALANCE);}     // Cancel trasaction due to insufficent value
          else if (errorID_ == 103) {require(valid_, ERR_INVALID_DELEGATE);}        // Cannot delegate to address 
          else if (errorID_ == 104) {require(valid_, ERR_ALLOWANCE_EXCEEDED);}      // Cancel trasaction due to insufficent value
          else if (errorID_ == 105) {require(valid_, ERR_INVALID_KILL_CODE);}       // Cancel trasaction due to insufficent value
          else if (errorID_ == 100) {require (valid_);}                             // Check if required?
        return valid_;
    }
    
    // WARNING! CONFIRM NOTHING ELSE NEEDS THIS CONTRACT BEFORE BURNING IT!
    // Terminates contract
    // @param killCode_ The contracts kill code
    // @return if contract has been terminated
    function burnContract(string memory killCode_) ownerOnly public {
        if (valid((keccak256(abi.encodePacked(killCode_)) ==
                   keccak256(abi.encodePacked(KILL_CODE))), 105))                    // Authenticate kill code
                   { selfdestruct(address(0)); }                                     // Kill contract
    }
}pragma solidity ^0.5.1;

/**
 * 
 * @title SafeMath Library
 * 
 * @dev Math operations with safety checks that throw on logic error
 * 
 *
 */
library SafeMath {
    // Converts Tokens into Toklets
    function toklets(uint256 numA_, uint8 numD_) internal pure returns (uint256) {
        uint256 numB_ = 10**uint256(numD_);
        uint256 numC_ = numA_ * numB_;
        require(numA_ > 0 && numC_ / numA_ == numB_, "Invalid amount of tokens");
      return numC_;
    }
 
    // Multipy unsigned integer value and check logic 
    function mul(uint256 numA_, uint256 numB_) internal pure returns (uint256) {
        uint256 numC_ = numA_ * numB_;
        assert(numA_ == 0 || numC_ / numA_ == numB_);
      return numC_;
    }
 
    // Divide unsigned integer value and check logic
    function div(uint256 numA_, uint256 numB_) internal pure returns (uint256) {
        uint256 numC_ = numA_ / numB_;                                                           // Solidity automatically throws when dividing by 0
      return numC_;
    }

    // Subtract unsigned integer value and check logic
    function sub(uint256 numA_, uint256 numB_) internal pure returns (uint256) {
        assert(numB_ <= numA_);
      return numA_ - numB_;
    }

     // Add unsigned integer values and check logic
    function add(uint256 numA_, uint256 numB_) internal pure returns (uint256) {
        uint256 numC_ = numA_ + numB_;
        assert(numC_ >= numA_);
      return numC_;
    }
}

/**
 * 
 * @title Genesis Contract
 * 
 * Initializes events, modifiers & data in the contract and defines default functionality
 * that follows the ERC20 standard token format
 * 
 **/
contract Genesis {
    using SafeMath for uint256;                                                     // Use SafeMath library to test the logic of uint256 calculations

    // Initalise contract global constants
    string constant ERR_PERMISSION_DENIED   = "Permission denied!";                 // Error message 101

    // Initalise token information 
    string public name;                                                             // Token Name
    string public symbol;                                                           // Token Symbol
    uint8  public decimals;                                                         // Token decimals (droplets)
    address coinOwner ;                                                             // Token owners address
    uint256 coinSupply;                                                             // Total token supply
    mapping(address => uint256) balances;                                           // Token balance state
    mapping(address => mapping (address => uint256)) allowed;                       // Token allowance state

    // Owner privelages only 
    modifier ownerOnly() {
        require(msg.sender == coinOwner, ERR_PERMISSION_DENIED) ;
        _;
    }

    // Transfer tokens
    event Transfer(address indexed owner_, address indexed receiver_, uint256 tokens_);
    
    // Approve token allowances
    event Approval(address indexed owner_, address indexed delegate_, uint256 tokens_);

    // Fallback function handles unidentified calls and allows contract to receive payments
    function() payable external { }
    
    // @return total supply of tokens
    function totalSupply() external view returns (uint256 supply) { return coinSupply; }
    
    // @return number of tokens at address
    function balanceOf(address owner_) external view returns (uint balance) { return balances[owner_]; }
    
    // Transfer tokens to receiver
    // @notice send `token_` token to `receiver_` from `msg.sender`
    // @param receiver_ The address of the recipient
    // @param token_ The amount of token to be transferred
    // @return whether the transfer was successful or not
    function transfer(address receiver_, uint tokens_) public returns (bool sucess) {}

    // Approve tokens allowence for delegate
    // @notice `msg.sender` approves `delegate_` to spend `_tokens`
    // @param _receiver The address of the account able to transfer the tokens
    // @param _tokens The amount of wei to be approved for transfer
    // @return Whether the approval was successful or not
    function approve(address delegate_, uint tokens_) public returns (bool sucess) {}
    
    // Returns approved tokens allowance for delegate
    // @param _owner The address of the account owning tokens
    // @param _spender The address of the account able to transfer the tokens
    // @return Amount of remaining tokens allowed to spent
    function allowance(address owner_, address delegate_) external view returns (uint remaining) { return allowed[owner_][delegate_]; }

    // Transfer tokens from delegated address
    // @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
    // @param _from The address of the sender
    // @param _to The address of the recipient
    // @param _value The amount of token to be transferred
    // @return Whether the transfer was successful or not
    function transferFrom(address owner_, address receiver_, uint tokens_) public returns (bool sucess) { }
}