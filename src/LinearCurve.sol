// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @notice Linear bonding-curve quotes using 18-decimals token amounts.
/// @dev basePrice and slope are denominated in the reserve token's smallest unit.
///      basePrice = reserve units per 1 whole curve token at zero supply.
///      slope = additional reserve units per whole curve token per additional
///      whole curve token of supply.
///      buy quotes round up; sell quotes round down.
library LinearCurve {
    uint256 internal constant WAD = 1e18;

    error InvalidAmount();
    error InvalidSupplyRange();

    function quoteBuy(
        uint256 supply,
        uint256 amount,
        uint256 basePrice,
        uint256 slope
    )
        internal
        pure
        returns (uint256)
    {
        if (amount == 0) revert InvalidAmount();

        // Integral of P(x) = basePrice + slope * x over [supply, supply + amount].
        // Cost = basePrice * amount / WAD
        //      + slope * amount ** (2 * supply + amount) / (2 * WAD ^ 2)
        uint256 weightedSupply = 2 * supply + amount;
        uint256 baseCost = Math.mulDiv(amount, basePrice, WAD, Math.Rounding.Ceil);
        uint256 averageSlopePrice =
            Math.mulDiv(weightedSupply, slope, 2 * WAD, Math.Rounding.Ceil);
        uint256 slopeCost =
            Math.mulDiv(amount, averageSlopePrice, WAD, Math.Rounding.Ceil);
        return baseCost + slopeCost;
    }

    function quoteSell(
        uint256 supply,
        uint256 amount,
        uint256 basePrice,
        uint256 slope
    )
        internal
        pure
        returns (uint256)
    {
        if (amount == 0) revert InvalidAmount();
        if (amount > supply) revert InvalidSupplyRange();

        // Integral over [supply - amount, supply]
        uint256 weightedSupply = 2 * supply - amount;
        uint256 baseReturn = Math.mulDiv(amount, basePrice, WAD);
        uint256 averageSlopePrice = Math.mulDiv(weightedSupply, slope, 2 * WAD);
        uint256 slopeReturn = Math.mulDiv(amount, averageSlopePrice, WAD);
        return baseReturn + slopeReturn;
    }
}
