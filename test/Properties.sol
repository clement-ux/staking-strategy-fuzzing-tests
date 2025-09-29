// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Test imports
import { TargetFunctions } from "test/TargetFunctions.sol";

// Helpers
import { console } from "@forge-std/console.sol";
import { LibMath } from "test/libraries/LibMath.sol";
import { LibLogger } from "test/libraries/LibLogger.sol";
import { LibBeacon } from "test/libraries/LibBeacon.sol";
import { LibStrategy } from "test/libraries/LibStrategy.sol";
import { LibConstant } from "test/libraries/LibConstant.sol";
import { LibValidator } from "test/libraries/LibValidator.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";

// Beacon
import { BeaconChain } from "src/BeaconChain.sol";

// Target contracts
import { CompoundingValidatorManager } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingSSVStrategy.sol";
import { CompoundingStakingSSVStrategy } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingSSVStrategy.sol";

/// @title Properties
/// @notice Abstract contract defining invariant properties for formal verification and fuzzing.
/// @dev    This contract contains pure property functions that express system invariants:
///         - Properties must be implemented as view/pure functions returning bool
///         - Each property should represent a mathematical invariant of the system
///         - Properties should be stateless and deterministic
///         - Property names should clearly indicate what invariant they check
///         Usage: Properties are called by fuzzing contracts to validate system state
abstract contract Properties is TargetFunctions {
    // ╔══════════════════════════════════════════════════════════════════════════════╗
    // ║                         ✦✦✦ INVARIANT PROPERTIES ✦✦✦                         ║
    // ╚══════════════════════════════════════════════════════════════════════════════╝
    // [x] Property A: The validator mapping can only contain 1 validator with state ValidatorState.STAKED
    // [ ] Property B: The amount of ETH in unprocessed deposits to STAKED validators (validators with unconfirmed withdrawal
    //                  credentials) is never larger than 1 ETH
    // [x] Property C: There can not be more than 12 unprocessed deposits
    // [x] Property D: There shouldn’t be more than 48 verified validators.

    using LibMath for int256;
    using LibMath for uint256;
    using LibLogger for bytes;
    using LibLogger for string;
    using LibLogger for bytes[];
    using LibLogger for bytes32;
    using LibBeacon for uint64;
    using LibBeacon for BeaconChain;
    using LibStrategy for CompoundingStakingSSVStrategy;
    using LibValidator for bytes;
    using SafeCastLib for uint256;

    function propertyA() public view returns (bool) {
        uint256 counter;
        for (uint256 i; i < LibConstant.MAX_VALIDATORS; i++) {
            bytes32 hashPubkey = validators[i].hashPubkey();
            (CompoundingValidatorManager.ValidatorState state,) = strategy.validator(hashPubkey);
            if (state == CompoundingValidatorManager.ValidatorState.STAKED) counter++;
        }

        return counter <= 1;
    }

    function propertyB() public view returns (bool) {
        // Get the pending deposit
        uint256 len = strategy.depositListLength();
        for (uint256 i; i < len; i++) {
            bytes32 pendingDepositRoot = strategy.depositList(i);

            // Get the deposit info
            (bytes32 pubkeyHash, uint64 amountGwei,,,) = strategy.deposits(pendingDepositRoot);

            // Get the validator that is receiving the deposit info
            (CompoundingValidatorManager.ValidatorState state,) = strategy.validator(pubkeyHash);

            // If the validator is STAKED, the amount must be exactly 1 gwei (i.e. 1 ETH)
            if (state == CompoundingValidatorManager.ValidatorState.STAKED && amountGwei != 1 gwei) return false;
        }
        return true;
    }

    function propertyC() public view returns (bool) {
        return strategy.depositListLength() <= LibConstant.MAX_DEPOSITS;
    }

    function propertyD() public view returns (bool) {
        return strategy.verifiedValidatorsLength() <= LibConstant.MAX_VERIFIED_VALIDATORS;
    }

    function propertyE() public view returns (bool) {
        uint256 balance = strategy.checkBalance(address(weth));
        console.log("\n=== Invariant E ===");
        console.log("Balance:                           %18e", balance);
        console.log("Sum of deposits:                   %18e", sumOfDeposit);
        console.log("Sum of withdrawals:                %18e", sumOfWithdraw);
        console.log("Sum of slashed:                    %18e", sumOfSlashed);
        console.log("Sum of frontrun:                   %18e", sumOfFrontrun);
        int256 local =
            sumOfDeposit.toInt256() - sumOfWithdraw.toInt256() - sumOfSlashed.toInt256() - sumOfFrontrun.toInt256();
        console.log("Sum of local:                      %18e", local);
        return local < 0 || balance >= local.abs() || balance.approxEqAbs(local.abs(), 1e12);
    }

    function propertyF() public view returns (bool) {
        uint256 balance = strategy.checkBalance(address(weth));
        console.log("\n=== Invariant F ===");
        console.log("Balance:                           %18e", balance);
        console.log("Sum of deposits:                   %18e", sumOfDeposit);
        console.log("Sum of withdrawals:                %18e", sumOfWithdraw);
        console.log("Sum of rewards:                    %18e", sumOfRewards);
        console.log("Sum of slashed:                    %18e", sumOfSlashed);
        console.log("Sum of frontrun:                   %18e", sumOfFrontrun);
        uint256 local = sumOfDeposit + sumOfRewards - sumOfWithdraw - sumOfFrontrun;
        console.log("Sum of local:                      %18e", local);
        console.log("Diff between expected and actual   %18e", balance.diffAbs(local));
        return balance <= local;
    }

    function afterInvariant() public {
        _afterInvariant();
        uint256 balance = strategy.checkBalance(address(weth));
        console.log("\n=== Invariant F ===");
        console.log("Balance:                           %18e", balance);
        console.log("Sum of deposits:                   %18e", sumOfDeposit);
        console.log("Sum of withdrawals:                %18e", sumOfWithdraw);
        console.log("Sum of rewards:                    %18e", sumOfRewards);
        console.log("Sum of slashed:                    %18e", sumOfSlashed);
        console.log("Sum of frontrun:                   %18e", sumOfFrontrun);
        uint256 local = sumOfDeposit + sumOfRewards - sumOfWithdraw - sumOfSlashed - sumOfFrontrun;
        console.log("Sum of local:                      %18e", local);
        console.log("Diff between expected and actual   %18e", balance.diffAbs(local));
        assertTrue(balance.approxEqAbs(local, 1e12));
    }
}
