// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Test imports
import { Properties } from "test/Properties.sol";

/// @title FuzzerFoundry
/// @notice Concrete fuzzing contract implementing Foundry's invariant testing framework.
/// @dev    This contract configures and executes property-based testing:
///         - Inherits from Properties to access handler functions and properties
///         - Configures fuzzer targeting (contracts, selectors, senders)
///         - Implements invariant test functions that call property validators
///         - Each invariant function represents a critical system property to maintain
///         - Fuzzer will call targeted handlers randomly and check invariants after each call
contract FuzzerFoundry is Properties {
    //////////////////////////////////////////////////////
    /// --- SETUP
    //////////////////////////////////////////////////////
    function setUp() public virtual override {
        super.setUp();

        // --- Setup Fuzzer target ---
        // Setup target
        targetContract(address(this));

        // Add selectors
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = this.handler_deposit.selector;
        selectors[1] = this.handler_registerSsvValidator.selector;
        selectors[2] = this.handler_stakeEth.selector;
        selectors[3] = this.handler_verifyValidator.selector;

        // Target selectors
        targetSelector(FuzzSelector({ addr: address(this), selectors: selectors }));
        targetSender(makeAddr("FuzzerSender"));
    }

    function invariantA() public pure {
        assertTrue(propertieA(), "Invariant A failed");
    }
}
