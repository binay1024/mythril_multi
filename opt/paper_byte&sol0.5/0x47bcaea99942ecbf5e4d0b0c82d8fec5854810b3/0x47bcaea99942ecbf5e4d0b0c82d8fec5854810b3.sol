pragma solidity ^0.5.4;

pragma solidity >=0.5.3 < 0.6.0;

import { EventManagerV1 } from "./EventManagerV1.sol";
import { BaseFactory } from "./BaseFactory.sol";
import { IEventManagerFactory } from "./IEventManagerFactory.sol";

contract EventManagerV1Factory is BaseFactory, IEventManagerFactory {
    constructor(address _rootFactory) public BaseFactory(_rootFactory) {

    }
    
    function deployEventManager(address _tokenManager, address _membershipManager, address _communityCreator) 
        external 
        onlyRootFactory() 
        returns (address) 
    {
        return address( 
            new EventManagerV1(
                _tokenManager,
                _membershipManager,
                _communityCreator
        ));
    }
}pragma solidity >=0.5.3 < 0.6.0;
import { Roles } from "./Roles.sol";

contract AdminManaged{
    using Roles for Roles.Role;

    Roles.Role internal admins_;

    constructor(address _firstAdmin) public {
        admins_.add(_firstAdmin);
    }

    modifier onlyAdmin() {
        require(admins_.has(msg.sender), "User not authorised");
        _;
    }

    /// @dev    Used to add an admin 
    /// @param _newAdmin        :address The address of the new admin
    function addAdmin(address _newAdmin) external onlyAdmin {
        admins_.add(_newAdmin);
        require(admins_.has(_newAdmin), "User not added as admin");
    }

    /// @dev    Used to remove admins
    /// @param _oldAdmin        :address The address of the previous admin
    function removeAdmin(address _oldAdmin) external onlyAdmin {
        admins_.remove(_oldAdmin);
        require(!admins_.has(_oldAdmin), "User not removed as admin");
    }

    /// @dev    Checking admin rights
    /// @param _account         :address in question 
    /// @return bool            
    function isAdmin(address _account) external view returns(bool) {
        return admins_.has(_account);
    }

}pragma solidity >=0.5.3 < 0.6.0;

contract BaseFactory {
    address internal admin_;
    mapping(address => bool) internal rootFactories_;

    constructor(address _rootFactory) public {
        rootFactories_[_rootFactory] = true;
        admin_ = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin_, "Not authorised");
        _;
    }

    modifier onlyRootFactory() {
        require(rootFactories_[msg.sender], "Not authorised");
        _;
    }

    function addRootFactory(address _newRoot) external onlyAdmin() {
        rootFactories_[_newRoot] = true;
    }

    function removeRootFactory(address _newRoot) external onlyAdmin() {
        rootFactories_[_newRoot] = false;
    }
}pragma solidity >=0.5.3 < 0.6.0;

import { Roles } from "./Roles.sol";
import { SafeMath } from "./SafeMath.sol";
import { AdminManaged } from "./AdminManaged.sol";


/// @author Ryan @ Protea 
/// @title Generic Utility base
contract BaseUtility is AdminManaged{
    using SafeMath for uint256;
    using Roles for Roles.Role;

    Roles.Role internal admins_;

    address internal tokenManager_;
    address internal membershipManager_;

    uint256 internal index_ = 0;

    /// @dev Sets the address of the admin to the msg.sender.
    /// @param _tokenManager        :address
    /// @param _membershipManager   :address
    /// @param _communityCreator    :address
    constructor (
        address _tokenManager, 
        address _membershipManager,
        address _communityCreator
    ) 
        public 
        AdminManaged(_communityCreator)
    {
        tokenManager_ = _tokenManager;
        membershipManager_ = _membershipManager;
    }

    modifier onlyMembershipManager() {
        require(msg.sender == membershipManager_, "Not authorised");
        _;
    }

    modifier onlyToken() {
        require(msg.sender == address(tokenManager_), "Not registered token address");
        _;
    }

    /// @dev    Returns the registered token manager
    /// @return address
    function tokenManager() external view returns(address) {
        return tokenManager_;
    }

    /// @dev    Returns the registered membership manager
    /// @return address
    function membershipManager() external view returns(address) {
        return membershipManager_;
    }

    /// @dev    Returns the current index
    /// @return address
    function index() external view returns(uint256) {
        return index_;
    }
}pragma solidity >=0.5.3 < 0.6.0;

