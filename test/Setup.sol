// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Base
import { Base } from "./Base.sol";

// Contract to test
import { InitializableAbstractStrategy } from "@origin-dollar/utils/InitializableAbstractStrategy.sol";
import { CompoundingStakingSSVStrategy } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingSSVStrategy.sol";
import { CompoundingStakingSSVStrategyProxy } from "@origin-dollar/proxies/Proxies.sol";

// Mocks
import { WETH } from "@solmate/tokens/WETH.sol";
import { SSVNetwork } from "../src/SSVNetwork.sol";
import { BeaconChain } from "../src/BeaconChain.sol";
import { BeaconProofs } from "../src/BeaconProofs.sol";
import { DepositContract } from "../src/DepositContract.sol";
import { PartialWithdrawContract } from "../src/PartialWithdrawContract.sol";

contract Setup is Base {
    ////////////////////////////////////////////////////
    /// --- SETUP
    ////////////////////////////////////////////////////
    function setUp() public virtual {
        // 1. Setup a realistic test environment
        _setUpRealisticEnvironment();

        // 2. Create user
        _createUsers();

        // To increase performance, we will not use fork., mocking contract instead.
        // 3. Deploy mocks.
        _deployMocks();

        // 4. Deploy contracts.
        _deployContracts();

        // 5. Initialize users and contracts.
        //_initiliaze();
        beaconChain.registerSsvValidator(validator1);
        beaconChain.registerSsvValidator(validator2);
        beaconChain.registerSsvValidator(validator3);
        beaconChain.registerSsvValidator(validator4);
        beaconChain.registerSsvValidator(validator5);
    }

    //////////////////////////////////////////////////////
    /// --- ENVIRONMENT
    //////////////////////////////////////////////////////
    function _setUpRealisticEnvironment() private {
        vm.warp(1_760_000_000);
        vm.roll(24_000_000);
    }

    //////////////////////////////////////////////////////
    /// --- USERS
    //////////////////////////////////////////////////////
    function _createUsers() private {
        deal(address(alice), 1_000_000 ether);
        deal(address(bobby), 1_000_000 ether);
    }

    //////////////////////////////////////////////////////
    /// --- MOCKS
    //////////////////////////////////////////////////////
    function _deployMocks() private {
        // First deploy BeaconChain contract
        beaconChain = new BeaconChain();

        // Then deploy BeaconProofs contract
        beaconProofs = new BeaconProofs(address(beaconChain));

        // Deploy DepositContract and PartialWithdrawContract to their respective addresses on mainnet
        deployCodeTo("DepositContract.sol", abi.encode(address(beaconChain)), DEPOSIT_CONTRACT_ADDRESS);
        deployCodeTo("PartialWithdrawContract.sol", abi.encode(address(beaconChain)), WITHDRAWAL_REQUEST_ADDRESS);
        depositContract = DepositContract(payable(DEPOSIT_CONTRACT_ADDRESS));
        partialWithdrawContract = PartialWithdrawContract(payable(WITHDRAWAL_REQUEST_ADDRESS));

        // Then deploy SSVNetwork contract
        ssvNetwork = new SSVNetwork(address(beaconChain));

        // Fetch RewardDistributor contract from BeaconChain and fund it heavily
        rewardDistributor = beaconChain.REWARD_DISTRIBUTOR();
        deal(address(beaconChain.REWARD_DISTRIBUTOR()), 1_000_000 ether);

        // Deploy WETH mock
        weth = new WETH();
    }

    //////////////////////////////////////////////////////
    /// --- CONTRACTS
    //////////////////////////////////////////////////////
    function _deployContracts() private {
        vm.startPrank(deployer);

        // ---
        // --- 1. Deploy all proxies. ---
        strategyProxy = new CompoundingStakingSSVStrategyProxy();

        // ---
        // --- 2. Deploy all logic contracts. ---
        strategy = new CompoundingStakingSSVStrategy(
            InitializableAbstractStrategy.BaseStrategyConfig(address(0), oethVault),
            address(weth),
            address(ssv),
            address(ssvNetwork),
            address(depositContract),
            address(beaconProofs),
            GENESIS_TIMESTAMP
        );
    }
}
