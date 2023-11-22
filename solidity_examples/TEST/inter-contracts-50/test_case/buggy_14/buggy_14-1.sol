pragma solidity ^0.5.0;

contract Test1 {
    uint public goal = 5000;
    uint public anotherGoal = 6000;
    function getGoal() public view returns(uint) {
        return goal;
    }
    function getAnotherGoal() public view returns(uint) {
        return anotherGoal;
    }
}

