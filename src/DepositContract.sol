// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BeaconChain } from "./BeaconChain.sol";

contract DepositContract {
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
    /// --- MUTATIVE FUNCTIONS
    ////////////////////////////////////////////////////
    receive() external payable { }

    function deposit(
        bytes memory pubkey,
        bytes memory withdrawalCredentials,
        bytes memory signature,
        bytes32 depositDataRoot
    ) external payable {
        beaconChain.deposit{ value: msg.value }(pubkey, withdrawalCredentials, signature, depositDataRoot);
    }
}
