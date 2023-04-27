// Contract A
contract ContractA {
    ContractB public contractB;

    constructor(address _contractBAddress) {
        contractB = ContractB(_contractBAddress);
    }

    function changeValueInContractB() public {
        contractB.changeValue();
    }
}

// Contract B
contract ContractB {
    uint256 public value = 123;

    function changeValue() public {
        value = value + 1;
    }
}

