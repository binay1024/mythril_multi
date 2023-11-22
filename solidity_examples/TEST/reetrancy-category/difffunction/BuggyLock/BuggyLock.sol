pragma solidity ^0.6.0;


abstract contract VulnBank {
    function getBalance(address a) virtual public returns(uint);
    function deposit() virtual public payable; 
    function transfer(address to, uint amount) virtual public; 
    function withdrawBalance() virtual public; 
}


contract VulnBankBuggyLock is VulnBank {

    mapping (address => uint) private userBalances;
    mapping (address => bool) private disableWithdraw;

    function getBalance(address a) override public returns(uint) {
        return userBalances[a];
    }

    // Tx 1
    function deposit() public override payable {
        userBalances[msg.sender] += msg.value;
    }
    // Tx 2-2 stolen
    // reentrancy attacker can use fallback to allow userBalances[other guy] + balance
    // then all the execution finish set his balance 0, then he and some guy all get money
    function transfer(address to, uint amount) override public {
        if (userBalances[msg.sender] >= amount) {
            userBalances[to] += amount;
            userBalances[msg.sender] -= amount;
        }
    }

    // Tx 2-1
    function withdrawBalance() override public {
        require(disableWithdraw[msg.sender] == false);

        uint amountToWithdraw = userBalances[msg.sender];
        
        if (amountToWithdraw > 0) {
            disableWithdraw[msg.sender] = true;
            msg.sender.call.value(amountToWithdraw)("");
            disableWithdraw[msg.sender] = false;

            userBalances[msg.sender] = 0;
        }
    }
}