pragma solidity ^0.5.0;

import "./buggy_3-1.sol";
contract Test2 {
    function transferMoney (Test1 t1, address addr) public {
        t1.setGoal(2000);
        bool res = t1.getResult();
        if (!res) {
            addr.call.value(10)("");
        }
    }
}
