// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { CompoundingStakingSSVStrategy } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingSSVStrategy.sol";

contract Ignite {
    CompoundingStakingSSVStrategy public strategy;
}

/// @notice Some notes
/// Mutative:
/// - registerSsvValidator
/// - stakeEth
/// - validatorWithdrawal
/// - removeSsvValidator
/// - snapBalances
/// Verification:
/// - verifyValidator
/// - verifyDeposit
/// - verifyBalances
/// Governor-only:
/// - withdrawSSV
/// - setRegistrator
/// - resetFirstDeposit

/// Path:
/// 1. registerSsvValidator
/// 2. stakeEth
/// 3. verifyValidator
/// 4. verifyDeposit
/// 5. snapBalances
/// 6. verifyBalances
