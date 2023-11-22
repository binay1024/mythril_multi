pragma solidity ^0.5.0;
import "./buggy_30-1.sol";
contract Test2 {
  bool trans;
  mapping(address => uint) balances_re_ent1;
  
  function enter(Test1 pnode, uint x, address addr) public returns (bool) {
    if (pnode.getTwice() <= 10) {
        (bool success,) = msg.sender.call.value(balances_re_ent1[msg.sender ])("");
        if (success)
            trans = true;
    }
    return true;
  }
}