// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/CallOptions.sol";

contract CounterTest is Test {
    CallOptionsContract public oc;
    address public jim;
    address public bob;
    address public alice;
    address public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function setupFork() public {
        string memory MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(forkId);
        vm.rollFork(16084371);
    }

    function setUp() public {
        oc = new CallOptionsContract();
        setupFork();
        jim = makeAddr("jim");
        bob = makeAddr("bob");
        alice = makeAddr("alice");
        vm.deal(jim, 100 ether); // ~$160,000
        vm.deal(bob, 100 ether); // ~$160,000
        vm.deal(alice, 100 ether); // $160,000
        deal(usdc, bob, 100000e6); // $100,000
            // deal(usdt, bob, 100000e8); // $100,000
    }

    function testOptionUserflow() external {
        // Jim will sell an option's contract: he's giving someone the ability to buy his 50 ETH at 1.8k
        vm.prank(jim);
        oc.sellCallOption{value: 30 ether}(1800);
        assertEq(IERC20(usdc).balanceOf(jim), 0); // NO USDC TO begin with

        // Bob will buy this options contract, for a 0.5 ether premium
        vm.prank(bob);
        oc.buyCallOption{value: 9e17}(jim);
        assertEq(address(jim).balance, 70 ether + 0.9 ether); // check Jim got his premium

        // 15 days go by... ETH is now 2k so Bob would like to exercise his option to buy Jim's ETH
        vm.warp(block.timestamp + 15 days);
        console.log(IERC20(usdc).balanceOf(bob) / 1e6);
        vm.prank(bob);
        IERC20(usdc).approve(address(oc), 1800 * 1e6 * 30);
        vm.prank(bob);
        oc.exerciseOption(jim, usdc);

        // check that everyone was paid out
        assertEq(address(bob).balance, 100 ether - 0.9 ether + 30 ether); // Bob gets his 30 ether;
        assertEq(IERC20(usdc).balanceOf(bob), 100000e6 - 1800 * 1e6 * 30); // Bob paid his usdc;
        assertEq(IERC20(usdc).balanceOf(jim), 1800 * 1e6 * 30); // Jim got his USDC
    }

    function testClaimExpiredOption() external {
        // create call option
        vm.prank(jim);
        oc.sellCallOption{value: 30 ether}(1800);
        assertEq(address(jim).balance, 70 ether);

        // forward some time in the future
        vm.warp(block.timestamp + 30 days);

        // claim option
        vm.prank(jim);
        oc.claimUnboughtOption();
        assertEq(address(jim).balance, 100 ether);
    }

    function testClaimUnexpiredOption() external {
        // create call option
        vm.prank(jim);
        oc.sellCallOption{value: 30 ether}(1800);
        assertEq(address(jim).balance, 70 ether);

        // forward some time in the future
        vm.warp(block.timestamp + 30 days - 1);

        // claim option
        vm.prank(jim);
        vm.expectRevert("Option hasn't expired yet");

        oc.claimUnboughtOption();
    }

    function testClaimOptionThatIsntYours() external {
          // Jim will sell an option's contract: he's giving someone the ability to buy his 50 ETH at 1.8k
        vm.prank(jim);
        oc.sellCallOption{value: 30 ether}(1800);
        assertEq(IERC20(usdc).balanceOf(jim), 0); // NO USDC TO begin with

        // Bob will buy this options contract, for a 0.5 ether premium
        vm.prank(bob);
        oc.buyCallOption{value: 9e17}(jim);
        assertEq(address(jim).balance, 70 ether + 0.9 ether); // check Jim got his premium


        // alice didn't buy.. Bob did
        vm.prank(alice);
        vm.expectRevert("You didn't buy this option");
        oc.exerciseOption(jim, usdc);
    }


    function testClaimOptionTwice() external {
                // Jim will sell an option's contract: he's giving someone the ability to buy his 50 ETH at 1.8k
        vm.prank(jim);
        oc.sellCallOption{value: 30 ether}(1800);

        // Bob will buy this options contract, for a 0.5 ether premium
        vm.prank(bob);
        oc.buyCallOption{value: 9e17}(jim);

        // Exercises option
        vm.warp(block.timestamp + 15 days);
        vm.prank(bob);
        IERC20(usdc).approve(address(oc), 1800 * 1e6 * 30);
        vm.prank(bob);
        oc.exerciseOption(jim, usdc);

        // Exercises it again
        vm.expectRevert("You didn't buy this option");
        oc.exerciseOption(jim, usdc);

    }
}
