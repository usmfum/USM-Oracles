# USM - Oracles

Collection of smart contracts pulling oracle data from several sources.

- Chainlink: AggregatorV3Interface
- Compound: UniswapAnchoredView (OpenOracle)
- MakerDAO: MakerMedianizer
- Uniswap: Spot Price
- Uniswap: TWAP (Time Weighted Average Price)

Plus a simple Median library and implementations of medianized oracle integrations.

- MedianOracle: Median of 3 arbitrary oracles using the Oracle interface.
- UniswapMedianSpotOracle: Median of 3 uniswap pair spot prices.
- UniswapMedianTWAPOracle: Median of 3 uniswap pair TWAP prices.
- CheapMedianOracle: The implementation chosen for USM. Optimal gas use for a Chainlink, Compound and Uniswap TWAP Median.



