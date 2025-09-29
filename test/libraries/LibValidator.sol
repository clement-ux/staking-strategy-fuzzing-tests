// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

library LibValidator {
    ////////////////////////////////////////////////////
    /// --- LIBRARY FUNCTIONS
    ////////////////////////////////////////////////////
    /// @notice Create a mock pubkey from an index, and include the index in the pubkey for easy retrieval.
    /// @dev    The pubkey is 48 bytes, we will use the first 2 bytes to store the index, then add bytes21 of 0xff
    ///         then again 2 bytes of index, bytes21 of 0xff and finally 2 bytes of index.
    ///         Example for index 1 (0x0001):
    ///         0x0001ffffffffffffffffffffffffffffffffffffffffff0001ffffffffffffffffffffffffffffffffffffffffff0001
    /// @param index The index of the validator.
    /// @return The mock pubkey.
    function createPubkey(
        uint16 index
    ) external pure returns (bytes memory) {
        return abi.encodePacked(
            bytes2(uint16(index)),
            bytes21(abi.encodePacked(~uint256(0))),
            bytes2(uint16(index)),
            bytes21(abi.encodePacked(~uint256(0))),
            bytes2(uint16(index))
        );
    }

    /// @notice Hash a validator public key using the Beacon Chain's format
    /// @param pubkey The pubkey to hash.
    /// @return The hash of the pubkey.
    function hashPubkey(
        bytes memory pubkey
    ) external pure returns (bytes32) {
        require(pubkey.length == 48, "Invalid public key length");
        return sha256(abi.encodePacked(pubkey, bytes16(0)));
    }

    /// @notice Extract the index from a pubkey created with `createPubkey`.
    /// @param pubkey The pubkey to extract the index from.
    /// @return The index of the validator.
    function getIndexFromPubkey(
        bytes memory pubkey
    ) external pure returns (uint16) {
        // The crop of the bytes into bytes2 is made on purpose, to extract the first 2 bytes.
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint16(bytes2(pubkey));
    }
}
