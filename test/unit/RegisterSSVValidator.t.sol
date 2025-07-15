// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

// Test imports
import { Modifiers } from "test/unit/Modifiers.sol";

// Origin Dollar
import { CompoundingValidatorManager } from "@origin-dollar/strategies/NativeStaking/CompoundingValidatorManager.sol";

/// @title RegisterSSVValidatorTest
/// @notice Unit tests for the registerSsvValidator function in CompoundingValidatorManager.
contract RegisterSSVValidatorTest is Modifiers {
    //////////////////////////////////////////////////////
    /// --- PASSING TESTS
    //////////////////////////////////////////////////////
    function test_RegisterSSVValidator_success() public asGovernor {
        bytes32 hashPublicKey = hashPubKey(bytes("publicKey"));

        vm.expectEmit(address(strategy));
        emit CompoundingValidatorManager.SSVValidatorRegistered(hashPublicKey, new uint64[](0));

        _registerValidator(bytes("publicKey"));

        assertEq(
            keccak256(abi.encodePacked(strategy.validatorState(hashPublicKey))),
            keccak256(abi.encodePacked(CompoundingValidatorManager.VALIDATOR_STATE.REGISTERED)),
            "Validator should be registered"
        );
    }

    //////////////////////////////////////////////////////
    /// --- REVERTING TESTS
    //////////////////////////////////////////////////////
    function test_RevertWhen_RegisterSSVValidator_Because_NotRegistrator() public asAlice {
        vm.expectRevert("Not Registrator");
        _registerValidator(bytes("publicKey"));
    }

    function test_RevertWhen_RegisterSSVValidator_Because_AlreadyRegistered()
        public
        asGovernor
        registerValidator(bytes("publicKey"))
    {
        vm.expectRevert("Validator already registered");
        _registerValidator(bytes("publicKey"));
    }
}
