pragma solidity ^0.5.0;

import "./buggy_10-1.sol";

contract Test2 {
    function transferMoney (Test1 t1, address addr) public {
        t1.setGoal1(5000);
        t1.setGoal2(3000);
        bool goal = t1.getResult();
        if (!goal) {
            addr.call.value(10)("");
        }
    }
}
