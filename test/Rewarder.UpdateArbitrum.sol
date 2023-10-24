// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Rewarder.sol";
import "openzeppelin-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin/proxy/transparent/ProxyAdmin.sol";
import "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpdateArbitrum is Test {
    Rewarder public rewarder = Rewarder(payable(0x624C5b9BEB13af6893e715932c26e2b7A59c410a));
    address public ms = 0xf1ec4E41B49582aF7E00D6525AF78111F37b94a8;
    IERC20Upgradeable public joe = IERC20Upgradeable(0x371c7ec6D8039ff7933a2AA28EB827Ffe1F52f07);
    ProxyAdmin public proxyAdmin = ProxyAdmin(0xa0BA87c58C7D09f859843256A9b87253F9a26C98);

    function setUp() public {
        vm.createSelectFork("https://rpc.ankr.com/arbitrum", 71_910_974);
    }

    function testRewarder() public {
        vm.startPrank(ms);
        Rewarder newImplementation = new Rewarder();

        proxyAdmin.upgrade(TransparentUpgradeableProxy(payable(address(rewarder))), address(newImplementation));
        rewarder.forceSync(joe);

        joe.transfer(address(rewarder), 210e18);

        IERC20Upgradeable[] memory tokens = new IERC20Upgradeable[](1);
        tokens[0] = joe;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 120e18;

        rewarder.setNewEpoch(
            0x7eC3717f70894F6d9BA0be00774610394Ce006eE,
            1,
            1_679_356_800,
            1_209_600,
            tokens,
            amounts,
            0x84c45e4957844cd1a5e0e8ad542f45cdfb8b416e7abffa297253385fc000aea0
        );

        amounts[0] = 40e18;
        rewarder.setNewEpoch(
            0xA51eE8b744E6cc1F2AC12b9eEaAE8dEB27619C6b,
            1,
            1_679_356_800,
            1_209_600,
            tokens,
            amounts,
            0xfc25c18e9328b995178e2040582602d9a01029c0714cdb5175dd301efa58f653
        );

        amounts[0] = 20e18;
        rewarder.setNewEpoch(
            0x5813CE0679e67dDaF0e9002939550710856C06D4,
            0,
            1_679_356_800,
            1_209_600,
            tokens,
            amounts,
            0x4cfedce99f1cbf821533f812d8438ccbbaf784433c81552cc70e33e8c280febf
        );

        amounts[0] = 20e18;
        rewarder.setNewEpoch(
            0xA0fd049466d57fC3637E27cA585D59E0Ad86B902,
            0,
            1_679_356_800,
            1_209_600,
            tokens,
            amounts,
            0x86675237ee63d1cf58b4d2f7cdec08fd19ea861783f584e85cb3c603c9c3e23b
        );

        amounts[0] = 10e18;
        rewarder.setNewEpoch(
            0x13FDa18516eAFe5e8AE930F86Fa51aE4B6C35E8F,
            0,
            1_679_356_800,
            1_209_600,
            tokens,
            amounts,
            0xd8d3bbd3865e6ee5f5b03141dbb79379ccb3f4e0a92c21ee18617973164f3c0e
        );
        vm.stopPrank();
    }
}
