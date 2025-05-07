// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "lib/forge-std/src/Test.sol";
import {SafeGuard} from "../src/SafeGuard.sol";
import {ProxyAdmin} from "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
    "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IVault} from "lib/yieldnest-vault/src/library/VaultLib.sol";
import {SafeRules} from "lib/yieldnest-vault/script/rules/SafeRules.sol";
import {BaseRules} from "lib/yieldnest-vault/script/rules/BaseRules.sol";
import {IValidator} from "lib/yieldnest-vault/src/interface/IValidator.sol";
import {Enum} from "lib/safe-smart-account/contracts/libraries/Enum.sol";
import {Guard} from "lib/yieldnest-vault/src/module/Guard.sol";

contract SafeGuardTest is Test {
    SafeGuard implementation;
    SafeGuard safeguard;
    ProxyAdmin admin;
    address adminAddress;
    address user;
    address processorManager;

    function setUp() public {
        // Set up accounts
        adminAddress = makeAddr("admin");
        user = makeAddr("user");
        processorManager = makeAddr("processorManager");

        // Deploy implementation
        implementation = new SafeGuard();

        TransparentUpgradeableProxy transparentProxy =
            new TransparentUpgradeableProxy(address(implementation), adminAddress, "");
        // Cast proxy to SafeGuard
        safeguard = SafeGuard(address(transparentProxy));

        safeguard.initialize(adminAddress);

        // Grant PROCESSOR_MANAGER_ROLE to processorManager
        vm.startPrank(adminAddress);
        safeguard.grantRole(safeguard.PROCESSOR_MANAGER_ROLE(), processorManager);
        vm.stopPrank();
    }

    function test_setProcessorRules_revertWhenCallerNotProcessorManager() public {
        // Create sample targets
        address mockContract = address(0x1234);
        address mockToken = address(0x5678);

        // Use BaseRules to get predefined rules
        SafeRules.RuleParams memory approvalRule = BaseRules.getApprovalRule(mockToken, address(this));

        // Prepare arrays for setProcessorRules
        address[] memory targets = new address[](1);
        bytes4[] memory functionSigs = new bytes4[](1);
        IVault.FunctionRule[] memory rules = new IVault.FunctionRule[](1);

        targets[0] = approvalRule.contractAddress;
        functionSigs[0] = approvalRule.funcSig;
        rules[0] = approvalRule.rule;

        // Call from unauthorized user (not processorManager)
        vm.startPrank(user);

        // Expect revert when caller doesn't have PROCESSOR_MANAGER_ROLE
        vm.expectRevert();
        safeguard.setProcessorRules(targets, functionSigs, rules);

        vm.stopPrank();
    }

    function test_setProcessorRules() public {
        // Create sample targets
        address mockContract = address(0x1234);
        address mockToken = address(0x5678);

        // Use BaseRules to get predefined rules
        SafeRules.RuleParams memory approvalRule = BaseRules.getApprovalRule(mockToken, address(this));

        SafeRules.RuleParams memory depositRule = BaseRules.getDepositRule(mockContract, user);

        SafeRules.RuleParams[] memory ruleParams = new SafeRules.RuleParams[](2);
        ruleParams[0] = approvalRule;
        ruleParams[1] = depositRule;
        vm.startPrank(processorManager);
        SafeRules.setProcessorRules(IVault(address(safeguard)), ruleParams, true);
        vm.stopPrank();

        // Verify the rules were set correctly
        IVault.FunctionRule memory retrievedRule0 =
            safeguard.getProcessorRule(approvalRule.contractAddress, approvalRule.funcSig);
        IVault.FunctionRule memory retrievedRule1 =
            safeguard.getProcessorRule(depositRule.contractAddress, depositRule.funcSig);

        // Assert rule 0 properties (approval rule)
        assertEq(retrievedRule0.isActive, true);
        assertEq(address(retrievedRule0.validator), address(0));
        assertEq(retrievedRule0.paramRules.length, 2);

        // Assert rule 1 properties (deposit rule)
        assertEq(retrievedRule1.isActive, true);
        assertEq(address(retrievedRule1.validator), address(0));
        assertEq(retrievedRule1.paramRules.length, 2);
    }

    function test_checkTransaction_revertsOnInactiveRule() public {
        // Create sample targets
        address mockContract = address(0x1234);
        address mockToken = address(0x5678);

        // Use BaseRules to get predefined rules
        SafeRules.RuleParams memory approvalRule = BaseRules.getApprovalRule(mockToken, address(this));
        SafeRules.RuleParams memory depositRule = BaseRules.getDepositRule(mockContract, user);

        // Set up rules - but make depositRule inactive
        depositRule.rule.isActive = false;

        SafeRules.RuleParams[] memory ruleParams = new SafeRules.RuleParams[](2);
        ruleParams[0] = approvalRule;
        ruleParams[1] = depositRule;

        vm.startPrank(processorManager);
        SafeRules.setProcessorRules(IVault(address(safeguard)), ruleParams, true);
        vm.stopPrank();

        // Verify the rules were set correctly
        IVault.FunctionRule memory retrievedRule =
            safeguard.getProcessorRule(depositRule.contractAddress, depositRule.funcSig);
        assertEq(retrievedRule.isActive, false);

        // Create transaction data for the inactive rule (deposit function)
        bytes memory txData = abi.encodeWithSelector(depositRule.funcSig, 1000, user);

        // Expect revert when checking transaction with inactive rule
        vm.expectRevert(
            abi.encodeWithSelector(Guard.RuleNotActive.selector, depositRule.contractAddress, depositRule.funcSig)
        );
        safeguard.checkTransaction(
            depositRule.contractAddress, // to
            0, // value
            txData, // data
            Enum.Operation.Call, // operation
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            payable(address(0)), // refundReceiver
            bytes(""), // signatures
            address(this) // executor
        );
    }

    function test_checkTransaction_succeedsWithActiveRule() public {
        // Create sample targets
        address mockContract = address(0x1234);
        address mockToken = address(0x5678);

        // Use BaseRules to get predefined rules
        SafeRules.RuleParams memory approvalRule = BaseRules.getApprovalRule(mockToken, address(this));
        SafeRules.RuleParams memory depositRule = BaseRules.getDepositRule(mockContract, user);

        // Make sure rules are active
        approvalRule.rule.isActive = true;
        depositRule.rule.isActive = true;

        SafeRules.RuleParams[] memory ruleParams = new SafeRules.RuleParams[](2);
        ruleParams[0] = approvalRule;
        ruleParams[1] = depositRule;

        vm.startPrank(processorManager);
        SafeRules.setProcessorRules(IVault(address(safeguard)), ruleParams, true);
        vm.stopPrank();

        // Verify the rules were set correctly
        IVault.FunctionRule memory retrievedRule =
            safeguard.getProcessorRule(depositRule.contractAddress, depositRule.funcSig);
        assertEq(retrievedRule.isActive, true);

        // Create transaction data for the active rule (deposit function)
        // The first parameter is uint256 amount, second is address receiver
        bytes memory txData = abi.encodeWithSelector(depositRule.funcSig, 1000, user);

        // This should not revert since the rule is active and parameters match the allowed values
        safeguard.checkTransaction(
            depositRule.contractAddress, // to
            0, // value
            txData, // data
            Enum.Operation.Call, // operation
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            payable(address(0)), // refundReceiver
            bytes(""), // signatures
            address(this) // executor
        );

        // Also test the approval rule
        bytes memory approvalData = abi.encodeWithSelector(approvalRule.funcSig, address(this), 500);

        // This should also not revert
        safeguard.checkTransaction(
            approvalRule.contractAddress, // to
            0, // value
            approvalData, // data
            Enum.Operation.Call, // operation
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            payable(address(0)), // refundReceiver
            bytes(""), // signatures
            address(this) // executor
        );
    }
}
