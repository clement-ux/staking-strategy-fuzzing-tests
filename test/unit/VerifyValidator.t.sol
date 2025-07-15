// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

// Test imports
import { Helpers } from "test/helpers/Helpers.sol";
import { Modifiers } from "test/unit/Modifiers.sol";

// Origin Dollar
import { CompoundingValidatorManager } from "@origin-dollar/strategies/NativeStaking/CompoundingValidatorManager.sol";

/// @title VerifyValidatorTest
/// @notice Unit tests for the verifyValidator function in CompoundingValidatorManager.
contract VerifyValidatorTest is Modifiers {
    //////////////////////////////////////////////////////
    /// --- PASSING TESTS
    //////////////////////////////////////////////////////
    function test_VerifyValidator()
        public
        asGovernor
        registerValidator(bytes("publicKey"))
        stakeETH(bytes("publicKey"), 1 ether)
    {
        vm.expectEmit(address(strategy));
        emit CompoundingValidatorManager.ValidatorVerified(hashPubKey(bytes("publicKey")), 0);

        _verifyValidator(bytes("publicKey"), 0);

        assertEq(
            keccak256(abi.encodePacked(strategy.validatorState(hashPubKey(bytes("publicKey"))))),
            keccak256(abi.encodePacked(CompoundingValidatorManager.VALIDATOR_STATE.VERIFIED)),
            "Validator state should be VERIFIED"
        );
        (bytes32 pubKeyHash, uint64 index) = strategy.verifiedValidators(0);
        assertEq(pubKeyHash, hashPubKey(bytes("publicKey")), "Public key hash should match");
        assertEq(index, 0, "Validator index should be 0");
    }

    //////////////////////////////////////////////////////
    /// --- REVERTING TESTS
    //////////////////////////////////////////////////////
    function test_RevertWhen_VerifyValidator_NotStaked() public asGovernor registerValidator(bytes("publicKey")) {
        bytes32 pubKeyHash = hashPubKey(bytes("publicKey"));
        vm.expectRevert("Validator not staked");
        strategy.verifyValidator(uint64(block.timestamp), 0, pubKeyHash, bytes(""));
    }
}
