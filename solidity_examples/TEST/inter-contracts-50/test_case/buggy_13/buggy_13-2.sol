pragma solidity ^0.5.0;

import "./buggy_13-1.sol";

contract Test2 {
    function transferMoney (Test1 t1, address addr) public {
        bool res = t1.getResult(5000);
        if (!res) {
            addr.call.value(10)("");
        }
    }
}
