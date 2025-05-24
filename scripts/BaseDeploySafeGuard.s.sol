// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {SafeGuard} from "../src/SafeGuard.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ProxyUtils} from "lib/yieldnest-vault/script/ProxyUtils.sol";
import {BaseScript} from "./BaseScript.s.sol";


 // To run this script:
 // forge script scripts/DeploySafeGuard.s.sol --sig "run(string calldata)" \
 // ${path} --rpc-url https://rpc.ankr.com/eth_holesky \
// --account ${deployerAccountName} --sender ${deployer} \
// --broadcast --etherscan-api-key ${api} --verify
/**
 * @title DeploySafeGuard
 * @notice Script to deploy the SafeGuard contract with a transparent proxy and timelock controller
 */
abstract contract BaseDeploySafeGuard is BaseScript {

    function setProcessorRules() internal virtual;

    function _deployTimelockController(
        address proposer,
        address executor,
        address _admin,
        uint256 minDelay
    ) internal virtual returns (TimelockController) {
        address[] memory proposers = new address[](1);
        proposers[0] = proposer;

        address[] memory executors = new address[](1);
        executors[0] = executor;

        return new TimelockController(minDelay, proposers, executors, _admin);
    }


    function run(string calldata _jsonPath) external {
        _loadInput(_jsonPath);
        // Start broadcasting transactions
        vm.startBroadcast();
        
        // Deploy implementation contract
        implementation = new SafeGuard();
        
        // Deploy TimelockController with 1 day delay
        uint256 oneDay = 1 days;
        
        timelock = _deployTimelockController(
            admin,
            admin,
            admin,
            oneDay
        );
        
        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            SafeGuard.initialize.selector,
            msg.sender
        );
        
        // Deploy transparent proxy with implementation and initialization data
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(timelock),
            initData
        );

        safeguard = SafeGuard(address(proxy));
        
        safeguard.grantRole(safeguard.DEFAULT_ADMIN_ROLE(), admin);
        safeguard.grantRole(safeguard.PROCESSOR_MANAGER_ROLE(), msg.sender);

        setProcessorRules();

        // Revoke admin role from msg.sender and grant it to the admin
        safeguard.revokeRole(safeguard.DEFAULT_ADMIN_ROLE(), msg.sender);


        vm.stopBroadcast();

        // Log deployment information
        console.log("SafeGuard implementation deployed at:", address(implementation));
        console.log("TimelockController deployed at:", address(timelock));
        console.log("SafeGuard proxy deployed at:", address(proxy));
        console.log("Admin address set to:", address(timelock));
        console.log("Timelock delay set to:", oneDay, "seconds (1 day)");
        _saveDeployment();
    }
}
