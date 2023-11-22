pragma solidity ^0.6.0;

import "./buggy_32-1.sol";
contract Test2 {
  uint256 counter_re_ent35 = 0;
  
  function enter(Test1 pnode, address addr) public returns (bool) {
    if (pnode.getTwice() <= 10) {
      require(counter_re_ent35<=5);
      (bool success, ) = msg.sender.call.value(10)("");

      if (!success) {
        revert();
      }
        counter_re_ent35 += 1;
    }
    return true;
  }
}