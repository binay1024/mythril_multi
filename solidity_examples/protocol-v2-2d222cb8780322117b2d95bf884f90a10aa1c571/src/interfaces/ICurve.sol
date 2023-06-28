// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ICurve {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
    function derivatives(uint256) external view returns (address);
}
