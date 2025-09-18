// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Test imports
import { Properties } from "test/Properties.sol";

// Helpers
import { console } from "@forge-std/console.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";

/// @title TargetFunctions
/// @notice TargetFunctions contract for tests, containing the target functions that should be tested.
///         This is the entry point with the contract we are testing. Ideally, it should never revert.
abstract contract TargetFunctions is Properties {
    // ╔══════════════════════════════════════════════════════════════════════════════╗
    // ║                           ✦✦✦ TARGET FUNCTIONS ✦✦✦                           ║
    // ╚══════════════════════════════════════════════════════════════════════════════╝
    //
    // --- BeaconChain
    // [ ] processDeposit
    // [ ] processWithdraw
    // [ ] activateValidators
    // [ ] deactivateValidators
    // [ ] processSweep
    // [ ] simulateRewards
    // [ ] slash
    //
    // --- CompoundingStakingSSVStrategy
    // [ ] deposit
    // [ ] withdraw
    // [ ] checkBalance
    // [ ] registerSsvValidator
    // [ ] removeSsvValidator
    // [ ] stakeEth
    // [ ] validatorWithdrawal
    // [ ] verifyValidator
    // [ ] verifyDeposit
    // [ ] snapBalances
    // [ ] verifyBalances
    //
    using SafeCastLib for uint256;

    // ╔══════════════════════════════════════════════════════════════════════════════╗
    // ║                          ✦✦✦ STRATEGY HANDLERS ✦✦✦                           ║
    // ╚══════════════════════════════════════════════════════════════════════════════╝

    /// @notice Simulate a deposit on the strategy from the vault.
    /// @param amount Amount of ETH to deposit, limited to uint80 because strategy can only process 48 validators at a time.
    /// This represents 48 * 2048 ETH = 98304 ETH max. uint72 ≈ 4.7k ETH which is too low, so using: uint80 ≈ 1.2M ETH.
    function handler_deposit(
        uint80 amount
    ) public {
        // Prevent deposit 0.
        amount = _bound(amount, 1, amount).toUint80();

        // Mint WETH directly to the strategy to simulate the vault having sent it.
        weth.mint(address(strategy), amount);

        // Main call: deposit
        vm.prank(oethVault);
        strategy.deposit(address(weth), amount);

        // Log the deposit.
        console.log("Deposit(): \t\t%18e", amount);
    }
}
