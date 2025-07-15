// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

// Test imports
import { Helpers } from "test/helpers/Helpers.sol";
import { Modifiers } from "test/unit/Modifiers.sol";

// Origin Dollar
import { CompoundingValidatorManager } from "@origin-dollar/strategies/NativeStaking/CompoundingValidatorManager.sol";

/// @title RequestConsolidationTest
/// @notice Unit tests for the requestConsolidation function in CompoundingValidatorManager.
contract RequestConsolidationTest is Modifiers {
    //////////////////////////////////////////////////////
    /// --- PASSING TESTS
    //////////////////////////////////////////////////////
    function test_RequestConsolidation_FirstRequest()
        public
        asGovernor
        registerValidator(bytes("publicKey"))
        stakeETH(bytes("publicKey"), 1 ether)
        verifyValidator(bytes("publicKey"), 0)
        addSourceRegistry(address(this))
    {
        vm.stopPrank();
        vm.expectEmit(address(strategy));
        emit CompoundingValidatorManager.ConsolidationRequested(
            hashPubKey(bytes("last publicKey")), hashPubKey(bytes("publicKey")), address(this)
        );
        strategy.requestConsolidation(hashPubKey(bytes("last publicKey")), hashPubKey(bytes("publicKey")));

        // Assertions
        assertEq(strategy.lastSnapTimestamp(), 0, "Last snap timestamp should be 0 before consolidation");
        assertEq(
            strategy.consolidationLastPubKeyHash(),
            hashPubKey(bytes("last publicKey")),
            "Last public key hash should match the last public key"
        );
        assertEq(
            strategy.consolidationSourceStrategy(),
            address(this),
            "Consolidation source strategy should match the current contract address"
        );
        assertTrue(strategy.paused(), "Strategy should be paused after requesting consolidation");
    }

    //////////////////////////////////////////////////////
    /// --- REVERTING TESTS
    //////////////////////////////////////////////////////

    function test_RevertWhen_RequestConsolidation_Because_TargetValidatorNotVerified()
        public
        asGovernor
        registerValidator(bytes("publicKey"))
        stakeETH(bytes("publicKey"), 1 ether)
        addSourceRegistry(address(this))
    {
        vm.stopPrank();
        vm.expectRevert("Target validator not verified");
        strategy.requestConsolidation(bytes32(""), bytes32(""));
    }

    function test_RevertWhen_RequestConsolidation_Because_NotSourceStrategy()
        public
        asGovernor
        registerValidator(bytes("publicKey"))
        stakeETH(bytes("publicKey"), 1 ether)
        verifyValidator(bytes("publicKey"), 0)
    {
        vm.stopPrank();
        vm.expectRevert("Not a source strategy");
        strategy.requestConsolidation(bytes32(""), bytes32(""));
    }

    function test_RevertWhen_RequestConsolidation_Because_Paused()
        public
        asGovernor
        registerValidator(bytes("publicKey"))
        stakeETH(bytes("publicKey"), 1 ether)
        verifyValidator(bytes("publicKey"), 0)
        addSourceRegistry(address(this))
        requestConsolidation(address(this), hashPubKey(bytes("last publicKey")), hashPubKey(bytes("publicKey")))
    {
        vm.stopPrank();
        vm.expectRevert("Pausable: paused");
        strategy.requestConsolidation(bytes32(""), bytes32(""));
    }
}
