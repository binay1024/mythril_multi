pragma solidity ^0.5.0;

contract Test1 {
  uint public goal = 100;
  function getPulse() public returns (uint) {
    return goal * goal;
  }
}

