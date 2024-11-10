//SPDX-License-Identifier :MIT
pragma solidity 0.8.22;

import {stdError, console, Test} from "forge-std/Test.sol";
import {Presale} from "../contracts/Presale.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "../contracts/Token.sol";
import "../contracts/Token2.sol";

contract TestPresale is Test {
    Presale public testPresale;
    Token2 public token;
    address public user1 = vm.addr(234);
    address public user2 = vm.addr(4567);
    address public user3 = vm.addr(907080);
    address public admin = vm.addr(1);
    address public saleToken;
    uint256 public maxSupply;

    function setUp() public {
        vm.startPrank(admin);
        token = new Token2("Aakash", "$AAKA");
        //tokens minted in total for sale round 1 and round 2
        token.mint(100000 ether);
        testPresale = new Presale(address(token));
        // //setting users balance
        deal(admin, 10000 ether);
        deal(user1, 30000 ether);
        deal(user2, 20000 ether);
        deal(user3, 10000 ether);
    }

    function test_failsetUp() external {
        vm.expectRevert("Presale: token is zero address");
        testPresale = new Presale(address(0));
    }

    function test_failsetSaleInfo() external {
        vm.startPrank(admin);
        IERC20(address(token)).approve(address(testPresale), 501);
        testPresale.setSaleInfo(
            0,
            500,
            uint64(block.timestamp + 2 days),
            uint64(block.timestamp + 4 days),
            5 ether,
            uint64(block.timestamp + 1 days)
        );
        //checking roundId
        vm.expectRevert("Presale: InvalidRoundId");
        testPresale.setSaleInfo(
            2,
            500,
            uint64(block.timestamp + 2 days),
            uint64(block.timestamp + 4 days),
            5 ether,
            uint64(block.timestamp + 1 days)
        );
        //checking param can't be changed in sale
        vm.warp(block.timestamp + 3 days);
        vm.expectRevert("Presale: Sale has not ended or force stopped");
        testPresale.setSaleInfo(
            0,
            500,
            uint64(block.timestamp + 2 days),
            uint64(block.timestamp + 4 days),
            5 ether,
            uint64(block.timestamp + 1 days)
        );
        //check if the round 2 is not started, should be able to set
        testPresale.stopSale(0);
        IERC20(address(token)).approve(address(testPresale), 501);
        testPresale.setSaleInfo(
            1,
            500,
            uint64(block.timestamp + 5 days),
            uint64(block.timestamp + 7 days),
            5 ether,
            uint64(block.timestamp + 1 days)
        );
    }

    function test_setSaleInfo() external {
        vm.startPrank(admin);
        IERC20(address(token)).approve(address(testPresale), 501);
        testPresale.setSaleInfo(
            0,
            500,
            uint64(block.timestamp + 2 days),
            uint64(block.timestamp + 4 days),
            5 ether,
            uint64(block.timestamp + 1 days)
        );
        //checking the ownership
        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), user2));
        testPresale.setSaleInfo(
            0,
            500,
            uint64(block.timestamp + 2 days),
            uint64(block.timestamp + 4 days),
            5 ether,
            uint64(block.timestamp + 1 days)
        );
        assertEq(testPresale.currentSaleRound(), 0);
    }

    function test_buyToken() external payable {
        vm.startPrank(admin);
        IERC20(address(token)).approve(address(testPresale), token.balanceOf(admin));
        testPresale.setSaleInfo(
            0,
            5000,
            uint64(block.timestamp + 2 days),
            uint64(block.timestamp + 4 days),
            5 ether,
            uint64(block.timestamp + 30 days)
        );
        vm.stopPrank();
        vm.startPrank(user1);
        vm.warp(block.timestamp + 3 days);
        testPresale.buyToken{value: 25000 ether}(5000);
        //reverting but without data
        vm.expectRevert("Presale: max token amount sale reached");
        testPresale.buyToken{value: 10 ether}(1);
        //testPresale.buyToken{value: 500 ether}(100);
        (uint256 a1,) = testPresale.userInfo(user1);
        console.log(a1);
        vm.stopPrank();
        assertEq(a1, 5000);
    }

    function test_failbuyToken() external payable {
        vm.startPrank(admin);
        IERC20(address(token)).approve(address(testPresale), 501);
        testPresale.setSaleInfo(
            0,
            500,
            uint64(block.timestamp + 2 days),
            uint64(block.timestamp + 4 days),
            5 ether,
            uint64(block.timestamp + 30 days)
        );
        vm.stopPrank();
        vm.startPrank(user1);
        vm.warp(block.timestamp + 3 days);
        vm.expectRevert("Presale: can not buy 0 tokens");
        testPresale.buyToken{value: 1000 ether}(0);
        vm.expectRevert("Presale: buyer has not enough funds");
        testPresale.buyToken{value: 1000 ether}(566);
        vm.warp(block.timestamp - 6 days);
        vm.expectRevert("Presale: Sale hasn't already started");
        testPresale.buyToken{value: 1000 ether}(200);
        vm.warp(block.timestamp + 7 days);
        vm.expectRevert("Presale: Sale has ended");
        testPresale.buyToken{value: 1000 ether}(200);
    }

    function test_stopSale() external {
        vm.startPrank(admin);
        IERC20(address(token)).approve(address(testPresale), 501);
        testPresale.setSaleInfo(
            0,
            500,
            uint64(block.timestamp + 2 days),
            uint64(block.timestamp + 4 days),
            5 ether,
            uint64(block.timestamp + 30 days)
        );
        vm.warp(block.timestamp + 3 days);
        testPresale.stopSale(0);
    }

    function test_failstopSale() external {
        vm.startPrank(admin);
        IERC20(address(token)).approve(address(testPresale), 501);
        testPresale.setSaleInfo(
            1,
            500,
            uint64(block.timestamp + 2 days),
            uint64(block.timestamp + 4 days),
            5 ether,
            uint64(block.timestamp + 30 days)
        );
        //console.log(testPresale.currentSaleRound());
        vm.warp(block.timestamp + 3 days);
        vm.expectRevert("Presale: InvalidRoundId");
        testPresale.stopSale(2);
        vm.warp(block.timestamp - 3 days);
        vm.expectRevert("Presale: Sale hasn't started yet");
        testPresale.stopSale(1);
    }

    function test_withdrawUnsoldTokens() public {
        //setting sale info
        vm.startPrank(admin);
        IERC20(address(token)).approve(address(testPresale), uint64(token.balanceOf(admin) / 2));
        testPresale.setSaleInfo(
            0,
            uint64(token.balanceOf(admin) / 2),
            uint64(block.timestamp + 2 days),
            uint64(block.timestamp + 4 days),
            3 ether,
            uint64(block.timestamp + 30 days)
        );
        vm.stopPrank();
        //user1 purchasing tokens in sale1
        vm.startPrank(user1);
        vm.warp(block.timestamp + 3 days);
        testPresale.buyToken{value: 9000 ether}(3000);
        testPresale.buyToken{value: 6000 ether}(2000);
        vm.stopPrank();
        //stopping 1st sale and setting sale info for 2nd sale
        vm.startPrank(admin);
        testPresale.stopSale(0);
        IERC20(address(token)).approve(address(testPresale), uint64(token.balanceOf(admin)));
        testPresale.setSaleInfo(
            1,
            uint64(token.balanceOf(admin)),
            uint64(block.timestamp + 5 days),
            uint64(block.timestamp + 8 days),
            3 ether,
            uint64(block.timestamp + 30 days)
        );
        vm.stopPrank();
        //user 2 purchasing tokens in presale round2
        vm.startPrank(user2);
        vm.warp(block.timestamp + 6 days);
        testPresale.buyToken{value: 9000 ether}(3000);
        vm.stopPrank();
        //leftover tokens should be returned
        vm.prank(admin);
        testPresale.withdrawUnsoldTokens();
    }

    function test_failwithdrawUnsoldTokens() external {
        vm.startPrank(admin);
        IERC20(address(token)).approve(address(testPresale), uint64(token.balanceOf(admin) / 2));
        testPresale.setSaleInfo(
            0,
            uint64(token.balanceOf(admin) / 2),
            uint64(block.timestamp + 2 days),
            uint64(block.timestamp + 4 days),
            3 ether,
            uint64(block.timestamp + 30 days)
        );
        vm.stopPrank();
        //user1 purchasing tokens in sale1
        vm.startPrank(user1);
        vm.warp(block.timestamp + 3 days);
        testPresale.buyToken{value: 9000 ether}(3000);
        testPresale.buyToken{value: 6000 ether}(2000);
        vm.stopPrank();
        //stopping 1st sale and setting sale info for 2nd sale
        vm.startPrank(admin);
        testPresale.stopSale(0);
        IERC20(address(token)).approve(address(testPresale), uint64(token.balanceOf(admin)));
        testPresale.setSaleInfo(
            1,
            uint64(token.balanceOf(admin)),
            uint64(block.timestamp + 5 days),
            uint64(block.timestamp + 8 days),
            3 ether,
            uint64(block.timestamp + 30 days)
        );
        vm.stopPrank();
        //user 2 purchasing tokens in presale round2
        vm.startPrank(user2);
        vm.warp(block.timestamp + 6 days);
        testPresale.buyToken{value: 9000 ether}(3000);
        testPresale.buyToken{value: 6000 ether}(2000);
        vm.stopPrank();
        //leftover tokens should be returned
        //checking if no tokens left
        vm.prank(admin);
        //vm.expectRevert("Presale: no tokens to withdraw");
        testPresale.withdrawUnsoldTokens();
    }

    function test_claimVestedTokens() external {
        vm.startPrank(admin);
        IERC20(address(token)).approve(address(testPresale), 10000);
        testPresale.setSaleInfo(
            0,
            10000,
            uint64(block.timestamp + 2 days),
            uint64(block.timestamp + 5 days),
            5 ether,
            uint64(block.timestamp + 30 days)
        );
        vm.stopPrank();
        vm.startPrank(user1);
        console.log(block.timestamp);
        vm.warp(block.timestamp + 3 days);
        testPresale.buyToken{value: 10000 ether}(1200);
        vm.stopPrank();
        vm.prank(admin);
        testPresale.stopSale(0);
        console.log(block.timestamp);
        vm.warp(block.timestamp + 90 days);
        vm.startPrank(user1);
        testPresale.claimVestedTokens();
        console.log(testPresale.timeElapsed());
        console.log(testPresale.tokenAllocated());
        vm.warp(block.timestamp + 30 days);
        testPresale.claimVestedTokens();
        console.log(testPresale.timeElapsed());
        console.log(testPresale.tokenAllocated());
        vm.warp(block.timestamp + 30 days);
        testPresale.claimVestedTokens();
        console.log(testPresale.timeElapsed());
        console.log(testPresale.tokenAllocated());
        vm.warp(block.timestamp + 210 days);
        testPresale.claimVestedTokens();
        console.log(testPresale.timeElapsed());
        console.log(testPresale.tokenAllocated());
        vm.warp(block.timestamp + 31 days);
        testPresale.claimVestedTokens();
        console.log(testPresale.timeElapsed());
        console.log(testPresale.tokenAllocated());
    }

    function test_tryBothSaleRound() external {
        vm.startPrank(user1);
        //testPresale.buyToken{value: 1200 ether}(1200);
        vm.stopPrank();
        vm.startPrank(admin);
        IERC20(address(token)).approve(address(testPresale), 1000 ether);
        testPresale.setSaleInfo(
            0,
            1000 ether,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 3 days),
            5,
            uint64(block.timestamp + 4 days)
        );
        vm.stopPrank();
        vm.warp(block.timestamp + 2 days);
        vm.startPrank(user1);
        testPresale.buyToken{value:5000 ether}(1000);
        vm.warp(block.timestamp + 34 days);
        testPresale.claimVestedTokens();
        uint256 userRemainingBalance=testPresale.tokenBalanceAfterVesting();
        console.log(userRemainingBalance);
        vm.stopPrank();
        vm.startPrank(admin);
        IERC20(address(token)).approve(address(testPresale), 1000 ether);
        testPresale.setSaleInfo(
            1,1000 ether, uint64(block.timestamp + 2 days), 
            uint64(block.timestamp + 6 days), 10, 
            uint64(block.timestamp + 7 days));
        vm.stopPrank();
        vm.startPrank(user2);
        vm.warp(block.timestamp + 5 days);
        testPresale.buyToken{value:20000 ether}(2000);   
        // testPresale.claimVestedTokens();
       // can not start the sale again
        IERC20(address(token)).approve(address(testPresale), 1000 ether);
        vm.stopPrank();
        // vm.prank(admin);
        // testPresale.setSaleInfo(0,10000 ether, uint64(block.timestamp + 4 days), uint64(block.timestamp + 6 days), 10, uint64(block.timestamp + 4 days));

    }
}
