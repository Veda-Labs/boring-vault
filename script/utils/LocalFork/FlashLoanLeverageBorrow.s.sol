// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {console2} from "forge-std/console2.sol";

interface IQuoter {
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut);
}

/*
 * source .env && forge script script/utils/LocalFork/FlashLoanLeverageBorrow.s.sol:FlashLoanLeverageBorrow --fork-url local --broadcast -vvvvv
 */

contract FlashLoanLeverageBorrow is Script, MerkleTreeHelper {
    address constant MANAGER = 0x54a352BE658a9CDe86409b7281BFBCE0cA94dd81;
    address constant TARGET_AGENT_VAULT = 0x3A29E2a5Ddb20C56D62a9D9Fa29b606833C4bf1d;
    address constant BASEDECODER = 0x078AF49028bDfC2a2247B76d170022a9C98308D0;
    
    // Precomputed constants
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant UNI_V3_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address constant UNI_V3_QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    uint256 constant FLASH_AMOUNT = 5000e6; // 5000 USDC (total position size)
    uint256 constant MIN_WETH_OUT = 0;
    uint256 constant LEVERAGE_BORROW_AMOUNT = 4000e6; // 4000 USDC (borrowed for 5x leverage)
    uint24 constant UNI_FEE_TIER = 3000;
    uint256 constant AAVE_VARIABLE_RATE = 2;
    
    // Precomputed function selectors (matching the JSON file)
    bytes4 constant APPROVE_SELECTOR = 0x095ea7b3;
    bytes4 constant EXACT_INPUT_SINGLE_SELECTOR = 0x04e45aaf; // correctInputSingle selector from JSON
    bytes4 constant SUPPLY_SELECTOR = 0x617ba037;
    bytes4 constant BORROW_SELECTOR = 0xa415bcad;
    bytes4 constant FLASHLOAN_SELECTOR = 0x5c38449e;

    function run() external {
        uint256 privateKey = vm.envUint("LOCAL_DEPLOYER_PRIVATE_KEY");
        setSourceChainName("mainnet");
        vm.startBroadcast(privateKey);

        string memory json = vm.readFile("leafs/LocalFork/FundMgmtUSDCAgentMainnetForkLeafs.json");
        bytes32 merkleRoot = vm.parseJsonBytes32(json, ".metadata.ManageRoot");

        _setupMerkleRoot(merkleRoot);
        _logPreBalances();
        _executeFlashloan(json);
        _logPostBalances();

        vm.stopBroadcast();
    }

    function _testSimpleApprove(string memory json) internal {
        // Test just the first inner call - approve USDC to SwapRouter02
        bytes32[][] memory innerManageProofs = new bytes32[][](1);
        address[] memory innerDecodersAndSanitizers = new address[](1);
        address[] memory innerTargets = new address[](1);
        bytes[] memory innerTargetData = new bytes[](1);
        uint256[] memory innerValues = new uint256[](1);

        // Set up the approve call
        innerTargets[0] = USDC;
        innerTargetData[0] = abi.encodeWithSelector(APPROVE_SELECTOR, UNI_V3_ROUTER, type(uint256).max);
        innerDecodersAndSanitizers[0] = BASEDECODER;
        innerValues[0] = 0;

        // Get the proof
        bytes memory packed = abi.encodePacked(UNI_V3_ROUTER);
        bytes32 computed = computeLeafDigest(BASEDECODER, USDC, false, APPROVE_SELECTOR, packed);
        innerManageProofs[0] = getMerkleProof(json, computed);

        console2.log("Testing simple approve...");
        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(MANAGER);
        
        try manager.manageVaultWithMerkleVerification(
            innerManageProofs, 
            innerDecodersAndSanitizers, 
            innerTargets, 
            innerTargetData, 
            innerValues
        ) {
            console2.log("Simple approve succeeded");
        } catch Error(string memory reason) {
            console2.log("Simple approve failed with reason:", reason);
        } catch (bytes memory lowLevelData) {
            console2.log("Simple approve failed with low-level error");
            console2.logBytes(lowLevelData);
        }
    }

    function _setupMerkleRoot(bytes32 merkleRoot) internal {
        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(MANAGER);
        address deployer = vm.envAddress("LOCAL_DEPLOYER_ADDRESS");
        
        // Set merkle root for deployer
        if (manager.manageRoot(deployer) != merkleRoot) {
            manager.setManageRoot(deployer, merkleRoot);
        }
        
        // Set merkle root for Manager itself (needed for flashloan callbacks)
        if (manager.manageRoot(MANAGER) != merkleRoot) {
            manager.setManageRoot(MANAGER, merkleRoot);
            console2.log("Set Merkle root for Manager address:", MANAGER);
        }
    }

    function _logPreBalances() internal view {
        ERC20 usdcToken = ERC20(USDC);
        ERC20 wethToken = ERC20(WETH);
        // aWETH token address on mainnet
        ERC20 aWETHToken = ERC20(0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8);
        
        uint256 wethBalance = wethToken.balanceOf(TARGET_AGENT_VAULT);
        uint256 aWethBalance = aWETHToken.balanceOf(TARGET_AGENT_VAULT);
        
        console2.log("=== BEFORE FLASHLOAN LEVERAGE ===");
        console2.log("Vault USDC Balance: ", usdcToken.balanceOf(TARGET_AGENT_VAULT) / 1e6);
        console2.log("Vault WETH Balance (wei): ", wethBalance);
        console2.log("Vault WETH Balance (ether): ", wethBalance / 1e18);
        console2.log("Vault WETH Balance (precise): ", wethBalance / 1e15); // Shows 3 decimal places
        console2.log("Vault aWETH Balance (wei): ", aWethBalance);
        console2.log("Vault aWETH Balance (ether): ", aWethBalance / 1e18);
        console2.log("Vault aWETH Balance (precise): ", aWethBalance / 1e15); // Shows 3 decimal places
    }

    function _logPostBalances() internal view {
        ERC20 usdcToken = ERC20(USDC);
        ERC20 wethToken = ERC20(WETH);
        // aWETH token address on mainnet
        ERC20 aWETHToken = ERC20(0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8);
        
        uint256 wethBalance = wethToken.balanceOf(TARGET_AGENT_VAULT);
        uint256 aWethBalance = aWETHToken.balanceOf(TARGET_AGENT_VAULT);
        
        console2.log("=== AFTER FLASHLOAN LEVERAGE ===");
        console2.log("Vault USDC Balance: ", usdcToken.balanceOf(TARGET_AGENT_VAULT) / 1e6);
        console2.log("Vault WETH Balance (wei): ", wethBalance);
        console2.log("Vault WETH Balance (ether): ", wethBalance / 1e18);
        console2.log("Vault WETH Balance (precise): ", wethBalance / 1e15); // Shows 3 decimal places
        console2.log("=== AAVE POSITIONS ===");
        console2.log("Vault aWETH Balance (wei): ", aWethBalance);
        console2.log("Vault aWETH Balance (ether): ", aWethBalance / 1e18);
        console2.log("Vault aWETH Balance (precise): ", aWethBalance / 1e15); // Shows 3 decimal places
    }

    function _executeFlashloan(string memory json) internal {
        (
            bytes32[][] memory innerManageProofs,
            address[] memory innerDecodersAndSanitizers,
            address[] memory innerTargets,
            bytes[] memory innerTargetData,
            uint256[] memory innerValues
        ) = _prepareInnerCalls(json);

        bytes memory userData = abi.encode(
            innerManageProofs, 
            innerDecodersAndSanitizers, 
            innerTargets, 
            innerTargetData, 
            innerValues
        );

        _executeOuterFlashloan(json, userData);
    }

    function _getExpectedWethOutput() internal returns (uint256) {
        // Quote the USDC->WETH swap for full 5000 USDC amount
        return IQuoter(UNI_V3_QUOTER).quoteExactInputSingle(
            USDC,
            WETH, 
            UNI_FEE_TIER,
            FLASH_AMOUNT, // 5000 USDC
            0
        );
    }

    function _prepareInnerCalls(string memory json) internal returns (
        bytes32[][] memory innerManageProofs,
        address[] memory innerDecodersAndSanitizers,
        address[] memory innerTargets,
        bytes[] memory innerTargetData,
        uint256[] memory innerValues
    ) {
        // 5x Leverage strategy: approve USDC, swap 5000 USDC to WETH, approve WETH, supply all WETH, borrow 4000 USDC  
        innerManageProofs = new bytes32[][](5);
        innerDecodersAndSanitizers = new address[](5);
        innerTargets = new address[](5);
        innerTargetData = new bytes[](5);
        innerValues = new uint256[](5);

        // Get expected WETH output from quoter (5000 USDC → ~1.8 WETH)
        uint256 expectedWethOutput = _getExpectedWethOutput();
        
        // Use existing leafs from JSON
        _setSimpleInnerCall0(innerTargets, innerTargetData, innerDecodersAndSanitizers, innerValues); // Approve USDC to SwapRouter02
        _setSimpleInnerCall1(innerTargets, innerTargetData, innerDecodersAndSanitizers, innerValues); // Swap 5000 USDC to WETH
        _setSimpleInnerCall2(innerTargets, innerTargetData, innerDecodersAndSanitizers, innerValues); // Approve WETH to Aave
        _setSimpleInnerCall3(innerTargets, innerTargetData, innerDecodersAndSanitizers, innerValues, expectedWethOutput); // Supply all WETH to Aave
        _setSimpleInnerCall4(innerTargets, innerTargetData, innerDecodersAndSanitizers, innerValues, expectedWethOutput); // Borrow 4000 USDC for leverage

        // Compute proofs using the computed digests (they match the JSON exactly)
        for (uint256 i = 0; i < 5; i++) {
            bytes memory packed = _getSimplePackedArgs(i);
            bytes4 selector = _getSimpleSelector(i);
            bytes32 computed = computeLeafDigest(BASEDECODER, innerTargets[i], false, selector, packed);
            innerManageProofs[i] = getMerkleProof(json, computed);
        }
    }

    function _setSimpleInnerCall0(
        address[] memory targets, 
        bytes[] memory targetData, 
        address[] memory decodersAndSanitizers, 
        uint256[] memory values
    ) internal pure {
        // Approve SwapRouter02 to spend USDC (matches JSON line 9)
        targets[0] = USDC;
        targetData[0] = abi.encodeWithSelector(APPROVE_SELECTOR, UNI_V3_ROUTER, type(uint256).max);
        decodersAndSanitizers[0] = BASEDECODER;
        values[0] = 0;
    }

    function _setSimpleInnerCall1(
        address[] memory targets, 
        bytes[] memory targetData, 
        address[] memory decodersAndSanitizers, 
        uint256[] memory values
    ) internal pure {
        // Swap 5000 USDC to WETH for 5x leverage position
        targets[1] = UNI_V3_ROUTER;
        targetData[1] = abi.encodeWithSelector(
            EXACT_INPUT_SINGLE_SELECTOR,
            USDC, WETH, UNI_FEE_TIER, TARGET_AGENT_VAULT, FLASH_AMOUNT, MIN_WETH_OUT, uint160(0)
        );
        decodersAndSanitizers[1] = BASEDECODER;
        values[1] = 0;
    }

    function _setSimpleInnerCall2(
        address[] memory targets, 
        bytes[] memory targetData, 
        address[] memory decodersAndSanitizers, 
        uint256[] memory values
    ) internal pure {
        // Approve Aave V3 Pool to spend WETH (matches JSON line 21)
        targets[2] = WETH;
        targetData[2] = abi.encodeWithSelector(APPROVE_SELECTOR, AAVE_POOL, type(uint256).max);
        decodersAndSanitizers[2] = BASEDECODER;
        values[2] = 0;
    }

    function _setSimpleInnerCall3(
        address[] memory targets, 
        bytes[] memory targetData, 
        address[] memory decodersAndSanitizers, 
        uint256[] memory values,
        uint256 wethAmount
    ) internal pure {
        // Supply the exact WETH amount from quoter
        targets[3] = AAVE_POOL;
        targetData[3] = abi.encodeWithSelector(
            SUPPLY_SELECTOR,
            WETH, 
            wethAmount, // Use quoted amount
            TARGET_AGENT_VAULT, 
            0
        );
        decodersAndSanitizers[3] = BASEDECODER;
        values[3] = 0;
    }

    function _setSimpleInnerCall4(
        address[] memory targets, 
        bytes[] memory targetData, 
        address[] memory decodersAndSanitizers, 
        uint256[] memory values,
        uint256 // wethAmount - not used, we use fixed leverage amount
    ) internal pure {
        // Borrow exactly 4000 USDC for 5x leverage (4000 borrowed + 1000 own = 5000 total)
        targets[4] = AAVE_POOL;
        targetData[4] = abi.encodeWithSelector(
            BORROW_SELECTOR,
            USDC, 
            LEVERAGE_BORROW_AMOUNT, // Fixed 4000 USDC for 5x leverage
            AAVE_VARIABLE_RATE, 
            0, 
            TARGET_AGENT_VAULT
        );
        decodersAndSanitizers[4] = BASEDECODER;
        values[4] = 0;
    }


    function _getSimplePackedArgs(uint256 index) internal pure returns (bytes memory) {
        if (index == 0) return abi.encodePacked(UNI_V3_ROUTER); // Approve USDC to SwapRouter02
        if (index == 1) return abi.encodePacked(USDC, WETH, TARGET_AGENT_VAULT); // Swap USDC to WETH
        if (index == 2) return abi.encodePacked(AAVE_POOL); // Approve WETH to Aave
        if (index == 3) return abi.encodePacked(WETH, TARGET_AGENT_VAULT); // Supply WETH to Aave
        if (index == 4) return abi.encodePacked(USDC, TARGET_AGENT_VAULT); // Borrow USDC from Aave
        return "";
    }

    function _getSimpleSelector(uint256 index) internal pure returns (bytes4) {
        if (index == 0) return APPROVE_SELECTOR; // approve
        if (index == 1) return EXACT_INPUT_SINGLE_SELECTOR; // exactInputSingle
        if (index == 2) return APPROVE_SELECTOR; // approve
        if (index == 3) return SUPPLY_SELECTOR; // supply
        if (index == 4) return BORROW_SELECTOR; // borrow
        return bytes4(0);
    }


    function _executeOuterFlashloan(string memory json, bytes memory userData) internal {
        address[] memory tokens = new address[](1);
        tokens[0] = USDC;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = FLASH_AMOUNT;
        
        bytes[] memory outerTargetData = new bytes[](1);
        outerTargetData[0] = abi.encodeWithSelector(
            FLASHLOAN_SELECTOR,
            MANAGER, 
            tokens, 
            amounts, 
            userData
        );

        bytes32[][] memory outerManageProofs = new bytes32[][](1);
        // Use the exact leaf digest from JSON line 33: Flashloan USDC from Balancer Vault
        outerManageProofs[0] = getMerkleProof(json, 0xa50c6593a1f7b746bf2006dba902573c35f62005b0510921070ae8f234cad304);

        address[] memory outerTargets = new address[](1);
        outerTargets[0] = MANAGER; // Target the Manager's flashLoan function as per JSON
        uint256[] memory outerValues = new uint256[](1);
        outerValues[0] = 0;
        address[] memory outerDecodersAndSanitizers = new address[](1);
        outerDecodersAndSanitizers[0] = BASEDECODER;

        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(MANAGER);
        try manager.manageVaultWithMerkleVerification(
            outerManageProofs, 
            outerDecodersAndSanitizers, 
            outerTargets, 
            outerTargetData, 
            outerValues
        ) {
            console2.log("Flashloan leverage borrow executed successfully");
        } catch Error(string memory reason) {
            console2.log("L Flashloan failed with reason:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console2.log("L Flashloan failed with low-level error");
            console2.logBytes(lowLevelData);
            revert("Low-level flashloan error");
        }
    }

    function _getPackedArgs(uint256 index) internal pure returns (bytes memory) {
        if (index == 0) return abi.encodePacked(UNI_V3_ROUTER); // Approve USDC to UniV3
        if (index == 1) return abi.encodePacked(USDC, WETH, TARGET_AGENT_VAULT); // Swap USDC to WETH
        if (index == 2) return abi.encodePacked(AAVE_POOL); // Approve WETH to Aave
        if (index == 3) return abi.encodePacked(WETH, TARGET_AGENT_VAULT); // Supply WETH to Aave
        if (index == 4) return abi.encodePacked(USDC, TARGET_AGENT_VAULT); // Borrow USDC from Aave
        if (index == 5) return abi.encodePacked(MANAGER); // Approve USDC to Manager
        return "";
    }

    function computeLeafDigest(
        address decoderAndSanitizer,
        address target,
        bool canSendValue,
        bytes4 selector,
        bytes memory packedAddressArgs
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            decoderAndSanitizer,
            target,
            canSendValue ? bytes1(0x01) : bytes1(0x00),
            selector,
            packedAddressArgs
        ));
    }

    function getMerkleProof(string memory json, bytes32 leafDigest) internal view returns (bytes32[] memory) {
        uint256 capacity = vm.parseJsonUint(json, ".metadata.TreeCapacity");
        uint256 height = log2(capacity);

        string memory leavesPath = string(abi.encodePacked(".MerkleTree.", vm.toString(height)));
        bytes32[] memory leaves = vm.parseJsonBytes32Array(json, leavesPath);

        uint256 index = type(uint256).max;
        for (uint256 i = 0; i < leaves.length; i++) {
            if (leaves[i] == leafDigest) {
                index = i;
                break;
            }
        }
        if (index == type(uint256).max) revert("Leaf not found");

        bytes32[] memory proof = new bytes32[](height);
        uint256 currentIndex = index;
        uint256 proofIdx = 0;

        for (uint256 level = height; level > 0; level--) {
            string memory levelPath = string(abi.encodePacked(".MerkleTree.", vm.toString(level)));
            bytes32[] memory levelHashes = vm.parseJsonBytes32Array(json, levelPath);
            uint256 siblingIndex = currentIndex ^ 1;
            proof[proofIdx++] = levelHashes[siblingIndex];
            currentIndex = currentIndex >> 1;
        }

        return proof;
    }

    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }
}