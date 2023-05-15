// SPDX-License-Identifier: GPL-3.0
// 情况四 由于是内部自己创建的合约所以 有固定的地址值 所以有 callee_account

// Contract C
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
