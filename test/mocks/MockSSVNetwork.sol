// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

contract MockSSVNetwork {
    mapping(bytes => bool) public isRegisteredValidator;

    struct Cluster {
        uint32 validatorCount;
        uint64 networkFeeIndex;
        uint64 index;
        bool active;
        uint256 balance;
    }

    function registerValidator(
        bytes calldata publicKey,
        uint64[] calldata operatorIds,
        bytes calldata sharesData,
        uint256 amount,
        Cluster memory cluster
    ) external {
        // Todo: Implement the logic for registering a validator
        isRegisteredValidator[publicKey] = true;

        // Silent unused variable warnings
        operatorIds;
        sharesData;
        amount;
        cluster;
    }

    function removeValidator(bytes memory publicKey, uint64[] memory operatorIds, Cluster memory cluster) external {
        // Todo: Implement the logic for removing a validator
    }

    function withdraw(uint64[] memory operatorIds, uint256 amount, Cluster memory cluster) external {
        // Todo: Implement the logic for withdrawing SSV tokens
    }
}
