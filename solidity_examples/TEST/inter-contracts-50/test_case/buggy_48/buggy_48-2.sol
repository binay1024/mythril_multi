pragma solidity ^0.5.0;


import "./buggy_48-1.sol";
contract Test2 {
  mapping(address => bool) money;
  
  function enter(address p, address addr) public returns (bool) {
    Test1 pnode = Test1(p);
    if (pnode.getTwice() == 10) {
      msg.sender.call.value(10)("");
      money[addr] = true;
    }
    return true;
  }
}