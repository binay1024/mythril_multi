// Contract A
contract ContractA {
    ContractB public contractB;

    constructor(address _contractBAddress) {
        contractB = ContractB(_contractBAddress);
    }

    function getValueFromContractB() public view returns (uint256) {
        return contractB.getValue();
    }
}

// Contract B
contract ContractB {
    uint256 public value = 123;

    function getValue() public view returns (uint256) {
        return value;
    }
}

