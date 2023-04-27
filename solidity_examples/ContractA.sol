// Contract A
pragma solidity ^0.8.0;

import "./ContractB.sol";

contract ContractA {
    ContractB public contractB;

    constructor(address _contractBAddress) {
        contractB = ContractB(_contractBAddress);
    }

    function setValueInContractB(uint256 _value) public {
        contractB.setValue(_value);
    }
}
