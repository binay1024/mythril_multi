pragma solidity ^0.5.0;

contract Test1 {
    bool public goal = false;
    function getGoal() public view returns(bool) {
        return goal;
    }
    function setGoal() public {
        goal = true;
    }
}

