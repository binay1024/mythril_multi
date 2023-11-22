pragma solidity ^0.5.0;

import "./buggy_23-1.sol";
contract Test2 {
  mapping(address => bool) money;
  
  function enter(Test1 pnode, address addr) public returns (bool) {
    if (pnode.getTwice() <= 10) {
      msg.sender.call.value(10)("");
      money[addr] = true;
    }
    return true;
  }
}