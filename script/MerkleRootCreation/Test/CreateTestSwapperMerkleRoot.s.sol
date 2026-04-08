// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Test/CreateTestSwapperMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateTestSwapperMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x0Fc760EEbEFbF5FE3B452A9a52325c4376FEADFA;
    address public rawDataDecoderAndSanitizer = 0xd9Bb301D37BEB60EbeD71093Cd9c63eFd20C72f4;
    address public managerAddress = 0x1AE3346BC6d3267b860De524D5E38E19679A1DB0;
    address public accountantAddress = 0xD1135B891143d3c5DfE158C6b4961937a27b8AE4;

  // AdapterRegistry:  0x291cf51d077F71509C0B41C26f857149Bb26D21b
  // BoringSwapper:    0xA19a28547d07C35B2F9C71DFDF7cEBA89C41E6CC
  // UniswapV3Adapter: 0x0B368fc268d2BbF641b4DD29bFE01FBF19f609d1
  // CowswapAdapter:   0x90BA671D3062fEd8B169933Ce61AC443191196a6
  // OneInchAdapter:   0x48EE2f75E67dE1Cc686b02F81EB3dFe95341DFC1
  // RolesAuthority:   0x13b92D87894E24B266A947255CD022749Fb52755
    

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Swapper ==========================
        address swapper = 0xA19a28547d07C35B2F9C71DFDF7cEBA89C41E6CC;
        address[] memory tokens = new address[](2);  
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");
        _addBoringSwapperLeafs(leafs, swapper, tokens); 

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/TestSwapperMerkleRoot.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

    }

}
