// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

// Test imports
import { Helpers } from "test/helpers/Helpers.sol";
import { Modifiers } from "test/unit/Modifiers.sol";

// Origin Dollar
import { ValidatorStakeData } from "@origin-dollar/strategies/NativeStaking/CompoundingValidatorManager.sol";
import { CompoundingValidatorManager } from "@origin-dollar/strategies/NativeStaking/CompoundingValidatorManager.sol";

/// @title StakeETHTest
/// @notice Unit tests for the stakeETH function in CompoundingValidatorManager.
contract StakeETHTest is Modifiers {
    //////////////////////////////////////////////////////
    /// --- PASSING TESTS
    //////////////////////////////////////////////////////
    function test_StakeETH_FirstDeposit() public asGovernor registerValidator(bytes("publicKey")) {
        uint256 amount = 1 ether;
        bytes memory publicKey = bytes("publicKey");
        bytes32 hashPublicKey = hashPubKey(publicKey);

        // Expected events
        vm.expectEmit(address(strategy));
        emit CompoundingValidatorManager.ETHStaked(hashPublicKey, getDepositDataRoots(publicKey, 0), publicKey, amount);

        // Main Call
        _stakeETH(publicKey, amount);

        // Fetch useful data
        (
            bytes32 pubKeyHash,
            uint64 amountGwei,
            uint64 blockNumber,
            uint32 depositIndex,
            CompoundingValidatorManager.DepositStatus status
        ) = strategy.deposits(getDepositDataRoots(publicKey, 0));
        // Assertions
        assertEq(address(strategy).balance, 0, "Strategy balance should be 0 after staking");
        assertEq(strategy.getDepositsRootsLength(), 1, "Deposits roots length should be 1 after the first deposit");
        assertEq(address(mockDepositContract).balance, amount, "Mock deposit contract should hold the staked amount");
        assertEq(pubKeyHash, hashPublicKey, "Deposit data root should match the public key hash");
        assertEq(amountGwei, amount / 1 gwei, "Amount should be 1 ether in gwei");
        assertEq(blockNumber, block.number, "Block number should be current block");
        assertEq(depositIndex, 0, "Deposit index should be 0 for the first deposit");
        assertEq(
            keccak256(abi.encodePacked(strategy.validatorState(hashPublicKey))),
            keccak256(abi.encodePacked(CompoundingValidatorManager.VALIDATOR_STATE.STAKED)),
            "Validator should be registered"
        );
        assertEq(
            keccak256(abi.encodePacked(status)),
            keccak256(abi.encodePacked(CompoundingValidatorManager.DepositStatus.PENDING)),
            "Deposit status should be PENDING"
        );
    }

    function test_StakeETH_SecondDeposit()
        public
        asGovernor
        registerValidator(bytes("publicKey"))
        stakeETH(bytes("publicKey"), 1 ether)
        verifyValidator(bytes("publicKey"), 0)
    {
        uint256 amount = 32 ether;
        bytes memory publicKey = bytes("publicKey");
        bytes32 hashPublicKey = hashPubKey(publicKey);

        // Expected events
        vm.expectEmit(address(strategy));
        emit CompoundingValidatorManager.ETHStaked(hashPublicKey, getDepositDataRoots(publicKey, 1), publicKey, amount);

        // Main Call
        _stakeETH(publicKey, amount);

        // Fetch useful data
        (
            bytes32 pubKeyHash,
            uint64 amountGwei,
            uint64 blockNumber,
            uint32 depositIndex,
            CompoundingValidatorManager.DepositStatus status
        ) = strategy.deposits(getDepositDataRoots(publicKey, 1));
        // Assertions
        assertEq(address(strategy).balance, 0, "Strategy balance should be 0 after staking");
        assertEq(strategy.getDepositsRootsLength(), 2, "Deposits roots length should be 1 after the first deposit");
        assertEq(
            address(mockDepositContract).balance,
            amount + 1 ether,
            "Mock deposit contract should hold the staked amount"
        );
        assertEq(pubKeyHash, hashPublicKey, "Deposit data root should match the public key hash");
        assertEq(amountGwei, amount / 1 gwei, "Amount should be 1 ether in gwei");
        assertEq(blockNumber, block.number, "Block number should be current block");
        assertEq(depositIndex, 1, "Deposit index should be 0 for the first deposit");
        assertEq(
            keccak256(abi.encodePacked(strategy.validatorState(hashPublicKey))),
            keccak256(abi.encodePacked(CompoundingValidatorManager.VALIDATOR_STATE.VERIFIED)),
            "Validator should be registered"
        );
        assertEq(
            keccak256(abi.encodePacked(status)),
            keccak256(abi.encodePacked(CompoundingValidatorManager.DepositStatus.PENDING)),
            "Deposit status should be PENDING"
        );
    }

    //////////////////////////////////////////////////////
    /// --- REVERTING TESTS
    //////////////////////////////////////////////////////
    function test_RevertWhen_StakeETH_Because_NotRegistrator() public asAlice {
        vm.expectRevert("Not Registrator");
        strategy.stakeEth(ValidatorStakeData(bytes("publicKey"), bytes(""), bytes32("")), 0);
    }

    function test_RevertWhen_StakeETH_Because_InsufficientWETH() public asGovernor {
        vm.expectRevert("Insufficient WETH");
        strategy.stakeEth(ValidatorStakeData(bytes("publicKey"), bytes(""), bytes32("")), 1 ether / 1 gwei);
    }

    function test_RevertWhen_StakeETH_Because_NotRegistered() public asGovernor {
        vm.deal(address(strategy), 1 ether);
        vm.expectRevert("Not registered or verified");
        strategy.stakeEth(ValidatorStakeData(bytes("publicKey"), bytes(""), bytes32("")), 0);
    }

    function test_RevertWhen_StakeETH_Because_FirstDepositNot1ETH()
        public
        asGovernor
        registerValidator(bytes("publicKey"))
    {
        deal(address(weth), address(strategy), 1 ether);
        vm.expectRevert("First deposit not 1 ETH");
        strategy.stakeEth(ValidatorStakeData(bytes("publicKey"), bytes(""), bytes32("")), 0.5 ether / 1 gwei);
    }

    function test_RevertWhen_StakeETH_Because_DepositTooSmall()
        public
        asGovernor
        registerValidator(bytes("publicKey"))
    {
        // Todo: Implement the verifyValidator function before
    }
}