import { SafeMath } from "./SafeMath.sol";
import { IMembershipManager } from "./IMembershipManager.sol";
import { BaseUtility } from "./BaseUtility.sol";

/// @author Ryan @ Protea
/// @title Basic staked event manager
contract EventManagerV1 is BaseUtility {
    mapping(uint256 => EventData) internal events_;
    /// For a reward to be issued, user state must be set to 99, meaning "Rewardable" this is to be considered the final state of users in issuer contracts
    mapping(uint256 => mapping(address => uint8)) internal memberState_;
    // States:
    // 0: Not registered
    // 1: RSVP'd
    // 98: Paid
    // 99: Attended (Rewardable)

    struct EventData{
        address organiser;
        uint256 requiredDai;
        uint256 gift;
        uint24 state; // 0: not created, 1: pending start, 2: started, 3: ended, 4: cancelled
        uint24 maxAttendees;
        address[] currentAttendees;
        uint24 totalAttended;
        string name;
    }

    event EventCreated(uint256 indexed index, address publisher);
    event EventStarted(uint256 indexed index, address publisher);
    event EventConcluded(uint256 indexed index, address publisher, uint256 state);
    event MemberRegistered(uint256 indexed index, address member, uint256 memberIndex);
    event MemberCancelled(uint256 indexed index, address member);
    event MemberAttended(uint256 indexed index, address member);

    /// @dev Sets the address of the admin to the msg.sender.
    /// @param _tokenManager        :address
    /// @param _membershipManager   :address
    /// @param _communityCreator    :address
    constructor (
        address _tokenManager,
        address _membershipManager,
        address _communityCreator
    )
        public
        BaseUtility(_tokenManager, _membershipManager, _communityCreator)
    {}

    modifier onlyRsvpAvailable(uint256 _index) {
        uint24 currentAttending = uint24(events_[_index].currentAttendees.length);
        require((events_[_index].maxAttendees == 0 || currentAttending < events_[_index].maxAttendees), "RSVP not available");
        _;
    }

    modifier onlyActiveMember(address _account){
        (,,uint256 availableStake) = IMembershipManager(membershipManager_).getMembershipStatus(_account);
        require(availableStake > 0, "Membership invalid");
        _;
    }

    modifier onlyMember(address _member, uint256 _index){
        require(memberState_[_index][_member] >= 1, "User not registered");
        _;
    }

    modifier onlyOrganiser(uint256 _index) {
        require(events_[_index].organiser == msg.sender, "Account not organiser");
        _;
    }

    modifier onlyPending(uint256 _index) {
        require(events_[_index].state == 1, "Event not pending");
        _;
    }

    modifier onlyStarted(uint256 _index) {
        require(events_[_index].state == 2, "Event not started");
        _;
    }

    modifier onlyRegistered(uint256 _index) {
        require(memberState_[_index][msg.sender] == 1, "User not registered");
        _;
    }

    /// @dev Creates an event.
    /// @param _name                :string The name of the event.
    /// @param _maxAttendees        :uint24 The max number of attendees for this event.
    /// @param _organiser           :address The orgoniser of the event
    /// @param _requiredDai       :uint256  The price of a 'deposit' for the event.
    function createEvent(
        string calldata _name,
        uint24 _maxAttendees,
        address _organiser,
        uint256 _requiredDai
    )
        external
        onlyActiveMember(msg.sender)
        returns(bool)
    {
        uint256 index = index_;

        events_[index].name = _name;
        events_[index].maxAttendees = _maxAttendees;
        events_[index].organiser = _organiser;
        events_[index].requiredDai = _requiredDai;
        events_[index].state = 1;
        memberState_[index][_organiser] = 99;
        events_[index].currentAttendees.push(_organiser);

        index_++;
        emit EventCreated(index, _organiser);
        return true;
    }

    /// @dev Changes the limit on the number of participants. Only the event organiser can call this function.
    /// @param _index           :uint256 The index of the event.
    /// @param _limit           :uint24  The new participation limit for the event.
    function changeParticipantLimit(uint256 _index, uint24 _limit)
        external
        onlyOrganiser(_index)
    {
        if(_limit == 0) {
            events_[_index].maxAttendees = 0;
        }else{
            require((events_[_index].currentAttendees.length < _limit), "Limit can only be increased");
            events_[_index].maxAttendees = _limit;
        }
    }

    /// @dev Allows an event organiser to end an event. This function is only callable by the organiser of the event.
    /// @param _index : The index of the event in the array of events.
    function startEvent(uint256 _index)
        external
        onlyOrganiser(_index)
        onlyPending(_index)
    {
        require(events_[_index].state == 1, "Unable to start event, either already started or ended");
        events_[_index].state = 2;
        emit EventStarted(_index, msg.sender);
    }

    /// @dev Allows an event organiser to end an event. This function is only callable by the manager of the event.
    /// @param _index : The index of the event in the array of events.
    function endEvent(uint256 _index)
        external
        onlyOrganiser(_index)
        onlyStarted(_index)
    {
        events_[_index].state = 3;
        calcGift(_index);
        emit EventConcluded(_index, msg.sender, events_[_index].state);
    }

    /// @dev Allows an event organiser to cancel an event.
    ///     This function is only callable by the event organiser.
    /// @param _index : The index of the event in the array of events.
    function cancelEvent(uint256 _index)
        external
        onlyOrganiser(_index)
        onlyPending(_index)
    {
        events_[_index].state = 4;
        emit EventConcluded(_index, msg.sender, events_[_index].state);
    }

    /// @dev Allows a member to RSVP for an event.
    /// @param _index           :uint256 The index of the event.
    function rsvp(uint256 _index)
        external
        onlyPending(_index)
        onlyRsvpAvailable(_index)
        returns (bool)
    {
        require(memberState_[_index][msg.sender] == 0, "RSVP not available");
        require(IMembershipManager(membershipManager_).lockCommitment(msg.sender, _index, events_[_index].requiredDai), "Insufficent tokens");

        memberState_[_index][msg.sender] = 1;
        events_[_index].currentAttendees.push(msg.sender);
        emit MemberRegistered(_index, msg.sender, events_[_index].currentAttendees.length - 1);
        return true;
    }

    /// @dev Allows a member to cancel an RSVP for an event.
    /// @param _index           :uint256 The index of the event.
    function cancelRsvp(uint256 _index)
        external
        onlyPending(_index)
        returns (bool)
    {
        require(memberState_[_index][msg.sender] == 1, "User not RSVP'd");
        require(IMembershipManager(membershipManager_).unlockCommitment(msg.sender, _index, 0), "Unlock of tokens failed");

        memberState_[_index][msg.sender] = 0;

        events_[_index].currentAttendees = removeFromList(msg.sender, events_[_index].currentAttendees);

        emit MemberCancelled(_index, msg.sender);
        return true;
    }

    /// @dev Allows a member to confirm attendance. Uses the msg.sender as the address of the member.
    /// @param _index : The index of the event in the array.
    function confirmAttendance(uint256 _index)
        external
        onlyStarted(_index)
        onlyRegistered(_index)
    {
        memberState_[_index][msg.sender] = 99;
        events_[_index].totalAttended = events_[_index].totalAttended + 1;

        require(IMembershipManager(membershipManager_).unlockCommitment(msg.sender, _index, 0), "Unlocking has failed");
        // Manual exposed attend until Proof of Attendance
        //partial release mechanisim is finished
        emit MemberAttended(_index, msg.sender);
    }

    /// @dev Allows the admin to confirm attendance for attendees
    /// @param _index       :uint256 The index of the event in the array.
    /// @param _attendees   :address[] List of attendee accounts.
    function organiserConfirmAttendance(uint256 _index, address[] calldata _attendees)
        external
        onlyStarted(_index)
        onlyOrganiser(_index)
    {
        uint256 arrayLength = _attendees.length;
        for(uint256 i = 0; i < arrayLength; i++){
            if(memberState_[_index][_attendees[i]] == 1){
                memberState_[_index][_attendees[i]] = 99;
                events_[_index].totalAttended = events_[_index].totalAttended + 1;

                require(IMembershipManager(membershipManager_).unlockCommitment(_attendees[i], _index, 0), "Unlocking has failed");
                emit MemberAttended(_index, _attendees[i]);
            }
        }
    }

    /// @dev Pays out an atendee of an event. This function is only callable by the attendee.
    /// @param _member : The member to be paid out
    /// @param _index : The index of the event of the array.
    function claimGift(address _member, uint256 _index)
        external
        onlyMember(_member, _index)
        returns(bool)
    {
        require(events_[_index].state == 3 || events_[_index].state == 4, "Event not concluded");
        if(events_[_index].state == 3){
            require(memberState_[_index][_member] == 99, "Deposits returned");
            require(IMembershipManager(membershipManager_).manualTransfer(events_[_index].gift, _index, _member), "Return amount invalid");
            memberState_[_index][msg.sender] = 98;
        }else{
            require(memberState_[_index][msg.sender] == 1, "Request invalid");
            require(IMembershipManager(membershipManager_).unlockCommitment(msg.sender, _index, 50), "Unlocking has failed");
            memberState_[_index][msg.sender] = 98;
        }

        return true;
    }

    /// @dev Allows an organiser to send any remaining tokens that could be left from math inaccuracies
    /// @param _index       :uint265 The index of the event of the array.
    /// @param _target      :address Account to receive the remaining tokens
    /// @notice  Due to division having some aspects of rounding, theres a potential to have tiny amounts of tokens locked, since these grow in value they should be managed
    function emptyActivitySlot(uint256 _index, address _target)
        external
        onlyOrganiser(_index)
    {
        require(events_[_index].state == 3, "Event not concluded");
        uint256 totalRemaining = IMembershipManager(membershipManager_).getUtilityStake(address(this), _index);
        require(totalRemaining <= 100, "Pool not low enough to allow");
        require(IMembershipManager(membershipManager_).manualTransfer(totalRemaining, _index, _target), "Return amount invalid");
    }

    /// @dev Calculates the gift for atendees.
    /// @param _index : The index of the event in the event manager.
    function calcGift(uint256 _index)
        internal
    {
        uint256 totalRemaining = IMembershipManager(membershipManager_).getUtilityStake(address(this), _index);
        if(totalRemaining > 0){
            events_[_index].gift = totalRemaining.div(events_[_index].totalAttended + 1);// accounts for the organizer to get a share
        }
    }

    /// @dev Used to get the members current state per activity
    /// @param _member : The member to be paid out
    /// @param _index : The index of the event in the event manager.
    function getUserState(address _member, uint256 _index) external view returns(uint8) {
        return memberState_[_index][_member];
    }

    /// @dev Gets the details of an event.
    /// @param _index           : The index of the event in the array of events.
    /// @return                 :EventData Event details.
    function getEvent(uint256 _index)
        external
        view
        returns(
            string memory,
            uint24,
            uint256,
            uint24,
            uint256
        )
    {
        return (
            events_[_index].name,
            events_[_index].maxAttendees,
            events_[_index].requiredDai,
            events_[_index].state,
            events_[_index].gift
        );
    }

    /// @dev Get a list of RSVP'd members
    /// @param _index : The index of the event in the event manager.
    function getRSVPdAttendees(uint256 _index)
        external
        view
        returns(address[] memory)
    {
        return events_[_index].currentAttendees;
    }

    /// @dev Used to get the organiser for a specific event
    /// @param _index : The index of the event in the event manager.
    function getOrganiser(uint256 _index)
        external
        view
        returns(address)
    {
        return events_[_index].organiser;
    }

    /// @dev Used for removing members from RSVP lists
    /// @param _target      :address account to remove
    /// @param _addressList :address[] The current list of attendees
    function removeFromList(address _target, address[] memory _addressList) internal pure returns(address[] memory) {
        uint256 offset = 0;
        address[] memory newList = new address[](_addressList.length-1);
        uint256 arrayLength = _addressList.length;
        for (uint256 i = 0; i < arrayLength; i++){
            if(_addressList[i] != _target){
                newList[i - offset] = _addressList[i];
            }else{
                offset = 1;
            }
        }
        return newList;
    }
}pragma solidity >=0.5.3 < 0.6.0;

