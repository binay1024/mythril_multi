pragma solidity ^0.5.0;


import "./buggy_14-1.sol";
contract Test2 {
    function transferMoney (Test1 t1, address addr) public {
        uint goal = t1.getGoal();
        uint anotherGoal = t1.getAnotherGoal();
        if (anotherGoal < 7000 && goal > 4000) {
            addr.call.value(10)("");
        }
    }
}
