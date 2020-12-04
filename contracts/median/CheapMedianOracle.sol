// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;
import "../chainlink/ChainlinkOracle.sol";
import "../compound/CompoundOpenOracle.sol";
import "../uniswap/UniswapV2TWAPOracle.sol";
import "./Median.sol";


/**
 * @title CheapMedianOracleUSM
 * @author Jacob Eliosoff (@jacob-eliosoff)
 * @notice MedianOracle that uses inheritance to save gas
 */
contract CheapMedianOracle is ChainlinkOracle, CompoundOpenOracle, UniswapV2TWAPOracle {
    uint private constant NUM_UNISWAP_PAIRS = 3;

    uint private savedPrice;

    constructor(
        AggregatorV3Interface chainlinkAggregator,
        UniswapAnchoredView compoundView,
        IUniswapV2Pair uniswapPair, uint uniswapToken0Decimals, uint uniswapToken1Decimals, bool uniswapTokensInReverseOrder
    ) public
        ChainlinkOracle(chainlinkAggregator)
        CompoundOpenOracle(compoundView)
        UniswapV2TWAPOracle(uniswapPair, uniswapToken0Decimals, uniswapToken1Decimals, uniswapTokensInReverseOrder) {}

    function latestPrice() public virtual override(ChainlinkOracle, CompoundOpenOracle, UniswapV2TWAPOracle)
        view returns (uint price)
    {
        price = (savedPrice != 0) ? savedPrice : Median.median(
            ChainlinkOracle.latestPrice(),
            CompoundOpenOracle.latestPrice(),
            UniswapV2TWAPOracle.latestPrice()
        );
    }

    function cacheLatestPrice() public virtual override(Oracle, UniswapV2TWAPOracle) returns (uint price) {
        price = (savedPrice != 0) ? savedPrice : Median.median(
            ChainlinkOracle.latestPrice(),              // Not ideal to call latestPrice() on two of these
            CompoundOpenOracle.latestPrice(),           // and cacheLatestPrice() on one...  But works, and
            UniswapV2TWAPOracle.cacheLatestPrice()
        ); // inheriting them like this saves significant gas
    }
}
