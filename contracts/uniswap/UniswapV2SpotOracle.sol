// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../Oracle.sol";
import "./UniswapTools.sol";


/// @dev Oracle on the Uniswap spot price for a given pair
/// @notice The spot price is easily manipulable and not fit to use as an oracle in most cases.
/// It's included here for educational purposes and not intended to be used for any serious purpose.
/// If you wish to obtain prices from Uniswap, use a TWAP instead.
contract UniswapV2SpotOracle is Oracle {
    using SafeMath for uint;

    UniswapTools.Pair private pair;

    /**
     *  Example pairs to pass in:
     *  ETH/USDT: 0x0d4a11d5eeaac28ec3f61d100daf4d40471f1852, false, 18, 6 (WETH reserve is stored w/ 18 dec places, USDT w/ 18)
     *  USDC/ETH: 0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc, true, 6, 18 (USDC reserve is stored w/ 6 dec places, WETH w/ 18)
     *  DAI/ETH: 0xa478c2975ab1ea89e8196811f51a7b7ade33eb11, true, 18, 18 (DAI reserve is stored w/ 18 dec places, WETH w/ 18)
     */
    constructor(IUniswapV2Pair uniswapPair, uint token0Decimals, uint token1Decimals, bool tokensInReverseOrder) public
    {
        pair = UniswapTools.createPair(uniswapPair, token0Decimals, token1Decimals, tokensInReverseOrder);
    }

    /**
     * @notice Retrieve the latest spot price of the price oracle.
     * @return price
     */
    function latestPrice() public virtual override view returns (uint price) {
        price = UniswapTools.spotPrice(pair);
    }

    /**
     * @notice Retrieve the latest spot price of the price oracle, in its original format.
     * @return price
     */
    function latestUniswapSpotPrice() public view returns (uint price) {
        price = UniswapTools.spotPrice(pair);
    }
}
