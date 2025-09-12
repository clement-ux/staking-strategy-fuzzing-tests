// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Foundry
import { Test } from "@forge-std/Test.sol";

// Contract to test
import { SSVNetwork } from "../src/SSVNetwork.sol";
import { BeaconChain } from "../src/BeaconChain.sol";
import { DepositContract } from "../src/DepositContract.sol";
import { RewardDistributor } from "../src/RewardDistributor.sol";
import { PartialWithdrawContract } from "../src/PartialWithdrawContract.sol";

contract BaseTest is Test {
    ////////////////////////////////////////////////////
    /// --- CONSTANTS & IMMUTABLES
    ////////////////////////////////////////////////////
    address public constant DEPOSIT_CONTRACT_ADDRESS = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
    address public constant WITHDRAWAL_REQUEST_ADDRESS = 0x00000961Ef480Eb55e80D19ad83579A64c007002;

    ////////////////////////////////////////////////////
    /// --- STORAGE VARIABLES
    ////////////////////////////////////////////////////
    // Users
    address public alice = makeAddr("alice");

    // Validator pubkeys for testing, should be exactly 2 bytes long!
    bytes public validator1 = hex"0001";
    bytes public validator2 = hex"0002";
    bytes public validator3 = hex"0003";
    bytes public validator4 = hex"0004";
    bytes public validator5 = hex"0005";

    // Contracts
    SSVNetwork public ssvNetwork;
    BeaconChain public beaconChain;
    DepositContract public depositContract;
    RewardDistributor public rewardDistributor;
    PartialWithdrawContract public partialWithdrawContract;

    ////////////////////////////////////////////////////
    /// --- SETUP
    ////////////////////////////////////////////////////
    function setUp() public virtual {
        // First deploy BeaconChain contract
        beaconChain = new BeaconChain();

        // Deploy DepositContract and PartialWithdrawContract to their respective addresses on mainnet
        deployCodeTo("DepositContract.sol", abi.encode(address(beaconChain)), DEPOSIT_CONTRACT_ADDRESS);
        deployCodeTo("PartialWithdrawContract.sol", abi.encode(address(beaconChain)), WITHDRAWAL_REQUEST_ADDRESS);
        depositContract = DepositContract(payable(DEPOSIT_CONTRACT_ADDRESS));
        partialWithdrawContract = PartialWithdrawContract(payable(WITHDRAWAL_REQUEST_ADDRESS));

        // Then deploy SSVNetwork contract
        ssvNetwork = new SSVNetwork(address(beaconChain));

        // Fetch RewardDistributor contract from BeaconChain and fund it heavily
        rewardDistributor = beaconChain.REWARD_DISTRIBUTOR();
        deal(address(beaconChain.REWARD_DISTRIBUTOR()), 1_000_000 ether);

        deal(address(alice), 1_000_000 ether);
        beaconChain.registerSsvValidator(validator1);
        beaconChain.registerSsvValidator(validator2);
        beaconChain.registerSsvValidator(validator3);
        beaconChain.registerSsvValidator(validator4);
        beaconChain.registerSsvValidator(validator5);
    }
}
