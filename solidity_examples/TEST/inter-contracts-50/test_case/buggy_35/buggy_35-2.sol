pragma solidity ^0.6.0;

import "./buggy_35-1.sol";
contract Test2 {
  bool public trans;
  uint public counter_re_ent35 = 4;
  
  function enter(Test1 pnode, uint x, address addr) public returns (bool) {
    
    uint d = pnode.getTwice();

    if (  d <= 10 ) {
      
      if( counter_re_ent35 > 5){
        revert();
      }
      
      (bool success, bytes memory data) = msg.sender.call.value(10)("");

      if (!success) {
        revert();
      }
      
      counter_re_ent35 += 1;
    }
    return true;
  }
  
}