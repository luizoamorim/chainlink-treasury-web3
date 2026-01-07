// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract SimpleLending {
    // STYLE GUIDE FIX: Immutables use SCREAMING_SNAKE_CASE
    IERC20 public immutable USDC_TOKEN;
    AggregatorV3Interface public immutable PRICE_FEED;

    // STATE VARIABLES
    mapping(address => uint256) public ethCollateral;
    mapping(address => uint256) public usdcBorrowed;

    // RISK PARAMETER: Loan-to-Value (LTV) set to 50%
    uint256 public constant LTV = 50;

    // EVENTS
    event Deposit(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(address _tokenAddress, address _priceFeedAddress) {
        USDC_TOKEN = IERC20(_tokenAddress);
        PRICE_FEED = AggregatorV3Interface(_priceFeedAddress);
    }

    // --- 1. DEPOSIT COLLATERAL ---
    function depositCollateral() external payable {
        require(msg.value > 0, "Must deposit ETH");
        ethCollateral[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    // --- 2. WITHDRAW COLLATERAL ---
    function withdrawCollateral(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        require(ethCollateral[msg.sender] >= amount, "Insufficient collateral balance");

        // CRITICAL STEP: Simulate health factor AFTER withdrawal
        uint256 collateralRemaining = ethCollateral[msg.sender] - amount;
        uint256 currentDebt = usdcBorrowed[msg.sender];

        // If user has debt, we must ensure they remain solvent
        if (currentDebt > 0) {
            uint256 price = getLatestPrice();

            // MATH FIX: Multiply first, Divide last (Prevents precision loss)
            // Original: (collateral * price / 1e8) * LTV / 100
            // Optimized: (collateral * price * LTV) / (1e8 * 100)
            uint256 maxBorrowAllowed = (collateralRemaining * price * LTV) / (1e8 * 100);

            require(currentDebt <= maxBorrowAllowed, "Cannot withdraw: Health Factor would be too low");
        }

        // CHECKS-EFFECTS-INTERACTIONS PATTERN
        // 1. Effect (Update state)
        ethCollateral[msg.sender] -= amount;

        // 2. Interaction (Send ETH)
        // Using .call is the current best practice for ETH transfers
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    // --- 3. BORROW ASSET ---
    function borrowUsdc(uint256 amountToBorrow) external {
        uint256 collateralValueInUsd = getCollateralValue(msg.sender);
        uint256 totalDebt = usdcBorrowed[msg.sender] + amountToBorrow;

        uint256 maxBorrow = (collateralValueInUsd * LTV) / 100;

        // Atomic solvency check
        require(totalDebt <= maxBorrow, "Health Factor too low! Add more collateral.");

        // CHECKS-EFFECTS-INTERACTIONS PATTERN
        // 1. Effect (Update state first)
        usdcBorrowed[msg.sender] += amountToBorrow;

        // 2. Interaction (External call later)
        require(USDC_TOKEN.balanceOf(address(this)) >= amountToBorrow, "Liquidity low in pool");
        bool success = USDC_TOKEN.transfer(msg.sender, amountToBorrow);
        require(success, "Transfer failed");

        emit Borrow(msg.sender, amountToBorrow);
    }

    // --- ORACLE LOGIC ---
    function getLatestPrice() public view returns (uint256) {
        (
            ,
            /* uint80 roundID */ int price,
            ,
            /* uint startedAt */ uint timeStamp,

         /* uint80 answeredInRound */) = PRICE_FEED.latestRoundData();

        require(price > 0, "Invalid price from Oracle");

        // SECURITY: Stale Price Check (Ensure data is fresh)
        require(block.timestamp - timeStamp < 3600, "Stale price data");

        return uint256(price);
    }

    function getCollateralValue(address user) public view returns (uint256) {
        uint256 ethAmount = ethCollateral[user];
        uint256 price = getLatestPrice();
        // Normalization: (18 decimals * 8 decimals) / 8 decimals = 18 decimals
        return (ethAmount * price) / 1e8;
    }
}
