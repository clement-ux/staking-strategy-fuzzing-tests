// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

// Test imports
import { Helpers } from "test/helpers/Helpers.sol";
import { Modifiers } from "test/unit/Modifiers.sol";

// Origin Dollar
import { CompoundingValidatorManager } from "@origin-dollar/strategies/NativeStaking/CompoundingValidatorManager.sol";

// Mock
import { MockBeaconOracle } from "test/mocks/MockBeaconOracle.sol";

/// @title VerifyDepositTest
/// @notice Unit tests for the verifyDeposit function in CompoundingValidatorManager.
contract VerifyDepositTest is Modifiers {
    //////////////////////////////////////////////////////
    /// --- PASSING TESTS
    //////////////////////////////////////////////////////
    function test_VerifyDeposit_FirstETH()
        public
        asGovernor
        registerValidator(bytes("publicKey"))
        stakeETH(bytes("publicKey"), 1 ether)
        verifyValidator(bytes("publicKey"), 0)
    {
        // Expected event emission
        vm.expectEmit(address(strategy));
        emit CompoundingValidatorManager.DepositVerified(getDepositDataRoots(bytes("publicKey"), 0), 1 ether);

        // Main call
        _verifyDeposit(bytes("publicKey"), 0);

        // Fetch useful data
        (
            bytes32 pubKeyHash,
            uint64 amountGwei,
            uint64 blockNumber,
            uint32 depositIndex,
            CompoundingValidatorManager.DepositStatus status
        ) = strategy.deposits(getDepositDataRoots(bytes("publicKey"), 0));
        // Assertions
        assertEq(address(strategy).balance, 0, "Strategy balance should be 0 after verifying deposit");
        assertEq(pubKeyHash, hashPubKey(bytes("publicKey")), "Deposit data root should match the public key hash");
        assertEq(amountGwei, 1 ether / 1 gwei, "Amount should be 1 ether in gwei");
        assertEq(blockNumber, block.number, "Block number should be current block");
        assertEq(depositIndex, 0, "Deposit index should be 0 for the first deposit");
        assertEq(
            keccak256(abi.encodePacked(status)),
            keccak256(abi.encodePacked(CompoundingValidatorManager.DepositStatus.VERIFIED)),
            "Validator should be verified"
        );
        assertEq(strategy.getDepositsRootsLength(), 0, "Deposits roots length should be 0 after verification");
    }

    function test_VerifyDeposit_SecondETH()
        public
        asGovernor
        registerValidator(bytes("publicKey"))
        stakeETH(bytes("publicKey"), 1 ether)
        verifyValidator(bytes("publicKey"), 0)
        verifyDeposit(bytes("publicKey"), 0)
        stakeETH(bytes("publicKey"), 30 ether)
        verifyDeposit(bytes("publicKey"), 1)
    {
        // Fetch useful data
        (
            bytes32 pubKeyHash,
            uint64 amountGwei,
            uint64 blockNumber,
            uint32 depositIndex,
            CompoundingValidatorManager.DepositStatus status
        ) = strategy.deposits(getDepositDataRoots(bytes("publicKey"), 1));
        // Assertions
        assertEq(address(strategy).balance, 0, "Strategy balance should be 0 after verifying deposit");
        assertEq(pubKeyHash, hashPubKey(bytes("publicKey")), "Deposit data root should match the public key hash");
        assertEq(amountGwei, 30 ether / 1 gwei, "Amount should be 30 ether in gwei");
        assertEq(blockNumber, block.number, "Block number should be current block");
        assertEq(depositIndex, 0, "Deposit index should be 0 for the first deposit");
        assertEq(
            keccak256(abi.encodePacked(status)),
            keccak256(abi.encodePacked(CompoundingValidatorManager.DepositStatus.VERIFIED)),
            "Validator should be verified"
        );
        assertEq(strategy.getDepositsRootsLength(), 0, "Deposits roots length should be 0 after verification");
    }

    //////////////////////////////////////////////////////
    /// --- REVERTING TESTS
    //////////////////////////////////////////////////////
    function test_RevertWhen_VerifyDeposit_Because_DepositNotPending_NonRegistered() public {
        (,,,, CompoundingValidatorManager.DepositStatus status) =
            strategy.deposits(getDepositDataRoots(bytes("publicKey"), 0));
        assertEq(
            keccak256(abi.encodePacked(status)),
            keccak256(abi.encodePacked(CompoundingValidatorManager.DepositStatus.UNKNOWN)),
            "Deposit status should be UNKNOWN"
        );

        vm.expectRevert("Deposit not pending");
        _verifyDeposit(bytes("publicKey"), 0);
    }

    function test_RevertWhen_VerifyDeposit_Because_DepositNotPending_AlreadyVerified()
        public
        asGovernor
        registerValidator(bytes("publicKey"))
        stakeETH(bytes("publicKey"), 1 ether)
        verifyValidator(bytes("publicKey"), 0)
        verifyDeposit(bytes("publicKey"), 0)
    {
        (,,,, CompoundingValidatorManager.DepositStatus status) =
            strategy.deposits(getDepositDataRoots(bytes("publicKey"), 0));
        assertEq(
            keccak256(abi.encodePacked(status)),
            keccak256(abi.encodePacked(CompoundingValidatorManager.DepositStatus.VERIFIED)),
            "Deposit status should be VERIFIED"
        );
        vm.expectRevert("Deposit not pending");
        _verifyDeposit(bytes("publicKey"), 0);
    }

    // Only validator state that can match this test is STAKED
    // Todo: check if this is possible with EXITED and REMOVED.
    function test_RevertWhen_VerifyDeposit_Because_ValidatorNotVerified()
        public
        asGovernor
        registerValidator(bytes("publicKey"))
        stakeETH(bytes("publicKey"), 1 ether)
    {
        assertEq(
            keccak256(abi.encodePacked(strategy.validatorState(hashPubKey(bytes("publicKey"))))),
            keccak256(abi.encodePacked(CompoundingValidatorManager.VALIDATOR_STATE.STAKED)),
            "Validator should be in STAKED state"
        );

        vm.expectRevert("Validator not verified");
        _verifyDeposit(bytes("publicKey"), 0);
    }

    function test_RevertWhen_VerifyDeposit_Because_DepositBlockBeforeDeposit()
        public
        asGovernor
        registerValidator(bytes("publicKey"))
        stakeETH(bytes("publicKey"), 1 ether)
        verifyValidator(bytes("publicKey"), 0)
    {
        vm.expectRevert("Deposit block before deposit");
        strategy.verifyDeposit(
            getDepositDataRoots(bytes("publicKey"), 0), uint64(block.number - 1), type(uint64).max, 0, bytes("")
        );
    }

    function test_RevertWhen_VerifyDeposit_Because_DepositNotProcessed()
        public
        asGovernor
        registerValidator(bytes("publicKey"))
        stakeETH(bytes("publicKey"), 1 ether)
        verifyValidator(bytes("publicKey"), 0)
    {
        vm.mockCall(
            address(mockBeaconOracle), MockBeaconOracle.slotToBlock.selector, abi.encode(uint64(block.number + 1))
        );
        vm.expectRevert("Deposit not processed");
        strategy.verifyDeposit(
            getDepositDataRoots(bytes("publicKey"), 0), uint64(block.number + 1), type(uint64).max, 1, bytes("")
        );
    }

    function test_RevertWhen_VerifyDeposit_Because_SlotNotAfterDeposit()
        public
        asGovernor
        registerValidator(bytes("publicKey"))
        stakeETH(bytes("publicKey"), 1 ether)
        verifyValidator(bytes("publicKey"), 0)
    {
        vm.mockCall(
            address(mockBeaconOracle), MockBeaconOracle.slotToBlock.selector, abi.encode(uint64(block.number + 1))
        );
        vm.expectRevert("Slot not after deposit");
        strategy.verifyDeposit(
            getDepositDataRoots(bytes("publicKey"), 0), uint64(block.number), uint64(block.number - 1), 0, bytes("")
        );
    }
}
