// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

contract SSVNetwork {
    ////////////////////////////////////////////////////
    /// --- STRUCTS & ENUM
    ////////////////////////////////////////////////////
    struct Cluster {
        uint32 validatorCount;
        uint64 networkFeeIndex;
        uint64 index;
        bool active;
        uint256 balance;
    }

    struct Validator {
        bytes publicKey;
        address owner;
    }

    ////////////////////////////////////////////////////
    /// --- STORAGE
    ////////////////////////////////////////////////////
    mapping(bytes publicKey => Validator) public validators;
    Validator[] public allValidators;

    ////////////////////////////////////////////////////
    /// --- MUTATIVE FUNCTIONS
    ////////////////////////////////////////////////////
    function registerValidator(
        bytes memory publicKey,
        uint64[] memory, /*a*/
        bytes memory, /*b*/
        uint256, /*c*/
        Cluster memory /*d*/
    ) external {
        require(validators[publicKey].owner == address(0), "Validator already registered");
        validators[publicKey] = Validator({ publicKey: publicKey, owner: msg.sender });
        allValidators.push(validators[publicKey]);
    }

    ////////////////////////////////////////////////////
    /// --- VIEW FUNCTIONS
    ////////////////////////////////////////////////////
    function getValidator(
        bytes memory publicKey
    ) external view returns (Validator memory) {
        return validators[publicKey];
    }

    function getAllValidators() external view returns (Validator[] memory) {
        return allValidators;
    }
}
