// SPDX-License-Identifier: BSD-3-Clause

/// @title The Verbs DAO logic version 1

/*********************************
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░██░░░████░░██░░░████░░░ *
 * ░░██████░░░████████░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 *********************************/

// LICENSE
// VerbsDAOLogicV1.sol is a modified version of Compound Lab's GovernorBravoDelegate.sol:
// https://github.com/compound-finance/compound-protocol/blob/b9b14038612d846b83f8a009a82c38974ff2dcfe/contracts/Governance/GovernorBravoDelegate.sol
//
// GovernorBravoDelegate.sol source code Copyright 2020 Compound Labs, Inc. licensed under the BSD-3-Clause license.
// With modifications by Nounders DAO.
//
// Additional conditions of BSD-3-Clause can be found here: https://opensource.org/licenses/BSD-3-Clause
//
// MODIFICATIONS
// See NounsDAOLogicV1 for initial GovernorBravoDelegate modifications.

// VerbsDAOLogicV1 adds:
// - `quorumParamsCheckpoints`, which store dynamic quorum parameters checkpoints
// to be used when calculating the dynamic quorum.
// - `_setDynamicQuorumParams(DynamicQuorumParams memory params)`, which allows the
// DAO to update the dynamic quorum parameters' values.
// - `getDynamicQuorumParamsAt(uint256 blockNumber_)`
// - Individual setters of the DynamicQuorumParams members:
//    - `_setMinQuorumVotesBPS(uint16 newMinQuorumVotesBPS)`
//    - `_setMaxQuorumVotesBPS(uint16 newMaxQuorumVotesBPS)`
//    - `_setQuorumCoefficient(uint32 newQuorumCoefficient)`
// - `minQuorumVotes` and `maxQuorumVotes`, which returns the current min and
// max quorum votes using the current Noun supply.
// - New `Proposal` struct member:
//    - `totalSupply` used in dynamic quorum calculation.
//    - `creationBlock` used for retrieving checkpoints of votes and dynamic quorum params. This now
// allows changing `votingDelay` without affecting the checkpoints lookup.
// - `quorumVotes(uint256 proposalId)`, which calculates and returns the dynamic
// quorum for a specific proposal.
// - `proposals(uint256 proposalId)` instead of the implicit getter, to avoid stack-too-deep error
//
// VerbsDAOLogicV1 removes:
// - `quorumVotes()` has been replaced by `quorumVotes(uint256 proposalId)`.

pragma solidity ^0.8.22;

import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

import { UUPS } from "../libs/proxy/UUPS.sol";
import { VersionedContract } from "../version/VersionedContract.sol";

import "./VerbsDAOInterfaces.sol";
import { IVerbsDAO } from "../interfaces/IVerbsDAO.sol";
import { IRevolutionBuilder } from "../interfaces/IRevolutionBuilder.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

