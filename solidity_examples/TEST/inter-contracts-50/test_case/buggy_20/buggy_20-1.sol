pragma solidity ^0.5.0;

contract Test1 {
    bool public goal1 = false;
    bool public goal2 = false;
    function getResult() public view returns(bool) {
        return goal1 || goal2;
    }
    function setGoal1(uint i) public {
        goal1 = i < 4000;
    }
    function setGoal2(uint i) public {
        goal2 = i > 4000;
    }
}

