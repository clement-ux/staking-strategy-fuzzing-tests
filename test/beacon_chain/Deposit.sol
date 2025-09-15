// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Setup } from "../Setup.sol";

contract Deposit_Test is Setup {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_Deposit() public {
        uint256 depositAmount = 1 ether;

        // Deposit
        vm.startPrank(alice);
        beaconChain.deposit{ value: depositAmount * 10 }(VALIDATOR_1, "", "", "");
        beaconChain.deposit{ value: depositAmount * 22 }(VALIDATOR_1, "", "", "");
        beaconChain.deposit{ value: depositAmount * 12 }(VALIDATOR_2, "", "", "");

        // Check deposit queue
        beaconChain.getDepositQueue();

        // Process deposits
        beaconChain.processDeposit(0);
        beaconChain.processDeposit(0);

        // Check validator state
        checkValidatorState();

        // Activate validator 1
        beaconChain.getValidatorLength();
        beaconChain.activateValidator(0);
        beaconChain.getValidatorLength();

        // Check validator state
        checkValidatorState();

        // Withdraw from validator 1
        beaconChain.withdraw(VALIDATOR_1, depositAmount * 5);
        beaconChain.processWithdraw(0);

        // Check validator state
        checkValidatorState();

        // Withdraw more than remaining balance
        beaconChain.withdraw(VALIDATOR_1, depositAmount * 18);
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
        beaconChain.deposit{ value: depositAmount * 2035 }(VALIDATOR_2, "", "", "");
        checkValidatorState();

        beaconChain.processDeposit(0);
        beaconChain.processDeposit(0);
        beaconChain.activateValidator(0);

        // Check validator state
        checkValidatorState();

        // Simulate some rewards on validator 2
        beaconChain.simulateRewards(VALIDATOR_2, 2 ether);

        // Check validator state
        checkValidatorState();

        // Process sweep
        beaconChain.processSweep();

        // Check validator state
        checkValidatorState();

        // Slash validator 2 by 2040 ether
        beaconChain.slash(VALIDATOR_2, 2040 ether);

        beaconChain.processExit(0);
        beaconChain.processSweep();

        vm.stopPrank();
    }

    function checkValidatorState() public view {
        //beaconChain.getDepositQueue();
        //beaconChain.getPendingQueue();
        //beaconChain.getWithdrawQueue();
        //beaconChain.getExitQueue();
        beaconChain.getValidators();
    }
}
