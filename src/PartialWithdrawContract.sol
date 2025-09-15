// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { BeaconChain } from "./BeaconChain.sol";

contract PartialWithdrawContract {
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
    fallback(
        bytes calldata
    ) external payable returns (bytes memory) {
        bytes memory data = msg.data;

        if (data.length == 0) return abi.encode(beaconChain.fee());

        uint8 validatorPubKeyLength = 48;
        // 48 bytes pubkey + 8 bytes amount
        require(data.length == (validatorPubKeyLength + 8), "Data must be exactly 56 bytes");

        // Decode msg.data to (bytes, uint64)
        bytes memory pubkey = new bytes(validatorPubKeyLength);
        uint64 amount;
        assembly {
            // Copy the bytes
            let src := add(data, 32)
            let dest := add(pubkey, 32)

            // Copy the data in 32-byte words
            let words := div(add(validatorPubKeyLength, 31), 32)
            for { let i := 0 } lt(i, words) { i := add(i, 1) } { mstore(add(dest, mul(i, 32)), mload(add(src, mul(i, 32)))) }

            // Extract the uint64 from position validatorPubKeyLength
            let uint64Position := add(add(data, 32), validatorPubKeyLength)
            let uint64Word := mload(uint64Position)
            // Shift to align the 8 bytes of the uint64
            let shift := mul(sub(32, 8), 8) // 192 bits
            amount := shr(shift, uint64Word)
        }

        beaconChain.withdraw(pubkey, amount);
        return "";
    }
}
