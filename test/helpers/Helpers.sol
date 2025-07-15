// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

// Test imports
import { Setup } from "test/Setup.sol";

abstract contract Helpers is Setup {
    mapping(bytes32 => uint256) public depositDataRootCount;
    uint256 public validatorCount;

    /// @notice Hash a validator public key using the Beacon Chain's format
    function hashPubKey(
        bytes memory pubKey
    ) public pure returns (bytes32) {
        return sha256(abi.encodePacked(pubKey, bytes16(0)));
    }

    function generateDepositDataRoots(
        bytes memory pubKey
    ) public returns (bytes32) {
        bytes32 depositDataRoot = keccak256(abi.encodePacked(pubKey, depositDataRootCount[hashPubKey(pubKey)]));
        depositDataRootCount[hashPubKey(pubKey)]++;
        return depositDataRoot;
    }

    function getDepositDataRoots(bytes memory pubKey, uint256 index) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(pubKey, index));
    }
}
