// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;


contract SubSC{
    mapping (address => uint256) public token;
    address public  _owner;

    constructor(address owner){
        // _owner = abi.decode(owner, (address));
        _owner = owner;
    }
    
    fallback() external payable {
        
        token[msg.sender] += msg.value;
    }

    // function bytesToUint256(bytes memory input) public pure returns (uint256) {
    //     return abi.decode(input, (uint256));
    // }
    function payout(address to, uint256 value) external payable returns (bool){
        
        if (msg.sender != _owner || msg.value > 0 ){
            revert();
        }
        if (address(this).balance > value){
            (bool success, bytes memory m) = address(to).call{value:value}("");
            if (!success){
                revert();
            }
            return true;
        }
    }

}

contract TestStore {

    mapping (address => uint256) public token;
    mapping (address => bool) public Secondtoken;
    bool thirdcon;

    SubSC public subcontract;

    constructor(){
        subcontract = new SubSC(address(this));
    }

    fallback() external payable {
        if (msg.value > 2 ether){
            address(subcontract).call{value:msg.value/2}("");
            token[msg.sender] += msg.value/2;
        }
        else{
            token[msg.sender] += msg.value;
        }
        
    }

    // Tx == 3, multi case ***************************************************************************

    function secondCondition() public payable {
        if (token[msg.sender]<=0){
            revert();
        }
        if (msg.value > 0 ){
            Secondtoken[msg.sender] = true;
            token[msg.sender] += msg.value;
        }
    }
    function refund(uint256 tvalue) payable public {
        // 有没有一种情况 条件反正都满足了, 但是 token 少于 5? 但是这都包含在路径内吧.
        if (token[msg.sender]>tvalue && tvalue>0 && Secondtoken[msg.sender] ){
            if (!subcontract.payout(msg.sender, 5 ether)){
                revert();
            }
            // if (!success){
            //     revert();
            // }
            token[msg.sender] -= 5 ether;
        }
    }
    
    // TX == 2 case ***************************************************************************
    // function refund(uint256 tvalue) public {
    //     if (token[msg.sender]>tvalue && tvalue>0){
    //         (bool success, bytes memory m) = address(msg.sender).call{value:tvalue}("");
    //         if (!success){
    //             revert();
    //         }
    //         token[msg.sender] -= tvalue;
    //     }
    // }

    // TX == 3 case ***************************************************************************
    // function secondCondition() public payable {
    //     if (token[msg.sender]<=0){
    //         revert();
    //     }

    //     if (msg.value > 0 ){
    //         Secondtoken[msg.sender] = true;
    //         token[msg.sender] += msg.value;
    //     }
    // }
    // function refund(uint256 tvalue) public {
    //     if (token[msg.sender]>tvalue && tvalue>0 && Secondtoken[msg.sender] ){
    //         (bool success, bytes memory m) = address(msg.sender).call{value:tvalue}("");
    //         if (!success){
    //             revert();
    //         }
    //         token[msg.sender] -= tvalue;
    //     }
    // }

    // TX == 4 case ***************************************************************************
    // function thirdCond() public {
    //     if (token[msg.sender]>0 && Secondtoken[msg.sender]){
    //         thirdcon = true;
    //     }
    // }

    // function secondCondition() public payable {
    //     if (token[msg.sender]<=0){
    //         revert();
    //     }

    //     if (token[msg.sender] == 5){
    //         Secondtoken[msg.sender] = true;
    //         token[msg.sender] += msg.value;
    //     }
    // }

    // function refund(uint256 tvalue) public {

    //     if (token[msg.sender]>tvalue && tvalue>0 && Secondtoken[msg.sender] && thirdcon ){
    //         (bool success, bytes memory m) = address(msg.sender).call{value:tvalue}("");
    //         if (!success){
    //             revert();
    //         }
    //         token[msg.sender] -= tvalue;
    //     }
    // }

    

}
