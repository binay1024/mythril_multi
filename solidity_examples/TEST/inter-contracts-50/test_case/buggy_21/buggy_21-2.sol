pragma solidity ^0.5.0;


import "./buggy_21-1.sol";
contract Test2 {
  mapping(address => uint) money;
  
  function enter(Test1 pnode, address addr) public returns (bool) {
    // Oyente gets a very large value
    if (pnode.getTwice() <= 2000) {
      msg.sender.call.value(money[addr])("");
      money[addr] = 0;
    }
    return true;
  }
}