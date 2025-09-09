// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { LibBytes } from "@solady/utils/LibBytes.sol";

import { RewardDistributor } from "./RewardDistributor.sol";

contract BeaconChain {
    using LibBytes for bytes;

    ////////////////////////////////////////////////////
    /// --- CONSTRANTS & IMMUTABLES
    ////////////////////////////////////////////////////
    uint256 public constant NOT_FOUND = type(uint256).max;
    uint256 public constant MIN_DEPOSIT = 1 ether;
    uint256 public constant MIN_EXIT_AMOUNT = 16 ether;
    uint256 public constant ACTIVATION_AMOUNT = 32 ether;
    uint256 public constant MAX_EFFECTIVE_BALANCE = 2048 ether;

    // Address where slashing rewards are sent to (generated using pk = uint256(keccak256(abi.encodePacked("name")))).
    // Using a real address instead of zero, to track ETH flow in tests.
    address public constant SLASHING_REWARD_RECIPIENT = address(0x91a36674f318e82322241CB62f771c90e3B77acb);

    RewardDistributor public immutable rewardDistributor = new RewardDistributor();

    ////////////////////////////////////////////////////
    /// --- STRUCTS & ENUM
    ////////////////////////////////////////////////////
    enum ValidatorStatus {
        UNKNOWN, // default value
        DEPOSITED, // ensure 1 eth has been deposited, at this stage validator is not yet active
        ACTIVE, // validator is active and participating in consensus
        EXITED, // validator has exited and is no longer participating
        WITHDRAWABLE // validator has exited and can withdraw funds (not implemented)

    }

    /// @notice Struct used to represent: Deposit, Pending, Exiting and Withdraw
    struct Queue {
        bytes pubkey;
        uint64 timestamp;
        uint256 amount; // in wei
        address owner;
    }

    struct Validator {
        bytes pubkey;
        address owner;
        uint256 amount; // in wei
        ValidatorStatus status;
    }

    ////////////////////////////////////////////////////
    /// --- STORAGE
    ////////////////////////////////////////////////////
    Queue[] public exitQueue;
    Queue[] public depositQueue;
    Queue[] public pendingQueue;
    Queue[] public withdrawQueue;
    Validator[] public validators; // unordered list of validator

    ////////////////////////////////////////////////////
    /// --- ERRORS & EVENTS
    ////////////////////////////////////////////////////
    // Deposit events
    event BeaconChain___Deposit(bytes pubkey, uint256 amount);
    event BeaconChain___DepositProcessed(bytes pubkey, uint256 amount);

    // Validators events
    event BeaconChain___ValidatorCreated(bytes pubkey);
    event BeaconChain___ValidatorActivated(bytes pubkey);
    event BeaconChain___ValidatorExited(bytes pubkey);
    event BeaconChain___ValidatorWithdrawable(bytes pubkey);
    event BeaconChain___ValidatorSlashed(bytes pubkey, uint256 amount);

    ////////////////////////////////////////////////////
    /// --- DEPOSIT FUNCTIONS
    ////////////////////////////////////////////////////
    function deposit(
        bytes calldata pubkey,
        bytes calldata, /*withdrawal_credentials*/
        bytes calldata, /*signature*/
        bytes32 /*deposit_data_root*/
    ) public payable {
        require(msg.value >= MIN_DEPOSIT, "Minimum deposit is 1 ETH");
        depositQueue.push(
            Queue({ amount: msg.value, pubkey: pubkey, timestamp: uint64(block.timestamp), owner: msg.sender })
        );
        emit BeaconChain___Deposit(pubkey, msg.value);
    }

    /// @param index The index of the deposit to process, should be always 0 to process in FIFO order, but can be any index
    /// to allow flexibility
    function processDeposit(
        uint256 index
    ) public {
        // Ensure the index is within bounds
        require(index < depositQueue.length, "Invalid deposit index");

        // Store deposit in memory to avoid multiple SLOADs
        Queue memory pendingDeposit = depositQueue[index];

        // Remove deposit from depositQueue and conserve order, by shifting elements from right to left
        _removeFromList(depositQueue, index);

        bytes memory pubkey = pendingDeposit.pubkey;

        // Get the validator index corresponding to the pubkey, if it exists
        // It is same to reuse `index` variable as not used anymore
        index = getValidatorIndex(pubkey);

        // --- 1. Validator doesn't exist for this pubkey, create it
        if (index == NOT_FOUND) {
            validators.push(
                Validator({
                    pubkey: pendingDeposit.pubkey,
                    amount: 0,
                    owner: pendingDeposit.owner,
                    status: ValidatorStatus.DEPOSITED
                })
            );
            emit BeaconChain___ValidatorCreated(pubkey);

            // Add to pendingQueue
            pendingQueue.push(
                Queue({
                    amount: pendingDeposit.amount,
                    pubkey: pendingDeposit.pubkey,
                    timestamp: pendingDeposit.timestamp,
                    owner: pendingDeposit.owner
                })
            );
            emit BeaconChain___DepositProcessed(pubkey, pendingDeposit.amount);

            return;
        }

        // --- 2. Validator exists, handle based on its current status
        Validator storage validator = validators[index];
        ValidatorStatus currentStatus = validator.status;

        // --- 2.a. Validator is in DEPOSITED state, increase pending validator amount
        if (currentStatus == ValidatorStatus.DEPOSITED) {
            // Find the pending validator and increase its amount
            for (uint256 i = 0; i < pendingQueue.length; i++) {
                if (keccak256(pendingQueue[i].pubkey) == keccak256(pubkey)) {
                    pendingQueue[i].amount += pendingDeposit.amount;
                    break;
                }
            }
            emit BeaconChain___DepositProcessed(pubkey, pendingDeposit.amount);
        }
        // --- 2.b. Validator exists and is ACTIVE or WITHDRAWABLE, increase stake
        else if (currentStatus == ValidatorStatus.ACTIVE || currentStatus == ValidatorStatus.WITHDRAWABLE) {
            validator.amount += pendingDeposit.amount;
            emit BeaconChain___DepositProcessed(pubkey, pendingDeposit.amount);
        }
        // --- 2.c. Exited validators cannot be reactivated, so deposits are postponed
        else if (currentStatus == ValidatorStatus.EXITED) {
            depositQueue.push(pendingDeposit);
            emit BeaconChain___Deposit(pubkey, pendingDeposit.amount);
        }
    }

    /// @param index The index of the pending validator to activate, should be always 0 to process in FIFO order, but can be
    /// any index to allow flexibility
    function activateValidator(
        uint256 index
    ) public {
        require(index < pendingQueue.length, "Invalid pending validator index");

        // Store pending validator in memory to avoid multiple SLOADs
        Queue memory pendingValidator = pendingQueue[index];
        bytes memory pubkey = pendingValidator.pubkey;

        // Move the pending validator to the end of the array, conserving order
        // We decide after if we will pop or update the last element, based on the amount of ETH in the validator
        for (uint256 i = index; i < pendingQueue.length - 1; i++) {
            pendingQueue[i] = pendingQueue[i + 1];
        }

        // Get the validator index corresponding to the pubkey, it must exist
        Validator storage validator = validators[getValidatorIndex(pubkey)];

        // If the pending validator has less than 32 ETH, update the last element and return
        if (validator.amount + pendingValidator.amount < ACTIVATION_AMOUNT) {
            pendingQueue[pendingQueue.length - 1] = pendingValidator;
            return;
        } else {
            pendingQueue.pop(); // Remove the last element (now a duplicate)
        }

        // Ensure the validator is in DEPOSITED state
        require(validator.status == ValidatorStatus.DEPOSITED, "Validator must be in DEPOSITED state");

        // Update the validator's status and amount
        validator.status = ValidatorStatus.ACTIVE;
        validator.amount += pendingValidator.amount;

        // Add to validators
        validators.push(
            Validator({
                pubkey: pendingValidator.pubkey,
                amount: validator.amount,
                owner: pendingValidator.owner,
                status: ValidatorStatus.ACTIVE
            })
        );

        emit BeaconChain___ValidatorActivated(pubkey);
    }

    function simulateRewards(uint16 index, uint256 amount) public {
        require(index < validators.length, "Invalid validator index");
        Validator storage validator = validators[index];
        require(validator.status == ValidatorStatus.ACTIVE, "Validator must be ACTIVE to receive rewards");

        // Increase the validator's amount by the reward
        validator.amount += amount;

        // Distribute rewards using RewardDistributor
        rewardDistributor.distributeRewards(address(this), amount);
    }

    ////////////////////////////////////////////////////
    /// --- WITHDRAW FUNCTIONS
    ////////////////////////////////////////////////////

    function withdraw(bytes calldata pubkey, uint256 amount) external {
        Validator memory validator = validators[getValidatorIndex(pubkey)];
        require(validator.owner == msg.sender, "Only owner can request withdrawal");
        require(validator.amount >= amount, "Insufficient validator balance");

        withdrawQueue.push(Queue({ pubkey: pubkey, amount: amount, timestamp: uint64(block.timestamp), owner: address(0) }));
    }

    function processWithdraw(
        uint256 index
    ) public {
        require(index < withdrawQueue.length, "Invalid withdrawal index");

        // Store withdrawal in memory to avoid multiple SLOADs
        Queue memory pendingWithdrawal = withdrawQueue[index];

        // Remove withdrawal from withdrawQueue and conserve order, by shifting elements from right to left
        _removeFromList(withdrawQueue, index);

        bytes memory pubkey = pendingWithdrawal.pubkey;

        // Get the validator index corresponding to the pubkey, it must exist
        Validator storage validator = validators[getValidatorIndex(pubkey)];

        // Ensure the validator has enough balance and deduct the amount
        require(validator.amount >= pendingWithdrawal.amount, "Insufficient validator balance");
        validator.amount -= pendingWithdrawal.amount;

        // Transfer ETH to the validator owner
        (bool success,) = validator.owner.call{ value: pendingWithdrawal.amount }("");
        require(success, "Withdrawal transfer failed");

        // If validator amount is less than 16 ETH, move validator to exit queue
        if (validator.amount < ACTIVATION_AMOUNT / 2) {
            validator.status = ValidatorStatus.EXITED;
            exitQueue.push(Queue({ pubkey: pubkey, timestamp: uint64(block.timestamp), amount: 0, owner: validator.owner }));
        }
    }

    function processExit(
        uint256 index
    ) public {
        require(index < exitQueue.length, "Invalid exit index");

        // Store exiting validator in memory to avoid multiple SLOADs
        Queue memory exitingValidator = exitQueue[index];

        // Remove exiting validator from exitQueue and conserve order, by shifting elements from right to left
        _removeFromList(exitQueue, index);

        bytes memory pubkey = exitingValidator.pubkey;

        //  Get the validator index corresponding to the pubkey, it must exist
        Validator storage validator = validators[getValidatorIndex(pubkey)];

        // Ensure the validator is in EXITED state
        require(validator.status == ValidatorStatus.EXITED, "Validator must be in EXITED state");

        // Validator can now be marked as WITHDRAWABLE
        validator.status = ValidatorStatus.WITHDRAWABLE;
    }

    /// @notice Get through all active validators and process:
    /// - removed all amount above 2048 ETH, assuming only 0x02 validators
    function processSweep() public {
        for (uint256 i = 0; i < validators.length; i++) {
            Validator storage validator = validators[i];
            ValidatorStatus status = validator.status;
            if (status == ValidatorStatus.UNKNOWN) revert("Validator in UNKNOWN state"); // should never happen
            if (status == ValidatorStatus.DEPOSITED) continue;
            if (status == ValidatorStatus.ACTIVE) {
                if (validator.amount > MAX_EFFECTIVE_BALANCE) {
                    uint256 excess = validator.amount - MAX_EFFECTIVE_BALANCE;
                    validator.amount = MAX_EFFECTIVE_BALANCE;

                    // Transfer excess ETH to the validator owner
                    (bool success,) = validator.owner.call{ value: excess }("");
                    require(success, "Excess transfer failed");
                }
            }
            if (status == ValidatorStatus.EXITED) continue;
            if (status == ValidatorStatus.WITHDRAWABLE) {
                if (validator.amount > 0) {
                    uint256 excess = validator.amount;
                    validator.amount = 0;

                    // Transfer all ETH to the validator owner
                    (bool success,) = validator.owner.call{ value: excess }("");
                    require(success, "Withdrawable transfer failed");
                }
            }
        }
    }

    function slash(uint16 index, uint256 amount) public {
        require(index < validators.length, "Invalid validator index");
        Validator storage validator = validators[index];
        require(validator.amount >= amount, "Insufficient validator balance to slash");
        require(validator.status == ValidatorStatus.ACTIVE, "Validator must be ACTIVE to be slashed");

        // Slash the validator
        validator.amount -= amount;

        // Send ETH to the slashing reward address
        (bool success,) = SLASHING_REWARD_RECIPIENT.call{ value: amount }("");
        require(success, "Slashing transfer failed");

        // If validator amount is less than 16 ETH, move validator to exit queue
        if (validator.amount < MIN_EXIT_AMOUNT) {
            validator.status = ValidatorStatus.EXITED;
            exitQueue.push(
                Queue({ pubkey: validator.pubkey, timestamp: uint64(block.timestamp), amount: 0, owner: validator.owner })
            );
        }
    }

    ////////////////////////////////////////////////////
    /// --- HELPER FUNCTIONS
    ////////////////////////////////////////////////////
    function _removeFromList(Queue[] storage list, uint256 index) internal {
        if (list.length == 0) return;
        require(index < list.length, "Invalid index");
        for (uint256 i = index; i < list.length - 1; i++) {
            list[i] = list[i + 1];
        }
        list.pop();
    }

    ////////////////////////////////////////////////////
    /// --- VIEW FUNCTIONS
    ////////////////////////////////////////////////////
    function getValidator(
        uint256 index
    ) external view returns (Validator memory) {
        require(index < validators.length, "Invalid validator index");
        return validators[index];
    }

    function getValidators() external view returns (Validator[] memory) {
        return validators;
    }

    function getDepositQueue() external view returns (Queue[] memory) {
        return depositQueue;
    }

    function getPendingQueue() external view returns (Queue[] memory) {
        return pendingQueue;
    }

    function getWithdrawQueue() external view returns (Queue[] memory) {
        return withdrawQueue;
    }

    function getExitQueue() external view returns (Queue[] memory) {
        return exitQueue;
    }

    function getValidatorIndex(
        bytes memory pubkey
    ) public view returns (uint256) {
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i].pubkey.eq(pubkey)) return i;
        }
        return NOT_FOUND; // Not found
    }
}
