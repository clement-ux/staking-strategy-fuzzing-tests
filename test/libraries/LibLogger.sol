// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Helpers
import { Vm } from "@forge-std/Vm.sol";
import { console } from "@forge-std/console.sol";
import { LibString } from "@solady/utils/LibString.sol";

library LibLogger {
    using LibString for string;

    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

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

    /// @notice Logs a message if a condition is false, then assumes the condition is true for fuzzing.
    /// @param message The message to log if the condition is false.
    function logAssume(
        string memory message
    ) public pure {
        console.log(message);
        vm.assume(false);
    }

    /// @notice Logs a truncated version of a public key for easier readability.
    /// @param pubkey The public key to log.
    function logPubkey(
        bytes memory pubkey
    ) public pure returns (string memory) {
        return vm.toString(pubkey).slice(0, 6);
    }

    /// @notice Logs a truncated version of a UDID for easier readability.
    /// @param udid The UDID to log.
    function logUdid(
        bytes32 udid
    ) public pure returns (string memory) {
        return vm.toString(udid).slice(0, 6);
    }
}
