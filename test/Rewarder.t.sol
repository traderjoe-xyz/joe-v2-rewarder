// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "murky/Merkle.sol";
import "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../src/Rewarder.sol";
import "./mocks/MockERC20.sol";

contract RewarderTest is Test {
    Merkle public merkle;

    Rewarder public implementation;
    Rewarder public rewarder; // proxy

    address public constant MARKET_A = address(bytes20(keccak256("MARKET_A")));
    address public constant MARKET_B = address(bytes20(keccak256("MARKET_B")));
    address public constant MARKET_C = address(bytes20(keccak256("MARKET_C")));

    MockERC20 public immutable TOKEN_A = new MockERC20("TOKEN A", "TKA");
    MockERC20 public immutable TOKEN_B = new MockERC20("TOKEN B", "TKB");

    address public constant OWNER = address(bytes20(keccak256("OWNER")));
    address public constant PROXY_OWNER = address(bytes20(keccak256("PROXY_OWNER")));
    address public constant ALICE = address(bytes20(keccak256("ALICE")));
    address public constant BOB = address(bytes20(keccak256("BOB")));
    address public constant CAROL = address(bytes20(keccak256("CAROL")));

    function setUp() public {
        vm.startPrank(OWNER);

        merkle = new Merkle();
        implementation = new Rewarder();

        rewarder = Rewarder(payable(address(new TransparentUpgradeableProxy(address(implementation), PROXY_OWNER, ""))));
        rewarder.initialize();

        vm.stopPrank();
    }

    function testForWhitelistedMarkets() public {
        vm.startPrank(OWNER);
        assertEq(rewarder.getNumberOfWhitelistedMarkets(), 0);
        assertEq(rewarder.isWhitelistedMarket(MARKET_A), false);
        assertEq(rewarder.isWhitelistedMarket(MARKET_B), false);
        assertEq(rewarder.isWhitelistedMarket(MARKET_C), false);

        rewarder.addMarketToWhitelist(MARKET_A);

        assertEq(rewarder.getNumberOfWhitelistedMarkets(), 1);
        assertEq(rewarder.getWhitelistedMarket(0), MARKET_A);
        assertEq(rewarder.isWhitelistedMarket(MARKET_A), true);
        assertEq(rewarder.isWhitelistedMarket(MARKET_B), false);
        assertEq(rewarder.isWhitelistedMarket(MARKET_C), false);

        rewarder.addMarketToWhitelist(MARKET_B);

        assertEq(rewarder.getNumberOfWhitelistedMarkets(), 2);
        assertEq(rewarder.getWhitelistedMarket(0), MARKET_A);
        assertEq(rewarder.getWhitelistedMarket(1), MARKET_B);
        assertEq(rewarder.isWhitelistedMarket(MARKET_A), true);
        assertEq(rewarder.isWhitelistedMarket(MARKET_B), true);
        assertEq(rewarder.isWhitelistedMarket(MARKET_C), false);

        rewarder.addMarketToWhitelist(MARKET_C);

        assertEq(rewarder.getNumberOfWhitelistedMarkets(), 3);
        assertEq(rewarder.getWhitelistedMarket(0), MARKET_A);
        assertEq(rewarder.getWhitelistedMarket(1), MARKET_B);
        assertEq(rewarder.getWhitelistedMarket(2), MARKET_C);
        assertEq(rewarder.isWhitelistedMarket(MARKET_A), true);
        assertEq(rewarder.isWhitelistedMarket(MARKET_B), true);
        assertEq(rewarder.isWhitelistedMarket(MARKET_C), true);

        rewarder.removeMarketFromWhitelist(MARKET_B);

        assertEq(rewarder.getNumberOfWhitelistedMarkets(), 2);
        assertEq(rewarder.getWhitelistedMarket(0), MARKET_A);
        assertEq(rewarder.getWhitelistedMarket(1), MARKET_C);
        assertEq(rewarder.isWhitelistedMarket(MARKET_A), true);
        assertEq(rewarder.isWhitelistedMarket(MARKET_B), false);
        assertEq(rewarder.isWhitelistedMarket(MARKET_C), true);

        rewarder.removeMarketFromWhitelist(MARKET_A);

        assertEq(rewarder.getNumberOfWhitelistedMarkets(), 1);
        assertEq(rewarder.getWhitelistedMarket(0), MARKET_C);
        assertEq(rewarder.isWhitelistedMarket(MARKET_A), false);
        assertEq(rewarder.isWhitelistedMarket(MARKET_B), false);
        assertEq(rewarder.isWhitelistedMarket(MARKET_C), true);

        rewarder.removeMarketFromWhitelist(MARKET_C);

        assertEq(rewarder.getNumberOfWhitelistedMarkets(), 0);
        assertEq(rewarder.isWhitelistedMarket(MARKET_A), false);
        assertEq(rewarder.isWhitelistedMarket(MARKET_B), false);
        assertEq(rewarder.isWhitelistedMarket(MARKET_C), false);
        vm.stopPrank();
    }

    function testGetVestingPeriodAtEpoch() public {
        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);
        rewarder.setNewEpoch(MARKET_A, 0, 10, 20, bytes32(uint256(1)));
        rewarder.setNewEpoch(MARKET_A, 1, 30, 20, bytes32(uint256(2)));
        rewarder.setNewEpoch(MARKET_A, 2, 50, 20, bytes32(uint256(3)));

        rewarder.addMarketToWhitelist(MARKET_B);
        rewarder.setNewEpoch(MARKET_B, 0, 10, 10, bytes32(uint256(1)));
        rewarder.setNewEpoch(MARKET_B, 1, 30, 5, bytes32(uint256(2)));
        rewarder.setNewEpoch(MARKET_B, 2, 50, 500, bytes32(uint256(3)));
        vm.stopPrank();

        (uint256 start, uint256 duration) = rewarder.getVestingPeriodAtEpoch(MARKET_A, 0);
        assertEq(start, 10);
        assertEq(duration, 20);

        (start, duration) = rewarder.getVestingPeriodAtEpoch(MARKET_A, 1);
        assertEq(start, 30);
        assertEq(duration, 20);

        (start, duration) = rewarder.getVestingPeriodAtEpoch(MARKET_A, 2);
        assertEq(start, 50);
        assertEq(duration, 20);

        (start, duration) = rewarder.getVestingPeriodAtEpoch(MARKET_B, 0);
        assertEq(start, 10);
        assertEq(duration, 10);

        (start, duration) = rewarder.getVestingPeriodAtEpoch(MARKET_B, 1);
        assertEq(start, 30);
        assertEq(duration, 5);

        (start, duration) = rewarder.getVestingPeriodAtEpoch(MARKET_B, 2);
        assertEq(start, 50);
        assertEq(duration, 500);

        vm.expectRevert();
        rewarder.getVestingPeriodAtEpoch(MARKET_A, 3);

        vm.expectRevert();
        rewarder.getVestingPeriodAtEpoch(MARKET_B, 3);

        vm.prank(OWNER);
        rewarder.cancelEpoch(MARKET_A, 2);

        (start, duration) = rewarder.getVestingPeriodAtEpoch(MARKET_A, 2);
        assertEq(start, 0);
        assertEq(duration, 0);
    }

    function testSetNewEpoch() public {
        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        assertEq(rewarder.getNumberOfEpochs(MARKET_A), 0);

        rewarder.setNewEpoch(MARKET_A, 0, 10, 20, bytes32(uint256(1)));

        assertEq(rewarder.getNumberOfEpochs(MARKET_A), 1);
        assertEq(rewarder.getRootAtEpoch(MARKET_A, 0), bytes32(uint256(1)));

        assertEq(rewarder.getNumberOfEpochs(MARKET_B), 0);
        rewarder.getRootAtEpoch(MARKET_A, 0);

        vm.stopPrank();
    }

    function testSetNewEpochRevertsForNonWhitelistedMarket() public {
        vm.expectRevert(IRewarder.Rewarder__MarketNotWhitelisted.selector);
        vm.prank(OWNER);
        rewarder.setNewEpoch(MARKET_A, 0, 10, 20, bytes32(uint256(1)));
    }

    function testVerify() public {
        uint256 epoch = 0;
        uint256 start = 100;
        uint256 duration = 50;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, IERC20Upgradeable(TOKEN_A), ALICE, 100);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, IERC20Upgradeable(TOKEN_B), BOB, 200);

        bytes32 root = merkle.getRoot(leaves);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, root);
        vm.stopPrank();

        bytes32[] memory proof0 = merkle.getProof(leaves, 0);
        bytes32[] memory proof1 = merkle.getProof(leaves, 1);

        assertTrue(rewarder.verify(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE, 100, proof0));
        assertTrue(rewarder.verify(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB, 200, proof1));

        assertFalse(rewarder.verify(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE, 200, proof0));
        assertFalse(rewarder.verify(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB, 100, proof1));

        assertFalse(rewarder.verify(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE, 100, proof1));
        assertFalse(rewarder.verify(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB, 200, proof0));
    }

    function testClaim() public {
        uint256 epoch = 0;
        uint256 start = 100;
        uint256 duration = 50;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, IERC20Upgradeable(TOKEN_A), ALICE, 100);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, IERC20Upgradeable(TOKEN_B), BOB, 200);

        bytes32 root = merkle.getRoot(leaves);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        TOKEN_A.mint(address(rewarder), 100);
        TOKEN_B.mint(address(rewarder), 200);

        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, root);
        vm.stopPrank();

        bytes32[] memory proof0 = merkle.getProof(leaves, 0);
        bytes32[] memory proof1 = merkle.getProof(leaves, 1);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), 100, proof0);

        assertEq(TOKEN_A.balanceOf(ALICE), 0);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE), 0);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE, 100, proof0), 0);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), 200, proof1);

        assertEq(TOKEN_B.balanceOf(BOB), 0);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB), 0);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB, 200, proof1), 0);

        vm.warp(start + 1);

        uint256 releasableAlice = (100 * (block.timestamp - start)) / duration;
        assertEq(
            rewarder.getReleasableAmount(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE, 100, proof0),
            releasableAlice
        );

        uint256 releasableBob = (200 * (block.timestamp - start)) / duration;
        assertEq(
            rewarder.getReleasableAmount(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB, 200, proof1), releasableBob
        );

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), 100, proof0);

        assertEq(TOKEN_A.balanceOf(ALICE), releasableAlice);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE), releasableAlice);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE, 100, proof0), 0);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), 200, proof1);

        assertEq(TOKEN_B.balanceOf(BOB), releasableBob);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB), releasableBob);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB, 200, proof1), 0);

        vm.warp(start + duration);

        assertEq(
            rewarder.getReleasableAmount(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE, 100, proof0),
            100 - releasableAlice
        );
        assertEq(
            rewarder.getReleasableAmount(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB, 200, proof1),
            200 - releasableBob
        );

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), 100, proof0);

        assertEq(TOKEN_A.balanceOf(ALICE), 100);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE), 100);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE, 100, proof0), 0);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), 200, proof1);

        assertEq(TOKEN_B.balanceOf(BOB), 200);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB), 200);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB, 200, proof1), 0);

        vm.warp(start + duration + 1);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), 100, proof0);

        assertEq(TOKEN_A.balanceOf(ALICE), 100);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE), 100);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE, 100, proof0), 0);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), 200, proof1);

        assertEq(TOKEN_B.balanceOf(BOB), 200);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB), 200);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB, 200, proof1), 0);
    }

    function testGetReleasableAmountWithWrongProof() public {
        uint256 epoch = 0;
        uint256 start = 100;
        uint256 duration = 50;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, IERC20Upgradeable(TOKEN_A), ALICE, 100);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, IERC20Upgradeable(TOKEN_B), BOB, 200);

        bytes32 root = merkle.getRoot(leaves);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);
        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, root);
        vm.stopPrank();

        bytes32[] memory proof0 = merkle.getProof(leaves, 0);
        bytes32[] memory proof1 = merkle.getProof(leaves, 1);

        vm.warp(start + 1);

        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE, 100, proof1), 0);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB, 200, proof0), 0);
    }

    function testClaimNative() public {
        uint256 epoch = 0;
        uint256 start = 100;
        uint256 duration = 50;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, IERC20Upgradeable(address(0)), ALICE, 100);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, IERC20Upgradeable(address(0)), BOB, 200);

        bytes32 root = merkle.getRoot(leaves);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, root);
        vm.stopPrank();

        bytes32[] memory proof0 = merkle.getProof(leaves, 0);
        bytes32[] memory proof1 = merkle.getProof(leaves, 1);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(address(0)), 100, proof0);
        assertEq(address(ALICE).balance, 0);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(address(0)), ALICE), 0);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(address(0)), 200, proof1);
        assertEq(address(BOB).balance, 0);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(address(0)), BOB), 0);

        vm.warp(start + 1);

        vm.expectRevert(IRewarder.Rewarder__NativeTransferFailed.selector);
        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(address(0)), 100, proof0);

        vm.deal(address(rewarder), 1e18);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(address(0)), 100, proof0);
        assertEq(address(ALICE).balance, (100 * (block.timestamp - start)) / duration);
        assertEq(
            rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(address(0)), ALICE),
            (100 * (block.timestamp - start)) / duration
        );

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(address(0)), 200, proof1);
        assertEq(address(BOB).balance, (200 * (block.timestamp - start)) / duration);
        assertEq(
            rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(address(0)), BOB),
            (200 * (block.timestamp - start)) / duration
        );

        vm.warp(start + duration);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(address(0)), 100, proof0);
        assertEq(address(ALICE).balance, 100);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(address(0)), ALICE), 100);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(address(0)), 200, proof1);
        assertEq(address(BOB).balance, 200);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(address(0)), BOB), 200);

        vm.warp(start + duration + 1);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(address(0)), 100, proof0);
        assertEq(address(ALICE).balance, 100);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(address(0)), ALICE), 100);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(address(0)), 200, proof1);
        assertEq(address(BOB).balance, 200);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(address(0)), BOB), 200);
    }

    function testClaimFor() public {
        uint256 epoch = 0;
        uint256 start = 100;
        uint256 duration = 50;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, IERC20Upgradeable(TOKEN_A), ALICE, 100);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, IERC20Upgradeable(TOKEN_B), BOB, 200);

        bytes32 root = merkle.getRoot(leaves);

        TOKEN_A.mint(address(rewarder), 1000);
        TOKEN_B.mint(address(rewarder), 2000);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);
        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, root);

        rewarder.grantRole(rewarder.CLAIMER_ROLE(), CAROL);
        vm.stopPrank();

        bytes32[] memory proof0 = merkle.getProof(leaves, 0);
        bytes32[] memory proof1 = merkle.getProof(leaves, 1);

        vm.warp(start + duration);

        vm.prank(CAROL);
        rewarder.claimFor(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE, 100, proof0);
        assertEq(IERC20Upgradeable(TOKEN_A).balanceOf(ALICE), 100);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE), 100);

        vm.prank(CAROL);
        rewarder.claimFor(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB, 200, proof1);
        assertEq(IERC20Upgradeable(TOKEN_B).balanceOf(BOB), 200);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB), 200);

        vm.warp(start + duration + 1);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), 100, proof0);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), 200, proof1);

        vm.warp(start + duration + 2);

        vm.prank(CAROL);
        rewarder.claimFor(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE, 100, proof0);

        assertEq(IERC20Upgradeable(TOKEN_A).balanceOf(ALICE), 100);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE), 100);

        vm.prank(CAROL);
        rewarder.claimFor(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB, 200, proof1);

        assertEq(IERC20Upgradeable(TOKEN_B).balanceOf(BOB), 200);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB), 200);
    }

    function testBatchFunctions() public {
        uint256 epoch = 0;
        uint256 start = 100;
        uint256 duration = 50;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, IERC20Upgradeable(TOKEN_A), ALICE, 100);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, IERC20Upgradeable(TOKEN_B), ALICE, 200);

        bytes32 root = merkle.getRoot(leaves);

        TOKEN_A.mint(address(rewarder), 1000);
        TOKEN_B.mint(address(rewarder), 2000);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, root);
        vm.stopPrank();

        IRewarder.MarketData[] memory marketData = new IRewarder.MarketData[](2);

        marketData[0] = IRewarder.MarketData(MARKET_A, epoch, TOKEN_A);
        marketData[1] = IRewarder.MarketData(MARKET_A, epoch, TOKEN_B);

        address[] memory accounts = new address[](2);

        accounts[0] = ALICE;
        accounts[1] = ALICE;

        uint256[] memory amounts = new uint256[](2);

        amounts[0] = 100;
        amounts[1] = 200;

        bytes32[][] memory proofs = new bytes32[][](2);

        proofs[0] = merkle.getProof(leaves, 0);
        proofs[1] = merkle.getProof(leaves, 1);

        vm.warp(start + 1);

        uint256[] memory releasable = rewarder.getBatchReleasableAmounts(marketData, accounts, amounts, proofs);

        assertEq(releasable[0], 100 * (block.timestamp - start) / duration);
        assertEq(releasable[1], 200 * (block.timestamp - start) / duration);

        vm.prank(ALICE);
        rewarder.batchClaim(marketData, amounts, proofs);

        assertEq(IERC20Upgradeable(TOKEN_A).balanceOf(ALICE), 100 * (block.timestamp - start) / duration);
        assertEq(IERC20Upgradeable(TOKEN_B).balanceOf(ALICE), 200 * (block.timestamp - start) / duration);

        assertEq(
            rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE),
            100 * (block.timestamp - start) / duration
        );
        assertEq(
            rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), ALICE),
            200 * (block.timestamp - start) / duration
        );

        vm.warp(start + duration);

        releasable = rewarder.getBatchReleasableAmounts(marketData, accounts, amounts, proofs);

        assertEq(releasable[0], 98);
        assertEq(releasable[1], 196);

        vm.prank(ALICE);
        rewarder.batchClaim(marketData, amounts, proofs);

        assertEq(IERC20Upgradeable(TOKEN_A).balanceOf(ALICE), 100);
        assertEq(IERC20Upgradeable(TOKEN_B).balanceOf(ALICE), 200);

        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE), 100);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), ALICE), 200);

        vm.warp(start + duration + 1);

        releasable = rewarder.getBatchReleasableAmounts(marketData, accounts, amounts, proofs);

        assertEq(releasable[0], 0);
        assertEq(releasable[1], 0);

        vm.prank(ALICE);
        rewarder.batchClaim(marketData, amounts, proofs);

        assertEq(IERC20Upgradeable(TOKEN_A).balanceOf(ALICE), 100);
        assertEq(IERC20Upgradeable(TOKEN_B).balanceOf(ALICE), 200);

        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE), 100);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), ALICE), 200);
    }

    function testPauseFunctions() public {
        uint256 epoch = 0;
        uint256 start = 100;
        uint256 duration = 50;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, IERC20Upgradeable(TOKEN_A), ALICE, 100);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, IERC20Upgradeable(TOKEN_B), ALICE, 200);

        bytes32 root = merkle.getRoot(leaves);

        TOKEN_A.mint(address(rewarder), 1000);
        TOKEN_B.mint(address(rewarder), 2000);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, root);
        vm.stopPrank();

        bytes32[][] memory proofs = new bytes32[][](2);

        proofs[0] = merkle.getProof(leaves, 0);
        proofs[1] = merkle.getProof(leaves, 1);

        vm.warp(start + duration + 1);

        vm.prank(OWNER);
        rewarder.pause();

        vm.expectRevert("Pausable: paused");
        vm.prank(OWNER);
        rewarder.pause();

        vm.expectRevert("Pausable: paused");
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), 100, proofs[0]);

        vm.expectRevert("Pausable: paused");
        rewarder.batchClaim(new IRewarder.MarketData[](0), new uint256[](0), new bytes32[][](0));

        vm.expectRevert("Pausable: paused");
        rewarder.claimFor(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE, 100, proofs[0]);

        vm.prank(OWNER);
        rewarder.unpause();

        vm.expectRevert("Pausable: not paused");
        vm.prank(OWNER);
        rewarder.unpause();

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), 100, proofs[0]);

        assertEq(IERC20Upgradeable(TOKEN_A).balanceOf(ALICE), 100);
    }

    function testBatchFunctionsRevertForInvalidLength() public {
        vm.expectRevert(IRewarder.Rewarder__InvalidLength.selector);
        rewarder.getBatchReleasableAmounts(
            new IRewarder.MarketData[](0), new address[](2), new uint256[](2), new bytes32[][](2)
        );

        vm.expectRevert(IRewarder.Rewarder__InvalidLength.selector);
        rewarder.getBatchReleasableAmounts(
            new IRewarder.MarketData[](1), new address[](2), new uint256[](2), new bytes32[][](2)
        );

        vm.expectRevert(IRewarder.Rewarder__InvalidLength.selector);
        rewarder.getBatchReleasableAmounts(
            new IRewarder.MarketData[](2), new address[](1), new uint256[](2), new bytes32[][](2)
        );

        vm.expectRevert(IRewarder.Rewarder__InvalidLength.selector);
        rewarder.getBatchReleasableAmounts(
            new IRewarder.MarketData[](2), new address[](2), new uint256[](1), new bytes32[][](2)
        );

        vm.expectRevert(IRewarder.Rewarder__InvalidLength.selector);
        rewarder.getBatchReleasableAmounts(
            new IRewarder.MarketData[](2), new address[](2), new uint256[](2), new bytes32[][](1)
        );

        vm.expectRevert(IRewarder.Rewarder__InvalidLength.selector);
        rewarder.batchClaim(new IRewarder.MarketData[](0), new uint256[](2), new bytes32[][](2));

        vm.expectRevert(IRewarder.Rewarder__InvalidLength.selector);
        rewarder.batchClaim(new IRewarder.MarketData[](1), new uint256[](2), new bytes32[][](2));

        vm.expectRevert(IRewarder.Rewarder__InvalidLength.selector);
        rewarder.batchClaim(new IRewarder.MarketData[](2), new uint256[](1), new bytes32[][](2));

        vm.expectRevert(IRewarder.Rewarder__InvalidLength.selector);
        rewarder.batchClaim(new IRewarder.MarketData[](2), new uint256[](2), new bytes32[][](1));
    }

    function testClaimRevertForEpochCanceled() public {
        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);
        rewarder.setNewEpoch(MARKET_A, 0, 10, 10, bytes32(uint256(1)));
        rewarder.cancelEpoch(MARKET_A, 0);
        vm.stopPrank();

        vm.expectRevert(IRewarder.Rewarder__EpochCanceled.selector);
        vm.prank(ALICE);
        rewarder.claim(MARKET_A, 0, IERC20Upgradeable(address(0)), 0, new bytes32[](0));
    }

    function testClaimRevertForInvalidProof() public {
        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);
        rewarder.setNewEpoch(MARKET_A, 0, 10, 10, bytes32(uint256(1)));
        vm.stopPrank();

        vm.expectRevert(IRewarder.Rewarder__InvalidProof.selector);
        vm.prank(ALICE);
        rewarder.claim(MARKET_A, 0, IERC20Upgradeable(address(0)), 0, new bytes32[](0));
    }

    function testSetNewEpochRevertForInvalidRoot() public {
        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        vm.expectRevert(IRewarder.Rewarder__InvalidRoot.selector);
        rewarder.setNewEpoch(MARKET_A, 0, 10, 10, bytes32(uint256(0)));
        vm.stopPrank();
    }

    function testSetNewEpochRevertForInvalidStart() public {
        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        vm.expectRevert(IRewarder.Rewarder__InvalidStart.selector);
        rewarder.setNewEpoch(MARKET_A, 0, 0, 10, bytes32(uint256(1)));

        vm.warp(10);

        vm.expectRevert(IRewarder.Rewarder__InvalidStart.selector);
        rewarder.setNewEpoch(MARKET_A, 0, 9, 10, bytes32(uint256(1)));

        vm.stopPrank();
    }

    function testSetNewEpochRevertForOverlappingEpoch() public {
        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, 0, 10, 10, bytes32(uint256(1)));

        vm.expectRevert(IRewarder.Rewarder__OverlappingEpoch.selector);
        rewarder.setNewEpoch(MARKET_A, 1, 5, 1, bytes32(uint256(1)));

        vm.expectRevert(IRewarder.Rewarder__OverlappingEpoch.selector);
        rewarder.setNewEpoch(MARKET_A, 1, 19, 10, bytes32(uint256(1)));

        vm.expectRevert(IRewarder.Rewarder__OverlappingEpoch.selector);
        rewarder.setNewEpoch(MARKET_A, 1, 11, 9, bytes32(uint256(1)));
        vm.stopPrank();
    }

    function testSetNewEpochRevertForInvalidEpoch() public {
        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        vm.expectRevert(IRewarder.Rewarder__InvalidEpoch.selector);
        rewarder.setNewEpoch(MARKET_A, 1, 10, 10, bytes32(uint256(1)));
        vm.stopPrank();
    }

    function testSetNewEpochForOverlappingEpochAfterCancel() public {
        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, 0, 10, 10, bytes32(uint256(1)));

        vm.expectRevert(IRewarder.Rewarder__OverlappingEpoch.selector);
        rewarder.setNewEpoch(MARKET_A, 1, 10, 50, bytes32(uint256(1)));

        rewarder.cancelEpoch(MARKET_A, 0);

        rewarder.setNewEpoch(MARKET_A, 1, 10, 50, bytes32(uint256(1)));
        vm.stopPrank();
    }

    function testCancelEpochRevertForEpochDoesNotExist() public {
        vm.startPrank(OWNER);
        vm.expectRevert(IRewarder.Rewarder__EpochDoesNotExist.selector);
        rewarder.cancelEpoch(MARKET_A, 0);
        vm.stopPrank();
    }

    function testCancelEpochRevertForOnlyValidLatestEpoch() public {
        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, 0, 10, 10, bytes32(uint256(1)));
        rewarder.setNewEpoch(MARKET_A, 1, 20, 10, bytes32(uint256(2)));
        rewarder.setNewEpoch(MARKET_A, 2, 30, 10, bytes32(uint256(3)));

        vm.expectRevert(IRewarder.Rewarder__OnlyValidLatestEpoch.selector);
        rewarder.cancelEpoch(MARKET_A, 0);

        vm.expectRevert(IRewarder.Rewarder__OnlyValidLatestEpoch.selector);
        rewarder.cancelEpoch(MARKET_A, 1);

        rewarder.cancelEpoch(MARKET_A, 2);

        vm.expectRevert(IRewarder.Rewarder__OnlyValidLatestEpoch.selector);
        rewarder.cancelEpoch(MARKET_A, 0);

        rewarder.cancelEpoch(MARKET_A, 1);
        rewarder.cancelEpoch(MARKET_A, 0);

        vm.stopPrank();
    }

    function testWhitelistMarketRevertForDuplicateMarket() public {
        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        vm.expectRevert(IRewarder.Rewarder__MarketAlreadyWhitelisted.selector);
        rewarder.addMarketToWhitelist(MARKET_A);
        vm.stopPrank();
    }

    function testUnwhitelistMarketRevertForDuplicateMarket() public {
        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        vm.expectRevert(IRewarder.Rewarder__MarketNotWhitelisted.selector);
        rewarder.removeMarketFromWhitelist(MARKET_B);
        vm.stopPrank();
    }

    function testOwnerFunctionRevertForNonOwner() public {
        vm.startPrank(ALICE);

        vm.expectRevert("Ownable: caller is not the owner");
        rewarder.setNewEpoch(MARKET_A, 0, 10, 10, bytes32(uint256(1)));

        vm.expectRevert("Ownable: caller is not the owner");
        rewarder.cancelEpoch(MARKET_A, 0);

        vm.expectRevert("Ownable: caller is not the owner");
        rewarder.addMarketToWhitelist(MARKET_A);

        vm.expectRevert("Ownable: caller is not the owner");
        rewarder.removeMarketFromWhitelist(MARKET_A);

        vm.stopPrank();
    }

    function testInitializeTwice() public {
        vm.startPrank(OWNER);

        // Redeploy it orelse coverage will complain
        rewarder = Rewarder(payable(address(new TransparentUpgradeableProxy(address(implementation), PROXY_OWNER, ""))));
        rewarder.initialize();

        vm.expectRevert("Initializable: contract is already initialized");
        rewarder.initialize();

        vm.stopPrank();
    }

    function getLeaf(
        address market,
        uint256 epoch,
        uint256 start,
        uint256 duration,
        IERC20Upgradeable token,
        address user,
        uint256 amount
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(market, epoch, start, duration, token, user, amount));
    }
}
