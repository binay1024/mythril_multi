pragma solidity ^0.6.0;


import "./buggy_42-1.sol";
contract Test2 {
  bool not_called_re_ent41 = true;
  
  function enter(address p, uint x, address addr) public returns (bool) {
    Test1 pnode = Test1(p);
    if (pnode.getTwice() == 10) {
        require(not_called_re_ent41);
      (bool success, ) = msg.sender.call.value(10)("");

      if (!success) {
        revert();
      }
        not_called_re_ent41 = false;
    }
    return not_called_re_ent41;
  }
}