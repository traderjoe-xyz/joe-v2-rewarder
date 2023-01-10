// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../script/deployment/fuji/Rewarder.deploy.sol";

contract RewarderDeployTest is Test {
    RewarderDeployer public deployer;

    function setUp() public {
        deployer = new RewarderDeployer();
    }

    function testDeploy() public {
        (address proxy, address implementation, address admin) = deployer.run();

        vm.startPrank(admin);
        assertEq(TransparentUpgradeableProxy(payable(proxy)).admin(), admin, "proxy admin");
        assertEq(TransparentUpgradeableProxy(payable(proxy)).implementation(), implementation, "proxy implementation");
        vm.stopPrank();
    }
}
