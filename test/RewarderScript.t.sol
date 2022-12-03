// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../script/Rewarder.s.sol";

contract MerkleTreeTest is Test {
    function test() public {
        RewarderScript script = new RewarderScript();
        script.run();
    }
}
