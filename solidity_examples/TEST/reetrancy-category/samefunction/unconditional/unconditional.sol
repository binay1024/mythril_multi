pragma solidity ^0.6.0;

contract VulnBank {

    mapping (address => uint) private userBalances;

    function getBalance(address a) public view returns(uint) {
        return userBalances[a];
    }

    function deposit() public payable {
        userBalances[msg.sender] += msg.value;
    }

    function withdrawAll() public {
        uint amountToWithdraw = userBalances[msg.sender];
       
        msg.sender.call.value(amountToWithdraw)("");

        userBalances[msg.sender] = 0;
    }
}

