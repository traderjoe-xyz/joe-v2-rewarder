// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../script/deployment/fuji/Rewarder.upgrade.sol";

contract RewarderUpgradeTest is Test {
    RewarderUpgrader public upgrader;

    function setUp() public {
        vm.createSelectFork(stdChains["fuji"].rpcUrl);

        upgrader = new RewarderUpgrader();
    }

    function testUpgrade() public {
        address admin = address(upgrader.admin());
        address proxy = address(upgrader.proxy());

        vm.prank(admin);
        address implementation = TransparentUpgradeableProxy(payable(proxy)).implementation();

        address newImplementation = upgrader.run();

        assertTrue(address(implementation) != newImplementation, "new implementation");

        vm.prank(admin);
        assertEq(
            TransparentUpgradeableProxy(payable(proxy)).implementation(), newImplementation, "proxy implementation"
        );
    }
}
