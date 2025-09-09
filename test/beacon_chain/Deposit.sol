// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BaseTest } from "../BaseTest.sol";

contract Deposit_Test is BaseTest {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_Deposit() public {
        uint256 depositAmount = 1 ether;

        // Deposit
        vm.startPrank(alice);
        beaconChain.deposit{ value: depositAmount * 10 }(validator1, "", "", "");
        beaconChain.deposit{ value: depositAmount * 22 }(validator1, "", "", "");
        beaconChain.deposit{ value: depositAmount * 12 }(validator2, "", "", "");
        vm.stopPrank();

        // Check deposit queue
        beaconChain.getDepositQueue();

        // Process deposits
        beaconChain.processDeposit(0);
        beaconChain.processDeposit(0);

        // Check validator state
        beaconChain.getDepositQueue();
        beaconChain.getPendingQueue();
        beaconChain.getValidators();

        // Activate validator 1
        beaconChain.activateValidator(0);

        // Check validator state
        beaconChain.getDepositQueue();
        beaconChain.getPendingQueue();
        beaconChain.getValidators();

        // 
    }
}
