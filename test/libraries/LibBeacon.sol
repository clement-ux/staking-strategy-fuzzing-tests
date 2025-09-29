// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Contracts
import { BeaconChain } from "../../src/BeaconChain.sol";

// Helpers
import { LibConstant } from "./LibConstant.sol";

library LibBeacon {
    /// @dev Calculates the timestamp of the next execution block from the given slot.
    /// @param slot The beacon chain slot number used for merkle proof verification.
    function calcNextBlockTimestamp(
        uint64 slot
    ) public pure returns (uint64) {
        // Calculate the next block timestamp from the slot.
        return LibConstant.SLOT_DURATION * slot + LibConstant.GENESIS_TIMESTAMP + LibConstant.SLOT_DURATION;
    }

    /// @notice Counts the number of validators with a specific status in the BeaconChain.
    /// @return count The number of validators with the ACTIVE status.
    function countActiveValidator(
        BeaconChain beaconChain
    ) public view returns (uint256 count) {
        BeaconChain.Validator[] memory validators = beaconChain.getValidators();
        uint256 len = validators.length;
        for (uint256 i = 0; i < len; i++) {
            if (validators[i].status == BeaconChain.Status.ACTIVE) count++;
        }
    }

    /// @notice Finds a validator with the ACTIVE status.
    /// @param index The starting index for the search.
    /// @return The first validator found with the ACTIVE status, or a default "not found" validator if none is found.
    function findActiveValidator(BeaconChain beaconChain, uint8 index) public view returns (BeaconChain.Validator memory) {
        BeaconChain.Validator[] memory validators = beaconChain.getValidators();
        uint256 len = validators.length;
        for (uint256 i = index; i < len + index; i++) {
            if (validators[i % len].status == BeaconChain.Status.ACTIVE) return validators[i % len];
        }

        return BeaconChain.Validator(LibConstant.NOT_FOUND_BYTES, address(0), 0, BeaconChain.Status.UNKNOWN);
    }
}
