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
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { MockERC20 } from "@solmate/test/utils/mocks/MockERC20.sol";
import { SSVNetwork } from "../src/SSVNetwork.sol";
import { BeaconRoot } from "../src/BeaconRoot.sol";
import { BeaconChain } from "../src/BeaconChain.sol";
import { BeaconProofs } from "../src/BeaconProofs.sol";
import { DepositContract } from "../src/DepositContract.sol";
import { PartialWithdrawContract } from "../src/PartialWithdrawContract.sol";

// Utils
import { ValidatorSet } from "../src/ValidatorSet.sol";

contract Setup is Base, ValidatorSet {
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
        _initiliaze();

        // 6. Label addresses for clarity in traces.
        _labelAddresses();
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
        deployCodeTo("BeaconRoot.sol", abi.encode(), BEACON_ROOTS_ADDRESS);
        deployCodeTo("DepositContract.sol", abi.encode(address(beaconChain)), DEPOSIT_CONTRACT_ADDRESS);
        deployCodeTo("PartialWithdrawContract.sol", abi.encode(address(beaconChain)), WITHDRAWAL_REQUEST_ADDRESS);
        beaconRoot = BeaconRoot(payable(BEACON_ROOTS_ADDRESS));
        depositContract = DepositContract(payable(DEPOSIT_CONTRACT_ADDRESS));
        partialWithdrawContract = PartialWithdrawContract(payable(WITHDRAWAL_REQUEST_ADDRESS));

        // Then deploy SSVNetwork contract
        ssvNetwork = new SSVNetwork(address(beaconChain));

        // Fetch RewardDistributor contract from BeaconChain and fund it heavily
        rewardDistributor = beaconChain.REWARD_DISTRIBUTOR();
        deal(address(beaconChain.REWARD_DISTRIBUTOR()), 1_000_000 ether);

        // Deploy WETH and SSV token
        ssv = ERC20(address(new MockERC20("SSV Token", "SSV", 18)));
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

        // ---
        // --- 3. Initialize proxy.
        strategyProxy.initialize(
            address(strategy),
            address(governor),
            abi.encodeWithSelector(
                CompoundingStakingSSVStrategy.initialize.selector,
                new address[](0), // _rewardTokenAddresses Not used so empty array
                new address[](0), // _assets Not used so empty array
                new address[](0) // _pTokens Not used so empty array
            )
        );

        // Set logic contract on proxy
        strategy = CompoundingStakingSSVStrategy(payable(address(strategyProxy)));

        vm.stopPrank();
    }

    //////////////////////////////////////////////////////
    /// --- INITIALIZATION
    //////////////////////////////////////////////////////
    function _initiliaze() private {
        vm.prank(governor);
        strategy.setRegistrator(operator);

        deal(address(weth), 1_000_000 ether);
    }

    //////////////////////////////////////////////////////
    /// --- LABELS
    //////////////////////////////////////////////////////
    function _labelAddresses() private {
        // Strategy
        vm.label(address(strategy), "CompoundingStakingSSVStrategy");
        vm.label(address(strategyProxy), "CompoundingStakingSSVStrategy Proxy");

        // Mocks
        vm.label(address(beaconRoot), "BeaconRoot");
        vm.label(address(beaconChain), "BeaconChain");
        vm.label(address(beaconProofs), "BeaconProofs");
        vm.label(address(depositContract), "Beacon_DepositContract");
        vm.label(address(partialWithdrawContract), "Beacon_PartialWithdrawContract");
        vm.label(address(ssvNetwork), "SSVNetwork");
        vm.label(address(rewardDistributor), "RewardDistributor");

        // Tokens
        vm.label(address(weth), "WETH");
        vm.label(address(ssv), "SSV Token");
        vm.label(address(oethVault), "OETH Vault");
    }
}
