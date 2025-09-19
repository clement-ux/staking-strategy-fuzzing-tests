// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Test imports
import { FuzzerBase } from "test/FuzzerBase.sol";

// Helpers
import { console } from "@forge-std/console.sol";
import { LibBytes } from "@solady/utils/LibBytes.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";

// Beacon
import { BeaconChain } from "src/BeaconChain.sol";

// Target contracts
import { CompoundingValidatorManager } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingSSVStrategy.sol";

/// @title TargetFunctions
/// @notice TargetFunctions contract for tests, containing the target functions that should be tested.
///         This is the entry point with the contract we are testing. Ideally, it should never revert.
abstract contract TargetFunctions is FuzzerBase {
    // ╔══════════════════════════════════════════════════════════════════════════════╗
    // ║                           ✦✦✦ TARGET FUNCTIONS ✦✦✦                           ║
    // ╚══════════════════════════════════════════════════════════════════════════════╝
    //
    // --- BeaconChain
    // [x] processDeposit
    // [ ] processWithdraw
    // [ ] activateValidators
    // [ ] deactivateValidators
    // [ ] processSweep
    // [ ] simulateRewards
    // [ ] slash
    //
    // --- CompoundingStakingSSVStrategy
    // [x] deposit
    // [ ] withdraw
    // [ ] checkBalance
    // [x] registerSsvValidator
    // [ ] removeSsvValidator
    // [x] stakeEth
    // [ ] validatorWithdrawal
    // [x] verifyValidator
    // [x] verifyDeposit
    // [ ] snapBalances
    // [ ] verifyBalances
    //
    using LibBytes for bytes;
    using LibString for string;
    using SafeCastLib for uint256;

    ////////////////////////////////////////////////////
    /// --- SETUP
    ////////////////////////////////////////////////////
    function setUp() public virtual override {
        super.setUp();

        // Gives a little boost at the start, to get more relevant situations right away:
    }

    ////////////////////////////////////////////////////
    /// --- STRATEGY HANDLERS
    ////////////////////////////////////////////////////

    /// @notice Simulate a deposit on the strategy from the vault.
    /// @param amount Amount of ETH to deposit, limited to uint80 because strategy can only process 48 validators at a time.
    /// This represents 48 * 2048 ETH = 98304 ETH max. uint72 ≈ 4.7k ETH which is too low, so using: uint80 ≈ 1.2M ETH.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_deposit(
        uint80 amount
    ) public {
        // Prevent deposit 0.
        amount = _bound(amount, 1, type(uint80).max).toUint80();

        // Prevent dust deposits. Dust deposit are "easy to make" (i.e. no restriction, no assume), which results having a a
        // huge proportion of `handler_deposit` calls, in comparison with other handlers that have more `assume`. This
        // results in having only small deposit and no other call, which is not relevant. Maybe once we will have more
        // handlers setup, we can remove this restriction. If not, it could be nice to have an handler that simulate dust
        // deposits. Or maybe this is not possible to deposit dust due to restriction on the vault side?
        vm.assume(amount > 1e12);

        // Mint WETH directly to the strategy to simulate the vault having sent it.
        weth.mint(address(strategy), amount);

        // Main call: deposit
        vm.prank(oethVault);
        strategy.deposit(address(weth), amount);

        // Log the deposit.
        console.log("Deposit():   \t\t\t\t%18e", amount, "ETH");
    }

    /// @notice Register a SSV validator.
    /// @param index Index of the validator to register, limited to uint8 because strategy can only process 48 validators at
    /// a time. uint8 ≈ 255, so this is more than enough for 48 validators.
    /// @dev Reduce probability of this function being successfully called to 40% to avoid having too many registered. As
    /// this function is easy to pass (because low amount of assume), it tends to be called a lot more than other handlers,
    /// which results in having too many registered validators and no other calls.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_registerSsvValidator(
        uint8 index
    ) public probability(index, 40) {
        // Pick a random validator that have NOT_REGISTERED status.
        bytes memory pubkey = validatorWithStatus(CompoundingValidatorManager.ValidatorState.NON_REGISTERED, index);
        // If all validators are already registered, skip the registration.
        if (pubkey.eq(abi.encodePacked(NOT_FOUND))) {
            logAssume(false, "RegisterSsvValidator(): \t\t all validators are already registered");
        }

        // Main call: registerSsvValidator
        vm.prank(operator);
        strategy.registerSsvValidator(pubkey, new uint64[](0), bytes(""), 0, emptyCluster);

        // Log the registration.
        console.log("RegisterSsvValidator(): \t\t", logPubkey(pubkey));
    }

    /// @notice Stake ETH.
    /// @param amountInGwei Amount of ETH to stake, in Gwei, limited to uint48 because maximum stakeable amount 2048 ETH.
    /// Amount deposited will be amountInGwei * 1e9, so uint48 * 1e9 will be 281k ETH, which is more than enough. On the
    /// other hand, uint40 * 1e9 will be 1.1k ETH, which is not enough to simulate max deposit of 2048 ETH. So using uint48.
    /// However, we will cap the amount to 3k ETH to avoid weird scenarios where we try to stake too much ETH at once.
    /// @param index Index in the list of registered SSV validators to use for the staking, limited to uint8 because, we
    /// should have more than 255 ssv validators registered, really low risk of overflow.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_stakeEth(uint48 amountInGwei, uint8 index) public {
        // Bound the amount to stake to a maximum of 3k ETH.
        uint256 balanceInGwei = weth.balanceOf(address(strategy)) / 1 gwei;

        // Some assertions to ensure the staking can be done.
        vm.assume(balanceInGwei >= 1 gwei); // Ensure there is at least 1 gwei to stake.
        vm.assume(!strategy.firstDeposit()); // Ensure not 2 deposits for 2 different validators that are not verified.
        vm.assume(strategy.depositListLength() < MAX_DEPOSITS); // Ensure we don't exceed max deposits.

        // Pick a random validator that have either REGISTERED, VERIFIED or ACTIVE status.
        (bytes memory pubkey, CompoundingValidatorManager.ValidatorState status) = validatorWithStatus(
            CompoundingValidatorManager.ValidatorState.REGISTERED,
            CompoundingValidatorManager.ValidatorState.VERIFIED,
            CompoundingValidatorManager.ValidatorState.ACTIVE,
            index
        );
        // If no validator match the criteria, skip the staking.
        if (pubkey.eq(abi.encodePacked(NOT_FOUND))) {
            logAssume(false, "StakeEth(): \t\t\t\t all validators are already staked");
        }

        // Bound the amount to stake between 1 ether and the minimum of 3k ether or the strategy balance.
        amountInGwei = _bound(amountInGwei, 1 gwei, min(3000 gwei, balanceInGwei)).toUint48();

        // If validator is REGISTERED, deposit should be exactly 1 ETH.
        if (status == CompoundingValidatorManager.ValidatorState.REGISTERED) {
            // Ensure we don't exceed max verified validators.
            vm.assume(strategy.verifiedValidatorsLength() + 1 < MAX_VERIFIED_VALIDATORS);

            // Convert amountInGwei to exactly 1 gwei.
            amountInGwei = 1 gwei;
        }

        bytes32 pendingDepositRoot = beaconProofs.merkleizePendingDeposit(
            hashPubKey(pubkey),
            abi.encodePacked(bytes1(0x02), bytes11(0), address(strategy)), // withdrawal credentials
            uint64(amountInGwei),
            abi.encodePacked(depositContract.uniqueDepositId()), // signature
            0 // slot
        );

        // Main call: stakeEth
        vm.startPrank(operator);
        strategy.stakeEth({
            validatorStakeData: CompoundingValidatorManager.ValidatorStakeData({
                pubkey: pubkey,
                signature: abi.encodePacked(depositContract.uniqueDepositId()),
                depositDataRoot: bytes32(0)
            }),
            depositAmountGwei: amountInGwei
        });
        vm.stopPrank();

        // Log the staking.
        console.log(
            "StakeEth(): \t\t\t\t%18e",
            uint256(amountInGwei) * 1 gwei,
            string("ETH to:").concat(logPubkey(pubkey)).concat(" udid: ").concat(logUdid(pendingDepositRoot))
        );
    }

    /// @notice Verify a validator.
    /// @param index Index in the list of staked validators to verify, limited to uint8 because we shouldn't have more than
    /// 255 ssv validators registered, really low risk of overflow.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_verifyValidator(
        uint8 index
    ) public {
        // Pick a random validator that have STAKED status.
        bytes memory pubkey = validatorWithStatus(CompoundingValidatorManager.ValidatorState.STAKED, index);
        // If no validator match the criteria, skip the verification.
        if (pubkey.eq(abi.encodePacked(NOT_FOUND))) {
            logAssume(false, "VerifyValidator(): \t\t all validators are already verified");
        }
        bytes32 pubkeyHash = hashPubKey(pubkey);

        // Main call: verifyValidator
        strategy.verifyValidator({
            nextBlockTimestamp: 0,
            validatorIndex: pubkeyToIndex[pubkey],
            pubKeyHash: pubkeyHash,
            withdrawalAddress: address(strategy),
            validatorPubKeyProof: bytes("")
        });

        // Log the verification.
        console.log("VerifyValidator(): \t\t\t", logPubkey(pubkey));
    }

    /// @notice Verify a deposit.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_verifyDeposit(
        uint8 index
    ) public {
        // Pick a random deposit that have PENDING status
        // + is linked to a validator with either VERIFIED, ACTIVE or EXITED
        // + the deposit must be PROCESSED in the beacon chain.
        CompoundingValidatorManager.ValidatorState[] memory validStates = new CompoundingValidatorManager.ValidatorState[](3);
        validStates[0] = CompoundingValidatorManager.ValidatorState.VERIFIED;
        validStates[1] = CompoundingValidatorManager.ValidatorState.ACTIVE;
        validStates[2] = CompoundingValidatorManager.ValidatorState.EXITED;

        (bytes32 pendingDepositRoot, bytes32 pubKeyHash, uint64 slot) = depositAndValidatorWithStatus(
            ExpectedStatus({
                beaconDepositStatus: BeaconChain.DepositStatus.PROCESSED,
                strategyDepositStatus: CompoundingValidatorManager.DepositStatus.PENDING,
                validatorStatusArr: validStates
            }),
            index
        );
        // If no deposit match the criteria, skip the verification.
        if (pendingDepositRoot == bytes32(abi.encodePacked(NOT_FOUND))) {
            logAssume(false, "VerifyDeposit(): \t\t all deposits are already verified");
        }

        // Main call: verifyDeposit
        strategy.verifyDeposit({
            pendingDepositRoot: pendingDepositRoot,
            depositProcessedSlot: slot + 1,
            firstPendingDeposit: CompoundingValidatorManager.FirstPendingDepositSlotProofData({ slot: 1, proof: bytes("") }),
            strategyValidatorData: CompoundingValidatorManager.StrategyValidatorProofData({
                withdrawableEpoch: type(uint64).max,
                withdrawableEpochProof: abi.encodePacked(pendingDepositRoot)
            })
        });

        // Log the verification.
        console.log("VerifyDeposit(): \t\t\t", logPubkey(hashToPubkey[pubKeyHash]), " - udid: ", logUdid(pendingDepositRoot));
    }

    ////////////////////////////////////////////////////
    /// --- BEACONCHAIN HANDLERS
    ////////////////////////////////////////////////////
    /// @notice Process a single deposit in the beacon chain.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_processDeposit() public {
        BeaconChain.Queue[] memory deposits = beaconChain.getDepositQueue();
        vm.assume(deposits.length > 0); // Ensure there is at least one deposit to process.

        beaconChain.processDeposit();

        console.log(
            "ProcessDeposit(): \t\t\t",
            logUdid(deposits[0].udid),
            string("remain: ").concat(vm.toString(deposits.length - 1))
        );
    }
}
