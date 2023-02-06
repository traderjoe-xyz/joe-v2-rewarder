// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin/proxy/transparent/ProxyAdmin.sol";

import "../../../src/Rewarder.sol";

contract RewarderDeployer is Script {
    function run() public returns (address, address, address) {
        vm.createSelectFork(stdChains["abitrum_one_goerli"].rpcUrl);

        uint256 deployerPrivateKey = vm.envUint("DEPLOY_PRIVATE_KEY");

        /**
         * Start broadcasting the transaction to the network.
         */
        vm.startBroadcast(deployerPrivateKey);

        ProxyAdmin admin = new ProxyAdmin();

        Rewarder implementation = new Rewarder();

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(admin),
            ""
        );

        Rewarder(payable(address(proxy))).initialize(30 days);

        vm.stopBroadcast();
        /**
         * Stop broadcasting the transaction to the network.
         */

        return (address(proxy), address(implementation), address(admin));
    }
}
