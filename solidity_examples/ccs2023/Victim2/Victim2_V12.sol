// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;


contract Victim2{

    Victim2_support public rewardAccount;
    uint public closingTime;
    uint public minTokensToCreate;
    uint constant creationGracePeriod = 40 days;
    uint256 public totalSupply;
    mapping (address => uint) public paidOut;
    mapping (address => uint) public paid;

    constructor(uint _closingTime) public {
        
        rewardAccount = new Victim2_support(address(this));
        if(address(rewardAccount) == address(0)){
            revert();
        }

        closingTime = _closingTime;
    }

    function () external payable {
        bool a = false;
        if (block.timestamp < closingTime + creationGracePeriod){
            a =  createTokenProxy(msg.sender);
        }
        if (!a){
            revert();
        }
    }

    function createTokenProxy(address _tokenHolder) internal returns (bool success) {
        if (block.timestamp < closingTime 
            && msg.value > 0
            ) {
            totalSupply += msg.value/2;
            if (totalSupply >= minTokensToCreate) {
                (bool sucess, bytes memory data) = address(rewardAccount).call.value(msg.value/2)("");
                if(!sucess){
                    revert();
                }
            }
            paid[_tokenHolder]+=totalSupply;
            return true;
        }
        return false;
    }

    function withdrawRewardFor() external returns (bool _success) {

        if (paid[msg.sender] == 0){
            revert();
        }

        uint reward = 0.000001 ether;

        // 这种写法有点问题哦
        // if (!rewardAccount.payOut(msg.sender, reward))
        //     revert();
        
        bool sucess = rewardAccount.payOut(msg.sender, reward);
        if(!sucess){
            revert();
        }

        paidOut[msg.sender] += reward;

        return true;
    }
}

contract Victim2_support{
    address public owner;
    uint public accumulatedInput;


    constructor (address owner_) public {
        owner = owner_;
    }

    function() external payable{
        accumulatedInput += msg.value;
    }

    function payOut(address _recipient, uint _amount) public payable returns (bool){
        
        if (msg.sender!= owner || msg.value > 0){
            revert();
        }

        (bool sucess, bytes memory data) = address(_recipient).call.value(_amount)("");
        if (!sucess){
            revert();
        }
        return sucess;
    }

}
