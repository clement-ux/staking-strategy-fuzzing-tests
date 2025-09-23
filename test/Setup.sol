// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Base
import { Base } from "./Base.sol";

// Contract to test
import { InitializableAbstractStrategy } from "@origin-dollar/utils/InitializableAbstractStrategy.sol";
import { CompoundingStakingSSVStrategy } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingSSVStrategy.sol";
import { CompoundingStakingStrategyView } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingView.sol";
import { CompoundingStakingSSVStrategyProxy } from "@origin-dollar/proxies/Proxies.sol";

// Mocks
import { MockWETH } from "../src/mock/MockWETH.sol";
import { MockERC20 } from "../src/mock/MockERC20.sol";
import { SSVNetwork } from "../src/SSVNetwork.sol";
import { BeaconRoot } from "../src/BeaconRoot.sol";
import { BeaconChain } from "../src/BeaconChain.sol";
import { BeaconHelper } from "../src/BeaconHelper.sol";
import { BeaconProofs } from "../src/BeaconProofs.sol";
import { DepositContract } from "../src/DepositContract.sol";
import { PartialWithdrawContract } from "../src/PartialWithdrawContract.sol";

// Utils
import { LibConstant } from "./libraries/LibConstant.sol";
import { LibValidator } from "./libraries/LibValidator.sol";

/// @title Setup
/// @notice Abstract contract responsible for test environment initialization and contract deployment.
/// @dev    This contract orchestrates the complete test setup process in a structured manner:
///         1. Environment configuration (block timestamp, number)
///         2. User address generation and role assignment
///         3. External contract deployment (mocks, dependencies)
///         4. Main contract deployment
///         5. System initialization and configuration
///         6. Address labeling for improved traceability
///         No test logic should be implemented here, only setup procedures.
contract Setup is Base {
    using LibValidator for bytes;
    using LibValidator for uint16;

    ////////////////////////////////////////////////////
    /// --- SETUP
    ////////////////////////////////////////////////////
    function setUp() public virtual {
        // 1. Setup a realistic test environment
        _setUpRealisticEnvironment();

        // 2. Create user
        _createUsersAndValidators();

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
    function _createUsersAndValidators() private {
        // Fund users
        deal(address(alice), 1_000_000 ether);
        deal(address(bobby), 1_000_000 ether);

        // Create validators and map pubkey hash to pubkey
        for (uint16 i = 1; i <= LibConstant.MAX_VALIDATORS; i++) {
            // Create a mock pubkey
            bytes memory pubkey = i.createPubkey();

            // Add to validators array
            validators.push(pubkey);

            // Map pubkey to hash to retrieve it later
            hashToPubkey[pubkey.hashPubkey()] = pubkey;
        }
    }

    //////////////////////////////////////////////////////
    /// --- MOCKS
    //////////////////////////////////////////////////////
    function _deployMocks() private {
        // First deploy BeaconChain contract
        beaconChain = new BeaconChain();

        // Then deploy side contract
        beaconHelper = new BeaconHelper(address(beaconChain));
        beaconProofs = new BeaconProofs(address(beaconChain));
        beaconChain.setBeaconProofs(address(beaconProofs));

        // Deploy DepositContract and PartialWithdrawContract to their respective addresses on mainnet
        deployCodeTo("BeaconRoot.sol", abi.encode(), LibConstant.BEACON_ROOTS_ADDRESS);
        deployCodeTo("DepositContract.sol", abi.encode(address(beaconChain)), LibConstant.DEPOSIT_CONTRACT_ADDRESS);
        deployCodeTo("PartialWithdrawContract.sol", abi.encode(address(beaconChain)), LibConstant.WITHDRAWAL_REQUEST_ADDRESS);
        beaconRoot = BeaconRoot(payable(LibConstant.BEACON_ROOTS_ADDRESS));
        depositContract = DepositContract(payable(LibConstant.DEPOSIT_CONTRACT_ADDRESS));
        partialWithdrawContract = PartialWithdrawContract(payable(LibConstant.WITHDRAWAL_REQUEST_ADDRESS));

        // Then deploy SSVNetwork contract
        ssvNetwork = new SSVNetwork(address(beaconChain));

        // Fetch RewardDistributor contract from BeaconChain and fund it heavily
        rewardDistributor = beaconChain.REWARD_DISTRIBUTOR();
        deal(address(beaconChain.REWARD_DISTRIBUTOR()), 1_000_000 ether);

        // Deploy WETH and SSV token
        ssv = new MockERC20("SSV Token", "SSV", 18);
        weth = new MockWETH();
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
            LibConstant.GENESIS_TIMESTAMP
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

        // ---
        // --- 4. Deploy view contract. ---
        strategyView = new CompoundingStakingStrategyView(address(strategy));

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
        vm.label(address(strategyView), "CompoundingStakingSSVStrategy View");

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
