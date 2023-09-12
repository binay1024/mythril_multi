// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;




contract AttackBridge{
    
    bytes4 private func_sig;
    bytes32 private call_data_list;
    uint32 private func_sig_re;
    uint private flag;



    constructor (uint32 func_sig_) public {
    }
   
    function attack1(uint num_, bytes4 func_sig_,  bytes32 call_data_1) public {
       
    }
    function attack0(uint num_, bytes4 func_sig_) public {
    }
    function call_ (address addr_, bytes4 sig) private returns (bool){
       
    }
   
    fallback () external {
    }
}