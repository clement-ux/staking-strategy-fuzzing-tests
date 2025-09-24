// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

library LibConstant {
    //////////////////////////////////////////////////////
    /// --- UINTS
    //////////////////////////////////////////////////////
    // 16
    uint16 public constant MAX_VALIDATORS = 21;
    // 64
    uint64 public constant SLOT_DURATION = 12; // seconds
    uint64 public constant GENESIS_TIMESTAMP = 1_606_824_023;
    // 256
    uint256 public constant NOT_FOUND = ~uint256(0); // type(uint256).max
    uint256 public constant MIN_DEPOSIT = 1 ether;
    uint256 public constant MAX_DEPOSITS = 12;
    uint256 public constant ACTIVATION_AMOUNT = 32.25 ether;
    uint256 public constant SNAP_BALANCES_DELAY = 35 * 12; // ~35 slots, i.e. ~7 minutes
    uint256 public constant MAX_EFFECTIVE_BALANCE = 2048 ether;
    uint256 public constant MAX_VERIFIED_VALIDATORS = 48;
    uint256 public constant FIXED_REWARD_PERCENTAGE = 0.01 ether; // 1% fixed reward for simulation
    uint256 public constant SLASHING_PENALTY_MULTIPLICATOR = 0.00024375 ether;

    //////////////////////////////////////////////////////
    /// --- ADDRESSES
    //////////////////////////////////////////////////////
    address public constant BEACON_ROOTS_ADDRESS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;
    address public constant DEPOSIT_CONTRACT_ADDRESS = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
    address public constant SLASHING_REWARD_RECIPIENT = 0x91a36674f318e82322241CB62f771c90e3B77acb;
    address public constant WITHDRAWAL_REQUEST_ADDRESS = 0x00000961Ef480Eb55e80D19ad83579A64c007002;

    //////////////////////////////////////////////////////
    /// --- BYTES
    //////////////////////////////////////////////////////
    bytes public constant NOT_FOUND_BYTES = abi.encodePacked(NOT_FOUND);
    bytes32 public constant NOT_FOUND_BYTES32 = bytes32(NOT_FOUND);
}
