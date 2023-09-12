// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract AttackBridge{
    // uint32 private counter;
    // address private last_caller_addr;
    bytes4 private func_sig;
    bytes32 private call_data_list;
    uint32 private func_sig_re;
    // address private owner;
    uint private flag;
    bytes32 private temp;


    constructor(uint32 func_sig_, bytes32 a) public {
      
    }
    
    // function set_func_sig(string memory func_sig_) public {
    //     func_sig = func_sig_;
    // }
    // function set_call_addr(address addr_) public {
    //     victim_addr = addr_;
    // }

    // 满足 call 的 地址是符号型的, sig 是符号型的 value 也是符号型的. 
   
    function attack1(uint num_, bytes4 func_sig_,  bytes32 call_data_1) public {
       
    }
    function attack0(uint num_, bytes4 func_sig_) public {
       
    }
    function call_ (address addr_, bytes4 sig) private returns (bool){
        
       
    }
    
    fallback () external {
      
    }
}