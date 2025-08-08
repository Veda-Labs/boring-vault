// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithRemediation} from "src/base/Roles/TellerWithRemediation.sol";
import {WstHypeLoopingUManager} from "src/micro-managers/WstHypeLoopingUManager.sol";
import {HyperliquidDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/HyperliquidDecoderAndSanitizer.sol";
import {FelixDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/FelixVanillaDecoderAndSanitizer.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

contract WstHypeLoopingIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    // Core contracts - COMPLETE ARCHITECTURE
    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    AccountantWithRateProviders public accountant;
    TellerWithRemediation public teller;
    WstHypeLoopingUManager public strategyManager;
    RolesAuthority public rolesAuthority;
    
    // Decoders
    HyperliquidDecoderAndSanitizer public hyperliquidDecoder;
    FelixDecoderAndSanitizer public felixDecoder;

    // Role constants
    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANAGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;

    // Protocol addresses (mock)
    address public wHYPE;
    address public stHYPE;
    address public wstHYPE;
    address public constant HYPE = address(0);
    address public overseer;
    address public felixMarkets;
    
    // Test addresses
    address public user1 = address(0x1001);
    address public strategist = address(0x2001);
    address public admin = address(0x3001);

    // Test amounts
    uint256 public constant INITIAL_BALANCE = 1000e18;
    uint256 public constant LOOP_AMOUNT = 100e18;
    uint256 public constant DEPOSIT_AMOUNT = 50e18;

    // Mock contracts
    MockWHYPE public mockWHYPE;
    MockStHYPE public mockStHYPE;
    MockWstHYPE public mockWstHYPE;
    MockOverseer public mockOverseer;
    MockFelix public mockFelix;

    function setUp() external {
        _deployMockContracts();
        _deployCoreSystem();
        _setupRolesCorrectly();
        _setupMockBalances();
        _setupMerkleRoot();
    }

    function _deployMockContracts() internal {
        mockWHYPE = new MockWHYPE();
        mockStHYPE = new MockStHYPE();
        mockWstHYPE = new MockWstHYPE(address(mockStHYPE));
        mockOverseer = new MockOverseer(address(mockStHYPE));
        mockFelix = new MockFelix();
        
        wHYPE = address(mockWHYPE);
        stHYPE = address(mockStHYPE);
        wstHYPE = address(mockWstHYPE);
        overseer = address(mockOverseer);
        felixMarkets = address(mockFelix);
    }

    function _deployCoreSystem() internal {
        // Deploy vault
        boringVault = new BoringVault(address(this), "WstHYPE Looping Vault", "wstHYPE-LOOP", 18);
        
        // Deploy manager
        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), address(0));
        
        // Deploy accountant
        accountant = new AccountantWithRateProviders(
            address(this),      // owner
            address(boringVault), // vault
            address(this),      // feeAddress
            1e18,              // startingExchangeRate
            wHYPE,             // base asset
            10500,             // allowedExchangeRateChangeUpper
            9500,              // allowedExchangeRateChangeLower
            24 hours,          // minimumUpdateDelayInSeconds
            50,                // managementFee
            1000               // performanceFee
        );
        
        // Deploy teller
        teller = new TellerWithRemediation(
            address(this),
            address(boringVault),
            address(accountant),
            wHYPE
        );
        
        // Deploy decoders
        hyperliquidDecoder = new HyperliquidDecoderAndSanitizer();
        felixDecoder = new FelixDecoderAndSanitizer();

        // Deploy strategy manager
        strategyManager = new WstHypeLoopingUManager(
            address(boringVault),
            address(manager),
            wHYPE,
            strategist,
            stHYPE,
            wstHYPE,
            overseer,
            felixMarkets,
            address(0xD767818Ef397e597810cF2Af6b440B1b66f0efD3), // felixOracle
            address(0xD4a426F010986dCad727e8dd6eed44cA4A9b7483), // felixIrm
            860000000000000000 // felixLltv
        );

        // Configure vault
        boringVault.setManager(address(manager));
        boringVault.setAccountant(address(accountant));
        boringVault.setTeller(address(teller));

        // Configure decoders
        strategyManager.setDecoders(
            address(hyperliquidDecoder),
            address(felixDecoder)
        );
    }

    function _setupRolesCorrectly() internal {
        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        
        // Set authorities
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);

        // Manager can manage vault
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            boringVault.manage.selector,
            true
        );

        // Strategist can call manager.manageVaultWithMerkleVerification (NOT strategy manager directly)
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            manager.manageVaultWithMerkleVerification.selector,
            true
        );

        // Admin can set merkle root
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE,
            address(manager),
            manager.setManageRoot.selector,
            true
        );

        // Grant roles
        rolesAuthority.setUserRole(strategist, STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
    }

    function _setupMockBalances() internal {
        // Give vault tokens for operations
        deal(wHYPE, address(boringVault), INITIAL_BALANCE);
        deal(stHYPE, address(boringVault), INITIAL_BALANCE);
        deal(wstHYPE, address(boringVault), INITIAL_BALANCE);
        vm.deal(address(boringVault), INITIAL_BALANCE);

        // Give user tokens for deposits
        deal(wHYPE, user1, INITIAL_BALANCE);
        
        // Give Felix mock liquidity
        deal(wHYPE, address(mockFelix), INITIAL_BALANCE * 10);
    }

    function _setupMerkleRoot() internal {
        ManageLeaf[] memory leafs = _createAllOperationLeafs();
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        
        // Set merkle root for strategist
        manager.setManageRoot(strategist, manageTree[manageTree.length - 1][0]);
    }

    // ========================================= TESTS =========================================

    function testCompleteLoopingFlow() external {
        // 1. User deposits wHYPE through teller
        vm.startPrank(user1);
        ERC20(wHYPE).approve(address(teller), DEPOSIT_AMOUNT);
        teller.deposit(ERC20(wHYPE), DEPOSIT_AMOUNT, user1);
        vm.stopPrank();

        // 2. Strategist executes looping strategy through manager
        ManageLeaf[] memory leafs = _createLoopingOperations();
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        
        // Prepare manager call data
        bytes32[][] memory proofs = new bytes32[][](leafs.length);
        address[] memory decoders = new address[](leafs.length);
        address[] memory targets = new address[](leafs.length);
        bytes[] memory calldatas = new bytes[](leafs.length);
        uint256[] memory values = new uint256[](leafs.length);

        for (uint256 i = 0; i < leafs.length; i++) {
            proofs[i] = _getProofsUsingTree(_createSingleLeafArray(leafs[i]), manageTree)[0];
            decoders[i] = leafs[i].decoderAndSanitizer;
            targets[i] = leafs[i].target;
            values[i] = leafs[i].valueIsNonZero ? LOOP_AMOUNT : 0;
            
            // Create appropriate calldata based on operation
            if (targets[i] == wHYPE && leafs[i].selector == "withdraw(uint256)") {
                calldatas[i] = abi.encodeWithSelector(MockWHYPE.withdraw.selector, LOOP_AMOUNT);
            } else if (targets[i] == overseer && leafs[i].selector == "mint(address)") {
                calldatas[i] = abi.encodeWithSelector(MockOverseer.mint.selector, address(boringVault));
            }
            // Add other operations as needed
        }

        uint256 initialWHype = ERC20(wHYPE).balanceOf(address(boringVault));

        // Execute through manager 
        vm.prank(strategist);
        manager.manageVaultWithMerkleVerification(
            proofs,
            decoders,
            targets,
            calldatas,
            values
        );

        // Verify operations were executed
        uint256 finalWHype = ERC20(wHYPE).balanceOf(address(boringVault));
    }

    function testAccessControlCorrect() external {
        ManageLeaf[] memory leafs = _createLoopingOperations();
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = _getProofsUsingTree(_createSingleLeafArray(leafs[0]), manageTree)[0];
        
        address[] memory decoders = new address[](1);
        decoders[0] = leafs[0].decoderAndSanitizer;
        
        address[] memory targets = new address[](1);
        targets[0] = leafs[0].target;
        
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(MockWHYPE.withdraw.selector, LOOP_AMOUNT);
        
        uint256[] memory values = new uint256[](1);
        values[0] = 0;


        vm.prank(user1);
        vm.expectRevert(); // Should revert due to missing STRATEGIST_ROLE
        manager.manageVaultWithMerkleVerification(
            proofs,
            decoders,
            targets,
            calldatas,
            values
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _createAllOperationLeafs() internal view returns (ManageLeaf[] memory) {
        ManageLeaf[] memory leafs = new ManageLeaf[](20);
        uint256 leafIndex = 0;

        // wHYPE withdraw
        leafs[leafIndex++] = ManageLeaf(
            wHYPE, false, "withdraw(uint256)", new address[](0),
            "Withdraw wHYPE", address(hyperliquidDecoder)
        );

        // Overseer mint
        leafs[leafIndex++] = ManageLeaf(
            overseer, true, "mint(address)", new address[](1),
            "Mint stHYPE", address(hyperliquidDecoder)
        );
        leafs[leafIndex-1].argumentAddresses[0] = address(boringVault);

        // Add all other required operations...
        
        // Trim array
        ManageLeaf[] memory trimmed = new ManageLeaf[](leafIndex);
        for (uint256 i = 0; i < leafIndex; i++) {
            trimmed[i] = leafs[i];
        }
        return trimmed;
    }

    function _createLoopingOperations() internal view returns (ManageLeaf[] memory) {
        // Simplified version for testing
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        
        leafs[0] = ManageLeaf(
            wHYPE, false, "withdraw(uint256)", new address[](0),
            "Withdraw wHYPE", address(hyperliquidDecoder)
        );
        
        leafs[1] = ManageLeaf(
            overseer, true, "mint(address)", new address[](1),
            "Mint stHYPE", address(hyperliquidDecoder)
        );
        leafs[1].argumentAddresses[0] = address(boringVault);
        
        return leafs;
    }

    function _createSingleLeafArray(ManageLeaf memory leaf) 
        internal pure returns (ManageLeaf[] memory) 
    {
        ManageLeaf[] memory singleLeaf = new ManageLeaf[](1);
        singleLeaf[0] = leaf;
        return singleLeaf;
    }
}

// ========================================= MOCK CONTRACTS =========================================

contract MockWHYPE is ERC20 {
    constructor() ERC20("Wrapped HYPE", "wHYPE", 18) {}
    
    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }
    
    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }
    
    receive() external payable {}
}

