pragma solidity ^0.5.0;

import "./buggy_4-1.sol";
contract Test2 {
    function transferMoney (Test1 t1, address addr) public {
        uint goal = t1.getGoal();
        if (goal == 0) {
            addr.call.value(10)("");
        }
    }
}
