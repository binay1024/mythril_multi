pragma solidity ^0.5.0;

contract Test1 {
  uint public goal = 2;
  function getTwice() public returns (uint) {
    return goal * 2;
  }
}
