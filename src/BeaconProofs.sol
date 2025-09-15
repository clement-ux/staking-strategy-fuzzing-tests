// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BeaconChain } from "./BeaconChain.sol";

contract BeaconProofs {
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
        bytes memory, /*pubkey*/
        bytes memory, /*withdrawalCredentials*/
        bytes memory, /*signature*/
        uint64 /*amount*/
    ) public pure returns (bytes32) { }

    function verifyValidator(
        bytes32, /*beaconBlockRoot*/
        bytes32, /*pubKeyHash*/
        bytes memory, /*proof*/
        uint40, /*validatorIndex*/
        address /*withdrawalAddress*/
    ) public pure { }

    function verifyFirstPendingDeposit(
        bytes32, /*beaconBlockRoot*/
        bytes32, /*pendingDepositRoot*/
        bytes memory /*pendingDepositProof*/
    ) public pure returns (bool) { }

    function verifyValidatorWithdrawable(
        bytes32, /*beaconBlockRoot*/
        uint40, /*validatorIndex*/
        uint64, /*withdrawableEpoch*/
        bytes memory /*withdrawableEpochProof*/
    ) public pure { }

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
