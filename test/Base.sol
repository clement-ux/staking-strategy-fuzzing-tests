// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

// Foundry
import { Test } from "@forge-std/Test.sol";

// ERC
import { ERC20 } from "@solmate/tokens/ERC20.sol";

/// @title Base
/// @notice Abstract base contract defining shared state variables and contract instances for the test suite.
/// @dev    This contract serves as the foundation for all test contracts, providing:
///         - Contract instances (tokens, external dependencies)
///         - Address definitions (users, governance, deployers)
///         - No logic or setup should be included here, only state variable declarations
abstract contract Base is Test {
    //////////////////////////////////////////////////////
    /// --- CONTRACTS
    //////////////////////////////////////////////////////
    // ERC20 tokens
    ERC20 public weth;

    //////////////////////////////////////////////////////
    /// --- Governance, multisigs and EOAs
    //////////////////////////////////////////////////////
    address public alice;
    address public bobby;

    address public deployer;
    address public governor;
}
