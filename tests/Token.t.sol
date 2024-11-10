//SPDX-License-Identifier:MIT
pragma solidity ^0.8.22;

//import {Token} from "../contracts/Token.sol";
import {Token} from "../contracts/AbrahamToken.sol";
import {Test, console} from "forge-std/Test.sol";
import "../contracts/PancakeSwap/IPancakeV2Pair.sol";
import "../contracts/PancakeSwap/IPancakeV2Router02.sol";
import "../contracts/PancakeSwap/IPancakeV2Factory.sol";
import {TestInternalFuncHarness} from "../contracts/HarnessContract.sol";
import "forge-std/Script.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "../contracts/IWBNB.sol";

contract TestToken is Test, Script {
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
    //address public WBNBaddress=0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    IWBNB public wbnb_;

    //setter
    function setUp() public {
        uint256 fork = vm.createSelectFork("https://data-seed-prebsc-1-s1.bnbchain.org:8545");

        // uint256 fork = vm.createSelectFork("https://bsc-testnet.publicnode.com");

        // Deploy contracts
        vm.startPrank(admin);
        testToken = new Token("Abraham", "$ABRA", admin);
        // Setup contract
        testToken.setTreasury(user3);
        testToken.setSellFee(250);
        pancakeV2Router = IPancakeV2Router02(routerAddress);
        WBNB = pancakeV2Router.WETH();
        wbnb_ = IWBNB(WBNB);
        pancakeV2pair = testToken.pancakeV2pair();
        vm.label(address(wbnb_), "wbnb");
        vm.label(address(testToken), "abraham");
        vm.label(address(admin), "admin");
        vm.label(address(pancakeV2pair), "pancakeV2pair");
        vm.label(address(pancakeV2Router), "pancakeV2Router");
        vm.stopPrank();
        // Add liquidity
        uint256 amount = 1000 ether;
        //* 10 ** testToken.decimals();

        vm.startPrank(admin);
        // deal(admin, 1000 ether);
        deal(WBNB, admin, 1000 ether);
        deal(address(testToken), admin, 1000 ether);
        wbnb_.approve(address(pancakeV2Router), 1000 ether);
        testToken.approve(address(pancakeV2Router), 1000 ether);
        pancakeV2Router.addLiquidity(
            address(testToken), WBNB, 1000 ether, amount, 0, 0, address(admin), block.timestamp + 100000
        );
        vm.stopPrank();
        // Set constants
        vm.startPrank(admin);
        sellFee = testToken.sellFees();
        vm.stopPrank();
        percentageMultiplier = testToken.percentageMultiplier();
        //pairAddress = testToken.pancakeV2pair();
        maxSupply = testToken.maxSupply() * 10 ** testToken.decimals();
    }

    //checking the initial treasury does not belong to zero address
    function test_setInitalTreasury() external {
        vm.startPrank(admin);
        vm.expectRevert("Token: treasury could not be zero address");
        testToken = new Token("Abraham", "$ABRA", address(0));
    }
    //ownership test

    function test_ownership() external {
        vm.startPrank(admin);
        testToken.transferOwnership(user2);
        (address pendingOwner) = testToken.pendingOwner();
        assertEq(pendingOwner, user2);
        vm.stopPrank();
        vm.prank(user2);
        testToken.acceptOwnership();
        assertEq(user2, testToken.owner());
    }

    // cle
    //test- accounting
    //write a vm.expect error for mint and burn
    //getting error while vm.expectRevert in the ownership methods
    function test_burn() external {
        uint256 balance;
        deal(address(testToken), user2, 1000);
        vm.startPrank(user2);
        balance = testToken.balanceOf(user2);
        console.log(balance);
        testToken.burn(balance);
        assertEq(testToken.balanceOf(user2), 0);
    }

    function test_burn_revert() external {
        uint256 balance;
        vm.startPrank(user2);
        balance = testToken.balanceOf(user2);
        console.log(balance);
        vm.expectRevert("Token: burn amount is 0");
        testToken.burn(balance);
    }

    function test_setAutomatedMarketMaker() external {
        vm.startPrank(admin);
        testToken.setAutomatedMarketMaker(testToken.pancakeV2pair(), true);
        vm.stopPrank();
    }

    function test_setAutomatedMarketMaker_revert() external {
        assertEq(testToken.owner(), admin);
        vm.startPrank(vm.addr(9876869));
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), vm.addr(9876869))
        );
        testToken.setAutomatedMarketMaker(pairAddress, false);
        vm.stopPrank();
        vm.startPrank(admin);
        vm.expectRevert("Token: AMM(DEX) is zero address");
        testToken.setAutomatedMarketMaker(address(0), false);
        vm.stopPrank();
    }

    function testFuzz_setSellFee(uint256 newSellFee) external {
        vm.startPrank(admin);
        if (newSellFee >= 0 && newSellFee < 501) {
            testToken.setSellFee(newSellFee);
            assertEq(testToken.sellFees(), newSellFee);
        } else {
            vm.expectRevert("Token: Sell fee is more than 5 or is 0");
            testToken.setSellFee(newSellFee);
        }
        vm.stopPrank();
    }

    function test_setTreasury() external {
        vm.startPrank(admin);
        testToken.setTreasury(user1);
        assertEq(testToken.treasury(), user1);
        vm.stopPrank();
        vm.startPrank(address(0));
        vm.expectRevert();
        testToken.setTreasury(user1);
    }

    function test_setTreasury_revert() external {
        vm.startPrank(admin);
        vm.expectRevert("Token: Tax collector is zero address");
        testToken.setTreasury(address(0));
    }

    function test_transferFrom() external {
        deal(address(testToken), admin, 400);
        vm.startPrank(admin);
        console.log(testToken.balanceOf(admin), "initial admin balance");
        testToken.setTreasury(user2);
        console.log(testToken.balanceOf(user2), "initial user2 balance");
        testToken.approve(user1, 200);
        vm.stopPrank();
        vm.startPrank(user1);
        console.log(testToken.balanceOf(user1), "initial user1 balance");
        testToken.transferFrom(admin, user2, 200);
        console.log(testToken.balanceOf(user2), "after transfer user2 balance");
        vm.stopPrank();
        vm.startPrank(user2);
        testToken.approve(user2, 100);
        testToken.transferFrom(user2, admin, 100);
    }

    function test_transferFrom_revert() external {
        vm.expectRevert("Token: transfer from the zero address");
        testToken.transferFrom(address(0), user1, 90997977);
        vm.expectRevert("Token: transfer to the zero address");
        testToken.transferFrom(admin, address(0), 9697080797);
        vm.expectRevert("Token: transfer amount exceeds balance");
        testToken.transferFrom(admin, user1, maxSupply * 10 ** 19);
    }

    function testBuyTokens() external {
        vm.startPrank(admin);
        deal(WBNB, user1, 900 ether);
        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = address(testToken);
        vm.stopPrank();
        // testToken.approve(address(pancakeV2Router),1000);
        vm.startPrank(user1);
        wbnb_.approve(address(pancakeV2Router), 100 ether);
        pancakeV2Router.swapExactTokensForTokens(100, 0, path, user1, block.timestamp + 3000);
        vm.stopPrank();
        console.log(testToken.balanceOf(user1));
        //pancakeV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amountOutMin, path, to, deadline);
        vm.startPrank(admin);
    }

    function testSellTokens() external {
        //admin selling ABRA token, no fees charged
        vm.startPrank(admin);
        deal(address(testToken), admin, 100);
        address[] memory path = new address[](2);
        path[0] = address(testToken);
        path[1] = WBNB;
        vm.stopPrank();
        console.log(testToken.balanceOf(admin), "admin bal before transfer");
        vm.startPrank(admin);
        testToken.approve(address(pancakeV2Router), 100);
        pancakeV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            100, 0, path, admin, block.timestamp + 10000
        );
        vm.stopPrank();
        console.log(testToken.balanceOf(admin), "after selling 100 tokens");
        //user1 selling 100 tokens fee will get deducted
        vm.prank(admin);
        deal(address(testToken), user1, 100);
        console.log(testToken.balanceOf(user1), "before selling the amount");
        vm.startPrank(user1);
        testToken.approve(address(pancakeV2Router), 100);
        pancakeV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            100, 0, path, user1, block.timestamp + 10000
        );
        vm.stopPrank();
        console.log(testToken.balanceOf(user1), "after selling the amount");
    }

    function testsetExcludeFromFees() external {
        vm.startPrank(admin);
        testToken.setExcludeFromFees(user1, true);
    }

    function testCalculateFees() public {
        TestInternalFuncHarness tokenHarness = new TestInternalFuncHarness(user2);
        uint256 fees_ = tokenHarness.calculateFees_Harness(100, 1000);
        assertEq(tokenHarness.percentageMultiplier(), 10_000);
        assertEq(fees_, 10);
    }
}
