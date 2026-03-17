// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ECDSA} from "@openzeppelin-contracts-5.3.0/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.3.0/utils/cryptography/MessageHashUtils.sol";
import {SafeCast} from "@openzeppelin-contracts-5.3.0/utils/math/SafeCast.sol";

contract IncentivePool is Auth {
    using SafeTransferLib for ERC20;
    using SafeCast for uint256;

    error InvalidToken();
    error InvalidSigner();
    error InvalidAddress();
    error InvalidDeadline();
    error RateLimitExceeded();
    error TotalRewardCapExceeded();
    error RewardsDisabled();
    error Blacklisted();

    event SecondsBetweenClaimsSet(uint256 secondsBetweenClaims);
    event RewardSignerSet(address indexed rewardSigner);
    event RewardsProcessed(address indexed rewardsRecipient, uint256 amountClaimed);
    event MaximumRewardAmountPerClaimSet(uint256 maxRewardAmount);
    event MaxDeadlineSet(uint256 maxDeadline);
    event TotalRewardCapSet(uint256 totalRewardCap);
    event FundsRescued(address indexed token, address indexed to, uint256 amount);
    event BlacklistUpdated(address indexed user, bool status);

    /// @notice The reward token
    ERC20 public immutable REWARD_TOKEN;

    /// @notice The address of the reward signer (centralized backend)
    address public rewardSigner;
    /// @notice The maximum reward amount for the rewards to be processed per delta
    uint96 public maximumRewardAmountPerClaim; // Packed with rewardSigner (20 + 12 = 32 bytes)

    /// @notice The maximum deadline for the rewards to be processed
    uint32 public maxDeadline; // Packed: maxDeadline (4) + secondsBetweenClaims (4) + totalRewardCap (13) = 21 bytes
    /// @notice The rate limit between claims
    uint32 public secondsBetweenClaims;
    /// @notice The maximum total rewards a single user can ever claim
    uint104 public totalRewardCap;

    /// @notice Whether a user is blacklisted from claiming rewards
    mapping(address => bool) public blacklisted;

    /// @notice A struct to store the claim checkpoint (packed into 1 slot: 48 + 208 = 256)
    struct ClaimCheckpoint {
        /// @notice The timestamp of the claim
        uint48 timestamp;
        /// @notice The cumulative total rewards claimed by this user up to and including this checkpoint
        uint208 cumulativeClaimed;
    }

    /// @notice A mapping of user addresses to their claim history
    mapping(address user => ClaimCheckpoint[]) internal _claimHistory;

    constructor(address _owner, ERC20 rewardToken) Auth(_owner, Authority(address(0))) {
        if (address(rewardToken) == address(0)) revert InvalidToken();
        REWARD_TOKEN = rewardToken;
    }

    //============================== RESTRICTED FUNCTIONS ===============================

    /**
     * @notice Sets the reward signer
     * @param newSigner The address of the reward signer
     * @dev Callable by OWNER_ROLE.
     *      When rotating keys, do not reuse a previously active signer address.
     *      Reusing a retired key would re-enable any unexpired signatures issued under that key.
     */
    function setRewardSigner(address newSigner) external requiresAuth {
        if (newSigner == address(0)) revert InvalidSigner();
        rewardSigner = newSigner;
        emit RewardSignerSet(newSigner);
    }

    /**
     * @notice Sets the maximum reward amount for the rewards to be processed
     * @param newMaximumRewardAmountPerClaim The new maximum reward amount for the rewards to be processed
     * @dev Callable by OWNER_ROLE.
     */
    function setMaximumRewardAmountPerClaim(uint96 newMaximumRewardAmountPerClaim) external requiresAuth {
        maximumRewardAmountPerClaim = newMaximumRewardAmountPerClaim;
        emit MaximumRewardAmountPerClaimSet(newMaximumRewardAmountPerClaim);
    }

    /**
     * @notice Sets the blacklist status for a user
     * @param user The address of the user to blacklist or unblacklist
     * @param status True to blacklist, false to unblacklist
     * @dev Callable by OWNER_ROLE.
     */
    function setBlacklisted(address user, bool status) external requiresAuth {
        blacklisted[user] = status;
        emit BlacklistUpdated(user, status);
    }

    /**
     * @notice Sets the maximum deadline for the rewards to be processed
     * @param newMaxDeadline The new maximum deadline for the rewards to be processed
     * @dev Callable by OWNER_ROLE.
     */
    function setMaxDeadline(uint32 newMaxDeadline) external requiresAuth {
        maxDeadline = newMaxDeadline;
        emit MaxDeadlineSet(newMaxDeadline);
    }

    /**
     * @notice Sets the time limit between claims
     * @param newSecondsBetweenClaims The time limit between claims in seconds
     * @dev Callable by OWNER_ROLE. Set secondsBetweenClaims to max uint32 to disable withdrawal of rewards.
     */
    function setSecondsBetweenClaims(uint32 newSecondsBetweenClaims) external requiresAuth {
        secondsBetweenClaims = newSecondsBetweenClaims;
        emit SecondsBetweenClaimsSet(newSecondsBetweenClaims);
    }

    /**
     * @notice Sets the maximum total rewards a single user can ever claim
     * @param newTotalRewardCap The new total reward cap per user
     * @dev Callable by OWNER_ROLE. Set to 0 to disable withdrawal of rewards.
     */
    function setTotalRewardCap(uint104 newTotalRewardCap) external requiresAuth {
        totalRewardCap = newTotalRewardCap;
        emit TotalRewardCapSet(newTotalRewardCap);
    }

    /**
     * @notice Rescues funds from the contract
     * @param token The token to rescue
     * @param to The address to send the funds to
     * @param amount The amount of funds to rescue
     * @dev Callable by OWNER_ROLE.
     */
    function rescueFunds(ERC20 token, address to, uint256 amount) external requiresAuth {
        if (to == address(0)) revert InvalidAddress();
        token.safeTransfer(to, amount);
        emit FundsRescued(address(token), to, amount);
    }

    /**
     * @notice Processes rewards for a recipient based on a signed cumulative rewards amount
     * @param rewardsRecipient The address of the rewards recipient
     * @param cumulativeRewards The cumulative amount of rewards owed to the rewards recipient
     * @param deadline The deadline for the rewards to be processed
     * @param signature The signature from the backend to verify the reward parameters
     * @return The amount of rewards processed between the last claim and the current claim
     * @dev Callable by TELLER_ROLE.
     */
    function processRewards(
        address rewardsRecipient,
        uint256 cumulativeRewards,
        uint256 deadline,
        bytes calldata signature
    ) external requiresAuth returns (uint256) {
        if (blacklisted[rewardsRecipient]) revert Blacklisted();
        uint256 totalRewardCapMemory = totalRewardCap;
        uint256 maximumRewardAmountPerClaimMemory = maximumRewardAmountPerClaim;
        if (totalRewardCapMemory == 0 || maximumRewardAmountPerClaimMemory == 0) revert RewardsDisabled();
        if (block.timestamp > deadline) revert InvalidDeadline();
        if (deadline > block.timestamp + maxDeadline) revert InvalidDeadline();

        (uint256 lastClaimTimestamp, uint256 totalClaimed) = _getLastCheckpointData(rewardsRecipient);
        if (block.timestamp < (lastClaimTimestamp + secondsBetweenClaims)) revert RateLimitExceeded();

        _checkSignature(rewardsRecipient, cumulativeRewards, deadline, signature);

        uint256 amountToSend = _calculateAmountToSend(
            totalClaimed, cumulativeRewards, maximumRewardAmountPerClaimMemory, totalRewardCapMemory
        );

        if (amountToSend == 0) return 0;

        _claimHistory[rewardsRecipient].push(
            ClaimCheckpoint({
                timestamp: block.timestamp.toUint48(), cumulativeClaimed: (totalClaimed + amountToSend).toUint208()
            })
        );

        REWARD_TOKEN.safeTransfer(rewardsRecipient, amountToSend);

        emit RewardsProcessed(rewardsRecipient, amountToSend);

        return amountToSend;
    }

    function _calculateAmountToSend(
        uint256 totalClaimed,
        uint256 cumulativeRewards,
        uint256 _maximumRewardAmountPerClaim,
        uint256 _totalRewardCap
    ) internal pure returns (uint256 amountToSend) {
        // No-op if nothing to claim (allows withdrawWithRewards to succeed even without pending rewards)
        if (cumulativeRewards <= totalClaimed) return 0;
        amountToSend = cumulativeRewards - totalClaimed;
        // Cap the amount to the maximum reward amount per claim
        if (amountToSend > _maximumRewardAmountPerClaim) {
            amountToSend = _maximumRewardAmountPerClaim;
        }

        // Recalculate amountToSend based on the total reward cap defined by the owner of the smart contract
        if (totalClaimed < _totalRewardCap) {
            uint256 remainingCap = _totalRewardCap - totalClaimed;
            if (amountToSend > remainingCap) {
                amountToSend = remainingCap;
            }
        } else {
            revert TotalRewardCapExceeded();
        }
    }

    function _checkSignature(
        address rewardsRecipient,
        uint256 cumulativeRewards,
        uint256 deadline,
        bytes calldata signature
    ) internal view {
        bytes32 messageHash = keccak256(
            abi.encode(
                address(this), // prevents cross-pool replay
                block.chainid, // prevents cross-chain replay
                rewardsRecipient, // prevents impersonation
                cumulativeRewards, // cumulative total amount of rewards
                deadline // expiry
            )
        );
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address recovered = ECDSA.recover(ethSignedHash, signature);

        if (recovered != rewardSigner) revert InvalidSigner();
    }

    function _getLastCheckpointData(address user) internal view returns (uint256 lastTimestamp, uint256 totalClaimed) {
        uint256 len = _claimHistory[user].length;
        if (len == 0) return (0, 0);
        ClaimCheckpoint storage checkpoint = _claimHistory[user][len - 1];
        lastTimestamp = checkpoint.timestamp;
        totalClaimed = checkpoint.cumulativeClaimed;
    }

    /**
     * @param user The address of the user to get the last claim timestamp for
     * @return The last claim timestamp
     */
    function getLastClaimTimestamp(address user) public view returns (uint256) {
        (uint256 ts,) = _getLastCheckpointData(user);
        return ts;
    }

    /**
     * @param user The address of the user to get the claim history for
     * @dev Used for off chain reporting and calculations of rewards earned
     * @return The claim history
     */
    function getClaimHistory(address user) external view returns (ClaimCheckpoint[] memory) {
        return _claimHistory[user];
    }

    /**
     * @notice Returns a paginated slice of a user's claim history
     * @param user The address of the user
     * @param startIndex The starting index (inclusive)
     * @param endIndex The ending index (exclusive)
     * @return checkpoints The claim checkpoints in the requested range
     * @return totalLength The total number of checkpoints for this user
     */
    function getClaimHistoryPaginated(address user, uint256 startIndex, uint256 endIndex)
        external
        view
        returns (ClaimCheckpoint[] memory checkpoints, uint256 totalLength)
    {
        totalLength = _claimHistory[user].length;
        if (startIndex >= totalLength) return (checkpoints, totalLength);
        if (endIndex > totalLength) endIndex = totalLength;

        uint256 count = endIndex - startIndex;
        checkpoints = new ClaimCheckpoint[](count);
        for (uint256 i; i < count; ++i) {
            checkpoints[i] = _claimHistory[user][startIndex + i];
        }
    }

    /**
     * @notice Returns the last claim timestamp and total claimed amount for a user
     * @param user The address of the user
     * @return lastTimestamp The timestamp of the user's last claim
     * @return totalClaimed The cumulative total rewards claimed by the user
     */
    function getLastCheckpointData(address user) external view returns (uint256 lastTimestamp, uint256 totalClaimed) {
        return _getLastCheckpointData(user);
    }

    /**
     * @param user The address of the user to get the claimed amount for
     * @return totalClaimed The total amount of rewards claimed from this pool by the user
     */
    function getTotalClaimedAmount(address user) public view returns (uint256) {
        (, uint256 claimed) = _getLastCheckpointData(user);
        return claimed;
    }
}
