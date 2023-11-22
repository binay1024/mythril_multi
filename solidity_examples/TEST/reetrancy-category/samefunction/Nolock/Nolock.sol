pragma solidity ^0.6.0;


abstract contract VulnBank {
    function getBalance(address a) virtual public returns(uint);
    function deposit() virtual public payable; 
    function transfer(address to, uint amount) virtual public; 
    function withdrawBalance() virtual public; 
}

contract VulnBankNoLock is VulnBank {

    mapping (address => uint) private userBalances;

    function getBalance(address a) override public returns(uint) {
        return userBalances[a];
    }

    function deposit() override public payable {
        userBalances[msg.sender] += msg.value;
    }

    function transfer(address to, uint amount) override public {
        if (userBalances[msg.sender] >= amount) {
            userBalances[to] += amount;
            userBalances[msg.sender] -= amount;
        }
    }

    function withdrawBalance() override public {
        uint amountToWithdraw = userBalances[msg.sender];
        
        if (amountToWithdraw > 0) {
            msg.sender.call.value(amountToWithdraw)("");

            userBalances[msg.sender] = 0;
        }
    }
}