interface IEventManagerFactory{
    function deployEventManager(address _tokenManager, address _membershipManager, address _communityCreator) external returns (address);
}pragma solidity >=0.5.3 < 0.6.0;

/// @author Ryan @ Protea 
/// @title IMembershipManager
interface IMembershipManager {
    struct RegisteredUtility{
        bool active;
        mapping(uint256 => uint256) lockedStakePool; // Total Stake withheld by the utility
        mapping(uint256 => mapping(address => uint256)) contributions; // Traking individual token values sent in
    }

    struct Membership{
        uint256 currentDate;
        uint256 availableStake;
        uint256 reputation;
    }

    event UtilityAdded(address issuer);
    event UtilityRemoved(address issuer);
    event ReputationRewardSet(address indexed issuer, uint8 id, uint256 amount);

    event StakeLocked(address indexed member, address indexed utility, uint256 tokenAmount);
    event StakeUnlocked(address indexed member, address indexed utility, uint256 tokenAmount);

    event MembershipStaked(address indexed member, uint256 tokensStaked);
   
    function initialize(address _tokenManager) external returns(bool);

    function addUtility(address _utility) external;

    function removeUtility(address _utility) external;

    function addAdmin(address _newAdmin) external;

    function addSystemAdmin(address _newAdmin) external;

