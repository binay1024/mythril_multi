pragma solidity ^0.5.0;

contract Test1 {
  uint public goal = 1000;
  function getTwice() public returns (uint) {
    return goal * 2;
  }
}

