// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import { Helpers } from "test/helpers/Helpers.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";
import { Cluster } from "@origin-dollar/interfaces/ISSVNetwork.sol";
import { ValidatorStakeData } from "@origin-dollar/strategies/NativeStaking/CompoundingValidatorManager.sol";

abstract contract Modifiers is Helpers {
    using SafeCastLib for uint256;

    //////////////////////////////////////////////////////
    /// --- MODIFIERS
    //////////////////////////////////////////////////////
    /// @notice Modifier to ensure the caller is the governor

    modifier asGovernor() {
        vm.startPrank(governor);
        _;
        vm.stopPrank();
    }

    modifier asAlice() {
        vm.startPrank(alice);
        _;
        vm.stopPrank();
    }

    modifier addSourceRegistry(
        address sourceRegistry
    ) {
        _addSourceRegistry(sourceRegistry);
        _;
    }

    modifier registerValidator(
        bytes memory publicKey
    ) {
        _registerValidator(publicKey);
        _;
    }

    modifier stakeETH(bytes memory publicKey, uint256 amount) {
        _stakeETH(publicKey, amount);
        _;
    }

    modifier verifyValidator(bytes memory publicKey, uint64 validatorIndex) {
        _verifyValidator(publicKey, validatorIndex);
        _;
    }

    modifier verifyDeposit(bytes memory publicKey, uint256 index) {
        _verifyDeposit(publicKey, index);
        _;
    }

    modifier requestConsolidation(
        address consolidationSourceStrategy,
        bytes32 lastPublicKeyHash,
        bytes32 currentPublicKeyHash
    ) {
        _requestConsolidation(consolidationSourceStrategy, lastPublicKeyHash, currentPublicKeyHash);
        _;
    }

    //////////////////////////////////////////////////////
    /// --- INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////
    function _registerValidator(
        bytes memory publicKey
    ) internal {
        strategy.registerSsvValidator(publicKey, new uint64[](0), bytes(""), 1 ether, Cluster(0, 0, 0, true, 1 ether));
    }

    function _stakeETH(bytes memory publicKey, uint256 amount) internal {
        deal(address(weth), address(strategy), amount);
        strategy.stakeEth(
            ValidatorStakeData(publicKey, bytes(""), generateDepositDataRoots(publicKey)), (amount / 1 gwei).toUint64()
        );
    }

    function _verifyValidator(bytes memory publicKey, uint64 validatorIndex) internal {
        strategy.verifyValidator(block.timestamp.toUint64(), validatorIndex, hashPubKey(publicKey), bytes(""));
        validatorCount++;
    }

    function _verifyDeposit(bytes memory publicKey, uint256 index) internal {
        bytes32 depositDataRoot = getDepositDataRoots(publicKey, index);
        strategy.verifyDeposit(depositDataRoot, uint64(block.number + 1), type(uint64).max, 0, bytes(""));
    }

    function _addSourceRegistry(
        address sourceRegistry
    ) internal {
        strategy.addSourceStrategy(sourceRegistry);
    }

    function _requestConsolidation(
        address consolidationSourceStrategy,
        bytes32 lastPublicKeyHash,
        bytes32 currentPublicKeyHash
    ) internal {
        address caller = msg.sender;
        vm.stopPrank();

        vm.prank(consolidationSourceStrategy);
        strategy.requestConsolidation(lastPublicKeyHash, currentPublicKeyHash);

        vm.startPrank(caller);
    }
}
