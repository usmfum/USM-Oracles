// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../Oracle.sol";
import "./UniswapTools.sol";

/**
 * @dev Retrieve time weighted average prices from an Unisap pair
 */
contract UniswapV2TWAPOracle is Oracle {
    using SafeMath for uint;

    /**
     * MIN_TWAP_PERIOD plays two roles:
     *
     * 1. Minimum age of the stored CumulativePrice we calculate our current TWAP vs.  Eg, if one of our stored prices is from
     * 5 secs ago, and the other from 10 min ago, we should calculate TWAP vs the 10-min-old one, since a 5-second TWAP is too
     * short - relatively easy to manipulate.
     *
     * 2. Minimum time gap between stored CumulativePrices.  Eg, if we stored one 5 seconds ago, we don't need to store another
     * one now - and shouldn't, since then if someone else made a TWAP call a few seconds later, both stored prices would be
     * too recent to calculate a robust TWAP.
     *
     * These roles could in principle be separated, eg: "Require the stored price we calculate TWAP from to be >= 2 minutes
     * old, but leave >= 10 minutes before storing a new price."  But for simplicity we keep them the same.
     */
    uint public constant MIN_TWAP_PERIOD = 2 minutes;

    uint private constant UINT32_MAX = 2 ** 32 - 1;     // Should really be type(uint32).max, but that needs Solidity 0.6.8...
    uint private constant UINT224_MAX = 2 ** 224 - 1;   // Ditto, type(uint224).max

    struct CumulativePrice {
        uint32 timestamp;
        uint224 priceSeconds;   // See UniswapTools.cumulativePrice() for an explanation of "priceSeconds"
    }

    UniswapTools.Pair private pair;

    /**
     * We store two CumulativePrices, A and B, without specifying which is more recent.  This is so that we only need to do one
     * SSTORE each time we save a new one: we can inspect them later to figure out which is newer - see orderedStoredPrices().
     */
    CumulativePrice private storedPriceA;
    CumulativePrice private storedPriceB;

    /**
     * See UniswapV2SpotOracle for example pairs to pass in.
     */
    constructor(IUniswapV2Pair uniswapPair, uint token0Decimals, uint token1Decimals, bool tokensInReverseOrder) public {
        pair = UniswapTools.createPair(uniswapPair, token0Decimals, token1Decimals, tokensInReverseOrder);
    }

    /**
     * @notice Retrieve the latest twap price of the price oracle from cached values.
     * @return price
     */
    function latestPrice() public virtual override view returns (uint price) {
        (, CumulativePrice storage newerStoredPrice) = orderedStoredPrices();
        (price, , ) = _latestPrice(newerStoredPrice);
    }

    function cacheLatestPrice() public virtual override returns (uint price) {
        (CumulativePrice storage olderStoredPrice, CumulativePrice storage newerStoredPrice) = orderedStoredPrices();

        uint timestamp;
        uint priceSeconds;
        (price, timestamp, priceSeconds) = _latestPrice(newerStoredPrice);

        // Store the latest cumulative price, if it's been long enough since the latest stored price:
        if (areNewAndStoredPriceFarEnoughApart(timestamp, newerStoredPrice)) {
            storeCumulativePrice(timestamp, priceSeconds, olderStoredPrice);
        }
    }

    /**
     * @notice Calculate a twap price from a new read of the oracle and cached values.
     * @return price
     * @return timestamp
     * @return priceSeconds
     */
    function _latestPrice(CumulativePrice storage newerStoredPrice)
        internal view returns (uint price, uint timestamp, uint priceSeconds)
    {
        (timestamp, priceSeconds) = UniswapTools.cumulativePrice(pair);

        // Now that we have the current cum price, subtract-&-divide the stored one, to get the TWAP price:
        CumulativePrice storage refPrice = storedPriceToCompareVs(timestamp, newerStoredPrice);
        price = UniswapTools.calculateTWAP(timestamp, priceSeconds, uint(refPrice.timestamp), uint(refPrice.priceSeconds));
    }

    /**
     * @notice Store a new cumulative price (timestamp and priceSeconds) overwriting the existing one (olderStoredPrice)
     */
    function storeCumulativePrice(uint timestamp, uint priceSeconds, CumulativePrice storage olderStoredPrice) internal
    {
        require(timestamp <= UINT32_MAX, "timestamp overflow");
        require(priceSeconds <= UINT224_MAX, "priceSeconds overflow");
        // (Note: this assignment only stores because olderStoredPrice has modifier "storage" - ie, store by reference!)
        (olderStoredPrice.timestamp, olderStoredPrice.priceSeconds) = (uint32(timestamp), uint224(priceSeconds));
    }

    /**
     * @notice Return pointers to the stored prices, ordered by age
     * @return olderStoredPrice
     * @return newerStoredPrice
     */
    function orderedStoredPrices() internal view
        returns (CumulativePrice storage olderStoredPrice, CumulativePrice storage newerStoredPrice)
    {
        (olderStoredPrice, newerStoredPrice) = storedPriceB.timestamp > storedPriceA.timestamp ?
            (storedPriceA, storedPriceB) : (storedPriceB, storedPriceA);
    }

    /**
     * @notice For a given timestamp, return whether we should use the newer or the older stored price
     */
    function storedPriceToCompareVs(uint newTimestamp, CumulativePrice storage newerStoredPrice)
        internal view returns (CumulativePrice storage refPrice)
    {
        bool aAcceptable = areNewAndStoredPriceFarEnoughApart(newTimestamp, storedPriceA);
        bool bAcceptable = areNewAndStoredPriceFarEnoughApart(newTimestamp, storedPriceB);
        if (aAcceptable) {
            if (bAcceptable) {
                refPrice = newerStoredPrice;        // Neither is *too* recent, so return the fresher of the two
            } else {
                refPrice = storedPriceA;            // Only A is acceptable
            }
        } else if (bAcceptable) {
            refPrice = storedPriceB;                // Only B is acceptable
        } else {
            revert("Both stored prices too recent");
        }
    }

    /**
     * @notice Returns whether it has passed enough time for a stored price to be usable.
     */
    function areNewAndStoredPriceFarEnoughApart(uint newTimestamp, CumulativePrice storage storedPrice) internal view
        returns (bool farEnough)
    {
        farEnough = newTimestamp >= storedPrice.timestamp + MIN_TWAP_PERIOD;    // No risk of overflow on a uint32
    }
}
