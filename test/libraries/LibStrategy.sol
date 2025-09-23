// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Contracts
import { BeaconChain } from "../../src/BeaconChain.sol";
import { CompoundingValidatorManager } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingSSVStrategy.sol";
import { CompoundingStakingSSVStrategy } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingSSVStrategy.sol";

// Helpers
import { LibConstant } from "./LibConstant.sol";
import { LibValidator } from "./LibValidator.sol";

/// @notice Helper library for strategy-related functions or research.
library LibStrategy {
    using LibValidator for bytes;

    /// @notice Finds a validator with a specific status starting from a given index.
    /// @param strategy The strategy contract to query.
    /// @param status The list of statuses to match. If the validator's status matches any in the list, it is returned.
    /// @param validators The list of validator public keys to search through.
    /// @param index The starting index for the search.
    /// @return The public key of the found validator, or NOT_FOUND if none match.
    function validatorWithStatus(
        CompoundingStakingSSVStrategy strategy,
        CompoundingValidatorManager.ValidatorState[] memory status,
        bytes[] memory validators,
        uint256 index
    ) public view returns (bytes memory, CompoundingValidatorManager.ValidatorState) {
        uint256 len = validators.length;
        // Browse through all possible validators, find one that matches the criteria
        for (uint256 i = index; i < len + index; i++) {
            // Get the pubkey of the validator to check
            bytes memory pubkey = validators[i % len];

            // Fetch status from strategy
            (CompoundingValidatorManager.ValidatorState currentStatus,) = strategy.validator(pubkey.hashPubkey());

            // If status matches, return the pubkey
            for (uint256 j = 0; j < status.length; j++) {
                if (currentStatus == status[j]) return (pubkey, currentStatus);
            }
        }

        // If no validator found, return NOT_FOUND
        return (LibConstant.NOT_FOUND_BYTES, CompoundingValidatorManager.ValidatorState.NON_REGISTERED);
    }

    /// @notice Finds a validator with a specific status starting from a given index.
    /// @param strategy The strategy contract to query.
    /// @param status The list of statuses to match. If the validator's status matches any in the list, it is returned.
    /// @param validators The list of validator public keys to search through.
    /// @param index The starting index for the search.
    /// @return The public key of the found validator, or NOT_FOUND if none match.
    /// @return The status of the validator.
    // Todo: it could be nice to merge the 2 functions into one with a boolean to indicate if we want to check beacon chain
    // or not.
    function validatorWithStatusOnBeaconChain(
        CompoundingStakingSSVStrategy strategy,
        BeaconChain beaconChain,
        CompoundingValidatorManager.ValidatorState[] memory status,
        bytes[] memory validators,
        uint256 index
    ) public view returns (bytes memory, CompoundingValidatorManager.ValidatorState) {
        uint256 len = validators.length;
        // Browse through all possible validators, find one that matches the criteria
        for (uint256 i = index; i < len + index; i++) {
            // Get the pubkey of the validator to check
            bytes memory pubkey = validators[i % len];

            // Fetch status from strategy
            (CompoundingValidatorManager.ValidatorState currentStatus,) = strategy.validator(pubkey.hashPubkey());

            // Get validator status from beacon chain
            uint256 beaconIndex = beaconChain.getValidatorIndex(pubkey);

            // If status matches, return the pubkey
            for (uint256 j = 0; j < status.length; j++) {
                if (currentStatus == status[j] && beaconIndex != LibConstant.NOT_FOUND) return (pubkey, currentStatus);
            }
        }

        // If no validator found, return NOT_FOUND
        return (LibConstant.NOT_FOUND_BYTES, CompoundingValidatorManager.ValidatorState.NON_REGISTERED);
    }

    /// @notice Finds an ACTIVE or EXITING validator. If `fullWithdraw` we should ensure there is no pending deposit related
    /// to this validator.
    /// @param fullWithdraw If this is full or partial withdraw.
    /// @param index The starting index for the search.
    /// @return The public key of the found validator, or NOT_FOUND if none match.
    /// @return The status of the validator.
    function validatorWithStatusNoPending(
        CompoundingStakingSSVStrategy strategy,
        bytes[] memory validators,
        bool fullWithdraw,
        uint256 index
    ) public view returns (bytes memory, CompoundingValidatorManager.ValidatorState) {
        uint256 len = validators.length;
        // Browse through all possible validators, find one that matches the criteria
        for (uint256 i = index; i < len + index; i++) {
            // Get the pubkey of the validator to check
            bytes memory pubkey = validators[i % len];

            // Fetch status from strategy
            (CompoundingValidatorManager.ValidatorState currentStatus,) = strategy.validator(pubkey.hashPubkey());

            // We only want ACTIVE or EXITING validators
            if (
                currentStatus != CompoundingValidatorManager.ValidatorState.ACTIVE
                    && currentStatus != CompoundingValidatorManager.ValidatorState.EXITING
            ) continue;

            // If we want to do a partial withdrawal, don't need to ensure there is no pending deposits.
            if (!fullWithdraw) return (pubkey, currentStatus);

            // If we want to do a full withdrawal, ensure there is no pending deposits.
            uint256 pendingDeposits = strategy.depositListLength();
            bool hasPendingDeposit = false;

            // It should be quick as there is maximum 12 deposits.
            for (uint256 j; j < pendingDeposits; j++) {
                // Get pending deposit root
                bytes32 pendingDepositRoot = strategy.depositList(j);

                // Get the validator pubkey corresponding to the pending deposit
                (bytes32 pubKeyHash,,,,) = strategy.deposits(pendingDepositRoot);

                // If there is a pending deposit for this validator, skip it.
                if (pubKeyHash == pubkey.hashPubkey()) {
                    hasPendingDeposit = true;
                    break;
                }
            }

            // There is no pending deposit, this validator match all criteria.
            if (!hasPendingDeposit) return (pubkey, currentStatus);
        }

        // If no validator found, return NOT_FOUND
        return (LibConstant.NOT_FOUND_BYTES, CompoundingValidatorManager.ValidatorState.NON_REGISTERED);
    }

    /// @notice Find a deposit that is ready to get verified by the strategy.
    /// @param strategy The strategy contract to query.
    /// @param beaconChain The beacon chain contract to query.
    /// @param index The starting index for the search.
    /// @return The root of the found deposit.
    /// @return The public key hash of the associated validator.
    /// @return The slot of the deposit, or NOT_FOUND if none match.
    function depositToVerify(
        CompoundingStakingSSVStrategy strategy,
        BeaconChain beaconChain,
        uint256 index
    ) public view returns (bytes32, bytes32, uint64) {
        uint256 len = strategy.depositListLength();

        for (uint256 i = index; i < len + index; i++) {
            bytes32 pendingDepositRoot = strategy.depositList(i % len);

            // Fetch current status of the deposit in the beacon chain
            // If the deposit is not PROCESSED, skip it.
            BeaconChain.DepositStatus currentBeaconDepositStatus = beaconChain.processedDeposits(pendingDepositRoot);
            if (currentBeaconDepositStatus != BeaconChain.DepositStatus.PROCESSED) continue;

            // Fetch current status of the deposit in the strategy
            // If the deposit is not in PENDING status, skip it.
            (bytes32 pubKeyHash,, uint64 slot,, CompoundingValidatorManager.DepositStatus currentStrategyDepositStatus) =
                strategy.deposits(pendingDepositRoot);
            if (currentStrategyDepositStatus != CompoundingValidatorManager.DepositStatus.PENDING) continue;

            // Fetch current status of the validator in the strategy
            // If the validator is not VERIFIED, ACTIVE or EXITED, skip it.
            (CompoundingValidatorManager.ValidatorState currentStrategyValidatorStatus,) = strategy.validator(pubKeyHash);
            if (
                currentStrategyValidatorStatus != CompoundingValidatorManager.ValidatorState.VERIFIED
                    && currentStrategyValidatorStatus != CompoundingValidatorManager.ValidatorState.ACTIVE
                    && currentStrategyValidatorStatus != CompoundingValidatorManager.ValidatorState.EXITED
            ) continue;

            return (pendingDepositRoot, pubKeyHash, slot);
        }

        return (LibConstant.NOT_FOUND_BYTES32, LibConstant.NOT_FOUND_BYTES32, 0);
    }
}
