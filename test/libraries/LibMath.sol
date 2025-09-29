// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Helpers
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";

library LibMath {
    using FixedPointMathLib for uint256;

    function eq(uint256 a, uint256 b) internal pure returns (bool) {
        return a == b;
    }

    function lt(uint256 a, uint256 b) internal pure returns (bool) {
        return a < b;
    }

    function lte(uint256 a, uint256 b) internal pure returns (bool) {
        return a <= b;
    }

    function gt(uint256 a, uint256 b) internal pure returns (bool) {
        return a > b;
    }

    function gte(uint256 a, uint256 b) internal pure returns (bool) {
        return a >= b;
    }

    function approxEqAbs(uint256 a, uint256 b, uint256 e) internal pure returns (bool) {
        if (a > b) return (a - b) <= e;
        else return (b - a) <= e;
    }

    function approxEqRel(uint256 a, uint256 b, uint256 e) internal pure returns (bool) {
        if (a == b) return true;
        if (a == 0 || b == 0) return false; // avoid division by zero

        uint256 absDelta = a > b ? a - b : b - a;
        uint256 relDeltaBps = absDelta.divWad(a < b ? a : b);
        return relDeltaBps <= e;
    }

    function diffAbs(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    function abs(
        int256 a
    ) internal pure returns (uint256) {
        return a >= 0 ? uint256(a) : uint256(-a);
    }
}
