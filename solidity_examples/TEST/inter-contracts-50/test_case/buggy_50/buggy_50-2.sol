pragma solidity ^0.5.0;


import "./buggy_50-1.sol";
contract Test2 {
  mapping(address => bool) money;
  
  function enter(address p, address addr) public returns (bool) {
    Test1 pnode = Test1(p);
    if (pnode.getTwice() == 10) {
      msg.sender.call.value(pnode.getTwice())("");
      money[addr] = true;
    }
    return true;
  }
}