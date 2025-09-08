// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

contract BeaconChain {
    ////////////////////////////////////////////////////
    /// --- CONSTRANTS & IMMUTABLES
    ////////////////////////////////////////////////////
    uint256 public constant MIN_DEPOSIT = 1 ether;
    uint256 public constant MIN_EXIT_AMOUNT = 16 ether;
    uint256 public constant ACTIVATION_AMOUNT = 32 ether;
    uint256 public constant MAX_EFFECTIVE_BALANCE = 2048 ether;

    // Address where slashing rewards are sent to (generated using pk = uint256(keccak256(abi.encodePacked("name")))).
    // Using a real address instead of zero, to track ETH flow in tests.
    address public constant SLASHING_REWARD_RECIPIENT = address(0x91a36674f318e82322241CB62f771c90e3B77acb);

    ////////////////////////////////////////////////////
    /// --- STRUCTS & ENUM
    ////////////////////////////////////////////////////
    enum ValidatorStatus {
        UNKNOWN, // default value
        DEPOSITED, // ensure 1 eth has been deposited, at this stage validator is not yet active
        ACTIVE, // validator is active and participating in consensus
        EXITED // validator has exited and is no longer participating

    }

    struct Deposit {
        bytes pubkey;
        uint64 timestamp;
        uint256 amount; // in wei
        address owner;
    }

    struct Pending {
        bytes pubkey;
        uint64 timestamp;
        uint256 amount; // in wei
        address owner;
    }

    struct Exiting {
        bytes pubkey;
        uint64 timestamp;
        address owner;
    }

    struct Withdraw {
        bytes pubkey;
        uint64 timestamp;
        uint256 amount; // in wei
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
    Exiting[] public exitQueue;
    Deposit[] public depositQueue;
    Pending[] public pendingQueue;
    Withdraw[] public withdrawQueue;
    Validator[] public activeValidators; // unordered list of active validators

    mapping(bytes pubkey => Validator) public validators;

    ////////////////////////////////////////////////////
    /// --- MUTATIVE FUNCTIONS
    ////////////////////////////////////////////////////
    function deposit(
        bytes calldata pubkey,
        bytes calldata, /*withdrawal_credentials*/
        bytes calldata, /*signature*/
        bytes32 /*deposit_data_root*/
    ) external payable {
        require(msg.value >= MIN_DEPOSIT, "Minimum deposit is 1 ETH");
        depositQueue.push(
            Deposit({ amount: msg.value, pubkey: pubkey, timestamp: uint64(block.timestamp), owner: msg.sender })
        );
    }

    function withdraw(bytes calldata validatorPubKey, uint256 amount) external {
        Validator memory validator = validators[validatorPubKey];
        require(validator.owner == msg.sender, "Only owner can request withdrawal");
        require(validator.amount >= amount, "Insufficient validator balance");

        withdrawQueue.push(Withdraw({ pubkey: validatorPubKey, amount: amount, timestamp: uint64(block.timestamp) }));
    }

    /// @param index The index of the deposit to process, should be always 0 to process in FIFO order, but can be any index
    /// to allow flexibility
    function processDeposit(
        uint16 index
    ) public {
        // Ensure the index is within bounds
        require(index < depositQueue.length, "Invalid deposit index");

        // Store deposit in memory to avoid multiple SLOADs
        Deposit memory pendingDeposit = depositQueue[index];

        // Remove deposit from depositQueue and conserve order, by shifting elements from right to left
        for (uint256 i = index; i < depositQueue.length - 1; i++) {
            depositQueue[i] = depositQueue[i + 1];
        }
        depositQueue.pop(); // Remove the last element (now a duplicate)

        bytes memory pubkey = pendingDeposit.pubkey;
        ValidatorStatus currentStatus = validators[pubkey].status;

        // --- 1. Validator doesn't exist, create it
        if (currentStatus == ValidatorStatus.UNKNOWN) {
            validators[pubkey] = Validator({
                pubkey: pendingDeposit.pubkey,
                amount: 0,
                owner: pendingDeposit.owner,
                status: ValidatorStatus.DEPOSITED
            });

            // Add to pendingQueue
            pendingQueue.push(
                Pending({
                    amount: pendingDeposit.amount,
                    pubkey: pendingDeposit.pubkey,
                    timestamp: pendingDeposit.timestamp,
                    owner: pendingDeposit.owner
                })
            );
        }
        // --- 2. Validator is in DEPOSITED state, increase pending validator amount
        else if (currentStatus == ValidatorStatus.DEPOSITED) {
            // Find the pending validator and increase its amount
            for (uint256 i = 0; i < pendingQueue.length; i++) {
                if (keccak256(pendingQueue[i].pubkey) == keccak256(pubkey)) {
                    pendingQueue[i].amount += pendingDeposit.amount;
                    break;
                }
            }
        }
        // --- 3. Validator exists and is ACTIVE, increase stake
        else if (currentStatus == ValidatorStatus.ACTIVE) {
            validators[pubkey].amount += pendingDeposit.amount;
        }
        // --- 4. Exited validators cannot be reactivated
        else if (currentStatus == ValidatorStatus.EXITED) {
            depositQueue.push(pendingDeposit); // Refund the deposit by re-adding it to pending deposits
        }
    }

    /// @param index The index of the pending validator to activate, should be always 0 to process in FIFO order, but can be
    /// any index to allow flexibility
    function activateValidator(
        uint16 index
    ) public {
        require(index < pendingQueue.length, "Invalid pending validator index");

        // Store pending validator in memory to avoid multiple SLOADs
        Pending memory pendingValidator = pendingQueue[index];
        bytes memory pubkey = pendingValidator.pubkey;

        // Move the pending validator to the end of the array, conserving order
        // We decide after if we will pop or update the last element, based on the amount of ETH in the validator
        for (uint256 i = index; i < pendingQueue.length - 1; i++) {
            pendingQueue[i] = pendingQueue[i + 1];
        }

        // If the pending validator has less than 32 ETH, update the last element and return
        if (validators[pubkey].amount + pendingValidator.amount < ACTIVATION_AMOUNT) {
            pendingQueue[pendingQueue.length - 1] = pendingValidator;
            return;
        } else {
            pendingQueue.pop(); // Remove the last element (now a duplicate)
        }

        // Ensure the validator is in DEPOSITED state
        require(validators[pubkey].status == ValidatorStatus.DEPOSITED, "Validator must be in DEPOSITED state");

        // Update the validator's status and amount
        validators[pubkey].status = ValidatorStatus.ACTIVE;
        validators[pubkey].amount += pendingValidator.amount;

        // Add to activeValidators
        activeValidators.push(
            Validator({
                pubkey: pendingValidator.pubkey,
                amount: validators[pubkey].amount,
                owner: pendingValidator.owner,
                status: ValidatorStatus.ACTIVE
            })
        );
    }

    function processWithdraw(
        uint16 index
    ) public {
        require(index < withdrawQueue.length, "Invalid withdrawal index");

        // Store withdrawal in memory to avoid multiple SLOADs
        Withdraw memory pendingWithdrawal = withdrawQueue[index];

        // Remove withdrawal from withdrawQueue and conserve order, by shifting elements from right to left
        for (uint256 i = index; i < withdrawQueue.length - 1; i++) {
            withdrawQueue[i] = withdrawQueue[i + 1];
        }
        withdrawQueue.pop(); // Remove the last element (now a duplicate)

        bytes memory pubkey = pendingWithdrawal.pubkey;
        Validator storage validator = validators[pubkey];

        // Ensure the validator has enough balance and deduct the amount
        require(validator.amount >= pendingWithdrawal.amount, "Insufficient validator balance");
        validator.amount -= pendingWithdrawal.amount;

        // Transfer ETH to the validator owner
        (bool success,) = validator.owner.call{ value: pendingWithdrawal.amount }("");
        require(success, "Withdrawal transfer failed");

        // If validator amount is less than 16 ETH, move validator to exit queue
        if (validator.amount < ACTIVATION_AMOUNT / 2) {
            validator.status = ValidatorStatus.EXITED;
            exitQueue.push(Exiting({ pubkey: pubkey, timestamp: uint64(block.timestamp), owner: validator.owner }));
        }
    }

    function processExit(
        uint16 index
    ) public {
        require(index < exitQueue.length, "Invalid exit index");

        // Store exiting validator in memory to avoid multiple SLOADs
        Exiting memory exitingValidator = exitQueue[index];

        // Remove exiting validator from exitQueue and conserve order, by shifting elements from right to left
        for (uint256 i = index; i < exitQueue.length - 1; i++) {
            exitQueue[i] = exitQueue[i + 1];
        }
        exitQueue.pop(); // Remove the last element (now a duplicate)

        bytes memory pubkey = exitingValidator.pubkey;
        Validator storage validator = validators[pubkey];

        // Ensure the validator is in EXITED state
        require(validator.status == ValidatorStatus.EXITED, "Validator must be in EXITED state");

        // Remove from activeValidators, not conserving order
        for (uint256 i = 0; i < activeValidators.length; i++) {
            if (keccak256(activeValidators[i].pubkey) == keccak256(pubkey)) {
                // Move the last element to the current index and pop the last element
                activeValidators[i] = activeValidators[activeValidators.length - 1];
                activeValidators.pop();
                break;
            }
        }

        // Finally, remove the validator from the mapping
        delete validators[pubkey];
    }

    /// @notice Get through all active validators and process:
    /// - removed all amount above 2048 ETH, assuming only 0x02 validators
    function processSweep() public {
        for (uint256 i = 0; i < activeValidators.length; i++) {
            Validator storage validator = validators[activeValidators[i].pubkey];
            if (validator.amount > MAX_EFFECTIVE_BALANCE) {
                uint256 excess = validator.amount - MAX_EFFECTIVE_BALANCE;
                validator.amount = MAX_EFFECTIVE_BALANCE;

                // Transfer excess ETH to the validator owner
                (bool success,) = validator.owner.call{ value: excess }("");
                require(success, "Excess transfer failed");
            }
        }
    }

    function slash(uint16 index, uint256 amount) public {
        require(index < activeValidators.length, "Invalid validator index");
        Validator storage validator = activeValidators[index];
        require(validator.amount >= amount, "Insufficient validator balance to slash");
        require(validator.status == ValidatorStatus.ACTIVE, "Validator must be ACTIVE to be slashed");

        // Slash the validator
        validator.amount -= amount;

        // Send ETH to the slashing reward address
        (bool success,) = SLASHING_REWARD_RECIPIENT.call{ value: amount }("");
        require(success, "Slashing transfer failed");

        // If validator amount is less than 16 ETH, move validator to exit queue
        if (validator.amount < ACTIVATION_AMOUNT / 2) {
            validator.status = ValidatorStatus.EXITED;
            exitQueue.push(Exiting({ pubkey: validator.pubkey, timestamp: uint64(block.timestamp), owner: validator.owner }));
        }
    }

    ////////////////////////////////////////////////////
    /// --- VIEW FUNCTIONS
    ////////////////////////////////////////////////////
    function getValidator(
        bytes calldata pubkey
    ) external view returns (Validator memory) {
        return validators[pubkey];
    }

    function getActiveValidators() external view returns (Validator[] memory) {
        return activeValidators;
    }

    function getDepositQueue() external view returns (Deposit[] memory) {
        return depositQueue;
    }

    function getPendingQueue() external view returns (Pending[] memory) {
        return pendingQueue;
    }

    function getWithdrawQueue() external view returns (Withdraw[] memory) {
        return withdrawQueue;
    }

    function getExitQueue() external view returns (Exiting[] memory) {
        return exitQueue;
    }
}
