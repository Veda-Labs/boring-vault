// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreatePrvlWETHAgent1CoreMainnetMerkleRoot.s.sol:USDCAgent1 --rpc-url mainnet
 */

 // reference implementation for Aave https://github.com/ParavelDAO/prvl-protocol/blob/71da554e0516105dc3d47702d290e8ae78dcf30b/script/MerkleRootCreation/Arbitrum/CreateMultiChainTestMerkleRoot.s.sol#L216 

contract USDCAgent1 is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault; // Set in setUp for mainnet fork
    address public managerAddress; // Set in setUp for mainnet fork  
    address public accountantAddress; // Set in setUp for mainnet fork
    address public rawDataDecoderAndSanitizer; // Set in setUp for mainnet fork
    address public wstETH; // Set in setUp for mainnet fork
    
    function setUp() external {
        boringVault = 0x8503B18b279Fd0f1EC35303D8db834619A12250f; // Agent vault address
        managerAddress = 0xF93C04915f69e95D9b8777609f07c969Ff24ee48; // Manager address  
        accountantAddress = 0x6520E0A84176573913d8EE07f2dceE7955c76f90; // Accountant address
        // Using deployed agent decoder address
        wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        rawDataDecoderAndSanitizer = 0xEb669E30f7A332FbEe9D3FCF3281e244F1539F49; // Deployed decoder address
    }

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, mainnet, "wstETH", wstETH);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](2);
        token0[0] = getAddress(sourceChain, "wstETH");
        token0[1] = getAddress(sourceChain, "WETH");

        address[] memory token1 = new address[](2);
        token1[0] = getAddress(sourceChain, "WETH");
        token1[1] = getAddress(sourceChain, "wstETH");

        _addUniswapV3AgentLeafs(leafs, token0, token1);

        
        // =========================== AAVE V3 ============================

        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "wstETH");
        ERC20[] memory borrowAssets = new ERC20[](1);
        borrowAssets[0] = getERC20(sourceChain, "WETH");
        //ERC20[] memory claimAssets = new ERC20[](1);
        //claimAssets[0] = getERC20(sourceChain, "WETH");
        _addAaveV3AgentLeafs(leafs, supplyAssets, borrowAssets /*claimAssets*/);

        // =========================== BALANCER V2 ============================
        _addBalancerFlashloanLeafs(leafs, address(getERC20(sourceChain, "WETH")));
        _addBalancerFlashloanLeafs(leafs, address(getERC20(sourceChain, "wstETH")));


        string memory filePath = "./leafs/Mainnet/ETHAgent1CORE.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }


    function _addUniswapV3AgentLeafs(ManageLeaf[] memory leafs, address[] memory token0, address[] memory token1) internal {
        require(token0.length == token1.length, "Token arrays must be of equal length");
        for (uint256 i; i < token0.length; ++i) {
            (token0[i], token1[i]) = token0[i] < token1[i] ? (token0[i], token1[i]) : (token1[i], token0[i]);
            // Approvals
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(sourceChain, "uniswapV3NonFungiblePositionManager")]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve UniswapV3 NonFungible Position Manager to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniswapV3NonFungiblePositionManager");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(sourceChain, "uniswapV3NonFungiblePositionManager")]
                = true;
            }
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(sourceChain, "uniswapV3NonFungiblePositionManager")]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve UniswapV3 NonFungible Position Manager to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniswapV3NonFungiblePositionManager");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(sourceChain, "uniswapV3NonFungiblePositionManager")]
                = true;
            }

            if (!ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve SwapRouter02 to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45] = true;
            }
            if (!ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve SwapRouter02 to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45] = true;
            }

            // Swapping
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45, // SwapRouter02
                false,
                "exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))",
                new address[](3),
                string.concat(
                    "Swap ", ERC20(token0[i]).symbol(), " for ", ERC20(token1[i]).symbol(), " using SwapRouter02"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf(
                0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45, // SwapRouter02
                false,
                "exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))",
                new address[](3),
                string.concat(
                    "Swap ", ERC20(token1[i]).symbol(), " for ", ERC20(token0[i]).symbol(), " using SwapRouter02"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token1[i];
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        }
    }
    function _addAaveV3AgentLeafs(
        ManageLeaf[] memory leafs,
        ERC20[] memory supplyAssets,
        ERC20[] memory borrowAssets
        //ERC20[] memory claimAssets
    ) internal {
        _addAaveV3AgentForkLeafs(
            "Aave V3", getAddress(sourceChain, "v3Pool"), leafs, supplyAssets, borrowAssets/*, claimAssets*/
        );
    }

    function _addAaveV3AgentForkLeafs(
        string memory protocolName,
        address protocolAddress,
        ManageLeaf[] memory leafs,
        ERC20[] memory supplyAssets,
        ERC20[] memory borrowAssets
        //ERC20[] memory claimAssets
    ) internal {
        // Approvals
        string memory baseApprovalString = string.concat("Approve ", protocolName, " Pool to spend ");
        for (uint256 i; i < supplyAssets.length; ++i) {
            if (!ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(supplyAssets[i])][protocolAddress]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(supplyAssets[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat(baseApprovalString, supplyAssets[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = protocolAddress;
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(supplyAssets[i])][protocolAddress] = true;
            }
        }
        for (uint256 i; i < borrowAssets.length; ++i) {
            if (!ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(borrowAssets[i])][protocolAddress]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(borrowAssets[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat(baseApprovalString, borrowAssets[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = protocolAddress;
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(borrowAssets[i])][protocolAddress] = true;
            }
        }
        // Lending
        for (uint256 i; i < supplyAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                protocolAddress,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                string.concat("Supply ", supplyAssets[i].symbol(), " to ", protocolName),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(supplyAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
        // Withdrawing
        for (uint256 i; i < supplyAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                protocolAddress,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                string.concat("Withdraw ", supplyAssets[i].symbol(), " from ", protocolName),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(supplyAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
        // Borrowing
        for (uint256 i; i < borrowAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                protocolAddress,
                false,
                "borrow(address,uint256,uint256,uint16,address)",
                new address[](2),
                string.concat("Borrow ", borrowAssets[i].symbol(), " from ", protocolName),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(borrowAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
        // Repaying
        for (uint256 i; i < borrowAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                protocolAddress,
                false,
                "repay(address,uint256,uint256,address)",
                new address[](2),
                string.concat("Repay ", borrowAssets[i].symbol(), " to ", protocolName),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(borrowAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
        
        for (uint256 i; i < supplyAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                protocolAddress,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                string.concat("Toggle ", supplyAssets[i].symbol(), " as collateral in ", protocolName),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(supplyAssets[i]);
        }
    
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            protocolAddress,
            false,
            "setUserEMode(uint8)",
            new address[](0),
            string.concat("Set user e-mode in ", protocolName),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    /*
        for (uint256 i; i < claimAssets.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "v3RewardsController"),
                false,
                "claimRewards(address[],uint256,address,address)",
                new address[](1),
                string.concat("Claim reward", claimAssets[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }
        */
        
    }

}