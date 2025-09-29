// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Utils
import { LibBytes } from "@solady/utils/LibBytes.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";
import { LibValidator } from "../test/libraries/LibValidator.sol";

// Contracts
import { BeaconChain } from "./BeaconChain.sol";

contract BeaconProofs {
    using LibBytes for bytes;
    using SafeCastLib for uint40;
    using SafeCastLib for uint256;
    using LibValidator for bytes;
    using LibValidator for uint16;

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
        bytes calldata signature,
        uint64 slot
    ) public pure returns (bytes32) {
        slot; // to silence solc warning about unused variable
        // forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encodePacked(pubKeyHash, withdrawalCredentials, amountGwei, signature));
    }

    /// @notice Verify that a validator with the given index and withdrawal address corresponds to the given pubKeyHash
    /// Ensure the withdrawal address matches the credentials, reading from the deposit queue or the active validators in
    /// the BeaconChain.
    function verifyValidator(
        bytes32,
        bytes32,
        bytes memory,
        uint40 validatorIndex,
        bytes32 withdrawalCredentials
    ) public view {
        bytes memory pubkey = validatorIndex.toUint16().createPubkey();

        // Ensure the withdrawal address matches the credentials
        // Browse the active validators
        BeaconChain.Validator[] memory validator = beaconChain.getValidators();
        uint256 len = validator.length;
        for (uint256 i = 0; i < len; i++) {
            if (validator[i].pubkey.eq(pubkey)) {
                require(
                    bytes32(abi.encodePacked(bytes1(0x02), bytes11(0), validator[i].owner)) == withdrawalCredentials,
                    "Beacon Proofs: Invalid withdrawal address (active)"
                );
                return;
            }
        }

        revert("Beacon Proofs: Validator not found");
    }

    /// @notice Check if the Deposit Queue is empty
    /// @dev for the sake of simplicity, we assume the deposit queue is always empty. As this is only used in the
    /// `verifyDeposit` function, we return true to bypass the last check, as we are only checking that the deposit as been
    /// processed and this check is performed with `verifyValidatorWithdrawable`.
    function verifyFirstPendingDeposit(bytes32, uint64, bytes calldata) public pure returns (bool) {
        return true;
    }

    /// @notice In theory check if the validator is withdrawable
    /// For the sake of the fuzz test; this will check that the deposit has been processed
    /// @param withdrawableEpochProof is used to pass the unique deposit identifier
    function verifyValidatorWithdrawable(bytes32, uint40, uint64, bytes memory withdrawableEpochProof) public view {
        // 1. Convert withdrawableEpochProof to bytes32 deposit udid
        require(withdrawableEpochProof.length == 32, "Beacon Proofs: Invalid withdrawableEpochProof length");
        // forge-lint: disable-next-line(unsafe-typecast)
        bytes32 udid = bytes32(withdrawableEpochProof);

        // 2. Check that the deposit has been processed
        require(
            beaconChain.processedDeposits(udid) == BeaconChain.DepositStatus.PROCESSED,
            "Beacon Proofs: Deposit not yet processed or doesn't exist"
        );
    }

    /// @notice As this is just a call to this function, we do not need to verify anything
    function verifyBalancesContainer(bytes32, bytes32, bytes memory) public pure { }

    /// @notice Get the balance of the validator from the BeaconChain contract
    function verifyValidatorBalance(bytes32, bytes32, bytes calldata, uint40 validatorIndex) public view returns (uint256) {
        // Get the validator pubkey from the index
        bytes memory pubkey = validatorIndex.toUint16().createPubkey();

        // Get validator index in the `validators` array of the BeaconChain
        //uint256 validatorArrayIndex = beaconChain.getValidatorIndex(pubkey);

        // Get the validator from the BeaconChain
        //BeaconChain.Validator memory validator = beaconChain.getValidator(validatorArrayIndex);

        // Get the balance from the validator
        //uint256 balance = validator.amount;

        uint256 balance = beaconChain.lastSnap(pubkey);

        // Return the balance in gwei
        return balance / 1 gwei;
    }

    /// @notice As this is just a call to this function, we do not need to verify anything
    function verifyPendingDepositsContainer(bytes32, bytes32, bytes memory) public pure { }

    /// @notice Check that the pending deposit is still pending
    function verifyPendingDeposit(bytes32, bytes32 pendingDepositRoot, bytes calldata, uint32) public view {
        require(
            beaconChain.processedDeposits(pendingDepositRoot) == BeaconChain.DepositStatus.PENDING,
            "Beacon Proofs: Deposit already processed"
        );
    }
}
