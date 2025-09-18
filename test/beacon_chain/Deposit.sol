// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console } from "@forge-std/console.sol";
import { Setup } from "../Setup.sol";
import { BeaconChain } from "../../src/BeaconChain.sol";
import { CompoundingValidatorManager } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingSSVStrategy.sol";
import { CompoundingStakingStrategyView } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingView.sol";

contract Deposit_Test is Setup {
    bytes nullBytes32 = aliceWithdrawalCredentials;
    bytes aliceWithdrawalCredentials = abi.encodePacked(bytes1(0x02), bytes11(0), address(alice));

    function setUp() public virtual override {
        super.setUp();
    }

    function test_Deposit() public {
        // Register a validator on SSV
        vm.prank(operator);
        strategy.registerSsvValidator(validator1.pubkey, new uint64[](0), bytes(""), 0, emptyCluster);

        // Stake 1 ETH
        weth.mint(address(strategy), 1 ether);
        vm.startPrank(operator);
        strategy.stakeEth({
            validatorStakeData: CompoundingValidatorManager.ValidatorStakeData({
                pubkey: validator1.pubkey,
                signature: abi.encodePacked(depositContract.uniqueDepositId()),
                depositDataRoot: bytes32(0)
            }),
            depositAmountGwei: 1 ether / 1 gwei
        });
        vm.stopPrank();

        // Verify validator
        strategy.verifyValidator(0, validator1.index, hashPubKey(validator1.pubkey), address(strategy), bytes(""));

        // Process deposit on BeaconChain
        beaconChain.processDeposit();

        // Verify deposit
        CompoundingStakingStrategyView.DepositView[] memory deposits = strategyView.getPendingDeposits();
        strategy.verifyDeposit({
            pendingDepositRoot: deposits[0].pendingDepositRoot,
            depositProcessedSlot: deposits[0].slot + 1,
            firstPendingDeposit: CompoundingValidatorManager.FirstPendingDepositSlotProofData({ slot: 1, proof: bytes("") }),
            strategyValidatorData: CompoundingValidatorManager.StrategyValidatorProofData({
                withdrawableEpoch: type(uint64).max,
                withdrawableEpochProof: abi.encodePacked(deposits[0].pendingDepositRoot)
            })
        });
    }
}
