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
        address[] memory targets = new address[](2);
        bytes4[] memory functionSigs = new bytes4[](2);
        IVault.FunctionRule[] memory rules = new IVault.FunctionRule[](2);

        // Create sample targets
        address mockContract = address(0x1234);
        address mockToken = address(0x5678);

        // Use BaseRules to get predefined rules
        SafeRules.RuleParams memory approvalRule = BaseRules.getApprovalRule(mockToken, address(this));

        SafeRules.RuleParams memory depositRule = BaseRules.getDepositRule(mockContract, user);

        // Set up the targets and function signatures from the rules
        targets[0] = approvalRule.contractAddress;
        targets[1] = depositRule.contractAddress;

        functionSigs[0] = approvalRule.funcSig;
        functionSigs[1] = depositRule.funcSig;

        // Define the rules with specific parameters
        rules[0] = IVault.FunctionRule({
            isActive: true,
            paramRules: new IVault.ParamRule[](0),
            validator: IValidator(address(0))
        });

        rules[1] = IVault.FunctionRule({
            isActive: true,
            paramRules: new IVault.ParamRule[](0),
            validator: IValidator(address(0))
        });
        // Set the processor rules
        vm.prank(processorManager);
        safeguard.setProcessorRules(targets, functionSigs, rules);

        // Verify the rules were set correctly
        IVault.FunctionRule memory retrievedRule0 = safeguard.getProcessorRule(targets[0], functionSigs[0]);
        IVault.FunctionRule memory retrievedRule1 = safeguard.getProcessorRule(targets[1], functionSigs[1]);

        // Assert rule 0 properties (approval rule)
        assertEq(retrievedRule0.isActive, true);
        assertEq(address(retrievedRule0.validator), address(0));
        assertEq(retrievedRule0.paramRules.length, 0);

        // Assert rule 1 properties (deposit rule)
        assertEq(retrievedRule1.isActive, true);
        assertEq(address(retrievedRule1.validator), address(0));
        assertEq(retrievedRule1.paramRules.length, 0);
    }
}
