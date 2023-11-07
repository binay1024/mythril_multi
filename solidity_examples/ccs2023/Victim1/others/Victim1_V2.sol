// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Victim1{
    uint private num;
    address private sender;
    uint private value; 

    function attacked(uint a, address b) public payable{
        (bool sucess, bytes memory data) = address(msg.sender).call{value: 1 ether}("");
        if (!sucess){
            revert();
        }

    }
    
    fallback() external payable{

    }
}