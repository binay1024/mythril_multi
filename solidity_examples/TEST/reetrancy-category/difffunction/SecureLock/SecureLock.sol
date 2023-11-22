pragma solidity ^0.6.0;


abstract contract VulnBank {
    function getBalance(address a) virtual public returns(uint);
    function deposit() virtual public payable; 
    function transfer(address to, uint amount) virtual public; 
    function withdrawBalance() virtual public; 
}

contract VulnBankSecureLock is VulnBank {

    mapping (address => uint) private userBalances;
    mapping (address => bool) private disableWithdraw;

    function getBalance(address a) override public returns(uint) {
        return userBalances[a];
    }

    function deposit() public override payable {
        require(disableWithdraw[msg.sender] == false);

        userBalances[msg.sender] += msg.value;
    }

    function transfer(address to, uint amount) override public {
        require(disableWithdraw[msg.sender] == false);

        if (userBalances[msg.sender] >= amount) {
            userBalances[to] += amount;
            userBalances[msg.sender] -= amount;
        }
    }

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