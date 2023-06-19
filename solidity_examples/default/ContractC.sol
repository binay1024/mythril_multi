// Contract A
pragma solidity ^0.8.0;

import "./ContractB.sol";

contract ContractC {
    ContractB public contractB;

    constructor() {
        contractB = new ContractB();
    }

    function setValueInContractB(uint256 _value) public {
        contractB.setValue(_value);
    }
}
