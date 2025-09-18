// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Foundry
import { Test } from "@forge-std/Test.sol";

// Contract to test
import { Cluster } from "@origin-dollar/interfaces/ISSVNetwork.sol";
import { CompoundingStakingSSVStrategy } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingSSVStrategy.sol";
import { CompoundingStakingStrategyView } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingView.sol";
import { CompoundingStakingSSVStrategyProxy } from "@origin-dollar/proxies/Proxies.sol";

// Mocks
import { MockWETH } from "../src/mock/MockWETH.sol";
import { MockERC20 } from "../src/mock/MockERC20.sol";
import { SSVNetwork } from "../src/SSVNetwork.sol";
import { BeaconRoot } from "../src/BeaconRoot.sol";
import { BeaconChain } from "../src/BeaconChain.sol";
import { BeaconProofs } from "../src/BeaconProofs.sol";
import { DepositContract } from "../src/DepositContract.sol";
import { RewardDistributor } from "../src/RewardDistributor.sol";
import { PartialWithdrawContract } from "../src/PartialWithdrawContract.sol";

/// @title Base
/// @notice Abstract base contract defining shared state variables and contract instances for the test suite.
/// @dev    This contract serves as the foundation for all test contracts, providing:
///         - Contract instances (tokens, external dependencies)
///         - Address definitions (users, governance, deployers)
///         - No logic or setup should be included here, only state variable declarations
contract Base is Test {
    ////////////////////////////////////////////////////
    /// --- CONSTANTS & IMMUTABLES
    ////////////////////////////////////////////////////
    uint64 public constant GENESIS_TIMESTAMP = 1_606_824_023;
    address public constant BEACON_ROOTS_ADDRESS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;
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

    // Mock
    address public oethVault = makeAddr("oethVault");

    Cluster public emptyCluster = Cluster(0, 0, 0, false, 0);

    ////////////////////////////////////////////////////
    /// --- CONTRACTS & MOCKS
    ////////////////////////////////////////////////////
    // Contracts
    CompoundingStakingSSVStrategy public strategy;
    CompoundingStakingStrategyView public strategyView;
    CompoundingStakingSSVStrategyProxy public strategyProxy;

    // Mocks
    MockWETH public weth;
    MockERC20 public ssv;
    SSVNetwork public ssvNetwork;
    BeaconRoot public beaconRoot;
    BeaconChain public beaconChain;
    BeaconProofs public beaconProofs;
    DepositContract public depositContract;
    RewardDistributor public rewardDistributor;
    PartialWithdrawContract public partialWithdrawContract;
}
