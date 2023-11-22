pragma solidity ^0.6.0;


contract Token {


    mapping (address => uint) tokenBalance;
    mapping (address => uint) etherBalance;
    uint currentRate;

    constructor() public {

        currentRate = 2;
    }

    // function getTokenCountFor(address x) public view returns(uint) {
    //     return tokenBalance[x];
    // }
    // function getEtherCountFor(address x) public view returns(uint) {
    //     return etherBalance[x];
    // }
    
    // function getTokenCount() public view returns(uint) {
    //     return tokenBalance[msg.sender];
    // }

    function depositEther() public payable {
        if (msg.value > 0) { etherBalance[msg.sender] += msg.value; }
    }

    function exchangeTokens(uint amount) public {
        if (tokenBalance[msg.sender] >= amount) {
            uint etherAmount = amount * currentRate;
            etherBalance[msg.sender] += etherAmount;
            tokenBalance[msg.sender] -= amount;
        }
    }
    // TX-1 需要调用这个 并且给他打钱， 这样拥有 etherBalance 和 tokenBalance
    function exchangeEther(uint amount) public payable {
        etherBalance[msg.sender] += msg.value;
        if (etherBalance[msg.sender] >= amount) {
            uint tokenAmount = amount / currentRate;
            etherBalance[msg.sender] -= amount;
            tokenBalance[msg.sender] += tokenAmount;
        }
    }
    function transferToken(address to, uint amount) public {
        if (tokenBalance[msg.sender] >= amount) {
            tokenBalance[to] += amount;
            tokenBalance[msg.sender] -= amount;
        }
    }
    

    function exchangeAndWithdrawToken(uint amount) public {
        if (tokenBalance[msg.sender] >= amount) {
            uint etherAmount = tokenBalance[msg.sender] * currentRate;
            tokenBalance[msg.sender] -= amount;

            msg.sender.transfer(etherAmount);
        }
    }
    // TX-2 在调用这个函数
    // Function vulnerable to re-entrancy attack
    function withdrawAll() public {
        uint etherAmount = etherBalance[msg.sender];
        uint tokenAmount = tokenBalance[msg.sender];
        if (etherAmount > 0 && tokenAmount > 0) {
            uint e = etherAmount + (tokenAmount * currentRate);

    
            etherBalance[msg.sender] = 0;


            msg.sender.call.value(e)("");


            tokenBalance[msg.sender] = 0;
        }
    }
}


