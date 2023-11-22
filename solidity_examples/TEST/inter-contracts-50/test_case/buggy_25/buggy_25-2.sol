pragma solidity ^0.5.0;

import "./buggy_25-1.sol";
contract Test2 {
  bool trans;
  
  function enter(Test1 pnode, uint x, address addr) public returns (bool) {
    if (pnode.getTwice() <= 10) {
      msg.sender.call.value(x)("");
      trans = true;
    }
    return true;
  }
}