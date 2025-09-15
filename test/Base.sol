// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Foundry
import { Test } from "@forge-std/Test.sol";

// Contract to test
import { CompoundingStakingSSVStrategy } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingSSVStrategy.sol";
import { CompoundingStakingSSVStrategyProxy } from "@origin-dollar/proxies/Proxies.sol";

// Mocks
import { WETH } from "@solmate/tokens/WETH.sol";
import { SSVNetwork } from "../src/SSVNetwork.sol";
import { BeaconChain } from "../src/BeaconChain.sol";
import { DepositContract } from "../src/DepositContract.sol";
import { RewardDistributor } from "../src/RewardDistributor.sol";
import { PartialWithdrawContract } from "../src/PartialWithdrawContract.sol";

contract Base is Test {
    ////////////////////////////////////////////////////
    /// --- CONSTANTS & IMMUTABLES
    ////////////////////////////////////////////////////
    uint64 public constant GENESIS_TIMESTAMP = 1_606_824_023;
    address public constant DEPOSIT_CONTRACT_ADDRESS = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
    address public constant WITHDRAWAL_REQUEST_ADDRESS = 0x00000961Ef480Eb55e80D19ad83579A64c007002;

    ////////////////////////////////////////////////////
    /// --- STORAGE VARIABLES
    ////////////////////////////////////////////////////
    // Users
    address public alice = makeAddr("alice");
    address public bobby = makeAddr("bobby");
    address public deployer = makeAddr("deployer");
    address public governor = makeAddr("governor");
    address public operator = makeAddr("operator");

    // Validator pubkeys for testing, should be exactly 2 bytes long!
    bytes public validator1 = hex"0001";
    bytes public validator2 = hex"0002";
    bytes public validator3 = hex"0003";
    bytes public validator4 = hex"0004";
    bytes public validator5 = hex"0005";

    // Mock
    address public ssv = makeAddr("ssv");
    address public oethVault = makeAddr("oethVault");
    address public beaconProofs = makeAddr("beaconProofs"); // Todo

    ////////////////////////////////////////////////////
    /// --- CONTRACTS & MOCKS
    ////////////////////////////////////////////////////
    // Contracts
    CompoundingStakingSSVStrategy public strategy;
    CompoundingStakingSSVStrategyProxy public strategyProxy;

    // Mocks
    WETH public weth;
    SSVNetwork public ssvNetwork;
    BeaconChain public beaconChain;
    DepositContract public depositContract;
    RewardDistributor public rewardDistributor;
    PartialWithdrawContract public partialWithdrawContract;
}
