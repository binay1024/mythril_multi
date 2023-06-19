// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract TestStore {

    mapping (address => uint256) token;
    mapping (address => bool) Secondtoken;
    bool thirdcon;

    fallback() external payable {
        token[msg.sender] = msg.value;
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
    function thirdCond() public {
        if (token[msg.sender]>0 && Secondtoken[msg.sender]){
            thirdcon = true;
        }
    }

    function secondCondition() public payable {
        if (token[msg.sender]<=0){
            revert();
        }

        if (token[msg.sender] == 5){
            Secondtoken[msg.sender] = true;
            token[msg.sender] += msg.value;
        }
    }

    function refund(uint256 tvalue) public {

        if (token[msg.sender]>tvalue && tvalue>0 && Secondtoken[msg.sender] && thirdcon ){
            (bool success, bytes memory m) = address(msg.sender).call{value:tvalue}("");
            if (!success){
                revert();
            }
            token[msg.sender] -= tvalue;
        }
    }

}
