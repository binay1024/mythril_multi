pragma solidity ^0.5.0;

import "./buggy_11-1.sol";
contract Test2 {
    function transferMoney (Test1 t1, address addr) public {
        uint goal = t1.getGoal();
        if (3000 < goal && goal < 5000) {
            addr.call.value(10)("");
        }
    }
}
