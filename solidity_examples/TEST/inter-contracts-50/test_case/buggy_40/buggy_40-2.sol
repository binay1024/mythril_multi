pragma solidity ^0.6.0;
import "./buggy_40-1.sol";
contract Test2 {
  bool not_called_re_ent41 = true;
  
  function enter(Test1 pnode, uint x, address addr) public returns (bool) {
    if (pnode.getTwice() <= 10) {
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