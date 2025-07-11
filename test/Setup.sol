// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

// Test imports
import { Base } from "test/Base.sol";

// Mocks
import { MockERC20 } from "@solmate/test/utils/mocks/MockERC20.sol";

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
        vm.warp(1_750_000_000);
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

        // Deploy external contracts ...

        vm.stopPrank();

        // Label all freshly deployed external contracts
        vm.label(address(weth), "WETH");
    }

    //////////////////////////////////////////////////////
    /// --- CONTRACTS
    //////////////////////////////////////////////////////
    function _deployContracts() private {
        vm.startPrank(deployer);

        // Deploy contracts ...

        vm.stopPrank();
    }

    //////////////////////////////////////////////////////
    /// --- INITIALIZATION
    //////////////////////////////////////////////////////
    function _initalize() private { }
}
