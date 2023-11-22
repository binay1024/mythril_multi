pragma solidity ^0.5.0;

contract Test1 {
    uint public goal = 5000;
    function getGoal() public view returns(uint) {
        return goal;
    }
}
