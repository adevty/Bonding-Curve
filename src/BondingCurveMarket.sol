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
    error ZeroPayout();

    event Bought(address indexed buyer, uint256 curveTokensOut, uint256 reserveIn);
    event Sold(address indexed seller, uint256 curveTokensIn, uint256 reserveOut);

    constructor(
        IERC20 reserveToken_,
        string memory tokenName_,
        string memory tokenSymbol_,
        uint256 basePrice_,
        uint256 slope_,
        uint256 maxSupply_
    ) {
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

    /// @notice "Quote the reserve cost for buying an exact token amount"
    function quoteBuy(uint256 amount) public view returns (uint256) {
        if (amount == 0) revert ZeroAmount();
        uint256 supply = curveToken.totalSupply();
        if (amount > maxSupply - supply) revert SupplyCapExceeded();
        return LinearCurve.quoteBuy(supply, amount, basePrice, slope);
    }

    /// @notice "Quote reserve proceeds for sellings an exact token amount"
    function quoteSell(uint256 amount) public view returns (uint256) {
        if (amount == 0) revert ZeroAmount();
        return LinearCurve.quoteSell(curveToken.totalSupply(), amount, basePrice, slope);
    }

    /// @notice buy an exact amount of curve token
    /// @param amountOut exact amount of curve tokens to mint (18 decimals)
    /// @param maxReserveIn maximum reserve amount the buyer accepts to pay
    function buy(
        uint256 amountOut,
        uint256 maxReserveIn
    )
        external
        nonReentrant
        returns (uint256 reserveIn)
    {
        reserveIn = quoteBuy(amountOut);
        if (reserveIn > maxReserveIn) {
            revert SlippageExceeded(reserveIn, maxReserveIn);
        }
        if (reserveIn == 0) revert ZeroAmount();

        uint256 beforeBalance = reserveToken.balanceOf(address(this));
        reserveToken.safeTransferFrom(msg.sender, address(this), reserveIn);
        uint256 received = reserveToken.balanceOf(address(this)) - beforeBalance;
        if (received != reserveIn) revert UnsopportedReserveToken();

        curveToken.mint(msg.sender, amountOut);
        emit Bought(msg.sender, amountOut, reserveIn);
    }

    /// @notice burn curve tokens and receive reserve tokens.
    /// @param amountIn amount of curve tokens to burn (18 decimals)
    /// @param minReserveOut minimum reserve payout accepted by the selller
    function sell(
        uint256 amountIn,
        uint256 minReserveOut
    )
        external
        nonReentrant
        returns (uint256 reserveOut)
    {
        reserveOut = quoteSell(amountIn);
        if (reserveOut < minReserveOut) {
            revert SlippageExceeded(reserveOut, minReserveOut);
        }
        if (reserveOut == 0) revert ZeroPayout();

        uint256 reserveBalance = reserveToken.balanceOf(address(this));
        if (reserveBalance < reserveOut) {
            revert InsufficientReserve(reserveBalance, minReserveOut);
        }

        // Effects before reserve transfer; transaction reverts atomically on failure.
        curveToken.burn(msg.sender, amountIn);

        uint256 recipientBalanceBefore = reserveToken.balanceOf(msg.sender);
        reserveToken.safeTransfer(msg.sender, reserveOut);
        uint256 recipientBalanceAfter = reserveToken.balanceOf(msg.sender);
        if (recipientBalanceAfter - recipientBalanceBefore != reserveOut) {
            revert UnsopportedReserveToken();
        }

        emit Sold(msg.sender, amountIn, reserveOut);
    }

    function reserveBalance() external view returns (uint256) {
        return reserveToken.balanceOf(address(this));
    }

    function currentMarginalPrice() external view returns (uint256) {
        // Result in reserve smallest units per whole curve tokens.
        // the value is rounded down to an integer reserve unit.
        uint256 supply = curveToken.totalSupply();
        // MaxSupply <= uint256.max / 2, so this addition cannot overflow
        // for any valid supply; Math.mulDiv protects the multiplication.
        return basePrice + Math.mulDiv(supply, slope, WAD);
    }
}
