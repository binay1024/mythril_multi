// Contract A
pragma solidity ^0.8.0;

contract ContractA is ContractB {
    uint256 public valueInContractA;

    function setValueInContractA(uint256 _value) public {
        valueInContractA = _value;
    }
}

// Contract B
pragma solidity ^0.8.0;

contract ContractB {
    uint256 public value;

    function setValue(uint256 _value) public {
        value = _value;
    }
}

