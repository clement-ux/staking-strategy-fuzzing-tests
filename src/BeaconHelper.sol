// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Contracts
import { BeaconChain } from "./BeaconChain.sol";

contract BeaconHelper {
    ////////////////////////////////////////////////////
    /// --- CONSTANTS & IMMUTABLES
    ////////////////////////////////////////////////////
    uint256 public constant NOT_FOUND = type(uint256).max;

    ////////////////////////////////////////////////////
    /// --- STORAGE
    ////////////////////////////////////////////////////
    BeaconChain public beaconChain;

    BeaconChain.Validator public notFoundValidator =
        BeaconChain.Validator(abi.encodePacked(NOT_FOUND), address(0), 0, BeaconChain.Status.UNKNOWN);

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
