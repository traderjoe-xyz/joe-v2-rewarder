// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin/proxy/transparent/ProxyAdmin.sol";

import "../../../src/Rewarder.sol";

contract RewarderUpgrader is Script {
    IVBS public constant vbs = IVBS(0xFFC08538077a0455E0F4077823b1A0E3e18Faf0b);

    ProxyAdmin public constant admin = ProxyAdmin(0x46709dbc09656292B27ad91EE2c5d324270D3387);

    TransparentUpgradeableProxy public constant proxy =
        TransparentUpgradeableProxy(payable(0x1D336E165CbA662fa49B935fFdD7362C09Cc93ec));

    function run() public returns (address) {
        vm.createSelectFork(stdChains["fuji"].rpcUrl, 17_891_593);

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
