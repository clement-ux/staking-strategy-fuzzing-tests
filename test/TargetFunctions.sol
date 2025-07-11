// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

// Test imports
import { Properties } from "test/Properties.sol";

// Foundry imports
import { console } from "@forge-std/console.sol";

/// @title TargetFunctions
/// @notice TargetFunctions contract for tests, containing the target functions that should be tested.
///         This is the entry point with the contract we are testing. Ideally, it should never revert.
abstract contract TargetFunctions is Properties {
    function handler_() public { }
}
