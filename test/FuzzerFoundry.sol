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

        bytes4[] memory selectors = new bytes4[](20);
        // Strategy handlers
        selectors[0] = this.handler_deposit.selector;
        selectors[1] = this.handler_withdraw.selector;
        selectors[2] = this.handler_stakeEth.selector;
        selectors[3] = this.handler_verifyDeposit.selector;
        selectors[4] = this.handler_verifyBalances.selector;
        selectors[5] = this.handler_verifyValidator.selector;
        selectors[6] = this.handler_registerSsvValidator.selector;
        selectors[7] = this.handler_validatorWithdrawal.selector;
        selectors[8] = this.handler_removeSsvValidator.selector;
        selectors[9] = this.handler_frontrunDeposit.selector;
        selectors[10] = this.handler_resetFirstDeposit.selector;

        // Beacon chain handlers
        selectors[11] = this.handler_processDeposit.selector;
        selectors[12] = this.handler_processWithdraw.selector;
        selectors[13] = this.handler_processSweep.selector;
        selectors[14] = this.handler_activateValidators.selector;
        selectors[15] = this.handler_deactivateValidators.selector;
        selectors[16] = this.handler_snapBalances.selector;
        selectors[17] = this.handler_simulateRewards.selector;
        selectors[18] = this.handler_slash.selector;

        // System handlers
        selectors[19] = this.handler_timejump.selector;

        // Target selectors
        targetSelector(FuzzSelector({ addr: address(this), selectors: selectors }));
        targetSender(makeAddr("FuzzerSender"));
    }

    function invariantA() public pure {
        assertTrue(propertieA(), "Invariant A failed");
    }
}
