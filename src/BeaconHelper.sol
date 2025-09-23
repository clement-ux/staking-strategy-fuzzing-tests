// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Contracts
import { BeaconChain } from "./BeaconChain.sol";

// Helpers
import { LibConstant } from "../test/libraries/LibConstant.sol";

contract BeaconHelper {
    ////////////////////////////////////////////////////
    /// --- STORAGE
    ////////////////////////////////////////////////////
    BeaconChain public beaconChain;

    BeaconChain.Validator public notFoundValidator =
        BeaconChain.Validator(LibConstant.NOT_FOUND_BYTES, address(0), 0, BeaconChain.Status.UNKNOWN);

    ////////////////////////////////////////////////////
    /// --- CONSTRUCTOR
    ////////////////////////////////////////////////////
    constructor(
        address _beaconChain
    ) {
        beaconChain = BeaconChain(payable(_beaconChain));
    }

    ////////////////////////////////////////////////////
    /// --- HELPER FUNCTIONS
    ////////////////////////////////////////////////////
    function countValidatorWithStatus(
        BeaconChain.Status status
    ) public view returns (uint256 count) {
        BeaconChain.Validator[] memory validators = beaconChain.getValidators();
        uint256 len = validators.length;
        for (uint256 i = 0; i < len; i++) {
            if (validators[i].status == status) count++;
        }
    }

    function findValidatorWithStatus(
        BeaconChain.Status status,
        uint8 index
    ) public view returns (BeaconChain.Validator memory) {
        BeaconChain.Validator[] memory validators = beaconChain.getValidators();
        uint256 len = validators.length;
        for (uint256 i = index; i < len + index; i++) {
            if (validators[i % len].status == status) return validators[i % len];
        }

        return notFoundValidator;
    }
}
