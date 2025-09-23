// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

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
}
