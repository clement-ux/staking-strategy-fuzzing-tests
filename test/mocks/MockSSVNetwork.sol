// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

contract MockSSVNetwork {
    struct Cluster {
        uint32 validatorCount;
        uint64 networkFeeIndex;
        uint64 index;
        bool active;
        uint256 balance;
    }

    function registerValidator(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external {
        // Todo: Implement the logic for registering a validator
    }

    function removeValidator(bytes memory publicKey, uint64[] memory operatorIds, Cluster memory cluster) external {
        // Todo: Implement the logic for removing a validator
    }

    function withdraw(uint64[] memory operatorIds, uint256 amount, Cluster memory cluster) external {
        // Todo: Implement the logic for withdrawing SSV tokens
    }
}
