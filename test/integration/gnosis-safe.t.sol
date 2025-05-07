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
import {MockERC20} from "lib/yieldnest-vault/test/unit/mocks/MockERC20.sol";
import {MockERC4626} from "lib/yieldnest-vault/test/mainnet/mocks/MockERC4626.sol";
import {IVault} from "lib/yieldnest-vault/src/interface/IVault.sol";
import {SafeRules} from "lib/yieldnest-vault/script/rules/SafeRules.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IValidator} from "lib/yieldnest-vault/src/interface/IValidator.sol";
import {BaseRules} from "lib/yieldnest-vault/script/rules/BaseRules.sol";
import {Guard} from "lib/yieldnest-vault/src/module/Guard.sol";

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
    
    // Mock tokens
    MockERC20 mockToken;
    MockERC4626 mockVault;

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

        // Deploy mock tokens
        mockToken = new MockERC20("Mock Token", "MTK");
        mockVault = new MockERC4626(mockToken, "Mock Vault", "MVT");
        
        addSafeGuardAsModule();

        // Set up rules for approve and deposit
        vm.startPrank(processorManager);
        
        // Create rule for token approval using BaseRules
        SafeRules.RuleParams memory approvalRule = BaseRules.getApprovalRule(address(mockToken), address(mockVault));
        
        // Create rule for deposit
        SafeRules.RuleParams memory depositRule = BaseRules.getDepositRule(address(mockVault), address(safe));
        
        // Prepare array of rules
        SafeRules.RuleParams[] memory ruleParams = new SafeRules.RuleParams[](2);
        ruleParams[0] = approvalRule;
        ruleParams[1] = depositRule;
        
        // Set the rules in the SafeGuard using the library function
        SafeRules.setProcessorRules(IVault(address(safeguard)), ruleParams, true);
        vm.stopPrank();
    }

    function addSafeGuardAsModule() public {
        {
            // Prepare the transaction to enable the module
            bytes memory data = abi.encodeWithSelector(IModuleManager.enableModule.selector, address(safeguard));
            
            // Execute the transaction and verify the module was added successfully
            bool success = executeTransaction(address(safe), 0, data, Enum.Operation.Call);
            assertTrue(success, "Failed to add SafeGuard as module");
            assertTrue(safe.isModuleEnabled(address(safeguard)), "SafeGuard module not enabled");
        }


        {
            bytes memory data = abi.encodeWithSelector(IModuleManager.setModuleGuard.selector, address(safeguard));
            
            // Execute the transaction and verify the module guard was set successfully
            bool success = executeTransaction(address(safe), 0, data, Enum.Operation.Call);
            assertTrue(success, "Failed to set SafeGuard as module guard");
        }
        // Prepare the transaction to set the module guard

    }
    
    function executeTransaction(address to, uint256 value, bytes memory data, Enum.Operation operation, bytes memory revertData) 
        internal returns (bool success) 
    {
        vm.startPrank(user);
        
        // Create signature for the transaction
        bytes memory signature = abi.encodePacked(
            uint256(uint160(user)),
            uint256(0),
            uint8(1)
        );
        
        // Execute the transaction
        if (revertData.length > 0) {
            vm.expectRevert(revertData);
        }
        success = safe.execTransaction(
            to,
            value,
            data,
            operation,
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            payable(address(0)), // refundReceiver
            signature // signatures
        );
        
        vm.stopPrank();
        return success;
    }

    function executeTransaction(address to, uint256 value, bytes memory data, Enum.Operation operation) 
        internal returns (bool success) 
    {
        return executeTransaction(to, value, data, operation, new bytes(0));
    }

    function test_executeTransaction() public {

        // Mint mock tokens to the Gnosis Safe
        uint256 mintAmount = 1000 * 10**18; // 1000 tokens
        vm.prank(address(safe));
        mockToken.mint(mintAmount);
        assertEq(mockToken.balanceOf(address(safe)), mintAmount, "Safe should have received tokens");
        
        
        // Execute approve transaction
        uint256 approveAmount = 500 * 10**18; // 500 tokens
        bytes memory approveData = abi.encodeWithSelector(
            IERC20.approve.selector,
            address(mockVault),
            approveAmount
        );
        
        bool approveSuccess = executeTransaction(
            address(mockToken),
            0,
            approveData,
            Enum.Operation.Call
        );
        assertTrue(approveSuccess, "Approve transaction failed");
        assertEq(
            mockToken.allowance(address(safe), address(mockVault)),
            approveAmount,
            "Allowance not set correctly"
        );
        
        // Execute deposit transaction
        uint256 depositAmount = 300 * 10**18; // 300 tokens
        bytes memory depositData = abi.encodeWithSelector(
            IERC4626.deposit.selector,
            depositAmount,
            address(safe)
        );
        
        bool depositSuccess = executeTransaction(
            address(mockVault),
            0,
            depositData,
            Enum.Operation.Call
        );
        assertTrue(depositSuccess, "Deposit transaction failed");
        
        // Verify deposit was successful
        assertEq(
            mockToken.balanceOf(address(safe)),
            mintAmount - depositAmount,
            "Token balance should be reduced after deposit"
        );
        assertGt(
            mockVault.balanceOf(address(safe)),
            0,
            "Safe should have received vault shares"
        );
    }

    function test_RevertWhenReceiverIsRandomAddress() public {
        // Setup: Deploy contracts and mint tokens
        address randomAddress = makeAddr("random");
        uint256 mintAmount = 1000 * 10**18;
        vm.prank(address(safe));
        mockToken.mint(mintAmount);
        assertEq(mockToken.balanceOf(address(safe)), mintAmount, "Safe should have received tokens");
        
        // Try to execute approve transaction with random address as receiver
        uint256 approveAmount = 500 * 10**18;
        bytes memory approveData = abi.encodeWithSelector(
            IERC20.approve.selector,
            randomAddress,
            approveAmount
        );
        

        executeTransaction(
            address(mockToken),
            0,
            approveData,
            Enum.Operation.Call
        );
        
        // Try to execute transfer transaction to random address
        bytes memory transferData = abi.encodeWithSelector(
            IERC20.transfer.selector,
            randomAddress,
            approveAmount
        );
        
        executeTransaction(
            address(mockToken),
            0,
            transferData,
            Enum.Operation.Call,
            abi.encodeWithSelector(Guard.RuleNotActive.selector, address(mockToken), IERC20.approve.selector)
        );
        
        // Verify no tokens were transferred
        assertEq(
            mockToken.balanceOf(randomAddress),
            0,
            "Random address should not receive any tokens"
        );
        assertEq(
            mockToken.balanceOf(address(safe)),
            mintAmount,
            "Safe's token balance should remain unchanged"
        );
    }
}
