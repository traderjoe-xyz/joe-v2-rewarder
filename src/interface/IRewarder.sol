// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "openzeppelin-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IRewarder {
    error Rewarder__EpochCanceled();
    error Rewarder__InvalidProof();
    error Rewarder__InvalidRoot();
    error Rewarder__InvalidStart();
    error Rewarder__InvalidEpoch();
    error Rewarder__OverlappingEpoch();
    error Rewarder__EpochDoesNotExist();
    error Rewarder__EpochHasNotStarted();
    error Rewarder__OnlyValidLatestEpoch();
    error Rewarder__EpochHasEnded();
    error Rewarder__MarketNotWhitelisted();
    error Rewarder__MarketAlreadyWhitelisted();
    error Rewarder__NativeTransferFailed();
    error Rewarder__OnlyClaimForSelf();
    error Rewarder__EmptyMerkleEntries();
    error Rewarder__ClawbackDelayTooLow();
    error Rewarder__ClawbackDelayNotPassed();
    error Rewarder__ZeroAddress();

    /**
     * @dev Structure to store the Merkle root, the start and the duration of an epoch.
     * - `root` is the Merkle root of the epoch.
     * - `start` is the start of the epoch.
     * - `duration` is the duration of the epoch.
     * - `totalUnreleased` is the total amount of reward tokens that have not been released yet.
     */
    struct EpochParameters {
        bytes32 root;
        uint64 start;
        uint64 duration;
        uint128 totalUnreleased;
    }

    /**
     * @dev Structure to store the Merkle tree entry. It contains:
     * - `market` is the address of the market.
     * - `epoch` is the epoch of the market.
     * - `token` is the token address of the market.
     * - `user` is the user address.
     * - `amount` is the amount of tokens to be claimed.
     * - `merkleProof` is the Merkle proof of the claim.
     */
    struct MerkleEntry {
        address market;
        uint256 epoch;
        IERC20Upgradeable token;
        address user;
        uint128 amount;
        bytes32[] merkleProof;
    }

    event RewardClaimed(
        address indexed user,
        address indexed market,
        IERC20Upgradeable indexed token,
        uint256 epoch,
        uint128 released,
        uint128 unreleased
    );

    event EpochAdded(address indexed market, uint256 epoch, uint64 start, uint64 duration, bytes32 root);

    event EpochCanceled(address indexed market, uint256 epoch);

    event MarketAddedToWhitelisted(address indexed market);

    event MarketRemovedFromUnwhitelisted(address indexed market);

    event ClawbackDelayUpdated(uint96 newClawbackDelay);

    event ClawbackRecipientUpdated(address newClawbackRecipient);

    event RewardClawedBack(
        address indexed user,
        address indexed market,
        IERC20Upgradeable indexed token,
        uint256 epoch,
        uint128 clawbackAmount,
        address recipient,
        address sender
    );

    function PAUSER_ROLE() external view returns (bytes32);

    function UNPAUSER_ROLE() external view returns (bytes32);

    function CLAWBACK_ROLE() external view returns (bytes32);

    function getNumberOfWhitelistedMarkets() external view returns (uint256 count);

    function getWhitelistedMarket(uint256 index) external view returns (address market);

    function isWhitelistedMarket(address market) external view returns (bool isWhitelisted);

    function getNumberOfEpochs(address market) external view returns (uint256 epochs);

    function getEpochParameters(address market, uint256 epoch) external view returns (EpochParameters memory params);

    function getReleased(address market, uint256 epoch, IERC20Upgradeable token, address user)
        external
        view
        returns (uint128 released);

    function getReleasableAmount(
        address market,
        uint256 epoch,
        IERC20Upgradeable token,
        address user,
        uint128 amount,
        bytes32[] calldata merkleProof
    ) external view returns (uint128 releasable);

    function verify(
        address market,
        uint256 epoch,
        IERC20Upgradeable token,
        address user,
        uint128 amount,
        bytes32[] calldata merkleProof
    ) external view returns (bool isValid);

    function getBatchReleasableAmounts(MerkleEntry[] calldata merkleEntries)
        external
        view
        returns (uint128[] memory releasableAmounts);

    function getClawbackParameters() external view returns (address clawbackRecipient, uint96 clawbackDelay);

    function claim(
        address market,
        uint256 epoch,
        IERC20Upgradeable token,
        uint128 amount,
        bytes32[] calldata merkleProof
    ) external;

    function batchClaim(MerkleEntry[] calldata merkleEntries) external;

    function clawback(
        address market,
        uint256 epoch,
        IERC20Upgradeable token,
        address user,
        uint128 amount,
        bytes32[] calldata merkleProof
    ) external;

    function batchClawback(MerkleEntry[] calldata merkleEntries) external;

    function pause() external;

    function unpause() external;

    function setNewEpoch(address market, uint256 epoch, uint64 start, uint64 duration, uint128 total, bytes32 root)
        external;

    function cancelEpoch(address market, uint256 epoch) external;

    function addMarketToWhitelist(address market) external;

    function removeMarketFromWhitelist(address market) external;

    function setClawbackDelay(uint96 newClawbackDelay) external;

    function setClawbackRecipient(address newClawbackRecipient) external;
}
