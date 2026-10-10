// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { CurveToken } from "./CurveToken.sol";
import { LinearCurve } from "./LinearCurve.sol";

/// @title Bonding Curve Market
/// @notice Buy and Sell a newly deployed ERC20 againtsa reserve ERC20.
/// @dev The curve token has 18 decimals. Pricing parameters use the reserve
///      token's smallest unit per whole curve token. Fee-on-transfer and
//       rebasing reserve tokens are unsopported; buys verify exact receipt.
contract BondingCurveMarket is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 private constant WAD = 1e18;

    IERC20 public immutable reserveToken;
    CurveToken public immutable curveToken;
    uint256 public immutable basePrice;
    uint256 public immutable slope;
    uint256 public immutable maxSupply;

    error ZeroAddress();
    error ZeroAmount();
    error SupplyCapExceeded();
    error SlippageExceeded(uint256 available, uint256 limit);
    error UnsopportedReserveToken();
    error InsufficientReserve(uint256 available, uint256 required);
    error ZeroPay();

    event Bought(address indexed buyer, uint256 curveTokensOut, uint256 reserveIn);
    event Sold(address indexed seller, uint256 curveTokensIn, uint256 reserveOut);
    
    constructor(IERC20 reserveToken_, string memory tokenName_, string memory tokenSymbol_, uint256 basePrice_, uint256 slope_, uint256 maxSupply_) {
        if (address(reserveToken_) == address(0)) revert ZeroAddress();
        if (basePrice_ == 0) revert ZeroAmount();
        if (maxSupply_ == 0 || maxSupply_ > type(uint256).max / 2) {
            revert SupplyCapExceeded();
        }

        reserveToken = reserveToken_;
        basePrice = basePrice_;
        slope = slope_;
        maxSupply = maxSupply_;

        // Deploy token from this constructor so its market address is fixed
        curveToken = new CurveToken(tokenName_, tokenSymbol_, address(this));
    }

    /// @notice "Not finished yet..."
}