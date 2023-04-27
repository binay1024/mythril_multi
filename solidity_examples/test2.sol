// Contract A
contract ContractA {
    ContractB public contractB;

    constructor(address _contractBAddress) {
        contractB = ContractB(_contractBAddress);
    }

    function setValueInContractB(uint256 _value) public {
        contractB.setValue(_value);
    }
}

// Contract B
contract ContractB {
    uint256 public value;

    function setValue(uint256 _value) public {
        value = _value;
    }
}

