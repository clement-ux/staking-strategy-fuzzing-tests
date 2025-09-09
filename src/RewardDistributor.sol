// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

contract RewardDistributor {
    function distributeRewards(address receiver, uint256 amount) external {
        (bool success,) = receiver.call{ value: amount }("");
        require(success, "RewardDistributor: Transfer failed");
    }
}
