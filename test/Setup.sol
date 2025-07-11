// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

// Test imports
import { Base } from "test/Base.sol";

// Origin Dollar
import { InitializableAbstractStrategy } from "@origin-dollar/utils/InitializableAbstractStrategy.sol";
import { CompoundingStakingSSVStrategy } from
    "@origin-dollar/strategies/NativeStaking/CompoundingStakingSSVStrategy.sol";
import { CompoundingStakingSSVStrategyProxy } from "@origin-dollar/proxies/Proxies.sol";

// Mocks
import { MockERC20 } from "@solmate/test/utils/mocks/MockERC20.sol";
import { MockSSVNetwork } from "test/mocks/MockSSVNetwork.sol";
import { MockBeaconRoots } from "test/mocks/MockBeaconRoots.sol";
import { MockBeaconOracle } from "test/mocks/MockBeaconOracle.sol";
import { MockBeaconProofs } from "test/mocks/MockBeaconProofs.sol";
import { MockDepositContract } from "test/mocks/MockDepositContract.sol";
import { MockWithdrawalRequest } from "test/mocks/MockWithdrawalRequest.sol";
import { MockConsolidationStrategy } from "test/mocks/MockConsolidationStrategy.sol";

/// @title Setup
/// @notice Abstract contract responsible for test environment initialization and contract deployment.
/// @dev    This contract orchestrates the complete test setup process in a structured manner:
///         1. Environment configuration (block timestamp, number)
///         2. User address generation and role assignment
///         3. External contract deployment (mocks, dependencies)
///         4. Main contract deployment
///         5. System initialization and configuration
///         No test logic should be implemented here, only setup procedures.
abstract contract Setup is Base {
    //////////////////////////////////////////////////////
    /// --- SETUP
    //////////////////////////////////////////////////////
    function setUp() public virtual {
        // 1. Setup a realistic test environnement.
        _setUpRealisticEnvironnement();

        // 2. Create user.
        _createUsers();

        // 3. Deploy external contracts.
        _deployExternal();

        // 4. Deploy contracts.
        _deployContracts();

        // 5. Initialize users and contracts.
        _initalize();
    }

    //////////////////////////////////////////////////////
    /// --- ENVIRONMENT
    //////////////////////////////////////////////////////
    function _setUpRealisticEnvironnement() private {
        vm.warp(1_800_000_000);
        vm.roll(23_000_000);
    }

    //////////////////////////////////////////////////////
    /// --- USERS
    //////////////////////////////////////////////////////
    function _createUsers() private {
        // Random users
        alice = makeAddr("Alice");
        bobby = makeAddr("Bobby");

        // Permissionned users
        deployer = makeAddr("Deployer");
        governor = makeAddr("Governor");
    }

    //////////////////////////////////////////////////////
    /// --- EXTERNAL CONTRACTS
    //////////////////////////////////////////////////////
    function _deployExternal() private {
        vm.startPrank(deployer);

        // Deploy WETH
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        ssv = new MockERC20("SSV Network Token", "SSV", 18);

        // Deploy mocks
        mockSSVNetwork = new MockSSVNetwork();
        mockBeaconRoots = new MockBeaconRoots();
        mockBeaconOracle = new MockBeaconOracle();
        mockBeaconProofs = new MockBeaconProofs();
        mockDepositContract = new MockDepositContract();
        mockWithdrawalRequest = new MockWithdrawalRequest();
        mockConsolidationStrategy = new MockConsolidationStrategy();

        // Mock as addresses
        vault = makeAddr("Vault");

        vm.stopPrank();

        // Label all freshly deployed external contracts
        vm.label(address(weth), "WETH");
        vm.label(address(ssv), "SSV");
        vm.label(address(mockSSVNetwork), "Mock SSVNetwork");
        vm.label(address(mockBeaconRoots), "Mock Beacon Roots");
        vm.label(address(mockBeaconOracle), "Mock Beacon Oracle");
        vm.label(address(mockBeaconProofs), "Mock Beacon Proofs");
        vm.label(address(mockDepositContract), "Mock Deposit Contract");
        vm.label(address(mockWithdrawalRequest), "Mock Withdrawal Request");
        vm.label(address(mockConsolidationStrategy), "Mock Consolidation Strategy");
        vm.label(vault, "Vault");
    }

    //////////////////////////////////////////////////////
    /// --- CONTRACTS
    //////////////////////////////////////////////////////
    function _deployContracts() private {
        vm.startPrank(deployer);

        // Deploy the Compounding Staking SSV Strategy proxy
        proxy = new CompoundingStakingSSVStrategyProxy();

        // Deploy the Compounding Staking SSV Strategy implementation
        strategy = new CompoundingStakingSSVStrategy({
            _baseConfig: InitializableAbstractStrategy.BaseStrategyConfig(address(0), vault),
            _wethAddress: address(weth),
            _ssvToken: address(ssv),
            _ssvNetwork: address(mockSSVNetwork),
            _beaconChainDepositContract: address(mockDepositContract),
            _beaconOracle: address(mockBeaconOracle),
            _beaconProofs: address(mockBeaconProofs)
        });

        // Initialize the proxy with the implementation address
        address[] memory rewardsTokenAddresses = new address[](1);
        rewardsTokenAddresses[0] = address(weth);
        bytes memory data = abi.encodeWithSelector(
            CompoundingStakingSSVStrategy.initialize.selector, rewardsTokenAddresses, new address[](0), new address[](0)
        );
        proxy.initialize({ _logic: address(strategy), _initGovernor: governor, _data: data });

        vm.label(address(proxy), "Compounding Staking SSV Strategy Proxy");
        vm.label(address(strategy), "Compounding Staking SSV Strategy Implementation");

        strategy = CompoundingStakingSSVStrategy(payable(address(proxy)));

        vm.stopPrank();
    }

    //////////////////////////////////////////////////////
    /// --- INITIALIZATION
    //////////////////////////////////////////////////////
    function _initalize() private {
        vm.startPrank(governor);

        strategy.setRegistrator(governor);
        strategy.addSourceStrategy(address(mockConsolidationStrategy));

        vm.stopPrank();
    }
}
