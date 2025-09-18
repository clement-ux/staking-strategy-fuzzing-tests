// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BeaconChain } from "./BeaconChain.sol";

contract DepositContract {
    ////////////////////////////////////////////////////
    /// --- STORAGE
    ////////////////////////////////////////////////////
    BeaconChain public beaconChain;

    /// @notice Unique counter for deposits, starting at 100 to avoid confusion with 0
    uint256 public uniqueDepositId = 100;

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
        uniqueDepositId++;
        beaconChain.deposit{ value: msg.value }(pubkey, withdrawalCredentials, signature, depositDataRoot);
    }
}
