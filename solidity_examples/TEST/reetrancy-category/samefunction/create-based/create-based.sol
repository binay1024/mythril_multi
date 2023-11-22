pragma solidity ^0.6.0;

abstract contract IntermediaryCallback {
    function registerIntermediary(address payable what) public virtual payable;

}

contract Intermediary {

    address owner;
    Bank bank;
    uint amount;

    constructor(Bank _bank, address _owner, uint _amount) public {

        owner = _owner;
        bank = _bank;
        amount = _amount;

        IntermediaryCallback(_owner).registerIntermediary(address(this));
    }

    function withdraw() public {
        if (msg.sender == owner) {
            msg.sender.transfer(amount);
        }
    }
    
    fallback () payable external {}
}

contract Bank {
    mapping (address => uint) balances;
    mapping (address => Intermediary) subs;

    function getBalance(address a) public view returns(uint) {
        return balances[a];
    }

    function withdraw(uint amount) public {
        if (balances[msg.sender] >= amount) {

            subs[msg.sender] = new Intermediary(this, msg.sender, amount);

            balances[msg.sender] -= amount;
            address(subs[msg.sender]).transfer(amount);
        }
    }
    
    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }
}
