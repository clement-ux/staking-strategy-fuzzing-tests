// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Test imports
import { FuzzerBase } from "test/FuzzerBase.sol";

// Helpers
import { console } from "@forge-std/console.sol";
import { LibBytes } from "@solady/utils/LibBytes.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";
import { FixedPointMathLib } from "@solady/utils/FixedPointMathLib.sol";

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
    // [x] processWithdraw
    // [x] activateValidators
    // [x] deactivateValidators
    // [x] processSweep
    // [x] simulateRewards
    // [x] slash
    //
    // --- CompoundingStakingSSVStrategy
    // [x] deposit
    // [x] withdraw
    // [x] registerSsvValidator
    // [x] removeSsvValidator
    // [x] stakeEth
    // [x] validatorWithdrawal
    // [x] verifyValidator
    // [x] verifyDeposit
    // [x] snapBalances
    // [x] verifyBalances
    //
    // --- System
    // [x] timejump
    //
    // ------------------------

    using LibBytes for bytes;
    using LibString for string;
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;

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
    /// @param random Random value used to reduce the probability of this function being called. Not limited because used for
    /// randomness.
    /// @param index Index of the validator to register, limited to uint8 because strategy can only process 48 validators at
    /// a time. uint8 ≈ 255, so this is more than enough for 48 validators.
    /// @dev Reduce probability of this function being successfully called to 40% to avoid having too many registered. As
    /// this function is easy to pass (because low amount of assume), it tends to be called a lot more than other handlers,
    /// which results in having too many registered validators and no other calls.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_registerSsvValidator(uint256 random, uint8 index) public probability(random, 40) {
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
        bytes memory pubkey = existingValidatorWithStatus(CompoundingValidatorManager.ValidatorState.STAKED, index);
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

        (, uint64 snapTimestamp,) = strategy.snappedBalance();
        uint64 depositProcessedSlot = slot + 1;
        vm.assume(snapTimestamp == 0 || calcNextBlockTimestamp(depositProcessedSlot) <= snapTimestamp);
        // Main call: verifyDeposit
        strategy.verifyDeposit({
            pendingDepositRoot: pendingDepositRoot,
            depositProcessedSlot: depositProcessedSlot,
            firstPendingDeposit: CompoundingValidatorManager.FirstPendingDepositSlotProofData({ slot: 1, proof: bytes("") }),
            strategyValidatorData: CompoundingValidatorManager.StrategyValidatorProofData({
                withdrawableEpoch: type(uint64).max,
                withdrawableEpochProof: abi.encodePacked(pendingDepositRoot)
            })
        });

        // Log the verification.
        console.log("VerifyDeposit(): \t\t\t", logPubkey(hashToPubkey[pubKeyHash]), " - udid: ", logUdid(pendingDepositRoot));
    }

    /// @notice Snap the balances of the strategy.
    /// @param random Index used to reduce the probability of this function being called, no limit because used for
    /// randomness.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_snapBalances(
        uint256 random
    ) public probability(random, 20) {
        (, uint64 snapTimestamp,) = strategy.snappedBalance();

        // Prevent calling snapBalances too often.
        vm.assume(snapTimestamp + SNAP_BALANCES_DELAY < block.timestamp);

        // Main call: snapBalances
        strategy.snapBalances();

        // Log the snap.
        console.log("SnapBalances(): \t\t\ttimestamp:", block.timestamp);
    }

    /// @notice Verify the balances of the strategy.
    /// @dev Currently, it's hard to pass this call, because it requires the BeaconChain to have to same deposit queue as the
    /// strategy i.e. that no deposit have been processed on the beacon chain without being verified on the strategy.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_verifyBalances() public {
        // Ensure snapBalances was called at least once.
        (, uint64 snapTimestamp,) = strategy.snappedBalance();
        vm.assume(snapTimestamp != 0);

        // It is only possible to verifyBalances if there is a deposit processed on beacon chain, but not verifier on the
        // strategy.
        // This is a temporary fix, as I assume this will not works once we will implement withdraw (especially with deposit
        // to an exited validator. This assume that only the strategy can process deposits.
        uint256 pendingDeposits = strategy.depositListLength();
        vm.assume(pendingDeposits == beaconChain.getDepositQueueLength());

        // Get sizes for arrays.
        uint256 validValidators = strategy.verifiedValidatorsLength();

        // Main call: verifyBalances
        strategy.verifyBalances({
            balanceProofs: CompoundingValidatorManager.BalanceProofs({
                balancesContainerRoot: bytes32(0),
                balancesContainerProof: bytes(""),
                validatorBalanceLeaves: new bytes32[](validValidators),
                validatorBalanceProofs: new bytes[](validValidators)
            }),
            pendingDepositProofs: CompoundingValidatorManager.PendingDepositProofs({
                pendingDepositContainerRoot: bytes32(0),
                pendingDepositContainerProof: bytes(""),
                pendingDepositIndexes: new uint32[](pendingDeposits),
                pendingDepositProofs: new bytes[](pendingDeposits)
            })
        });

        // Log the verification.
        console.log("VerifyBalances(): \t\t\t%18e ETH", strategy.lastVerifiedEthBalance());
    }

    /// @notice Withdraw from a validator.
    /// @param fullWithdraw Whether to do a full withdraw (true) or a partial withdraw (false).
    /// @param amountToWithdraw Amount of ETH to withdraw, in Gwei, limited to uint48 because maximum withdrawable amount
    /// will be bound to 3000k ETH.
    /// @param index Index in the list of registered SSV validators to use for the withdrawal, limited to uint8 because we
    /// should have more than 255 ssv validators registered, really low risk of overflow.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_validatorWithdrawal(bool fullWithdraw, uint48 amountToWithdraw, uint8 index) public {
        // Bound the amount to withdraw between 1 gwei and 3k ETH.
        amountToWithdraw = fullWithdraw ? 0 : _bound(amountToWithdraw, 1, 3000 gwei).toUint48();

        // Pick a random validator that have either ACTIVE or EXITING status.
        // If the validator is EXITING and fullWithdraw requested, ensure there is no pending deposit.
        (bytes memory pubkey,) = pleaseFindBetterName(fullWithdraw, index);

        // If no validator match the criteria, skip the withdrawal.
        if (pubkey.eq(abi.encodePacked(NOT_FOUND))) {
            logAssume(
                false, "ValidatorWithdrawal(): \t all validators are either not active or exiting with pending deposits"
            );
        }

        // Main call: validatorWithdrawal
        vm.prank(operator);
        strategy.validatorWithdrawal({ publicKey: pubkey, amountGwei: amountToWithdraw });

        bytes32 udid = bytes32(abi.encodePacked(uint16(beaconChain.withdrawCounter() - 1), bytes30(0)));

        // Log the withdrawal.
        console.log(
            "ValidatorWithdrawal(): \t\t %18e ETH - pubkey: %s, udid: %s",
            uint256(amountToWithdraw) * 1 gwei,
            logPubkey(pubkey),
            logUdid(udid)
        );
    }

    /// @notice Withdraw from the strategy to a recipient.
    /// @param amount Amount of ETH to withdraw, limited to uint80 because it will be bound to the strategy balance.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_withdraw(uint80 amount, uint256 random) public probability(random, 20) {
        uint256 balance = weth.balanceOf(address(strategy)) + address(strategy).balance;
        vm.assume(balance > 1); // Ensure there is at least 1 wei to withdraw.

        // Bound the amount to withdraw between 1 wei and the strategy balance.
        amount = _bound(amount, 1, balance).toUint80();

        // Main call: withdraw
        vm.prank(oethVault);
        strategy.withdraw(address(this), address(weth), amount);

        // Log the withdrawal.
        console.log("Withdraw():  \t\t\t\t%18e", amount, "ETH");
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

    /// @notice Activate validator in the beacon chain.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_activateValidators() public {
        // Activate the first validator that can be activated.
        bytes memory pubkey = beaconChain.activateValidator();

        // Ensure at least one validator was activated.
        vm.assume(!pubkey.eq(abi.encodePacked(NOT_FOUND)));

        // Log the activation.
        console.log("ActivateValidators(): \t\t", logPubkey(pubkey));
    }

    /// @notice Remove a SSV validator.
    /// @param index Index in the list of registered SSV validators to remove, limited to uint8 because we should have
    /// more than 255 ssv validators registered, really low risk of overflow.
    /// @param random Random value used to reduce the probability of this function being called. Not limited because used for
    /// randomness.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_removeSsvValidator(uint8 index, uint256 random) public probability(random, 20) {
        // Pick a random validator that have either REGISTERED, EXITED or INVALID status.
        (bytes memory pubkey,) = validatorWithStatus(
            CompoundingValidatorManager.ValidatorState.REGISTERED,
            CompoundingValidatorManager.ValidatorState.EXITED,
            CompoundingValidatorManager.ValidatorState.INVALID,
            index
        );
        // If no validator match the criteria, skip the removal.
        if (pubkey.eq(abi.encodePacked(NOT_FOUND))) vm.assume(false);

        // Main call: removeSsvValidator
        vm.prank(operator);
        strategy.removeSsvValidator(pubkey, new uint64[](0), emptyCluster);

        // Log the removal.
        console.log("RemoveSsvValidator(): \t\t", logPubkey(pubkey));
    }

    /// @notice Process a sweep of validators in the beacon chain.
    /// @param count Maximum number of validators to process in this sweep, limited to uint8 because we should not have
    /// more than 255 validators, really low risk of overflow.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_processSweep(
        uint8 count
    ) public {
        uint256 validatorsCount = beaconChain.getValidatorLength();
        vm.assume(validatorsCount > 0); // Ensure there is at least one validator to process.

        // Bound the count to process between 1 and the number of validators.
        count = _bound(count, 1, uint8(validatorsCount)).toUint8();

        // Main call: processSweep
        beaconChain.processSweep();

        console.log("ProcessSweep(): \t\t\t (%d total)", validatorsCount);
    }

    /// @notice Process a withdrawal in the beacon chain.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_processWithdraw() public {
        vm.assume(beaconChain.getWithdrawQueueLength() > 0); // Ensure there is at least one withdraw to process.

        // Main call: processWithdraw
        (bytes memory pubkey, bytes32 udid, uint256 amount) = beaconChain.processWithdraw();

        if (pubkey.eq(abi.encodePacked(NOT_FOUND))) {
            console.log("ProcessWithdraw(): \t\t\t udid: %s thrown as not possible to process", logUdid(udid));
        }

        console.log("ProcessWithdraw(): \t\t\t%18e ETH pubkey: %s, udid: %s", amount, logPubkey(pubkey), logUdid(udid));
    }

    /// @notice Deactivate validators in the beacon chain.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_deactivateValidators() public {
        vm.assume(beaconChain.getValidatorLength() > 0); // Ensure there is at least one validator to process.

        // Main call: deactivateValidators
        (bytes[] memory deactivatedPubkeys, uint256 counter) = beaconChain.deactivateValidators();

        vm.assume(counter > 0); // Ensure at least one validator was deactivated.

        console.log(
            "DeactivateValidators(): \t\t deactivated %d validators: %s",
            counter,
            arrayIntoString(deactivatedPubkeys, counter)
        );
    }

    /// @notice Simulate rewards for active validators in the beacon chain.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_simulateRewards() public {
        // Ensure there is at least one active validator.
        vm.assume(beaconHelper.countValidatorWithStatus(BeaconChain.Status.ACTIVE) > 0);

        // Main call: simulateRewards
        (bytes[] memory receivers, uint256 counter, uint256 amount) = beaconChain.simulateRewards();

        console.log(
            "SimulateRewards(): \t\t\t %18e ETH rewards distributed to: %s", amount, arrayIntoString(receivers, counter)
        );
    }

    /// @notice Slash a validator in the beacon chain.
    /// @param amount Amount of ETH to slash, limited to uint80 because maximum slashing amount will be 3k ETH.
    /// @param index Index to use to find an active validator, limited to uint8 because we should have more than 255
    /// active validators, really low risk of overflow.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_slash(uint80 amount, uint8 index) public {
        BeaconChain.Validator memory validator = beaconHelper.findValidatorWithStatus(BeaconChain.Status.ACTIVE, index);

        // Ensure at least one active validator.
        vm.assume(!validator.pubkey.eq(abi.encodePacked(NOT_FOUND)));

        uint256 multiplicator = beaconChain.SLASHING_PENALTY_MULTIPLICATOR();
        amount =
            _bound(amount, validator.amount.mulWad(multiplicator), validator.amount.mulWad(multiplicator * 1000)).toUint80();

        // Main call: slash
        beaconChain.slash(validator.pubkey, amount);

        console.log("Slash():    \t\t\t\t %18e ETH - pubkey: %s", amount, logPubkey(validator.pubkey));
    }

    ////////////////////////////////////////////////////
    /// --- SYSTEM HANDLERS
    ////////////////////////////////////////////////////
    /// @notice Simulate a time jump in the system.
    /// @param random Index used to reduce the probability of this function being called. Not limited because used for
    /// randomness.
    /// @param secondsToJump Number of seconds to jump, limited to uint32 to avoid too big jumps.
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_timejump(uint256 random, uint32 secondsToJump) public probability(random, 10) {
        // Minimum jump of 12 seconds to ensure we replicate execution block time.
        secondsToJump = _bound(secondsToJump, 12, 1 days).toUint32();
        skip(secondsToJump);

        console.log("Timejump(): \t\t\t\t jumped %d seconds to %d", secondsToJump, block.timestamp);
    }
}
