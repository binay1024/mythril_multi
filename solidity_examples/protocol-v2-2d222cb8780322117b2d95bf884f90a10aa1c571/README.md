# DFX Protocol V2

A decentralized foreign exchange protocol optimized for stablecoins.

[![Discord](https://img.shields.io/discord/786747729376051211.svg?color=768AD4&label=discord&logo=https%3A%2F%2Fdiscordapp.com%2Fassets%2F8c9701b98ad4372b58f13fd9f65f966e.svg)](http://discord.dfx.finance/)
[![Twitter Follow](https://img.shields.io/twitter/follow/DFXFinance.svg?label=DFXFinance&style=social)](https://twitter.com/DFXFinance)

## Overview

DFX v2 is an update from DFX protocol v0.5 with some additional features including the protocol fee, which is set by the percentage of the platform fee(which incurs for each swap on all the pools across the platform), fixing issues of invariant check, and the support of flashloans. The major change from the previous version is, V2 is more generalized for users, meaning anybody can create their curves(pools) while V0.5 only allowed the DFX team to create pools.

There are two major parts to the protocol: **Assimilators** and **Curves**. Assimilators allow the AMM to handle pairs of different value while also retrieving reported oracle prices for respective currencies. Curves allow the custom parameterization of the bonding curve with dynamic fees, halting bounderies, etc.

### Assimilators

Assimilators are a key part of the protocol, it converts all amounts to a "numeraire" which is essentially a base value used for computations across the entire protocol. This is necessary as we are dealing with pairs of different values. **AssimilatorFactory** is responsible for deploying new AssimilatorV2.

Oracle price feeds are also piped in through the assimilator as they inform what numeraire amounts should be set. Since oracle price feeds report their values in USD, all assimilators attempt to convert token values to a numeraire amount based on USD.

### Curve Parameter Terminology

High level overview.

| Name      | Description                                                                                               |
| --------- | --------------------------------------------------------------------------------------------------------- |
| Weights   | Weighting of the pair (only 50/50)                                                                        |
| Alpha     | The maximum and minimum allocation for each reserve                                                       |
| Beta      | Liquidity depth of the exchange; The higher the value, the flatter the curve at the reported oracle price |
| Delta/Max | Slippage when exchange is not at the reported oracle price                                                |
| Epsilon   | Fixed fee                                                                                                 |
| Lambda    | Dynamic fee captured when slippage occurs                                                                 |

In order to prevent anti-slippage being greater than slippate, DFX V2 requires deployers to set Lambda to 1(1e18).

For a more in-depth discussion, refer to [section 3 of the shellprotocol whitepaper](https://github.com/cowri/shell-solidity-v1/blob/master/Shell_White_Paper_v1.0.pdf)

### Major changes from the Shell Protocol

The main changes between V2 and the original code can be found in the following files:

- All the assimilators
- `AssimilatorV2.sol`
- `CurveFactoryV2.sol`
- `CurveMath.sol`
- `ProportionalLiquidity.sol`
- `Swaps.sol`
- `Structs.sol`

#### Different Valued Pairs

In the original implementation, all pools are assumed to be baskets of like-valued tokens. In our implementation, all pools are assumed to be pairs of different-valued FX stablecoins (of which one side is always USDC).

This is achieved by having custom assimilators that normalize the foreign currencies to their USD counterparts. We're sourcing our FX price feed from chainlink oracles. See above for more information about assimilators.

Withdrawing and depositing related operations will respect the existing LP ratio. As long as the pool ratio hasn't changed since the deposit, amount in ~= amount out (minus fees), even if the reported price on the oracle changes. The oracle is only here to assist with efficient swaps.

#### Flashloans
Flashloans live in every curve contract produced by the CurveFactory. DFX curve flash function is based on the the flashloan model in UniswapV2. The user calling flash function must conform to the `IFlash.sol` interface. It must containing their own logic along with code to return the correct amount of tokens requested along with its respective fee. Flash function will check for the balances of the curve before and after to ensure that the correct amount of fees has been sent to the treasury as well as funds returned back to the curve. 

## Third Party Libraries

- [Openzeppelin contracts (v3.3.0)](https://github.com/OpenZeppelin/openzeppelin-contracts/releases/tag/v3.3.0)
- [ABDKMath (v2.4)](https://github.com/abdk-consulting/abdk-libraries-solidity/releases/tag/v2.4)
- [Shell Protocol@48dac1c](https://github.com/cowri/shell-solidity-v1/tree/48dac1c1a18e2da292b0468577b9e6cbdb3786a4)


## Test Locally
1. Install Foundry

   - [Foundry Docs](https://jamesbachini.com/foundry-tutorial/)

2. Download all dependencies. 
    ```
    forge install
    ```
2. Run Ethereum mainnet forked testnet on your local in one terminal:

   ```
   anvil -f https://mainnet.infura.io/v3/<INFURA KEY> --fork-block-number 15129966
   ```

3. In another terminal, run V2 test script:

   ```
   forge test --match-contract V2Test -vvv -f http://127.0.0.1:8545
   ```

4. Run Protocol Fee test:

    ```
    forge test --match-contract ProtocolFeeTest -vvv -f http://127.0.0.1:8545
    ```

## Test Cases
### ```V2.t.sol```
1. testDeployTokenAndSwap

    - deploy a random erc20 token (we call it `gold` token) and it's price oralce (`gold oracle`), gold : usdc ratio is set to 1:20 in the test
    - deploy a new curve from Curve Factory
    - try swaps back and forth between `gold` and `usdc`
    - in each swap, usdc and gold swap in and out amount are correct based on the gold oracle's price

2. testForeignStableCoinSwap
    
    - test uses the EURC and CADC tokens deployed on the ethereum mainnet
    - this test is to ensure deploying curves by curveFactoryV2 doesn't break any stable swap features from the previous version

3. testTotalSupply

    - this test has nothing to do with V2 update
    - in the test, we directly transfer erc20 tokens to the curve without calling deposit function
    - the test ensures total supply of curve lpt remains unchanged when tokens are transferred directly to the curve
4. testSwapDifference

    - this test is to ensure there is no anti-slippage occurred
    - We frist swap relatively large amount of token(saying from token A to token B) to change the pool ratio
    - we swap back all output amount of B to A
    - this test ensures the user gets all of his original A amount except the fee
5. testInvariant

    - this test ensures anybody can deposit any amount of LPs to the curve
### ```ProtocolFee.t.sol```
1. testProtocolFeeUsdcCadcSwap

    - For each trade on DFX, platform fee is applied, it is set by Epsilon when deploying the curve
    - platform fee is splitted into 2 parts, some of the fee is sent back to the pool, while rest amount is sent to the protocol's treasury address (we call this `protocol fee`)
    - `protocol fee` is calculated by the following formular
    ```
    protocol fee = platform fee * CurveFactoryV2.protocolFee / 100000
    ```
    if protocolFee is set to 50,000 (50% because of 6 decimal places), then the platform fee is divided evenly to the treasury & curve
### ```Router.t.sol```
1. testTargetSwap
    - Swaps a dynamic origin amount for a fixed target amount
    - this test checks if the swapped amount is correct within 99% accuracy by multiplying the requested amount at the foriegn exchange rate pulled from chainlink oracles
    - the test is repeated for trading unlike pairs to test their varying decimal places such as CADC -> XSGD, CADC -> EUROC, CADC -> USDC etc. as well as run through extensive fuzzing

2. testOriginSwap
    - Swaps a fixed origin amount for a dynamic target amount
    - this test checks if the swapped amount is correct within 99% accuracy by multiplying the requested amount at the foriegn exchange rate pulled from chainlink oracles
    - the test is repeated for trading unlike pairs to test their varying decimal places such as CADC -> XSGD, CADC -> EUROC, CADC -> USDC etc. as well as run through extensive fuzzing

### ```Flashloan.t.sol```
1. testFlashloan
    - this test ensures the correct amount of stablecoins requested to be flashloaned from any DFX curves is correctly transfered to the contract calling the `flash` function
    - it also checks the correct amount of fees owed proportional to the epsilon value within the curve mutiplied by the amount borrowed is sent directly to the treasury
    - last sanity check is to check that the balance of USDC and the respective foreign stablecoin in the pool is equal or greater than before the flashloan was conducted 
    - the test is repeated for already exisiting stablecoins including CADC, EUROC, XSGD to test their varying decimal places as well as run through extensive fuzzing

2. testFail_FlashloanFee
    - this tests fails upon a user calling the flash function and does not have enough funds to pay back the original loan including fees
    - the test is repeated for already exisiting stablecoins including CADC, EUROC, XSGD to test their varying decimal places as well as run through extensive fuzzing

3. testFail_FlashloanCurveDepth
    - this tests fails upon a user calling the flash function and the curve not having enough funds to lend to the user
    - the test is repeated for already exisiting stablecoins including CADC, EUROC, XSGD to test their varying decimal places as well as run through extensive fuzzing

### ```CurveFactoryV2.t.sol```
1. testFailDuplicatePairs
    - this test ensures already exisiting pairs cannot be added to avoid duplicates

2. testNewPairs
    - this test ensures that new pairs can be properly added as long as they dont already exist

3. testUpdateFee
    - this test ensures protocol fee can be updated properly as long as it is within the correct range of 0 to 100% in 6 decimals

4. testFailUpdateFee
    - this test ensures trying to update the protocol fee to a new fee higher than 100% will revert in 6 decimals

5. testUpdateTreasury
    - this test ensures the protocol treasury address can be updated properly to a new address
