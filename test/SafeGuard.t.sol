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
}
