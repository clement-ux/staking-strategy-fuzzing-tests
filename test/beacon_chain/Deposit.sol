// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Setup } from "../Setup.sol";
import { CompoundingValidatorManager } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingSSVStrategy.sol";

contract Deposit_Test is Setup {
    bytes nullBytes32 = aliceWithdrawalCredentials;
    bytes aliceWithdrawalCredentials = abi.encodePacked(bytes1(0x02), bytes11(0), address(alice));

    function setUp() public virtual override {
        super.setUp();
    }

    function test_Direct_BC_Deposit() public {
        uint256 depositAmount = 1 ether;

        beaconChain.registerSsvValidator(validator1.pubkey);
        beaconChain.registerSsvValidator(validator2.pubkey);

        // Deposit
        vm.startPrank(alice);
        beaconChain.deposit{ value: depositAmount * 10 }(validator1.pubkey, aliceWithdrawalCredentials, "", "");
        beaconChain.deposit{ value: depositAmount * 22 }(validator1.pubkey, aliceWithdrawalCredentials, "", "");
        beaconChain.deposit{ value: depositAmount * 12 }(validator2.pubkey, aliceWithdrawalCredentials, "", "");

        // Check deposit queue
        beaconChain.getDepositQueue();

        // Process deposits
        beaconChain.processDeposit(0);
        beaconChain.processDeposit(0);

        // Check validator state
        checkValidatorState();

        // Activate validator 1
        beaconChain.getValidatorLength();
        beaconChain.activateValidators();
        beaconChain.getValidatorLength();

        // Check validator state
        checkValidatorState();

        // Withdraw from validator 1
        beaconChain.withdraw(validator1.pubkey, depositAmount * 5);
        beaconChain.processWithdraw(0);

        // Check validator state
        checkValidatorState();

        // Withdraw more than remaining balance
        beaconChain.withdraw(validator1.pubkey, depositAmount * 18);
        beaconChain.processWithdraw(0);

        // Check validator state
        checkValidatorState();

        // Process exit
        beaconChain.processExit(0);

        // Check validator state
        checkValidatorState();

        // Sweep
        beaconChain.processSweep();

        // Check validator state
        checkValidatorState();

        // Deposit more to validator 2
        beaconChain.deposit{ value: depositAmount * 2035 }(validator2.pubkey, aliceWithdrawalCredentials, "", "");
        checkValidatorState();

        beaconChain.processDeposit(0);
        beaconChain.processDeposit(0);
        beaconChain.activateValidators();

        // Check validator state
        checkValidatorState();

        // Simulate some rewards on validator 2
        beaconChain.simulateRewards(validator2.pubkey, 2 ether);

        // Check validator state
        checkValidatorState();

        // Process sweep
        beaconChain.processSweep();

        // Check validator state
        checkValidatorState();

        // Slash validator 2 by 2040 ether
        beaconChain.slash(validator2.pubkey, 2040 ether);

        beaconChain.processExit(0);
        beaconChain.processSweep();

        vm.stopPrank();
    }

    function checkValidatorState() public view {
        beaconChain.getDepositQueue();
        beaconChain.getWithdrawQueue();
        beaconChain.getExitQueue();
        beaconChain.getValidators();
    }

    function test_Deposit() public {
        // Register a validator on SSV
        vm.prank(operator);
        strategy.registerSsvValidator(validator1.pubkey, new uint64[](0), bytes(""), 0, emptyCluster);

        // Alice front run the deposit
        bytes memory withdrawalCredentials = abi.encodePacked(bytes1(0x02), bytes11(0), address(alice));
        vm.prank(alice);
        depositContract.deposit{ value: 1 ether }(validator1.pubkey, withdrawalCredentials, bytes(""), bytes32(0));
        // Stake 1 ETH
        deal(address(weth), address(strategy), 1 ether);
        vm.prank(operator);
        strategy.stakeEth(
            CompoundingValidatorManager.ValidatorStakeData(validator1.pubkey, bytes(""), bytes32(0)), 1 ether / 1 gwei
        );

        // Verify validator
        strategy.verifyValidator(0, validator1.index, hashPubKey(validator1.pubkey), address(alice), bytes(""));
    }
}
