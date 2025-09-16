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

    RewardDistributor public immutable REWARD_DISTRIBUTOR = new RewardDistributor();

    ////////////////////////////////////////////////////
    /// --- STRUCTS & ENUM
    ////////////////////////////////////////////////////
    enum ValidatorStatus {
        UNKNOWN, // default value
        DEPOSITED, // ensure 1 eth has been deposited, at this stage validator is not yet active
        ACTIVE, // validator is active and participating in consensus
        EXITED, // validator is no longer participating, but still has funds in the system
        WITHDRAWABLE // validator has exited and can withdraw funds

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
    Queue[] public withdrawQueue;
    Validator[] public validators; // unordered list of validator
    mapping(bytes pubkey => bool registered) public ssvRegistreredValidators; // mapping of SSV registered validators

    ////////////////////////////////////////////////////
    /// --- ERRORS & EVENTS
    ////////////////////////////////////////////////////
    // Deposit events
    event BeaconChain___Deposit(bytes pubkey, uint256 amount);
    event BeaconChain___DepositProcessed(bytes pubkey, uint256 amoun, ValidatorStatus status);
    event BeaconChain___Withdraw(bytes pubkey, uint256 amount);
    event BeaconChain___WithdrawProcessed(bytes pubkey, uint256 amount);
    event BeaconChain___Exit(bytes pubkey, uint256 remainingAmount);

    // Validators events
    event BeaconChain___ValidatorCreated(bytes pubkey);
    event BeaconChain___ValidatorActivated(bytes pubkey, uint256 amount);
    event BeaconChain___ValidatorExited(bytes pubkey);
    event BeaconChain___ValidatorWithdrawable(bytes pubkey);
    event BeaconChain___ValidatorSlashed(bytes pubkey, uint256 amount);

    // General
    event SSVNetwork___ValidatorRegistered(bytes pubkey);
    event SSVNetwork___ValidatorRemoved(bytes pubkey);
    event BeaconChain___Sweep(bytes pubkey, uint256 amount);
    event BeaconChain___RewardsDistributed(bytes to, uint256 amount);

    // Errors (labeled as event to prevent revert)
    event INSUFFICIENT_VALIDATOR_BALANCE(bytes pubkey, uint256 available, uint256 requested);
    event ONLY_OWNER_CAN_REQUEST_WITHDRAWAL(bytes pubkey, address owner, address requester);

    ////////////////////////////////////////////////////
    /// --- DEPOSIT FUNCTIONS
    ////////////////////////////////////////////////////
    /// @notice Accepts ETH sent directly to the contract.
    receive() external payable { }

    /// @notice Deposit ETH for a validator.
    /// @param pubkey The public key of the validator.
    /// @dev Requires validator to be registered in SSVNetwork and deposit >= 1 ETH.
    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawalCredentials,
        bytes calldata, /*signature*/
        bytes32 /*deposit_data_root*/
    ) public payable {
        require(msg.value >= MIN_DEPOSIT, "Minimum deposit is 1 ETH");
        require(ssvRegistreredValidators[pubkey], "Validator not registered in SSVNetwork");
        depositQueue.push(
            Queue({
                amount: msg.value,
                pubkey: pubkey,
                timestamp: uint64(block.timestamp),
                owner: decodeOwner(withdrawalCredentials)
            })
        );
        emit BeaconChain___Deposit(pubkey, msg.value);
    }

    /// @notice Processes a deposit from the deposit queue.
    function processDeposit() public {
        if (depositQueue.length == 0) return; // No pending deposits

        // Store first deposit in memory to avoid multiple SLOADs
        Queue memory pendingDeposit = depositQueue[0];

        // Remove deposit from depositQueue and conserve order, by shifting elements from right to left
        _removeFromList(depositQueue, 0);

        bytes memory pubkey = pendingDeposit.pubkey;

        // Get the validator index corresponding to the pubkey, if it exists
        // It is same to reuse `index` variable as not used anymore
        uint256 index = getValidatorIndex(pubkey);

        // --- 1. Validator doesn't exist for this pubkey, create it and add amount
        if (index == NOT_FOUND) {
            validators.push(
                Validator({
                    pubkey: pendingDeposit.pubkey,
                    amount: pendingDeposit.amount,
                    owner: pendingDeposit.owner,
                    status: ValidatorStatus.DEPOSITED
                })
            );
            emit BeaconChain___ValidatorCreated(pubkey);
            emit BeaconChain___DepositProcessed(pubkey, pendingDeposit.amount, ValidatorStatus.DEPOSITED);
            return;
        }

        // --- 2. Validator exists, handle based on its current status
        Validator storage validator = validators[index];
        ValidatorStatus currentStatus = validator.status;

        // --- 2.a. UNKNOWN status should never happen
        if (currentStatus == ValidatorStatus.UNKNOWN) revert("Validator in UNKNOWN state"); // should never happen

        // --- 2.b. Exited validators cannot be reactivated, so deposits are postponed
        if (currentStatus == ValidatorStatus.EXITED) {
            depositQueue.push(pendingDeposit);
            emit BeaconChain___Deposit(pubkey, pendingDeposit.amount);
        }

        // --- 2.c. Validator exists and is either DEPOSITED, ACTIVE or WITHDRAWABLE: increase stake
        validator.amount += pendingDeposit.amount;
        emit BeaconChain___DepositProcessed(pubkey, pendingDeposit.amount, currentStatus);
    }

    /// @notice Processes multiple deposits from the deposit queue.
    /// @param count The number of deposits to process.
    /// @dev Processes up to `count` deposits, or all if `count` exceeds the queue length.
    function processDeposit(
        uint256 count
    ) public {
        uint256 len = min(depositQueue.length, count);
        for (uint256 i; i < len; i++) {
            processDeposit();
        }
    }

    /// @notice Activates all eligible validators.
    function activateValidators() public {
        activateValidators(validators.length);
    }

    /// @notice Goes through all validators and activates those that are `DEPOSITED` and have enough ETH.
    function activateValidators(
        uint256 count
    ) public {
        uint256 len = min(validators.length, count);
        for (uint256 i; i < len; i++) {
            Validator storage validator = validators[i];
            if (validator.status == ValidatorStatus.DEPOSITED && validator.amount >= ACTIVATION_AMOUNT) {
                validator.status = ValidatorStatus.ACTIVE;
                emit BeaconChain___ValidatorActivated(validator.pubkey, validator.amount);
            }
        }
    }

    ////////////////////////////////////////////////////
    /// --- WITHDRAW FUNCTIONS
    ////////////////////////////////////////////////////

    /// @notice Request withdrawal of ETH from a validator.
    /// @param pubkey The public key of the validator.
    /// @param amount The amount to withdraw.
    /// @dev Only the owner can request withdrawal.
    function withdraw(bytes calldata pubkey, uint256 amount) external {
        Validator memory validator = validators[getValidatorIndex(pubkey)];
        if (validator.status != ValidatorStatus.ACTIVE) return; // Only ACTIVE validators can request withdrawal

        withdrawQueue.push(Queue({ pubkey: pubkey, amount: amount, timestamp: uint64(block.timestamp), owner: address(0) }));

        emit BeaconChain___Withdraw(pubkey, amount);
    }

    /// @notice Processes a withdrawal from the withdraw queue.
    function processWithdraw() public {
        if (withdrawQueue.length == 0) return; // No pending withdrawals

        // Store withdrawal in memory to avoid multiple SLOADs
        Queue memory pendingWithdrawal = withdrawQueue[0];

        // Remove withdrawal from withdrawQueue and conserve order, by shifting elements from right to left
        _removeFromList(withdrawQueue, 0);

        bytes memory pubkey = pendingWithdrawal.pubkey;

        // Get the validator index corresponding to the pubkey, it must exist
        Validator storage validator = validators[getValidatorIndex(pubkey)];

        // Ensure the validator has enough balance and deduct the amount
        if (validator.amount < pendingWithdrawal.amount) {
            emit INSUFFICIENT_VALIDATOR_BALANCE(pubkey, validator.amount, pendingWithdrawal.amount);
            return; // Incorrect withdraw request, ignored
        }
        if (validator.owner != msg.sender) {
            emit ONLY_OWNER_CAN_REQUEST_WITHDRAWAL(pubkey, validator.owner, msg.sender);
            return; // Only owner can request withdrawal, ignored
        }
        validator.amount -= pendingWithdrawal.amount;

        // Transfer ETH to the validator owner
        (bool success,) = validator.owner.call{ value: pendingWithdrawal.amount }("");
        require(success, "Withdrawal transfer failed");

        emit BeaconChain___WithdrawProcessed(pubkey, pendingWithdrawal.amount);

        // If validator amount is less than 16 ETH, move validator to exit queue
        if (validator.amount < ACTIVATION_AMOUNT / 2) {
            validator.status = ValidatorStatus.EXITED;
            exitQueue.push(Queue({ pubkey: pubkey, timestamp: uint64(block.timestamp), amount: 0, owner: validator.owner }));
            emit BeaconChain___Exit(pubkey, validator.amount);
        }
    }

    /// @notice Processes the first pending exit in the exit queue (FIFO).
    function processExit() public {
        require(exitQueue.length > 0, "No pending exits");
        processExit(0);
    }

    /// @notice Processes an exit from the exit queue.
    /// @param index The index of the exit to process.
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

        emit BeaconChain___ValidatorWithdrawable(pubkey);
    }

    /// @notice Get through all active validators and process:
    /// - removed all amount above 2048 ETH, assuming only 0x02 validators
    /// @notice Sweeps excess ETH from active and withdrawable validators, transferring to owners.
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
                    emit BeaconChain___Sweep(validator.pubkey, excess);
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
                    emit BeaconChain___WithdrawProcessed(validator.pubkey, excess);
                }
            }
        }
    }

    ////////////////////////////////////////////////////
    /// --- VALIDATORS MANAGEMENT FUNCTIONS
    ////////////////////////////////////////////////////
    /// @notice Registers a validator in the SSVNetwork.
    /// @param pubkey The public key of the validator.
    function registerSsvValidator(
        bytes memory pubkey
    ) public {
        require(!ssvRegistreredValidators[pubkey], "Validator already registered");
        ssvRegistreredValidators[pubkey] = true;

        emit SSVNetwork___ValidatorRegistered(pubkey);
    }

    /// @notice Removes a validator from the SSVNetwork.
    /// @param pubkey The public key of the validator.
    /// @dev Validator must have zero balance and not be withdrawable.
    function removeSsvValidator(
        bytes memory pubkey
    ) public {
        Validator memory validator = validators[getValidatorIndex(pubkey)];
        require(ssvRegistreredValidators[pubkey], "Validator not registered");
        require(validator.status != ValidatorStatus.WITHDRAWABLE, "Cannot remove WITHDRAWABLE validator");
        require(validator.amount == 0, "Cannot remove validator with balance");
        ssvRegistreredValidators[pubkey] = false;

        emit SSVNetwork___ValidatorRemoved(pubkey);
    }

    /// @notice Simulates reward distribution to a validator.
    /// @param pubkey The public key of the validator.
    /// @param amount The amount of rewards to distribute.
    function simulateRewards(bytes memory pubkey, uint256 amount) public {
        uint256 index = getValidatorIndex(pubkey);
        require(index < validators.length, "Invalid validator index");
        Validator storage validator = validators[index];
        require(validator.status == ValidatorStatus.ACTIVE, "Validator must be ACTIVE to receive rewards");

        // Increase the validator's amount by the reward
        validator.amount += amount;

        // Distribute rewards using RewardDistributor
        REWARD_DISTRIBUTOR.distributeRewards(address(this), amount);

        emit BeaconChain___RewardsDistributed(pubkey, amount);
    }

    /// @notice Slashes a validator by reducing its balance and sending ETH to the slashing reward recipient.
    /// @param pubkey The public key of the validator.
    /// @param amount The amount to slash.
    function slash(bytes memory pubkey, uint256 amount) public {
        uint256 index = getValidatorIndex(pubkey);
        require(index < validators.length, "Invalid validator index");
        Validator storage validator = validators[index];
        require(validator.amount >= amount, "Insufficient validator balance to slash");
        require(validator.status == ValidatorStatus.ACTIVE, "Validator must be ACTIVE to be slashed");

        // Slash the validator
        validator.amount -= amount;

        // Send ETH to the slashing reward address
        (bool success,) = SLASHING_REWARD_RECIPIENT.call{ value: amount }("");
        require(success, "Slashing transfer failed");

        emit BeaconChain___ValidatorSlashed(pubkey, amount);

        // If validator amount is less than 16 ETH, move validator to exit queue
        if (validator.amount < MIN_EXIT_AMOUNT) {
            validator.status = ValidatorStatus.EXITED;
            exitQueue.push(
                Queue({ pubkey: validator.pubkey, timestamp: uint64(block.timestamp), amount: 0, owner: validator.owner })
            );
            emit BeaconChain___Exit(pubkey, validator.amount);
        }
    }

    /// @notice Returns the protocol fee (not implemented).
    function fee() external pure returns (uint256) { }

    ////////////////////////////////////////////////////
    /// --- HELPER FUNCTIONS
    ////////////////////////////////////////////////////
    /// @notice Removes an element from a queue at a given index, preserving order.
    /// @param list The queue to remove from.
    /// @param index The index to remove.
    function _removeFromList(Queue[] storage list, uint256 index) internal {
        if (list.length == 0) return;
        require(index < list.length, "Invalid index");
        for (uint256 i = index; i < list.length - 1; i++) {
            list[i] = list[i + 1];
        }
        list.pop();
    }

    /// @notice Decodes the owner address from withdrawal credentials.
    /// @param withdrawalCredentials The withdrawal credentials.
    /// @return The owner address.
    function decodeOwner(
        bytes memory withdrawalCredentials
    ) public pure returns (address) {
        require(withdrawalCredentials.length == 32, "Invalid withdrawal credentials length");
        require(!withdrawalCredentials.eq(bytes("")), "Invalid withdrawal credentials prefix");

        // forge-lint: disable-next-line(unsafe-typecast)
        return address(uint160(uint256(bytes32(withdrawalCredentials))));
    }

    /// @notice Returns the minimum of two uint256 values.
    /// @param a The first value.
    /// @param b The second value.
    /// @return The minimum value.
    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    ////////////////////////////////////////////////////
    /// --- VIEW FUNCTIONS
    ////////////////////////////////////////////////////
    /// @notice Returns a validator by index.
    /// @param index The index of the validator.
    /// @return The validator struct.
    function getValidator(
        uint256 index
    ) external view returns (Validator memory) {
        require(index < validators.length, "Invalid validator index");
        return validators[index];
    }

    /// @notice Returns all validators.
    function getValidators() external view returns (Validator[] memory) {
        return validators;
    }

    /// @notice Returns the number of validators.
    function getValidatorLength() external view returns (uint256) {
        return validators.length;
    }

    /// @notice Returns the deposit queue.
    function getDepositQueue() external view returns (Queue[] memory) {
        return depositQueue;
    }

    /// @notice Returns the length of the deposit queue.
    function getDepositQueueLength() external view returns (uint256) {
        return depositQueue.length;
    }

    /// @notice Returns the withdraw queue.
    function getWithdrawQueue() external view returns (Queue[] memory) {
        return withdrawQueue;
    }

    /// @notice Returns the length of the withdraw queue.
    function getWithdrawQueueLength() external view returns (uint256) {
        return withdrawQueue.length;
    }

    /// @notice Returns the exit queue.
    function getExitQueue() external view returns (Queue[] memory) {
        return exitQueue;
    }

    /// @notice Returns the length of the exit queue.
    function getExitQueueLength() external view returns (uint256) {
        return exitQueue.length;
    }

    /// @notice Returns the index of a validator by public key.
    /// @param pubkey The public key of the validator.
    /// @return The index of the validator, or NOT_FOUND if not found.
    function getValidatorIndex(
        bytes memory pubkey
    ) public view returns (uint256) {
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i].pubkey.eq(pubkey)) return i;
        }
        return NOT_FOUND; // Not found
    }
}

// --- List of actions ---
// processDeposit
// activateValidators
// processExit
// processWithdraw
// processSweep
// simulateRewards
// slash

// --- Process epoch ---
// activate validators
// process slashing
// process deposits
