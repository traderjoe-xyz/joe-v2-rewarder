// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "murky/Merkle.sol";
import "openzeppelin-upgradeable/utils/StringsUpgradeable.sol";
import "openzeppelin-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "openzeppelin-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../src/Rewarder.sol";

/**
 * @title Rewarder Script
 * @author Trader Joe
 * @notice This script is used to create Merkle trees for the Rewarder contract.
 * It takes a json file as input, and outputs a Merkle tree in the form of a json file.
 * The input needs to follow the following format:
 * {
 *   "length": <number of merkle roots>,
 *   "markets": [
 *     {
 *       "address": <market address>,
 *       "start": <start of the vesting period>,
 *       "duration": <duration of the vesting period>,
 *       "epoch": <epoch of the market>,
 *       "rewards": [
 *         {
 *           "user": <user address>,
 *           "token": <reward token address>,
 *           "amount": <amount of reward tokens to be distributed at the end of the vesting period>
 *         },
 *         ...
 *       ]
 *     },
 *     ...
 *   ]
 * }
 *
 * The output will be a json file with the following format:
 * {
 *   "length": <number of merkle roots>,
 *   "markets": [
 *     {
 *       "address": <market address>,
 *       "start": <start of the vesting period>,
 *       "duration": <duration of the vesting period>,
 *       "epoch": <epoch of the market>,
 *       "root": <merkle root>,
 *       "rewards": [
 *         {
 *           "user": <user address>,
 *           "token": <reward token address>,
 *           "amount": <amount of reward tokens to be distributed at the end of the vesting period>,
 *           "proof": [<merkle proof>]
 *         },
 *         ...
 *       ]
 *     },
 *     ...
 *   ]
 * }
 */
