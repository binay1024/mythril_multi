pragma solidity ^0.8.0;

import "./Receiver.sol";

contract Sender {
    function sendEtherUsingSend(address payable _receiver) public payable {
        bool success = _receiver.send(msg.value);
        require(success, "Send failed");
    }

    function sendEtherUsingTransfer(address payable _receiver) public payable {
        _receiver.transfer(msg.value);
    }

    function sendEtherUsingCallValue(address payable _receiver) public payable {
        (bool success, ) = _receiver.call{value: msg.value}("");
//        (bool success, ) = _receiver.call.value(msg.value)("");   Old syntax (Solidity < 0.7.0)
        require(success, "Send failed");
    }
}
