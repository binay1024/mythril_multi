pragma solidity ^0.5.0;

contract Test1 {
    uint public goal = 5000;
    function getResult() public view returns(bool) {
        return goal % 2 != 0;
    }
}

