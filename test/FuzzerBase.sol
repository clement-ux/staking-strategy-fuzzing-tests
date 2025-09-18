// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

/// @title FuzzerBase
/// @notice Abstract base contract for fuzzing tests that hold all variable and helpers.
/// @dev    This contract is inherited by concrete fuzzing contracts to share common setup and utilities.
abstract contract FuzzerBase {
    ////////////////////////////////////////////////////
    /// --- CONSTANTS & IMMUTABLES
    ////////////////////////////////////////////////////
    uint256 public constant MAX_DEPOSITS = 12;

    ////////////////////////////////////////////////////
    /// --- STORAGE
    ////////////////////////////////////////////////////
    bytes[] public registeredSsvValidators; // Validators that are marked as registered
    bytes[] public stakedValidators; // Validators that are marked as staked
    bytes[] public verifiedValidators; // Validators that are marked as verified

    ////////////////////////////////////////////////////
    /// --- HELPERS
    ////////////////////////////////////////////////////
    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    function removeFromArray(bytes[] storage array, uint256 index) internal {
        require(index < array.length, "Index out of bounds");
        array[index] = array[array.length - 1];
        array.pop();
    }
}
