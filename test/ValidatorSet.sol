// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { LibBytes } from "@solady/utils/LibBytes.sol";

abstract contract ValidatorSet {
    using LibBytes for bytes;

    // Validator pubkeys for testing, should be exactly 48 bytes long!
    bytes public constant VALIDATOR_1 =
        hex"001fffffffffffffffffffffffffffffffffffffffffff001ffffffffffffffffffffffffffffffffffffffffffff001";
    bytes public constant VALIDATOR_2 =
        hex"002fffffffffffffffffffffffffffffffffffffffffff002ffffffffffffffffffffffffffffffffffffffffffff002";
    bytes public constant VALIDATOR_3 =
        hex"003fffffffffffffffffffffffffffffffffffffffffff003ffffffffffffffffffffffffffffffffffffffffffff003";
    bytes public constant VALIDATOR_4 =
        hex"004fffffffffffffffffffffffffffffffffffffffffff004ffffffffffffffffffffffffffffffffffffffffffff004";
    bytes public constant VALIDATOR_5 =
        hex"005fffffffffffffffffffffffffffffffffffffffffff005ffffffffffffffffffffffffffffffffffffffffffff005";
    bytes public constant VALIDATOR_6 =
        hex"006fffffffffffffffffffffffffffffffffffffffffff006ffffffffffffffffffffffffffffffffffffffffffff006";
    bytes public constant VALIDATOR_7 =
        hex"007fffffffffffffffffffffffffffffffffffffffffff007ffffffffffffffffffffffffffffffffffffffffffff007";
    bytes public constant VALIDATOR_8 =
        hex"008fffffffffffffffffffffffffffffffffffffffffff008ffffffffffffffffffffffffffffffffffffffffffff008";
    bytes public constant VALIDATOR_9 =
        hex"009fffffffffffffffffffffffffffffffffffffffffff009ffffffffffffffffffffffffffffffffffffffffffff009";
    bytes public constant VALIDATOR_10 =
        hex"00afffffffffffffffffffffffffffffffffffffffffff00affffffffffffffffffffffffffffffffffffffffffff00a";
    bytes public constant VALIDATOR_11 =
        hex"00bfffffffffffffffffffffffffffffffffffffffffff00bffffffffffffffffffffffffffffffffffffffffffff00b";
    bytes public constant VALIDATOR_12 =
        hex"00cfffffffffffffffffffffffffffffffffffffffffff00cffffffffffffffffffffffffffffffffffffffffffff00c";
    bytes public constant VALIDATOR_13 =
        hex"00dfffffffffffffffffffffffffffffffffffffffffff00dffffffffffffffffffffffffffffffffffffffffffff00d";
    bytes public constant VALIDATOR_14 =
        hex"00efffffffffffffffffffffffffffffffffffffffffff00effffffffffffffffffffffffffffffffffffffffffff00e";
    // bytes public constant VALIDATOR_15 // has been removed to due to the "f" in the middle.
    bytes public constant VALIDATOR_16 =
        hex"010fffffffffffffffffffffffffffffffffffffffffff010ffffffffffffffffffffffffffffffffffffffffffff010";
    bytes public constant VALIDATOR_17 =
        hex"011fffffffffffffffffffffffffffffffffffffffffff011ffffffffffffffffffffffffffffffffffffffffffff011";
    bytes public constant VALIDATOR_18 =
        hex"012fffffffffffffffffffffffffffffffffffffffffff012ffffffffffffffffffffffffffffffffffffffffffff012";
    bytes public constant VALIDATOR_19 =
        hex"013fffffffffffffffffffffffffffffffffffffffffff013ffffffffffffffffffffffffffffffffffffffffffff013";
    bytes public constant VALIDATOR_20 =
        hex"014fffffffffffffffffffffffffffffffffffffffffff014ffffffffffffffffffffffffffffffffffffffffffff014";
    bytes public constant VALIDATOR_21 =
        hex"015fffffffffffffffffffffffffffffffffffffffffff015ffffffffffffffffffffffffffffffffffffffffffff015";

    bytes[] public validators = [
        VALIDATOR_1,
        VALIDATOR_2,
        VALIDATOR_3,
        VALIDATOR_4,
        VALIDATOR_5,
        VALIDATOR_6,
        VALIDATOR_7,
        VALIDATOR_8,
        VALIDATOR_9,
        VALIDATOR_10,
        VALIDATOR_11,
        VALIDATOR_12,
        VALIDATOR_13,
        VALIDATOR_14,
        VALIDATOR_16,
        VALIDATOR_17,
        VALIDATOR_18,
        VALIDATOR_19,
        VALIDATOR_20,
        VALIDATOR_21
    ];
}
