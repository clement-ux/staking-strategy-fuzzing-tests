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

        require(data.length == 10, "Data must be exactly 10 bytes");

        // Decode msg.data to (bytes, uint64)
        bytes2 pubkey;
        uint64 amount;
        assembly {
            let lastBytes := mload(add(data, 34))
            pubkey := mload(add(data, 32))
            amount := shr(192, lastBytes)
        }
        beaconChain.withdraw(abi.encodePacked(pubkey), amount);

        return "";
    }
}
