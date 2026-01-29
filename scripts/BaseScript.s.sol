// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {SafeGuard} from "../src/SafeGuard.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ProxyUtils} from "lib/yieldnest-vault/script/ProxyUtils.sol";

/**
 * @title BaseScript
 * @notice Base script with common utilities for SafeGuard deployment and verification
 */
abstract contract BaseScript is Script {

    string public name;
    address public gnosisSafeAddress;
    address public admin;

    TimelockController public timelock;
    SafeGuard public safeguard;
    ProxyAdmin public proxyAdmin;
    SafeGuard implementation;

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

    /**
     * @notice Load input configuration by name (looks for scripts/inputs/{name}.json)
     * @param _name The deployment name
     */
    function _loadInputByName(string calldata _name) internal {
        name = _name;
        require(bytes(name).length > 0, "Invalid name");

        string memory inputPath = string.concat("scripts/inputs/", _name, ".json");
        string memory json = vm.readFile(inputPath);

        // Parse the input file and set global variables
        gnosisSafeAddress = abi.decode(vm.parseJson(json, ".gnosisSafeAddress"), (address));
        admin = abi.decode(vm.parseJson(json, ".admin"), (address));

        // Validate input
        require(gnosisSafeAddress != address(0), "Invalid Gnosis Safe address");
        require(admin != address(0), "Invalid admin address");

        console.log("Loaded input configuration:");
        // Parse chain ID from input file
        uint256 chainId = abi.decode(vm.parseJson(json, ".chainId"), (uint256));
        // Validate chain ID
        require(chainId > 0, "Invalid chain ID");
        require(chainId == block.chainid, string.concat("Chain ID mismatch: expected ", vm.toString(chainId), ", got ", vm.toString(block.chainid)));
        console.log("Name:", name);
        console.log("Chain ID:", chainId);
        console.log("Gnosis Safe address:", gnosisSafeAddress);
        console.log("Admin address:", admin);
    }

    /**
     * @notice Load input from a full file path
     * @param _inputPath The full path to the input JSON file
     */
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
        require(chainId == block.chainid, string.concat("Chain ID mismatch: expected ", vm.toString(chainId), ", got ", vm.toString(block.chainid)));
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
        vm.serializeAddress(root, "timelock", address(timelock));

        string memory jsonOutput =
            vm.serializeAddress(root, "safeguard-implementation", address(implementation));

        vm.writeJson(jsonOutput, _deploymentFilePath());
        console.log("Deployment saved to:", _deploymentFilePath());
    }

    /**
     * @notice Load deployment from a file path
     * @param _deploymentPath The path to the deployment JSON file
     */
    function _loadDeploymentFromPath(string memory _deploymentPath) internal virtual {
        string memory json = vm.readFile(_deploymentPath);
        // Parse the deployment data
        name = abi.decode(vm.parseJson(json, ".name"), (string));
        admin = abi.decode(vm.parseJson(json, ".admin"), (address));
        gnosisSafeAddress = abi.decode(vm.parseJson(json, ".gnosisSafeAddress"), (address));

        proxyAdmin = ProxyAdmin(abi.decode(vm.parseJson(json, ".safeguard-proxyAdmin"), (address)));
        address proxy = abi.decode(vm.parseJson(json, ".safeguard-proxy"), (address));
        address implementationAddr = abi.decode(vm.parseJson(json, ".safeguard-implementation"), (address));

        // Load the timelock controller address
        address timelockAddr = abi.decode(vm.parseJson(json, ".timelock"), (address));
        timelock = TimelockController(payable(timelockAddr));

        // Set the contract instances
        safeguard = SafeGuard(proxy);
        implementation = SafeGuard(implementationAddr);

        console.log("Loaded deployment from:", _deploymentPath);
        console.log("Name:", name);
        console.log("Admin:", admin);
        console.log("Proxy:", address(safeguard));
        console.log("Implementation:", address(implementation));
        console.log("ProxyAdmin:", address(proxyAdmin));
        console.log("Timelock:", address(timelock));
    }

    /**
     * @notice Load deployment using name (constructs path from name + chainId)
     */
    function _loadDeployment() internal virtual {
        _loadDeploymentFromPath(_deploymentFilePath());
    }
}
