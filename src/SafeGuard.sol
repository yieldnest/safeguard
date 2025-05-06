// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseTransactionGuard, ITransactionGuard} from "lib/safe-smart-account/contracts/base/GuardManager.sol";
import {BaseModuleGuard, IModuleGuard} from "lib/safe-smart-account/contracts/base/ModuleManager.sol";
import {IERC165} from "lib/safe-smart-account/contracts/interfaces/IERC165.sol";
import {Enum} from "lib/safe-smart-account/contracts/libraries/Enum.sol";
import {ISafe} from "lib/safe-smart-account/contracts/interfaces/ISafe.sol";
import {Guard} from "lib/yieldnest-vault/src/module/Guard.sol";
import {VaultLib, IVault} from "lib/yieldnest-vault/src/library/VaultLib.sol";
// import {IVault} from "lib/yieldnest-vault/src/interface/IVault.sol";
import {AccessControlUpgradeable} from
    "lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";

contract SafeGuard is BaseTransactionGuard, BaseModuleGuard, AccessControlUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    /**
     * @notice Initializes the contract.
     * @param admin The address that will be granted the admin role.
     */

    function initialize(address admin) public initializer {
        __AccessControl_init();

        // Grant the admin role to the deployer
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// TransactionGuard ///

    /**
     * @notice Called by the Safe contract before a transaction is executed.
     * @dev Reverts if the transaction is not executed by an owner.
     */
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation, /* operation */
        uint256, /* safeTxGas */
        uint256, /* baseGas */
        uint256, /* gasPrice */
        address, /* gasToken */
        address payable, /* refundReceiver */
        bytes memory, /* signatures */
        address /* executor */
    ) external view override {
        // TODO: optimize this; it should do another external call to handle this.
        SafeGuard(address(this)).validateCall(to, value, data);
    }

    /**
     * @inheritdoc ITransactionGuard
     */
    function checkAfterExecution(bytes32, bool) external pure override {
        // No-op implementation
    }

    /**
     * @inheritdoc IModuleGuard
     */
    function checkModuleTransaction(address, uint256, bytes memory, Enum.Operation, address)
        external
        pure
        override
        returns (bytes32 moduleTxHash)
    {
        // No-op implementation
        return bytes32(0);
    }

    /**
     * @inheritdoc IModuleGuard
     */
    function checkAfterModuleExecution(bytes32, bool) external pure override {
        // No-op implementation
    }

    /// VautLib Guard Rules ///

    // Role identifier for processor manager
    bytes32 public constant PROCESSOR_MANAGER_ROLE = keccak256("PROCESSOR_MANAGER_ROLE");

    /**
     * @notice Validates a transaction call against the guard rules
     * @param target The address of the target contract
     * @param value The amount of ETH being sent with the call
     * @param data The calldata of the transaction
     * @dev This function is called by the checkTransaction function to validate calls
     */
    function validateCall(address target, uint256 value, bytes calldata data) public view {
        Guard.validateCall(target, value, data);
    }

    /**
     * @notice Sets the processor rule for a given contract address and function signature.
     * @param target The address of the target contract.
     * @param functionSig The function signature.
     * @param rule The function rule.
     */
    function _setProcessorRule(address target, bytes4 functionSig, IVault.FunctionRule calldata rule)
        internal
        virtual
    {
        VaultLib.setProcessorRule(target, functionSig, rule);
    }

    /**
     * @notice Sets the processor rule for a given contract address and function signature.
     * @param target The address of the target contract.
     * @param functionSig The function signature.
     * @param rule The function rule.
     */
    function setProcessorRules(
        address[] calldata target,
        bytes4[] calldata functionSig,
        IVault.FunctionRule[] calldata rule
    ) public virtual onlyRole(PROCESSOR_MANAGER_ROLE) {
        uint256 targetLength = target.length;
        if (targetLength != functionSig.length || targetLength != rule.length) {
            revert IVault.InvalidArray();
        }

        for (uint256 i = 0; i < targetLength; i++) {
            _setProcessorRule(target[i], functionSig[i], rule[i]);
        }
    }

    /**
     * @notice Returns the function rule for a given contract address and function signature.
     * @param contractAddress The address of the contract.
     * @param funcSig The function signature.
     * @return FunctionRule The function rule.
     */
    function getProcessorRule(address contractAddress, bytes4 funcSig)
        public
        view
        virtual
        returns (IVault.FunctionRule memory)
    {
        return _getProcessorStorage().rules[contractAddress][funcSig];
    }

    /**
     * @notice Internal function to get the processor storage.
     * @return The processor storage.
     */
    function _getProcessorStorage() internal pure returns (IVault.ProcessorStorage storage) {
        return VaultLib.getProcessorStorage();
    }

    /// ERC165 ///

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(BaseTransactionGuard, BaseModuleGuard, AccessControlUpgradeable)
        returns (bool)
    {
        return interfaceId == type(ITransactionGuard).interfaceId // 0xe6d7a83a
            || interfaceId == type(IModuleGuard).interfaceId // 0x58401ed8
            || interfaceId == type(IERC165).interfaceId; // 0x01ffc9a7
    }
}
