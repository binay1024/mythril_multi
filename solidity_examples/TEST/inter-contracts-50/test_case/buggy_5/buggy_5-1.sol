pragma solidity ^0.5.0;
contract Test1 {
    bool public flag = true;
    function getGoal() public view returns(uint) {
        if (flag) return 5000;
        else return 3000;
    }
}

