// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Foundry
import { Test } from "@forge-std/Test.sol";

// Contract to test
import { BeaconChain } from "../src/BeaconChain.sol";

contract BaseTest is Test {
    BeaconChain beaconChain;

    address public alice = makeAddr("alice");

    bytes public validator1 = hex"01";
    bytes public validator2 = hex"02";
    bytes public validator3 = hex"03";
    bytes public validator4 = hex"04";
    bytes public validator5 = hex"05";

    function setUp() public virtual {
        beaconChain = new BeaconChain();

        deal(address(alice), 1_000_000 ether);
        deal(address(beaconChain.REWARD_DISTRIBUTOR()), 1_000_000 ether);
    }
}
