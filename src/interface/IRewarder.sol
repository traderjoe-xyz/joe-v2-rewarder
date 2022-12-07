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
     */
    struct MerkleTreePeriod {
        bytes32 root;
        uint256 start;
        uint256 duration;
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
        uint256 amount;
        bytes32[] merkleProof;
    }

    event RewardClaimed(
        address indexed user,
        address indexed market,
        IERC20Upgradeable indexed token,
        uint256 epoch,
        uint256 released,
        uint256 unreleased
    );

    event EpochAdded(address indexed market, uint256 epoch, uint256 start, uint256 duration, bytes32 root);

    event EpochCanceled(address indexed market, uint256 epoch);

    event MarketAddedToWhitelisted(address indexed market);

    event MarketRemovedFromUnwhitelisted(address indexed market);

    event ClawbackDelayUpdated(uint256 newClawbackDelay);

    event ClawbackRecipientUpdated(address newClawbackRecipient);

    event RewardClawedBack(
        address indexed user,
        address indexed market,
        IERC20Upgradeable indexed token,
        uint256 epoch,
        uint256 clawbackAmount,
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

    function getRootAtEpoch(address market, uint256 epoch) external view returns (bytes32 root);

    function getVestingPeriodAtEpoch(address market, uint256 epoch)
        external
        view
        returns (uint256 start, uint256 duration);

    function getReleased(address market, uint256 epoch, IERC20Upgradeable token, address user)
        external
        view
        returns (uint256 released);

    function getReleasableAmount(
        address market,
        uint256 epoch,
        IERC20Upgradeable token,
        address user,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external view returns (uint256 releasable);

    function verify(
        address market,
        uint256 epoch,
        IERC20Upgradeable token,
        address user,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external view returns (bool isValid);

    function getBatchReleasableAmounts(MerkleEntry[] calldata merkleEntries)
        external
        view
        returns (uint256[] memory releasableAmounts);

    function getClawbackDelay() external view returns (uint256 clawbackDelay);

    function getClawbackRecipient() external view returns (address clawbackRecipient);

    function claim(
        address market,
        uint256 epoch,
        IERC20Upgradeable token,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external;

    function batchClaim(MerkleEntry[] calldata merkleEntries) external;

    function clawback(
        address market,
        uint256 epoch,
        IERC20Upgradeable token,
        address user,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external;

    function pause() external;

    function unpause() external;

    function setNewEpoch(address market, uint256 epoch, uint256 start, uint256 duration, bytes32 root) external;

    function cancelEpoch(address market, uint256 epoch) external;

    function addMarketToWhitelist(address market) external;

    function removeMarketFromWhitelist(address market) external;

    function setClawbackDelay(uint256 newClawbackDelay) external;

    function setClawbackRecipient(address newClawbackRecipient) external;
}
