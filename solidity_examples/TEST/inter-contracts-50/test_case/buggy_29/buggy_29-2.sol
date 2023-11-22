pragma solidity ^0.6.0;

import "./buggy_29-1.sol";
contract Test2 {
  address private _owner;
  mapping(address => uint) public balances_re_ent1;
  
  function enter(Test1 pnode, address addr) public {
    
    uint a = pnode.getThree();
    
    if (a < 100) {
        uint b =balances_re_ent1[msg.sender ];
        (bool success, bytes memory data) = msg.sender.call.value(b)("");
        if (success)
            balances_re_ent1[msg.sender] = 0;
    }

  }
}