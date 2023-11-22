pragma solidity ^0.5.0;
import "./buggy_17-1.sol";
contract Test2 {
    function transferMoney (Test1 t1, address addr) public {
        uint res = t1.checkInput(1000);
        if (res == 0) {
            addr.call.value(10)("");
        }
    }
}
