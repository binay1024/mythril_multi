// Contract D
pragma solidity ^0.8.0;

import "./ContractB.sol";

contract ContractD {
    ContractB public contractB;

    constructor() {
        bytes memory bytecode = type(ContractB).creationCode;
        assembly {
            let bAddress := create(0, add(bytecode, 0x20), mload(bytecode))
            if iszero(extcodesize(bAddress)) {
                revert(0, 0)
            }
            sstore(contractB.slot, bAddress)
        }
    }

    function setValueInContractB(uint256 _value) public {
        contractB.setValue(_value);
    }
}
