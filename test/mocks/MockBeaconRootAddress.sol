// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

contract MockBeaconRootAddress {
    fallback(
        bytes calldata data
    ) external returns (bytes memory) {
        // This is a mock contract, so we can leave it empty or implement a simple fallback
        // to simulate the behavior of the actual BeaconRootAddress contract.
        return data;
    }
}
