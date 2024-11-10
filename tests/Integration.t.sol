//SPDX-License-Identifier:MIT
pragma solidity 0.8.22;

import {Token} from "../contracts/Token.sol";
import {Test, console} from "forge-std/Test.sol";
import "../contracts/PancakeSwap/IPancakeV2Pair.sol";
import "../contracts/PancakeSwap/IPancakeV2Router02.sol";
import "../contracts/PancakeSwap/IPancakeV2Factory.sol";
import "forge-std/Script.sol";

contract TestToken is Test {
    Token public testToken;
    address public admin = vm.addr(1234);
    address public user1 = vm.addr(456);
    address public user2 = vm.addr(346435);
    address public user3 = vm.addr(54353);
    address public routerAddress = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;
    address public WBNB;
    IPancakeV2Router02 public pancakeV2Router;
    uint256 public sellFee;
    uint256 public percentageMultiplier;
    address public pairAddress;
    uint256 public maxSupply;
    address public pancakeV2pair;

    //setter
    function setUp() public {
        // uint256 fork = vm.createSelectFork("https://data-seed-prebsc-1-s2.bnbchain.org:8545");
        // Deploy contracts
        vm.startPrank(admin);
        testToken = new Token("Abraham", "$ABRA");
        vm.stopPrank();
        // Setup contract
        vm.startPrank(admin);
        testToken.setTreasury(user3);
        pancakeV2Router = IPancakeV2Router02(routerAddress);
        // WBNB = pancakeV2Router.WETH();
        // pancakeV2pair = IPancakeV2Factory(pancakeV2Router.factory()).createPair(address(testToken), WBNB);
        // testToken.setAutomatedMarketMaker(pancakeV2pair,true);
        // console.log(pancakeV2pair);
        vm.stopPrank();
        // Add liquidity
        uint256 amount = 2000 * 10 ** testToken.decimals();
        vm.startPrank(admin);
        deal(admin, 1000 ether);
        testToken.approve(address(pancakeV2Router), amount);
        pancakeV2Router.addLiquidityETH{value: 1000 ether}(
            address(testToken), amount, 0, 0, admin, block.timestamp + 100000
        );
        vm.stopPrank();
        // Set constants
        vm.startPrank(admin);
        sellFee = testToken.sellFees();
        vm.stopPrank();
        percentageMultiplier = testToken.percentageMultiplier();
        pairAddress = testToken.pancakeV2pair();
        maxSupply = testToken.maxSupply() * 10 ** testToken.decimals();
    }

    function testBuyTokenTransfer() public payable {
        uint256 amount = 2000 * 10 ** testToken.decimals();
        vm.startPrank(admin);
        testToken.approve(address(pancakeV2Router), amount);
        vm.deal(admin, 10000 ether);
        address[] memory path = new address[](2);
        path[0] = testToken.WBNB();
        path[1] = address(testToken);
        vm.deal(user2, 20000 ether);
        vm.stopPrank();
        vm.startPrank(user2);
        pancakeV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 1000 ether}(
            0, path, user2, block.timestamp + 20000
        );
        assertEq(user2.balance / 1e18, 19000 ether / 1e18);
    }

    function testSellTokenTransfer() public payable {
        uint256 sellAmt;
        uint256 oldBalance;
        uint256 fee;
        uint256 treasuryBalance;
        uint256 amount = 5000;
        //2000 * 10 ** testToken.decimals()
        vm.startPrank(admin);
        testToken.approve(address(pancakeV2Router), amount);
        address[] memory path = new address[](2);
        path[0] = testToken.WBNB();
        path[1] = address(testToken);
        vm.deal(user2, 10000 ether);
        vm.stopPrank();
        vm.startPrank(user2);
        pancakeV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 1000 ether}(
            0, path, user2, block.timestamp + 20000
        );
        treasuryBalance = testToken.balanceOf(user3);
        console.log(treasuryBalance);
        // changing path for sell token
        // recipient is the pair
        path[0] = address(testToken);
        path[1] = testToken.WBNB();
        sellAmt = testToken.balanceOf(user2);
        oldBalance = testToken.balanceOf(pairAddress);
        testToken.approve(address(pancakeV2Router), sellAmt);
        fee = (sellAmt * sellFee) / percentageMultiplier;
        console.log(fee);
        console.log(testToken.balanceOf(user3));
        pancakeV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            sellAmt, 0, path, msg.sender, block.timestamp + 100000
        );
        console.log(fee);
        (uint112 TokenAmtInPoolAfterSell, uint112 WETHInPoolAfterSell,) = IPancakeV2Pair(pairAddress).getReserves();
        console.log("Tokens after sell", TokenAmtInPoolAfterSell);
        console.log("WETH after sell", WETHInPoolAfterSell);
        console.log("Users Token balance after sell", testToken.balanceOf(user2));
        assertEq(testToken.balanceOf(user3), treasuryBalance + fee);
        assertEq(testToken.balanceOf(pairAddress), oldBalance + sellAmt - fee);
    }
}
