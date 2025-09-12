// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Foundry
import { Test } from "@forge-std/Test.sol";

// Contract to test
import { BeaconChain } from "../src/BeaconChain.sol";
import { PartialWithdrawContract } from "../src/PartialWithdrawContract.sol";

contract BaseTest is Test {
    BeaconChain beaconChain;
    PartialWithdrawContract partialWithdrawContract;

    address public alice = makeAddr("alice");

    /// @dev it is mandatory for decoding that the pubkey is 2 bytes long!
    bytes public validator1 = hex"0001";
    bytes public validator2 = hex"0002";
    bytes public validator3 = hex"0003";
    bytes public validator4 = hex"0004";
    bytes public validator5 = hex"0005";

    function setUp() public virtual {
        beaconChain = new BeaconChain();
        partialWithdrawContract = new PartialWithdrawContract(address(beaconChain));

        deal(address(alice), 1_000_000 ether);
        deal(address(beaconChain.REWARD_DISTRIBUTOR()), 1_000_000 ether);
        beaconChain.registerSsvValidator(validator1);
        beaconChain.registerSsvValidator(validator2);
        beaconChain.registerSsvValidator(validator3);
        beaconChain.registerSsvValidator(validator4);
        beaconChain.registerSsvValidator(validator5);
    }
}
