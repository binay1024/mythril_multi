pragma solidity ^0.5.0;

contract Test1 {
    uint public goal = 5000;
    function getResult(uint i) public view returns(bool) {
        return goal > i;
    }
    function setGoal(uint i) public {
        goal = i;
    }
}
