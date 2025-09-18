// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

// Test imports
import { Setup } from "test/Setup.sol";
import { FuzzerBase } from "test/FuzzerBase.sol";

// Helpers
import { console } from "@forge-std/console.sol";
import { LibBytes } from "@solady/utils/LibBytes.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { SafeCastLib } from "@solady/utils/SafeCastLib.sol";

// Target contracts
import { CompoundingValidatorManager } from "@origin-dollar/strategies/NativeStaking/CompoundingStakingSSVStrategy.sol";

/// @title TargetFunctions
/// @notice TargetFunctions contract for tests, containing the target functions that should be tested.
///         This is the entry point with the contract we are testing. Ideally, it should never revert.
abstract contract TargetFunctions is Setup, FuzzerBase {
    // ╔══════════════════════════════════════════════════════════════════════════════╗
    // ║                           ✦✦✦ TARGET FUNCTIONS ✦✦✦                           ║
    // ╚══════════════════════════════════════════════════════════════════════════════╝
    //
    // --- BeaconChain
    // [ ] processDeposit
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
    // [ ] verifyDeposit
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

        // 1. Make an initial deposit of 100 ETH.
        // Mint WETH directly to the strategy to simulate the vault having sent it.
        weth.mint(address(strategy), 100 ether);
        vm.prank(oethVault);
        strategy.deposit(address(weth), 100 ether);

        // 2. Register a first SSV validator.
        vm.prank(operator);
        strategy.registerSsvValidator(validator1.pubkey, new uint64[](0), bytes(""), 0, emptyCluster);
        registeredSsvValidators.push(validator1.pubkey);
    }

    // ╔══════════════════════════════════════════════════════════════════════════════╗
    // ║                          ✦✦✦ STRATEGY HANDLERS ✦✦✦                           ║
    // ╚══════════════════════════════════════════════════════════════════════════════╝

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
    // forge-lint: disable-next-line(mixed-case-function)
    function handler_registerSsvValidator(
        uint8 index
    ) public {
        // Bound the index of the validator to register.
        index = _bound(index, 1, MAX_VALIDATORS).toUint8();

        bytes memory pubkey;
        // Ensure the validator is not already registered, if it is, try the next one, until we find one that is not
        // registered.
        for (uint256 i; i < MAX_VALIDATORS; i++) {
            uint256 currentIndex = ((index - 1 + i) % MAX_VALIDATORS) + 1;
            bytes memory _pubkey = indexToPubkey[currentIndex.toUint40()];
            if (!beaconChain.ssvRegisteredValidators(_pubkey)) {
                pubkey = _pubkey;
                break;
            }
        }
        // If all validators are already registered, skip the registration.
        if (pubkey.eq(bytes(""))) {
            // All validators are already registered.
            console.log("RegisterSsvValidator(): \t\t all validators are already registered");
            vm.assume(false);
            return;
        }

        // Main call: registerSsvValidator
        vm.prank(operator);
        strategy.registerSsvValidator(pubkey, new uint64[](0), bytes(""), 0, emptyCluster);

        // Keep track of the registered validator.
        registeredSsvValidators.push(pubkey);

        // Log the registration.
        console.log("RegisterSsvValidator(): \t\t", vm.toString(pubkey).slice(0, 5));
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
        vm.assume(registeredSsvValidators.length > 0); // Ensure there is at least 1 registered SSV validator.
        vm.assume(strategy.depositListLength() < MAX_DEPOSITS); // Ensure we don't exceed max deposits.

        // Pick a random registered SSV validator in the list of registered SSV validators.
        bytes memory pubkey = registeredSsvValidators[index % registeredSsvValidators.length.toUint8()];

        // If validator is REGISTERED, deposit should be exactly 1 ETH.
        bytes32 pubkeyHash = beaconProofs.hashPubKey(pubkey);
        (CompoundingValidatorManager.ValidatorState status,) = strategy.validator(pubkeyHash);
        vm.assume(
            status == CompoundingValidatorManager.ValidatorState.REGISTERED
                || status == CompoundingValidatorManager.ValidatorState.VERIFIED
                || status == CompoundingValidatorManager.ValidatorState.ACTIVE
        );

        amountInGwei = _bound(amountInGwei, 1 gwei, min(3000 gwei, balanceInGwei)).toUint48();
        uint256 amountInWei = uint256(amountInGwei) * 1e9;
        if (status == CompoundingValidatorManager.ValidatorState.REGISTERED) {
            // Ensure we don't exceed max verified validators.
            vm.assume(strategy.verifiedValidatorsLength() + 1 < MAX_VERIFIED_VALIDATORS);

            // Mark the validator as staked.
            stakedValidators.push(pubkey);

            // Convert amountInGwei to exactly 1 gwei.
            amountInGwei = 1 gwei;
            amountInWei = 1 ether;
        }

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
        console.log("StakeEth(): \t\t\t\t%18e", amountInWei, "ETH to:", vm.toString(pubkey).slice(0, 5));
    }

    /// @notice Verify a validator.
    /// @param index Index in the list of staked validators to verify, limited to uint8 because we shouldn't have more than
    /// 255 ssv validators registered, really low risk of overflow.
    function handler_verifyValidator(
        uint8 index
    ) public {
        vm.assume(stakedValidators.length > 0); // Ensure there is at least 1 staked validator.

        index = index % stakedValidators.length.toUint8();
        bytes memory pubkey = stakedValidators[index];
        bytes32 pubkeyHash = pubkeyToHash[pubkey];

        // Check status of the validator.
        (CompoundingValidatorManager.ValidatorState status,) = strategy.validator(pubkeyHash);
        require(status == CompoundingValidatorManager.ValidatorState.STAKED, "Validator should not be in this list");

        // Main call: verifyValidator
        strategy.verifyValidator({
            nextBlockTimestamp: 0,
            validatorIndex: pubkeyToIndex[pubkey],
            pubKeyHash: pubkeyHash,
            withdrawalAddress: address(strategy),
            validatorPubKeyProof: bytes("")
        });

        // Remove the validator from the list of staked validators.
        removeFromArray(stakedValidators, index);

        // Mark the validator as verified.
        verifiedValidators.push(pubkey);

        // Log the verification.
        console.log("VerifyValidator(): \t\t\t", vm.toString(pubkey).slice(0, 5));
    }
}
