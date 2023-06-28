// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/ICurveFactory.sol";
import "./interfaces/IOracle.sol";

struct OriginSwapData {
    address _origin;
    address _target;
    uint256 _originAmount;
    address _recipient;
    address _curveFactory;
}

struct TargetSwapData {
    address _origin;
    address _target;
    uint256 _targetAmount;
    address _recipient;
    address _curveFactory;
}

struct SwapInfo {
    int128 totalAmount;
    int128 totalFee;
    int128 amountToUser;
    int128 amountToTreasury;
    int128 protocolFeePercentage;
    address treasury;
    ICurveFactory curveFactory;
}

struct CurveInfo {
    string _name;
    string _symbol;
    address _baseCurrency;
    address _quoteCurrency;
    uint256 _baseWeight;
    uint256 _quoteWeight;
    IOracle _baseOracle;
    uint256 _baseDec;
    IOracle _quoteOracle;
    uint256 _quoteDec;
    uint256 _alpha;
    uint256 _beta;
    uint256 _feeAtHalt;
    uint256 _epsilon;
    uint256 _lambda;
}
