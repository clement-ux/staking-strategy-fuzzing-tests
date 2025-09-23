// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Test imports
import { Setup } from "test/Setup.sol";

// Helpers
import { console } from "@forge-std/console.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { LibValidator } from "test/libraries/LibValidator.sol";

// Target contracts
import { BeaconChain } from "src/BeaconChain.sol";
import { CompoundingValidatorManager } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingSSVStrategy.sol";

/// @title FuzzerBase
/// @notice Abstract base contract for fuzzing tests that hold all variable and helpers.
/// @dev    This contract is inherited by concrete fuzzing contracts to share common setup and utilities.

abstract contract FuzzerBase is Setup {
    using LibString for string;
    using LibValidator for bytes;

    ////////////////////////////////////////////////////
    /// --- CONSTANTS & IMMUTABLES
    ////////////////////////////////////////////////////
    uint64 public constant SLOT_DURATION = 12; // seconds

    uint256 public constant NOT_FOUND = type(uint256).max;
    uint256 public constant MAX_DEPOSITS = 12;
    uint256 public constant SNAP_BALANCES_DELAY = 35 * 12; // ~35 slots, i.e. ~7 minutes

    ////////////////////////////////////////////////////
    /// --- STORAGE
    ////////////////////////////////////////////////////

    ////////////////////////////////////////////////////
    /// --- HELPERS
    ////////////////////////////////////////////////////
    /// @notice Customize probability of executing a function.
    /// @param random Random number provided by the fuzzer.
    /// @param pct Probability percentage (0-100) to execute the function.
    modifier probability(uint256 random, uint256 pct) {
        vm.assume(random % 100 < pct);
        _;
    }

    /// @notice Returns the minimum of two uint256 values.
    /// @param a First uint256 value.
    /// @param b Second uint256 value.
    /// @return The minimum of the two values.
    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @notice Removes an element from a dynamic array by index, not preserving order.
    /// @param array The dynamic array from which to remove the element.
    /// @param index The index of the element to remove.
    function removeFromArray(bytes[] storage array, uint256 index) internal {
        require(index < array.length, "Index out of bounds");
        array[index] = array[array.length - 1];
        array.pop();
    }

    /// @notice Converts an array of bytes to a string representation.
    /// @param array The array of bytes to convert.
    /// @return A string representation of the array.
    function arrayIntoString(bytes[] memory array, uint256 stopAt) public pure returns (string memory) {
        if (array.length == 0) return "[]";
        string memory result = "[";
        for (uint256 i = 0; i < array.length && i < stopAt; i++) {
            result = string.concat(result, logPubkey(array[i]));
            if (i < array.length - 1 && i < stopAt - 1) result = string.concat(result, ", ");
        }
        result = string.concat(result, "]");
        return result;
    }

    /// @dev Calculates the timestamp of the next execution block from the given slot.
    /// @param slot The beacon chain slot number used for merkle proof verification.
    function calcNextBlockTimestamp(
        uint64 slot
    ) public pure returns (uint64) {
        // Calculate the next block timestamp from the slot.
        return SLOT_DURATION * slot + GENESIS_TIMESTAMP + SLOT_DURATION;
    }

    ////////////////////////////////////////////////////
    /// --- FIND VALIDATORS
    ////////////////////////////////////////////////////
    /// @notice Finds a validator with a specific status starting from a given index.
    /// @param status The desired validator status to search for.
    /// @param index The starting index for the search.
    /// @return The public key of the found validator, or NOT_FOUND if none match.
    function validatorWithStatus(
        CompoundingValidatorManager.ValidatorState status,
        uint256 index
    ) public view returns (bytes memory) {
        bytes[] memory _validators = validators;

        uint256 len = _validators.length;
        // Browse through all possible validators, find one that matches the criteria
        for (uint256 i = index; i < len + index; i++) {
            // Get the pubkey of the validator to check
            bytes memory pubkey = _validators[i % len];

            // Fetch status from strategy
            (CompoundingValidatorManager.ValidatorState currentStatus,) = strategy.validator(pubkey.hashPubkey());

            // If status matches, return the pubkey
            if (currentStatus == status) return pubkey;
        }

        // If no validator found, return NOT_FOUND
        return abi.encodePacked(NOT_FOUND);
    }

    /// @notice Finds an existing validator (i.e., registered on the beacon chain) with a specific status starting from a
    /// given index.
    /// @param status The desired validator status to search for.
    /// @param index The starting index for the search.
    /// @return The public key of the found validator, or NOT_FOUND if none match.
    function existingValidatorWithStatus(
        CompoundingValidatorManager.ValidatorState status,
        uint256 index
    ) public view returns (bytes memory) {
        bytes[] memory _validators = validators;

        uint256 len = _validators.length;
        // Browse through all possible validators, find one that matches the criteria
        for (uint256 i = index; i < len + index; i++) {
            // Get the pubkey of the validator to check
            bytes memory pubkey = _validators[i % len];

            // Fetch status from strategy
            (CompoundingValidatorManager.ValidatorState currentStatus,) = strategy.validator(pubkey.hashPubkey());

            // Get validator status from beacon chain
            uint256 beaconIndex = beaconChain.getValidatorIndex(pubkey);

            // If status matches, return the pubkey
            if (currentStatus == status && beaconIndex != NOT_FOUND) return pubkey;
        }

        // If no validator found, return NOT_FOUND
        return abi.encodePacked(NOT_FOUND);
    }

    /// @notice Finds a validator having one of the two specific statuses starting from a given index.
    /// @param status1 The first desired validator status to search for.
    /// @param status2 The second desired validator status to search for.
    /// @param index The starting index for the search.
    /// @return The public key of the found validator and its status, or NOT_FOUND if none match.
    function validatorWithStatus(
        CompoundingValidatorManager.ValidatorState status1,
        CompoundingValidatorManager.ValidatorState status2,
        uint256 index
    ) public view returns (bytes memory, CompoundingValidatorManager.ValidatorState) {
        bytes[] memory _validators = validators;

        uint256 len = _validators.length;
        // Browse through all possible validators, find one that matches the criteria
        for (uint256 i = index; i < len + index; i++) {
            // Get the pubkey of the validator to check
            bytes memory pubkey = _validators[i % len];

            // Fetch status from strategy
            (CompoundingValidatorManager.ValidatorState currentStatus,) = strategy.validator(pubkey.hashPubkey());

            // If status matches, return the pubkey
            if (currentStatus == status1 || currentStatus == status2) return (pubkey, currentStatus);
        }

        // If no validator found, return NOT_FOUND
        return (abi.encodePacked(NOT_FOUND), CompoundingValidatorManager.ValidatorState.NON_REGISTERED);
    }

    function pleaseFindBetterName(
        bool fullWithdraw,
        uint256 index
    ) public view returns (bytes memory, CompoundingValidatorManager.ValidatorState) {
        bytes[] memory _validators = validators;

        uint256 len = _validators.length;
        // Browse through all possible validators, find one that matches the criteria
        for (uint256 i = index; i < len + index; i++) {
            // Get the pubkey of the validator to check
            bytes memory pubkey = _validators[i % len];

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

            if (!hasPendingDeposit) return (pubkey, currentStatus);
        }

        // If no validator found, return NOT_FOUND
        return (abi.encodePacked(NOT_FOUND), CompoundingValidatorManager.ValidatorState.NON_REGISTERED);
    }

    /// @notice Finds a validator having one of the three specific statuses starting from a given index.
    /// @param status1 The first desired validator status to search for.
    /// @param status2 The second desired validator status to search for.
    /// @param status3 The third desired validator status to search for.
    /// @param index The starting index for the search.
    /// @return The public key of the found validator and its status, or NOT_FOUND if none match.
    function validatorWithStatus(
        CompoundingValidatorManager.ValidatorState status1,
        CompoundingValidatorManager.ValidatorState status2,
        CompoundingValidatorManager.ValidatorState status3,
        uint256 index
    ) public view returns (bytes memory, CompoundingValidatorManager.ValidatorState) {
        bytes[] memory _validators = validators;

        uint256 len = _validators.length;
        // Browse through all possible validators, find one that matches the criteria
        for (uint256 i = index; i < len + index; i++) {
            // Get the pubkey of the validator to check
            bytes memory pubkey = _validators[i % len];

            // Fetch status from strategy
            (CompoundingValidatorManager.ValidatorState currentStatus,) = strategy.validator(pubkey.hashPubkey());

            // If status matches, return the pubkey
            if (currentStatus == status1 || currentStatus == status2 || currentStatus == status3) {
                return (pubkey, currentStatus);
            }
        }

        // If no validator found, return NOT_FOUND
        return (abi.encodePacked(NOT_FOUND), CompoundingValidatorManager.ValidatorState.NON_REGISTERED);
    }

    ////////////////////////////////////////////////////
    /// --- FIND DEPOSITS
    ////////////////////////////////////////////////////
    /// @notice Finds a deposit with a specific status starting from a given index.
    /// @param status The desired deposit status to search for.
    /// @param index The starting index for the search.
    /// @return The root of the found deposit, or NOT_FOUND if none match.
    function depositWithStatus(
        CompoundingValidatorManager.DepositStatus status,
        uint256 index
    ) public view returns (bytes32) {
        uint256 len = strategy.depositListLength();

        for (uint256 i = index; i < len + index; i++) {
            bytes32 pendingDepositRoot = strategy.depositList(i % len);
            (,,,, CompoundingValidatorManager.DepositStatus currentStatus) = strategy.deposits(pendingDepositRoot);
            if (currentStatus == status) return pendingDepositRoot;
        }

        return (bytes32(abi.encodePacked(NOT_FOUND)));
    }

    /// @notice Finds a deposit and its associated validator with specific statuses starting from a given index.
    /// @param depositStatus The desired deposit status to search for.
    /// @param validatorStatus The desired validator status to search for.
    /// @param index The starting index for the search.
    /// @return The root of the found deposit and the public key hash of the associated validator, or NOT_FOUND if none
    /// match.
    function depositAndValidatorWithStatus(
        CompoundingValidatorManager.DepositStatus depositStatus,
        CompoundingValidatorManager.ValidatorState validatorStatus,
        uint256 index
    ) public view returns (bytes32, bytes32) {
        uint256 len = strategy.depositListLength();

        for (uint256 i = index; i < len + index; i++) {
            bytes32 pendingDepositRoot = strategy.depositList(i % len);

            // Fetch current status of the deposit
            (bytes32 pubKeyHash,,,, CompoundingValidatorManager.DepositStatus currentStrategyDepositStatus) =
                strategy.deposits(pendingDepositRoot);

            // Fetch current status of the validator
            (CompoundingValidatorManager.ValidatorState currentValidatorStatus,) = strategy.validator(pubKeyHash);

            if (currentStrategyDepositStatus == depositStatus && currentValidatorStatus == validatorStatus) {
                return (pendingDepositRoot, pubKeyHash);
            }
        }

        return (bytes32(abi.encodePacked(NOT_FOUND)), bytes32(abi.encodePacked(NOT_FOUND)));
    }

    struct ExpectedStatus {
        // Expected deposit status in the beacon chain
        BeaconChain.DepositStatus beaconDepositStatus;
        // Expected deposit status in the strategy
        CompoundingValidatorManager.DepositStatus strategyDepositStatus;
        // Array of acceptable validator statuses in the strategy
        CompoundingValidatorManager.ValidatorState[] validatorStatusArr;
    }

    /// @notice Finds a deposit and its associated validator matching expected statuses starting from a given index.
    /// @param expectedStatus The expected statuses for the deposit and validator.
    /// @param index The starting index for the search.
    /// @return The root of the found deposit, the public key hash of the associated validator, and the slot of the deposit,
    /// or NOT_FOUND if none match.
    function depositAndValidatorWithStatus(
        ExpectedStatus memory expectedStatus,
        uint256 index
    ) public view returns (bytes32, bytes32, uint64) {
        uint256 len = strategy.depositListLength();

        for (uint256 i = index; i < len + index; i++) {
            bytes32 pendingDepositRoot = strategy.depositList(i % len);

            (bool success, bytes32 pubKeyHash, uint64 slot) = areStatusCorrect(expectedStatus, pendingDepositRoot);
            if (success) return (pendingDepositRoot, pubKeyHash, slot);
        }

        return (bytes32(abi.encodePacked(NOT_FOUND)), bytes32(abi.encodePacked(NOT_FOUND)), 0);
    }

    function areStatusCorrect(
        ExpectedStatus memory expectedStatus,
        bytes32 pendingDepositRoot
    ) public view returns (bool, bytes32, uint64) {
        // Fetch current status of the deposit in the beacon chain
        BeaconChain.DepositStatus currentBeaconDepositStatus = beaconChain.processedDeposits(pendingDepositRoot);

        // Fetch current status of the deposit in the strategy
        (bytes32 pubKeyHash,, uint64 slot,, CompoundingValidatorManager.DepositStatus currentStrategyDepositStatus) =
            strategy.deposits(pendingDepositRoot);

        // Fetch current status of the validator in the strategy
        (CompoundingValidatorManager.ValidatorState currentStrategyValidatorStatus,) = strategy.validator(pubKeyHash);

        // Check if all statuses match the expected ones
        // forgefmt: disable-start
            // forgefmt: disable-end
        return (
            currentBeaconDepositStatus == expectedStatus.beaconDepositStatus
                && currentStrategyDepositStatus == expectedStatus.strategyDepositStatus
                && matchAtLeastOne(currentStrategyValidatorStatus, expectedStatus.validatorStatusArr),
            pubKeyHash,
            slot
        );
    }

    /// @notice Checks if a given validator status matches at least one status in an array.
    /// @param status The validator status to check.
    /// @param statusArr The array of validator statuses to match against.
    /// @return True if the status matches at least one in the array, false otherwise.
    function matchAtLeastOne(
        CompoundingValidatorManager.ValidatorState status,
        CompoundingValidatorManager.ValidatorState[] memory statusArr
    ) public pure returns (bool) {
        for (uint256 i = 0; i < statusArr.length; i++) {
            if (status == statusArr[i]) return true;
        }
        return false;
    }

    ////////////////////////////////////////////////////
    /// --- LOGGER
    ////////////////////////////////////////////////////
    /// @notice Logs a message if a condition is false, then assumes the condition is true for fuzzing.
    /// @param condition The condition to check.
    /// @param message The message to log if the condition is false.
    function logAssume(bool condition, string memory message) public pure {
        if (!condition) console.log(message);
        vm.assume(condition);
    }

    /// @notice Logs a truncated version of a public key for easier readability.
    /// @param pubkey The public key to log.
    function logPubkey(
        bytes memory pubkey
    ) public pure returns (string memory) {
        return vm.toString(pubkey).slice(0, 6);
    }

    function logUdid(
        bytes32 udid
    ) public pure returns (string memory) {
        return vm.toString(udid).slice(0, 6);
    }
}
