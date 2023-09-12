// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Victim1{
    uint public num;
    address public sender;
    uint public value; 

    function attacked(uint a, address b) public payable{
        (bool sucess, bytes memory data) = address(msg.sender).call{value: 1 ether}("");
    }

    fallback() external payable{

    }
}
