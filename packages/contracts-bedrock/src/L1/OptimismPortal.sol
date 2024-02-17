// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { SafeCall } from "src/libraries/SafeCall.sol";
import { L2OutputOracle } from "src/L1/L2OutputOracle.sol";
import { SystemConfig } from "src/L1/SystemConfig.sol";
import { SuperchainConfig } from "src/L1/SuperchainConfig.sol";
import { Constants } from "src/libraries/Constants.sol";
import { Types } from "src/libraries/Types.sol";
import { Hashing } from "src/libraries/Hashing.sol";
import { SecureMerkleTrie } from "src/libraries/trie/SecureMerkleTrie.sol";
import { AddressAliasHelper } from "src/vendor/AddressAliasHelper.sol";
import { ResourceMetering } from "src/L1/ResourceMetering.sol";
import { ISemver } from "src/universal/ISemver.sol";

contract OptimismPortal is Initializable, ResourceMetering, ISemver {
    address public bridge;
    uint256 public bridgeBalance;

    SuperchainConfig public superchainConfig;
    L2OutputOracle public l2Oracle;
    SystemConfig public systemConfig;

    event TransactionDeposited(address indexed from, address indexed to, uint256 indexed version, bytes opaqueData);
    event WithdrawalProven(bytes32 indexed withdrawalHash, address indexed from, address indexed to);
    event WithdrawalFinalized(bytes32 indexed withdrawalHash, bool success);
    event RewardsDistributed(address indexed distributor, address[] recipients, uint256[] amounts);

    constructor() {
        initialize({
            _l2Oracle: L2OutputOracle(address(0)),
            _systemConfig: SystemConfig(address(0)),
            _superchainConfig: SuperchainConfig(address(0))
        });
    }

    function initialize(
        L2OutputOracle _l2Oracle,
        SystemConfig _systemConfig,
        SuperchainConfig _superchainConfig
    )
        public
        initializer
    {
        l2Oracle = _l2Oracle;
        systemConfig = _systemConfig;
        superchainConfig = _superchainConfig;
        bridge = address(0);
        bridgeBalance = 0;
        __ResourceMetering_init();
    }

    modifier whenNotPaused() {
        require(paused() == false, "OptimismPortal: paused");
        _;
    }

    string public constant version = "2.5.0";

    function paused() public view returns (bool paused_) {
        paused_ = superchainConfig.paused();
    }

    function _resourceConfig() internal view override returns (ResourceMetering.ResourceConfig memory) {
        return systemConfig.resourceConfig();
    }

    function minimumGasLimit(uint64 _byteCount) public pure returns (uint64) {
        return _byteCount * 16 + 21000;
    }

    receive() external payable {
        depositTransaction(msg.sender, msg.value, RECEIVE_DEFAULT_GAS_LIMIT, false, bytes(""));
    }

    function donateETH() external payable {}

    function proveWithdrawalTransaction(
        Types.WithdrawalTransaction memory _tx,
        uint256 _l2OutputIndex,
        Types.OutputRootProof calldata _outputRootProof,
        bytes[] calldata _withdrawalProof
    )
        external
        whenNotPaused
    {
        bytes32 outputRoot = l2Oracle.getL2Output(_l2OutputIndex).outputRoot;
        require(
            outputRoot == Hashing.hashOutputRootProof(_outputRootProof), "OptimismPortal: invalid output root proof"
        );

        bytes32 withdrawalHash = Hashing.hashWithdrawal(_tx);

        ProvenWithdrawal memory provenWithdrawal = provenWithdrawals[withdrawalHash];

        require(
            provenWithdrawal.timestamp == 0
                || l2Oracle.getL2Output(provenWithdrawal.l2OutputIndex).outputRoot != provenWithdrawal.outputRoot,
            "OptimismPortal: withdrawal hash has already been proven"
        );

        bytes32 storageKey = keccak256(
            abi.encode(
                withdrawalHash,
                uint256(0)
            )
        );

        require(
            SecureMerkleTrie.verifyInclusionProof(
                abi.encode(storageKey), hex"01", _withdrawalProof, _outputRootProof.messagePasserStorageRoot
            ),
            "OptimismPortal: invalid withdrawal inclusion proof"
        );

        provenWithdrawals[withdrawalHash] = ProvenWithdrawal({
            outputRoot: outputRoot,
            timestamp: uint128(block.timestamp),
            l2OutputIndex: uint128(_l2OutputIndex)
        });

        emit WithdrawalProven(withdrawalHash, _tx.sender, _tx.target);
    }

    function finalizeWithdrawalTransaction(Types.WithdrawalTransaction memory _tx) external whenNotPaused {
        require(
            l2Sender == Constants.DEFAULT_L2_SENDER, "OptimismPortal: can only trigger one withdrawal per transaction"
        );

        bytes32 withdrawalHash = Hashing.hashWithdrawal(_tx);
        ProvenWithdrawal memory provenWithdrawal = provenWithdrawals[withdrawalHash];

        require(provenWithdrawal.timestamp != 0, "OptimismPortal: withdrawal has not been proven yet");

        require(
            provenWithdrawal.timestamp >= l2Oracle.startingTimestamp(),
            "OptimismPortal: withdrawal timestamp less than L2 Oracle starting timestamp"
        );

        require(
            _isFinalizationPeriodElapsed(provenWithdrawal.timestamp),
            "OptimismPortal: proven withdrawal finalization period has not elapsed"
        );

        Types.OutputProposal memory proposal = l2Oracle.getL2Output(provenWithdrawal.l2OutputIndex);

        require(
            proposal.outputRoot == provenWithdrawal.outputRoot,
            "OptimismPortal: output root proven is not the same as current output root"
        );

        require(
            _isFinalizationPeriodElapsed(proposal.timestamp),
            "OptimismPortal: output proposal finalization period has not elapsed"
        );

        require(finalizedWithdrawals[withdrawalHash] == false, "OptimismPortal: withdrawal has already been finalized");

        finalizedWithdrawals[withdrawalHash] = true;

        l2Sender = _tx.sender;

        bool success = SafeCall.callWithMinGas(_tx.target, _tx.gasLimit, _tx.value, _tx.data);

        l2Sender = Constants.DEFAULT_L2_SENDER;

        emit WithdrawalFinalized(withdrawalHash, success);

        if (success == false && tx.origin == Constants.ESTIMATION_ADDRESS) {
            revert("OptimismPortal: withdrawal failed");
        }
    }

    function depositTransaction(
        address _to,
        uint256 _value,
        uint64 _gasLimit,
        bool _isCreation,
        bytes memory _data
    )
        public
        payable
        metered(_gasLimit)
    {
        if (_isCreation) {
            require(_to == address(0), "OptimismPortal: must send to address(0) when creating a contract");
        }

        require(_gasLimit >= minimumGasLimit(uint64(_data.length)), "OptimismPortal: gas limit too small");

        require(_data.length <= 120_000, "OptimismPortal: data too large");

        address from = msg.sender;
        if (msg.sender != tx.origin) {
            from = AddressAliasHelper.applyL1ToL2Alias(msg.sender);
        }

        depositToBridge();

        bytes memory opaqueData = abi.encodePacked(msg.value, _value, _gasLimit, _isCreation, _data);

        emit TransactionDeposited(from, _to, DEPOSIT_VERSION, opaqueData);
    }

    function isOutputFinalized(uint256 _l2OutputIndex) external view returns (bool) {
        return _isFinalizationPeriodElapsed(l2Oracle.getL2Output(_l2OutputIndex).timestamp);
    }

    function _isFinalizationPeriodElapsed(uint256 _timestamp) internal view returns (bool) {
        return block.timestamp > _timestamp + l2Oracle.FINALIZATION_PERIOD_SECONDS();
    }

    function distributeRewards(address[] calldata _receivers, uint256[] calldata _amounts) external payable {
        require(_receivers.length == _amounts.length, "OptimismPortal: invalid input length");

        depositToBridge();

        emit RewardsDistributed(msg.sender, _receivers, _amounts);
    }

    function depositToBridge() internal {
        require(bridge != address(0), "OptimismPortal: bridge not set");
        bridgeBalance += msg.value;
    }
}
