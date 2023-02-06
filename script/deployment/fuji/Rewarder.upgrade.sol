// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin/proxy/transparent/ProxyAdmin.sol";

import "../../../src/Rewarder.sol";

contract RewarderUpgrader is Script {
    IVBS public constant vbs = IVBS(0xFFC08538077a0455E0F4077823b1A0E3e18Faf0b);

    ProxyAdmin public constant admin = ProxyAdmin(0x65F3c037Ee4C142f4B60434a5f166EAfA06D458E);

    TransparentUpgradeableProxy public constant proxy =
        TransparentUpgradeableProxy(payable(0x3e031f1486a27c997e85C5a2af2638EE3A4C28a1));

    function run() public returns (address) {
        vm.createSelectFork(stdChains["fuji"].rpcUrl);

        uint256 deployerPrivateKey = vm.envUint("DEPLOY_PRIVATE_KEY");

        /**
         * Start broadcasting the transaction to the network.
         */
        vm.startBroadcast(deployerPrivateKey);

        Rewarder implementation = new Rewarder();

        vbs.call(
            address(admin), abi.encodeWithSelector(admin.upgrade.selector, address(proxy), address(implementation))
        );

        vm.stopBroadcast();
        /**
         * Stop broadcasting the transaction to the network.
         */

        return address(implementation);
    }
}

interface IVBS {
    function getOwner(uint256 _index) external view returns (address owner);

    function getNumberOfOwners() external view returns (uint256 nbOfAdmins);

    function addOwner(address _owner) external;

    function removeOwner(address _owner) external;

    function call(address _target, bytes calldata _data) external payable;
}
