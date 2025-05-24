// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {IVault, IValidator} from "lib/yieldnest-vault/src/interface/IVault.sol";
import {SafeRules} from "lib/yieldnest-vault/script/rules/SafeRules.sol";
import {IAutopilotRouter} from "src/interfaces/tokemak/IAutopilotRouter.sol";

library AutoETHRules {

    function getClaimAutopoolRewardsRule(address contractAddress, address vault, address rewarder, address recipient)
        internal
        pure
        returns (SafeRules.RuleParams memory)
    {
        bytes4 funcSig = bytes4(keccak256("claimAutopoolRewards(address,address,address)"));

        IVault.ParamRule[] memory paramRules = new IVault.ParamRule[](3);

        address[] memory vaultAllowList = new address[](1);
        vaultAllowList[0] = vault;
        paramRules[0] = IVault.ParamRule({paramType: IVault.ParamType.ADDRESS, isArray: false, allowList: vaultAllowList});

        address[] memory rewarderAllowList = new address[](1);
        rewarderAllowList[0] = rewarder;
        paramRules[1] = IVault.ParamRule({paramType: IVault.ParamType.ADDRESS, isArray: false, allowList: rewarderAllowList});

        address[] memory recipientAllowList = new address[](1);
        recipientAllowList[0] = recipient;
        paramRules[2] = IVault.ParamRule({paramType: IVault.ParamType.ADDRESS, isArray: false, allowList: recipientAllowList});

        IVault.FunctionRule memory rule =
            IVault.FunctionRule({isActive: true, paramRules: paramRules, validator: IValidator(address(0))});

        return SafeRules.RuleParams({contractAddress: contractAddress, funcSig: funcSig, rule: rule});
    }

    function getDepositRule(address contractAddress, address vault, address to)
        internal
        pure
        returns (SafeRules.RuleParams memory)
    {
        bytes4 funcSig = bytes4(keccak256("deposit(address,address,uint256,uint256)"));

        IVault.ParamRule[] memory paramRules = new IVault.ParamRule[](4);

        address[] memory vaultAllowList = new address[](1);
        vaultAllowList[0] = vault;
        paramRules[0] = IVault.ParamRule({paramType: IVault.ParamType.ADDRESS, isArray: false, allowList: vaultAllowList});

        address[] memory toAllowList = new address[](1);
        toAllowList[0] = to;
        paramRules[1] = IVault.ParamRule({paramType: IVault.ParamType.ADDRESS, isArray: false, allowList: toAllowList});

        paramRules[2] =
            IVault.ParamRule({paramType: IVault.ParamType.UINT256, isArray: false, allowList: new address[](0)});

        paramRules[3] =
            IVault.ParamRule({paramType: IVault.ParamType.UINT256, isArray: false, allowList: new address[](0)});

        IVault.FunctionRule memory rule =
            IVault.FunctionRule({isActive: true, paramRules: paramRules, validator: IValidator(address(0))});

        return SafeRules.RuleParams({contractAddress: contractAddress, funcSig: funcSig, rule: rule});
    }

    function getRedeemRule(address contractAddress, address vault, address to)
        internal
        pure
        returns (SafeRules.RuleParams memory)
    {
        bytes4 funcSig = bytes4(keccak256("redeem(address,address,uint256,uint256)"));

        IVault.ParamRule[] memory paramRules = new IVault.ParamRule[](4);

        address[] memory vaultAllowList = new address[](1);
        vaultAllowList[0] = vault;
        paramRules[0] = IVault.ParamRule({paramType: IVault.ParamType.ADDRESS, isArray: false, allowList: vaultAllowList});

        address[] memory toAllowList = new address[](1);
        toAllowList[0] = to;
        paramRules[1] = IVault.ParamRule({paramType: IVault.ParamType.ADDRESS, isArray: false, allowList: toAllowList});

        paramRules[2] =
            IVault.ParamRule({paramType: IVault.ParamType.UINT256, isArray: false, allowList: new address[](0)});

        paramRules[3] =
            IVault.ParamRule({paramType: IVault.ParamType.UINT256, isArray: false, allowList: new address[](0)});

        IVault.FunctionRule memory rule =
            IVault.FunctionRule({isActive: true, paramRules: paramRules, validator: IValidator(address(0))});

        return SafeRules.RuleParams({contractAddress: contractAddress, funcSig: funcSig, rule: rule});
    }

    function getAutopilotApproveRule(address contractAddress, address token, address to)
        internal
        pure
        returns (SafeRules.RuleParams memory)
    {
        bytes4 funcSig = bytes4(keccak256("approve(address,address,uint256)"));

        IVault.ParamRule[] memory paramRules = new IVault.ParamRule[](3);

        address[] memory tokenAllowList = new address[](1);
        tokenAllowList[0] = token;
        paramRules[0] = IVault.ParamRule({paramType: IVault.ParamType.ADDRESS, isArray: false, allowList: tokenAllowList});

        address[] memory toAllowList = new address[](1);
        toAllowList[0] = to;
        paramRules[1] = IVault.ParamRule({paramType: IVault.ParamType.ADDRESS, isArray: false, allowList: toAllowList});

        paramRules[2] =
            IVault.ParamRule({paramType: IVault.ParamType.UINT256, isArray: false, allowList: new address[](0)});

        IVault.FunctionRule memory rule =
            IVault.FunctionRule({isActive: true, paramRules: paramRules, validator: IValidator(address(0))});

        return SafeRules.RuleParams({contractAddress: contractAddress, funcSig: funcSig, rule: rule});
    }

    function getStakeVaultTokenRule(address contractAddress, address token)
        internal
        pure
        returns (SafeRules.RuleParams memory)
    {
        bytes4 funcSig = bytes4(keccak256("stakeVaultToken(address,uint256)"));

        IVault.ParamRule[] memory paramRules = new IVault.ParamRule[](2);

        address[] memory tokenAllowList = new address[](1);
        tokenAllowList[0] = token;
        paramRules[0] = IVault.ParamRule({paramType: IVault.ParamType.ADDRESS, isArray: false, allowList: tokenAllowList});

        paramRules[1] =
            IVault.ParamRule({paramType: IVault.ParamType.UINT256, isArray: false, allowList: new address[](0)});

        IVault.FunctionRule memory rule =
            IVault.FunctionRule({isActive: true, paramRules: paramRules, validator: IValidator(address(0))});

        return SafeRules.RuleParams({contractAddress: contractAddress, funcSig: funcSig, rule: rule});
    }

    function getWithdrawVaultTokenRule(address contractAddress, address token, address rewarder)
        internal
        pure
        returns (SafeRules.RuleParams memory)
    {
        bytes4 funcSig = bytes4(keccak256("withdrawVaultToken(address,address,uint256,bool)"));

        IVault.ParamRule[] memory paramRules = new IVault.ParamRule[](4);

        address[] memory tokenAllowList = new address[](1);
        tokenAllowList[0] = token;
        paramRules[0] = IVault.ParamRule({paramType: IVault.ParamType.ADDRESS, isArray: false, allowList: tokenAllowList});

        address[] memory rewarderAllowList = new address[](1);
        rewarderAllowList[0] = rewarder;
        paramRules[1] = IVault.ParamRule({paramType: IVault.ParamType.ADDRESS, isArray: false, allowList: rewarderAllowList});

        paramRules[2] =
            IVault.ParamRule({paramType: IVault.ParamType.UINT256, isArray: false, allowList: new address[](0)});

        // no rule for bool
        paramRules[3] =
            IVault.ParamRule({paramType: IVault.ParamType.UINT256, isArray: false, allowList: new address[](0)});

        IVault.FunctionRule memory rule =
            IVault.FunctionRule({isActive: true, paramRules: paramRules, validator: IValidator(address(0))});

        return SafeRules.RuleParams({contractAddress: contractAddress, funcSig: funcSig, rule: rule});
    }
}