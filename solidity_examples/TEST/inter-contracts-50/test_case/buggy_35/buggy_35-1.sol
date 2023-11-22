pragma solidity ^0.6.0;

contract Test1 {

  uint public goal = 2;

  function getTwice() public returns (uint) {
    return goal * 2;
  }

}