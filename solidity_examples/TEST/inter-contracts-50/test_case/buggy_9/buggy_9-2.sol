pragma solidity ^0.5.0;

import "./buggy_9-1.sol";
contract Test2 {
    function transferMoney (Test1 t1, address addr) public {
        t1.setGoal1(3000);
        t1.setGoal2(5000);
        bool goal = t1.getResult();
        if (goal) {
            addr.call.value(10)("");
        }
    }
}
