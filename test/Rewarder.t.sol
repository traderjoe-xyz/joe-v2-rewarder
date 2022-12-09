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

    IERC20Upgradeable public constant NATIVE = IERC20Upgradeable(address(0));
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
        rewarder.initialize(1 days);

        vm.stopPrank();
    }

    function testForWhitelistedMarkets() public {
        vm.startPrank(OWNER);
        assertEq(rewarder.getNumberOfWhitelistedMarkets(), 0);
        assertEq(rewarder.isMarketWhitelisted(MARKET_A), false);
        assertEq(rewarder.isMarketWhitelisted(MARKET_B), false);
        assertEq(rewarder.isMarketWhitelisted(MARKET_C), false);

        rewarder.addMarketToWhitelist(MARKET_A);

        assertEq(rewarder.getNumberOfWhitelistedMarkets(), 1);
        assertEq(rewarder.getWhitelistedMarket(0), MARKET_A);
        assertEq(rewarder.isMarketWhitelisted(MARKET_A), true);
        assertEq(rewarder.isMarketWhitelisted(MARKET_B), false);
        assertEq(rewarder.isMarketWhitelisted(MARKET_C), false);

        rewarder.addMarketToWhitelist(MARKET_B);

        assertEq(rewarder.getNumberOfWhitelistedMarkets(), 2);
        assertEq(rewarder.getWhitelistedMarket(0), MARKET_A);
        assertEq(rewarder.getWhitelistedMarket(1), MARKET_B);
        assertEq(rewarder.isMarketWhitelisted(MARKET_A), true);
        assertEq(rewarder.isMarketWhitelisted(MARKET_B), true);
        assertEq(rewarder.isMarketWhitelisted(MARKET_C), false);

        rewarder.addMarketToWhitelist(MARKET_C);

        assertEq(rewarder.getNumberOfWhitelistedMarkets(), 3);
        assertEq(rewarder.getWhitelistedMarket(0), MARKET_A);
        assertEq(rewarder.getWhitelistedMarket(1), MARKET_B);
        assertEq(rewarder.getWhitelistedMarket(2), MARKET_C);
        assertEq(rewarder.isMarketWhitelisted(MARKET_A), true);
        assertEq(rewarder.isMarketWhitelisted(MARKET_B), true);
        assertEq(rewarder.isMarketWhitelisted(MARKET_C), true);

        rewarder.removeMarketFromWhitelist(MARKET_B);

        assertEq(rewarder.getNumberOfWhitelistedMarkets(), 2);
        assertEq(rewarder.getWhitelistedMarket(0), MARKET_A);
        assertEq(rewarder.getWhitelistedMarket(1), MARKET_C);
        assertEq(rewarder.isMarketWhitelisted(MARKET_A), true);
        assertEq(rewarder.isMarketWhitelisted(MARKET_B), false);
        assertEq(rewarder.isMarketWhitelisted(MARKET_C), true);

        rewarder.removeMarketFromWhitelist(MARKET_A);

        assertEq(rewarder.getNumberOfWhitelistedMarkets(), 1);
        assertEq(rewarder.getWhitelistedMarket(0), MARKET_C);
        assertEq(rewarder.isMarketWhitelisted(MARKET_A), false);
        assertEq(rewarder.isMarketWhitelisted(MARKET_B), false);
        assertEq(rewarder.isMarketWhitelisted(MARKET_C), true);

        rewarder.removeMarketFromWhitelist(MARKET_C);

        assertEq(rewarder.getNumberOfWhitelistedMarkets(), 0);
        assertEq(rewarder.isMarketWhitelisted(MARKET_A), false);
        assertEq(rewarder.isMarketWhitelisted(MARKET_B), false);
        assertEq(rewarder.isMarketWhitelisted(MARKET_C), false);
        vm.stopPrank();
    }

    function testGetVestingPeriodAtEpoch() public {
        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](1);
        uint256[] memory amounts = new uint256[](1);

        tokens[0] = TOKEN_A;
        amounts[0] = 100;

        TOKEN_A.mint(address(rewarder), 600);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);
        rewarder.setNewEpoch(MARKET_A, 0, 10, 20, tokens, amounts, bytes32(uint256(1)));
        rewarder.setNewEpoch(MARKET_A, 1, 30, 20, tokens, amounts, bytes32(uint256(2)));
        rewarder.setNewEpoch(MARKET_A, 2, 50, 20, tokens, amounts, bytes32(uint256(3)));

        rewarder.addMarketToWhitelist(MARKET_B);
        rewarder.setNewEpoch(MARKET_B, 0, 10, 10, tokens, amounts, bytes32(uint256(1)));
        rewarder.setNewEpoch(MARKET_B, 1, 30, 5, tokens, amounts, bytes32(uint256(2)));
        rewarder.setNewEpoch(MARKET_B, 2, 50, 500, tokens, amounts, bytes32(uint256(3)));
        vm.stopPrank();

        IRewarder.EpochParameters memory params = rewarder.getEpochParameters(MARKET_A, 0);
        assertEq(params.start, 10);
        assertEq(params.duration, 20);
        assertEq(params.root, bytes32(uint256(1)));

        params = rewarder.getEpochParameters(MARKET_A, 1);
        assertEq(params.start, 30);
        assertEq(params.duration, 20);
        assertEq(params.root, bytes32(uint256(2)));

        params = rewarder.getEpochParameters(MARKET_A, 2);
        assertEq(params.start, 50);
        assertEq(params.duration, 20);
        assertEq(params.root, bytes32(uint256(3)));

        params = rewarder.getEpochParameters(MARKET_B, 0);
        assertEq(params.start, 10);
        assertEq(params.duration, 10);

        params = rewarder.getEpochParameters(MARKET_B, 1);
        assertEq(params.start, 30);
        assertEq(params.duration, 5);
        assertEq(params.root, bytes32(uint256(2)));

        params = rewarder.getEpochParameters(MARKET_B, 2);
        assertEq(params.start, 50);
        assertEq(params.duration, 500);
        assertEq(params.root, bytes32(uint256(3)));

        vm.expectRevert();
        rewarder.getEpochParameters(MARKET_A, 3);

        vm.expectRevert();
        rewarder.getEpochParameters(MARKET_B, 3);

        vm.prank(OWNER);
        rewarder.cancelEpoch(MARKET_A, 2);

        params = rewarder.getEpochParameters(MARKET_A, 2);
        assertEq(params.start, 0);
        assertEq(params.duration, 0);
        assertEq(params.root, bytes32(uint256(0)));
    }

    function testSetNewEpoch() public {
        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](1);
        uint256[] memory amounts = new uint256[](1);

        tokens[0] = TOKEN_A;
        amounts[0] = 100;

        TOKEN_A.mint(address(rewarder), 100);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        assertEq(rewarder.getNumberOfEpochs(MARKET_A), 0);

        rewarder.setNewEpoch(MARKET_A, 0, 10, 20, tokens, amounts, bytes32(uint256(1)));

        assertEq(rewarder.getNumberOfEpochs(MARKET_A), 1);

        IRewarder.EpochParameters memory params = rewarder.getEpochParameters(MARKET_A, 0);
        assertEq(params.start, 10);
        assertEq(params.duration, 20);
        assertEq(params.root, bytes32(uint256(1)));

        assertEq(rewarder.getNumberOfEpochs(MARKET_B), 0);

        vm.stopPrank();
    }

    function testVerify() public {
        uint256 epoch = 0;
        uint128 start = 100;
        uint128 duration = 50;

        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](2);

        tokens[0] = IERC20Upgradeable(TOKEN_A);
        tokens[1] = IERC20Upgradeable(TOKEN_B);

        uint256[] memory amounts = new uint256[](2);

        amounts[0] = 100;
        amounts[1] = 200;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, tokens[0], ALICE, amounts[0]);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, tokens[1], BOB, amounts[1]);

        bytes32 root = merkle.getRoot(leaves);

        TOKEN_A.mint(address(rewarder), 100);
        TOKEN_B.mint(address(rewarder), 200);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, tokens, amounts, root);
        vm.stopPrank();

        bytes32[] memory proof0 = merkle.getProof(leaves, 0);
        bytes32[] memory proof1 = merkle.getProof(leaves, 1);

        assertTrue(rewarder.verify(MARKET_A, epoch, tokens[0], ALICE, amounts[0], proof0));
        assertTrue(rewarder.verify(MARKET_A, epoch, tokens[1], BOB, amounts[1], proof1));

        assertFalse(rewarder.verify(MARKET_A, epoch, tokens[0], ALICE, amounts[1], proof0));
        assertFalse(rewarder.verify(MARKET_A, epoch, tokens[1], BOB, amounts[0], proof1));

        assertFalse(rewarder.verify(MARKET_A, epoch, tokens[0], ALICE, amounts[0], proof1));
        assertFalse(rewarder.verify(MARKET_A, epoch, tokens[1], BOB, amounts[1], proof0));
    }

    function testClaim() public {
        uint256 epoch = 0;
        uint128 start = 100;
        uint128 duration = 50;

        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](2);
        tokens[0] = IERC20Upgradeable(TOKEN_A);
        tokens[1] = IERC20Upgradeable(TOKEN_B);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, tokens[0], ALICE, amounts[0]);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, tokens[1], BOB, amounts[1]);

        bytes32 root = merkle.getRoot(leaves);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        TOKEN_A.mint(address(rewarder), 100);
        TOKEN_B.mint(address(rewarder), 200);

        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, tokens, amounts, root);
        vm.stopPrank();

        bytes32[] memory proof0 = merkle.getProof(leaves, 0);
        bytes32[] memory proof1 = merkle.getProof(leaves, 1);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, tokens[0], amounts[0], proof0);

        assertEq(TOKEN_A.balanceOf(ALICE), 0);
        assertEq(rewarder.getReleased(MARKET_A, epoch, tokens[0], ALICE), 0);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, tokens[0], ALICE, amounts[0], proof0), 0);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, tokens[1], amounts[1], proof1);

        assertEq(TOKEN_B.balanceOf(BOB), 0);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB), 0);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, tokens[1], BOB, amounts[1], proof1), 0);

        vm.warp(start + 1);

        uint256 releasableAlice = (100 * (block.timestamp - start)) / duration;
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, tokens[0], ALICE, amounts[0], proof0), releasableAlice);

        uint256 releasableBob = (200 * (block.timestamp - start)) / duration;
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, tokens[1], BOB, amounts[1], proof1), releasableBob);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, tokens[0], amounts[0], proof0);

        assertEq(TOKEN_A.balanceOf(ALICE), releasableAlice);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE), releasableAlice);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, tokens[0], ALICE, amounts[0], proof0), 0);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, tokens[1], amounts[1], proof1);

        assertEq(TOKEN_B.balanceOf(BOB), releasableBob);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB), releasableBob);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, tokens[1], BOB, amounts[1], proof1), 0);

        vm.warp(start + duration);

        assertEq(
            rewarder.getReleasableAmount(MARKET_A, epoch, tokens[0], ALICE, amounts[0], proof0), 100 - releasableAlice
        );
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, tokens[1], BOB, amounts[1], proof1), 200 - releasableBob);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, tokens[0], amounts[0], proof0);

        assertEq(TOKEN_A.balanceOf(ALICE), 100);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE), 100);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, tokens[0], ALICE, amounts[0], proof0), 0);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, tokens[1], amounts[1], proof1);

        assertEq(TOKEN_B.balanceOf(BOB), 200);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB), 200);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, tokens[1], BOB, amounts[1], proof1), 0);

        vm.warp(start + duration + 1);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, tokens[0], amounts[0], proof0);

        assertEq(TOKEN_A.balanceOf(ALICE), 100);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE), 100);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, tokens[0], ALICE, amounts[0], proof0), 0);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, tokens[1], amounts[1], proof1);

        assertEq(TOKEN_B.balanceOf(BOB), 200);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), BOB), 200);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, tokens[1], BOB, amounts[1], proof1), 0);
    }

    function testGetReleasableAmountWithWrongProof() public {
        uint256 epoch = 0;
        uint128 start = 100;
        uint128 duration = 50;

        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](2);
        tokens[0] = IERC20Upgradeable(TOKEN_A);
        tokens[1] = IERC20Upgradeable(TOKEN_B);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, tokens[0], ALICE, amounts[0]);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, tokens[1], BOB, amounts[1]);

        bytes32 root = merkle.getRoot(leaves);

        TOKEN_A.mint(address(rewarder), 100);
        TOKEN_B.mint(address(rewarder), 200);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);
        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, tokens, amounts, root);
        vm.stopPrank();

        bytes32[] memory proof0 = merkle.getProof(leaves, 0);
        bytes32[] memory proof1 = merkle.getProof(leaves, 1);

        vm.warp(start + 1);

        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, tokens[0], ALICE, amounts[0], proof1), 0);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, tokens[1], BOB, amounts[1], proof0), 0);
    }

    function testClaimNative() public {
        uint256 epoch = 0;
        uint128 start = 100;
        uint128 duration = 50;

        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](1);
        tokens[0] = NATIVE;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 300;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, NATIVE, ALICE, 100);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, NATIVE, BOB, 200);

        bytes32 root = merkle.getRoot(leaves);

        vm.deal(address(rewarder), 300);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, tokens, amounts, root);
        vm.stopPrank();

        bytes32[] memory proof0 = merkle.getProof(leaves, 0);
        bytes32[] memory proof1 = merkle.getProof(leaves, 1);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, NATIVE, 100, proof0);
        assertEq(address(ALICE).balance, 0);
        assertEq(rewarder.getReleased(MARKET_A, epoch, NATIVE, ALICE), 0);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, NATIVE, 200, proof1);
        assertEq(address(BOB).balance, 0);
        assertEq(rewarder.getReleased(MARKET_A, epoch, NATIVE, BOB), 0);

        vm.warp(start + 1);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, NATIVE, 100, proof0);
        assertEq(address(ALICE).balance, (100 * (block.timestamp - start)) / duration);
        assertEq(rewarder.getReleased(MARKET_A, epoch, NATIVE, ALICE), (100 * (block.timestamp - start)) / duration);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, NATIVE, 200, proof1);
        assertEq(address(BOB).balance, (200 * (block.timestamp - start)) / duration);
        assertEq(rewarder.getReleased(MARKET_A, epoch, NATIVE, BOB), (200 * (block.timestamp - start)) / duration);

        vm.warp(start + duration);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, NATIVE, 100, proof0);
        assertEq(address(ALICE).balance, 100);
        assertEq(rewarder.getReleased(MARKET_A, epoch, NATIVE, ALICE), 100);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, NATIVE, 200, proof1);
        assertEq(address(BOB).balance, 200);
        assertEq(rewarder.getReleased(MARKET_A, epoch, NATIVE, BOB), 200);

        vm.warp(start + duration + 1);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, NATIVE, 100, proof0);
        assertEq(address(ALICE).balance, 100);
        assertEq(rewarder.getReleased(MARKET_A, epoch, NATIVE, ALICE), 100);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, NATIVE, 200, proof1);
        assertEq(address(BOB).balance, 200);
        assertEq(rewarder.getReleased(MARKET_A, epoch, NATIVE, BOB), 200);
    }

    function testClawback() public {
        uint256 epoch = 0;
        uint128 start = 100;
        uint128 duration = 50;

        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](2);
        tokens[0] = TOKEN_A;
        tokens[1] = TOKEN_B;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, tokens[0], ALICE, amounts[0]);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, tokens[1], BOB, amounts[1]);

        bytes32 root = merkle.getRoot(leaves);

        TOKEN_A.mint(address(rewarder), 100);
        TOKEN_B.mint(address(rewarder), 200);

        vm.startPrank(OWNER);
        rewarder.grantRole(rewarder.CLAWBACK_ROLE(), CAROL);

        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, tokens, amounts, root);
        vm.stopPrank();

        bytes32[] memory proof0 = merkle.getProof(leaves, 0);
        bytes32[] memory proof1 = merkle.getProof(leaves, 1);

        (address clawbackRecipient, uint96 clawbackDelay) = rewarder.getClawbackParameters();

        vm.warp(start + duration + clawbackDelay);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(address(TOKEN_A)), 100, proof0);

        assertEq(TOKEN_A.balanceOf(ALICE), 100);

        vm.prank(CAROL);
        rewarder.clawback(MARKET_A, epoch, IERC20Upgradeable(address(TOKEN_B)), BOB, 200, proof1);

        assertEq(TOKEN_B.balanceOf(BOB), 0);
        assertEq(TOKEN_B.balanceOf(clawbackRecipient), 200);

        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(address(TOKEN_B)), BOB), 200);
        assertEq(
            rewarder.getReleasableAmount(MARKET_A, epoch, IERC20Upgradeable(address(TOKEN_B)), BOB, 200, proof1), 0
        );

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(address(TOKEN_B)), 200, proof1);

        assertEq(TOKEN_B.balanceOf(BOB), 0);

        vm.prank(CAROL);
        rewarder.clawback(MARKET_A, epoch, IERC20Upgradeable(address(TOKEN_B)), BOB, 200, proof1);

        assertEq(TOKEN_B.balanceOf(clawbackRecipient), 200);
    }

    function testClawbackNative() public {
        uint256 epoch = 0;
        uint128 start = 100;
        uint128 duration = 50;

        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](1);
        tokens[0] = NATIVE;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 300;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, NATIVE, ALICE, 100);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, NATIVE, BOB, 200);

        bytes32 root = merkle.getRoot(leaves);

        vm.deal(address(rewarder), 300);

        vm.startPrank(OWNER);
        rewarder.grantRole(rewarder.CLAWBACK_ROLE(), CAROL);

        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, tokens, amounts, root);
        vm.stopPrank();

        bytes32[] memory proof0 = merkle.getProof(leaves, 0);
        bytes32[] memory proof1 = merkle.getProof(leaves, 1);

        (address clawbackRecipient, uint96 clawbackDelay) = rewarder.getClawbackParameters();

        vm.warp(start + duration + clawbackDelay);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, NATIVE, 100, proof0);

        assertEq(address(ALICE).balance, 100);

        vm.prank(CAROL);
        rewarder.clawback(MARKET_A, epoch, NATIVE, BOB, 200, proof1);

        assertEq(address(BOB).balance, 0);
        assertEq(address(clawbackRecipient).balance, 200);

        assertEq(rewarder.getReleased(MARKET_A, epoch, NATIVE, BOB), 200);
        assertEq(rewarder.getReleasableAmount(MARKET_A, epoch, NATIVE, BOB, 200, proof1), 0);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, NATIVE, 200, proof1);

        assertEq(address(BOB).balance, 0);

        vm.prank(CAROL);
        rewarder.clawback(MARKET_A, epoch, NATIVE, BOB, 200, proof1);

        assertEq(address(clawbackRecipient).balance, 200);
    }

    function testBatchClawback() public {
        uint256 epoch = 0;
        uint128 start = 100;
        uint128 duration = 50;

        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](2);
        tokens[0] = TOKEN_A;
        tokens[1] = TOKEN_B;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, tokens[0], ALICE, amounts[0]);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, tokens[1], BOB, amounts[1]);

        bytes32 root = merkle.getRoot(leaves);

        TOKEN_A.mint(address(rewarder), 100);
        TOKEN_B.mint(address(rewarder), 200);

        vm.startPrank(OWNER);
        rewarder.grantRole(rewarder.CLAWBACK_ROLE(), CAROL);

        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, tokens, amounts, root);
        vm.stopPrank();

        bytes32[] memory proof0 = merkle.getProof(leaves, 0);
        bytes32[] memory proof1 = merkle.getProof(leaves, 1);

        (address clawbackRecipient, uint96 clawbackDelay) = rewarder.getClawbackParameters();

        vm.warp(start + duration + clawbackDelay);

        IRewarder.MerkleEntry[] memory entries = new IRewarder.MerkleEntry[](2);

        entries[0] = IRewarder.MerkleEntry({
            market: MARKET_A,
            epoch: epoch,
            token: IERC20Upgradeable(address(TOKEN_A)),
            user: ALICE,
            amount: 100,
            merkleProof: proof0
        });

        entries[1] = IRewarder.MerkleEntry({
            market: MARKET_A,
            epoch: epoch,
            token: IERC20Upgradeable(address(TOKEN_B)),
            user: BOB,
            amount: 200,
            merkleProof: proof1
        });

        vm.prank(CAROL);
        rewarder.batchClawback(entries);

        assertEq(TOKEN_A.balanceOf(address(clawbackRecipient)), 100);
        assertEq(TOKEN_B.balanceOf(address(clawbackRecipient)), 200);

        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(address(TOKEN_A)), ALICE), 100);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(address(TOKEN_B)), BOB), 200);

        assertEq(
            rewarder.getReleasableAmount(MARKET_A, epoch, IERC20Upgradeable(address(TOKEN_A)), ALICE, 100, proof0), 0
        );
        assertEq(
            rewarder.getReleasableAmount(MARKET_A, epoch, IERC20Upgradeable(address(TOKEN_B)), BOB, 200, proof1), 0
        );

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(address(TOKEN_A)), 100, proof0);

        assertEq(TOKEN_A.balanceOf(address(ALICE)), 0);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(address(TOKEN_B)), 200, proof1);

        assertEq(TOKEN_B.balanceOf(address(BOB)), 0);

        vm.prank(CAROL);
        rewarder.batchClawback(entries);

        assertEq(TOKEN_A.balanceOf(address(clawbackRecipient)), 100);
        assertEq(TOKEN_B.balanceOf(address(clawbackRecipient)), 200);
    }

    function testBatchFunctions() public {
        uint256 epoch = 0;
        uint128 start = 100;
        uint128 duration = 50;

        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](2);
        tokens[0] = TOKEN_A;
        tokens[1] = TOKEN_B;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, tokens[0], ALICE, amounts[0]);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, IERC20Upgradeable(TOKEN_B), ALICE, 200);

        bytes32 root = merkle.getRoot(leaves);

        TOKEN_A.mint(address(rewarder), 100);
        TOKEN_B.mint(address(rewarder), 200);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, tokens, amounts, root);
        vm.stopPrank();

        IRewarder.MerkleEntry[] memory merkleEntries = new IRewarder.MerkleEntry[](2);

        merkleEntries[0] = IRewarder.MerkleEntry(MARKET_A, epoch, TOKEN_A, ALICE, 100, merkle.getProof(leaves, 0));
        merkleEntries[1] = IRewarder.MerkleEntry(MARKET_A, epoch, TOKEN_B, ALICE, 200, merkle.getProof(leaves, 1));

        vm.warp(start + 1);

        uint256[] memory releasable = rewarder.getBatchReleasableAmounts(merkleEntries);

        assertEq(releasable[0], 100 * (block.timestamp - start) / duration);
        assertEq(releasable[1], 200 * (block.timestamp - start) / duration);

        vm.prank(ALICE);
        rewarder.batchClaim(merkleEntries);

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

        releasable = rewarder.getBatchReleasableAmounts(merkleEntries);

        assertEq(releasable[0], 98);
        assertEq(releasable[1], 196);

        vm.prank(ALICE);
        rewarder.batchClaim(merkleEntries);

        assertEq(IERC20Upgradeable(TOKEN_A).balanceOf(ALICE), 100);
        assertEq(IERC20Upgradeable(TOKEN_B).balanceOf(ALICE), 200);

        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE), 100);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), ALICE), 200);

        vm.warp(start + duration + 1);

        releasable = rewarder.getBatchReleasableAmounts(merkleEntries);

        assertEq(releasable[0], 0);
        assertEq(releasable[1], 0);

        vm.prank(ALICE);
        rewarder.batchClaim(merkleEntries);

        assertEq(IERC20Upgradeable(TOKEN_A).balanceOf(ALICE), 100);
        assertEq(IERC20Upgradeable(TOKEN_B).balanceOf(ALICE), 200);

        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_A), ALICE), 100);
        assertEq(rewarder.getReleased(MARKET_A, epoch, IERC20Upgradeable(TOKEN_B), ALICE), 200);
    }

    function testPauseFunctions() public {
        uint256 epoch = 0;
        uint128 start = 100;
        uint128 duration = 50;

        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](2);
        tokens[0] = TOKEN_A;
        tokens[1] = TOKEN_B;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, tokens[0], ALICE, amounts[0]);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, IERC20Upgradeable(TOKEN_B), ALICE, 200);

        bytes32 root = merkle.getRoot(leaves);

        TOKEN_A.mint(address(rewarder), 1000);
        TOKEN_B.mint(address(rewarder), 2000);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, tokens, amounts, root);
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
        rewarder.claim(MARKET_A, epoch, tokens[0], amounts[0], proofs[0]);

        vm.expectRevert("Pausable: paused");
        rewarder.batchClaim(new IRewarder.MerkleEntry[](0));

        vm.expectRevert("Pausable: paused");
        rewarder.clawback(MARKET_A, epoch, tokens[0], ALICE, amounts[0], proofs[0]);

        vm.prank(OWNER);
        rewarder.unpause();

        vm.expectRevert("Pausable: not paused");
        vm.prank(OWNER);
        rewarder.unpause();

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, tokens[0], amounts[0], proofs[0]);

        assertEq(IERC20Upgradeable(TOKEN_A).balanceOf(ALICE), 100);
    }

    function testSetClawbackDelay(uint96 delay) public {
        vm.assume(delay > 1 days);
        vm.prank(OWNER);
        rewarder.setClawbackDelay(delay);

        (, uint96 clawbackDelay) = rewarder.getClawbackParameters();
        assertEq(clawbackDelay, delay);
    }

    function testSetClawbackRecipient(address recipient) public {
        vm.assume(recipient != address(0));

        vm.prank(OWNER);
        rewarder.setClawbackRecipient(recipient);

        (address clawbackRecipient,) = rewarder.getClawbackParameters();
        assertEq(clawbackRecipient, recipient);
    }

    function testBatchClaimRevertForEmptyEntries() public {
        vm.expectRevert(IRewarder.Rewarder__EmptyMerkleEntries.selector);
        vm.prank(ALICE);
        rewarder.batchClaim(new IRewarder.MerkleEntry[](0));
    }

    function testBatchClawbackRevertForEmptyEntries() public {
        vm.expectRevert(IRewarder.Rewarder__EmptyMerkleEntries.selector);
        vm.prank(OWNER);
        rewarder.batchClawback(new IRewarder.MerkleEntry[](0));
    }

    function testBatchClaimRevertForClaimSomeoneElse() public {
        IRewarder.MerkleEntry[] memory merkleEntries = new IRewarder.MerkleEntry[](1);
        merkleEntries[0] = IRewarder.MerkleEntry({
            market: MARKET_A,
            epoch: 0,
            token: NATIVE,
            user: BOB,
            amount: 0,
            merkleProof: new bytes32[](0)
        });

        vm.expectRevert(IRewarder.Rewarder__OnlyClaimForSelf.selector);
        vm.prank(ALICE);
        rewarder.batchClaim(merkleEntries);
    }

    function testClaimRevertForEpochCanceled() public {
        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](1);
        tokens[0] = NATIVE;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.deal(address(rewarder), 100);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);
        rewarder.setNewEpoch(MARKET_A, 0, 10, 10, tokens, amounts, bytes32(uint256(1)));
        rewarder.cancelEpoch(MARKET_A, 0);
        vm.stopPrank();

        vm.expectRevert(IRewarder.Rewarder__EpochCanceled.selector);
        vm.prank(ALICE);
        rewarder.claim(MARKET_A, 0, NATIVE, 0, new bytes32[](0));
    }

    function testClaimRevertForInvalidProof() public {
        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](1);
        tokens[0] = NATIVE;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.deal(address(rewarder), 100);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);
        rewarder.setNewEpoch(MARKET_A, 0, 10, 10, tokens, amounts, bytes32(uint256(1)));
        vm.stopPrank();

        vm.expectRevert(IRewarder.Rewarder__InvalidProof.selector);
        vm.prank(ALICE);
        rewarder.claim(MARKET_A, 0, NATIVE, 0, new bytes32[](0));
    }

    function testSetNewEpochRevertsForNonWhitelistedMarket() public {
        vm.expectRevert(IRewarder.Rewarder__MarketNotWhitelisted.selector);
        vm.prank(OWNER);
        rewarder.setNewEpoch(MARKET_A, 0, 10, 20, new IERC20Upgradeable[](0), new uint256[](0), bytes32(uint256(1)));
    }

    function testSetNewEpochRevertForInvalidRoot() public {
        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        vm.expectRevert(IRewarder.Rewarder__InvalidRoot.selector);
        rewarder.setNewEpoch(MARKET_A, 0, 10, 10, new IERC20Upgradeable[](0), new uint256[](0), bytes32(uint256(0)));
        vm.stopPrank();
    }

    function testSetNewEpochRevertForInvalidStart() public {
        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](1);
        tokens[0] = NATIVE;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.deal(address(rewarder), 100);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        vm.expectRevert(IRewarder.Rewarder__InvalidStart.selector);
        rewarder.setNewEpoch(MARKET_A, 0, 0, 10, tokens, amounts, bytes32(uint256(1)));

        vm.warp(10);

        vm.expectRevert(IRewarder.Rewarder__InvalidStart.selector);
        rewarder.setNewEpoch(MARKET_A, 0, 9, 10, tokens, amounts, bytes32(uint256(1)));

        vm.stopPrank();
    }

    function testSetNewEpochRevertForOverlappingEpoch() public {
        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](1);
        tokens[0] = NATIVE;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.deal(address(rewarder), 100);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, 0, 10, 10, tokens, amounts, bytes32(uint256(1)));

        vm.expectRevert(IRewarder.Rewarder__OverlappingEpoch.selector);
        rewarder.setNewEpoch(MARKET_A, 1, 5, 1, new IERC20Upgradeable[](0), new uint256[](0), bytes32(uint256(1)));

        vm.expectRevert(IRewarder.Rewarder__OverlappingEpoch.selector);
        rewarder.setNewEpoch(MARKET_A, 1, 19, 10, new IERC20Upgradeable[](0), new uint256[](0), bytes32(uint256(1)));

        vm.expectRevert(IRewarder.Rewarder__OverlappingEpoch.selector);
        rewarder.setNewEpoch(MARKET_A, 1, 11, 9, new IERC20Upgradeable[](0), new uint256[](0), bytes32(uint256(1)));
        vm.stopPrank();
    }

    function testSetNewEpochRevertForInvalidEpoch() public {
        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        vm.expectRevert(IRewarder.Rewarder__InvalidEpoch.selector);
        rewarder.setNewEpoch(MARKET_A, 1, 10, 10, new IERC20Upgradeable[](0), new uint256[](0), bytes32(uint256(1)));
        vm.stopPrank();
    }

    function testSetNewEpochRevertForInvalidLength() public {
        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        vm.expectRevert(IRewarder.Rewarder__InvalidLength.selector);
        rewarder.setNewEpoch(MARKET_A, 0, 1, 0, new IERC20Upgradeable[](0), new uint256[](0), bytes32(uint256(1)));

        vm.expectRevert(IRewarder.Rewarder__InvalidLength.selector);
        rewarder.setNewEpoch(MARKET_A, 0, 1, 0, new IERC20Upgradeable[](2), new uint256[](1), bytes32(uint256(1)));

        vm.expectRevert(IRewarder.Rewarder__InvalidLength.selector);
        rewarder.setNewEpoch(MARKET_A, 0, 1, 0, new IERC20Upgradeable[](2), new uint256[](1), bytes32(uint256(1)));
        vm.stopPrank();
    }

    function testSetNewEpochRevertForInvalidAmount() public {
        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        vm.expectRevert(IRewarder.Rewarder__InvalidAmount.selector);
        rewarder.setNewEpoch(MARKET_A, 0, 1, 0, new IERC20Upgradeable[](1), new uint256[](1), bytes32(uint256(1)));
        vm.stopPrank();
    }

    function testSetNewRevertForInsufficientBalance() public {
        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](1);
        tokens[0] = TOKEN_A;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        vm.expectRevert(abi.encodeWithSelector(IRewarder.Rewarder__InsufficientBalance.selector, TOKEN_A));
        rewarder.setNewEpoch(MARKET_A, 0, 1, 0, tokens, amounts, bytes32(uint256(1)));

        TOKEN_A.mint(address(rewarder), 99);

        vm.expectRevert(abi.encodeWithSelector(IRewarder.Rewarder__InsufficientBalance.selector, TOKEN_A));
        rewarder.setNewEpoch(MARKET_A, 0, 1, 0, tokens, amounts, bytes32(uint256(1)));

        TOKEN_A.mint(address(rewarder), 1);

        rewarder.setNewEpoch(MARKET_A, 0, 1, 0, tokens, amounts, bytes32(uint256(1)));

        vm.expectRevert(abi.encodeWithSelector(IRewarder.Rewarder__InsufficientBalance.selector, TOKEN_A));
        rewarder.setNewEpoch(MARKET_A, 1, 2, 0, tokens, amounts, bytes32(uint256(1)));
        vm.stopPrank();
    }

    function testSetNewRevertForInsufficientBalanceOfNative() public {
        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](1);
        tokens[0] = NATIVE;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        vm.expectRevert(abi.encodeWithSelector(IRewarder.Rewarder__InsufficientBalance.selector, NATIVE));
        rewarder.setNewEpoch(MARKET_A, 0, 1, 0, tokens, amounts, bytes32(uint256(1)));

        vm.deal(address(rewarder), 99);

        vm.expectRevert(abi.encodeWithSelector(IRewarder.Rewarder__InsufficientBalance.selector, NATIVE));
        rewarder.setNewEpoch(MARKET_A, 0, 1, 0, tokens, amounts, bytes32(uint256(1)));

        vm.deal(address(rewarder), 100);

        rewarder.setNewEpoch(MARKET_A, 0, 1, 0, tokens, amounts, bytes32(uint256(1)));

        vm.expectRevert(abi.encodeWithSelector(IRewarder.Rewarder__InsufficientBalance.selector, NATIVE));
        rewarder.setNewEpoch(MARKET_A, 1, 2, 0, tokens, amounts, bytes32(uint256(1)));
        vm.stopPrank();
    }

    function testSetNewRevertForAlreadySetForEpoch() public {
        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](2);
        tokens[0] = TOKEN_A;
        tokens[1] = TOKEN_A;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 100;

        TOKEN_A.mint(address(rewarder), 200);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        vm.expectRevert(abi.encodeWithSelector(IRewarder.Rewarder__AlreadySetForEpoch.selector, TOKEN_A));
        rewarder.setNewEpoch(MARKET_A, 0, 1, 0, tokens, amounts, bytes32(uint256(1)));
        vm.stopPrank();
    }

    function testSetNewRevertForInsufficientBalanceOfTokenB() public {
        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](2);
        tokens[0] = TOKEN_A;
        tokens[1] = TOKEN_B;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 1;

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        vm.expectRevert(abi.encodeWithSelector(IRewarder.Rewarder__InsufficientBalance.selector, TOKEN_A));
        rewarder.setNewEpoch(MARKET_A, 0, 1, 0, tokens, amounts, bytes32(uint256(1)));

        TOKEN_A.mint(address(rewarder), 99);

        vm.expectRevert(abi.encodeWithSelector(IRewarder.Rewarder__InsufficientBalance.selector, TOKEN_A));
        rewarder.setNewEpoch(MARKET_A, 0, 1, 0, tokens, amounts, bytes32(uint256(1)));

        TOKEN_A.mint(address(rewarder), 1);

        vm.expectRevert(abi.encodeWithSelector(IRewarder.Rewarder__InsufficientBalance.selector, TOKEN_B));
        rewarder.setNewEpoch(MARKET_A, 0, 1, 0, tokens, amounts, bytes32(uint256(1)));

        TOKEN_B.mint(address(rewarder), 1);

        rewarder.setNewEpoch(MARKET_A, 0, 1, 0, tokens, amounts, bytes32(uint256(1)));

        vm.expectRevert(abi.encodeWithSelector(IRewarder.Rewarder__InsufficientBalance.selector, TOKEN_A));
        rewarder.setNewEpoch(MARKET_A, 1, 2, 0, tokens, amounts, bytes32(uint256(1)));

        TOKEN_A.mint(address(rewarder), 100);

        vm.expectRevert(abi.encodeWithSelector(IRewarder.Rewarder__InsufficientBalance.selector, TOKEN_B));
        rewarder.setNewEpoch(MARKET_A, 1, 2, 0, tokens, amounts, bytes32(uint256(1)));
        vm.stopPrank();
    }

    function testSetNewEpochForOverlappingEpochAfterCancel() public {
        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](1);
        tokens[0] = NATIVE;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        vm.deal(address(rewarder), 100);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, 0, 10, 10, tokens, amounts, bytes32(uint256(1)));

        vm.expectRevert(IRewarder.Rewarder__OverlappingEpoch.selector);
        rewarder.setNewEpoch(MARKET_A, 1, 10, 50, new IERC20Upgradeable[](0), new uint256[](0), bytes32(uint256(1)));

        rewarder.cancelEpoch(MARKET_A, 0);

        (bool s,) = address(rewarder).call{value: 100}("");
        assertTrue(s);

        rewarder.setNewEpoch(MARKET_A, 1, 10, 50, tokens, amounts, bytes32(uint256(1)));
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

        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](1);
        tokens[0] = TOKEN_A;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        TOKEN_A.mint(address(rewarder), 3);

        rewarder.setNewEpoch(MARKET_A, 0, 10, 10, tokens, amounts, bytes32(uint256(1)));
        rewarder.setNewEpoch(MARKET_A, 1, 20, 10, tokens, amounts, bytes32(uint256(1)));
        rewarder.setNewEpoch(MARKET_A, 2, 30, 10, tokens, amounts, bytes32(uint256(1)));

        vm.expectRevert(IRewarder.Rewarder__OnlyValidLatestEpoch.selector);
        rewarder.cancelEpoch(MARKET_A, 0);

        vm.expectRevert(IRewarder.Rewarder__OnlyValidLatestEpoch.selector);
        rewarder.cancelEpoch(MARKET_A, 1);

        rewarder.cancelEpoch(MARKET_A, 2);
        assertEq(TOKEN_A.balanceOf(OWNER), 1);
        assertEq(TOKEN_A.balanceOf(address(rewarder)), 2);

        vm.expectRevert(IRewarder.Rewarder__OnlyValidLatestEpoch.selector);
        rewarder.cancelEpoch(MARKET_A, 0);

        rewarder.cancelEpoch(MARKET_A, 1);
        assertEq(TOKEN_A.balanceOf(OWNER), 2);
        assertEq(TOKEN_A.balanceOf(address(rewarder)), 1);

        rewarder.cancelEpoch(MARKET_A, 0);
        assertEq(TOKEN_A.balanceOf(OWNER), 3);
        assertEq(TOKEN_A.balanceOf(address(rewarder)), 0);

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
        rewarder.setNewEpoch(MARKET_A, 0, 10, 10, new IERC20Upgradeable[](0), new uint256[](0), bytes32(uint256(1)));

        vm.expectRevert("Ownable: caller is not the owner");
        rewarder.cancelEpoch(MARKET_A, 0);

        vm.expectRevert("Ownable: caller is not the owner");
        rewarder.addMarketToWhitelist(MARKET_A);

        vm.expectRevert("Ownable: caller is not the owner");
        rewarder.removeMarketFromWhitelist(MARKET_A);

        vm.stopPrank();
    }

    function testSetClawbackRevertForDelayTooLow(uint96 delay) public {
        vm.assume(delay < 1 days);
        vm.expectRevert(IRewarder.Rewarder__ClawbackDelayTooLow.selector);
        vm.startPrank(OWNER);
        rewarder.setClawbackDelay(delay);
        vm.stopPrank();
    }

    function testSetClawbackRecipientRevertForZeroAddress() public {
        vm.expectRevert(IRewarder.Rewarder__ZeroAddress.selector);
        vm.startPrank(OWNER);
        rewarder.setClawbackRecipient(address(0));
        vm.stopPrank();
    }

    function testClawbackRevertForDelayNotPassed(uint256 ts) public {
        uint256 epoch = 0;
        uint128 start = 100;
        uint128 duration = 50;

        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](2);
        tokens[0] = TOKEN_A;
        tokens[1] = TOKEN_B;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        (, uint96 clawbackDelay) = rewarder.getClawbackParameters();

        vm.assume(ts < start + duration + clawbackDelay);

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, tokens[0], ALICE, amounts[0]);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, tokens[1], BOB, amounts[1]);

        bytes32 root = merkle.getRoot(leaves);

        TOKEN_A.mint(address(rewarder), 100);
        TOKEN_B.mint(address(rewarder), 200);

        vm.startPrank(OWNER);
        rewarder.grantRole(rewarder.CLAWBACK_ROLE(), CAROL);

        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, tokens, amounts, root);
        vm.stopPrank();

        bytes32[] memory proof0 = merkle.getProof(leaves, 0);
        bytes32[] memory proof1 = merkle.getProof(leaves, 1);

        vm.warp(ts);

        vm.expectRevert(IRewarder.Rewarder__ClawbackDelayNotPassed.selector);
        vm.prank(CAROL);
        rewarder.clawback(MARKET_A, epoch, IERC20Upgradeable(address(TOKEN_A)), ALICE, 100, proof0);

        vm.expectRevert(IRewarder.Rewarder__ClawbackDelayNotPassed.selector);
        vm.prank(CAROL);
        rewarder.clawback(MARKET_A, epoch, IERC20Upgradeable(address(TOKEN_B)), BOB, 200, proof1);
    }

    function testInitializeTwice() public {
        vm.startPrank(OWNER);

        // Redeploy it orelse coverage will complain
        rewarder = Rewarder(payable(address(new TransparentUpgradeableProxy(address(implementation), PROXY_OWNER, ""))));
        rewarder.initialize(1 days);

        vm.expectRevert("Initializable: contract is already initialized");
        rewarder.initialize(1 days);

        vm.stopPrank();
    }

    function testClaim0() public {
        uint256 epoch = 0;
        uint128 start = 100;
        uint128 duration = 50;

        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](2);
        tokens[0] = TOKEN_A;
        tokens[1] = TOKEN_B;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 200;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, tokens[0], ALICE, 0);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, tokens[1], BOB, amounts[1]);

        TOKEN_A.mint(address(rewarder), 1);
        TOKEN_B.mint(address(rewarder), 200);

        bytes32 root = merkle.getRoot(leaves);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, tokens, amounts, root);
        vm.stopPrank();

        bytes32[] memory proof0 = merkle.getProof(leaves, 0);
        bytes32[] memory proof1 = merkle.getProof(leaves, 1);

        vm.warp(start + duration + 1);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(address(TOKEN_A)), 0, proof0);

        assertEq(TOKEN_A.balanceOf(ALICE), 0);

        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(address(TOKEN_B)), 200, proof1);

        assertEq(TOKEN_B.balanceOf(BOB), 200);
    }

    function testClaimRevertForClaimingMoreThanTotalReward() public {
        uint256 epoch = 0;
        uint128 start = 100;
        uint128 duration = 50;

        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](2);
        tokens[0] = TOKEN_A;
        tokens[1] = TOKEN_B;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, tokens[0], ALICE, amounts[0]);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, tokens[1], BOB, amounts[1]);

        TOKEN_A.mint(address(rewarder), 100);
        TOKEN_B.mint(address(rewarder), 200);

        bytes32 root = merkle.getRoot(leaves);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        amounts[0] -= 1;
        amounts[1] -= 1;

        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, tokens, amounts, root);
        vm.stopPrank();

        bytes32[] memory proof0 = merkle.getProof(leaves, 0);
        bytes32[] memory proof1 = merkle.getProof(leaves, 1);

        vm.warp(start + duration);

        vm.expectRevert();
        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(address(TOKEN_A)), 100, proof0);

        vm.expectRevert();
        vm.prank(BOB);
        rewarder.claim(MARKET_A, epoch, IERC20Upgradeable(address(TOKEN_B)), 200, proof1);
    }

    function testClaimNativeRevertForNativeTransferFailed() public {
        uint256 epoch = 0;
        uint128 start = 100;
        uint128 duration = 50;

        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](1);
        tokens[0] = NATIVE;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 300;

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = getLeaf(MARKET_A, epoch, start, duration, NATIVE, ALICE, 100);
        leaves[1] = getLeaf(MARKET_A, epoch, start, duration, NATIVE, address(this), 200);

        vm.deal(address(rewarder), 300);

        bytes32 root = merkle.getRoot(leaves);

        vm.startPrank(OWNER);
        rewarder.addMarketToWhitelist(MARKET_A);

        rewarder.setNewEpoch(MARKET_A, epoch, start, duration, tokens, amounts, root);
        vm.stopPrank();

        bytes32[] memory proof0 = merkle.getProof(leaves, 0);
        bytes32[] memory proof1 = merkle.getProof(leaves, 1);

        vm.warp(start + duration);

        vm.prank(ALICE);
        rewarder.claim(MARKET_A, epoch, NATIVE, 100, proof0);

        vm.expectRevert(IRewarder.Rewarder__NativeTransferFailed.selector);
        vm.prank(address(this));
        rewarder.claim(MARKET_A, epoch, NATIVE, 200, proof1);
    }

    function getLeaf(
        address market,
        uint256 epoch,
        uint128 start,
        uint128 duration,
        IERC20Upgradeable token,
        address user,
        uint256 amount
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(market, epoch, start, duration, token, user, amount));
    }
}
