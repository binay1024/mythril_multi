pragma solidity ^0.5.0;


import "./buggy_19-1.sol";
contract Test2 {
    function transferMoney (Test1 t1, address addr) public {
        uint goal = t1.getGoal();
        require(6000 > goal);
        addr.call.value(10)("");
    }
}
