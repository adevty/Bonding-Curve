// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice ERC20 whose mint and burn operations are restricted to its market
contract CurveToken is ERC20 {
    address public immutable market;

    error OnlyMarket();

    modifier onlyMarket() {
        if (msg.sender != market) revert OnlyMarket();
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address market_
    )
        ERC20(name_, symbol_)
    {
        require(market_ != address(0), "market=zero");
        market = market_;
    }

    function mint(address to, uint256 amount) external onlyMarket {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyMarket {
        _burn(from, amount);
    }
}
