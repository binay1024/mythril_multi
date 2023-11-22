pragma solidity ^0.6.0;

contract Test1 {
  uint public goal = 33;
  function getThree() public returns (uint) {
    return goal * 3;
  }
}

