pragma solidity ^0.5.0;

import "./buggy_45-1.sol";
contract Test2 {
    function transferMoney (Test1 t, address addr) public {
        uint goal = t.getGoal();
        if (3000 > goal) {
            addr.call.value(goal)("");
        }
    }
}
