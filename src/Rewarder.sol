// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "openzeppelin-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "openzeppelin-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "openzeppelin-upgradeable/security/PausableUpgradeable.sol";
import "openzeppelin-upgradeable/proxy/utils/Initializable.sol";

import "./library/SafeAccessControlUpgradeable.sol";
import "./interface/IRewarder.sol";

/**
 * @title Rewarder
 * @author Trader Joe
 * @notice Rewarder contract for Trader Joe
 * This contract allows admin to add rewards for specific market and user.
 * Each (market, epoch, token, user) is used to create a Merkle tree.
 * The Merkle tree is used to verify the reward amount for each user and avoid admin having to set reward for each user.
 * The root is stored in this contract and can be accessed by anyone calling the `getRootAt(market, epoch)` function.
 * The rewards are distributed following a vesting schedule during the epoch.
 * The vesting schedule starts at `start` and ends at `start + duration`.
 * The user can claim the reward at any time during the vesting schedule by calling the
 * `claim(market, epoch, token, amount, merkleProof)` function.
 * The admins can start a new epoch, cancel the latest active epoch, or even pause the claim functions.
 */
contract Rewarder is
    Initializable,
    SafeAccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    IRewarder
{
    using MerkleProofUpgradeable for bytes32[];
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    bytes32 public constant override PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant override UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");
    bytes32 public constant override CLAWBACK_ROLE = keccak256("CLAWBACK_ROLE");

    EnumerableSetUpgradeable.AddressSet private _whitelistedMarkets;
    mapping(address => MerkleTreePeriod[]) private _merkleTrees;

    mapping(bytes32 => uint256) private _released;

    uint256 private _clawbackDelay;
    address private _clawbackRecipient;

    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract.
     * @param clawbackDelay The delay in seconds before the admin can clawback the unclaimed rewards.
     */
    function initialize(uint256 clawbackDelay) public initializer {
        __SafeAccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _setClawbackDelay(clawbackDelay);
        _setClawbackRecipient(msg.sender);
    }

    receive() external payable {}

    /**
     * @notice Returns the number of whitelisted markets.
     * @return count The number of whitelisted markets.
     */
    function getNumberOfWhitelistedMarkets() external view override returns (uint256 count) {
        return _whitelistedMarkets.length();
    }

    /**
     * @notice Returns the whitelisted market at the given index.
     * @param index The index of the whitelisted market.
     * @return market The whitelisted market.
     */
    function getWhitelistedMarket(uint256 index) external view override returns (address market) {
        return _whitelistedMarkets.at(index);
    }

    /**
     * @notice Returns whether the given market is whitelisted (true) or not (false).
     * @param market The market to check.
     * @return isWhitelisted Whether the given market is whitelisted (true) or not (false).
     */
    function isWhitelistedMarket(address market) external view override returns (bool isWhitelisted) {
        return _whitelistedMarkets.contains(market);
    }

    /**
     * @notice Returns the number of epochs for the given market.
     * @param market The market to check.
     * @return epochs The number of epochs for the given market.
     */
    function getNumberOfEpochs(address market) external view override returns (uint256 epochs) {
        return _merkleTrees[market].length;
    }

    /**
     * @notice Returns the root of the Merkle tree for the given market and epoch.
     * @param market The market to check.
     * @param epoch The epoch to check.
     * @return root The root of the Merkle tree for the given market and epoch.
     */
    function getRootAtEpoch(address market, uint256 epoch) external view override returns (bytes32 root) {
        return _merkleTrees[market][epoch].root;
    }

    /**
     * @notice Returns the period of the epoch for the given market and epoch.
     * @param market The market to check.
     * @param epoch The epoch to check.
     * @return start The start of the period.
     * @return duration The duration of the period.
     */
    function getVestingPeriodAtEpoch(address market, uint256 epoch)
        external
        view
        override
        returns (uint256 start, uint256 duration)
    {
        MerkleTreePeriod storage mtp = _merkleTrees[market][epoch];
        return (mtp.start, mtp.duration);
    }

    /**
     * @notice Returns the amount of reward released for the given market, epoch, token, and user.
     * @param market The market to check.
     * @param epoch The epoch to check.
     * @param token The token to check.
     * @param user The user to check.
     * @return released The amount of reward released for the given market, epoch, token, and user.
     */
    function getReleased(address market, uint256 epoch, IERC20Upgradeable token, address user)
        external
        view
        override
        returns (uint256 released)
    {
        return _released[_getReleasedId(market, epoch, token, user)];
    }

    /**
     * @notice Returns the amount of reward releasable for the given market, epoch, token, user, amount, and proof.
     * @param market The market to check.
     * @param epoch The epoch to check.
     * @param token The token to check.
     * @param user The user to check.
     * @param amount The amount to check.
     * @param merkleProof The merkle proof to check.
     * @return releasable The amount of reward releasable for the given market, epoch, token, user, amount, and proof.
     */
    function getReleasableAmount(
        address market,
        uint256 epoch,
        IERC20Upgradeable token,
        address user,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external view override returns (uint256 releasable) {
        return _getReleasableAmount(market, epoch, token, user, amount, merkleProof);
    }

    /**
     * @notice Returns whether the given market, epoch, token, user, amount, and proof are valid (true) or not (false).
     * @param market The market to check.
     * @param epoch The epoch to check.
     * @param token The token to check.
     * @param user The user to check.
     * @param amount The amount to check.
     * @param merkleProof The merkle proof to check.
     * @return isValid Whether the given market, epoch, token, user, amount, and proof are valid (true) or not (false).
     */
    function verify(
        address market,
        uint256 epoch,
        IERC20Upgradeable token,
        address user,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external view override returns (bool isValid) {
        MerkleTreePeriod storage mtp = _merkleTrees[market][epoch];

        return _verify(mtp.root, market, epoch, mtp.start, mtp.duration, token, user, amount, merkleProof);
    }

    /**
     * @notice Returns the releasable amount for each Merkle entry in the given list.
     * @dev Does not check if each tuple is unique.
     * @param merkleEntries The list of Merkle entries.
     * @return releasableAmounts The releasable amount for each entry.
     */
    function getBatchReleasableAmounts(MerkleEntry[] calldata merkleEntries)
        external
        view
        override
        returns (uint256[] memory releasableAmounts)
    {
        releasableAmounts = new uint256[](merkleEntries.length);

        for (uint256 i; i < merkleEntries.length;) {
            releasableAmounts[i] = _getReleasableAmount(
                merkleEntries[i].market,
                merkleEntries[i].epoch,
                merkleEntries[i].token,
                merkleEntries[i].user,
                merkleEntries[i].amount,
                merkleEntries[i].merkleProof
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Returns the clawback delay.
     * @return clawbackDelay The clawback delay.
     */
    function getClawbackDelay() external view override returns (uint256 clawbackDelay) {
        return _clawbackDelay;
    }

    /**
     * @notice Returns the clawback recipient.
     * @return clawbackRecipient The clawback recipient.
     */
    function getClawbackRecipient() external view override returns (address clawbackRecipient) {
        return _clawbackRecipient;
    }

    /**
     * @notice Claims the vested reward for the given market, epoch, token, amount, and merkle proof.
     * @param market The market to claim.
     * @param epoch The epoch to claim.
     * @param token The token to claim.
     * @param amount The amount to claim.
     * @param merkleProof The merkle proof to claim.
     */
    function claim(
        address market,
        uint256 epoch,
        IERC20Upgradeable token,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external override nonReentrant whenNotPaused {
        _claimForSelf(market, epoch, token, amount, merkleProof);
    }

    /**
     * @notice Claims the vested reward for each Merkle entry in the given list.
     * @dev Does not check if each entry is unique.
     * @param merkleEntries The list of merkle entries.
     */
    function batchClaim(MerkleEntry[] calldata merkleEntries) external override nonReentrant whenNotPaused {
        if (merkleEntries.length == 0) revert Rewarder__EmptyMerkleEntries();

        for (uint256 i; i < merkleEntries.length;) {
            if (merkleEntries[i].user != msg.sender) revert Rewarder__OnlyClaimForSelf();

            _claimForSelf(
                merkleEntries[i].market,
                merkleEntries[i].epoch,
                merkleEntries[i].token,
                merkleEntries[i].amount,
                merkleEntries[i].merkleProof
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Clawbacks the unclaimed reward for the given market, epoch, token, user, amount, and proof.
     * @dev Only callable by the owner or by anyone having the CLAWBACK_ROLE and after the clawback delay
     * once the epoch has ended.
     * @param market The market to clawback.
     * @param epoch The epoch to clawback.
     * @param token The token to clawback.
     * @param user The user to clawback.
     * @param amount The amount to clawback.
     * @param merkleProof The merkle proof to clawback.
     */
    function clawback(
        address market,
        uint256 epoch,
        IERC20Upgradeable token,
        address user,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external override nonReentrant whenNotPaused onlyOwnerOrRole(CLAWBACK_ROLE) {
        MerkleTreePeriod memory mtp = _merkleTrees[market][epoch];

        _clawback(market, epoch, token, user, amount, _clawbackRecipient, _clawbackDelay, merkleProof, mtp);
    }

    /**
     * @notice Pause the rewarder contract, preventing any claim.
     * @dev Only callable by the owner or by anyone having the PAUSER_ROLE.
     */
    function pause() external override onlyOwnerOrRole(PAUSER_ROLE) whenNotPaused {
        _pause();
    }

    /**
     * @notice Unpause the rewarder contract, allowing claims.
     * @dev Only callable by the owner or by anyone having the PAUSER_ROLE.
     */
    function unpause() external override onlyOwnerOrRole(UNPAUSER_ROLE) whenPaused {
        _unpause();
    }

    /**
     * @notice Sets the new epoch parameters for the given market, such as its start, duration and root.
     * @dev Only callable by the owner.
     * @param market The market to set.
     * @param epoch The epoch to set, it used to check if the epoch is valid.
     * @param start The start of the epoch.
     * @param duration The duration of the epoch.
     * @param root The root of the merkle tree.
     */
    function setNewEpoch(address market, uint256 epoch, uint256 start, uint256 duration, bytes32 root)
        external
        override
        onlyOwner
    {
        if (!_whitelistedMarkets.contains(market)) revert Rewarder__MarketNotWhitelisted();
        if (root == bytes32(0)) revert Rewarder__InvalidRoot();
        if (start == 0 || start < block.timestamp) revert Rewarder__InvalidStart();

        uint256 length = _merkleTrees[market].length;
        if (epoch != length) revert Rewarder__InvalidEpoch();

        if (length > 0) {
            MerkleTreePeriod storage previousVesting = _merkleTrees[market][length - 1];

            if (start < previousVesting.start + previousVesting.duration) revert Rewarder__OverlappingEpoch();
        }

        _merkleTrees[market].push(MerkleTreePeriod(root, start, duration));

        emit EpochAdded(market, epoch, start, duration, root);
    }

    /**
     * @notice Cancels the given epoch for the given market.
     * @dev Can only called the latest epoch that isn't cancelled yet. Only callable by the owner.
     * @param market The market to cancel.
     * @param epoch The epoch to cancel.
     */
    function cancelEpoch(address market, uint256 epoch) external override onlyOwner {
        uint256 length = _merkleTrees[market].length;
        if (epoch >= length) revert Rewarder__EpochDoesNotExist();

        if (epoch + 1 < length && _merkleTrees[market][epoch + 1].root != 0) {
            revert Rewarder__OnlyValidLatestEpoch();
        }

        // We also reset the start and duration to allow the creation of a new vesting period that could have overlapped
        // with the canceled one
        _merkleTrees[market][epoch] = MerkleTreePeriod(bytes32(0), 0, 0);

        emit EpochCanceled(market, epoch);
    }

    /**
     * @notice Adds the given market to the whitelist, allowing to set epochs for it and receive rewards.
     * @dev Only callable by the owner.
     */
    function addMarketToWhitelist(address market) external override onlyOwner {
        if (!_whitelistedMarkets.add(market)) revert Rewarder__MarketAlreadyWhitelisted();

        emit MarketAddedToWhitelisted(market);
    }

    /**
     * @notice Removes the given market from the whitelist, preventing to set epochs for it and receive further rewards.
     * @dev Only callable by the owner.
     */
    function removeMarketFromWhitelist(address market) external override onlyOwner {
        if (!_whitelistedMarkets.remove(market)) revert Rewarder__MarketNotWhitelisted();

        emit MarketRemovedFromUnwhitelisted(market);
    }

    /**
     * @notice Sets the clawback delay.
     * @dev Only callable by the owner.
     * @param newClawbackDelay The new clawback delay.
     */
    function setClawbackDelay(uint256 newClawbackDelay) external override onlyOwner {
        _setClawbackDelay(newClawbackDelay);
    }

    /**
     * @notice Sets the recipient of the clawbacked rewards.
     * @dev Only callable by the owner.
     * @param newRecipient The new recipient of the clawbacked rewards.
     */
    function setClawbackRecipient(address newRecipient) external override onlyOwner {
        _setClawbackRecipient(newRecipient);
    }

    /**
     * Internal Functions
     */

    /**
     * @dev Returns whether the parameters and the merkle proof are valid.
     * @param root The root of the merkle tree.
     * @param market The market to claim.
     * @param epoch The epoch to claim.
     * @param start The start of the epoch.
     * @param duration The duration of the epoch.
     * @param token The token to claim.
     * @param user The user to claim.
     * @param amount The amount to claim.
     * @param merkleProof The merkle proof to claim.
     * @return isValid Whether the parameters and the merkle proof are valid.
     */
    function _verify(
        bytes32 root,
        address market,
        uint256 epoch,
        uint256 start,
        uint256 duration,
        IERC20Upgradeable token,
        address user,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) internal pure returns (bool isValid) {
        bytes32 leaf = keccak256(abi.encodePacked(market, epoch, start, duration, token, user, amount));

        return merkleProof.verifyCalldata(root, leaf);
    }

    /**
     * @dev Returns the vested amount for a given start, duration and amount.
     * @param start The start of the epoch.
     * @param duration The duration of the epoch.
     * @param amount The amount to claim.
     * @return vestedAmount The vested amount for a given start, duration and amount.
     */
    function _vestingSchedule(uint256 start, uint256 duration, uint256 amount)
        internal
        view
        returns (uint256 vestedAmount)
    {
        if (block.timestamp < start) return 0;
        if (block.timestamp >= start + duration) return amount;
        return amount * (block.timestamp - start) / duration;
    }

    /**
     * @dev Helper function to transfer native or ERC20 tokens. The address(0) is used to represent native tokens.
     * @param token The token to transfer.
     * @param user The user to transfer to.
     * @param amount The amount to transfer.
     */
    function _transferNativeOrERC20(IERC20Upgradeable token, address user, uint256 amount) internal {
        if (token == IERC20Upgradeable(address(0))) {
            (bool success,) = user.call{value: amount}("");
            if (!success) revert Rewarder__NativeTransferFailed();
        } else {
            token.safeTransfer(user, amount);
        }
    }

    /**
     * @dev Return the releasable amount of token.
     * @param market The market to check.
     * @param epoch The epoch to check.
     * @param token The token to check.
     * @param user The user to check.
     * @param amount The amount to check.
     * @param merkleProof The merkle proof to check.
     * @return releasable The releasable amount of token.
     */
    function _getReleasableAmount(
        address market,
        uint256 epoch,
        IERC20Upgradeable token,
        address user,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) internal view returns (uint256 releasable) {
        MerkleTreePeriod memory mtp = _merkleTrees[market][epoch];

        if (_verify(mtp.root, market, epoch, mtp.start, mtp.duration, token, user, amount, merkleProof)) {
            bytes32 id = _getReleasedId(market, epoch, token, user);
            releasable = _vestingSchedule(mtp.start, mtp.duration, amount) - _released[id];
        }
    }

    /**
     * @dev Return the released id.
     * @param market The market to check.
     * @param epoch The epoch to check.
     * @param token The token to check.
     * @param user The user to check.
     * @return id The released id.
     */
    function _getReleasedId(address market, uint256 epoch, IERC20Upgradeable token, address user)
        internal
        pure
        returns (bytes32 id)
    {
        return keccak256(abi.encodePacked(market, epoch, token, user));
    }

    function _claimForSelf(
        address market,
        uint256 epoch,
        IERC20Upgradeable token,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) internal {
        (uint256 amountToRelease, uint256 unreleased) =
            _claim(market, epoch, token, msg.sender, amount, msg.sender, merkleProof);

        emit RewardClaimed(msg.sender, market, token, epoch, amountToRelease, unreleased);
    }

    /**
     * @dev Claims the vested amount for the given market, epoch, token, user, amount and merkle proof.
     * @param market The market to claim.
     * @param epoch The epoch to claim.
     * @param token The token to claim.
     * @param user The user to claim.
     * @param amount The amount to claim.
     * @param merkleProof The merkle proof to claim.
     */
    function _claim(
        address market,
        uint256 epoch,
        IERC20Upgradeable token,
        address user,
        uint256 amount,
        address recipient,
        bytes32[] calldata merkleProof
    ) internal returns (uint256 amountToRelease, uint256 unreleased) {
        MerkleTreePeriod memory mtp = _merkleTrees[market][epoch];

        if (mtp.root == bytes32(0)) revert Rewarder__EpochCanceled();

        if (!_verify(mtp.root, market, epoch, mtp.start, mtp.duration, token, user, amount, merkleProof)) {
            revert Rewarder__InvalidProof();
        }

        bytes32 id = _getReleasedId(market, epoch, token, user);

        uint256 released = _released[id];
        amountToRelease = _vestingSchedule(mtp.start, mtp.duration, amount) - released;

        if (amountToRelease > 0) {
            uint256 totalReleased = released + amountToRelease;

            _released[id] = totalReleased;
            unreleased = amount - totalReleased;

            _transferNativeOrERC20(token, recipient, amountToRelease);
        }
    }

    /**
     * @dev Sets the clawback delay.
     * @param newClawbackDelay The new clawback delay.
     */
    function _setClawbackDelay(uint256 newClawbackDelay) internal {
        if (newClawbackDelay < 1 days) revert Rewarder__ClawbackDelayTooLow();

        _clawbackDelay = newClawbackDelay;

        emit ClawbackDelayUpdated(newClawbackDelay);
    }

    /**
     * @dev Sets the clawback recipient.
     * @param newClawbackRecipient The new clawback recipient.
     */
    function _setClawbackRecipient(address newClawbackRecipient) internal {
        if (newClawbackRecipient == address(0)) revert Rewarder__ZeroAddress();

        _clawbackRecipient = newClawbackRecipient;

        emit ClawbackRecipientUpdated(newClawbackRecipient);
    }

    /**
     * @dev Clawbacks the vested amount for the given market, epoch, token, user, amount and merkle proof.
     * @param market The market to clawback.
     * @param epoch The epoch to clawback.
     * @param token The token to clawback.
     * @param user The user to clawback.
     * @param amount The amount to clawback.
     * @param merkleProof The merkle proof to clawback.
     */
    function _clawback(
        address market,
        uint256 epoch,
        IERC20Upgradeable token,
        address user,
        uint256 amount,
        address recipient,
        uint256 clawbackDelay,
        bytes32[] calldata merkleProof,
        MerkleTreePeriod memory mtp
    ) internal {
        if (block.timestamp < mtp.start + mtp.duration + clawbackDelay) revert Rewarder__ClawbackDelayNotPassed();

        (uint256 clawedBackAmount,) = _claim(market, epoch, token, user, amount, recipient, merkleProof);

        emit RewardClawedBack(user, market, token, epoch, clawedBackAmount, recipient, msg.sender);
    }
}
