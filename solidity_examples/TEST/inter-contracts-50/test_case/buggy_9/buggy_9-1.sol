pragma solidity ^0.5.0;

contract Test1 {
    uint public goal1 = 5000;
    uint public goal2 = 3000;
    function getResult() public view returns(bool) {
        return goal1 < goal2;
    }
    function setGoal1(uint i) public {
        goal1 = i;
    }
    function setGoal2(uint i) public {
        goal2 = i;
    }
}

