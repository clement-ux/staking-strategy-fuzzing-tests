// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Test imports
import { Properties } from "test/Properties.sol";

// Helpers
import { console } from "@forge-std/console.sol";
import { LibBytes } from "@solady/utils/LibBytes.sol";
import { LibString } from "@solady/utils/LibString.sol";
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
    using LibBytes for bytes;
    using LibString for string;
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
        amount = _bound(amount, 1, type(uint80).max).toUint80();

        // Mint WETH directly to the strategy to simulate the vault having sent it.
        weth.mint(address(strategy), amount);

        // Main call: deposit
        vm.prank(oethVault);
        strategy.deposit(address(weth), amount);

        // Log the deposit.
        console.log("Deposit():   \t\t\t\t%18e", amount);
    }

    /// @notice Register a SSV validator.
    /// @param index Index of the validator to register, limited to uint8 because strategy can only process 48 validators at
    /// a time. uint8 = 255, so this is more than enough for 48 validators.
    function handler_registerSsvValidator(
        uint8 index
    ) public {
        // Bound the index of the validator to register.
        index = _bound(index, 1, MAX_VALIDATORS).toUint8();

        bytes memory pubkey;
        // Ensure the validator is not already registered, if it is, try the next one, until we find one that is not
        // registered.
        for (uint256 i; i < MAX_VALIDATORS; i++) {
            uint256 currentIndex = ((index - 1 + i) % MAX_VALIDATORS) + 1;
            bytes memory _pubkey = indexToPubkey[currentIndex.toUint40()];
            if (!beaconChain.ssvRegisteredValidators(_pubkey)) {
                pubkey = _pubkey;
                break;
            }
        }
        // If all validators are already registered, skip the registration.
        if (pubkey.eq(bytes(""))) {
            // All validators are already registered.
            console.log("RegisterSsvValidator(): \t\t all validators are already registered");
            vm.assume(false);
            return;
        }

        // Main call: registerSsvValidator
        vm.prank(operator);
        strategy.registerSsvValidator(pubkey, new uint64[](0), bytes(""), 0, emptyCluster);

        // Log the registration.
        console.log("RegisterSsvValidator(): \t\t", vm.toString(pubkey).slice(0, 5));
    }
}
