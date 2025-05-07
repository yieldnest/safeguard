// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "lib/forge-std/src/Test.sol";
import {SafeGuard} from "src/SafeGuard.sol";
import {ProxyAdmin} from "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from
    "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ISafe} from "lib/safe-smart-account/contracts/interfaces/ISafe.sol";
import {IModuleManager} from "lib/safe-smart-account/contracts/interfaces/IModuleManager.sol";
import {Enum} from "lib/safe-smart-account/contracts/libraries/Enum.sol";
import {SafeProxyFactory} from "lib/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {SafeProxy} from "lib/safe-smart-account/contracts/proxies/SafeProxy.sol";
import {Safe} from "lib/safe-smart-account/contracts/Safe.sol";

contract GnosisSafeTest is Test {
    SafeGuard implementation;
    SafeGuard safeguard;
    ProxyAdmin admin;
    address adminAddress;
    address user;
    address processorManager;

    // Gnosis Safe contracts
    Safe singleton;
    SafeProxyFactory factory;
    ISafe safe;

    // Owner addresses for the Safe
    address[] owners;
    uint256 threshold = 1;

    function setUp() public {
        // Set up accounts
        adminAddress = makeAddr("admin");
        user = makeAddr("user");
        processorManager = makeAddr("processorManager");

        // Create owner addresses for the Safe
        owners = new address[](1);
        owners[0] = user;

        // Deploy SafeGuard implementation and proxy
        implementation = new SafeGuard();
        TransparentUpgradeableProxy transparentProxy =
            new TransparentUpgradeableProxy(address(implementation), adminAddress, "");
        safeguard = SafeGuard(address(transparentProxy));
        safeguard.initialize(adminAddress);

        // Grant PROCESSOR_MANAGER_ROLE to processorManager
        vm.startPrank(adminAddress);
        safeguard.grantRole(safeguard.PROCESSOR_MANAGER_ROLE(), processorManager);
        vm.stopPrank();

        // Deploy Gnosis Safe contracts
        singleton = new Safe();
        factory = new SafeProxyFactory();

        // Deploy a new Safe
        bytes memory initializer = abi.encodeWithSelector(
            Safe.setup.selector,
            owners,
            threshold,
            address(0), // to
            bytes(""), // data
            address(0), // fallbackHandler
            address(0), // paymentToken
            0, // payment
            address(0) // paymentReceiver
        );

        SafeProxy safeProxy = factory.createProxyWithNonce(address(singleton), initializer, 0);
        safe = ISafe(address(safeProxy));
    }

    function test_AddSafeGuardAsModule() public {
        // Prepare the transaction to enable the module
        bytes memory data = abi.encodeWithSelector(IModuleManager.enableModule.selector, address(safeguard));

        vm.startPrank(user);

        // Execute the transaction to add the SafeGuard as a module
        bool success = safe.execTransaction(
            address(safe), // to
            0, // value
            data, // data
            Enum.Operation.Call, // operation
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            payable(address(0)), // refundReceiver
            "" // signatures (empty for single owner with threshold 1)
        );

        vm.stopPrank();

        // Verify the module was added successfully
        assertTrue(success, "Failed to add SafeGuard as module");
        assertTrue(safe.isModuleEnabled(address(safeguard)), "SafeGuard module not enabled");
    }
}
