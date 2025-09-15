// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

contract BeaconRoot {
    fallback(
        bytes calldata
    ) external payable returns (bytes memory) {
        // Atm this is a mock, that just returns a hash of the block timestamp
        // It can not return bytes("") as that would make the calling contract revert
        return bytes(abi.encode(keccak256(abi.encode(block.timestamp))));
    }
}
