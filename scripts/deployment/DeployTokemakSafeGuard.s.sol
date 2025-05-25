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
    address constant AUTOETH_TOKEN = 0x0A2b94F6871c1D7A32Fe58E1ab5e6deA2f114E56;
    address constant AUTOETH_REWARDER = 0x60882D6f70857606Cdd37729ccCe882015d1755E;
    address constant AUTOPILOT_ROUTER = 0x37dD409f5e98aB4f151F4259Ea0CC13e97e8aE21;

    // TODO: set AccountingModule address 
    address constant ACCOUNTING_MODULE = address(0);
    /**
     * @notice Sets up processor rules specific to Tokemak AutoETH operations
     */
    function setProcessorRules() internal override {
        console.log("Setting up Tokemak AutoETH processor rules...");

        // Create array to hold all rule parameters
        SafeRules.RuleParams[] memory rules = new SafeRules.RuleParams[](5);

        {
            // Rule 1: Allow approval of WETH to multiple contracts
            address[] memory spenders = new address[](2);
            spenders[0] = AUTOPILOT_ROUTER;
            spenders[1] = ACCOUNTING_MODULE;
            rules[0] = BaseRules.getApprovalRule(MC.WETH, spenders);
        }

        console.log("Added approval rule for WETH to Autopilot Router and Accounting Module");

        // Rule 2: Allow staking vault tokens
        rules[1] = AutoETHRules.getStakeVaultTokenRule(AUTOPILOT_ROUTER, AUTOETH_TOKEN);
        console.log("Added stake vault token rule for AutoETH");

        // Rule 3: Allow withdrawing vault tokens
        rules[2] = AutoETHRules.getWithdrawVaultTokenRule(AUTOPILOT_ROUTER, AUTOETH_TOKEN, AUTOETH_REWARDER);
        console.log("Added withdraw vault token rule for AutoETH");

        // Rule 4: Allow claiming autopool rewards
        rules[3] = AutoETHRules.getClaimAutopoolRewardsRule(
            AUTOPILOT_ROUTER,
            AUTOETH_TOKEN,
            AUTOETH_REWARDER,
            gnosisSafeAddress
        );
        console.log("Added claim autopool rewards rule");

        // Rule 5: Allow approval of AutoETH token to rewarder
        rules[4] = BaseRules.getApprovalRule(AUTOETH_TOKEN, AUTOETH_REWARDER);
        console.log("Added approval rule for AutoETH token to rewarder");

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
