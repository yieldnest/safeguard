// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseTransactionGuard, ITransactionGuard} from "lib/safe-smart-account/contracts/base/GuardManager.sol";
import {BaseModuleGuard, IModuleGuard} from "lib/safe-smart-account/contracts/base/ModuleManager.sol";
import {IERC165} from "lib/safe-smart-account/contracts/interfaces/IERC165.sol";
import {Enum} from "lib/safe-smart-account/contracts/libraries/Enum.sol";
import {ISafe} from "lib/safe-smart-account/contracts/interfaces/ISafe.sol";

contract SafeGuard is BaseTransactionGuard, BaseModuleGuard {

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) external view virtual override(BaseTransactionGuard, BaseModuleGuard) returns (bool) {
        return
            interfaceId == type(ITransactionGuard).interfaceId || // 0xe6d7a83a
            interfaceId == type(IModuleGuard).interfaceId || // 0x58401ed8
            interfaceId == type(IERC165).interfaceId; // 0x01ffc9a7
    }


    /**
     * @notice Called by the Safe contract before a transaction is executed.
     * @dev Reverts if the transaction is not executed by an owner.
     * @param msgSender Executor of the transaction.
     */
    function checkTransaction(
        address,
        uint256,
        bytes memory,
        Enum.Operation,
        uint256,
        uint256,
        uint256,
        address,
        // solhint-disable-next-line no-unused-vars
        address payable,
        bytes memory,
        address msgSender
    ) external view override {
        require(ISafe(msg.sender).isOwner(msgSender), "msg sender is not allowed to exec");
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
    function checkModuleTransaction(
        address,
        uint256,
        bytes memory,
        Enum.Operation,
        address
    ) external pure override returns (bytes32 moduleTxHash) {
        // No-op implementation
        return bytes32(0);
    }

    /**
     * @inheritdoc IModuleGuard
     */
    function checkAfterModuleExecution(bytes32, bool) external pure override {
        // No-op implementation
    }

}
