// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract TestStore {

    mapping (address => uint256) token;

    fallback() external payable {
        token[msg.sender] = msg.value;
    }


    function refund(uint256 tvalue) public {
        if (token[msg.sender]>tvalue && tvalue>0){
            (bool success, bytes memory m) = address(msg.sender).call{value:tvalue}("");
            if (!success){
                revert();
            }
            token[msg.sender] -= tvalue;
        }
    }

}
