// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Test imports
import { Setup } from "test/Setup.sol";

// Helpers
import { console } from "@forge-std/console.sol";
import { LibString } from "@solady/utils/LibString.sol";

/// @title FuzzerBase
/// @notice Abstract base contract for fuzzing tests that hold all variable and helpers.
/// @dev    This contract is inherited by concrete fuzzing contracts to share common setup and utilities.

abstract contract FuzzerBase is Setup {
    using LibString for string;

    ////////////////////////////////////////////////////
    /// --- HELPERS
    ////////////////////////////////////////////////////

    /// @notice Returns the minimum of two uint256 values.
    /// @param a First uint256 value.
    /// @param b Second uint256 value.
    /// @return The minimum of the two values.
    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
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