contract RewarderScript is Script {
    using MerkleProofUpgradeable for bytes32[];
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    /**
     * @dev The structures are ordered in alphabetical order, don't change the order.
     */
    struct Reward {
        uint256 amount;
        address token;
        address user;
    }

    /**
     * @dev The structures are ordered in alphabetical order, don't change the order.
     */
    struct Market {
        uint256 duration;
        uint256 epoch;
        address market;
        bytes32 root;
        uint256 start;
        User[] users;
    }

    /**
     * @dev The structures are ordered in alphabetical order, don't change the order.
     */
    struct User {
        uint256 amount;
        bytes32[] proof;
        address token;
        address user;
    }

    Rewarder public rewarder;

    Market[] public markets;
    EnumerableSetUpgradeable.Bytes32Set private _set;

    function run() public {
        // TODO Uncomment and change address when it is deployed
        // if (block.chainid == 43_114) {
        //     rewarder = IRewarder(address(0x0000000000000000000000000000000000000000));
        // } else if (block.chainid == 43_113) {
        //     rewarder = IRewarder(address(0x0000000000000000000000000000000000000000));
        // } else {
        //     Rewarder implementation = new Rewarder();

        //     rewarder = Rewarder(payable(address(new TransparentUpgradeableProxy(address(implementation), address(1), ""))));
        //     rewarder.initialize();

        //     // Add dummy markets
        //     rewarder.addMarketToWhitelist(address(0x000000000000000000000000000000000000000A));
        //     rewarder.addMarketToWhitelist(address(0x000000000000000000000000000000000000000b));
        //     rewarder.addMarketToWhitelist(address(0x000000000000000000000000000000000000000C));
        //     rewarder.addMarketToWhitelist(address(0x000000000000000000000000000000000000000d));
        // }

        Rewarder implementation = new Rewarder();

        rewarder = Rewarder(payable(address(new TransparentUpgradeableProxy(address(implementation), address(1), ""))));
        rewarder.initialize(1 days);

        // Add dummy markets
        rewarder.addMarketToWhitelist(address(0x000000000000000000000000000000000000000A));
        rewarder.addMarketToWhitelist(address(0x000000000000000000000000000000000000000b));
        rewarder.addMarketToWhitelist(address(0x000000000000000000000000000000000000000C));
        rewarder.addMarketToWhitelist(address(0x000000000000000000000000000000000000000d));

        string memory fileName = "rewards-example";
        string memory path = string(abi.encodePacked("./files/in/", fileName, ".json"));

        string memory json = vm.readFile(path);
        vm.closeFile(path);

        uint256 length = abi.decode(vm.parseJson(json, ".length"), (uint256));

        Merkle merkle = new Merkle();

        for (uint256 i; i < length; i++) {
            string memory mKey = string(abi.encodePacked(".markets[", StringsUpgradeable.toString(i), "]"));

            address market = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".address"))), (address));
            uint256 epoch = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".epoch"))), (uint256));
            uint256 start = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".start"))), (uint256));
            uint256 duration = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".duration"))), (uint256));

            require(_set.add(keccak256(abi.encodePacked(market, epoch))), "Market already exists");

            Market storage m = markets.push();

            m.market = market;
            m.epoch = epoch;
            m.start = start;
            m.duration = duration;

            Reward[] memory rewards =
                abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".rewards"))), (Reward[]));

            bytes32[] memory leaves = new bytes32[](rewards.length);

            for (uint256 j; j < rewards.length; j++) {
                Reward memory reward = rewards[j];

                require(
                    _set.add(keccak256(abi.encodePacked(market, epoch, reward.token, reward.user))),
                    "User rewards already exists"
                );

                bytes32 leaf = keccak256(
                    abi.encodePacked(market, epoch, start, duration, reward.token, reward.user, reward.amount)
                );

                leaves[j] = leaf;
            }

            bytes32 root = merkle.getRoot(leaves);
            m.root = root;

            require(rewarder.isWhitelistedMarket(market), "Market is not whitelisted");
            require(rewarder.getNumberOfEpochs(market) == epoch, "Invalid epoch");
            require(start >= block.timestamp, "Invalid start");
            require(duration <= 365 days, "duration is probably too long");

            if (epoch > 0) {
                (uint256 startPrevious, uint256 durationPrevious) = rewarder.getVestingPeriodAtEpoch(market, epoch - 1);
                require(startPrevious + durationPrevious <= start, "Overlapping epochs");
            }

            for (uint256 j; j < rewards.length; j++) {
                Reward memory reward = rewards[j];

                bytes32[] memory proof = merkle.getProof(leaves, j);

                m.users.push(User(reward.amount, proof, reward.token, reward.user));

                require(
                    _verify(root, market, epoch, start, duration, reward.token, reward.user, reward.amount, proof),
                    "Invalid proof"
                );
            }
        }

        string memory out = convertArrayOfMarketToString(markets);
        string memory f_out = string(abi.encodePacked("./files/out/", fileName, "-out.json"));

        vm.writeJson(out, f_out);

        verifyGeneratedJSON(f_out);
    }

    function verifyGeneratedJSON(string memory file) public {
        string memory json = vm.readFile(file);
        vm.closeFile(file);

        uint256 length = abi.decode(vm.parseJson(json, ".length"), (uint256));

        require(markets.length == length, "Invalid length");

        for (uint256 i; i < length; i++) {
            Market storage m = markets[i];

            string memory mKey = string(abi.encodePacked(".markets[", StringsUpgradeable.toString(i), "]"));

            address market = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".address"))), (address));
            uint256 epoch = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".epoch"))), (uint256));
            uint256 start = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".start"))), (uint256));
            uint256 duration = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".duration"))), (uint256));
            bytes32 root = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".root"))), (bytes32));

            require(_set.contains(keccak256(abi.encodePacked(market, epoch))), "Market does not exists");

            require(rewarder.isWhitelistedMarket(market), "Market is not whitelisted");
            require(start >= block.timestamp, "Invalid start");
            require(duration <= 365 days, "duration is probably too long");

            if (epoch > 0) {
                (uint256 startPrevious, uint256 durationPrevious) = rewarder.getVestingPeriodAtEpoch(market, epoch - 1);
                require(startPrevious + durationPrevious <= start, "Overlapping epochs");
            }

            User[] memory users = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".rewards"))), (User[]));

            for (uint256 j; j < users.length; j++) {
                User memory user = users[j];

                require(
                    _set.contains(keccak256(abi.encodePacked(market, epoch, user.token, user.user))),
                    "User rewards does not exists"
                );

                require(m.duration == duration, "Invalid duration");
                require(m.epoch == epoch, "Invalid epoch");
                require(m.market == market, "Invalid market");
                require(m.root == root, "Invalid root");
                require(m.start == start, "Invalid start");

                User storage u = m.users[j];

                require(u.user == user.user, "Invalid user");
                require(u.amount == user.amount, "Invalid amount");
                require(u.token == user.token, "Invalid token");

                require(u.proof.length == user.proof.length, "Invalid proof length");

                for (uint256 k; k < u.proof.length; k++) {
                    require(u.proof[k] == user.proof[k], "Invalid proof");
                }

                require(
                    _verify(root, market, epoch, start, duration, user.token, user.user, user.amount, user.proof),
                    "Invalid proof"
                );
            }
        }
    }

    function _verify(
        bytes32 root,
        address market,
        uint256 epoch,
        uint256 start,
        uint256 duration,
        address token,
        address user,
        uint256 amount,
        bytes32[] memory merkleProof
    ) internal pure returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(market, epoch, start, duration, token, user, amount));
        return merkleProof.verify(root, leaf);
    }

    function convertArrayOfMarketToString(Market[] storage m) internal view returns (string memory) {
        string memory str = '{"length":';
        str = string(abi.encodePacked(str, StringsUpgradeable.toString(m.length), ',"markets":['));

        for (uint256 i; i < m.length; i++) {
            str = string(abi.encodePacked(str, convertMarketToString(m[i])));
            if (i < m.length - 1) {
                str = string(abi.encodePacked(str, ","));
            }
        }
        str = string(abi.encodePacked(str, "]}"));
        return str;
    }

    function convertMarketToString(Market storage market) internal view returns (string memory) {
        string memory str = "{";
        str = string(abi.encodePacked(str, '"address":"', StringsUpgradeable.toHexString(market.market)));
        str = string(abi.encodePacked(str, '","start":', StringsUpgradeable.toString(market.start)));
        str = string(abi.encodePacked(str, ',"duration":', StringsUpgradeable.toString(market.duration)));
        str = string(abi.encodePacked(str, ',"epoch":', StringsUpgradeable.toString(market.epoch)));
        str = string(abi.encodePacked(str, ',"root":"', StringsUpgradeable.toHexString(uint256(market.root), 32)));
        str = string(abi.encodePacked(str, '","rewards":', convertArrayOfUserToString(market.users)));
        str = string(abi.encodePacked(str, "}"));
        return str;
    }

    function convertArrayOfUserToString(User[] storage users) internal view returns (string memory) {
        string memory str = "[";
        for (uint256 i; i < users.length; i++) {
            str = string(abi.encodePacked(str, convertUserToString(users[i])));
            if (i < users.length - 1) {
                str = string(abi.encodePacked(str, ","));
            }
        }
        str = string(abi.encodePacked(str, "]"));
        return str;
    }

    function convertUserToString(User storage user) internal view returns (string memory) {
        string memory str = "{";
        str = string(abi.encodePacked(str, '"user":"', StringsUpgradeable.toHexString(user.user)));
        str = string(abi.encodePacked(str, '","token":"', StringsUpgradeable.toHexString(user.token)));
        str = string(abi.encodePacked(str, '","amount":', StringsUpgradeable.toString(user.amount)));
        str = string(abi.encodePacked(str, ',"proof":', convertArrayOfBytes32ToString(user.proof)));
        str = string(abi.encodePacked(str, "}"));
        return str;
    }

    function convertArrayOfBytes32ToString(bytes32[] storage proof) internal view returns (string memory) {
        string memory str = "[";
        for (uint256 i; i < proof.length; i++) {
            str = string(abi.encodePacked(str, '"', StringsUpgradeable.toHexString(uint256(proof[i]), 32), '"'));
            if (i < proof.length - 1) {
                str = string(abi.encodePacked(str, ","));
            }
        }
        str = string(abi.encodePacked(str, "]"));
        return str;
    }
}
