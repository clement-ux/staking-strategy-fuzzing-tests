// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

contract BeaconChain {
    ////////////////////////////////////////////////////
    /// --- STRUCTS & ENUM
    ////////////////////////////////////////////////////
    enum ValidatorStatus {
        UNKNOWN, // default value
        DEPOSITED, // ensure 1 eth has been deposited, at this stage validator is not yet active
        ACTIVE, // validator is active and participating in consensus
        EXITED, // validator has exited and is no longer participating
        SLASHED // validator has been penalized for misbehavior

    }

    struct Deposit {
        bytes pubkey;
        uint64 amount; // in Gwei
        uint64 timestamp;
        address owner;
    }

    struct Pending {
        bytes pubkey;
        uint64 amount; // in Gwei
        uint64 timestamp;
        address owner;
    }

    struct Validator {
        bytes pubkey;
        uint64 amount; // in Gwei
        address owner;
        ValidatorStatus status;
    }

    ////////////////////////////////////////////////////
    /// --- STORAGE
    ////////////////////////////////////////////////////
    Deposit[] public pendingDeposits;
    Pending[] public pendingValidators;
    Validator[] public activeValidators;

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
        pendingDeposits.push(
            Deposit({ amount: uint64(msg.value), pubkey: pubkey, timestamp: uint64(block.timestamp), owner: msg.sender })
        );
    }

    /// @param index The index of the deposit to process, should be always 0 to process in FIFO order, but can be any index
    /// to allow flexibility
    function processDeposit(
        uint8 index
    ) public {
        // Ensure the index is within bounds
        require(index < pendingDeposits.length, "Invalid deposit index");

        // Store deposit in memory to avoid multiple SLOADs
        Deposit memory pendingDeposit = pendingDeposits[index];

        // Remove deposit from pendingDeposits and conserve order, by shifting elements from right to left
        for (uint256 i = index; i < pendingDeposits.length - 1; i++) {
            pendingDeposits[i] = pendingDeposits[i + 1];
        }
        pendingDeposits.pop(); // Remove the last element (now a duplicate)

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

            // Add to pendingValidators
            pendingValidators.push(
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
            for (uint256 i = 0; i < pendingValidators.length; i++) {
                if (keccak256(pendingValidators[i].pubkey) == keccak256(pubkey)) {
                    pendingValidators[i].amount += pendingDeposit.amount;
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
            revert("Validator has exited");
        }
    }

    /// @param index The index of the pending validator to activate, should be always 0 to process in FIFO order, but can be
    /// any index to allow flexibility
    function activateValidator(
        uint8 index
    ) public {
        require(index < pendingValidators.length, "Invalid pending validator index");

        // Store pending validator in memory to avoid multiple SLOADs
        Pending memory pendingValidator = pendingValidators[index];

        // Ensure the pending validator has at least 32 ETH
        require(pendingValidator.amount >= 32 ether, "Insufficient stake to activate");

        // Remove pending validator from pendingValidators and conserve order, by shifting elements from right to left
        for (uint256 i = index; i < pendingValidators.length - 1; i++) {
            pendingValidators[i] = pendingValidators[i + 1];
        }
        pendingValidators.pop(); // Remove the last element (now a duplicate)

        bytes memory pubkey = pendingValidator.pubkey;

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

    ////////////////////////////////////////////////////
    /// --- VIEW FUNCTIONS
    ////////////////////////////////////////////////////
}
