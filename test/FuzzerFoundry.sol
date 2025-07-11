// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

// Test imports
import { TargetFunctions } from "test/TargetFunctions.sol";

/// @title FuzzerFoundry
/// @notice Concrete fuzzing contract implementing Foundry's invariant testing framework.
/// @dev    This contract configures and executes property-based testing:
///         - Inherits from TargetFunctions to access handler functions and properties
///         - Configures fuzzer targeting (contracts, selectors, senders)
///         - Implements invariant test functions that call property validators
///         - Each invariant function represents a critical system property to maintain
///         - Fuzzer will call targeted handlers randomly and check invariants after each call
contract FuzzerFoundry is TargetFunctions {
    //////////////////////////////////////////////////////
    /// --- SETUP
    //////////////////////////////////////////////////////
    function setUp() public virtual override {
        super.setUp();

        // --- Setup Fuzzer target ---
        // Setup target
        targetContract(address(this));

        // Add selectors
        bytes4[] memory selectors = new bytes4[](0);

        // Target selectors
        targetSelector(FuzzSelector({ addr: address(this), selectors: selectors }));
        targetSender(makeAddr("FuzzerSender"));
    }

    function invariantA() public view {
        assertTrue(propertieA(), "Invariant A failed");
    }
}
