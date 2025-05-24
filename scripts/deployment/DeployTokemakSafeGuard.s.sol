// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseDeploySafeGuard} from "../BaseDeploySafeGuard.s.sol";
import {AutoETHRules} from "../rules/AutoETHRules.sol";
import {SafeRules} from "lib/yieldnest-vault/script/rules/SafeRules.sol";
import {BaseRules} from "lib/yieldnest-vault/script/rules/BaseRules.sol";
import {MainnetContracts as MC} from "lib/yieldnest-vault/script/Contracts.sol";
import {console} from "forge-std/Script.sol";
import {IVault} from "lib/yieldnest-vault/src/interface/IVault.sol";
/**
 * @title DeployTokemakSafeGuard
 * @notice Script to deploy the SafeGuard contract with Tokemak-specific rules
 */
contract DeployTokemakSafeGuard is BaseDeploySafeGuard {

    // Tokemak contract addresses (these would be set based on the network)
    address constant AUTOETH_VAULT = 0x1234567890123456789012345678901234567890; // Replace with actual address
    address constant AUTOETH_TOKEN = 0x2345678901234567890123456789012345678901; // Replace with actual address
    address constant AUTOETH_REWARDER = 0x3456789012345678901234567890123456789012; // Replace with actual address
    address constant AUTOPILOT_ROUTER = 0x4567890123456789012345678901234567890123; // Replace with actual address

    // TODO: set AccountingModule address 
    address constant ACCOUNTING_MODULE = address(0);
    /**
     * @notice Sets up processor rules specific to Tokemak AutoETH operations
     */
    function setProcessorRules() internal override {
        console.log("Setting up Tokemak AutoETH processor rules...");

        // Create array to hold all rule parameters
        SafeRules.RuleParams[] memory rules = new SafeRules.RuleParams[](4);

        // Rule 1: Allow approval of AutoETH token to Autopilot Router
        rules[0] = BaseRules.getApprovalRule(MC.WETH, ACCOUNTING_MODULE);
        console.log("Added approval rule for AutoETH token to Autopilot Router");

        // Rule 2: Allow staking vault tokens
        rules[1] = AutoETHRules.getStakeVaultTokenRule(AUTOETH_VAULT, AUTOETH_TOKEN);
        console.log("Added stake vault token rule for AutoETH");

        // Rule 3: Allow withdrawing vault tokens
        rules[2] = AutoETHRules.getWithdrawVaultTokenRule(AUTOETH_VAULT, AUTOETH_TOKEN, AUTOETH_REWARDER);
        console.log("Added withdraw vault token rule for AutoETH");

        // Rule 4: Allow claiming autopool rewards
        rules[3] = AutoETHRules.getClaimAutopoolRewardsRule(
            AUTOPILOT_ROUTER,
            AUTOETH_VAULT,
            AUTOETH_REWARDER,
            gnosisSafeAddress
        );
        console.log("Added claim autopool rewards rule");


        {
            // Set all rules in the SafeGuard contract
            address[] memory targets = new address[](rules.length);
            bytes4[] memory functionSigs = new bytes4[](rules.length);
            IVault.FunctionRule[] memory functionRules = new IVault.FunctionRule[](rules.length);
            
            for (uint256 i = 0; i < rules.length; i++) {
                targets[i] = rules[i].contractAddress;
                functionSigs[i] = rules[i].funcSig;
                functionRules[i] = rules[i].rule;
            }
            
            safeguard.setProcessorRules(targets, functionSigs, functionRules);
        }

        console.log("All Tokemak AutoETH rules have been set for processor manager:", processorManager);
    }
}