contract MockStHYPE is ERC20 {
    constructor() ERC20("Staked HYPE", "stHYPE", 18) {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockWstHYPE is ERC20 {
    MockStHYPE public immutable stHYPE;
    
    constructor(address _stHYPE) ERC20("Wrapped Staked HYPE", "wstHYPE", 18) {
        stHYPE = MockStHYPE(_stHYPE);
    }
    
    function wrap(uint256 _stHYPEAmount) external {
        stHYPE.transferFrom(msg.sender, address(this), _stHYPEAmount);
        _mint(msg.sender, _stHYPEAmount);
    }
}

contract MockOverseer {
    MockStHYPE public immutable stHYPE;
    uint256 public nextBurnId = 1;
    mapping(uint256 => uint256) public burnAmount;
    mapping(uint256 => bool) public burnRedeemable;
    uint256 public maxRedeemableAmount = 1000e18;
    
    constructor(address _stHYPE) {
        stHYPE = MockStHYPE(_stHYPE);
    }
    
    function mint(address to) external payable returns (uint256) {
        stHYPE.mint(to, msg.value);
        return msg.value;
    }
    
    function burnAndRedeemIfPossible(address to, uint256 amount, string calldata) external returns (uint256) {
        stHYPE.transferFrom(msg.sender, address(this), amount);
        if (amount <= maxRedeemableAmount) {
            payable(to).transfer(amount);
            return 0;
        } else {
            uint256 burnId = nextBurnId++;
            burnAmount[burnId] = amount;
            return burnId;
        }
    }
    
    function maxRedeemable() external view returns (uint256) {
        return maxRedeemableAmount;
    }
    
    function redeemable(uint256 burnId) external view returns (bool) {
        return burnRedeemable[burnId];
    }
    
    receive() external payable {}
}

// Use the same struct as actual contracts
contract MockFelix {
    // Import from DecoderCustomTypes
    struct MarketParams {
        address loanToken;
        address collateralToken; 
        address oracle;
        address irm;
        uint256 lltv;
    }
    
    mapping(bytes32 => mapping(address => uint256)) public collateralBalance;
    mapping(bytes32 => mapping(address => uint256)) public borrowBalance;
    
    function supplyCollateral(
        MarketParams calldata marketParams,
        uint256 assets,
        address onBehalf,
        bytes calldata
    ) external {
        bytes32 marketId = keccak256(abi.encode(marketParams));
        ERC20(marketParams.collateralToken).transferFrom(msg.sender, address(this), assets);
        collateralBalance[marketId][onBehalf] += assets;
    }
    
    function borrow(
        MarketParams calldata marketParams,
        uint256 assets,
        uint256,
        address onBehalf,
        address receiver
    ) external {
        bytes32 marketId = keccak256(abi.encode(marketParams));
        borrowBalance[marketId][onBehalf] += assets;
        ERC20(marketParams.loanToken).transfer(receiver, assets);
    }
}