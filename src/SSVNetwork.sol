// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BeaconChain } from "./BeaconChain.sol";

contract SSVNetwork {
    ////////////////////////////////////////////////////
    /// --- STRUCTS & ENUM
    ////////////////////////////////////////////////////
    struct Cluster {
        uint32 validatorCount;
        uint64 networkFeeIndex;
        uint64 index;
        bool active;
        uint256 balance;
    }

    struct Validator {
        bytes publicKey;
        address owner;
    }

    ////////////////////////////////////////////////////
    /// --- STORAGE
    ////////////////////////////////////////////////////
    BeaconChain public beaconChain;

    ////////////////////////////////////////////////////
    /// --- MUTATIVE FUNCTIONS
    ////////////////////////////////////////////////////
    function registerValidator(
        bytes memory publicKey,
        uint64[] memory, /*a*/
        bytes memory, /*b*/
        uint256, /*c*/
        Cluster memory /*d*/
    ) external {
        beaconChain.registerSsvValidator(publicKey);
    }
}
