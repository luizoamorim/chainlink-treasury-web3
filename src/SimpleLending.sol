// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title Simple Lending Protocol
/// @notice A basic lending protocol allowing users to deposit ETH as collateral and borrow USDC against it
/// @author Chainlink Treasury Tutorials
contract SimpleLending {
    IERC20 public usdcToken;
    AggregatorV3Interface public priceFeed;

    /// @notice Mappings to track user collateral and borrowed amounts
    mapping(address => uint256) public ethCollateral;
    mapping(address => uint256) public usdcBorrowed;

    /// @notice Loan-to-Value ratio (LTV) set at 50%
    uint256 public constant LTV = 50;

    event Deposit(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);

    constructor(address _tokenAddress, address _priceFeedAddress) {
        usdcToken = IERC20(_tokenAddress);
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    /// @notice Allows users to deposit ETH as collateral
    function depositCollateral() external payable {
        require(msg.value > 0, "Must deposit ETH");
        ethCollateral[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Allows users to borrow USDC against their ETH collateral
    function borrowUsdc(uint256 amountToBorrow) external {
        uint256 collateralValueInUsd = getCollateralValue(msg.sender);
        uint256 totalDebt = usdcBorrowed[msg.sender] + amountToBorrow;

        uint256 maxBorrow = (collateralValueInUsd * LTV) / 100;

        require(totalDebt <= maxBorrow, "Health Factor too low! Add more collateral.");

        usdcBorrowed[msg.sender] += amountToBorrow;
        require(usdcToken.balanceOf(address(this)) >= amountToBorrow, "Liquidity low in pool");

        bool success = usdcToken.transfer(msg.sender, amountToBorrow);
        require(success, "Transfer failed");

        emit Borrow(msg.sender, amountToBorrow);
    }

    /// @notice Fetches the latest ETH/USD price from Chainlink Oracle
    function getLatestPrice() public view returns (uint256) {
        (
            ,
            /* uint80 roundID */ int price,
            ,
            ,

        ) = /* uint timeStamp */ /* uint startedAt */ /* uint80 answeredInRound */ priceFeed.latestRoundData();

        require(price > 0, "Invalid price from Oracle");
        return uint256(price);
    }

    /// @notice Calculates the USD value of a user's ETH collateral
    function getCollateralValue(address user) public view returns (uint256) {
        uint256 ethAmount = ethCollateral[user];
        uint256 price = getLatestPrice();
        return (ethAmount * price) / 1e8;
    }
}
