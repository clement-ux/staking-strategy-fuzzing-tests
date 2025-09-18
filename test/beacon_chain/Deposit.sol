// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { console } from "@forge-std/console.sol";
import { Setup } from "../Setup.sol";
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

        // Check state
        beaconChain.getValidators();
        beaconChain.getDepositQueue();
        beaconChain.getWithdrawQueue();

        // Stake 31 ETH
        weth.mint(address(strategy), 31 ether);
        vm.startPrank(operator);
        strategy.stakeEth({
            validatorStakeData: CompoundingValidatorManager.ValidatorStakeData({
                pubkey: validator1.pubkey,
                signature: abi.encodePacked(depositContract.uniqueDepositId()),
                depositDataRoot: bytes32(0)
            }),
            depositAmountGwei: 31 ether / 1 gwei
        });
        vm.stopPrank();

        // Process deposit on BeaconChain
        beaconChain.processDeposit();

        // Verify deposit
        console.log("Second deposit verification");
        deposits = strategyView.getPendingDeposits();
        strategy.verifyDeposit({
            pendingDepositRoot: deposits[0].pendingDepositRoot,
            depositProcessedSlot: deposits[0].slot + 1,
            firstPendingDeposit: CompoundingValidatorManager.FirstPendingDepositSlotProofData({ slot: 1, proof: bytes("") }),
            strategyValidatorData: CompoundingValidatorManager.StrategyValidatorProofData({
                withdrawableEpoch: type(uint64).max,
                withdrawableEpochProof: abi.encodePacked(deposits[0].pendingDepositRoot)
            })
        });

        // Stake 2 ETH
        weth.mint(address(strategy), 2 ether);
        vm.startPrank(operator);
        strategy.stakeEth({
            validatorStakeData: CompoundingValidatorManager.ValidatorStakeData({
                pubkey: validator1.pubkey,
                signature: abi.encodePacked(depositContract.uniqueDepositId()),
                depositDataRoot: bytes32(0)
            }),
            depositAmountGwei: 2 ether / 1 gwei
        });
        vm.stopPrank();

        // Stake 3 ETH
        weth.mint(address(strategy), 3 ether);
        vm.startPrank(operator);
        strategy.stakeEth({
            validatorStakeData: CompoundingValidatorManager.ValidatorStakeData({
                pubkey: validator1.pubkey,
                signature: abi.encodePacked(depositContract.uniqueDepositId()),
                depositDataRoot: bytes32(0)
            }),
            depositAmountGwei: 3 ether / 1 gwei
        });
        vm.stopPrank();

        // Snap balance
        strategy.snapBalances();

        console.log("Verify balance for the first time");
        uint256 validValidators = strategy.verifiedValidatorsLength();
        uint256 pendingDeposits = strategy.depositListLength();
        // Verify balance
        strategy.verifyBalances({
            balanceProofs: CompoundingValidatorManager.BalanceProofs({
                balancesContainerRoot: bytes32(0),
                balancesContainerProof: bytes(""),
                validatorBalanceLeaves: new bytes32[](validValidators),
                validatorBalanceProofs: new bytes[](validValidators)
            }),
            pendingDepositProofs: CompoundingValidatorManager.PendingDepositProofs({
                pendingDepositContainerRoot: bytes32(0),
                pendingDepositContainerProof: bytes(""),
                pendingDepositIndexes: new uint32[](pendingDeposits),
                pendingDepositProofs: new bytes[](pendingDeposits)
            })
        });

        // Activeate validator
        beaconChain.activateValidators();

        // Process 1 deposit on BeaconChain
        beaconChain.processDeposit();

        // Verify deposit
        deposits = strategyView.getPendingDeposits();
        strategy.verifyDeposit({
            pendingDepositRoot: deposits[0].pendingDepositRoot,
            depositProcessedSlot: deposits[0].slot + 1,
            firstPendingDeposit: CompoundingValidatorManager.FirstPendingDepositSlotProofData({ slot: 1, proof: bytes("") }),
            strategyValidatorData: CompoundingValidatorManager.StrategyValidatorProofData({
                withdrawableEpoch: type(uint64).max,
                withdrawableEpochProof: abi.encodePacked(deposits[0].pendingDepositRoot)
            })
        });

        // Snap balance
        skip(1 hours);
        strategy.snapBalances();

        console.log("Verify balance for the second time");
        // Verify balance
        validValidators = strategy.verifiedValidatorsLength();
        pendingDeposits = strategy.depositListLength();
        strategy.verifyBalances({
            balanceProofs: CompoundingValidatorManager.BalanceProofs({
                balancesContainerRoot: bytes32(0),
                balancesContainerProof: bytes(""),
                validatorBalanceLeaves: new bytes32[](validValidators),
                validatorBalanceProofs: new bytes[](validValidators)
            }),
            pendingDepositProofs: CompoundingValidatorManager.PendingDepositProofs({
                pendingDepositContainerRoot: bytes32(0),
                pendingDepositContainerProof: bytes(""),
                pendingDepositIndexes: new uint32[](pendingDeposits),
                pendingDepositProofs: new bytes[](pendingDeposits)
            })
        });

        // Get state
        beaconChain.getValidators();
        beaconChain.getDepositQueue();

        // Withdraw 1 ETH
        vm.startPrank(operator);
        strategy.validatorWithdrawal(validator1.pubkey, uint64(1 ether / 1 gwei));

        // Process withdraw on BeaconChain
        beaconChain.processWithdraw();

        // Check state
        beaconChain.getValidators();
        beaconChain.getDepositQueue();
        beaconChain.getWithdrawQueue();

        // Process last deposit on BeaconChain
        beaconChain.processDeposit();

        // Verify deposit
        deposits = strategyView.getPendingDeposits();
        strategy.verifyDeposit({
            pendingDepositRoot: deposits[0].pendingDepositRoot,
            depositProcessedSlot: deposits[0].slot + 1,
            firstPendingDeposit: CompoundingValidatorManager.FirstPendingDepositSlotProofData({ slot: 1, proof: bytes("") }),
            strategyValidatorData: CompoundingValidatorManager.StrategyValidatorProofData({
                withdrawableEpoch: type(uint64).max,
                withdrawableEpochProof: abi.encodePacked(deposits[0].pendingDepositRoot)
            })
        });

        // Snap balance
        skip(1 hours);
        strategy.snapBalances();

        // Verify balance
        validValidators = strategy.verifiedValidatorsLength();
        pendingDeposits = strategy.depositListLength();
        strategy.verifyBalances({
            balanceProofs: CompoundingValidatorManager.BalanceProofs({
                balancesContainerRoot: bytes32(0),
                balancesContainerProof: bytes(""),
                validatorBalanceLeaves: new bytes32[](validValidators),
                validatorBalanceProofs: new bytes[](validValidators)
            }),
            pendingDepositProofs: CompoundingValidatorManager.PendingDepositProofs({
                pendingDepositContainerRoot: bytes32(0),
                pendingDepositContainerProof: bytes(""),
                pendingDepositIndexes: new uint32[](pendingDeposits),
                pendingDepositProofs: new bytes[](pendingDeposits)
            })
        });

        // Get state
        beaconChain.getValidators();
        beaconChain.getDepositQueue();
        beaconChain.getWithdrawQueue();

        // Full withdraw
        vm.startPrank(operator);
        strategy.validatorWithdrawal(validator1.pubkey, 0);
        vm.stopPrank();

        console.log("Process withdraw");
        // Get state before
        beaconChain.getValidators();
        beaconChain.getDepositQueue();
        beaconChain.getWithdrawQueue();
        // Process withdraw on BeaconChain
        beaconChain.processWithdraw();

        // Snap balance
        skip(1 hours);
        strategy.snapBalances();

        // Verify balance
        validValidators = strategy.verifiedValidatorsLength();
        pendingDeposits = strategy.depositListLength();
        strategy.verifyBalances({
            balanceProofs: CompoundingValidatorManager.BalanceProofs({
                balancesContainerRoot: bytes32(0),
                balancesContainerProof: bytes(""),
                validatorBalanceLeaves: new bytes32[](validValidators),
                validatorBalanceProofs: new bytes[](validValidators)
            }),
            pendingDepositProofs: CompoundingValidatorManager.PendingDepositProofs({
                pendingDepositContainerRoot: bytes32(0),
                pendingDepositContainerProof: bytes(""),
                pendingDepositIndexes: new uint32[](pendingDeposits),
                pendingDepositProofs: new bytes[](pendingDeposits)
            })
        });

        // Get state
        beaconChain.getValidators();
        beaconChain.getDepositQueue();

        // Deactivate validator
        beaconChain.deactivateValidator();

        // Process sweep
        beaconChain.processSweep();

        // Snap balance
        skip(1 hours);
        strategy.snapBalances();

        // Verify balance
        validValidators = strategy.verifiedValidatorsLength();
        pendingDeposits = strategy.depositListLength();
        strategy.verifyBalances({
            balanceProofs: CompoundingValidatorManager.BalanceProofs({
                balancesContainerRoot: bytes32(0),
                balancesContainerProof: bytes(""),
                validatorBalanceLeaves: new bytes32[](validValidators),
                validatorBalanceProofs: new bytes[](validValidators)
            }),
            pendingDepositProofs: CompoundingValidatorManager.PendingDepositProofs({
                pendingDepositContainerRoot: bytes32(0),
                pendingDepositContainerProof: bytes(""),
                pendingDepositIndexes: new uint32[](pendingDeposits),
                pendingDepositProofs: new bytes[](pendingDeposits)
            })
        });
    }
}
