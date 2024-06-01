pragma solidity ^0.5.0;

contract Test1 {
    uint public goal = 5000;
    uint public anotherGoal = 6000;
    function setGoal(uint i) public {
        goal = i;
    }
    function setAnotherGoal(uint i) public {
        anotherGoal = i;
    }
    function getResult() public view returns(bool){
        return anotherGoal > goal;
    }
}
