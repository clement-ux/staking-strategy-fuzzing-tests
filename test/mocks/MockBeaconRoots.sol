// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

contract MockBeaconRoots {
    function parentBlockRoot(
        uint64 timestamp
    ) external pure returns (bytes32) {
        // Mock implementation for testing purposes
        // Todo: do better
        return keccak256(abi.encodePacked(timestamp));
    }
}
