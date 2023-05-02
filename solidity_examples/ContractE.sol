// Contract E
pragma solidity ^0.8.0;

import "./ContractB.sol";

contract ContractE {
    ContractB public contractB;
    bytes32 public constant salt = keccak256("some_salt");


    constructor() {
        bytes memory bytecode = type(ContractB).creationCode;
        assembly {
            let bAddress := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(bAddress)) {
                revert(0, 0)
            }
            sstore(contracrtB.slot, bAddress)
        }
    }

    function setValueInContractB(uint256 _value) public {
        contractB.setValue(_value);
    }
}
