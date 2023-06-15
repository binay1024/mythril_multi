// Contract B
pragma solidity ^0.8.0;

contract ContractB {
    uint256 public value;
    address public fixed_address;
    uint256 statevar;

    function setValue(address addr, uint256 _value) public {
        fixed_address = addr;
        value = _value;
        fixed_address.call{value: _value}("");
        statevar = 0;
    }
}
