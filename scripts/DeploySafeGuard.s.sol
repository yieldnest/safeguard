// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {SafeGuard} from "../src/SafeGuard.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
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
contract DeploySafeGuard is Script {

    string public name;
    address public gnosisSafeAddress;
    address public admin;

    TimelockController public timelock;
    SafeGuard public safeguard;
    SafeGuard implementation;

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
            admin
        );
        
        // Deploy transparent proxy with implementation and initialization data
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(timelock),
            initData
        );

        safeguard = SafeGuard(address(proxy));
        
        // Log deployment information
        console.log("SafeGuard implementation deployed at:", address(implementation));
        console.log("TimelockController deployed at:", address(timelock));
        console.log("SafeGuard proxy deployed at:", address(proxy));
        console.log("Admin address set to:", admin);
        console.log("Timelock delay set to:", oneDay, "seconds (1 day)");
        
        vm.stopBroadcast();

        _saveDeployment();
    }


    /**
     * @notice Returns the file path for saving deployment information
     * @return The path where deployment data will be saved
     */
    function _deploymentFilePath() internal view returns (string memory) {
        string memory deploymentsDir = "deployments";
        
        return string.concat(
            deploymentsDir,
            "/",
            name,
            "-",
            vm.toString(block.chainid),
            ".json"
        );
    }

    function _loadInput(string calldata _inputPath) internal {
        string memory json = vm.readFile(_inputPath);
        // Parse the input file and set global variables
        gnosisSafeAddress = abi.decode(vm.parseJson(json, ".gnosisSafeAddress"), (address));
        admin = abi.decode(vm.parseJson(json, ".admin"), (address));
        // Parse the name from the input file
        name = abi.decode(vm.parseJson(json, ".name"), (string));
        
        require(bytes(name).length > 0, "Invalid name");
     
        // Validate input
        require(gnosisSafeAddress != address(0), "Invalid Gnosis Safe address");
        require(admin != address(0), "Invalid admin address");
        
        console.log("Loaded input configuration:");
        // Parse chain ID from input file
        uint256 chainId = abi.decode(vm.parseJson(json, ".chainId"), (uint256));   
        // Validate chain ID
        require(chainId > 0, "Invalid chain ID");
        require(chainId == block.chainid, "Chain ID mismatch: deployment is on the wrong network"); 
        console.log("Name:", name);
        console.log("Chain ID:", chainId);
        console.log("Gnosis Safe address:", gnosisSafeAddress);
        console.log("Admin address:", admin);
    }


    function _saveDeployment() internal virtual {
        string memory root = "";
        vm.serializeString(root, "name", name);
        vm.serializeAddress(root, "deployer", msg.sender);
        vm.serializeAddress(root, "admin", admin);
        vm.serializeAddress(root, "gnosisSafeAddress", gnosisSafeAddress);
        
        vm.serializeAddress(root, "safeguard-proxyAdmin", ProxyUtils.getProxyAdmin(address(safeguard)));
        vm.serializeAddress(root, "safeguard-proxy", address(safeguard));
        
        string memory jsonOutput =
            vm.serializeAddress(root, "safeguard-implementation", address(implementation));

        vm.writeJson(jsonOutput, _deploymentFilePath());
    }
}
