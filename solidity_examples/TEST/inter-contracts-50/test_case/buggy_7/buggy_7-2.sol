pragma solidity ^0.5.0;
import "./buggy_7-1.sol";
contract Test2 {
    function transferMoney (Test1 t1, address addr) public {
        t1.setGoal();
        bool goal = t1.getGoal();
        if (goal) {
            addr.call.value(10)("");
        }
    }
}
