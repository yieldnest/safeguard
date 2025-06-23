// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseDeploySafeGuard} from "../BaseDeploySafeGuard.s.sol";
import {AutoETHRules} from "../rules/AutoETHRules.sol";
import {SafeRules} from "lib/yieldnest-vault/script/rules/SafeRules.sol";
import {BaseRules} from "lib/yieldnest-vault/script/rules/BaseRules.sol";
import {MainnetContracts as MC} from "lib/yieldnest-vault/script/Contracts.sol";
import {console} from "forge-std/Script.sol";
import {IVault} from "lib/yieldnest-vault/src/interface/IVault.sol";

 // To run this script:
 // forge script scripts/deployment/DeployTokemakSafeGuard.s.sol --sig "run(string)" \
 // ${path} --rpc-url <RPC_URL> \
// --account ${deployerAccountName} --sender ${deployer} \
// --broadcast --etherscan-api-key ${api} --verify
/**
 * @title DeployTokemakSafeGuard
 * @notice Script to deploy the SafeGuard contract with Tokemak-specific rules
 */
contract DeployTokemakSafeGuard is BaseDeploySafeGuard {

    // Tokemak contract addresses for mainnet (these would be set based on the network)
    address constant AUTOETH_TOKEN = 0x0A2b94F6871c1D7A32Fe58E1ab5e6deA2f114E56;
    address constant AUTOETH_REWARDER = 0x60882D6f70857606Cdd37729ccCe882015d1755E;
    address constant AUTOPILOT_ROUTER = 0x39ff6d21204B919441d17bef61D19181870835A2;
    address public constant TOKE = 0x2e9d63788249371f1DFC918a52f8d799F4a38C94;

    // TODO: set AccountingModule address 
    address constant ACCOUNTING_MODULE = address(0x7E8bCCF8c3A55Fd611A928E004E132a5bD08E935);
    /**
     * @notice Sets up processor rules specific to Tokemak AutoETH operations
     */
    function setProcessorRules() internal override {
        console.log("Setting up Tokemak AutoETH processor rules...");

        require(ACCOUNTING_MODULE != address(0), "ACCOUNTING_MODULE is not set");

        // Create array to hold all rule parameters
        SafeRules.RuleParams[] memory rules = new SafeRules.RuleParams[](9);

        {
            // Rule 1: Allow approval of WETH to multiple contracts
            address[] memory spenders = new address[](3);
            spenders[0] = AUTOPILOT_ROUTER;
            spenders[1] = ACCOUNTING_MODULE;
            spenders[2] = AUTOETH_TOKEN;
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
        
        {
            address[] memory spenders = new address[](2);
            spenders[0] = AUTOPILOT_ROUTER;
            spenders[1] = AUTOETH_REWARDER;
            // Rule 5: Allow approval of AutoETH token to rewarder
            rules[4] = BaseRules.getApprovalRule(AUTOETH_TOKEN, spenders);
            console.log("Added approval rule for AutoETH token to rewarder");
        }

        // Rule 6: Allow deposit of WETH to AutoETH
        rules[5] = AutoETHRules.getDepositRule(AUTOPILOT_ROUTER, AUTOETH_TOKEN, gnosisSafeAddress);
        console.log("Added deposit rule for WETH to AutoETH");

        // Rule 7: Allow pulling WETH from safe to Autopilot Router
        rules[6] = AutoETHRules.getPullTokenRuleForWETH(AUTOPILOT_ROUTER, AUTOETH_TOKEN, MC.WETH);
        console.log("Added pull token rule for WETH to AutoETH");

        // Rule 8: Allow pulling AutoETH from safe to Autopilot Router
        rules[7] = AutoETHRules.getPullTokenRuleForAutoETH(AUTOPILOT_ROUTER, AUTOPILOT_ROUTER, AUTOETH_TOKEN);
        console.log("Added pull token rule for AutoETH to Autopilot Router");
        
        {
            // Rule 9: Allow approving AutoETH to Autopilot Rewarder and WETH to AutoETH contract
            address[] memory tokenAllowList = new address[](2);
            tokenAllowList[0] = AUTOETH_TOKEN;
            tokenAllowList[1] = MC.WETH;
            address[] memory toAllowList = new address[](2);
            toAllowList[0] = AUTOETH_REWARDER;
            toAllowList[1] = AUTOETH_TOKEN;
            rules[8] = AutoETHRules.getAutopilotApproveRule(AUTOPILOT_ROUTER, tokenAllowList, toAllowList);
            console.log("Added autopilot approve rule for AutoETH to Autopilot Rewarder and WETH to AutoETH");
        }

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