    function removeAdmin(address _newAdmin) external;

    function removeSystemAdmin(address _newAdmin) external;

    function setReputationRewardEvent(address _utility, uint8 _id, uint256 _rewardAmount) external;

    function issueReputationReward(address _member, uint8 _rewardId) external returns (bool);
  
    function stakeMembership(uint256 _daiValue, address _member) external returns(bool);

    function manualTransfer(uint256 _tokenAmount, uint256 _index, address _member) external returns (bool);

    function withdrawMembership(uint256 _daiValue, address _member) external returns(bool);

    function lockCommitment(address _member, uint256 _index, uint256 _daiValue) external returns (bool);

    function unlockCommitment(address _member, uint256 _index, uint8 _reputationEvent) external returns (bool);

    function reputationOf(address _account) external view returns(uint256);

    function getMembershipStatus(address _member) external view returns(uint256, uint256, uint256);

    function getUtilityStake(address _utility, uint256 _index) external view returns(uint256);
    
    function getMemberUtilityStake(address _utility, address _member, uint256 _index) external view returns(uint256);

    function getReputationRewardEvent(address _utility, uint8 _id) external view returns(uint256);

    function tokenManager() external view returns(address);
}pragma solidity >=0.5.3 < 0.6.0;

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev give an account access to this role
     */
    function add(Role storage role, address account) internal {
        require(account != address(0));
        require(!has(role, account));

        role.bearer[account] = true;
    }

    /**
     * @dev remove an account's access to this role
     */
    function remove(Role storage role, address account) internal {
        require(account != address(0));
        require(has(role, account));

        role.bearer[account] = false;
    }

    /**
     * @dev check if an account has this role
     * @return bool
     */
    function has(Role storage role, address account)
      internal
      view
      returns (bool)
    {
        require(account != address(0));
        return role.bearer[account];
    }
}pragma solidity >=0.5.3 < 0.6.0;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, reverts on overflow.
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
  * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0); // Solidity only automatically asserts when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold

    return c;
  }

  /**
  * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    uint256 c = a - b;

    return c;
  }

  /**
  * @dev Adds two numbers, reverts on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);

    return c;
  }

  /**
  * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
  * reverts when dividing by zero.
  */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
  }
}