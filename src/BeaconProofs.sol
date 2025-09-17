// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Utils
import { LibBytes } from "@solady/utils/LibBytes.sol";

// Contracts
import { BeaconChain } from "./BeaconChain.sol";
import { ValidatorSet } from "./ValidatorSet.sol";

contract BeaconProofs is ValidatorSet {
    using LibBytes for bytes;

    ////////////////////////////////////////////////////
    /// --- STORAGE
    ////////////////////////////////////////////////////
    BeaconChain public beaconChain;

    ////////////////////////////////////////////////////
    /// --- CONSTRUCTOR
    ////////////////////////////////////////////////////
    constructor(
        address _beaconChain
    ) {
        beaconChain = BeaconChain(payable(_beaconChain));
    }

    ////////////////////////////////////////////////////
    /// --- MOCK FUNCTIONS
    ////////////////////////////////////////////////////
    function merkleizePendingDeposit(
        bytes32 pubKeyHash,
        bytes calldata withdrawalCredentials,
        uint64 amountGwei,
        bytes calldata, /*signature*/
        uint64 /*slot*/
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(pubKeyHash, withdrawalCredentials, amountGwei /*, signature, slot*/ ));
    }

    /// @notice Verify that a validator with the given index and withdrawal address corresponds to the given pubKeyHash
    /// For this, we need to:
    /// 1. Ensure the pubkey matches the index, reading from the ValidatorSet.
    /// 2. Ensure the withdrawal address matches the credentials, reading from the deposit queue or the active validators in
    /// the BeaconChain.
    function verifyValidator(
        bytes32, /*beaconBlockRoot*/
        bytes32 pubKeyHash,
        bytes memory, /*proof*/
        uint40 validatorIndex,
        address withdrawalAddress
    ) public view {
        bytes memory pubkey = hashToPubkey[pubKeyHash];

        // First ensure the pubkey matches the index
        require(pubkeyToIndex[pubkey] == validatorIndex, "Beacon Proofs: Invalid validator index");

        // Second, ensure the withdrawal address matches the credentials
        // The deposit can be either in the depositQueue or already deposited
        //1. Browse the deposit queue
        BeaconChain.Queue[] memory depositQueue = beaconChain.getDepositQueue();
        uint256 len = depositQueue.length;
        for (uint256 i = 0; i < len; i++) {
            if (depositQueue[i].pubkey.eq(pubkey)) {
                require(
                    depositQueue[i].owner == withdrawalAddress, "Beacon Proofs: Invalid withdrawal address (deposit queue)"
                );
                return;
            }
        }
        // 2. Browse the active validators
        BeaconChain.Validator[] memory validator = beaconChain.getValidators();
        len = validator.length;
        for (uint256 i = 0; i < len; i++) {
            if (validator[i].pubkey.eq(pubkey)) {
                require(validator[i].owner == withdrawalAddress, "Beacon Proofs: Invalid withdrawal address (active)");
                return;
            }
        }

        revert("Beacon Proofs: Validator not found");
    }

    /// @notice Check if the Deposit Queue is empty
    /// @dev for the sake of simplicity, we assume the deposit queue is always empty. As this is only used in the
    /// `verifyDeposit` function, we return true to bypass the last check, as we are only checking that the deposit as been
    /// processed and this check is performed with `verifyValidatorWithdrawable`.
    function verifyFirstPendingDeposit(
        bytes32, /*beaconBlockRoot*/
        uint64, /*slot*/
        bytes calldata /*firstPendingDepositSlotProof*/
    ) public pure returns (bool) {
        return true;
    }

    /// @notice In theory check if the validator is withdrawable
    /// For the sake of the fuzz test; this will check that the deposit has been processed
    /// @param withdrawableEpochProof is used to pass the unique deposit identifier
    function verifyValidatorWithdrawable(
        bytes32, /*beaconBlockRoot*/
        uint40 validatorIndex,
        uint64, /*withdrawableEpoch*/
        bytes memory withdrawableEpochProof
    ) public view {
        // Find the uinque deposit corresponding to the validator
        // 1. Find the pubkey from the index
        bytes memory pubkey = indexToPubkey[validatorIndex];

        // 2. Convert withdrawableEpochProof to uint256 deposit uid uint256
        uint256 uid = uint256(bytes32(withdrawableEpochProof));

        // 3. Browse the deposit queue to find a deposit with the same pubkey and uid, revert if it find the deposit
        BeaconChain.Queue[] memory depositQueue = beaconChain.getDepositQueue();
        uint256 len = depositQueue.length;
        for (uint256 i = 0; i < len; i++) {
            if (depositQueue[i].pubkey.eq(pubkey)) {
                require(depositQueue[i].uid == uid, "Beacon Proofs: Deposit not yet processed");
            }
        }
    }

    function verifyBalancesContainer(
        bytes32, /*beaconBlockRoot*/
        bytes32, /*balancesContainerRoot*/
        bytes memory /*balancesContainerProof*/
    ) public pure { }

    function verifyValidatorBalance(
        bytes32, /*balancesContainerRoot*/
        uint40, /*validatorIndex*/
        uint64, /*balance*/
        bytes memory /*balanceProof*/
    ) public pure returns (uint256) { }

    function verifyPendingDepositsContainer(
        bytes32, /*beaconBlockRoot*/
        bytes32, /*pendingDepositsContainerRoot*/
        bytes memory /*pendingDepositsContainerProof*/
    ) public pure { }

    function verifyPendingDeposit(
        bytes32, /*pendingDepositsContainerRoot*/
        bytes32, /*pendingDepositLeaf*/
        bytes memory, /*pendingDepositProof*/
        uint64 /*index*/
    ) public pure returns (bool) { }
}
