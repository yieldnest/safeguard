// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {SafeGuard} from "src/SafeGuard.sol";
import {Test} from "forge-std/Test.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ProxyUtils} from "lib/yieldnest-vault/script/ProxyUtils.sol";
import {BaseScript} from "scripts/BaseScript.s.sol";
import {ProxyUtils} from "lib/yieldnest-vault/script/ProxyUtils.sol";


 // To run this script:
 // forge script scripts/DeploySafeGuard.s.sol --sig "run(string calldata)" \
 // ${path} --rpc-url https://rpc.ankr.com/eth_holesky \
// --account ${deployerAccountName} --sender ${deployer} \
// --broadcast --etherscan-api-key ${api} --verify
/**
 * @title DeploySafeGuard
 * @notice Script to deploy the SafeGuard contract with a transparent proxy and timelock controller
 */
contract VerifySafeGuard is BaseScript, Test {

    function run(string calldata _jsonPath) external {
        _loadInput(_jsonPath);
        _loadDeployment();

        // Assert that the proxy admin is correctly set;
        assertEq(ProxyUtils.getProxyAdmin(address(safeguard)), address(proxyAdmin), "Proxy admin is not set correctly");

        // Assert that the implementation is correctly set
        assertEq(ProxyUtils.getImplementation(address(safeguard)), address(implementation), "Implementation is not set correctly");

        // Assert that the admin has DEFAULT_ADMIN_ROLE
        assertTrue(safeguard.hasRole( safeguard.DEFAULT_ADMIN_ROLE(), admin), "Admin does not have DEFAULT_ADMIN_ROLE");
        
        console.log("Verification successful: Admin has DEFAULT_ADMIN_ROLE");

        // Assert that the timelock is the owner of the proxy admin
        // Assert that the timelock is the owner of the proxy admin
        assertEq(ProxyAdmin(proxyAdmin).owner(), address(timelock), "Timelock is not the owner of the proxy admin");
        
        console.log("Verification successful: Timelock is the owner of the proxy admin");

        // Assert that the timelock has 1 day min delay
        uint256 expectedDelay = 1 days;
        assertEq(timelock.getMinDelay(), expectedDelay, "Timelock delay is not set to 1 day");
        console.log("Verification successful: Timelock has 1 day minimum delay");
        
        // Assert that the admin has the proposer role in the timelock
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), admin), "Admin does not have PROPOSER_ROLE");
        console.log("Verification successful: Admin has PROPOSER_ROLE in timelock");
        
        // Assert that the admin has the executor role in the timelock
        assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), admin), "Admin does not have EXECUTOR_ROLE");
        console.log("Verification successful: Admin has EXECUTOR_ROLE in timelock");
        
        // Assert that the admin has the timelock admin role
        assertTrue(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), admin), "Admin does not have TIMELOCK_ADMIN_ROLE");
        console.log("Verification successful: Admin has TIMELOCK_ADMIN_ROLE");
    }
}