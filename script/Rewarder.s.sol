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
 *       "epoch": <epoch of the market>,
 *       "start": <start of the vesting period>,
 *       "duration": <duration of the vesting period>,
 *       "length": <number of reward tokens>,
 *       "rewards": [
 *         {
 *           "address": <reward token address>,
 *           "totalRewards": <total amount of reward tokens to be distributed at the end of the vesting period>,
 *           "length": <number of users>,
 *           "users": [
 *             {
 *               "address": <user address>,
 *               "amount": <amount of reward tokens to be distributed at the end of the vesting period>
 *             },
 *             ...
 *           ]
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
 *       "epoch": <epoch of the market>,
 *       "start": <start of the vesting period>,
 *       "duration": <duration of the vesting period>,
 *       "root": <merkle root>,
 *       "length": <number of reward tokens>,
 *       "rewards": [
 *         {
 *           "address": <reward token address>,
 *           "totalRewards": <total amount of reward tokens to be distributed at the end of the vesting period>,
 *           "length": <number of users>,
 *           "users": [
 *             {
 *               "address": <user address>,
 *               "amount": <amount of reward tokens to be distributed at the end of the vesting period>,
 *               "proof": [<merkle proof>]
 *             },
 *             ...
 *           ]
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
    struct Market {
        uint128 duration;
        uint256 epoch;
        address market;
        bytes32 root;
        uint128 start;
        Reward[] rewards;
    }

    /**
     * @dev The structures are ordered in alphabetical order, don't change the order.
     */
    struct Reward {
        address token;
        uint256 totalRewards;
        User[] users;
    }

    /**
     * @dev The structures are ordered in alphabetical order, don't change the order.
     */
    struct User {
        uint256 amount;
        bytes32[] proof;
        address user;
    }

    Rewarder public rewarder;
    Merkle public merkle;

    Market[] private _markets;
    EnumerableSetUpgradeable.Bytes32Set private _set;

    // Dirty array, never cleaned up
    bytes32[] private _leaves;

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

        merkle = new Merkle();

        uint256 nbOfMarkets = abi.decode(vm.parseJson(json, ".length"), (uint256));

        for (uint256 i; i < nbOfMarkets; i++) {
            Market storage m = _markets.push();

            string memory mKey = string(abi.encodePacked(".markets[", StringsUpgradeable.toString(i), "]"));

            m.market = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".address"))), (address));
            m.epoch = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".epoch"))), (uint256));
            m.start = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".start"))), (uint128));
            m.duration = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".duration"))), (uint128));

            require(_set.add(keccak256(abi.encodePacked(m.market, m.epoch))), "Market already exists");
            require(rewarder.isMarketWhitelisted(m.market), "Market not whitelisted");
            require(rewarder.getNumberOfEpochs(m.market) == m.epoch, "Invalid epoch");
            require(m.start > block.timestamp, "Invalid start");
            require(m.duration <= 365 days, "Duration is probably too long");

            if (m.epoch > 0) {
                IRewarder.EpochParameters memory previousParams = rewarder.getEpochParameters(m.market, m.epoch - 1);
                require(previousParams.start + previousParams.duration <= m.start, "Overlapping epochs");
            }

            uint256 nbOfRewards = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".length"))), (uint256));

            for (uint256 j; j < nbOfRewards; j++) {
                Reward storage r = m.rewards.push();

                string memory rKey = string(abi.encodePacked(mKey, ".rewards[", StringsUpgradeable.toString(j), "]"));

                r.token = abi.decode(vm.parseJson(json, string(abi.encodePacked(rKey, ".address"))), (address));
                r.totalRewards =
                    abi.decode(vm.parseJson(json, string(abi.encodePacked(rKey, ".totalRewards"))), (uint256));

                require(r.totalRewards > 0, "Invalid total rewards");

                uint256 nbOfUsers = abi.decode(vm.parseJson(json, string(abi.encodePacked(rKey, ".length"))), (uint256));

                uint256 sumRewards;
                for (uint256 k; k < nbOfUsers; k++) {
                    User storage u = r.users.push();

                    string memory uKey = string(abi.encodePacked(rKey, ".users[", StringsUpgradeable.toString(k), "]"));

                    u.user = abi.decode(vm.parseJson(json, string(abi.encodePacked(uKey, ".address"))), (address));
                    u.amount = abi.decode(vm.parseJson(json, string(abi.encodePacked(uKey, ".amount"))), (uint256));

                    require(
                        _set.add(keccak256(abi.encodePacked(m.market, m.epoch, r.token, u.user))),
                        "User rewards already exists"
                    );
                    require(u.amount > 0, "Invalid amount");

                    sumRewards += u.amount;

                    bytes32 leaf =
                        keccak256(abi.encodePacked(m.market, m.epoch, m.start, m.duration, r.token, u.user, u.amount));

                    // Overwrite the previous storage slot, doesn't matter if it's empty or not
                    _leaves.push(leaf);
                }

                require(sumRewards == r.totalRewards, "Invalid total rewards");
            }

            bytes32 root = merkle.getRoot(_leaves);
            m.root = root;

            uint256 nbLeaf;
            for (uint256 j; j < nbOfRewards; j++) {
                Reward storage r = m.rewards[j];
                for (uint256 k; k < r.users.length; k++) {
                    User storage u = r.users[k];

                    bytes32[] memory proof = merkle.getProof(_leaves, nbLeaf++);
                    u.proof = proof;

                    require(
                        _verify(root, m.market, m.epoch, m.start, m.duration, r.token, u.user, u.amount, proof),
                        "Invalid proof"
                    );
                }
            }

            // Reset the length of the array, but doesn't free the storage
            assembly {
                sstore(_leaves.slot, 0)
            }
        }

        string memory out = convertArrayOfMarketToString(_markets);
        string memory f_out = string(abi.encodePacked("./files/out/", fileName, "-out.json"));

        vm.writeJson(out, f_out);

        // verifyGeneratedJSON(f_out);
    }

    // function verifyGeneratedJSON(string memory file) public {
    //     string memory json = vm.readFile(file);
    //     vm.closeFile(file);

    //     uint256 length = abi.decode(vm.parseJson(json, ".length"), (uint256));

    //     require(_markets.length == length, "Invalid length");

    //     for (uint256 i; i < length; i++) {
    //         Market storage m = _markets[i];

    //         string memory mKey = string(abi.encodePacked("._markets[", StringsUpgradeable.toString(i), "]"));

    //         address market = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".address"))), (address));
    //         uint256 epoch = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".epoch"))), (uint256));
    //         uint128 start = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".start"))), (uint128));
    //         uint128 duration = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".duration"))), (uint128));
    //         uint256 totalRewards =
    //             abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".totalRewards"))), (uint256));
    //         bytes32 root = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".root"))), (bytes32));

    //         require(_set.contains(keccak256(abi.encodePacked(market, epoch))), "Market does not exists");

    //         require(rewarder.isMarketWhitelisted(market), "Market is not whitelisted");
    //         require(start >= block.timestamp, "Invalid start");
    //         require(duration <= 365 days, "duration is probably too long");

    //         if (epoch > 0) {
    //             IRewarder.EpochParameters memory previousParams = rewarder.getEpochParameters(market, epoch - 1);
    //             require(previousParams.start + previousParams.duration <= start, "Overlapping epochs");
    //         }

    //         User[] memory users = abi.decode(vm.parseJson(json, string(abi.encodePacked(mKey, ".rewards"))), (User[]));

    //         for (uint256 j; j < users.length; j++) {
    //             User memory user = users[j];

    //             require(
    //                 _set.contains(keccak256(abi.encodePacked(market, epoch, user.token, user.user))),
    //                 "User rewards does not exists"
    //             );

    //             require(m.duration == duration, "Invalid duration");
    //             require(m.epoch == epoch, "Invalid epoch");
    //             require(m.market == market, "Invalid market");
    //             require(m.root == root, "Invalid root");
    //             require(m.start == start, "Invalid start");
    //             require(m.totalRewards == totalRewards, "Invalid total rewards");

    //             User storage u = m.users[j];

    //             require(u.user == user.user, "Invalid user");
    //             require(u.amount == user.amount, "Invalid amount");
    //             require(u.token == user.token, "Invalid token");

    //             require(u.proof.length == user.proof.length, "Invalid proof length");

    //             for (uint256 k; k < u.proof.length; k++) {
    //                 require(u.proof[k] == user.proof[k], "Invalid proof");
    //             }

    //             require(
    //                 _verify(root, market, epoch, start, duration, user.token, user.user, user.amount, user.proof),
    //                 "Invalid proof"
    //             );
    //         }
    //     }
    // }

    function _verify(
        bytes32 root,
        address market,
        uint256 epoch,
        uint128 start,
        uint128 duration,
        address token,
        address user,
        uint256 amount,
        bytes32[] memory merkleProof
    ) internal pure returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(market, epoch, start, duration, token, user, amount));
        return merkleProof.verify(root, leaf);
    }

    function convertArrayOfMarketToString(Market[] storage markets) internal view returns (string memory) {
        uint256 length = markets.length;

        string memory str = '{"length":';
        str = string(abi.encodePacked(str, StringsUpgradeable.toString(length), ',"markets":['));

        for (uint256 i; i < length; i++) {
            str = string(abi.encodePacked(str, convertMarketToString(markets[i])));
            if (i < length - 1) {
                str = string(abi.encodePacked(str, ","));
            }
        }
        str = string(abi.encodePacked(str, "]}"));
        return str;
    }

    function convertMarketToString(Market storage market) internal view returns (string memory) {
        string memory str = "{";
        str = string(abi.encodePacked(str, '"address":"', StringsUpgradeable.toHexString(market.market)));
        str = string(abi.encodePacked(str, '","epoch":', StringsUpgradeable.toString(market.epoch)));
        str = string(abi.encodePacked(str, ',"start":', StringsUpgradeable.toString(market.start)));
        str = string(abi.encodePacked(str, ',"duration":', StringsUpgradeable.toString(market.duration)));
        str = string(abi.encodePacked(str, ',"root":"', StringsUpgradeable.toHexString(uint256(market.root), 32)));
        str = string(abi.encodePacked(str, '","length":', StringsUpgradeable.toString(market.rewards.length)));
        str = string(abi.encodePacked(str, ',"rewards":', convertArrayOfRewarsToString(market.rewards)));
        str = string(abi.encodePacked(str, "}"));
        return str;
    }

    function convertArrayOfRewarsToString(Reward[] storage rewards) internal view returns (string memory) {
        uint256 length = rewards.length;

        string memory str = "[";
        for (uint256 i; i < length; i++) {
            str = string(abi.encodePacked(str, convertRewardToString(rewards[i])));
            if (i < length - 1) {
                str = string(abi.encodePacked(str, ","));
            }
        }
        str = string(abi.encodePacked(str, "]"));
        return str;
    }

    function convertRewardToString(Reward storage reward) internal view returns (string memory) {
        string memory str = "{";
        str = string(abi.encodePacked(str, '"address":"', StringsUpgradeable.toHexString(reward.token)));
        str = string(abi.encodePacked(str, '","totalRewards":', StringsUpgradeable.toString(reward.totalRewards)));
        str = string(abi.encodePacked(str, ',"length":', StringsUpgradeable.toString(reward.users.length)));
        str = string(abi.encodePacked(str, ',"users":', convertArrayOfUserToString(reward.users)));
        str = string(abi.encodePacked(str, "}"));
        return str;
    }

    function convertArrayOfUserToString(User[] storage users) internal view returns (string memory) {
        uint256 length = users.length;

        string memory str = "[";
        for (uint256 i; i < length; i++) {
            str = string(abi.encodePacked(str, convertUserToString(users[i])));
            if (i < length - 1) {
                str = string(abi.encodePacked(str, ","));
            }
        }
        str = string(abi.encodePacked(str, "]"));
        return str;
    }

    function convertUserToString(User storage user) internal view returns (string memory) {
        string memory str = "{";
        str = string(abi.encodePacked(str, '"address":"', StringsUpgradeable.toHexString(user.user)));
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
