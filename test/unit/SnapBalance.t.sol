// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

// Test imports
import { Helpers } from "test/helpers/Helpers.sol";
import { Modifiers } from "test/unit/Modifiers.sol";

// Origin Dollar
import { CompoundingValidatorManager } from "@origin-dollar/strategies/NativeStaking/CompoundingValidatorManager.sol";

/// @title SnapBlanceTest
/// @notice Unit tests for the snapBalance function in CompoundingValidatorManager.
contract SnapBlanceTest is Modifiers {
    //////////////////////////////////////////////////////
    /// --- PASSING TESTS
    //////////////////////////////////////////////////////
    function test_SnapBalance_WithoutEth() public {
        // Expected event emission
        vm.expectEmit(address(strategy));
        emit CompoundingValidatorManager.BalancesSnapped(block.timestamp, bytes32(abi.encodePacked(block.timestamp)), 0);

        strategy.snapBalances();

        // Fetch useful data
        (uint64 time, uint128 ethBalance) = strategy.snappedBalances(bytes32(abi.encodePacked(block.timestamp)));
        // Assertions
        assertEq(strategy.lastSnapTimestamp(), block.timestamp, "Last snap timestamp should be current block timestamp");
        assertEq(time, block.timestamp, "Snapped time should be current block timestamp");
        assertEq(ethBalance, 0, "Snapped ETH balance should be 0");
    }

    function test_SnapBalance_WithEth() public {
        // Send some ETH to the strategy
        vm.deal(address(strategy), 1 ether);

        // Expected event emission
        vm.expectEmit(address(strategy));
        emit CompoundingValidatorManager.BalancesSnapped(
            block.timestamp, bytes32(abi.encodePacked(block.timestamp)), 1 ether
        );

        strategy.snapBalances();

        // Fetch useful data
        (uint64 time, uint128 ethBalance) = strategy.snappedBalances(bytes32(abi.encodePacked(block.timestamp)));
        // Assertions
        assertEq(strategy.lastSnapTimestamp(), block.timestamp, "Last snap timestamp should be current block timestamp");
        assertEq(time, block.timestamp, "Snapped time should be current block timestamp");
        assertEq(ethBalance, 1 ether, "Snapped ETH balance should be 1 ether");
    }

    //////////////////////////////////////////////////////
    /// --- REVERTING TESTS
    //////////////////////////////////////////////////////
    function test_RevertWhen_SnapBalance_Because_Paused()
        public
        asGovernor
        registerValidator(bytes("publicKey"))
        stakeETH(bytes("publicKey"), 1 ether)
        verifyValidator(bytes("publicKey"), 0)
        addSourceRegistry(address(this))
        requestConsolidation(address(this), hashPubKey(bytes("last publicKey")), hashPubKey(bytes("publicKey")))
    {
        vm.expectRevert("Pausable: paused");
        strategy.snapBalances();
    }
}
