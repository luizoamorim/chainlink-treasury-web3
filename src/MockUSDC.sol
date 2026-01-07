// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Named import: Mais eficiente e profissional
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Mock USDC Token for Testing Purposes
/// @notice This contract simulates a USDC-like ERC20 token with minting functionality
/// @author Chainlink Treasury Tutorials
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
