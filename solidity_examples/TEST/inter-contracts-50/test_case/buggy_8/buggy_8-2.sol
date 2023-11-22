pragma solidity ^0.5.0;

import "./buggy_8-1.sol";
contract Test2 {
    function transferMoney (Test1 t1, address addr) public {
        bool goal = t1.getResult(3000);
        if (goal) {
            addr.call.value(10)("");
        }
    }
}
