// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Utils
import { LibBytes } from "@solady/utils/LibBytes.sol";

contract ValidatorSet {
    using LibBytes for bytes;

    ////////////////////////////////////////////////////
    /// --- STRUCTS & ENUMS
    ////////////////////////////////////////////////////
    struct Validator {
        uint40 index;
        bytes pubkey; // 48 bytes
    }

    ////////////////////////////////////////////////////
    /// --- STORAGE
    ////////////////////////////////////////////////////
    Validator public validator1 =
        Validator(1, hex"001fffffffffffffffffffffffffffffffffffffffffff001ffffffffffffffffffffffffffffffffffffffffffff001");
    Validator public validator2 =
        Validator(2, hex"002fffffffffffffffffffffffffffffffffffffffffff002ffffffffffffffffffffffffffffffffffffffffffff002");
    Validator public validator3 =
        Validator(3, hex"003fffffffffffffffffffffffffffffffffffffffffff003ffffffffffffffffffffffffffffffffffffffffffff003");
    Validator public validator4 =
        Validator(4, hex"004fffffffffffffffffffffffffffffffffffffffffff004ffffffffffffffffffffffffffffffffffffffffffff004");
    Validator public validator5 =
        Validator(5, hex"005fffffffffffffffffffffffffffffffffffffffffff005ffffffffffffffffffffffffffffffffffffffffffff005");
    Validator public validator6 =
        Validator(6, hex"006fffffffffffffffffffffffffffffffffffffffffff006ffffffffffffffffffffffffffffffffffffffffffff006");
    Validator public validator7 =
        Validator(7, hex"007fffffffffffffffffffffffffffffffffffffffffff007ffffffffffffffffffffffffffffffffffffffffffff007");
    Validator public validator8 =
        Validator(8, hex"008fffffffffffffffffffffffffffffffffffffffffff008ffffffffffffffffffffffffffffffffffffffffffff008");
    Validator public validator9 =
        Validator(9, hex"009fffffffffffffffffffffffffffffffffffffffffff009ffffffffffffffffffffffffffffffffffffffffffff009");
    Validator public validator10 =
        Validator(10, hex"00afffffffffffffffffffffffffffffffffffffffffff00afffffffffffffffffffffffffffffffffffffffffff00af");
    Validator public validator11 =
        Validator(11, hex"00bfffffffffffffffffffffffffffffffffffffffffff00bffffffffffffffffffffffffffffffffffffffffffff00b");
    Validator public validator12 =
        Validator(12, hex"00cfffffffffffffffffffffffffffffffffffffffffff00cffffffffffffffffffffffffffffffffffffffffffff00c");
    Validator public validator13 =
        Validator(13, hex"00dfffffffffffffffffffffffffffffffffffffffffff00dffffffffffffffffffffffffffffffffffffffffffff00d");
    Validator public validator14 =
        Validator(14, hex"00efffffffffffffffffffffffffffffffffffffffffff00efffffffffffffffffffffffffffffffffffffffffff00ef");
    // Validator public validator15 ; // has been removed to due to the "f" in the middle.
    Validator public validator16 =
        Validator(16, hex"010fffffffffffffffffffffffffffffffffffffffffff010ffffffffffffffffffffffffffffffffffffffffffff010");
    Validator public validator17 =
        Validator(17, hex"011fffffffffffffffffffffffffffffffffffffffffff011ffffffffffffffffffffffffffffffffffffffffffff011");
    Validator public validator18 =
        Validator(18, hex"012fffffffffffffffffffffffffffffffffffffffffff012ffffffffffffffffffffffffffffffffffffffffffff012");
    Validator public validator19 =
        Validator(19, hex"013fffffffffffffffffffffffffffffffffffffffffff013ffffffffffffffffffffffffffffffffffffffffffff013");
    Validator public validator20 =
        Validator(20, hex"014fffffffffffffffffffffffffffffffffffffffffff014ffffffffffffffffffffffffffffffffffffffffffff014");
    Validator public validator21 =
        Validator(21, hex"015fffffffffffffffffffffffffffffffffffffffffff015ffffffffffffffffffffffffffffffffffffffffffff015");

    Validator[] public validators;

    mapping(bytes pubkey => uint40 index) public pubkeyToIndex;
    mapping(bytes pubkey => bytes32) public pubkeyToHash;
    mapping(bytes32 pubkeyHash => bytes pubkey) public hashToPubkey;

    ////////////////////////////////////////////////////
    /// --- CONSTRUCTOR
    ////////////////////////////////////////////////////
    constructor() {
        validators.push(validator1);
        validators.push(validator2);
        validators.push(validator3);
        validators.push(validator4);
        validators.push(validator5);
        validators.push(validator6);
        validators.push(validator7);
        validators.push(validator8);
        validators.push(validator9);
        validators.push(validator10);
        validators.push(validator11);
        validators.push(validator12);
        validators.push(validator13);
        validators.push(validator14);
        // validators.push(validator15);
        validators.push(validator16);
        validators.push(validator17);
        validators.push(validator18);
        validators.push(validator19);
        validators.push(validator20);
        validators.push(validator21);

        for (uint256 i = 0; i < validators.length; i++) {
            pubkeyToIndex[validators[i].pubkey] = validators[i].index;

            bytes32 pubKeyHash = hashPubKey(validators[i].pubkey);
            pubkeyToHash[validators[i].pubkey] = pubKeyHash;
            hashToPubkey[pubKeyHash] = validators[i].pubkey;
        }
    }

    ////////////////////////////////////////////////////
    /// --- HELPERS
    ////////////////////////////////////////////////////
    /// @notice Hash a validator public key using the Beacon Chain's format
    function hashPubKey(
        bytes memory pubKey
    ) public pure returns (bytes32) {
        require(pubKey.length == 48, "Invalid public key length");
        return sha256(abi.encodePacked(pubKey, bytes16(0)));
    }
}
