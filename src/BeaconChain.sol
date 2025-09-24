// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Contracts
import { BeaconProofs } from "./BeaconProofs.sol";
import { RewardDistributor } from "./RewardDistributor.sol";

// Helper
import { LibBytes } from "@solady/utils/LibBytes.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";
import { LibConstant } from "../test/libraries/LibConstant.sol";
import { LibValidator } from "../test/libraries/LibValidator.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";

contract BeaconChain {
    using LibBytes for bytes;
    using SafeCastLib for uint256;
    using LibValidator for bytes;
    using FixedPointMathLib for uint256;

    RewardDistributor public immutable REWARD_DISTRIBUTOR = new RewardDistributor();

    ////////////////////////////////////////////////////
    /// --- STRUCTS & ENUM
    ////////////////////////////////////////////////////
    enum Status {
        UNKNOWN, // default value
        DEPOSITED, // ensure 1 eth has been deposited, at this stage validator is not yet active
        ACTIVE, // validator is active and participating in consensus
        EXITED, // validator is no longer participating, but still has funds in the system
        WITHDRAWABLE // validator has exited and can withdraw funds

    }

    enum DepositStatus {
        UNKNOWN, // default value
        PENDING, // deposit is in the queue, waiting to be processed
        PROCESSED // deposit has been processed

    }

    /// @notice Struct used to represent: Deposit, Pending, Exiting and Withdraw
    struct Queue {
        bytes pubkey;
        uint64 timestamp;
        uint256 amount; // in wei
        address owner;
        bytes32 udid;
    }

    struct Validator {
        bytes pubkey;
        address owner;
        uint256 amount; // in wei
        Status status;
    }

    ////////////////////////////////////////////////////
    /// --- STORAGE
    ////////////////////////////////////////////////////
    Queue[] public depositQueue;
    Queue[] public withdrawQueue;
    Validator[] public validators; // unordered list of validator

    uint256 public withdrawCounter; // counter to track number of withdraw processed

    mapping(bytes pubkey => bool registered) public ssvRegisteredValidators; // mapping of SSV registered validators
    mapping(bytes32 id => DepositStatus processed) public processedDeposits; // to help tracking processed deposits

    BeaconProofs public beaconProofs;

    ////////////////////////////////////////////////////
    /// --- ERRORS & EVENTS
    ////////////////////////////////////////////////////
    // Status change events
    event BeaconChain___StatusChanged(bytes pubkey, uint256 amount, Status oldStatus, Status newStatus);
    // Deposit events
    event BeaconChain___Deposit(bytes pubkey, uint256 amount);
    event BeaconChain___DepositProcessed(bytes pubkey, uint256 amount, Status status);
    event BeaconChain___DepositPostponed(bytes pubkey, uint256 amount);
    // Withdraw events
    event BeaconChain___Withdraw(bytes pubkey, uint256 amount);
    event BeaconChain___PartialWithdrawProcessed(bytes pubkey, uint256 amount);
    event BeaconChain___WithdrawProcessed(bytes pubkey, uint256 amount);
    event BeaconChain___WithdrawNotProcessed(bytes pubkey, bytes32 udid, string reason);

    // Validators events
    event BeaconChain___ValidatorCreated(bytes pubkey);
    event BeaconChain___ValidatorSlashed(bytes pubkey, uint256 amount);

    // General
    event SSVNetwork___ValidatorRegistered(bytes pubkey);
    event SSVNetwork___ValidatorRemoved(bytes pubkey);
    event BeaconChain___Sweep(bytes pubkey, uint256 amount);
    event BeaconChain___RewardsDistributed(bytes to, uint256 amount);

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
        bytes calldata signature,
        bytes32 /*deposit_data_root*/
    ) public payable {
        require(msg.value >= LibConstant.MIN_DEPOSIT, "Minimum deposit is 1 ETH");
        require(ssvRegisteredValidators[pubkey], "Validator not registered in SSVNetwork");

        // recreate the pendingDepositRoot, that will be used as unique deposit ID
        // signature is the value responsible to make the deposit unique
        bytes32 udid = beaconProofs.merkleizePendingDeposit({
            pubKeyHash: pubkey.hashPubkey(),
            withdrawalCredentials: withdrawalCredentials,
            amountGwei: (msg.value / 1 gwei).toUint64(),
            signature: signature,
            slot: 0
        });
        // This check is only for the sake of the fuzz test
        require(processedDeposits[udid] == DepositStatus.UNKNOWN, "Deposit with same UDID already processed");
        processedDeposits[udid] = DepositStatus.PENDING;

        depositQueue.push(
            Queue({
                amount: msg.value,
                pubkey: pubkey,
                timestamp: uint64(block.timestamp),
                owner: decodeOwner(withdrawalCredentials),
                udid: udid
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
        if (index == LibConstant.NOT_FOUND) {
            validators.push(
                Validator({
                    pubkey: pendingDeposit.pubkey,
                    amount: pendingDeposit.amount,
                    owner: pendingDeposit.owner,
                    status: Status.DEPOSITED
                })
            );
            processedDeposits[pendingDeposit.udid] = DepositStatus.PROCESSED;
            emit BeaconChain___ValidatorCreated(pubkey);
            emit BeaconChain___StatusChanged(pubkey, pendingDeposit.amount, Status.UNKNOWN, Status.DEPOSITED);
            emit BeaconChain___DepositProcessed(pubkey, pendingDeposit.amount, Status.DEPOSITED);
            return;
        }

        // --- 2. Validator exists, handle based on its current status
        Validator storage validator = validators[index];
        Status currentStatus = validator.status;

        // --- 2.a. UNKNOWN status should never happen
        if (currentStatus == Status.UNKNOWN) revert("Validator in UNKNOWN state"); // should never happen

        // --- 2.b. Exited validators cannot be reactivated, so deposits are postponed
        if (currentStatus == Status.EXITED) {
            depositQueue.push(pendingDeposit);
            emit BeaconChain___DepositPostponed(pubkey, pendingDeposit.amount);
            return;
        }

        // --- 2.c. Validator exists and is either DEPOSITED, ACTIVE or WITHDRAWABLE: increase stake
        validator.amount += pendingDeposit.amount;
        processedDeposits[pendingDeposit.udid] = DepositStatus.PROCESSED;
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

    ////////////////////////////////////////////////////
    /// --- WITHDRAW FUNCTIONS
    ////////////////////////////////////////////////////

    /// @notice Request withdrawal of ETH from a validator.
    /// @param pubkey The public key of the validator.
    /// @param amount The amount to withdraw. If 0, it means full withdrawal.
    /// @dev Only the owner can request withdrawal.
    function withdraw(bytes calldata pubkey, uint256 amount, address requester) external {
        withdrawQueue.push(
            Queue({
                pubkey: pubkey,
                amount: amount,
                timestamp: uint64(block.timestamp),
                owner: requester,
                udid: bytes32(abi.encodePacked(withdrawCounter.toUint16(), bytes30(0)))
            })
        );
        withdrawCounter++;
        emit BeaconChain___Withdraw(pubkey, amount);
    }

    /// @notice Processes a withdrawal from the withdraw queue.
    /// @notice Returns (pubkey, udid, amountWithdrawn). If no withdrawal processed, returns (0, 0, 0).
    function processWithdraw() public returns (bytes memory, bytes32, uint256) {
        if (withdrawQueue.length == 0) return (bytes(abi.encodePacked(uint256(0))), 0, 0); // No pending withdrawals

        // Store withdrawal in memory to avoid multiple SLOADs
        Queue memory pendingWithdrawal = withdrawQueue[0];

        // Remove withdrawal from withdrawQueue and conserve order, by shifting elements from right to left
        _removeFromList(withdrawQueue, 0);

        bytes memory pubkey = pendingWithdrawal.pubkey;
        bytes32 udid = pendingWithdrawal.udid;

        // Get the validator index corresponding to the pubkey, it must exist
        Validator storage validator = validators[getValidatorIndex(pubkey)];

        // Ensure validator is in correct state to process withdrawal
        if (validator.status != Status.ACTIVE) {
            emit BeaconChain___WithdrawNotProcessed(pubkey, udid, "Validator not ACTIVE state");
            return (LibConstant.NOT_FOUND_BYTES, udid, 0);
        }

        // Ensure only the owner can request withdrawal
        if (validator.owner != pendingWithdrawal.owner) {
            emit BeaconChain___WithdrawNotProcessed(pubkey, udid, "Only owner can request withdrawal");
            return (LibConstant.NOT_FOUND_BYTES, udid, 0);
        }

        // Ensure the validator has enough balance and deduct the amount for partial withdrawal
        if (pendingWithdrawal.amount != 0 && validator.amount < LibConstant.ACTIVATION_AMOUNT + pendingWithdrawal.amount) {
            emit BeaconChain___WithdrawNotProcessed(pubkey, udid, "Insufficient validator balance");
            return (LibConstant.NOT_FOUND_BYTES, udid, 0);
        }

        // There is two option, partial or full withdrawal
        // 1. Partial withdrawal:
        if (pendingWithdrawal.amount != 0 && validator.amount >= LibConstant.ACTIVATION_AMOUNT + pendingWithdrawal.amount) {
            // Reduce instantly the validator amount
            validator.amount -= pendingWithdrawal.amount;

            // Transfer ETH to the validator owner
            (bool success,) = validator.owner.call{ value: pendingWithdrawal.amount }("");
            require(success, "Withdrawal transfer failed");

            emit BeaconChain___PartialWithdrawProcessed(pubkey, pendingWithdrawal.amount);
            return (pubkey, udid, pendingWithdrawal.amount); // Partial withdrawal processed
        }

        // 2. Full withdrawal:
        if (pendingWithdrawal.amount == 0) {
            // Only mark the validator as EXITED, actual withdrawal will be processed in sweep
            validator.status = Status.EXITED;
            emit BeaconChain___StatusChanged(pubkey, validator.amount, Status.ACTIVE, Status.EXITED);
            return (pubkey, udid, validator.amount);
        }

        // This should never happen, but just in case, to avoid useless fuzz calls
        revert("Invalid withdrawal request");
    }

    /// @notice Processes multiple withdrawals from the withdraw queue.
    function processWithdraw(
        uint256 count
    ) public {
        uint256 len = min(withdrawQueue.length, count);
        for (uint256 i; i < len; i++) {
            processWithdraw();
        }
    }

    ////////////////////////////////////////////////////
    /// --- VALIDATORS MANAGEMENT FUNCTIONS
    ////////////////////////////////////////////////////
    /// @notice Activates all eligible validators.
    /// @return activatedPubkeys The public keys of activated validators.
    /// @return counter The number of validators activated.
    function activateValidators() public returns (bytes[] memory activatedPubkeys, uint256 counter) {
        return activateValidators(validators.length);
    }

    /// @notice Goes through all validators and activates those that are `DEPOSITED` and have enough ETH.
    /// @param count The maximum number of validators to activate.
    /// @return activatedPubkeys The public keys of activated validators.
    /// @return counter The number of validators activated.
    function activateValidators(
        uint256 count
    ) public returns (bytes[] memory activatedPubkeys, uint256 counter) {
        uint256 len = min(validators.length, count);
        activatedPubkeys = new bytes[](len);
        for (uint256 i; i < len; i++) {
            Validator storage validator = validators[i];
            if (validator.status == Status.DEPOSITED && validator.amount >= LibConstant.ACTIVATION_AMOUNT) {
                validator.status = Status.ACTIVE;
                emit BeaconChain___StatusChanged(validator.pubkey, validator.amount, Status.DEPOSITED, Status.ACTIVE);
                activatedPubkeys[counter] = validator.pubkey;
                counter++;
            }
        }
    }

    /// @notice Goes through all validators and activates the first one that is `DEPOSITED` and has enough ETH.
    function activateValidator() public returns (bytes memory) {
        uint256 len = validators.length;
        for (uint256 i; i < len; i++) {
            Validator storage validator = validators[i];
            if (validator.status == Status.DEPOSITED && validator.amount >= LibConstant.ACTIVATION_AMOUNT) {
                validator.status = Status.ACTIVE;
                emit BeaconChain___StatusChanged(validator.pubkey, validator.amount, Status.DEPOSITED, Status.ACTIVE);
                return validator.pubkey;
            }
        }
        return LibConstant.NOT_FOUND_BYTES; // No validator activated
    }

    /// @notice Goes through all validators and change status from EXITED to WITHDRAWABLE.
    /// @dev This function is used to simulate the exit delay, but does not enforce any time-based logic.
    function deactivateValidators(
        uint256 count
    ) public {
        // First count validators in EXITED state
        uint256 exitedCount;
        uint256 len = validators.length;
        for (uint256 i = 0; i < len; i++) {
            if (validators[i].status == Status.EXITED) exitedCount++;
        }
        if (exitedCount == 0) return; // No exited validators to process

        // Process up to `count` exited validators
        // Having two loops is not optimal but simplifies the logic, it can be improved.
        uint256 toProcess = min(exitedCount, count);
        uint256 processed;
        for (uint256 i = 0; i < len && processed < toProcess; i++) {
            Validator storage validator = validators[i];
            if (validator.status == Status.EXITED) {
                validator.status = Status.WITHDRAWABLE;
                emit BeaconChain___StatusChanged(validator.pubkey, validator.amount, Status.EXITED, Status.WITHDRAWABLE);
                processed++;
            }
        }
    }

    /// @notice Desactivate all exited validators.
    function deactivateValidators() public returns (bytes[] memory deactivatedPubkeys, uint256 counter) {
        uint256 len = validators.length;

        // Len is max size, will trim later if needed
        deactivatedPubkeys = new bytes[](len);
        for (uint256 i = 0; i < len; i++) {
            if (validators[i].status == Status.EXITED) {
                validators[i].status = Status.WITHDRAWABLE;
                emit BeaconChain___StatusChanged(
                    validators[i].pubkey, validators[i].amount, Status.EXITED, Status.WITHDRAWABLE
                );
                deactivatedPubkeys[counter] = validators[i].pubkey;
                counter++;
            }
        }
    }

    /// @notice Get through all active validators and process if status is:
    /// - UNKNOWN: revert as should never happen
    /// - DEPOSITED: do nothing, waiting either for more deposits or activateValidators to be called
    /// - ACTIVE: remove all amount above 2048 ETH, assuming only 0x02 validators
    /// - EXITED: do nothing, waiting for deactivateValidators to be called and move to WITHDRAWABLE
    /// - WITHDRAWABLE: transfer all amount to owner and set amount to 0
    function processSweep() public {
        for (uint256 i = 0; i < validators.length; i++) {
            _processSweep(i);
        }
    }

    /// @notice Processes sweep for fixed number of validators.
    /// @param count The number of validators to process.
    function processSweep(uint256 count, uint256 startIndex) public returns (uint256 len) {
        len = min(validators.length, count);
        for (uint256 i = startIndex; i < len + startIndex; i++) {
            _processSweep(i % len);
        }
    }

    /// @notice Internal function to process sweep for a single validator by index.
    /// @param index The index of the validator to process.
    function _processSweep(
        uint256 index
    ) internal {
        bool success;
        Validator storage validator = validators[index];
        Status status = validator.status;
        if (status == Status.UNKNOWN) revert("Validator in UNKNOWN state"); // should never happen
        if (status == Status.DEPOSITED) return;
        if (status == Status.ACTIVE) {
            if (validator.amount > LibConstant.MAX_EFFECTIVE_BALANCE) {
                uint256 excess = validator.amount - LibConstant.MAX_EFFECTIVE_BALANCE;
                validator.amount = LibConstant.MAX_EFFECTIVE_BALANCE;

                // Transfer excess ETH to the validator owner
                (success,) = validator.owner.call{ value: excess }("");
                require(success, "Excess transfer failed");
                emit BeaconChain___Sweep(validator.pubkey, excess);
            }
        }
        if (status == Status.EXITED) return;
        if (status == Status.WITHDRAWABLE) {
            if (validator.amount == 0) return; // Nothing to withdraw

            uint256 remaining = validator.amount;
            validator.amount = 0;
            // Transfer all ETH to the validator owner
            (success,) = validator.owner.call{ value: remaining }("");
            require(success, "Withdrawable transfer failed");
            emit BeaconChain___WithdrawProcessed(validator.pubkey, remaining);
        }
    }

    /// @notice Simulates reward distribution to a validator.
    /// @param pubkey The public key of the validator.
    /// @param amount The amount of rewards to distribute.
    function simulateRewards(bytes memory pubkey, uint256 amount) public {
        uint256 index = getValidatorIndex(pubkey);
        require(index < validators.length, "Invalid validator index");
        Validator storage validator = validators[index];
        require(validator.status == Status.ACTIVE, "Validator must be ACTIVE to receive rewards");

        // Increase the validator's amount by the reward
        validator.amount += amount;

        // Distribute rewards using RewardDistributor
        REWARD_DISTRIBUTOR.distributeRewards(address(this), amount);

        emit BeaconChain___RewardsDistributed(pubkey, amount);
    }

    /// @notice Browse through all active validators and simulate fixed percentage rewards.
    function simulateRewards() public returns (bytes[] memory receivers, uint256 counter, uint256 amount) {
        uint256 len = validators.length;
        receivers = new bytes[](len);
        for (uint256 i = 0; i < len; i++) {
            Validator storage validator = validators[i];
            if (validator.status == Status.ACTIVE) {
                // Calculate reward as a fixed percentage of the validator's amount
                uint256 reward = validator.amount.mulWad(LibConstant.FIXED_REWARD_PERCENTAGE);

                // Increase the validator's amount by the reward
                validator.amount += reward;
                amount += reward;

                // Distribute rewards using RewardDistributor
                REWARD_DISTRIBUTOR.distributeRewards(address(this), reward);
                emit BeaconChain___RewardsDistributed(validator.pubkey, reward);

                receivers[counter] = validator.pubkey;
                counter++;
            }
        }
    }

    /// @notice Slashes a validator by reducing its balance.
    /// @dev The actual deduction from the validator's balance happens during the sweep process.
    /// @param pubkey The public key of the validator.
    /// @param amount The amount to slash.
    function slash(bytes memory pubkey, uint256 amount) public {
        uint256 index = getValidatorIndex(pubkey);
        require(index < validators.length, "Invalid validator index");

        Validator storage validator = validators[index];
        require(validator.amount >= amount, "Insufficient validator balance to slash");
        require(validator.status == Status.ACTIVE, "Validator must be ACTIVE to be slashed");
        require(
            amount >= validator.amount.mulWad(LibConstant.SLASHING_PENALTY_MULTIPLICATOR),
            "Slashing amount must be greater than minimum penalty"
        );

        // Increase slashed amount, decrease validator amount will be done in sweep
        validator.amount -= amount;

        // Send slashed amount to the slashing reward recipient
        (bool success,) = LibConstant.SLASHING_REWARD_RECIPIENT.call{ value: amount }("");
        require(success, "Slashing transfer failed");

        // Slashed validators are forced to exit
        validator.status = Status.EXITED;
        emit BeaconChain___ValidatorSlashed(pubkey, amount);
        emit BeaconChain___StatusChanged(pubkey, validator.amount, Status.ACTIVE, Status.EXITED);
    }

    /// @notice Returns the protocol fee (not implemented).
    function fee() external pure returns (uint256) { }

    ////////////////////////////////////////////////////
    /// --- SSV FUNCTIONS
    ////////////////////////////////////////////////////

    /// @notice Registers a validator in the SSVNetwork.
    /// @param pubkey The public key of the validator.
    function registerSsvValidator(
        bytes memory pubkey
    ) public {
        require(!ssvRegisteredValidators[pubkey], "Validator already registered");
        require(getValidatorIndex(pubkey) == LibConstant.NOT_FOUND, "Validator already exists in BeaconChain");
        ssvRegisteredValidators[pubkey] = true;

        emit SSVNetwork___ValidatorRegistered(pubkey);
    }

    /// @notice Removes a validator from the SSVNetwork.
    /// @param pubkey The public key of the validator.
    /// @dev Validator must have zero balance and not be withdrawable.
    function removeSsvValidator(
        bytes memory pubkey
    ) public {
        require(ssvRegisteredValidators[pubkey], "Validator not registered");

        uint256 index = getValidatorIndex(pubkey);
        if (index != LibConstant.NOT_FOUND) {
            Validator memory validator = validators[index];

            if (validator.status == Status.DEPOSITED) return; // Cannot remove if still DEPOSITED

            // Force exit if validator is still active
            if (validator.status == Status.ACTIVE) {
                slash(pubkey, LibConstant.SLASHING_PENALTY_MULTIPLICATOR * validator.amount);
            }
        }

        ssvRegisteredValidators[pubkey] = false;
        emit SSVNetwork___ValidatorRemoved(pubkey);
    }

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

    /// @notice Sets the BeaconProofs contract address.
    function setBeaconProofs(
        address _beaconProofs
    ) public {
        beaconProofs = BeaconProofs(_beaconProofs);
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

    /// @notice Returns the index of a validator by public key.
    /// @param pubkey The public key of the validator.
    /// @return The index of the validator, or LibConstant.NOT_FOUND if not found.
    function getValidatorIndex(
        bytes memory pubkey
    ) public view returns (uint256) {
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i].pubkey.eq(pubkey)) return i;
        }
        return LibConstant.NOT_FOUND; // Not found
    }
}
