// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

contract Victim1{
    uint256 private num;
    address private sender;
    uint256 private value; 

    function attacked(uint256 a, address b) public returns (bool) {
        if (address(this).balance < a ){
            revert();
        }
        (bool scuess, bytes memory data) = address(msg.sender).call.value(a)("");
        if (!scuess){
            revert();
        }
        return true;
    }
    
    function() external {
        // return true;
    }
}