contract VerbsDAOLogicV1 is
    IVerbsDAO,
    VersionedContract,
    Ownable2StepUpgradeable,
    UUPS,
    EIP712Upgradeable,
    VerbsDAOEvents,
    VerbsDAOStorageV1
{
    ///                                                          ///
    ///                         IMMUTABLES                       ///
    ///                                                          ///

    /// @notice The contract upgrade manager
    IRevolutionBuilder private immutable manager;

    /// @notice The name of this contract
    string public constant name = "Vrbs DAO";

    /// @notice The minimum settable proposal threshold
    uint256 public constant MIN_PROPOSAL_THRESHOLD_BPS = 1; // 1 basis point or 0.01%

    /// @notice The maximum settable proposal threshold
    uint256 public constant MAX_PROPOSAL_THRESHOLD_BPS = 1_000; // 1,000 basis points or 10%

    /// @notice The minimum voting delay setting
    uint256 public immutable MIN_VOTING_DELAY = 1 seconds;

    /// @notice The maximum voting delay setting
    uint256 public immutable MAX_VOTING_DELAY = 12 weeks;

    /// @notice The minimum voting period setting
    uint256 public immutable MIN_VOTING_PERIOD = 10 minutes;

    /// @notice The maximum voting period setting
    uint256 public immutable MAX_VOTING_PERIOD = 24 weeks;

    /// @notice The lower bound of minimum quorum votes basis points
    uint256 public constant MIN_QUORUM_VOTES_BPS_LOWER_BOUND = 200; // 200 basis points or 2%

    /// @notice The upper bound of minimum quorum votes basis points
    uint256 public constant MIN_QUORUM_VOTES_BPS_UPPER_BOUND = 2_000; // 2,000 basis points or 20%

    /// @notice The upper bound of maximum quorum votes basis points
    uint256 public constant MAX_QUORUM_VOTES_BPS_UPPER_BOUND = 6_000; // 6,000 basis points or 60%

    /// @notice The maximum settable quorum votes basis points
    uint256 public constant MAX_QUORUM_VOTES_BPS = 2_000; // 2,000 basis points or 20%

    /// @notice The maximum number of actions that can be included in a proposal
    uint256 public constant proposalMaxOperations = 10; // 10 actions

    /// @notice The maximum priority fee used to cap gas refunds in `castRefundableVote`
    uint256 public constant MAX_REFUND_PRIORITY_FEE = 2 gwei;

    /// @notice The vote refund gas overhead, including 7K for ETH transfer and 29K for general transaction overhead
    uint256 public constant REFUND_BASE_GAS = 36000;

    /// @notice The maximum gas units the DAO will refund voters on; supports about 9,190 characters
    uint256 public constant MAX_REFUND_GAS_USED = 200_000;

    /// @notice The maximum basefee the DAO will refund voters on
    uint256 public constant MAX_REFUND_BASE_FEE = 200 gwei;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,uint8 support)");

    ///                                                          ///
    ///                           ERRORS                         ///
    ///                                                          ///

    /// @dev Introduced these errors to reduce contract size, to avoid deployment failure
    error AdminOnly();
    error InvalidMinQuorumVotesBPS();
    error InvalidMaxQuorumVotesBPS();
    error MinQuorumBPSGreaterThanMaxQuorumBPS();
    error UnsafeUint16Cast();
    error VetoerOnly();
    error PendingVetoerOnly();
    error VetoerBurned();
    error CantVetoExecutedProposal();
    error CantCancelExecutedProposal();

    ///                                                          ///
    ///                         CONSTRUCTOR                      ///
    ///                                                          ///

    /// @param _manager The contract upgrade manager address
    constructor(address _manager) payable initializer {
        manager = IRevolutionBuilder(_manager);
    }

    ///                                                          ///
    ///                         INITIALIZER                      ///
    ///                                                          ///

    /**
     * @notice Used to initialize the contract during delegator contructor
     * @param executor_ The address of the DAOExecutor
     * @param erc721Token_ The address of the ERC-721 token
     * @param erc20Token_ The address of the ERC-20 token
     * @param govParams_ The initial governance parameters
     */
    function initialize(
        address executor_,
        address erc721Token_,
        address erc20Token_,
        IRevolutionBuilder.GovParams calldata govParams_
    ) public virtual initializer {
        require(msg.sender == address(manager), "VerbsDAO::initialize: only the manager can initialize");
        require(executor_ != address(0), "VerbsDAO::initialize: invalid executor address");
        require(erc721Token_ != address(0), "VerbsDAO::initialize: invalid erc721 address");
        require(erc20Token_ != address(0), "VerbsDAO::initialize: invalid erc20 address");
        require(
            govParams_.votingPeriod >= MIN_VOTING_PERIOD && govParams_.votingPeriod <= MAX_VOTING_PERIOD,
            "VerbsDAO::initialize: invalid voting period"
        );
        require(
            govParams_.votingDelay >= MIN_VOTING_DELAY && govParams_.votingDelay <= MAX_VOTING_DELAY,
            "VerbsDAO::initialize: invalid voting delay"
        );
        require(
            govParams_.proposalThresholdBPS >= MIN_PROPOSAL_THRESHOLD_BPS &&
                govParams_.proposalThresholdBPS <= MAX_PROPOSAL_THRESHOLD_BPS,
            "VerbsDAO::initialize: invalid proposal threshold bps"
        );
        require(govParams_.erc721TokenVotingWeight > 0, "VerbsDAO::initialize: invalid verbs token voting weight");

        // Initialize EIP-712 support
        __EIP712_init(govParams_.daoName, "1");

        // Grant ownership to the treasury
        __Ownable_init(executor_);

        emit VotingPeriodSet(votingPeriod, govParams_.votingPeriod);
        emit VotingDelaySet(votingDelay, govParams_.votingDelay);
        emit ProposalThresholdBPSSet(proposalThresholdBPS, govParams_.proposalThresholdBPS);

        timelock = IDAOExecutor(executor_);
        verbs = VerbsTokenLike(erc721Token_);
        verbsPoints = VerbsPointsLike(erc20Token_);
        vetoer = govParams_.vetoer;
        votingPeriod = govParams_.votingPeriod;
        votingDelay = govParams_.votingDelay;
        proposalThresholdBPS = govParams_.proposalThresholdBPS;
        erc721TokenVotingWeight = govParams_.erc721TokenVotingWeight;

        // TODO set these dynamic quorum params
        // _setDynamicQuorumParams(
        //     govParams_.dynamicQuorumParams.minQuorumVotesBPS,
        //     govParams_.dynamicQuorumParams.maxQuorumVotesBPS,
        //     govParams_.dynamicQuorumParams.quorumCoefficient
        // );
    }

    struct ProposalTemp {
        uint256 totalSupply;
        uint256 proposalThreshold;
        uint256 latestProposalId;
        uint256 startBlock;
        uint256 endBlock;
    }

    /**
     * @notice Function used to propose a new proposal. Sender must have delegates above the proposal threshold
     * @param targets Target addresses for proposal calls
     * @param values Eth values for proposal calls
     * @param signatures Function signatures for proposal calls
     * @param calldatas Calldatas for proposal calls
     * @param description String description of the proposal
     * @return Proposal id of new proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256) {
        ProposalTemp memory temp;

        temp.totalSupply = verbs.totalSupply();

        temp.proposalThreshold = bps2Uint(proposalThresholdBPS, temp.totalSupply);

        require(
            getTotalVotes(msg.sender, block.number - 1) > temp.proposalThreshold,
            "VerbsDAO::propose: proposer votes below proposal threshold"
        );
        require(
            targets.length == values.length &&
                targets.length == signatures.length &&
                targets.length == calldatas.length,
            "VerbsDAO::propose: proposal function information parity mismatch"
        );
        require(targets.length != 0, "VerbsDAO::propose: must provide actions");
        require(targets.length <= proposalMaxOperations, "VerbsDAO::propose: too many actions");

        temp.latestProposalId = latestProposalIds[msg.sender];
        if (temp.latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(temp.latestProposalId);
            require(
                proposersLatestProposalState != ProposalState.Active,
                "VerbsDAO::propose: one live proposal per proposer, found an already active proposal"
            );
            require(
                proposersLatestProposalState != ProposalState.Pending,
                "VerbsDAO::propose: one live proposal per proposer, found an already pending proposal"
            );
        }

        temp.startBlock = block.number + votingDelay;
        temp.endBlock = temp.startBlock + votingPeriod;

        proposalCount++;
        Proposal storage newProposal = _proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.proposer = msg.sender;
        newProposal.proposalThreshold = temp.proposalThreshold;
        newProposal.eta = 0;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.signatures = signatures;
        newProposal.calldatas = calldatas;
        newProposal.startBlock = temp.startBlock;
        newProposal.endBlock = temp.endBlock;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.abstainVotes = 0;
        newProposal.canceled = false;
        newProposal.executed = false;
        newProposal.vetoed = false;
        newProposal.totalSupply = temp.totalSupply;
        newProposal.creationBlock = block.number;

        latestProposalIds[newProposal.proposer] = newProposal.id;

        /// @notice Maintains backwards compatibility with GovernorBravo events
        emit ProposalCreated(
            newProposal.id,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            newProposal.startBlock,
            newProposal.endBlock,
            description
        );

        /// @notice Updated event with `proposalThreshold` and `minQuorumVotes`
        /// @notice `minQuorumVotes` is always zero since V2 introduces dynamic quorum with checkpoints
        emit ProposalCreatedWithRequirements(
            newProposal.id,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            newProposal.startBlock,
            newProposal.endBlock,
            newProposal.proposalThreshold,
            minQuorumVotes(),
            description
        );

        return newProposal.id;
    }

    /**
     * @notice Queues a proposal of state succeeded
     * @param proposalId The id of the proposal to queue
     */
    function queue(uint256 proposalId) external {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "VerbsDAO::queue: proposal can only be queued if it is succeeded"
        );
        Proposal storage proposal = _proposals[proposalId];
        uint256 eta = block.timestamp + timelock.delay();
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            queueOrRevertInternal(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                eta
            );
        }
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    function queueOrRevertInternal(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal {
        require(
            !timelock.queuedTransactions(keccak256(abi.encode(target, value, signature, data, eta))),
            "VerbsDAO::queueOrRevertInternal: identical proposal action already queued at eta"
        );
        timelock.queueTransaction(target, value, signature, data, eta);
    }

    /**
     * @notice Executes a queued proposal if eta has passed
     * @param proposalId The id of the proposal to execute
     */
    function execute(uint256 proposalId) external {
        require(
            state(proposalId) == ProposalState.Queued,
            "VerbsDAO::execute: proposal can only be executed if it is queued"
        );
        Proposal storage proposal = _proposals[proposalId];
        proposal.executed = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }
        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice Calculates the total number of votes given an account at a specific block
     * @param account The address of the account to check
     * @param blockNumber The block number to get the votes at
     */
    function getTotalVotes(address account, uint256 blockNumber) public view returns (uint256) {
        uint256 erc721TokenVotes = verbs.getPriorVotes(account, blockNumber);

        uint256 erc20PointsVotesWad = verbsPoints.getPastVotes(account, blockNumber);

        return (erc721TokenVotes * 1e18 * erc721TokenVotingWeight) + erc20PointsVotesWad;
    }

    /**
     * @notice Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` votes should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IVerbsDAOLogicV1-getTotalVotes}.
     */
    function voteDecimals() public pure returns (uint256) {
        return 18;
    }

    /**
     * @notice Cancels a proposal only if sender is the proposer, or proposer delegates dropped below proposal threshold
     * @param proposalId The id of the proposal to cancel
     */
    function cancel(uint256 proposalId) external {
        if (state(proposalId) == ProposalState.Executed) {
            revert CantCancelExecutedProposal();
        }

        Proposal storage proposal = _proposals[proposalId];
        require(
            msg.sender == proposal.proposer ||
                getTotalVotes(proposal.proposer, block.number - 1) <= proposal.proposalThreshold,
            "VerbsDAO::cancel: proposer above threshold"
        );

        proposal.canceled = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.cancelTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }

        emit ProposalCanceled(proposalId);
    }

    /**
     * @notice Vetoes a proposal only if sender is the vetoer and the proposal has not been executed.
     * @param proposalId The id of the proposal to veto
     */
    function veto(uint256 proposalId) external {
        if (vetoer == address(0)) {
            revert VetoerBurned();
        }

        if (msg.sender != vetoer) {
            revert VetoerOnly();
        }

        if (state(proposalId) == ProposalState.Executed) {
            revert CantVetoExecutedProposal();
        }

        Proposal storage proposal = _proposals[proposalId];

        proposal.vetoed = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.cancelTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }

        emit ProposalVetoed(proposalId);
    }

    /**
     * @notice Gets actions of a proposal
     * @param proposalId the id of the proposal
     * @return targets
     * @return values
     * @return signatures
     * @return calldatas
     */
    function getActions(
        uint256 proposalId
    )
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        )
    {
        Proposal storage p = _proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    /**
     * @notice Gets the receipt for a voter on a given proposal
     * @param proposalId the id of proposal
     * @param voter The address of the voter
     * @return The voting receipt
     */
    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory) {
        return _proposals[proposalId].receipts[voter];
    }

    /**
     * @notice Gets the state of a proposal
     * @param proposalId The id of the proposal
     * @return Proposal state
     */
    function state(uint256 proposalId) public view returns (ProposalState) {
        require(proposalCount >= proposalId, "VerbsDAO::state: invalid proposal id");
        Proposal storage proposal = _proposals[proposalId];
        if (proposal.vetoed) {
            return ProposalState.Vetoed;
        } else if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes(proposal.id)) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= proposal.eta + timelock.GRACE_PERIOD()) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    /**
     * @notice Returns the proposal details given a proposal id.
     *     The `quorumVotes` member holds the *current* quorum, given the current votes.
     * @param proposalId the proposal id to get the data for
     * @return A `ProposalCondensed` struct with the proposal data
     */
    function proposals(uint256 proposalId) external view returns (ProposalCondensed memory) {
        Proposal storage proposal = _proposals[proposalId];
        return
            ProposalCondensed({
                id: proposal.id,
                proposer: proposal.proposer,
                proposalThreshold: proposal.proposalThreshold,
                quorumVotes: quorumVotes(proposal.id),
                eta: proposal.eta,
                startBlock: proposal.startBlock,
                endBlock: proposal.endBlock,
                forVotes: proposal.forVotes,
                againstVotes: proposal.againstVotes,
                abstainVotes: proposal.abstainVotes,
                canceled: proposal.canceled,
                vetoed: proposal.vetoed,
                executed: proposal.executed,
                totalSupply: proposal.totalSupply,
                creationBlock: proposal.creationBlock
            });
    }

    /**
     * @notice Cast a vote for a proposal
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     */
    function castVote(uint256 proposalId, uint8 support) external {
        emit VoteCast(msg.sender, proposalId, support, castVoteInternal(msg.sender, proposalId, support), "");
    }

    /**
     * @notice Cast a vote for a proposal, asking the DAO to refund gas costs.
     * Users with > 0 votes receive refunds. Refunds are partial when using a gas priority fee higher than the DAO's cap.
     * Refunds are partial when the DAO's balance is insufficient.
     * No refund is sent when the DAO's balance is empty. No refund is sent to users with no votes.
     * Voting takes place regardless of refund success.
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @dev Reentrancy is defended against in `castVoteInternal` at the `receipt.hasVoted == false` require statement.
     */
    function castRefundableVote(uint256 proposalId, uint8 support) external {
        castRefundableVoteInternal(proposalId, support, "");
    }

    /**
     * @notice Cast a vote for a proposal, asking the DAO to refund gas costs.
     * Users with > 0 votes receive refunds. Refunds are partial when using a gas priority fee higher than the DAO's cap.
     * Refunds are partial when the DAO's balance is insufficient.
     * No refund is sent when the DAO's balance is empty. No refund is sent to users with no votes.
     * Voting takes place regardless of refund success.
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @param reason The reason given for the vote by the voter
     * @dev Reentrancy is defended against in `castVoteInternal` at the `receipt.hasVoted == false` require statement.
     */
    function castRefundableVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external {
        castRefundableVoteInternal(proposalId, support, reason);
    }

    /**
     * @notice Internal function that carries out refundable voting logic
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @param reason The reason given for the vote by the voter
     * @dev Reentrancy is defended against in `castVoteInternal` at the `receipt.hasVoted == false` require statement.
     */
    function castRefundableVoteInternal(uint256 proposalId, uint8 support, string memory reason) internal {
        uint256 startGas = gasleft();
        uint256 votes = castVoteInternal(msg.sender, proposalId, support);
        emit VoteCast(msg.sender, proposalId, support, votes, reason);
        if (votes > 0) {
            _refundGas(startGas);
        }
    }

    /**
     * @notice Cast a vote for a proposal with a reason
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @param reason The reason given for the vote by the voter
     */
    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external {
        emit VoteCast(msg.sender, proposalId, support, castVoteInternal(msg.sender, proposalId, support), reason);
    }

    /**
     * @notice Cast a vote for a proposal by signature
     * @dev External function that accepts EIP-712 signatures for voting on proposals.
     */
    function castVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainIdInternal(), address(this))
        );
        bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "VerbsDAO::castVoteBySig: invalid signature");
        emit VoteCast(signatory, proposalId, support, castVoteInternal(signatory, proposalId, support), "");
    }

    /**
     * @notice Internal function that caries out voting logic
     * @param voter The voter that is casting their vote
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @return The number of votes cast
     */
    function castVoteInternal(address voter, uint256 proposalId, uint8 support) internal returns (uint256) {
        require(state(proposalId) == ProposalState.Active, "VerbsDAO::castVoteInternal: voting is closed");
        require(support <= 2, "VerbsDAO::castVoteInternal: invalid vote type");
        Proposal storage proposal = _proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(receipt.hasVoted == false, "VerbsDAO::castVoteInternal: voter already voted");

        /// @notice: Unlike GovernerBravo, votes are considered from the block the proposal was created in order to normalize quorumVotes and proposalThreshold metrics
        uint256 votes = getTotalVotes(voter, proposalCreationBlock(proposal));

        if (support == 0) {
            proposal.againstVotes = proposal.againstVotes + votes;
        } else if (support == 1) {
            proposal.forVotes = proposal.forVotes + votes;
        } else if (support == 2) {
            proposal.abstainVotes = proposal.abstainVotes + votes;
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        return votes;
    }

    /**
     * @notice Admin function for setting the voting delay
     * @param newVotingDelay new voting delay, in blocks
     */
    function _setVotingDelay(uint256 newVotingDelay) external {
        if (msg.sender != admin) {
            revert AdminOnly();
        }
        require(
            newVotingDelay >= MIN_VOTING_DELAY && newVotingDelay <= MAX_VOTING_DELAY,
            "VerbsDAO::_setVotingDelay: invalid voting delay"
        );
        uint256 oldVotingDelay = votingDelay;
        votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay, votingDelay);
    }

    /**
     * @notice Admin function for setting the voting period
     * @param newVotingPeriod new voting period, in blocks
     */
    function _setVotingPeriod(uint256 newVotingPeriod) external {
        if (msg.sender != admin) {
            revert AdminOnly();
        }
        require(
            newVotingPeriod >= MIN_VOTING_PERIOD && newVotingPeriod <= MAX_VOTING_PERIOD,
            "VerbsDAO::_setVotingPeriod: invalid voting period"
        );
        uint256 oldVotingPeriod = votingPeriod;
        votingPeriod = newVotingPeriod;

        emit VotingPeriodSet(oldVotingPeriod, votingPeriod);
    }

    /**
     * @notice Admin function for setting the proposal threshold basis points
     * @dev newProposalThresholdBPS must be greater than the hardcoded min
     * @param newProposalThresholdBPS new proposal threshold
     */
    function _setProposalThresholdBPS(uint256 newProposalThresholdBPS) external {
        if (msg.sender != admin) {
            revert AdminOnly();
        }
        require(
            newProposalThresholdBPS >= MIN_PROPOSAL_THRESHOLD_BPS &&
                newProposalThresholdBPS <= MAX_PROPOSAL_THRESHOLD_BPS,
            "VerbsDAO::_setProposalThreshold: invalid proposal threshold bps"
        );
        uint256 oldProposalThresholdBPS = proposalThresholdBPS;
        proposalThresholdBPS = newProposalThresholdBPS;

        emit ProposalThresholdBPSSet(oldProposalThresholdBPS, proposalThresholdBPS);
    }

    /**
     * @notice Admin function for setting the minimum quorum votes bps
     * @param newMinQuorumVotesBPS minimum quorum votes bps
     *     Must be between `MIN_QUORUM_VOTES_BPS_LOWER_BOUND` and `MIN_QUORUM_VOTES_BPS_UPPER_BOUND`
     *     Must be lower than or equal to maxQuorumVotesBPS
     */
    function _setMinQuorumVotesBPS(uint16 newMinQuorumVotesBPS) external {
        if (msg.sender != admin) {
            revert AdminOnly();
        }
        DynamicQuorumParams memory params = getDynamicQuorumParamsAt(block.number);

        require(
            newMinQuorumVotesBPS >= MIN_QUORUM_VOTES_BPS_LOWER_BOUND &&
                newMinQuorumVotesBPS <= MIN_QUORUM_VOTES_BPS_UPPER_BOUND,
            "VerbsDAO::_setMinQuorumVotesBPS: invalid min quorum votes bps"
        );
        require(
            newMinQuorumVotesBPS <= params.maxQuorumVotesBPS,
            "VerbsDAO::_setMinQuorumVotesBPS: min quorum votes bps greater than max"
        );

        uint16 oldMinQuorumVotesBPS = params.minQuorumVotesBPS;
        params.minQuorumVotesBPS = newMinQuorumVotesBPS;

        _writeQuorumParamsCheckpoint(params);

        emit MinQuorumVotesBPSSet(oldMinQuorumVotesBPS, newMinQuorumVotesBPS);
    }

    /**
     * @notice Admin function for setting the maximum quorum votes bps
     * @param newMaxQuorumVotesBPS maximum quorum votes bps
     *     Must be lower than `MAX_QUORUM_VOTES_BPS_UPPER_BOUND`
     *     Must be higher than or equal to minQuorumVotesBPS
     */
    function _setMaxQuorumVotesBPS(uint16 newMaxQuorumVotesBPS) external {
        if (msg.sender != admin) {
            revert AdminOnly();
        }
        DynamicQuorumParams memory params = getDynamicQuorumParamsAt(block.number);

        require(
            newMaxQuorumVotesBPS <= MAX_QUORUM_VOTES_BPS_UPPER_BOUND,
            "VerbsDAO::_setMaxQuorumVotesBPS: invalid max quorum votes bps"
        );
        require(
            params.minQuorumVotesBPS <= newMaxQuorumVotesBPS,
            "VerbsDAO::_setMaxQuorumVotesBPS: min quorum votes bps greater than max"
        );

        uint16 oldMaxQuorumVotesBPS = params.maxQuorumVotesBPS;
        params.maxQuorumVotesBPS = newMaxQuorumVotesBPS;

        _writeQuorumParamsCheckpoint(params);

        emit MaxQuorumVotesBPSSet(oldMaxQuorumVotesBPS, newMaxQuorumVotesBPS);
    }

    /**
     * @notice Admin function for setting the dynamic quorum coefficient
     * @param newQuorumCoefficient the new coefficient, as a fixed point integer with 6 decimals
     */
    function _setQuorumCoefficient(uint32 newQuorumCoefficient) external {
        if (msg.sender != admin) {
            revert AdminOnly();
        }
        DynamicQuorumParams memory params = getDynamicQuorumParamsAt(block.number);

        uint32 oldQuorumCoefficient = params.quorumCoefficient;
        params.quorumCoefficient = newQuorumCoefficient;

        _writeQuorumParamsCheckpoint(params);

        emit QuorumCoefficientSet(oldQuorumCoefficient, newQuorumCoefficient);
    }

    /**
     * @notice Admin function for setting all the dynamic quorum parameters
     * @param newMinQuorumVotesBPS minimum quorum votes bps
     *     Must be between `MIN_QUORUM_VOTES_BPS_LOWER_BOUND` and `MIN_QUORUM_VOTES_BPS_UPPER_BOUND`
     *     Must be lower than or equal to maxQuorumVotesBPS
     * @param newMaxQuorumVotesBPS maximum quorum votes bps
     *     Must be lower than `MAX_QUORUM_VOTES_BPS_UPPER_BOUND`
     *     Must be higher than or equal to minQuorumVotesBPS
     * @param newQuorumCoefficient the new coefficient, as a fixed point integer with 6 decimals
     */
    function _setDynamicQuorumParams(
        uint16 newMinQuorumVotesBPS,
        uint16 newMaxQuorumVotesBPS,
        uint32 newQuorumCoefficient
    ) public {
        if (msg.sender != admin) {
            revert AdminOnly();
        }
        if (
            newMinQuorumVotesBPS < MIN_QUORUM_VOTES_BPS_LOWER_BOUND ||
            newMinQuorumVotesBPS > MIN_QUORUM_VOTES_BPS_UPPER_BOUND
        ) {
            revert InvalidMinQuorumVotesBPS();
        }
        if (newMaxQuorumVotesBPS > MAX_QUORUM_VOTES_BPS_UPPER_BOUND) {
            revert InvalidMaxQuorumVotesBPS();
        }
        if (newMinQuorumVotesBPS > newMaxQuorumVotesBPS) {
            revert MinQuorumBPSGreaterThanMaxQuorumBPS();
        }

        DynamicQuorumParams memory oldParams = getDynamicQuorumParamsAt(block.number);

        DynamicQuorumParams memory params = DynamicQuorumParams({
            minQuorumVotesBPS: newMinQuorumVotesBPS,
            maxQuorumVotesBPS: newMaxQuorumVotesBPS,
            quorumCoefficient: newQuorumCoefficient
        });
        _writeQuorumParamsCheckpoint(params);

        emit MinQuorumVotesBPSSet(oldParams.minQuorumVotesBPS, params.minQuorumVotesBPS);
        emit MaxQuorumVotesBPSSet(oldParams.maxQuorumVotesBPS, params.maxQuorumVotesBPS);
        emit QuorumCoefficientSet(oldParams.quorumCoefficient, params.quorumCoefficient);
    }

    function _withdraw() external returns (uint256, bool) {
        if (msg.sender != admin) {
            revert AdminOnly();
        }

        uint256 amount = address(this).balance;
        (bool sent, ) = msg.sender.call{ value: amount }("");

        emit Withdraw(amount, sent);

        return (amount, sent);
    }

    /**
     * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @param newPendingAdmin New pending admin.
     */
    function _setPendingAdmin(address newPendingAdmin) external {
        // Check caller = admin
        require(msg.sender == admin, "VerbsDAO::_setPendingAdmin: admin only");

        // Save current value, if any, for inclusion in log
        address oldPendingAdmin = pendingAdmin;

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        // Emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin)
        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);
    }

    /**
     * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
     * @dev Admin function for pending admin to accept role and update admin
     */
    function _acceptAdmin() external {
        // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
        require(msg.sender == pendingAdmin && msg.sender != address(0), "VerbsDAO::_acceptAdmin: pending admin only");

        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
    }

    /**
     * @notice Begins transition of vetoer. The newPendingVetoer must call _acceptVetoer to finalize the transfer.
     * @param newPendingVetoer New Pending Vetoer
     */
    function _setPendingVetoer(address newPendingVetoer) public {
        if (msg.sender != vetoer) {
            revert VetoerOnly();
        }

        emit NewPendingVetoer(pendingVetoer, newPendingVetoer);

        pendingVetoer = newPendingVetoer;
    }

    function _acceptVetoer() external {
        if (msg.sender != pendingVetoer) {
            revert PendingVetoerOnly();
        }

        // Update vetoer
        emit NewVetoer(vetoer, pendingVetoer);
        vetoer = pendingVetoer;

        // Clear the pending value
        emit NewPendingVetoer(pendingVetoer, address(0));
        pendingVetoer = address(0);
    }

    /**
     * @notice Burns veto privileges
     * @dev Vetoer function destroying veto power forever
     */
    function _burnVetoPower() public {
        // Check caller is vetoer
        require(msg.sender == vetoer, "VerbsDAO::_burnVetoPower: vetoer only");

        // Update vetoer to 0x0
        emit NewVetoer(vetoer, address(0));
        vetoer = address(0);

        // Clear the pending value
        emit NewPendingVetoer(pendingVetoer, address(0));
        pendingVetoer = address(0);
    }

    /**
     * @notice Current proposal threshold using Noun Total Supply
     * Differs from `GovernerBravo` which uses fixed amount
     */
    function proposalThreshold() public view returns (uint256) {
        return bps2Uint(proposalThresholdBPS, verbs.totalSupply());
    }

    function proposalCreationBlock(Proposal storage proposal) internal view returns (uint256) {
        if (proposal.creationBlock == 0) {
            return proposal.startBlock - votingDelay;
        }
        return proposal.creationBlock;
    }

    /**
     * @notice Quorum votes required for a specific proposal to succeed
     * Differs from `GovernerBravo` which uses fixed amount
     */
    function quorumVotes(uint256 proposalId) public view returns (uint256) {
        Proposal storage proposal = _proposals[proposalId];
        if (proposal.totalSupply == 0) {
            return proposal.quorumVotes;
        }

        return
            dynamicQuorumVotes(
                proposal.againstVotes,
                proposal.totalSupply,
                getDynamicQuorumParamsAt(proposal.creationBlock)
            );
    }

    /**
     * @notice Calculates the required quorum of for-votes based on the amount of against-votes
     *     The more against-votes there are for a proposal, the higher the required quorum is.
     *     The quorum BPS is between `params.minQuorumVotesBPS` and params.maxQuorumVotesBPS.
     *     The additional quorum is calculated as:
     *       quorumCoefficient * againstVotesBPS
     * @dev Note the coefficient is a fixed point integer with 6 decimals
     * @param againstVotes Number of against-votes in the proposal
     * @param totalSupply The total supply of Verbs at the time of proposal creation
     * @param params Configurable parameters for calculating the quorum based on againstVotes. See `DynamicQuorumParams` definition for additional details.
     * @return quorumVotes The required quorum
     */
    function dynamicQuorumVotes(
        uint256 againstVotes,
        uint256 totalSupply,
        DynamicQuorumParams memory params
    ) public pure returns (uint256) {
        uint256 againstVotesBPS = (10000 * againstVotes) / totalSupply;
        uint256 quorumAdjustmentBPS = (params.quorumCoefficient * againstVotesBPS) / 1e6;
        uint256 adjustedQuorumBPS = params.minQuorumVotesBPS + quorumAdjustmentBPS;
        uint256 quorumBPS = min(params.maxQuorumVotesBPS, adjustedQuorumBPS);
        return bps2Uint(quorumBPS, totalSupply);
    }

    /**
     * @notice returns the dynamic quorum parameters values at a certain block number
     * @dev The checkpoints array must not be empty, and the block number must be higher than or equal to
     *     the block of the first checkpoint
     * @param blockNumber_ the block number to get the params at
     * @return The dynamic quorum parameters that were set at the given block number
     */
    function getDynamicQuorumParamsAt(uint256 blockNumber_) public view returns (DynamicQuorumParams memory) {
        uint32 blockNumber = safe32(blockNumber_, "VerbsDAO::getDynamicQuorumParamsAt: block number exceeds 32 bits");
        uint256 len = quorumParamsCheckpoints.length;

        if (len == 0) {
            return
                DynamicQuorumParams({
                    minQuorumVotesBPS: safe16(quorumVotesBPS),
                    maxQuorumVotesBPS: safe16(quorumVotesBPS),
                    quorumCoefficient: 0
                });
        }

        if (quorumParamsCheckpoints[len - 1].fromBlock <= blockNumber) {
            return quorumParamsCheckpoints[len - 1].params;
        }

        if (quorumParamsCheckpoints[0].fromBlock > blockNumber) {
            return
                DynamicQuorumParams({
                    minQuorumVotesBPS: safe16(quorumVotesBPS),
                    maxQuorumVotesBPS: safe16(quorumVotesBPS),
                    quorumCoefficient: 0
                });
        }

        uint256 lower = 0;
        uint256 upper = len - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2;
            DynamicQuorumParamsCheckpoint memory cp = quorumParamsCheckpoints[center];
            if (cp.fromBlock == blockNumber) {
                return cp.params;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return quorumParamsCheckpoints[lower].params;
    }

    function _writeQuorumParamsCheckpoint(DynamicQuorumParams memory params) internal {
        uint32 blockNumber = safe32(block.number, "block number exceeds 32 bits");
        uint256 pos = quorumParamsCheckpoints.length;
        if (pos > 0 && quorumParamsCheckpoints[pos - 1].fromBlock == blockNumber) {
            quorumParamsCheckpoints[pos - 1].params = params;
        } else {
            quorumParamsCheckpoints.push(DynamicQuorumParamsCheckpoint({ fromBlock: blockNumber, params: params }));
        }
    }

    function _refundGas(uint256 startGas) internal {
        unchecked {
            uint256 balance = address(this).balance;
            if (balance == 0) {
                return;
            }
            uint256 basefee = min(block.basefee, MAX_REFUND_BASE_FEE);
            uint256 gasPrice = min(tx.gasprice, basefee + MAX_REFUND_PRIORITY_FEE);
            uint256 gasUsed = min(startGas - gasleft() + REFUND_BASE_GAS, MAX_REFUND_GAS_USED);
            uint256 refundAmount = min(gasPrice * gasUsed, balance);
            (bool refundSent, ) = tx.origin.call{ value: refundAmount }("");
            emit RefundableVote(tx.origin, refundAmount, refundSent);
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @notice Current min quorum votes using Noun total supply
     */
    function minQuorumVotes() public view returns (uint256) {
        return bps2Uint(getDynamicQuorumParamsAt(block.number).minQuorumVotesBPS, verbs.totalSupply());
    }

    /**
     * @notice Current max quorum votes using Noun total supply
     */
    function maxQuorumVotes() public view returns (uint256) {
        return bps2Uint(getDynamicQuorumParamsAt(block.number).maxQuorumVotesBPS, verbs.totalSupply());
    }

    function bps2Uint(uint256 bps, uint256 number) internal pure returns (uint256) {
        return (number * bps) / 10000;
    }

    function getChainIdInternal() internal view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    function safe32(uint256 n, string memory errorMessage) internal pure returns (uint32) {
        require(n <= type(uint32).max, errorMessage);
        return uint32(n);
    }

    function safe16(uint256 n) internal pure returns (uint16) {
        if (n > type(uint16).max) {
            revert UnsafeUint16Cast();
        }
        return uint16(n);
    }

    receive() external payable {}

    ///                                                          ///
    ///                          DAO UPGRADE                     ///
    ///                                                          ///

    /// @notice Ensures the caller is authorized to upgrade the contract and that the new implementation is valid
    /// @dev This function is called in `upgradeTo` & `upgradeToAndCall`
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal view override onlyOwner {
        // Ensure the new implementation is a registered upgrade
        if (!manager.isRegisteredUpgrade(_getImplementation(), _newImpl)) revert INVALID_UPGRADE(_newImpl);
    }
}
