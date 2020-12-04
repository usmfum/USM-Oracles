// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;
import "../Oracle.sol";
import "./Median.sol";

/**
 * @dev Use 3 oracles and return their median price.
 */
contract MedianOracle is Oracle {

    Oracle[3] public oracles;

    uint public cachedPrice;

    constructor(Oracle[3] memory oracles_) public {
        oracles = oracles_;
    }

    /**
     * @notice Retrieve the latest price of the price oracle.
     * @return price
     */
    function latestPrice() 
        public virtual override view returns (uint)
    {
        return Median.median(
            oracles[0].latestPrice(),
            oracles[1].latestPrice(),
            oracles[2].latestPrice()
        );
    }

    /**
     * @notice Store the latest price of the price oracle.
     * @return price
     */
    function cacheLatestPrice()
        public virtual override returns (uint)
    {
        cachedPrice = Median.median(
            oracles[0].latestPrice(),
            oracles[1].latestPrice(),
            oracles[2].latestPrice()
        );

        return cachedPrice;
    }
}
