// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

abstract contract ValidatorSet {
    // Validator pubkeys for testing, should be exactly 2 bytes long!
    bytes public constant VALIDATOR_1 = hex"0001";
    bytes public constant VALIDATOR_2 = hex"0002";
    bytes public constant VALIDATOR_3 = hex"0003";
    bytes public constant VALIDATOR_4 = hex"0004";
    bytes public constant VALIDATOR_5 = hex"0005";
    bytes public constant VALIDATOR_6 = hex"0006";
    bytes public constant VALIDATOR_7 = hex"0007";
    bytes public constant VALIDATOR_8 = hex"0008";
    bytes public constant VALIDATOR_9 = hex"0009";
    bytes public constant VALIDATOR_10 = hex"000a";
    bytes public constant VALIDATOR_11 = hex"000b";
    bytes public constant VALIDATOR_12 = hex"000c";
    bytes public constant VALIDATOR_13 = hex"000d";
    bytes public constant VALIDATOR_14 = hex"000e";
    bytes public constant VALIDATOR_15 = hex"000f";
    bytes public constant VALIDATOR_16 = hex"0010";
    bytes public constant VALIDATOR_17 = hex"0011";
    bytes public constant VALIDATOR_18 = hex"0012";
    bytes public constant VALIDATOR_19 = hex"0013";
    bytes public constant VALIDATOR_20 = hex"0014";

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
        VALIDATOR_15,
        VALIDATOR_16,
        VALIDATOR_17,
        VALIDATOR_18,
        VALIDATOR_19,
        VALIDATOR_20
    ];
}
