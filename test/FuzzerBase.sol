// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Test imports
import { Setup } from "test/Setup.sol";

// Helpers
import { console } from "@forge-std/console.sol";
import { LibString } from "@solady/utils/LibString.sol";

// Target contracts
import { CompoundingValidatorManager } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingSSVStrategy.sol";

/// @title FuzzerBase
/// @notice Abstract base contract for fuzzing tests that hold all variable and helpers.
/// @dev    This contract is inherited by concrete fuzzing contracts to share common setup and utilities.

abstract contract FuzzerBase is Setup {
    using LibString for string;

    ////////////////////////////////////////////////////
    /// --- CONSTANTS & IMMUTABLES
    ////////////////////////////////////////////////////
    uint256 public constant NOT_FOUND = type(uint256).max;
    uint256 public constant MAX_DEPOSITS = 12;

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

    /// @notice Finds a validator with a specific status starting from a given index.
    /// @param status The desired validator status to search for.
    /// @param index The starting index for the search.
    /// @return The public key of the found validator, or NOT_FOUND if none match.
    function validatorWithStatus(
        CompoundingValidatorManager.ValidatorState status,
        uint256 index
    ) public view returns (bytes memory) {
        Validator[] memory _validators = validators;

        uint256 len = _validators.length;
        // Browse through all possible validators, find one that matches the criteria
        for (uint256 i = index; i < len + index; i++) {
            // Get the pubkey of the validator to check
            bytes memory pubkey = _validators[i % len].pubkey;

            // Fetch status from strategy
            (CompoundingValidatorManager.ValidatorState currentStatus,) = strategy.validator(pubkeyToHash[pubkey]);

            // If status matches, return the pubkey
            if (currentStatus == status) return pubkey;
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
        Validator[] memory _validators = validators;

        uint256 len = _validators.length;
        // Browse through all possible validators, find one that matches the criteria
        for (uint256 i = index; i < len + index; i++) {
            // Get the pubkey of the validator to check
            bytes memory pubkey = _validators[i % len].pubkey;

            // Fetch status from strategy
            (CompoundingValidatorManager.ValidatorState currentStatus,) = strategy.validator(pubkeyToHash[pubkey]);

            // If status matches, return the pubkey
            if (currentStatus == status1 || currentStatus == status2) return (pubkey, currentStatus);
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
        Validator[] memory _validators = validators;

        uint256 len = _validators.length;
        // Browse through all possible validators, find one that matches the criteria
        for (uint256 i = index; i < len + index; i++) {
            // Get the pubkey of the validator to check
            bytes memory pubkey = _validators[i % len].pubkey;

            // Fetch status from strategy
            (CompoundingValidatorManager.ValidatorState currentStatus,) = strategy.validator(pubkeyToHash[pubkey]);

            // If status matches, return the pubkey
            if (currentStatus == status1 || currentStatus == status2 || currentStatus == status3) {
                return (pubkey, currentStatus);
            }
        }

        // If no validator found, return NOT_FOUND
        return (abi.encodePacked(NOT_FOUND), CompoundingValidatorManager.ValidatorState.NON_REGISTERED);
    }

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
        return vm.toString(pubkey).slice(0, 5);
    }
}
