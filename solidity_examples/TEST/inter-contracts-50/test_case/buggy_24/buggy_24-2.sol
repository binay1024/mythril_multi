pragma solidity ^0.5.0;

import "./buggy_24-1.sol";
contract Test2 {
  mapping(address => uint) money;
  
  function enter(Test1 pnode, address addr) public {
    if (pnode.getThree() < 100) {
      msg.sender.call.value(money[addr])("");
      money[addr] = 0;
    }
  }
}