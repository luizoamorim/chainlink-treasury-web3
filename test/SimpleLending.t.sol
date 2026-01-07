// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {SimpleLending} from "../src/SimpleLending.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract SimpleLendingTest is Test {
    SimpleLending public lending;
    MockUSDC public usdc;

    address user = address(1);

    // MAINNET FORK ADDRESS
    address constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    function setUp() public {
        usdc = new MockUSDC();
        lending = new SimpleLending(address(usdc), ETH_USD_FEED);

        usdc.mint(address(lending), 1000000 * 1e18);
        vm.deal(user, 10 ether);
    }

    function testChainlinkConnection() public {
        uint256 price = lending.getLatestPrice();
        console.log("Current ETH Price from Chainlink:", price);
        assertTrue(price > 0);
    }

    function testBorrowWithCollateral() public {
        vm.startPrank(user);

        lending.depositCollateral{value: 1 ether}();

        uint256 borrowAmount = 1000 * 1e18;
        // Chamando a função com o nome novo (CamelCase)
        lending.borrowUsdc(borrowAmount);

        assertEq(usdc.balanceOf(user), borrowAmount);

        vm.stopPrank();
    }

    function testCannotBorrowWithoutCollateral() public {
        vm.startPrank(user);

        vm.expectRevert("Health Factor too low! Add more collateral.");
        lending.borrowUsdc(100 * 1e18);

        vm.stopPrank();
    }
}
