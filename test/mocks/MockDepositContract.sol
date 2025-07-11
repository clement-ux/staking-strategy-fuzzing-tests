// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

contract MockDepositContract {
    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external payable { }

    receive() external payable { }
}
