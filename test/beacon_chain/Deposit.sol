// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import { Setup } from "../Setup.sol";
import { CompoundingValidatorManager } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingSSVStrategy.sol";

contract Deposit_Test is Setup {
    bytes nullBytes32 = aliceWithdrawalCredentials;
    bytes aliceWithdrawalCredentials = abi.encodePacked(bytes1(0x02), bytes11(0), address(alice));

    function setUp() public virtual override {
        super.setUp();
    }

    function test_Deposit() public {
        // Register a validator on SSV
        vm.prank(operator);
        strategy.registerSsvValidator(validator1.pubkey, new uint64[](0), bytes(""), 0, emptyCluster);

        // Alice front run the deposit
        bytes memory withdrawalCredentials = abi.encodePacked(bytes1(0x02), bytes11(0), address(alice));
        vm.prank(alice);
        depositContract.deposit{ value: 1 ether }(validator1.pubkey, withdrawalCredentials, bytes(""), bytes32(0));
        // Stake 1 ETH
        weth.mint(address(strategy), 1 ether);
        vm.prank(operator);
        strategy.stakeEth(
            CompoundingValidatorManager.ValidatorStakeData(validator1.pubkey, bytes(""), bytes32(0)), 1 ether / 1 gwei
        );

        // Verify validator
        strategy.verifyValidator(0, validator1.index, hashPubKey(validator1.pubkey), address(alice), bytes(""));
    }
}
