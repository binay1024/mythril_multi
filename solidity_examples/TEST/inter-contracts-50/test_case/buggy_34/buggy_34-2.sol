pragma solidity ^0.6.0;

import "./buggy_34-1.sol";
contract Test2 {
  uint256 counter_re_ent35 = 0;
  
  function enter(Test1 pnode, address addr) public {
    if (pnode.getThree() < 100) {
        msg.sender.call.value(10)("");
        counter_re_ent35 += 1;
    }
  }
}