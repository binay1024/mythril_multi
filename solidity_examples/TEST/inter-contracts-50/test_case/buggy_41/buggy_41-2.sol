pragma solidity ^0.6.0;


import "./buggy_41-1.sol";
contract Test2 {

    bool private not_called_re_ent41 = true;
  
    function enter(address p, uint x, address addr) public returns (bool) {
        
        Test1 pnode = Test1(p);
        uint d = pnode.getTwice();

        if (d == 100) {
            if (!not_called_re_ent41){
                revert();
            }
            (bool success, ) = msg.sender.call.value(x)("");

            if (!success) {
                revert();
            }
            not_called_re_ent41 = false;
        }

        return not_called_re_ent41;
    }
}