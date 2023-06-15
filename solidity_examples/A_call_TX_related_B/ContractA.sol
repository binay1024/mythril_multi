// SPDX-License-Identifier: GPL-3.0
// 情况二: callee_account 地址 是符号型的, 并且取决于用户输入


// Contract A
pragma solidity ^0.8.0;

import "./ContractB.sol";

contract ContractA {
    ContractB public contractB;
    uint public temp = 0;

    constructor(address _contractBAddress) {
        contractB = ContractB(_contractBAddress);
    }

    function setValueInContractB(address addr, uint256 _value) public {
        contractB.setValue(addr, _value);
        temp += 1;
    }
}
