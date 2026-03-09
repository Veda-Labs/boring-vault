// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ChainValues} from "test/resources/ChainValues.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IComet} from "src/interfaces/IComet.sol";

interface ITellerVaultGetter {
    function vault() external view returns (ERC20);
}

/// @dev Hardcoded selector for BaseDecoderAndSanitizer__FunctionSelectorNotSupported() = 0xde42fa1c
bytes4 constant BASE_DECODER_UNSUPPORTED_SELECTOR = 0xde42fa1c;
// forge-lint: disable-next-line(unused-import)
import "forge-std/Base.sol";
import "forge-std/Test.sol";

contract MerkleTreeHelper is CommonBase, ChainValues, Test {
    using Address for address;

    string public sourceChain;
    uint256 leafIndex = type(uint256).max;

    mapping(address => mapping(address => mapping(address => bool))) public ownerToTokenToSpenderToApprovalInTree;
    mapping(address => mapping(address => mapping(address => bool))) public ownerToOneInchSellTokenToBuyTokenToInTree;
    mapping(address => mapping(address => mapping(address => bool))) public ownerToOneInchV6SellTokenToBuyTokenToInTree;
    mapping(address => mapping(address => mapping(address => bool))) public ownerToOdosSellTokenToBuyTokenToInTree;
    mapping(address => mapping(address => mapping(address => bool))) public ownerToOogaBoogaSellTokenToBuyTokenToInTree;
    mapping(address => mapping(address => mapping(address => bool))) public ownerToGlueXSellTokenToBuyTokenToInTree;
    mapping(address => mapping(address => mapping(address => bool))) public ownerToSushiSellTokenToBuyTokenToInTree;

    function setSourceChainName(string memory _chain) internal {
        sourceChain = _chain;
    }

    // ========================================= 1Inch =========================================

    enum SwapKind {
        BuyAndSell,
        Sell
    }

    function _addLeafsFor1InchGeneralSwapping(
        ManageLeaf[] memory leafs,
        address[] memory assets,
        SwapKind[] memory kind
    ) internal {
        require(assets.length == kind.length, "Arrays must be of equal length");
        for (uint256 i; i < assets.length; ++i) {
            // Add approval leaf if not already added
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][assets[i]][getAddress(sourceChain, "aggregationRouterV5")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: assets[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve 1Inch router to spend ", ERC20(assets[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "aggregationRouterV5");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][assets[i]][getAddress(sourceChain, "aggregationRouterV5")] = true;
            }
            // Iterate through the list again.
            for (uint256 j; j < assets.length; ++j) {
                // Skip if we are on the same index
                if (i == j) {
                    continue;
                }
                if (
                    !ownerToOneInchSellTokenToBuyTokenToInTree[
                            getAddress(sourceChain, "boringVault")
                        ][assets[i]][assets[j]] && kind[j] != SwapKind.Sell
                ) {
                    // Add sell swap.
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "aggregationRouterV5"),
                        canSendValue: false,
                        signature: "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                        argumentAddresses: new address[](5),
                        description: string.concat(
                            "Swap ",
                            ERC20(assets[i]).symbol(),
                            " for ",
                            ERC20(assets[j]).symbol(),
                            " using 1inch router"
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "oneInchExecutor");
                    leafs[leafIndex].argumentAddresses[1] = assets[i];
                    leafs[leafIndex].argumentAddresses[2] = assets[j];
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "oneInchExecutor");
                    leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
                    ownerToOneInchSellTokenToBuyTokenToInTree[
                        getAddress(sourceChain, "boringVault")
                    ][assets[i]][assets[j]] = true;
                }

                if (
                    kind[i] == SwapKind.BuyAndSell
                        && !ownerToOneInchSellTokenToBuyTokenToInTree[
                            getAddress(sourceChain, "boringVault")
                        ][assets[j]][assets[i]]
                ) {
                    // Add buy swap.
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "aggregationRouterV5"),
                        canSendValue: false,
                        signature: "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                        argumentAddresses: new address[](5),
                        description: string.concat(
                            "Swap ",
                            ERC20(assets[j]).symbol(),
                            " for ",
                            ERC20(assets[i]).symbol(),
                            " using 1inch router"
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "oneInchExecutor");
                    leafs[leafIndex].argumentAddresses[1] = assets[j];
                    leafs[leafIndex].argumentAddresses[2] = assets[i];
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "oneInchExecutor");
                    leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
                    ownerToOneInchSellTokenToBuyTokenToInTree[
                        getAddress(sourceChain, "boringVault")
                    ][assets[j]][assets[i]] = true;
                }
            }
        }
    }

    function _addLeafsFor1InchOwnedGeneralSwapping(
        ManageLeaf[] memory leafs,
        address[] memory assets,
        SwapKind[] memory kind
    ) internal {
        require(assets.length == kind.length, "Arrays must be of equal length");
        for (uint256 i; i < assets.length; ++i) {
            // Add approval leaf if not already added
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][assets[i]][getAddress(sourceChain, "aggregationRouterV5")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: assets[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve 1Inch router to spend ", ERC20(assets[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "aggregationRouterV5");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][assets[i]][getAddress(sourceChain, "aggregationRouterV5")] = true;
            }
            // Iterate through the list again.
            for (uint256 j; j < assets.length; ++j) {
                // Skip if we are on the same index
                if (i == j) {
                    continue;
                }
                if (
                    !ownerToOneInchSellTokenToBuyTokenToInTree[
                            getAddress(sourceChain, "boringVault")
                        ][assets[i]][assets[j]] && kind[j] != SwapKind.Sell
                ) {
                    // Add sell swap.
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "aggregationRouterV5"),
                        canSendValue: false,
                        signature: "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                        argumentAddresses: new address[](3),
                        description: string.concat(
                            "Swap ",
                            ERC20(assets[i]).symbol(),
                            " for ",
                            ERC20(assets[j]).symbol(),
                            " using 1inch router"
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = assets[i];
                    leafs[leafIndex].argumentAddresses[1] = assets[j];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
                    ownerToOneInchSellTokenToBuyTokenToInTree[
                        getAddress(sourceChain, "boringVault")
                    ][assets[i]][assets[j]] = true;
                }

                if (
                    kind[i] == SwapKind.BuyAndSell
                        && !ownerToOneInchSellTokenToBuyTokenToInTree[
                            getAddress(sourceChain, "boringVault")
                        ][assets[j]][assets[i]]
                ) {
                    // Add buy swap.
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "aggregationRouterV5"),
                        canSendValue: false,
                        signature: "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                        argumentAddresses: new address[](3),
                        description: string.concat(
                            "Swap ",
                            ERC20(assets[j]).symbol(),
                            " for ",
                            ERC20(assets[i]).symbol(),
                            " using 1inch router"
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = assets[j];
                    leafs[leafIndex].argumentAddresses[1] = assets[i];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
                    ownerToOneInchSellTokenToBuyTokenToInTree[
                        getAddress(sourceChain, "boringVault")
                    ][assets[j]][assets[i]] = true;
                }
            }
        }
    }

    function _addLeafsFor1InchUniswapV3Swapping(ManageLeaf[] memory leafs, address pool) internal {
        UniswapV3Pool uniswapV3Pool = UniswapV3Pool(pool);
        address token0 = uniswapV3Pool.token0();
        address token1 = uniswapV3Pool.token1();
        // Add approval leaf if not already added
        if (!ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][token0][getAddress(sourceChain, "aggregationRouterV5")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: token0,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve 1Inch router to spend ", ERC20(token0).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "aggregationRouterV5");
            ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][token0][getAddress(sourceChain, "aggregationRouterV5")] = true;
        }
        if (!ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][token1][getAddress(sourceChain, "aggregationRouterV5")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: token1,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve 1Inch router to spend ", ERC20(token1).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "aggregationRouterV5");
            ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][token1][getAddress(sourceChain, "aggregationRouterV5")] = true;
        }
        uint256 feeInBps = uniswapV3Pool.fee() / 100;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "aggregationRouterV5"),
            canSendValue: false,
            signature: "uniswapV3Swap(uint256,uint256,uint256[])",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Swap between ",
                ERC20(token0).symbol(),
                " and ",
                ERC20(token1).symbol(),
                " with ",
                vm.toString(feeInBps),
                " bps fee on UniswapV3 using 1inch router"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = pool;
    }

    // ========================================= 1Inch V6 =========================================

    function _addLeafsFor1InchV6GeneralSwapping(
        ManageLeaf[] memory leafs,
        address[] memory assets,
        SwapKind[] memory kind
    ) internal {
        require(assets.length == kind.length, "Arrays must be of equal length");
        for (uint256 i; i < assets.length; ++i) {
            // Add approval leaf if not already added
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][assets[i]][getAddress(sourceChain, "aggregationRouterV6")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: assets[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve 1Inch V6 router to spend ", ERC20(assets[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "aggregationRouterV6");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][assets[i]][getAddress(sourceChain, "aggregationRouterV6")] = true;
            }
            // Iterate through the list again.
            for (uint256 j; j < assets.length; ++j) {
                // Skip if we are on the same index
                if (i == j) {
                    continue;
                }
                if (
                    !ownerToOneInchV6SellTokenToBuyTokenToInTree[
                            getAddress(sourceChain, "boringVault")
                        ][assets[i]][assets[j]] && kind[j] != SwapKind.Sell
                ) {
                    // Add sell swap.
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "aggregationRouterV6"),
                        canSendValue: false,
                        signature: "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes)",
                        argumentAddresses: new address[](5),
                        description: string.concat(
                            "Swap ",
                            ERC20(assets[i]).symbol(),
                            " for ",
                            ERC20(assets[j]).symbol(),
                            " using 1inch V6 router"
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "oneInchExecutor");
                    leafs[leafIndex].argumentAddresses[1] = assets[i];
                    leafs[leafIndex].argumentAddresses[2] = assets[j];
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "oneInchExecutor");
                    leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
                    ownerToOneInchV6SellTokenToBuyTokenToInTree[
                        getAddress(sourceChain, "boringVault")
                    ][assets[i]][assets[j]] = true;
                }

                if (
                    kind[i] == SwapKind.BuyAndSell
                        && !ownerToOneInchV6SellTokenToBuyTokenToInTree[
                            getAddress(sourceChain, "boringVault")
                        ][assets[j]][assets[i]]
                ) {
                    // Add buy swap.
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "aggregationRouterV6"),
                        canSendValue: false,
                        signature: "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes)",
                        argumentAddresses: new address[](5),
                        description: string.concat(
                            "Swap ",
                            ERC20(assets[j]).symbol(),
                            " for ",
                            ERC20(assets[i]).symbol(),
                            " using 1inch V6 router"
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "oneInchExecutor");
                    leafs[leafIndex].argumentAddresses[1] = assets[j];
                    leafs[leafIndex].argumentAddresses[2] = assets[i];
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "oneInchExecutor");
                    leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
                    ownerToOneInchV6SellTokenToBuyTokenToInTree[
                        getAddress(sourceChain, "boringVault")
                    ][assets[j]][assets[i]] = true;
                }
            }
        }
    }

    function _addLeafsFor1InchV6Unoswap(ManageLeaf[] memory leafs, address token, address[] memory dexes) internal {
        require(dexes.length >= 1 && dexes.length <= 3, "Invalid number of dexes");

        // Add approval leaf if not already added
        if (!ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][token][getAddress(sourceChain, "aggregationRouterV6")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: token,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve 1Inch V6 router to spend ", ERC20(token).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "aggregationRouterV6");
            ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][token][getAddress(sourceChain, "aggregationRouterV6")] = true;
        }

        string memory sig;
        if (dexes.length == 1) sig = "unoswap(uint256,uint256,uint256,uint256)";
        else if (dexes.length == 2) sig = "unoswap2(uint256,uint256,uint256,uint256,uint256)";
        else sig = "unoswap3(uint256,uint256,uint256,uint256,uint256,uint256)";

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "aggregationRouterV6"),
            canSendValue: false,
            signature: sig,
            argumentAddresses: new address[](1 + dexes.length),
            description: string.concat("Unoswap ", ERC20(token).symbol(), " using 1inch V6 router"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = token;
        for (uint256 i; i < dexes.length; ++i) {
            leafs[leafIndex].argumentAddresses[1 + i] = dexes[i];
        }
    }

    function _addLeafsFor1InchV6EthUnoswap(ManageLeaf[] memory leafs, address[] memory dexes) internal {
        require(dexes.length >= 1 && dexes.length <= 3, "Invalid number of dexes");

        string memory sig;
        if (dexes.length == 1) sig = "ethUnoswap(uint256,uint256)";
        else if (dexes.length == 2) sig = "ethUnoswap2(uint256,uint256,uint256)";
        else sig = "ethUnoswap3(uint256,uint256,uint256,uint256)";

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "aggregationRouterV6"),
            canSendValue: true,
            signature: sig,
            argumentAddresses: new address[](dexes.length),
            description: "Eth unoswap using 1inch V6 router",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        for (uint256 i; i < dexes.length; ++i) {
            leafs[leafIndex].argumentAddresses[i] = dexes[i];
        }
    }

    // ========================================= 1Inch V6 Owned =========================================

    function _addLeafsFor1InchV6OwnedGeneralSwapping(
        ManageLeaf[] memory leafs,
        address[] memory assets,
        SwapKind[] memory kind
    ) internal {
        require(assets.length == kind.length, "Arrays must be of equal length");
        for (uint256 i; i < assets.length; ++i) {
            // Add approval leaf if not already added
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][assets[i]][getAddress(sourceChain, "aggregationRouterV6")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: assets[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve 1Inch V6 router to spend ", ERC20(assets[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "aggregationRouterV6");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][assets[i]][getAddress(sourceChain, "aggregationRouterV6")] = true;
            }
            // Iterate through the list again.
            for (uint256 j; j < assets.length; ++j) {
                // Skip if we are on the same index
                if (i == j) {
                    continue;
                }
                if (
                    !ownerToOneInchV6SellTokenToBuyTokenToInTree[
                            getAddress(sourceChain, "boringVault")
                        ][assets[i]][assets[j]] && kind[j] != SwapKind.Sell
                ) {
                    // Add sell swap.
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "aggregationRouterV6"),
                        canSendValue: false,
                        signature: "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes)",
                        argumentAddresses: new address[](3),
                        description: string.concat(
                            "Swap ",
                            ERC20(assets[i]).symbol(),
                            " for ",
                            ERC20(assets[j]).symbol(),
                            " using 1inch V6 router"
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = assets[i];
                    leafs[leafIndex].argumentAddresses[1] = assets[j];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
                    ownerToOneInchV6SellTokenToBuyTokenToInTree[
                        getAddress(sourceChain, "boringVault")
                    ][assets[i]][assets[j]] = true;
                }

                if (
                    kind[i] == SwapKind.BuyAndSell
                        && !ownerToOneInchV6SellTokenToBuyTokenToInTree[
                            getAddress(sourceChain, "boringVault")
                        ][assets[j]][assets[i]]
                ) {
                    // Add buy swap.
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "aggregationRouterV6"),
                        canSendValue: false,
                        signature: "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes)",
                        argumentAddresses: new address[](3),
                        description: string.concat(
                            "Swap ",
                            ERC20(assets[j]).symbol(),
                            " for ",
                            ERC20(assets[i]).symbol(),
                            " using 1inch V6 router"
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = assets[j];
                    leafs[leafIndex].argumentAddresses[1] = assets[i];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
                    ownerToOneInchV6SellTokenToBuyTokenToInTree[
                        getAddress(sourceChain, "boringVault")
                    ][assets[j]][assets[i]] = true;
                }
            }
        }
    }

    function _addLeafsFor1InchV6OwnedUnoswap(ManageLeaf[] memory leafs, address token, address[] memory dexes)
        internal
    {
        require(dexes.length >= 1 && dexes.length <= 3, "Invalid number of dexes");

        // Add approval leaf if not already added
        if (!ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][token][getAddress(sourceChain, "aggregationRouterV6")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: token,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve 1Inch V6 router to spend ", ERC20(token).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "aggregationRouterV6");
            ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][token][getAddress(sourceChain, "aggregationRouterV6")] = true;
        }

        string memory sig;
        if (dexes.length == 1) sig = "unoswap(uint256,uint256,uint256,uint256)";
        else if (dexes.length == 2) sig = "unoswap2(uint256,uint256,uint256,uint256,uint256)";
        else sig = "unoswap3(uint256,uint256,uint256,uint256,uint256,uint256)";

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "aggregationRouterV6"),
            canSendValue: false,
            signature: sig,
            argumentAddresses: new address[](1 + dexes.length),
            description: string.concat("Unoswap ", ERC20(token).symbol(), " using 1inch V6 router"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = token;
        for (uint256 i; i < dexes.length; ++i) {
            leafs[leafIndex].argumentAddresses[1 + i] = dexes[i];
        }
    }

    function _addLeafsFor1InchV6OwnedEthUnoswap(ManageLeaf[] memory leafs, address[] memory dexes) internal {
        require(dexes.length >= 1 && dexes.length <= 3, "Invalid number of dexes");

        string memory sig;
        if (dexes.length == 1) sig = "ethUnoswap(uint256,uint256)";
        else if (dexes.length == 2) sig = "ethUnoswap2(uint256,uint256,uint256)";
        else sig = "ethUnoswap3(uint256,uint256,uint256,uint256)";

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "aggregationRouterV6"),
            canSendValue: true,
            signature: sig,
            argumentAddresses: new address[](dexes.length),
            description: "Eth unoswap using 1inch V6 router",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        for (uint256 i; i < dexes.length; ++i) {
            leafs[leafIndex].argumentAddresses[i] = dexes[i];
        }
    }

    // ========================================= Curve/Convex =========================================
    // TODO need to use this in the test suite.
    function _addCurveLeafs(ManageLeaf[] memory leafs, address poolAddress, uint256 coinCount, address gauge) internal {
        CurvePool pool = CurvePool(poolAddress);
        ERC20[] memory coins = new ERC20[](coinCount);

        // Approve pool to spend tokens.
        for (uint256 i; i < coinCount; i++) {
            coins[i] = ERC20(pool.coins(i));
            // Approvals.
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(coins[i])][poolAddress]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(coins[i]),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Curve pool to spend ", coins[i].symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = poolAddress;
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(coins[i])][poolAddress] = true;
            }
        }

        // Add liquidity.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: poolAddress,
            canSendValue: false,
            signature: "add_liquidity(uint256[],uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Add liquidity to Curve pool"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        // Remove liquidity.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: poolAddress,
            canSendValue: false,
            signature: "remove_liquidity(uint256,uint256[])",
            argumentAddresses: new address[](0),
            description: string.concat("Remove liquidity from Curve pool"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        if (gauge != address(0)) {
            address lpToken = ICurveGauge(gauge).lp_token();

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: lpToken,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Curve gauge to spend ", ERC20(lpToken).name()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = gauge;

            // Deposit into gauge.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: gauge,
                canSendValue: false,
                signature: "deposit(uint256,address)",
                argumentAddresses: new address[](1),
                description: string.concat("Deposit ", ERC20(lpToken).name(), " into Curve gauge"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Withdraw from gauge.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: gauge,
                canSendValue: false,
                signature: "withdraw(uint256)",
                argumentAddresses: new address[](0),
                description: string.concat("Withdraw ", ERC20(lpToken).name(), " from Curve gauge"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });

            // Claim rewards.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: gauge,
                canSendValue: false,
                signature: "claim_rewards(address)",
                argumentAddresses: new address[](1),
                description: string.concat("Claim rewards from Curve gauge"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }
    }

    function _addCurveGaugeLeafs(ManageLeaf[] memory leafs, address gauge) internal {
        address lpToken = ICurveGauge(gauge).lp_token();

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: lpToken,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Curve gauge to spend ", ERC20(lpToken).name()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = gauge;

        // Deposit into gauge.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: gauge,
            canSendValue: false,
            signature: "deposit(uint256,address)",
            argumentAddresses: new address[](1),
            description: string.concat("Deposit ", ERC20(lpToken).name(), " into Curve gauge"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Withdraw from gauge.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: gauge,
            canSendValue: false,
            signature: "withdraw(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Withdraw ", ERC20(lpToken).name(), " from Curve gauge"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        // Claim rewards.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: gauge,
            canSendValue: false,
            signature: "claim_rewards(address)",
            argumentAddresses: new address[](1),
            description: string.concat("Claim rewards from Curve gauge"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    function _addCRVClaimingLeafs(ManageLeaf[] memory leafs, address gauge) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "curve_CRV_claiming"),
            canSendValue: false,
            signature: "mint(address)",
            argumentAddresses: new address[](1),
            description: string.concat("Claim CRV Rewards from Curve gauge"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = gauge;
    }

    function _addConvexLeafs(ManageLeaf[] memory leafs, ERC20 token, address rewardsContract) internal {
        // Approve convexCurveMainnetBooster to spend lp tokens.
        if (!ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][address(token)][getAddress(sourceChain, "convexCurveMainnetBooster")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(token),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Convex Curve Mainnet Booster to spend ", token.symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "convexCurveMainnetBooster");
            ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][address(token)][getAddress(sourceChain, "convexCurveMainnetBooster")] = true;
        }

        // Deposit into convexCurveMainnetBooster.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "convexCurveMainnetBooster"),
            canSendValue: false,
            signature: "deposit(uint256,uint256,bool)",
            argumentAddresses: new address[](0),
            description: "Deposit into Convex Curve Mainnet Booster",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        // Withdraw from rewardsContract.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: rewardsContract,
            canSendValue: false,
            signature: "withdrawAndUnwrap(uint256,bool)",
            argumentAddresses: new address[](0),
            description: "Withdraw and unwrap from Convex Curve Rewards Contract",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        // Get rewards from rewardsContract.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: rewardsContract,
            canSendValue: false,
            signature: "getReward(address,bool)",
            argumentAddresses: new address[](1),
            description: "Get rewards from Convex Curve Rewards Contract",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    function _addLeafsForCurveSwapping(ManageLeaf[] memory leafs, address curvePool) internal {
        CurvePool pool = CurvePool(curvePool);
        ERC20 coins0 = ERC20(pool.coins(0));
        ERC20 coins1 = ERC20(pool.coins(1));
        // Approvals.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(coins0),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Approve Curve ", coins0.symbol(), "/", coins1.symbol(), " pool to spend ", coins0.symbol()
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = curvePool;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(coins1),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Approve Curve ", coins0.symbol(), "/", coins1.symbol(), " pool to spend ", coins1.symbol()
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = curvePool;
        // Swapping.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: curvePool,
            canSendValue: false,
            signature: "exchange(int128,int128,uint256,uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Swap using Curve ", coins0.symbol(), "/", coins1.symbol(), " pool"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    function _addLeafsForCurveSwapping3Pool(ManageLeaf[] memory leafs, address curvePool) internal {
        CurvePool pool = CurvePool(curvePool);
        ERC20 coins0 = ERC20(pool.coins(0));
        ERC20 coins1 = ERC20(pool.coins(1));
        ERC20 coins2 = ERC20(pool.coins(2));
        // Approvals.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(coins0),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Approve Curve ",
                coins0.symbol(),
                "/",
                coins1.symbol(),
                "/",
                coins2.symbol(),
                " pool to spend ",
                coins0.symbol()
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = curvePool;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(coins1),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Approve Curve ",
                coins0.symbol(),
                "/",
                coins1.symbol(),
                "/",
                coins2.symbol(),
                " pool to spend ",
                coins1.symbol()
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = curvePool;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(coins2),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Approve Curve ",
                coins0.symbol(),
                "/",
                coins1.symbol(),
                "/",
                coins2.symbol(),
                " pool to spend ",
                coins2.symbol()
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = curvePool;
        // Swapping.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: curvePool,
            canSendValue: false,
            signature: "exchange(int128,int128,uint256,uint256)",
            argumentAddresses: new address[](0),
            description: string.concat(
                "Swap using Curve ", coins0.symbol(), "/", coins1.symbol(), "/", coins2.symbol(), " pool"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    function _addConvexFXBoosterLeafs(ManageLeaf[] memory leafs, address stakingAddress, address stakingToken)
        internal
    {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "convexFXBooster"),
            canSendValue: false,
            signature: "createVault(uint256)",
            argumentAddresses: new address[](2),
            description: string.concat("Create Vault for ", ERC20(stakingToken).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = stakingAddress;
        leafs[leafIndex].argumentAddresses[1] = stakingToken;
    }

    function _addConvexFXVaultLeafs(ManageLeaf[] memory leafs, address fxVault) internal {
        address stakingToken = IConvexFXVault(fxVault).stakingToken();

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: stakingToken,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Created FXVault to spend ", ERC20(stakingToken).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = fxVault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: fxVault,
            canSendValue: false,
            signature: "deposit(uint256,bool)",
            argumentAddresses: new address[](0),
            description: string.concat("Deposit ", ERC20(stakingToken).symbol(), " into created Convex FX Vault"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: fxVault,
            canSendValue: false,
            signature: "withdraw(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Withdraw ", ERC20(stakingToken).symbol(), " from created Convex FX Vault"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: fxVault,
            canSendValue: false,
            signature: "getReward(bool)",
            argumentAddresses: new address[](0),
            description: string.concat("Get Reward from ", ERC20(stakingToken).symbol(), " Convex FX Vault"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: fxVault,
            canSendValue: false,
            signature: "transferTokens(address[])",
            argumentAddresses: new address[](0),
            description: string.concat("Rescue Tokens from ", ERC20(stakingToken).symbol(), " Convex FX Vault"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= Usual Money =========================================

    function _addUsualMoneyLeafs(ManageLeaf[] memory leafs) internal {
        ERC20 USDC = getERC20(sourceChain, "USDC");
        ERC20 Usd0 = getERC20(sourceChain, "USD0");
        ERC20 Usd0PP = getERC20(sourceChain, "USD0_plus"); //new function added here
        address swapperEngine = getAddress(sourceChain, "usualSwapperEngine");

        // Approve Usd0PP to spend Usd0.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(Usd0),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Usd0PP to spend ", Usd0.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = address(Usd0PP);

        // Approve Usd0 to be swapped in swapper engine.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(Usd0),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Swapper Engine to spend ", Usd0.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = address(swapperEngine);

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(USDC),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Usual Swapper Engine to spend ", USDC.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = address(swapperEngine);

        // Call mint on Usd0PP.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(Usd0PP),
            canSendValue: false,
            signature: "mint(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Mint Usd0PP"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        //Call unlock on Usd0pp
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(Usd0PP),
            canSendValue: false,
            signature: "unlockUsd0ppFloorPrice(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Unlock Usd0PP at the USD0 floor price"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        // Call unwrap on Usd0PP.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(Usd0PP),
            canSendValue: false,
            signature: "unwrap()",
            argumentAddresses: new address[](0),
            description: string.concat("Unwrap Usd0PP"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(swapperEngine),
            canSendValue: false,
            signature: "depositUSDC(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Deposit USDC to swap for USD0"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(swapperEngine),
            canSendValue: false,
            signature: "provideUsd0ReceiveUSDC(address,uint256,uint256[],bool)",
            argumentAddresses: new address[](1),
            description: string.concat("Deposit USDC to swap for USD0"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(swapperEngine),
            canSendValue: false,
            signature: "swapUsd0(address,uint256,uint256[],bool)",
            argumentAddresses: new address[](1),
            description: string.concat("Swap USD0 for USDC"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(swapperEngine),
            canSendValue: false,
            signature: "withdrawUSDC(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Cancel order for USDC swap"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= Treehouse =========================================

    function _addTreehouseLeafs(
        ManageLeaf[] memory leafs,
        ERC20[] memory routerTokensIn,
        address router,
        address redemptionContract,
        ERC20 tAsset,
        address poolAddress,
        uint256 coinCount,
        address gauge
    ) internal {
        for (uint256 i; i < routerTokensIn.length; ++i) {
            // Approve Treehouse Router to spend tokens in.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(routerTokensIn[i]),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Treehouse Router to spend ", routerTokensIn[i].symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = router;

            // Deposit into Treehouse contract using router.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: router,
                canSendValue: false,
                signature: "deposit(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat(
                    "Deposit into Treehouse contract using router with ", routerTokensIn[i].symbol()
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(routerTokensIn[i]);
        }

        // Approve redemption contract to spend tAsset.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(tAsset),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve redemption contract to spend ", tAsset.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = redemptionContract;

        // Redeem tAsset.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: redemptionContract,
            canSendValue: false,
            signature: "redeem(uint96)",
            argumentAddresses: new address[](0),
            description: string.concat("Redeem ", tAsset.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        // Finalize redeem.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: redemptionContract,
            canSendValue: false,
            signature: "finalizeRedeem(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Finalize redeem ", tAsset.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        _addCurveLeafs(leafs, poolAddress, coinCount, gauge);
    }

    // ========================================= StandardBridge =========================================

    error StandardBridge__LocalAndRemoteTokensLengthMismatch();

    function _addStandardBridgeLeafs(
        ManageLeaf[] memory leafs,
        string memory destination,
        address destinationCrossDomainMessenger,
        address sourceResolvedDelegate,
        address sourceStandardBridge,
        address sourcePortal,
        ERC20[] memory localTokens,
        ERC20[] memory remoteTokens
    ) internal virtual {
        if (localTokens.length != remoteTokens.length) {
            revert StandardBridge__LocalAndRemoteTokensLengthMismatch();
        }
        // Approvals
        for (uint256 i; i < localTokens.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(localTokens[i]),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve StandardBridge to spend ", localTokens[i].symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = sourceStandardBridge;
        }

        // ERC20 bridge leafs.
        for (uint256 i; i < localTokens.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: sourceStandardBridge,
                canSendValue: false,
                signature: "bridgeERC20To(address,address,address,uint256,uint32,bytes)",
                argumentAddresses: new address[](3),
                description: string.concat(
                    "Bridge ", localTokens[i].symbol(), " from ", sourceChain, " to ", destination
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(localTokens[i]);
            leafs[leafIndex].argumentAddresses[1] = address(remoteTokens[i]);
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        }

        if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mantle))) {
            // Mantle uses a nonstand `bridgeETHTo` function on their L2.
            // Bridge ETH.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: sourceStandardBridge,
                canSendValue: false,
                signature: "bridgeETHTo(uint256,address,uint32,bytes)",
                argumentAddresses: new address[](1),
                description: string.concat("Bridge ETH from ", sourceChain, " to ", destination),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        } else {
            // Bridge ETH.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: sourceStandardBridge,
                canSendValue: true,
                signature: "bridgeETHTo(address,uint32,bytes)",
                argumentAddresses: new address[](1),
                description: string.concat("Bridge ETH from ", sourceChain, " to ", destination),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }

        // If we are generating leafs for some L2 back to mainnet, these leafs are not needed.
        if (keccak256(abi.encode(destination)) != keccak256(abi.encode(mainnet))) {
            if (keccak256(abi.encode(destination)) == keccak256(abi.encode(mantle))) {
                // Prove withdrawal transaction.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: sourcePortal,
                    canSendValue: false,
                    signature: "proveWithdrawalTransaction((uint256,address,address,uint256,uint256,uint256,bytes),uint256,(bytes32,bytes32,bytes32,bytes32),bytes[])",
                    argumentAddresses: new address[](2),
                    description: string.concat("Prove withdrawal transaction from ", destination, " to ", sourceChain),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
                leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;

                // Finalize withdrawal transaction.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: sourcePortal,
                    canSendValue: false,
                    signature: "finalizeWithdrawalTransaction((uint256,address,address,uint256,uint256,uint256,bytes))",
                    argumentAddresses: new address[](2),
                    description: string.concat(
                        "Finalize withdrawal transaction from ", destination, " to ", sourceChain
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
                leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;
            } else {
                // Prove withdrawal transaction.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: sourcePortal,
                    canSendValue: false,
                    signature: "proveWithdrawalTransaction((uint256,address,address,uint256,uint256,bytes),uint256,(bytes32,bytes32,bytes32,bytes32),bytes[])",
                    argumentAddresses: new address[](2),
                    description: string.concat("Prove withdrawal transaction from ", destination, " to ", sourceChain),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
                leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;

                // Finalize withdrawal transaction.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: sourcePortal,
                    canSendValue: false,
                    signature: "finalizeWithdrawalTransaction((uint256,address,address,uint256,uint256,bytes))",
                    argumentAddresses: new address[](2),
                    description: string.concat(
                        "Finalize withdrawal transaction from ", destination, " to ", sourceChain
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
                leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;
            }
        }
    }

    function _addLidoStandardBridgeLeafs(
        ManageLeaf[] memory leafs,
        string memory destination,
        address destinationCrossDomainMessenger,
        address sourceResolvedDelegate,
        address sourceStandardBridge,
        address sourcePortal
    ) internal virtual {
        ERC20 localToken = getERC20(sourceChain, "WSTETH");
        ERC20 remoteToken = getERC20(destination, "WSTETH");
        if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mainnet))) {
            // Approvals
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(localToken),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve StandardBridge to spend ", localToken.symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = sourceStandardBridge;

            // ERC20 bridge leafs.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: sourceStandardBridge,
                canSendValue: false,
                signature: "depositERC20To(address,address,address,uint256,uint32,bytes)",
                argumentAddresses: new address[](3),
                description: string.concat("Bridge ", localToken.symbol(), " from ", sourceChain, " to ", destination),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(localToken);
            leafs[leafIndex].argumentAddresses[1] = address(remoteToken);
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // Prove withdrawal transaction.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: sourcePortal,
                canSendValue: false,
                signature: "proveWithdrawalTransaction((uint256,address,address,uint256,uint256,bytes),uint256,(bytes32,bytes32,bytes32,bytes32),bytes[])",
                argumentAddresses: new address[](2),
                description: string.concat("Prove withdrawal transaction from ", destination, " to ", sourceChain),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
            leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;

            // Finalize withdrawal transaction.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: sourcePortal,
                canSendValue: false,
                signature: "finalizeWithdrawalTransaction((uint256,address,address,uint256,uint256,bytes))",
                argumentAddresses: new address[](2),
                description: string.concat("Finalize withdrawal transaction from ", destination, " to ", sourceChain),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
            leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;
        } else if (keccak256(abi.encode(destination)) == keccak256(abi.encode(mainnet))) {
            // We are bridging back to mainnet.
            // Approve L2 ERC20 Token Bridge to spent wstETH.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(localToken),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve L2 ERC20 Token Bridge to spend ", localToken.symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = sourceStandardBridge;

            // call withdrawTo.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: sourceStandardBridge,
                canSendValue: false,
                signature: "withdrawTo(address,address,uint256,uint32,bytes)",
                argumentAddresses: new address[](2),
                description: string.concat("Withdraw wstETH to ", destination),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(localToken);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
    }

    // ========================================= Arbitrum Native Bridge =========================================

    /// @notice When sourceChain is arbitrum bridgeAssets MUST be mainnet addresses.
    function _addArbitrumNativeBridgeLeafs(ManageLeaf[] memory leafs, ERC20[] memory bridgeAssets) internal {
        if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mainnet))) {
            // Bridge ERC20 Assets to Arbitrum
            bool hasWstETH = false;
            bool hasWETH = false;
            bool hasOtherERC20 = false;
            for (uint256 i; i < bridgeAssets.length; i++) {
                bool isWstETH = address(bridgeAssets[i]) == getAddress(sourceChain, "WSTETH");
                bool isWETH = address(bridgeAssets[i]) == getAddress(sourceChain, "WETH");
                address spender;
                if (isWstETH) {
                    spender = getAddress(sourceChain, "arbitrumL1ERC20GatewayLido");
                    hasWstETH = true;
                } else if (isWETH) {
                    spender = getAddress(sourceChain, "arbitrumWethGateway");
                    hasWETH = true;
                } else {
                    spender = getAddress(sourceChain, "arbitrumL1ERC20Gateway");
                    hasOtherERC20 = true;
                }
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(bridgeAssets[i]),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Arbitrum L1 Gateway to spend ", bridgeAssets[i].symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = spender;
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "arbitrumL1GatewayRouter"),
                    canSendValue: true,
                    signature: "outboundTransfer(address,address,uint256,uint256,uint256,bytes)",
                    argumentAddresses: new address[](2),
                    description: string.concat("Bridge ", bridgeAssets[i].symbol(), " to Arbitrum"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(bridgeAssets[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "arbitrumL1GatewayRouter"),
                    canSendValue: true,
                    signature: "outboundTransferCustomRefund(address,address,address,uint256,uint256,uint256,bytes)",
                    argumentAddresses: new address[](3),
                    description: string.concat("Bridge ", bridgeAssets[i].symbol(), " to Arbitrum"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(bridgeAssets[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            }
            // Create Retryable Ticket
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "arbitrumDelayedInbox"),
                canSendValue: false,
                signature: "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
                argumentAddresses: new address[](3),
                description: "Create retryable ticket for Arbitrum",
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // Unsafe Create Retryable Ticket
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "arbitrumDelayedInbox"),
                canSendValue: false,
                signature: "unsafeCreateRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
                argumentAddresses: new address[](3),
                description: "Unsafe Create retryable ticket for Arbitrum",
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // Create Retryable Ticket
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "arbitrumDelayedInbox"),
                canSendValue: true,
                signature: "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
                argumentAddresses: new address[](3),
                description: "Create retryable ticket for Arbitrum",
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // Unsafe Create Retryable Ticket
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "arbitrumDelayedInbox"),
                canSendValue: true,
                signature: "unsafeCreateRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
                argumentAddresses: new address[](3),
                description: "Unsafe Create retryable ticket for Arbitrum",
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            if (hasOtherERC20) {
                // Execute Transaction For ERC20 claim.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "arbitrumOutbox"),
                    canSendValue: false,
                    signature: "executeTransaction(bytes32[],uint256,address,address,uint256,uint256,uint256,uint256,bytes)",
                    argumentAddresses: new address[](2),
                    description: "Execute transaction to claim ERC20",
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(arbitrum, "arbitrumL2Sender");
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "arbitrumL1ERC20Gateway");
            }
            if (hasWstETH) {
                // Execute Transaction For WSTETH claim.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "arbitrumOutbox"),
                    canSendValue: false,
                    signature: "executeTransaction(bytes32[],uint256,address,address,uint256,uint256,uint256,uint256,bytes)",
                    argumentAddresses: new address[](2),
                    description: "Execute transaction to claim WSTETH",
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(arbitrum, "arbitrumL2SenderLido");
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "arbitrumL1ERC20GatewayLido");
            }
            if (hasWETH) {
                // Execute Transaction For WETH claim.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "arbitrumOutbox"),
                    canSendValue: false,
                    signature: "executeTransaction(bytes32[],uint256,address,address,uint256,uint256,uint256,uint256,bytes)",
                    argumentAddresses: new address[](2),
                    description: "Execute transaction to claim WETH",
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(arbitrum, "arbitrumL2SenderWeth");
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "arbitrumWethGateway");
            }

            // Execute Transaction For ETH claim.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "arbitrumOutbox"),
                canSendValue: false,
                signature: "executeTransaction(bytes32[],uint256,address,address,uint256,uint256,uint256,uint256,bytes)",
                argumentAddresses: new address[](2),
                description: "Execute transaction to claim ETH",
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        } else if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(arbitrum))) {
            // ERC20 bridge withdraws.
            for (uint256 i; i < bridgeAssets.length; ++i) {
                // outboundTransfer
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "arbitrumL2GatewayRouter"),
                    canSendValue: false,
                    signature: "outboundTransfer(address,address,uint256,bytes)",
                    argumentAddresses: new address[](2),
                    description: string.concat("Withdraw ", vm.toString(address(bridgeAssets[i])), " from Arbitrum"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(bridgeAssets[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            }

            // WithdrawEth
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "arbitrumSys"),
                canSendValue: true,
                signature: "withdrawEth(address)",
                argumentAddresses: new address[](1),
                description: "Withdraw ETH from Arbitrum",
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Redeem
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "arbitrumRetryableTx"),
                canSendValue: false,
                signature: "redeem(bytes32)",
                argumentAddresses: new address[](0),
                description: "Redeem retryable ticket on Arbitrum",
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
        } else {
            revert("Unsupported chain for Arbitrum Native Bridge");
        }
    }

    // ========================================= Linea Native Bridge =========================================

    function _addLineaNativeBridgeLeafs(
        ManageLeaf[] memory leafs,
        string memory destination,
        ERC20[] memory localTokens
    ) internal {
        // Approve the source chains tokenBridge to spend local tokens.
        for (uint256 i; i < localTokens.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(localTokens[i]),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat(
                    "Approve Linea ", sourceChain, " tokenBridge to spend ", localTokens[i].symbol()
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "tokenBridge");

            // Call bridgeToken to bridge the token.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "tokenBridge"),
                canSendValue: false,
                signature: "bridgeToken(address,uint256,address)",
                argumentAddresses: new address[](2),
                description: string.concat(
                    "Bridge ", localTokens[i].symbol(), " from ", sourceChain, " to ", destination
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(localTokens[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "tokenBridge"),
                canSendValue: true,
                signature: "bridgeToken(address,uint256,address)",
                argumentAddresses: new address[](2),
                description: string.concat(
                    "Bridge ", localTokens[i].symbol(), " from ", sourceChain, " to ", destination
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(localTokens[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }

        if (localTokens.length > 0) {
            if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mainnet))) {
                // Call claimMessageWithProof to handle claiming ERC20s.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "lineaMessageService"),
                    canSendValue: false,
                    signature: "claimMessageWithProof((bytes32[],uint256,uint32,address,address,uint256,uint256,address,bytes32,bytes))",
                    argumentAddresses: new address[](3),
                    description: string.concat(
                        "Claim ERC20s from ", destination, " Token Bridge to ", sourceChain, " Token Bridge"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(destination, "tokenBridge");
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "tokenBridge");
                leafs[leafIndex].argumentAddresses[2] = address(0);
            } else if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(linea))) {
                // Use claimMessage Leaf instead of claimMessageWithProof.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "lineaMessageService"),
                    canSendValue: false,
                    signature: "claimMessage(address,address,uint256,uint256,address,bytes,uint256)",
                    argumentAddresses: new address[](3),
                    description: string.concat(
                        "Claim ERC20s from ", destination, " Token Bridge to ", sourceChain, " Token Bridge"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(destination, "tokenBridge");
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "tokenBridge");
                leafs[leafIndex].argumentAddresses[2] = address(0);
            }
        }

        // Call sendMessage to send ETH.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "lineaMessageService"),
            canSendValue: true,
            signature: "sendMessage(address,uint256,bytes)",
            argumentAddresses: new address[](1),
            description: string.concat("Send ETH from ", sourceChain, " to ", destination),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Call claimMessage to handle claiming ETH.
        if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mainnet))) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "lineaMessageService"),
                canSendValue: false,
                signature: "claimMessageWithProof((bytes32[],uint256,uint32,address,address,uint256,uint256,address,bytes32,bytes))",
                argumentAddresses: new address[](3),
                description: string.concat(
                    "Claim ETH from ", destination, " Token Bridge to ", sourceChain, " Token Bridge"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = address(0);
        } else if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(linea))) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "lineaMessageService"),
                canSendValue: false,
                signature: "claimMessage(address,address,uint256,uint256,address,bytes,uint256)",
                argumentAddresses: new address[](3),
                description: string.concat(
                    "Claim ETH from ", destination, " Token Bridge to ", sourceChain, " Token Bridge"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = address(0);
        }
    }

    // ========================================= Scroll Native Bridge =========================================

    function _addScrollNativeBridgeLeafs(
        ManageLeaf[] memory leafs,
        string memory destination,
        ERC20[] memory localTokens,
        address[] memory scrollGateways
    ) internal {
        if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mainnet))) {
            // Add leaf for bridging ETH.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "scrollMessenger"),
                canSendValue: true,
                signature: "sendMessage(address,uint256,bytes,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Bridge ETH from ", sourceChain, " to ", mainnet),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Add leafs for bridging and claiming ERC20s.
            for (uint256 i; i < localTokens.length; ++i) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(localTokens[i]),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Scroll Gateway Router to spend ", localTokens[i].symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "scrollGatewayRouter");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "scrollGatewayRouter"),
                    canSendValue: true,
                    signature: "depositERC20(address,address,uint256,uint256)",
                    argumentAddresses: new address[](2),
                    description: string.concat(
                        "Bridge ", localTokens[i].symbol(), " from ", sourceChain, " to ", destination
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(localTokens[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

                address mainnetGateway = IScrollGateway(getAddress(sourceChain, "scrollGatewayRouter"))
                    .getERC20Gateway(address(localTokens[i]));
                // Add leaf for ERC20 claiming.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "scrollMessenger"),
                    canSendValue: false,
                    signature: "relayMessageWithProof(address,address,uint256,uint256,bytes,(uint256,bytes))",
                    argumentAddresses: new address[](2),
                    description: string.concat(
                        "Claim ", localTokens[i].symbol(), " from ", destination, " to ", sourceChain
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = scrollGateways[i];
                leafs[leafIndex].argumentAddresses[1] = mainnetGateway;
            }

            // Add leaf for claiming ETH.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "scrollMessenger"),
                canSendValue: false,
                signature: "relayMessageWithProof(address,address,uint256,uint256,bytes,(uint256,bytes))",
                argumentAddresses: new address[](2),
                description: string.concat("Claim ETH from ", destination, " to ", sourceChain),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        } else if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(scroll))) {
            // Add leafs for withdrawing ETH.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "scrollMessenger"),
                canSendValue: true,
                signature: "sendMessage(address,uint256,bytes,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Bridge ETH from ", sourceChain, " to ", destination),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Add leafs for withdrawing ERC20s.
            for (uint256 i; i < localTokens.length; ++i) {
                address gateway = IScrollGateway(getAddress(sourceChain, "scrollGatewayRouter"))
                    .getERC20Gateway(address(localTokens[i]));

                //most tokens won't need an approval, but some do (USDC, WETH)
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(localTokens[i]),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve ERC20 Gateway to spend ", localTokens[i].symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = gateway;

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "scrollGatewayRouter"),
                    canSendValue: false,
                    signature: "withdrawERC20(address,address,uint256,uint256)",
                    argumentAddresses: new address[](2),
                    description: string.concat(
                        "Withdraw ", localTokens[i].symbol(), " from ", sourceChain, " to ", destination
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(localTokens[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            }
        }
    }

    // ========================================= CCIP Send =========================================

    function _addCcipBridgeLeafs(
        ManageLeaf[] memory leafs,
        uint64 destinationChainId,
        ERC20[] memory bridgeAssets,
        ERC20[] memory feeTokens
    ) internal {
        // Bridge ERC20 Assets
        for (uint256 i; i < feeTokens.length; i++) {
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(feeTokens[i])][getAddress(sourceChain, "ccipRouter")]) {
                // Add fee token approval.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(feeTokens[i]),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat(
                        "Approve ", sourceChain, " CCIP Router to spend ", feeTokens[i].symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "ccipRouter");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(feeTokens[i])][getAddress(sourceChain, "ccipRouter")] = true;
            }
            for (uint256 j; j < bridgeAssets.length; j++) {
                if (!ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][address(bridgeAssets[j])][getAddress(sourceChain, "ccipRouter")]) {
                    // Add bridge asset approval.
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: address(bridgeAssets[j]),
                        canSendValue: false,
                        signature: "approve(address,uint256)",
                        argumentAddresses: new address[](1),
                        description: string.concat(
                            "Approve ", sourceChain, " CCIP Router to spend ", bridgeAssets[j].symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "ccipRouter");
                    ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][address(bridgeAssets[j])][getAddress(sourceChain, "ccipRouter")] = true;
                }
                // Add ccipSend leaf.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "ccipRouter"),
                    canSendValue: false,
                    signature: "ccipSend(uint64,(bytes,bytes,(address,uint256)[],address,bytes))",
                    argumentAddresses: new address[](4),
                    description: string.concat(
                        "Bridge ",
                        bridgeAssets[j].symbol(),
                        " to chain ",
                        vm.toString(destinationChainId),
                        " using CCIP"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(uint160(destinationChainId));
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                leafs[leafIndex].argumentAddresses[2] = address(bridgeAssets[j]);
                leafs[leafIndex].argumentAddresses[3] = address(feeTokens[i]);
            }
        }
    }

    // ========================================= PancakeSwap V3 =========================================

    function _addPancakeSwapV3Leafs(ManageLeaf[] memory leafs, address[] memory token0, address[] memory token1)
        internal
    {
        require(token0.length == token1.length, "Token arrays must be of equal length");
        for (uint256 i; i < token0.length; ++i) {
            (token0[i], token1[i]) = token0[i] < token1[i] ? (token0[i], token1[i]) : (token1[i], token0[i]);
            // Approvals
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token0[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat(
                        "Approve PancakeSwapV3 NonFungible Position Manager to spend ", ERC20(token0[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] =
                    getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager")] = true;
            }
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1[i]][getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token1[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat(
                        "Approve PancakeSwapV3 NonFungible Position Manager to spend ", ERC20(token1[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] =
                    getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1[i]][getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager")] = true;
            }
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][getAddress(sourceChain, "pancakeSwapV3MasterChefV3")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token0[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat(
                        "Approve PancakeSwapV3 Master Chef to spend ", ERC20(token0[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][getAddress(sourceChain, "pancakeSwapV3MasterChefV3")] = true;
            }
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1[i]][getAddress(sourceChain, "pancakeSwapV3MasterChefV3")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token1[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat(
                        "Approve PancakeSwapV3 Master Chef to spend ", ERC20(token1[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1[i]][getAddress(sourceChain, "pancakeSwapV3MasterChefV3")] = true;
            }

            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][getAddress(sourceChain, "pancakeSwapV3Router")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token0[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve PancakeSwapV3 Router to spend ", ERC20(token0[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pancakeSwapV3Router");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][getAddress(sourceChain, "pancakeSwapV3Router")] = true;
            }
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1[i]][getAddress(sourceChain, "pancakeSwapV3Router")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token1[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve PancakeSwapV3 Router to spend ", ERC20(token1[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pancakeSwapV3Router");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1[i]][getAddress(sourceChain, "pancakeSwapV3Router")] = true;
            }

            // Minting
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
                canSendValue: false,
                signature: "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
                argumentAddresses: new address[](3),
                description: string.concat(
                    "Mint PancakeSwapV3 ", ERC20(token0[i]).symbol(), " ", ERC20(token1[i]).symbol(), " position"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            // Increase liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
                canSendValue: false,
                signature: "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
                argumentAddresses: new address[](5),
                description: string.concat(
                    "Add liquidity to PancakeSwapV3 ",
                    ERC20(token0[i]).symbol(),
                    " ",
                    ERC20(token1[i]).symbol(),
                    " position"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(0);
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = token1[i];
            leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[4] = address(0);

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "pancakeSwapV3MasterChefV3"),
                canSendValue: false,
                signature: "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
                argumentAddresses: new address[](5),
                description: string.concat(
                    "Add liquidity to PancakeSwapV3 ",
                    ERC20(token0[i]).symbol(),
                    " ",
                    ERC20(token1[i]).symbol(),
                    " staked position"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(0);
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = token1[i];
            leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");
            leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");

            // Swapping to move tick in pool.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "pancakeSwapV3Router"),
                canSendValue: false,
                signature: "exactInput((bytes,address,uint256,uint256))",
                argumentAddresses: new address[](3),
                description: string.concat(
                    "Swap ",
                    ERC20(token0[i]).symbol(),
                    " for ",
                    ERC20(token1[i]).symbol(),
                    " using PancakeSwapV3 router"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "pancakeSwapV3Router"),
                canSendValue: false,
                signature: "exactInput((bytes,address,uint256,uint256))",
                argumentAddresses: new address[](3),
                description: string.concat(
                    "Swap ",
                    ERC20(token1[i]).symbol(),
                    " for ",
                    ERC20(token0[i]).symbol(),
                    " using PancakeSwapV3 router"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = token1[i];
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        }
        // Decrease liquidity
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
            canSendValue: false,
            signature: "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            argumentAddresses: new address[](2),
            description: "Remove liquidity from PancakeSwapV3 position",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = address(0);

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pancakeSwapV3MasterChefV3"),
            canSendValue: false,
            signature: "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            argumentAddresses: new address[](2),
            description: "Remove liquidity from PancakeSwapV3 staked position",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
            canSendValue: false,
            signature: "collect((uint256,address,uint128,uint128))",
            argumentAddresses: new address[](3),
            description: "Collect fees from PancakeSwapV3 position",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[2] = address(0);

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pancakeSwapV3MasterChefV3"),
            canSendValue: false,
            signature: "collect((uint256,address,uint128,uint128))",
            argumentAddresses: new address[](3),
            description: "Collect fees from PancakeSwapV3 staked position",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

        // burn
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
            canSendValue: false,
            signature: "burn(uint256)",
            argumentAddresses: new address[](0),
            description: "Burn PancakeSwapV3 position",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        // Staking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
            canSendValue: false,
            signature: "safeTransferFrom(address,address,uint256)",
            argumentAddresses: new address[](2),
            description: "Stake PancakeSwapV3 position",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");

        // Staking harvest.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pancakeSwapV3MasterChefV3"),
            canSendValue: false,
            signature: "harvest(uint256,address)",
            argumentAddresses: new address[](1),
            description: "Harvest rewards from PancakeSwapV3 staked postiion",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Unstaking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pancakeSwapV3MasterChefV3"),
            canSendValue: false,
            signature: "withdraw(uint256,address)",
            argumentAddresses: new address[](1),
            description: "Unstake PancakeSwapV3 position",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Native =========================================

    function _addNativeLeafs(ManageLeaf[] memory leafs) internal {
        _addNativeLeafs(leafs, getAddress(sourceChain, "WETH"));
    }

    function _addNativeLeafs(ManageLeaf[] memory leafs, address wrappedToken) internal {
        // Wrapping
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: wrappedToken,
            canSendValue: true,
            signature: "deposit()",
            argumentAddresses: new address[](0),
            description: string.concat("Wrap Native to ", ERC20(wrappedToken).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: wrappedToken,
            canSendValue: false,
            signature: "withdraw(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Unwrap ", ERC20(wrappedToken).symbol(), " to Native"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= EtherFi =========================================

    function _addEtherFiLeafs(ManageLeaf[] memory leafs) internal {
        // Approvals
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "EETH"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Approve WEETH to spend eETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "WEETH");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "EETH"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Approve EtherFi Liquidity Pool to spend eETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "EETH_LIQUIDITY_POOL");
        // Staking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "EETH_LIQUIDITY_POOL"),
            canSendValue: true,
            signature: "deposit()",
            argumentAddresses: new address[](0),
            description: "Stake ETH for eETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        // Unstaking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "EETH_LIQUIDITY_POOL"),
            canSendValue: false,
            signature: "requestWithdraw(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Request withdrawal from eETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "withdrawalRequestNft"),
            canSendValue: false,
            signature: "claimWithdraw(uint256)",
            argumentAddresses: new address[](0),
            description: "Claim eETH withdrawal",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        // Wrapping
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "WEETH"),
            canSendValue: false,
            signature: "wrap(uint256)",
            argumentAddresses: new address[](0),
            description: "Wrap eETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "WEETH"),
            canSendValue: false,
            signature: "unwrap(uint256)",
            argumentAddresses: new address[](0),
            description: "Unwrap weETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        //deposit ERC20s
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "STETH"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Approve EtherFi Vampire Pool to spend STETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "etherFiVampirePool");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "etherFiVampirePool"),
            canSendValue: false,
            signature: "depositWithERC20(address,uint256,address)",
            argumentAddresses: new address[](2),
            description: "Deposit ERC20 for eETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "STETH");
        leafs[leafIndex].argumentAddresses[1] = address(0);
    }

    // ========================================= LIDO =========================================

    function _addLidoLeafs(ManageLeaf[] memory leafs) internal {
        // Approvals
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "STETH"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Approve WSTETH to spend stETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "WSTETH");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "STETH"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Approve unstETH to spend stETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "unstETH");
        // Staking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "STETH"),
            canSendValue: true,
            signature: "submit(address)",
            argumentAddresses: new address[](1),
            description: "Stake ETH for stETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = address(0);
        // Unstaking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "unstETH"),
            canSendValue: false,
            signature: "requestWithdrawals(uint256[],address)",
            argumentAddresses: new address[](1),
            description: "Request withdrawals from stETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "unstETH"),
            canSendValue: false,
            signature: "claimWithdrawal(uint256)",
            argumentAddresses: new address[](0),
            description: "Claim stETH withdrawal",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "unstETH"),
            canSendValue: false,
            signature: "claimWithdrawals(uint256[],uint256[])",
            argumentAddresses: new address[](0),
            description: "Claim stETH withdrawals",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        // Wrapping
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "WSTETH"),
            canSendValue: false,
            signature: "wrap(uint256)",
            argumentAddresses: new address[](0),
            description: "Wrap stETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "WSTETH"),
            canSendValue: false,
            signature: "unwrap(uint256)",
            argumentAddresses: new address[](0),
            description: "Unwrap wstETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= MFOne =========================================
    function _addMfOneLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "USDC"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Approve USDC to be spent by MF-ONE Deposit Vault",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "mfOneDepositVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "MF-ONE"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Approve MF-ONE to be spent by MF-ONE Redemption Vault",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "mfOneRedemptionVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "mfOneDepositVault"),
            canSendValue: false,
            signature: "depositInstant(address,uint256,uint256,bytes32)",
            argumentAddresses: new address[](3),
            description: "Deposit Instant USDC for MFONE",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDC");
        leafs[leafIndex].argumentAddresses[1] = address(0);
        leafs[leafIndex].argumentAddresses[2] = address(0);

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "mfOneDepositVault"),
            canSendValue: false,
            signature: "depositRequest(address,uint256,bytes32)",
            argumentAddresses: new address[](3),
            description: "Deposit Request USDC for MFONE",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDC");
        leafs[leafIndex].argumentAddresses[1] = address(0);
        leafs[leafIndex].argumentAddresses[2] = address(0);

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "mfOneRedemptionVault"),
            canSendValue: false,
            signature: "redeemInstant(address,uint256,uint256)",
            argumentAddresses: new address[](1),
            description: "Redeem Instant MFONE for USDC",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDC");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "mfOneRedemptionVault"),
            canSendValue: false,
            signature: "redeemRequest(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Redeem Request MFONE for USDC",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDC");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "mfOneRedemptionVault"),
            canSendValue: false,
            signature: "redeemFiatRequest(uint256)",
            argumentAddresses: new address[](0),
            description: "Redeem Fiat Request MFONE",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= Kinetiq KHYPE =========================================
    function _addKHypeLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "KHYPE"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Approve kHype to be spent by kHype Staking Manager",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "kHypeStakingManager");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "kHypeStakingManager"),
            canSendValue: true,
            signature: "stake()",
            argumentAddresses: new address[](0),
            description: "Stake HYPE for KHYPE",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "kHypeStakingManager"),
            canSendValue: false,
            signature: "queueWithdrawal(uint256)",
            argumentAddresses: new address[](0),
            description: "Queue Withdraw on KHYPE",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "kHypeStakingManager"),
            canSendValue: false,
            signature: "confirmWithdrawal(uint256)",
            argumentAddresses: new address[](0),
            description: "Confirm Withdraw on KHYPE and receive HYPE",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= Frax =========================================

    function _addFraxLeafs(ManageLeaf[] memory leafs) internal {
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SFRXETH")));
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "FRXETH"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Approve frxETH Redemption Ticket to spend frxETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "frxETHRedemptionTicket");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "SFRXETH"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Approve frxETH Redemption Ticket to spend sfrxETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "frxETHRedemptionTicket");

        // Staking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "frxETHMinter"),
            canSendValue: true,
            signature: "submit()",
            argumentAddresses: new address[](0),
            description: "Stake ETH for frxETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        // Unstaking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "frxETHRedemptionTicket"),
            canSendValue: false,
            signature: "enterRedemptionQueue(address,uint120)",
            argumentAddresses: new address[](1),
            description: "Request withdrawal from frxETH using frxETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "frxETHRedemptionTicket"),
            canSendValue: false,
            signature: "enterRedemptionQueueViaSfrxEth(address,uint120)",
            argumentAddresses: new address[](1),
            description: "Request withdrawal from frxETH using sfrxETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Complete withdrawal
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "frxETHRedemptionTicket"),
            canSendValue: false,
            signature: "burnRedemptionTicketNft(uint256,address)",
            argumentAddresses: new address[](1),
            description: "Claim frxETH withdrawal",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "frxETHRedemptionTicket"),
            canSendValue: false,
            signature: "earlyBurnRedemptionTicketNft(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Cancel frxETH withdrawal with penalty",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Swell Staking =========================================

    function _addSwellStakingLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "SWETH"),
            canSendValue: true,
            signature: "deposit()",
            argumentAddresses: new address[](0),
            description: "Stake ETH for swETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "SWETH"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Approve swEXIT to spend swETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "swEXIT");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "swEXIT"),
            canSendValue: false,
            signature: "createWithdrawRequest(uint256)",
            argumentAddresses: new address[](0),
            description: "Create a withdraw request from swETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "swEXIT"),
            canSendValue: false,
            signature: "finalizeWithdrawal(uint256)",
            argumentAddresses: new address[](0),
            description: "Finalize a swETH withdraw request",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    function _addRsWETHUnstakingLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "RSWETH"),
            canSendValue: true,
            signature: "deposit()",
            argumentAddresses: new address[](0),
            description: "Stake ETH for rswETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "RSWETH"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Approve rswEXIT to spend rswETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "rswEXIT");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "rswEXIT"),
            canSendValue: false,
            signature: "createWithdrawRequest(uint256)",
            argumentAddresses: new address[](0),
            description: "Create a withdraw request from rswETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "rswEXIT"),
            canSendValue: false,
            signature: "finalizeWithdrawal(uint256)",
            argumentAddresses: new address[](0),
            description: "Finalize a rswETH withdraw request",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= Mantle Staking =========================================

    function _addMantleStakingLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "mantleLspStaking"),
            canSendValue: true,
            signature: "stake(uint256)",
            argumentAddresses: new address[](0),
            description: "Stake ETH for mETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "METH"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Approve Mantle LSP Staking to spend mETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "mantleLspStaking");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "mantleLspStaking"),
            canSendValue: false,
            signature: "unstakeRequest(uint128,uint128)",
            argumentAddresses: new address[](0),
            description: "Request Unstake mETH for ETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "mantleLspStaking"),
            canSendValue: false,
            signature: "claimUnstakeRequest(uint256)",
            argumentAddresses: new address[](0),
            description: "Claim Unstake Request for ETH",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= Aave V3 =========================================

    function _addAaveV3Leafs(ManageLeaf[] memory leafs, ERC20[] memory supplyAssets, ERC20[] memory borrowAssets)
        internal
    {
        _addAaveV3ForkLeafs("Aave V3", getAddress(sourceChain, "v3Pool"), leafs, supplyAssets, borrowAssets);
    }

    function _addAaveV3PrimeLeafs(ManageLeaf[] memory leafs, ERC20[] memory supplyAssets, ERC20[] memory borrowAssets)
        internal
    {
        _addAaveV3ForkLeafs("Aave V3 Prime", getAddress(sourceChain, "v3PrimePool"), leafs, supplyAssets, borrowAssets);
    }

    function _addAaveV3LidoLeafs(ManageLeaf[] memory leafs, ERC20[] memory supplyAssets, ERC20[] memory borrowAssets)
        internal
    {
        _addAaveV3ForkLeafs("Aave V3 Lido", getAddress(sourceChain, "v3LidoPool"), leafs, supplyAssets, borrowAssets);
    }

    function _addAaveV3HorizonLeafs(ManageLeaf[] memory leafs, ERC20[] memory supplyAssets, ERC20[] memory borrowAssets)
        internal
    {
        _addAaveV3ForkLeafs(
            "Aave V3 Horizon", getAddress(sourceChain, "v3HorizonPool"), leafs, supplyAssets, borrowAssets
        );
    }

    function _addSparkLendLeafs(ManageLeaf[] memory leafs, ERC20[] memory supplyAssets, ERC20[] memory borrowAssets)
        internal
    {
        _addAaveV3ForkLeafs("SparkLend", getAddress(sourceChain, "sparkLendPool"), leafs, supplyAssets, borrowAssets);
    }

    function _addZerolendLeafs(ManageLeaf[] memory leafs, ERC20[] memory supplyAssets, ERC20[] memory borrowAssets)
        internal
    {
        _addAaveV3ForkLeafs("Zerolend", getAddress(sourceChain, "zeroLendPool"), leafs, supplyAssets, borrowAssets);
    }

    function _addHyperLendLeafs(ManageLeaf[] memory leafs, ERC20[] memory supplyAssets, ERC20[] memory borrowAssets)
        internal
    {
        _addAaveV3ForkLeafs("HyperLend", getAddress(sourceChain, "hyperLendPool"), leafs, supplyAssets, borrowAssets);
    }

    function _addAaveV3ForkLeafs(
        string memory protocolName,
        address protocolAddress,
        ManageLeaf[] memory leafs,
        ERC20[] memory supplyAssets,
        ERC20[] memory borrowAssets
    ) internal {
        // Approvals
        string memory baseApprovalString = string.concat("Approve ", protocolName, " Pool to spend ");
        for (uint256 i; i < supplyAssets.length; ++i) {
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(supplyAssets[i])][protocolAddress]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(supplyAssets[i]),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat(baseApprovalString, supplyAssets[i].symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = protocolAddress;
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(supplyAssets[i])][protocolAddress] = true;
            }
        }
        for (uint256 i; i < borrowAssets.length; ++i) {
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(borrowAssets[i])][protocolAddress]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(borrowAssets[i]),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat(baseApprovalString, borrowAssets[i].symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = protocolAddress;
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(borrowAssets[i])][protocolAddress] = true;
            }
        }
        // Lending
        for (uint256 i; i < supplyAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: protocolAddress,
                canSendValue: false,
                signature: "supply(address,uint256,address,uint16)",
                argumentAddresses: new address[](2),
                description: string.concat("Supply ", supplyAssets[i].symbol(), " to ", protocolName),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(supplyAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
        // Withdrawing
        for (uint256 i; i < supplyAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: protocolAddress,
                canSendValue: false,
                signature: "withdraw(address,uint256,address)",
                argumentAddresses: new address[](2),
                description: string.concat("Withdraw ", supplyAssets[i].symbol(), " from ", protocolName),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(supplyAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
        // Borrowing
        for (uint256 i; i < borrowAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: protocolAddress,
                canSendValue: false,
                signature: "borrow(address,uint256,uint256,uint16,address)",
                argumentAddresses: new address[](2),
                description: string.concat("Borrow ", borrowAssets[i].symbol(), " from ", protocolName),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(borrowAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
        // Repaying
        for (uint256 i; i < borrowAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: protocolAddress,
                canSendValue: false,
                signature: "repay(address,uint256,uint256,address)",
                argumentAddresses: new address[](2),
                description: string.concat("Repay ", borrowAssets[i].symbol(), " to ", protocolName),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(borrowAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
        // Misc
        for (uint256 i; i < supplyAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: protocolAddress,
                canSendValue: false,
                signature: "setUserUseReserveAsCollateral(address,bool)",
                argumentAddresses: new address[](1),
                description: string.concat("Toggle ", supplyAssets[i].symbol(), " as collateral in ", protocolName),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(supplyAssets[i]);
        }
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: protocolAddress,
            canSendValue: false,
            signature: "setUserEMode(uint8)",
            argumentAddresses: new address[](0),
            description: string.concat("Set user e-mode in ", protocolName),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "v3RewardsController"),
            canSendValue: false,
            signature: "claimRewards(address[],uint256,address,address)",
            argumentAddresses: new address[](1),
            description: string.concat("Claim rewards"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // only functions that can't hurt LTV of the position
    function _addAaveV3EOALeafs(
        string memory protocolName,
        address protocolAddress,
        ManageLeaf[] memory leafs,
        ERC20[] memory assets
    ) public {
        // Approvals
        string memory baseApprovalString = string.concat("Approve ", protocolName, " Pool to spend ");
        for (uint256 i; i < assets.length; ++i) {
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(assets[i])][protocolAddress]) {
                leafIndex++;
                leafs[leafIndex] = ManageLeaf({
                    target: address(assets[i]),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat(baseApprovalString, assets[i].symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = protocolAddress;
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(assets[i])][protocolAddress] = true;
            }
        }

        // repay
        for (uint256 i; i < assets.length; ++i) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf({
                target: protocolAddress,
                canSendValue: false,
                signature: "repay(address,uint256,uint256,address)",
                argumentAddresses: new address[](2),
                description: string.concat("Repay ", assets[i].symbol(), " to ", protocolName),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }

        // supply
        for (uint256 i; i < assets.length; ++i) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf({
                target: protocolAddress,
                canSendValue: false,
                signature: "supply(address,uint256,address,uint16)",
                argumentAddresses: new address[](2),
                description: string.concat("Supply ", assets[i].symbol(), " to ", protocolName),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }

        // rewards
        leafIndex++;
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "v3RewardsController"),
            canSendValue: false,
            signature: "claimRewards(address[],uint256,address,address)",
            argumentAddresses: new address[](1),
            description: string.concat("Claim rewards"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Uniswap V2 =========================================

    function _addUniswapV2Leafs(
        ManageLeaf[] memory leafs,
        address[] memory token0,
        address[] memory token1,
        bool includeNativeETHLeaves
    ) internal {
        require(token0.length == token1.length, "Token arrays must be of equal length");
        address nativeETH = getAddress(sourceChain, "ETH");

        // 3 * n token - repeats leaves
        for (uint256 i; i < token0.length; i++) {
            if (token0[i] == nativeETH) token0[i] = getAddress(sourceChain, "WETH");
            if (token1[i] == nativeETH) token1[i] = getAddress(sourceChain, "WETH");
            //Approvals
            //1) token0
            //2) token1
            //3) tokenPair

            if (token0[i] != nativeETH) {
                if (!ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][token0[i]][getAddress(sourceChain, "uniV2Router")]) {
                    (token0[i], token1[i]) = token0[i] < token1[i] ? (token0[i], token1[i]) : (token1[i], token0[i]);

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: token0[i],
                        canSendValue: false,
                        signature: "approve(address,uint256)",
                        argumentAddresses: new address[](1),
                        description: string.concat("Approve UniswapV2 Router to spend ", ERC20(token0[i]).symbol()),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV2Router");
                    ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][token0[i]][getAddress(sourceChain, "uniV2Router")] = true;
                }
            }

            if (token1[i] != nativeETH) {
                if (!ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][token1[i]][getAddress(sourceChain, "uniV2Router")]) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: token1[i],
                        canSendValue: false,
                        signature: "approve(address,uint256)",
                        argumentAddresses: new address[](1),
                        description: string.concat("Approve UniswapV2 Router to spend ", ERC20(token1[i]).symbol()),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV2Router");
                    ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][token1[i]][getAddress(sourceChain, "uniV2Router")] = true;
                }
            }

            address tokenPair = IUniswapV2Factory(getAddress(sourceChain, "uniV2Factory")).getPair(token0[i], token1[i]);
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][tokenPair][getAddress(sourceChain, "uniV2Router")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: tokenPair,
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat(
                        "Approve UniswapV2 Router to spend ",
                        ERC20(tokenPair).symbol(),
                        "-",
                        ERC20(token0[i]).symbol(),
                        "-",
                        ERC20(token1[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV2Router");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][tokenPair][getAddress(sourceChain, "uniV2Router")] = true;
            }
        }

        // TOKEN TO TOKEN SWAP FUNCTIONS //
        // 6 * n tokens leaves
        // token0 -> token1 * 2 funcs
        // token1 -> token0 * 2 funcs
        // add liquidity
        // remove liquidity

        for (uint256 i; i < token0.length; i++) {
            if (token0[i] == nativeETH || token1[i] == nativeETH) continue;
            // Swap token0 for token1
            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "uniV2Router"),
                canSendValue: false,
                signature: "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
                argumentAddresses: new address[](3),
                description: string.concat(
                    "Swap exact ", ERC20(token0[i]).symbol(), " for ", ERC20(token1[i]).symbol()
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            //Swap token1 for token0
            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "uniV2Router"),
                canSendValue: false,
                signature: "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
                argumentAddresses: new address[](3),
                description: string.concat(
                    "Swap exact ", ERC20(token1[i]).symbol(), " for ", ERC20(token0[i]).symbol()
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = token1[i];
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            //Swap token0 for exact token1
            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "uniV2Router"),
                canSendValue: false,
                signature: "swapTokensForExactTokens(uint256,uint256,address[],address,uint256)",
                argumentAddresses: new address[](3),
                description: string.concat(
                    "Swap ", ERC20(token0[i]).symbol(), " for exact ", ERC20(token1[i]).symbol()
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            //Swap token1 for exact token0
            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "uniV2Router"),
                canSendValue: false,
                signature: "swapTokensForExactTokens(uint256,uint256,address[],address,uint256)",
                argumentAddresses: new address[](3),
                description: string.concat(
                    "Swap ", ERC20(token1[i]).symbol(), " for exact ", ERC20(token0[i]).symbol()
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = token1[i];
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // LIQUIDITY FUNCTIONS
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "uniV2Router"),
                canSendValue: false,
                signature: "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)",
                argumentAddresses: new address[](3),
                description: string.concat("Add liquidty on UniswapV2"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "uniV2Router"),
                canSendValue: false,
                signature: "removeLiquidity(address,address,uint256,uint256,uint256,address,uint256)",
                argumentAddresses: new address[](3),
                description: string.concat("Remove liquidty on UniswapV2"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        }

        if (!includeNativeETHLeaves) return;

        for (uint256 i; i < token0.length; i++) {
            if (token0[i] == getAddress(sourceChain, "WETH") || token1[i] == getAddress(sourceChain, "WETH")) {
                address token = token0[i] != getAddress(sourceChain, "WETH") ? token0[i] : token1[i];

                //9
                unchecked {
                    leafIndex++;
                }

                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV2Router"),
                    canSendValue: true,
                    signature: "swapExactETHForTokens(uint256,address[],address,uint256)",
                    argumentAddresses: new address[](3),
                    description: string.concat("Swap exact ETH for ", ERC20(token).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "WETH");
                leafs[leafIndex].argumentAddresses[1] = token;
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }

                //10
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV2Router"),
                    canSendValue: false,
                    signature: "swapExactTokensForETH(uint256,uint256,address[],address,uint256)",
                    argumentAddresses: new address[](3),
                    description: string.concat("Swap exact ETH for ", ERC20(token).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token;
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "WETH");
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }

                //11
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV2Router"),
                    canSendValue: false,
                    signature: "swapTokensForExactETH(uint256,uint256,address[],address,uint256)",
                    argumentAddresses: new address[](3),
                    description: string.concat("Swap ", ERC20(token).symbol(), " for exact ETH"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token;
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "WETH");
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }

                //12
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV2Router"),
                    canSendValue: true,
                    signature: "swapETHForExactTokens(uint256,address[],address,uint256)",
                    argumentAddresses: new address[](3),
                    description: string.concat("Swap ETH for exact ", ERC20(token).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "WETH");
                leafs[leafIndex].argumentAddresses[1] = token;
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }

                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV2Router"),
                    canSendValue: true,
                    signature: "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
                    argumentAddresses: new address[](2),
                    description: string.concat("Add liquidity for ETH and ", ERC20(token).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token;
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }

                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV2Router"),
                    canSendValue: false,
                    signature: "removeLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
                    argumentAddresses: new address[](2),
                    description: string.concat("Remove liquidity from ETH and ", ERC20(token).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token;
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            }
        }
    }

    // ========================================= Uniswap V3 =========================================
    function _addUniswapV3Leafs(
        ManageLeaf[] memory leafs,
        address[] memory token0,
        address[] memory token1,
        bool swap_only
    ) internal {
        _addUniswapV3Leafs(leafs, token0, token1, swap_only, false);
    }

    function _addUniswapV3Leafs(
        ManageLeaf[] memory leafs,
        address[] memory token0,
        address[] memory token1,
        bool swap_only,
        bool swapRouter02
    ) internal {
        require(token0.length == token1.length, "Token arrays must be of equal length");
        for (uint256 i; i < token0.length; ++i) {
            (token0[i], token1[i]) = token0[i] < token1[i] ? (token0[i], token1[i]) : (token1[i], token0[i]);

            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][getAddress(sourceChain, "uniV3Router")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token0[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve UniswapV3 Router to spend ", ERC20(token0[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV3Router");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][getAddress(sourceChain, "uniV3Router")] = true;
            }
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1[i]][getAddress(sourceChain, "uniV3Router")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token1[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve UniswapV3 Router to spend ", ERC20(token1[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV3Router");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1[i]][getAddress(sourceChain, "uniV3Router")] = true;
            }

            //end swap only

            if (!swap_only) {
                // Approvals for position manager
                if (!ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][token0[i]][getAddress(sourceChain, "uniswapV3NonFungiblePositionManager")]) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: token0[i],
                        canSendValue: false,
                        signature: "approve(address,uint256)",
                        argumentAddresses: new address[](1),
                        description: string.concat(
                            "Approve UniswapV3 NonFungible Position Manager to spend ", ERC20(token0[i]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] =
                        getAddress(sourceChain, "uniswapV3NonFungiblePositionManager");
                    ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][token0[i]][getAddress(sourceChain, "uniswapV3NonFungiblePositionManager")] = true;
                }
                if (!ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][token1[i]][getAddress(sourceChain, "uniswapV3NonFungiblePositionManager")]) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: token1[i],
                        canSendValue: false,
                        signature: "approve(address,uint256)",
                        argumentAddresses: new address[](1),
                        description: string.concat(
                            "Approve UniswapV3 NonFungible Position Manager to spend ", ERC20(token1[i]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] =
                        getAddress(sourceChain, "uniswapV3NonFungiblePositionManager");
                    ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][token1[i]][getAddress(sourceChain, "uniswapV3NonFungiblePositionManager")] = true;
                }

                // Minting
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
                    canSendValue: false,
                    signature: "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
                    argumentAddresses: new address[](3),
                    description: string.concat(
                        "Mint UniswapV3 ", ERC20(token0[i]).symbol(), " ", ERC20(token1[i]).symbol(), " position"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                // Increase liquidity
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
                    canSendValue: false,
                    signature: "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
                    argumentAddresses: new address[](4),
                    description: string.concat(
                        "Add liquidity to UniswapV3 ",
                        ERC20(token0[i]).symbol(),
                        " ",
                        ERC20(token1[i]).symbol(),
                        " position"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(0);
                leafs[leafIndex].argumentAddresses[1] = token0[i];
                leafs[leafIndex].argumentAddresses[2] = token1[i];
                leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
            }

            //BEGIN SWAP ONLY LEAVES
            // Swapping to move tick in pool.
            if (!swapRouter02) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV3Router"),
                    canSendValue: false,
                    signature: "exactInput((bytes,address,uint256,uint256,uint256))",
                    argumentAddresses: new address[](3),
                    description: string.concat(
                        "Swap ",
                        ERC20(token0[i]).symbol(),
                        " for ",
                        ERC20(token1[i]).symbol(),
                        " using UniswapV3 router"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV3Router"),
                    canSendValue: false,
                    signature: "exactInput((bytes,address,uint256,uint256,uint256))",
                    argumentAddresses: new address[](3),
                    description: string.concat(
                        "Swap ",
                        ERC20(token1[i]).symbol(),
                        " for ",
                        ERC20(token0[i]).symbol(),
                        " using UniswapV3 router"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token1[i];
                leafs[leafIndex].argumentAddresses[1] = token0[i];
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            }

            if (swapRouter02) {
                //SWAPROUTER02
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV3Router"),
                    canSendValue: false,
                    signature: "exactInput((bytes,address,uint256,uint256))",
                    argumentAddresses: new address[](3),
                    description: string.concat(
                        "Swap ",
                        ERC20(token0[i]).symbol(),
                        " for ",
                        ERC20(token1[i]).symbol(),
                        " using UniswapV3 router"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV3Router"),
                    canSendValue: false,
                    signature: "exactInput((bytes,address,uint256,uint256))",
                    argumentAddresses: new address[](3),
                    description: string.concat(
                        "Swap ",
                        ERC20(token1[i]).symbol(),
                        " for ",
                        ERC20(token0[i]).symbol(),
                        " using UniswapV3 router"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token1[i];
                leafs[leafIndex].argumentAddresses[1] = token0[i];
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            }
        }

        //END FOR LOOP
        //END SWAP ONLY LEAVES

        if (!swap_only) {
            // Decrease liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
                canSendValue: false,
                signature: "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
                argumentAddresses: new address[](1),
                description: "Remove liquidity from UniswapV3 position",
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
                canSendValue: false,
                signature: "collect((uint256,address,uint128,uint128))",
                argumentAddresses: new address[](2),
                description: "Collect fees from UniswapV3 position",
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            // burn
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
                canSendValue: false,
                signature: "burn(uint256)",
                argumentAddresses: new address[](0),
                description: "Burn UniswapV3 position",
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
        }
    }

    function _addUniswapV3OneWaySwapLeafs(
        ManageLeaf[] memory leafs,
        address[] memory token0,
        address[] memory token1,
        bool swapRouter02
    ) internal {
        require(token0.length == token1.length, "Token arrays must be of equal length");

        for (uint256 i; i < token0.length; ++i) {
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][getAddress(sourceChain, "uniV3Router")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token0[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve UniswapV3 Router to spend ", ERC20(token0[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV3Router");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][getAddress(sourceChain, "uniV3Router")] = true;
            }

            if (swapRouter02) {
                leafIndex++;
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV3Router"),
                    canSendValue: false,
                    signature: "exactInput((bytes,address,uint256,uint256))",
                    argumentAddresses: new address[](3),
                    description: string.concat(
                        "Swap ",
                        ERC20(token0[i]).symbol(),
                        " for ",
                        ERC20(token1[i]).symbol(),
                        " using UniswapV3 router"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            } else {
                leafIndex++;
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV3Router"),
                    canSendValue: false,
                    signature: "exactInput((bytes,address,uint256,uint256,uint256))",
                    argumentAddresses: new address[](3),
                    description: string.concat(
                        "Swap ",
                        ERC20(token0[i]).symbol(),
                        " for ",
                        ERC20(token1[i]).symbol(),
                        " using UniswapV3 router"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            }
        }
    }

    // ========================================= Uniswap V4 =========================================

    /// @dev NOTE that for decreasing and burning positions, the decoder has the option to include a SWEEP, but isn't needed for regular functionality and thus
    /// is not included in the leaves at this time
    /// -- if in the future it is required for a specific hook, these leaves could be added, but as no ETH is sent during these calls, SWEEP shouldn't be needed
    function _addUniswapV4Leafs(
        ManageLeaf[] memory leafs,
        address[] memory token0,
        address[] memory token1,
        address[] memory hooks
    ) internal {
        require(token0.length == token1.length, "Token arrays must be of equal length");
        require(token1.length == hooks.length, "Token and hook arrays must be of equal length");
        for (uint256 i; i < token0.length; ++i) {
            console.log("TOKEN 0: ", token0[i]);
            console.log("TOKEN 1: ", token1[i]);

            //after sorting, ETH can only ever be token0, and is always token0 in univ4 pools (iirc)
            if (token0[i] == getAddress(sourceChain, "ETH")) {
                token0[i] = address(0); //in univ4, ETH is address(0)
            }

            if (token1[i] == getAddress(sourceChain, "ETH")) {
                token1[i] = address(0); //in univ4, ETH is address(0)
            }

            (token0[i], token1[i]) = token0[i] < token1[i] ? (token0[i], token1[i]) : (token1[i], token0[i]);

            if (token0[i] != address(0)) {
                if (!ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][token0[i]][getAddress(sourceChain, "uniV4UniversalRouter")]) {
                    //approve token0 after sorting
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: token0[i],
                        canSendValue: false,
                        signature: "approve(address,uint256)",
                        argumentAddresses: new address[](1),
                        description: string.concat(
                            "Approve UniswapV4 Pool Manager to spend ", ERC20(token0[i]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV4UniversalRouter");
                    ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][token0[i]][getAddress(sourceChain, "uniV4PoolManager")] = true;

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: token0[i],
                        canSendValue: false,
                        signature: "approve(address,uint256)",
                        argumentAddresses: new address[](1),
                        description: string.concat(
                            "Approve UniswapV4 Position Manager to spend ", ERC20(token0[i]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV4PositionManager");

                    ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][token0[i]][getAddress(sourceChain, "uniV4PoolManager")] = true;

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: token0[i],
                        canSendValue: false,
                        signature: "approve(address,uint256)",
                        argumentAddresses: new address[](1),
                        description: string.concat("Approve Permit2 to spend ", ERC20(token0[i]).symbol()),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "permit2");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "permit2"),
                        canSendValue: false,
                        signature: "approve(address,address,uint160,uint48)",
                        argumentAddresses: new address[](2),
                        description: string.concat(
                            "Use Permit2 to approve ", ERC20(token0[i]).symbol(), " for Universal Router"
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = token0[i];
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "uniV4UniversalRouter");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "permit2"),
                        canSendValue: false,
                        signature: "approve(address,address,uint160,uint48)",
                        argumentAddresses: new address[](2),
                        description: string.concat("Use Permit2 to approve ", ERC20(token0[i]).symbol(), " for POSM"),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = token0[i];
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "uniV4PositionManager");
                }
            }

            if (token1[i] != address(0)) {
                if (!ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][token1[i]][getAddress(sourceChain, "uniV4UniversalRouter")]) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: token1[i],
                        canSendValue: false,
                        signature: "approve(address,uint256)",
                        argumentAddresses: new address[](1),
                        description: string.concat(
                            "Approve UniswapV4 Universal Router to spend ", ERC20(token1[i]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV4UniversalRouter");
                    ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][token1[i]][getAddress(sourceChain, "uniV4UniversalRouter")] = true;

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: token1[i],
                        canSendValue: false,
                        signature: "approve(address,uint256)",
                        argumentAddresses: new address[](1),
                        description: string.concat(
                            "Approve UniswapV4 Position Manager to spend ", ERC20(token1[i]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV4PositionManager");
                    ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][token1[i]][getAddress(sourceChain, "uniV4PositionManager")] = true;

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: token1[i],
                        canSendValue: false,
                        signature: "approve(address,uint256)",
                        argumentAddresses: new address[](1),
                        description: string.concat("Approve Permit2 to spend ", ERC20(token1[i]).symbol()),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "permit2");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "permit2"),
                        canSendValue: false,
                        signature: "approve(address,address,uint160,uint48)",
                        argumentAddresses: new address[](2),
                        description: string.concat("Approve Permit2 to spend ", ERC20(token1[i]).symbol()),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = token1[i];
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "uniV4UniversalRouter");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "permit2"),
                        canSendValue: false,
                        signature: "approve(address,address,uint160,uint48)",
                        argumentAddresses: new address[](2),
                        description: string.concat("Approve Permit2 to spend ", ERC20(token1[i]).symbol(), " for POSM"),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = token1[i];
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "uniV4PositionManager");
                } //end if
            }

            if (token0[i] != address(0)) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV4UniversalRouter"),
                    canSendValue: false,
                    signature: "execute(bytes,bytes[],uint256)",
                    argumentAddresses: new address[](5),
                    description: string.concat("Swap ", ERC20(token0[i]).symbol(), " for ", ERC20(token1[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(token0[i]);
                leafs[leafIndex].argumentAddresses[1] = address(token1[i]);
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = address(token0[i]);
                leafs[leafIndex].argumentAddresses[4] = address(token1[i]);

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV4UniversalRouter"),
                    canSendValue: false,
                    signature: "execute(bytes,bytes[],uint256)",
                    argumentAddresses: new address[](5),
                    description: string.concat("Swap ", ERC20(token1[i]).symbol(), " for ", ERC20(token0[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(token0[i]);
                leafs[leafIndex].argumentAddresses[1] = address(token1[i]);
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = address(token1[i]);
                leafs[leafIndex].argumentAddresses[4] = address(token0[i]);
            } else {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV4UniversalRouter"),
                    canSendValue: true,
                    signature: "execute(bytes,bytes[],uint256)",
                    argumentAddresses: new address[](7),
                    description: string.concat("Swap ETH for ", ERC20(token1[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });

                leafs[leafIndex].argumentAddresses[0] = address(token0[i]);
                leafs[leafIndex].argumentAddresses[1] = address(token1[i]);
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = address(token0[i]);
                leafs[leafIndex].argumentAddresses[4] = address(token1[i]);
                leafs[leafIndex].argumentAddresses[5] = address(token0[i]); //should be ETH
                leafs[leafIndex].argumentAddresses[6] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV4UniversalRouter"),
                    canSendValue: false,
                    signature: "execute(bytes,bytes[],uint256)",
                    argumentAddresses: new address[](5),
                    description: string.concat("Swap ", ERC20(token1[i]).symbol(), " for ETH"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });

                leafs[leafIndex].argumentAddresses[0] = address(token0[i]);
                leafs[leafIndex].argumentAddresses[1] = address(token1[i]);
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = address(token1[i]);
                leafs[leafIndex].argumentAddresses[4] = address(token0[i]);
            }

            //MINT POSITION LEAVES

            if (token0[i] != address(0)) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV4PositionManager"),
                    canSendValue: false,
                    signature: "modifyLiquidities(bytes,uint256)",
                    argumentAddresses: new address[](6),
                    description: string.concat(
                        "Mint UniswapV4 position for ", ERC20(token0[i]).symbol(), " and ", ERC20(token1[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
                leafs[leafIndex].argumentAddresses[4] = token0[i];
                leafs[leafIndex].argumentAddresses[5] = token1[i];
            } else {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV4PositionManager"),
                    canSendValue: true,
                    signature: "modifyLiquidities(bytes,uint256)",
                    argumentAddresses: new address[](8),
                    description: string.concat("Mint UniswapV4 position for ETH and ", ERC20(token1[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
                leafs[leafIndex].argumentAddresses[4] = token0[i];
                leafs[leafIndex].argumentAddresses[5] = token1[i];
                leafs[leafIndex].argumentAddresses[6] = token0[i];
                leafs[leafIndex].argumentAddresses[7] = getAddress(sourceChain, "boringVault");
            }

            //INCREASE LIQUIDITY
            //all variations of this function give back 2 addressess
            if (token0[i] != address(0)) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV4PositionManager"),
                    canSendValue: false,
                    signature: "modifyLiquidities(bytes,uint256)",
                    argumentAddresses: new address[](5),
                    description: string.concat(
                        "Increase liquidity for UniswapV4 position for ",
                        ERC20(token0[i]).symbol(),
                        " and ",
                        ERC20(token1[i]).symbol(),
                        " using SETTLE_PAIR, CLOSE_CURRENCY (both pairs), or CLEAR_AND_TAKE (both pairs)"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = token0[i];
                leafs[leafIndex].argumentAddresses[4] = token1[i];
            } else {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV4PositionManager"),
                    canSendValue: true,
                    signature: "modifyLiquidities(bytes,uint256)",
                    argumentAddresses: new address[](7),
                    description: string.concat(
                        "Increase liquidity for UniswapV4 position for ETH and ", ERC20(token1[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = token0[i];
                leafs[leafIndex].argumentAddresses[4] = token1[i];
                leafs[leafIndex].argumentAddresses[5] = token0[i];
                leafs[leafIndex].argumentAddresses[6] = getAddress(sourceChain, "boringVault");
            }

            //DECREASE LIQUIDITY
            if (token0[i] != address(0)) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV4PositionManager"),
                    canSendValue: false,
                    signature: "modifyLiquidities(bytes,uint256)",
                    argumentAddresses: new address[](6),
                    description: string.concat(
                        "Decrease liquidity for UniswapV4 position for ",
                        ERC20(token0[i]).symbol(),
                        " and ",
                        ERC20(token1[i]).symbol(),
                        " using SETTLE"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = token0[i];
                leafs[leafIndex].argumentAddresses[4] = token1[i];
                leafs[leafIndex].argumentAddresses[5] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV4PositionManager"),
                    canSendValue: false,
                    signature: "modifyLiquidities(bytes,uint256)",
                    argumentAddresses: new address[](5),
                    description: string.concat(
                        "Decrease liquidity for UniswapV4 position for ",
                        ERC20(token0[i]).symbol(),
                        " and ",
                        ERC20(token1[i]).symbol(),
                        " using CLEAR_OR_TAKE or CLOSE_CURRENCY"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = token0[i];
                leafs[leafIndex].argumentAddresses[4] = token1[i];
            } else {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV4PositionManager"),
                    canSendValue: false,
                    signature: "modifyLiquidities(bytes,uint256)",
                    argumentAddresses: new address[](6),
                    description: string.concat(
                        "Decrease liquidity for UniswapV4 position for ETH and ",
                        ERC20(token1[i]).symbol(),
                        " using SETTLE"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = token0[i];
                leafs[leafIndex].argumentAddresses[4] = token1[i];
                leafs[leafIndex].argumentAddresses[5] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV4PositionManager"),
                    canSendValue: false,
                    signature: "modifyLiquidities(bytes,uint256)",
                    argumentAddresses: new address[](5),
                    description: string.concat(
                        "Decrease liquidity for UniswapV4 position for ETH and ",
                        ERC20(token1[i]).symbol(),
                        " using CLEAR_OR_TAKE or CLOSE_CURRENCY"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = token0[i];
                leafs[leafIndex].argumentAddresses[4] = token1[i];
            }

            //BURN LIQUIDITY
            if (token0[i] != address(0)) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV4PositionManager"),
                    canSendValue: false,
                    signature: "modifyLiquidities(bytes,uint256)",
                    argumentAddresses: new address[](6),
                    description: string.concat(
                        "Burn liquidity position for UniswapV4 position for ",
                        ERC20(token0[i]).symbol(),
                        " and ",
                        ERC20(token1[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = token0[i];
                leafs[leafIndex].argumentAddresses[4] = token1[i];
                leafs[leafIndex].argumentAddresses[5] = getAddress(sourceChain, "boringVault");
            } else {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "uniV4PositionManager"),
                    canSendValue: false,
                    signature: "modifyLiquidities(bytes,uint256)",
                    argumentAddresses: new address[](6),
                    description: string.concat(
                        "Burn liquidity position for UniswapV4 position for ETH and ", ERC20(token1[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = token0[i];
                leafs[leafIndex].argumentAddresses[4] = token1[i];
                leafs[leafIndex].argumentAddresses[5] = getAddress(sourceChain, "boringVault");
            }
        }
    }

    // ========================================= Camelot V3 =========================================

    function _addCamelotV3Leafs(ManageLeaf[] memory leafs, address[] memory token0, address[] memory token1) internal {
        require(token0.length == token1.length, "Token arrays must be of equal length");
        for (uint256 i; i < token0.length; ++i) {
            (token0[i], token1[i]) = token0[i] < token1[i] ? (token0[i], token1[i]) : (token1[i], token0[i]);
            // Approvals
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][getAddress(sourceChain, "camelotNonFungiblePositionManager")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token0[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat(
                        "Approve CamelotV3 NonFungible Position Manager to spend ", ERC20(token0[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][getAddress(sourceChain, "camelotNonFungiblePositionManager")] = true;
            }
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1[i]][getAddress(sourceChain, "camelotNonFungiblePositionManager")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token1[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat(
                        "Approve CamelotV3 NonFungible Position Manager to spend ", ERC20(token1[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1[i]][getAddress(sourceChain, "camelotNonFungiblePositionManager")] = true;
            }

            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][getAddress(sourceChain, "camelotRouterV3")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token0[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve CamelotV3 Router to spend ", ERC20(token0[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "camelotRouterV3");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][getAddress(sourceChain, "camelotRouterV3")] = true;
            }
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1[i]][getAddress(sourceChain, "camelotRouterV3")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token1[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve CamelotV3 Router to spend ", ERC20(token1[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "camelotRouterV3");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1[i]][getAddress(sourceChain, "camelotRouterV3")] = true;
            }

            // Minting
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "camelotNonFungiblePositionManager"),
                canSendValue: false,
                signature: "mint((address,address,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
                argumentAddresses: new address[](3),
                description: string.concat(
                    "Mint CamelotV3 ", ERC20(token0[i]).symbol(), " ", ERC20(token1[i]).symbol(), " position"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            // Increase liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "camelotNonFungiblePositionManager"),
                canSendValue: false,
                signature: "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
                argumentAddresses: new address[](4),
                description: string.concat(
                    "Add liquidity to CamelotV3 ",
                    ERC20(token0[i]).symbol(),
                    " ",
                    ERC20(token1[i]).symbol(),
                    " position"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(0);
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = token1[i];
            leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");

            // Swapping to move tick in pool.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "camelotRouterV3"),
                canSendValue: false,
                signature: "exactInput((bytes,address,uint256,uint256,uint256))",
                argumentAddresses: new address[](3),
                description: string.concat(
                    "Swap ", ERC20(token0[i]).symbol(), " for ", ERC20(token1[i]).symbol(), " using CamelotV3 router"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "camelotRouterV3"),
                canSendValue: false,
                signature: "exactInput((bytes,address,uint256,uint256,uint256))",
                argumentAddresses: new address[](3),
                description: string.concat(
                    "Swap ", ERC20(token1[i]).symbol(), " for ", ERC20(token0[i]).symbol(), " using CamelotV3 router"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = token1[i];
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        }
        // Decrease liquidity
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "camelotNonFungiblePositionManager"),
            canSendValue: false,
            signature: "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            argumentAddresses: new address[](1),
            description: "Remove liquidity from CamelotV3 position",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "camelotNonFungiblePositionManager"),
            canSendValue: false,
            signature: "collect((uint256,address,uint128,uint128))",
            argumentAddresses: new address[](2),
            description: "Collect fees from CamelotV3 position",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        // burn
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "camelotNonFungiblePositionManager"),
            canSendValue: false,
            signature: "burn(uint256)",
            argumentAddresses: new address[](0),
            description: "Burn CamelotV3 position",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= Algebra V4 / Camelot V4 =========================================

    function _addAlgebraV4Leafs(
        ManageLeaf[] memory leafs,
        address[] memory token0,
        address[] memory token1,
        address deployer
    ) internal {
        require(token0.length == token1.length, "Token arrays must be of equal length");
        for (uint256 i; i < token0.length; ++i) {
            (token0[i], token1[i]) = token0[i] < token1[i] ? (token0[i], token1[i]) : (token1[i], token0[i]);
            // Approvals
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][getAddress(sourceChain, "algebraNonFungiblePositionManager")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token0[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat(
                        "Approve AlgebraV4 NonFungible Position Manager to spend ", ERC20(token0[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "algebraNonFungiblePositionManager");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][getAddress(sourceChain, "algebraNonFungiblePositionManager")] = true;
            }
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1[i]][getAddress(sourceChain, "algebraNonFungiblePositionManager")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token1[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat(
                        "Approve AlgebraV4 NonFungible Position Manager to spend ", ERC20(token1[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "algebraNonFungiblePositionManager");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1[i]][getAddress(sourceChain, "algebraNonFungiblePositionManager")] = true;
            }

            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][getAddress(sourceChain, "algebraV4Router")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token0[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve AlgebraV4 Router to spend ", ERC20(token0[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "algebraV4Router");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][getAddress(sourceChain, "algebraV4Router")] = true;
            }
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1[i]][getAddress(sourceChain, "algebraV4Router")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token1[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve AlgebraV4 Router to spend ", ERC20(token1[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "algebraV4Router");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1[i]][getAddress(sourceChain, "algebraV4Router")] = true;
            }

            // Minting
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "algebraNonFungiblePositionManager"),
                canSendValue: false,
                signature: "mint((address,address,address,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
                argumentAddresses: new address[](4),
                description: string.concat(
                    "Mint AlgebraV4 ", ERC20(token0[i]).symbol(), " ", ERC20(token1[i]).symbol(), " position"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = deployer;
            leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
            // Increase liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "algebraNonFungiblePositionManager"),
                canSendValue: false,
                signature: "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
                argumentAddresses: new address[](5),
                description: string.concat(
                    "Add liquidity to AlgebraV4 ",
                    ERC20(token0[i]).symbol(),
                    " ",
                    ERC20(token1[i]).symbol(),
                    " position"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(0);
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = token1[i];
            leafs[leafIndex].argumentAddresses[3] = deployer;
            leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");

            // Swapping to move tick in pool.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "algebraV4Router"),
                canSendValue: false,
                signature: "exactInput((bytes,address,uint256,uint256,uint256))",
                argumentAddresses: new address[](4),
                description: string.concat(
                    "Swap ", ERC20(token0[i]).symbol(), " for ", ERC20(token1[i]).symbol(), " using AlgebraV4 router"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = deployer;
            leafs[leafIndex].argumentAddresses[2] = token1[i];
            leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "algebraV4Router"),
                canSendValue: false,
                signature: "exactInput((bytes,address,uint256,uint256,uint256))",
                argumentAddresses: new address[](3),
                description: string.concat(
                    "Swap ", ERC20(token1[i]).symbol(), " for ", ERC20(token0[i]).symbol(), " using AlgebraV4 router"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = token1[i];
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        }
        // Decrease liquidity
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "algebraNonFungiblePositionManager"),
            canSendValue: false,
            signature: "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            argumentAddresses: new address[](1),
            description: "Remove liquidity from AlgebraV4 position",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "algebraNonFungiblePositionManager"),
            canSendValue: false,
            signature: "collect((uint256,address,uint128,uint128))",
            argumentAddresses: new address[](2),
            description: "Collect fees from AlgebraV4 position",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        // burn
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "algebraNonFungiblePositionManager"),
            canSendValue: false,
            signature: "burn(uint256)",
            argumentAddresses: new address[](0),
            description: "Burn AlgebraV4 position",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= Balancer V2 Flashloans =========================================

    function _addBalancerFlashloanLeafs(ManageLeaf[] memory leafs, address tokenToFlashloan) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "managerAddress"),
            canSendValue: false,
            signature: "flashLoan(address,address[],uint256[],bytes)",
            argumentAddresses: new address[](2),
            description: string.concat("Flashloan ", ERC20(tokenToFlashloan).symbol(), " from Balancer Vault"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "managerAddress");
        leafs[leafIndex].argumentAddresses[1] = tokenToFlashloan;
    }

    // ========================================= Pendle Router =========================================
    function _addPendleMarketLeafs(ManageLeaf[] memory leafs, address marketAddress, bool allowLimitOrderFills)
        internal
    {
        PendleMarket market = PendleMarket(marketAddress);
        (address sy, address pt, address yt) = market.readTokens();
        PendleSy SY = PendleSy(sy);
        address[] memory possibleTokensIn = SY.getTokensIn();
        address[] memory possibleTokensOut = SY.getTokensOut();
        string memory underlyingAssetDescriptor;
        {
            // Some pendle markets report underlying assets that are not actually on the source chain, so handle that edge case.
            (, ERC20 underlyingAsset,) = SY.assetInfo();
            if (keccak256(bytes(sourceChain)) == keccak256(bytes(mainnet))) {
                // Underlying asset is a contract on sourceChain.
                if (address(underlyingAsset) == address(0)) {
                    underlyingAssetDescriptor = "liquidBeraETH";
                } else {
                    underlyingAssetDescriptor = underlyingAsset.symbol();
                }
            } else {
                // Underlying asset is not a contract on targetChain.
                underlyingAssetDescriptor = ERC20(sy).symbol();
            }
        }
        // Approve router to spend all tokens in, skipping zero addresses.
        for (uint256 i; i < possibleTokensIn.length; ++i) {
            if (
                possibleTokensIn[i] != address(0)
                    && !ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][possibleTokensIn[i]][getAddress(sourceChain, "pendleRouter")]
            ) {
                ERC20 tokenIn = ERC20(possibleTokensIn[i]);
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: possibleTokensIn[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Pendle router to spend ", tokenIn.symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleRouter");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][possibleTokensIn[i]][getAddress(sourceChain, "pendleRouter")] = true;
            }
        }
        // Approve router to spend LP, SY, PT, YT
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: marketAddress,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Pendle router to spend LP-", underlyingAssetDescriptor),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleRouter");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: sy,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Pendle router to spend ", ERC20(sy).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleRouter");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: pt,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Pendle router to spend ", ERC20(pt).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleRouter");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: yt,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Pendle router to spend ", ERC20(yt).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleRouter");
        // Mint SY using input token.
        for (uint256 i; i < possibleTokensIn.length; ++i) {
            if (possibleTokensIn[i] != address(0)) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "pendleRouter"),
                    canSendValue: false,
                    signature: "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
                    argumentAddresses: new address[](6),
                    description: string.concat(
                        "Mint ", ERC20(sy).symbol(), " using ", ERC20(possibleTokensIn[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
                leafs[leafIndex].argumentAddresses[1] = sy;
                leafs[leafIndex].argumentAddresses[2] = possibleTokensIn[i];
                leafs[leafIndex].argumentAddresses[3] = possibleTokensIn[i];
                leafs[leafIndex].argumentAddresses[4] = address(0);
                leafs[leafIndex].argumentAddresses[5] = address(0);
            }
        }
        // Mint PT and YT using SY.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pendleRouter"),
            canSendValue: false,
            signature: "mintPyFromSy(address,address,uint256,uint256)",
            argumentAddresses: new address[](2),
            description: string.concat(
                "Mint ", ERC20(pt).symbol(), " and ", ERC20(yt).symbol(), " from ", ERC20(sy).symbol()
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = yt;
        // Swap between PT and YT.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pendleRouter"),
            canSendValue: false,
            signature: "swapExactYtForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            argumentAddresses: new address[](2),
            description: string.concat("Swap ", ERC20(yt).symbol(), " for ", ERC20(pt).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pendleRouter"),
            canSendValue: false,
            signature: "swapExactPtForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            argumentAddresses: new address[](2),
            description: string.concat("Swap ", ERC20(pt).symbol(), " for ", ERC20(yt).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        // Manage Liquidity.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pendleRouter"),
            canSendValue: false,
            signature: "addLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            argumentAddresses: new address[](2),
            description: string.concat(
                "Mint LP-", underlyingAssetDescriptor, " using ", ERC20(sy).symbol(), " and ", ERC20(pt).symbol()
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pendleRouter"),
            canSendValue: false,
            signature: "removeLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            argumentAddresses: new address[](2),
            description: string.concat(
                "Burn LP-", underlyingAssetDescriptor, " for ", ERC20(sy).symbol(), " and ", ERC20(pt).symbol()
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        // Burn PT and YT for SY.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pendleRouter"),
            canSendValue: false,
            signature: "redeemPyToSy(address,address,uint256,uint256)",
            argumentAddresses: new address[](2),
            description: string.concat(
                "Burn ", ERC20(pt).symbol(), " and ", ERC20(yt).symbol(), " for ", ERC20(sy).symbol()
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = yt;
        // Redeem SY for output token.
        for (uint256 i; i < possibleTokensOut.length; ++i) {
            if (possibleTokensOut[i] != address(0)) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "pendleRouter"),
                    canSendValue: false,
                    signature: "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
                    argumentAddresses: new address[](6),
                    description: string.concat(
                        "Burn ", ERC20(sy).symbol(), " for ", ERC20(possibleTokensOut[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
                leafs[leafIndex].argumentAddresses[1] = sy;
                leafs[leafIndex].argumentAddresses[2] = possibleTokensOut[i];
                leafs[leafIndex].argumentAddresses[3] = possibleTokensOut[i];
                leafs[leafIndex].argumentAddresses[4] = address(0);
                leafs[leafIndex].argumentAddresses[5] = address(0);
            }
        }
        // Harvest rewards.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pendleRouter"),
            canSendValue: false,
            signature: "redeemDueInterestAndRewards(address,address[],address[],address[])",
            argumentAddresses: new address[](4),
            description: string.concat("Redeem due interest and rewards for ", underlyingAssetDescriptor, " Pendle"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = sy;
        leafs[leafIndex].argumentAddresses[2] = yt;
        leafs[leafIndex].argumentAddresses[3] = marketAddress;

        // Swap between SY and PT
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pendleRouter"),
            canSendValue: false,
            signature: "swapExactSyForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256),(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
            argumentAddresses: new address[](2),
            description: string.concat("Swap ", ERC20(sy).symbol(), " for ", ERC20(pt).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pendleRouter"),
            canSendValue: false,
            signature: "swapExactPtForSy(address,address,uint256,uint256,(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
            argumentAddresses: new address[](2),
            description: string.concat("Swap ", ERC20(pt).symbol(), " for ", ERC20(sy).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;

        // Swap between SY and YT
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pendleRouter"),
            canSendValue: false,
            signature: "swapExactSyForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256),(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
            argumentAddresses: new address[](2),
            description: string.concat("Swap ", ERC20(sy).symbol(), " for ", ERC20(yt).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pendleRouter"),
            canSendValue: false,
            signature: "swapExactYtForSy(address,address,uint256,uint256,(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
            argumentAddresses: new address[](2),
            description: string.concat("Swap ", ERC20(yt).symbol(), " for ", ERC20(sy).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;

        if (allowLimitOrderFills) {
            // Re-add the swap between SY and PT and YT leaves, but add in the limit order router, and YT in the argumentAddresses.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "pendleRouter"),
                canSendValue: false,
                signature: "swapExactSyForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256),(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
                argumentAddresses: new address[](4),
                description: string.concat(
                    "Swap ", ERC20(sy).symbol(), " for ", ERC20(pt).symbol(), " with limit orders"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = marketAddress;
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "pendleLimitOrderRouter");
            leafs[leafIndex].argumentAddresses[3] = yt;
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "pendleRouter"),
                canSendValue: false,
                signature: "swapExactPtForSy(address,address,uint256,uint256,(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
                argumentAddresses: new address[](4),
                description: string.concat(
                    "Swap ", ERC20(pt).symbol(), " for ", ERC20(sy).symbol(), " with limit orders"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = marketAddress;
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "pendleLimitOrderRouter");
            leafs[leafIndex].argumentAddresses[3] = yt;

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "pendleRouter"),
                canSendValue: false,
                signature: "swapExactSyForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256),(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
                argumentAddresses: new address[](4),
                description: string.concat(
                    "Swap ", ERC20(sy).symbol(), " for ", ERC20(yt).symbol(), " with limit orders"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = marketAddress;
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "pendleLimitOrderRouter");
            leafs[leafIndex].argumentAddresses[3] = yt;
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "pendleRouter"),
                canSendValue: false,
                signature: "swapExactYtForSy(address,address,uint256,uint256,(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
                argumentAddresses: new address[](4),
                description: string.concat(
                    "Swap ", ERC20(yt).symbol(), " for ", ERC20(sy).symbol(), " with limit orders"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = marketAddress;
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "pendleLimitOrderRouter");
            leafs[leafIndex].argumentAddresses[3] = yt;

            _addPendleLimitOrderLeafs(leafs, marketAddress);
        }
    }

    // ========================================= Pendle Limit Order =========================================

    function _addPendleLimitOrderLeafs(ManageLeaf[] memory leafs, address marketAddress) internal {
        // Approve Limit Order Router to spend yt, pt and sy.
        PendleMarket market = PendleMarket(marketAddress);
        (address sy, address pt, address yt) = market.readTokens();

        if (!ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][yt][getAddress(sourceChain, "pendleLimitOrderRouter")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: yt,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Pendle Limit Order Router to spend ", ERC20(yt).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleLimitOrderRouter");
            ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][yt][getAddress(sourceChain, "pendleLimitOrderRouter")] = true;
        }

        if (!ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][pt][getAddress(sourceChain, "pendleLimitOrderRouter")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: pt,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Pendle Limit Order Router to spend ", ERC20(pt).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleLimitOrderRouter");
            ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][pt][getAddress(sourceChain, "pendleLimitOrderRouter")] = true;
        }

        if (!ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][sy][getAddress(sourceChain, "pendleLimitOrderRouter")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: sy,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Pendle Limit Order Router to spend ", ERC20(sy).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleLimitOrderRouter");
            ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][sy][getAddress(sourceChain, "pendleLimitOrderRouter")] = true;
        }

        // Add fill leaf.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "pendleLimitOrderRouter"),
            canSendValue: false,
            signature: "fill(((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],address,uint256,bytes,bytes)",
            argumentAddresses: new address[](2),
            description: string.concat("Fill Limit orders for ", ERC20(sy).symbol(), " Pendle market"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = yt;
    }

    // ========================================= Balancer =========================================

    function _addBalancerLeafs(ManageLeaf[] memory leafs, bytes32 poolId, address gauge) internal {
        BalancerVault bv = BalancerVault(getAddress(sourceChain, "balancerVault"));

        (ERC20[] memory tokens,,) = bv.getPoolTokens(poolId);
        address pool = _getPoolAddressFromPoolId(poolId);
        uint256 tokenCount;
        for (uint256 i; i < tokens.length; i++) {
            if (
                address(tokens[i]) != pool
                    && !ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][address(tokens[i])][getAddress(sourceChain, "balancerVault")]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(tokens[i]),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Balancer Vault to spend ", tokens[i].symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "balancerVault");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(tokens[i])][getAddress(sourceChain, "balancerVault")] = true;
            }
            tokenCount++;
        }

        // Approve gauge.
        if (gauge != address(0)) {
            if (!ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][pool][gauge]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: pool,
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Balancer gauge to spend ", ERC20(pool).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = gauge;
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][pool][gauge] = true;
            }
        }

        address[] memory addressArguments = new address[](3 + tokenCount);
        addressArguments[0] = pool;
        addressArguments[1] = getAddress(sourceChain, "boringVault");
        addressArguments[2] = getAddress(sourceChain, "boringVault");
        // uint256 j;
        for (uint256 i; i < tokens.length; i++) {
            // if (address(tokens[i]) == pool) continue;
            addressArguments[3 + i] = address(tokens[i]);
            // j++;
        }

        // Join pool
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "balancerVault"),
            canSendValue: false,
            signature: "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            argumentAddresses: new address[](addressArguments.length),
            description: string.concat("Join Balancer pool ", ERC20(pool).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        for (uint256 i; i < addressArguments.length; i++) {
            leafs[leafIndex].argumentAddresses[i] = addressArguments[i];
        }

        // Exit pool
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "balancerVault"),
            canSendValue: false,
            signature: "exitPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            argumentAddresses: new address[](addressArguments.length),
            description: string.concat("Exit Balancer pool ", ERC20(pool).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        for (uint256 i; i < addressArguments.length; i++) {
            leafs[leafIndex].argumentAddresses[i] = addressArguments[i];
        }

        // Deposit into gauge.
        if (gauge != address(0)) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: gauge,
                canSendValue: false,
                signature: "deposit(uint256,address)",
                argumentAddresses: new address[](1),
                description: string.concat("Deposit ", ERC20(pool).symbol(), " into Balancer gauge"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Withdraw from gauge.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: gauge,
                canSendValue: false,
                signature: "withdraw(uint256)",
                argumentAddresses: new address[](0),
                description: string.concat("Withdraw ", ERC20(pool).symbol(), " from Balancer gauge"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });

            if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mainnet))) {
                // Mint rewards.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "minter"),
                    canSendValue: false,
                    signature: "mint(address)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Mint rewards from Balancer gauge"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = gauge;
            } else {
                // Call claim_rewards(address) on gauge.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: gauge,
                    canSendValue: false,
                    signature: "claim_rewards(address)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Claim rewards from Balancer gauge"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            }
        }
    }

    function _addBalancerSwapLeafs(ManageLeaf[] memory leafs, bytes32 poolId) internal {
        BalancerVault bv = BalancerVault(getAddress(sourceChain, "balancerVault"));

        (ERC20[] memory tokens,,) = bv.getPoolTokens(poolId);
        address pool = _getPoolAddressFromPoolId(poolId);
        uint256 tokenCount;

        require(tokens.length <= 2, "Swaps for token pools above 2 are not supported");

        for (uint256 i; i < tokens.length; i++) {
            if (
                address(tokens[i]) != pool
                    && !ownerToTokenToSpenderToApprovalInTree[
                        getAddress(sourceChain, "boringVault")
                    ][address(tokens[i])][getAddress(sourceChain, "balancerVault")]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(tokens[i]),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Balancer Vault to spend ", tokens[i].symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "balancerVault");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(tokens[i])][getAddress(sourceChain, "balancerVault")] = true;
            }
            tokenCount++;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "balancerVault"),
            canSendValue: false,
            signature: "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            argumentAddresses: new address[](5),
            description: string.concat("Swap ", tokens[0].symbol(), " for ", tokens[1].symbol(), " using Balancer"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = pool;
        leafs[leafIndex].argumentAddresses[1] = address(tokens[0]);
        leafs[leafIndex].argumentAddresses[2] = address(tokens[1]);
        leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "balancerVault"),
            canSendValue: false,
            signature: "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            argumentAddresses: new address[](5),
            description: string.concat("Swap ", tokens[1].symbol(), " for ", tokens[0].symbol(), " using Balancer"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = pool;
        leafs[leafIndex].argumentAddresses[1] = address(tokens[1]);
        leafs[leafIndex].argumentAddresses[2] = address(tokens[0]);
        leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
    }

    function _addBalancerV3Leafs(ManageLeaf[] memory leafs, address _pool, bool boosted, address gauge) internal {
        // if it's a boosted pool, these will be wrapped YB tokens, so we will need to somehow get the underlying of those pools
        // it appears like they are a standard ERC4626(?) compliant wrapper vault, so we can proably just check if the pool is boosted, and if it is, then we add ERC4626 leaves
        address[] memory tokens =
            IVaultExplorer(getAddress(sourceChain, "balancerV3VaultExplorer")).getPoolTokens(_pool);

        IBalancerV3Pool pool = IBalancerV3Pool(_pool);

        // NOTE: the router functions are all payable, but pool creation does not seem to support Native ETH? so it might be payable for something else, idk yet
        bool hasEth = false;

        //I think the router uses permit2, but will double check
        uint256 length = tokens.length;
        for (uint256 i = 0; i < length; ++i) {
            //if ETH is not used on chain, will have to add it to `ChainValues`, but this should revert during root creation alerting us of that
            if (tokens[i] == address(0) || tokens[i] == getAddress(sourceChain, "ETH")) {
                hasEth = true;
            }

            if (boosted) {
                try ERC4626(tokens[i]).asset() returns (ERC20 assetAddress) {
                    if (address(assetAddress) != address(0)) {
                        _addERC4626Leafs(leafs, ERC4626(tokens[i]));
                    }
                } catch {
                    // Token doesn't implement asset() or isn't a valid ERC4626
                    // Skip this token or handle the error as needed
                }
            }

            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(tokens[i])][_pool]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(tokens[i]),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Permit2 to spend ", ERC20(tokens[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "permit2");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(tokens[i])][getAddress(sourceChain, "permit2")] = true;

                //use permit2 to approve router
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "permit2"),
                    canSendValue: false,
                    signature: "approve(address,address,uint160,uint48)",
                    argumentAddresses: new address[](2),
                    description: string.concat(
                        "Use Permit2 to approve ", pool.name(), " to spend ", ERC20(tokens[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = tokens[i];
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "balancerV3Router");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(tokens[i])][getAddress(sourceChain, "balancerV3Router")] = true;
            }

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "permit2"),
                canSendValue: false,
                signature: "lockdown((address,address)[])",
                argumentAddresses: new address[](2),
                description: string.concat("Revoke approval from BalancerV3Router for ", ERC20(tokens[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = tokens[i];
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "balancerV3Router");
        }

        if (!ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][address(_pool)][getAddress(sourceChain, "permit2")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(_pool),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Router to spend bpt: ", ERC20(_pool).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "balancerV3Router");
            ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][address(_pool)][getAddress(sourceChain, "balancerV3Router")] = true;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "balancerV3Router"),
            canSendValue: false,
            signature: "addLiquidityProportional(address,uint256[],uint256,bool,bytes)",
            argumentAddresses: new address[](1),
            description: string.concat("Add liquidty proportional to ", pool.name(), " on BalancerV3"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = _pool;

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "balancerV3Router"),
                canSendValue: true,
                signature: "addLiquidityProportional(address,uint256[],uint256,bool,bytes)",
                argumentAddresses: new address[](1),
                description: string.concat("Add liquidty proportional to ", pool.name(), " on BalancerV3"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "balancerV3Router"),
            canSendValue: false,
            signature: "addLiquidityUnbalanced(address,uint256[],uint256,bool,bytes)",
            argumentAddresses: new address[](1),
            description: string.concat("Add liquidty unbalanced to ", pool.name(), " on BalancerV3"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = _pool;

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "balancerV3Router"),
                canSendValue: true,
                signature: "addLiquidityUnbalanced(address,uint256[],uint256,bool,bytes)",
                argumentAddresses: new address[](1),
                description: string.concat("Add liquidty proportional to ", pool.name(), " on BalancerV3"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "balancerV3Router"),
            canSendValue: false,
            signature: "addLiquiditySingleTokenExactOut(address,address,uint256,uint256,bool,bytes)",
            argumentAddresses: new address[](1),
            description: string.concat("Add liquidty unbalanced to ", pool.name(), " on BalancerV3"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = _pool;
        //leafs[leafIndex].argumentAddresses[1] = _pool;

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "balancerV3Router"),
                canSendValue: true,
                signature: "addLiquiditySingleTokenExactOut(address,address,uint256,uint256,bool,bytes)",
                argumentAddresses: new address[](1),
                description: string.concat("Add liquidty proportional to ", pool.name(), " on BalancerV3"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "balancerV3Router"),
            canSendValue: false,
            signature: "addLiquidityCustom(address,uint256[],uint256,bool,bytes)",
            argumentAddresses: new address[](1),
            description: string.concat("Add liquidty custom to ", pool.name(), " on BalancerV3"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = _pool;

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "balancerV3Router"),
                canSendValue: true,
                signature: "addLiquidityCustom(address,uint256[],uint256,bool,bytes)",
                argumentAddresses: new address[](1),
                description: string.concat("Add liquidty custom to ", pool.name(), " on BalancerV3"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "balancerV3Router"),
            canSendValue: false,
            signature: "removeLiquidityProportional(address,uint256,uint256[],bool,bytes)",
            argumentAddresses: new address[](1),
            description: string.concat("Remove liquidity proportional to ", pool.name(), " on BalancerV3"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = _pool;

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "balancerV3Router"),
                canSendValue: true,
                signature: "removeLiquidityProportional(address,uint256,uint256[],bool,bytes)",
                argumentAddresses: new address[](1),
                description: string.concat("Remove liquidity proportional to ", pool.name(), " on BalancerV3"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "balancerV3Router"),
            canSendValue: false,
            signature: "removeLiquiditySingleTokenExactIn(address,uint256,address,uint256,bool,bytes)",
            argumentAddresses: new address[](1),
            description: string.concat("Remove liquidty single token exact in from ", pool.name()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = _pool;

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "balancerV3Router"),
                canSendValue: true,
                signature: "removeLiquiditySingleTokenExactIn(address,uint256,address,uint256,bool,bytes)",
                argumentAddresses: new address[](1),
                description: string.concat("Remove liquidty single token exact in from ", pool.name()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "balancerV3Router"),
            canSendValue: false,
            signature: "removeLiquiditySingleTokenExactOut(address,uint256,address,uint256,bool,bytes)",
            argumentAddresses: new address[](1),
            description: string.concat("Remove Liquidity single token exact out from ", pool.name()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = _pool;

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "balancerV3Router"),
                canSendValue: true,
                signature: "removeLiquiditySingleTokenExactOut(address,uint256,address,uint256,bool,bytes)",
                argumentAddresses: new address[](1),
                description: string.concat("Remove liquidty single token exact in from ", pool.name()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "balancerV3Router"),
            canSendValue: false,
            signature: "removeLiquidityCustom(address,uint256,uint256[],bool,bytes)",
            argumentAddresses: new address[](1),
            description: string.concat("Remove Liquidity custom from ", pool.name()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = _pool;

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "balancerV3Router"),
                canSendValue: true,
                signature: "removeLiquidityCustom(address,uint256,uint256[],bool,bytes)",
                argumentAddresses: new address[](1),
                description: string.concat("Remove Liquidity custom from ", pool.name()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "balancerV3Router"),
            canSendValue: false,
            signature: "removeLiquidityRecovery(address,uint256,uint256[])",
            argumentAddresses: new address[](1),
            description: string.concat("Remove Liquidity in recovery mode from ", pool.name()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = _pool;

        if (gauge != address(0)) {
            _addCurveGaugeLeafs(leafs, gauge);
        }
    }

    function _addBalancerV3SwapLeafs(ManageLeaf[] memory leafs, address _pool, bool hasEth) internal {
        address[] memory tokens =
            IVaultExplorer(getAddress(sourceChain, "balancerV3VaultExplorer")).getPoolTokens(_pool);

        IBalancerV3Pool pool = IBalancerV3Pool(_pool);

        //if the pool as WETH, you can use native eth and wrap it

        //I think the router uses permit2, but will double check
        uint256 length = tokens.length;
        for (uint256 i = 0; i < length; ++i) {
            //unchecked {
            //    leafIndex++;
            //}

            //leafs[leafIndex] = ManageLeaf(
            //    address(tokens[i]),
            //    false,
            //    "approve(address,uint256)",
            //    new address[](1),
            //    string.concat("Approve BalancerV3 Vault to spend ", ERC20(tokens[i]).symbol()),
            //    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            //);
            //leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "balancerV3Vault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(tokens[i]),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Permit2 to spend ", ERC20(tokens[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "permit2");
            ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][address(tokens[i])][getAddress(sourceChain, "permit2")] = true;

            //use permit2 to approve router
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "permit2"),
                canSendValue: false,
                signature: "approve(address,address,uint160,uint48)",
                argumentAddresses: new address[](2),
                description: string.concat(
                    "Use Permit2 to approve ", pool.name(), " to spend ", ERC20(tokens[i]).symbol()
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = tokens[i];
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "balancerV3Router");
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "balancerV3Router"),
            canSendValue: false,
            signature: "swapSingleTokenExactIn(address,address,address,uint256,uint256,uint256,bool,bytes)",
            argumentAddresses: new address[](1),
            description: string.concat("Swap tokens using ", ERC20(_pool).name()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = _pool;
        //leafs[leafIndex].argumentAddresses[1] = tokens[0]; //token0
        //leafs[leafIndex].argumentAddresses[2] = tokens[1]; //token1...tokenN

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "balancerV3Router"),
                canSendValue: true,
                signature: "swapSingleTokenExactIn(address,address,address,uint256,uint256,uint256,bool,bytes)",
                argumentAddresses: new address[](1),
                description: string.concat("Swap tokens using ", ERC20(_pool).name()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "balancerV3Router"),
            canSendValue: false,
            signature: "swapSingleTokenExactOut(address,address,address,uint256,uint256,uint256,bool,bytes)",
            argumentAddresses: new address[](1),
            description: string.concat("Swap tokens using ", ERC20(_pool).name()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = _pool;
        //leafs[leafIndex].argumentAddresses[1] = tokens[0]; //token0
        //leafs[leafIndex].argumentAddresses[2] = tokens[1]; //token1...tokenN

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "balancerV3Router"),
                canSendValue: true,
                signature: "swapSingleTokenExactOut(address,address,address,uint256,uint256,uint256,bool,bytes)",
                argumentAddresses: new address[](1),
                description: string.concat("Swap tokens using ", ERC20(_pool).name()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }
    }

    // ========================================= Aura =========================================

    function _addAuraLeafs(ManageLeaf[] memory leafs, address auraDeposit) internal {
        ERC4626 auraVault = ERC4626(auraDeposit);
        ERC20 bpt = auraVault.asset();

        // Approve vault to spend BPT.
        if (!ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(bpt)][auraDeposit]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(bpt),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve ", auraVault.symbol(), " to spend ", bpt.symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = auraDeposit;
            ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(bpt)][auraDeposit] =
            true;
        }

        // Deposit BPT into Aura vault.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: auraDeposit,
            canSendValue: false,
            signature: "deposit(uint256,address)",
            argumentAddresses: new address[](1),
            description: string.concat("Deposit ", bpt.symbol(), " into ", auraVault.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Withdraw BPT from Aura vault.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: auraDeposit,
            canSendValue: false,
            signature: "withdraw(uint256,address,address)",
            argumentAddresses: new address[](2),
            description: string.concat("Withdraw ", bpt.symbol(), " from ", auraVault.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        // Call getReward.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: auraDeposit,
            canSendValue: false,
            signature: "getReward(address,bool)",
            argumentAddresses: new address[](1),
            description: string.concat("Get rewards from ", auraVault.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= MorphoBlue =========================================

    function _addMorphoBlueSupplyLeafs(ManageLeaf[] memory leafs, bytes32 marketId) internal {
        IMB.MarketParams memory marketParams = IMB(getAddress(sourceChain, "morphoBlue")).idToMarketParams(marketId);
        ERC20 loanToken = ERC20(marketParams.loanToken);
        ERC20 collateralToken;
        if (marketParams.collateralToken != address(0)) {
            collateralToken = ERC20(marketParams.collateralToken);
        }
        uint256 leftSideLLTV = marketParams.lltv / 1e16;
        uint256 rightSideLLTV = (marketParams.lltv / 1e14) % 100;

        string memory morphoBlueMarketName;
        if (address(collateralToken) == address(0)) {
            morphoBlueMarketName = string.concat(
                "MorphoBlue ",
                "IDLE" "/",
                loanToken.symbol(),
                " ",
                vm.toString(leftSideLLTV),
                ".",
                vm.toString(rightSideLLTV),
                " LLTV market"
            );
        } else {
            morphoBlueMarketName = string.concat(
                "MorphoBlue ",
                collateralToken.symbol(),
                "/",
                loanToken.symbol(),
                " ",
                vm.toString(leftSideLLTV),
                ".",
                vm.toString(rightSideLLTV),
                " LLTV market"
            );
        }
        // Add approval leaf if not already added
        if (!ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][marketParams.loanToken][getAddress(sourceChain, "morphoBlue")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: marketParams.loanToken,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve MorhoBlue to spend ", loanToken.symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "morphoBlue");
            ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][marketParams.loanToken][getAddress(sourceChain, "morphoBlue")] = true;
        }
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "morphoBlue"),
            canSendValue: false,
            signature: "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            argumentAddresses: new address[](5),
            description: string.concat("Supply ", loanToken.symbol(), " to ", morphoBlueMarketName),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
        leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
        leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
        leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
        leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "morphoBlue"),
            canSendValue: false,
            signature: "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            argumentAddresses: new address[](6),
            description: string.concat("Withdraw ", loanToken.symbol(), " from ", morphoBlueMarketName),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
        leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
        leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
        leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
        leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[5] = getAddress(sourceChain, "boringVault");
    }

    function _addMorphoBlueCollateralLeafs(ManageLeaf[] memory leafs, bytes32 marketId) internal {
        IMB.MarketParams memory marketParams = IMB(getAddress(sourceChain, "morphoBlue")).idToMarketParams(marketId);
        ERC20 loanToken = ERC20(marketParams.loanToken);
        ERC20 collateralToken;
        if (marketParams.collateralToken != address(0)) {
            collateralToken = ERC20(marketParams.collateralToken);
        }
        uint256 leftSideLLTV = marketParams.lltv / 1e16;
        uint256 rightSideLLTV = (marketParams.lltv / 1e14) % 100;

        string memory morphoBlueMarketName;
        if (address(collateralToken) == address(0)) {
            morphoBlueMarketName = string.concat(
                "MorphoBlue ",
                "IDLE" "/",
                loanToken.symbol(),
                " ",
                vm.toString(leftSideLLTV),
                ".",
                vm.toString(rightSideLLTV),
                " LLTV market"
            );
        } else {
            morphoBlueMarketName = string.concat(
                "MorphoBlue ",
                collateralToken.symbol(),
                "/",
                loanToken.symbol(),
                " ",
                vm.toString(leftSideLLTV),
                ".",
                vm.toString(rightSideLLTV),
                " LLTV market"
            );
        }

        // Approve MorphoBlue to spend collateral.
        if (!ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][marketParams.collateralToken][getAddress(sourceChain, "morphoBlue")]) {
            if (address(collateralToken) != address(0)) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: marketParams.collateralToken,
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve MorhoBlue to spend ", collateralToken.symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "morphoBlue");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][marketParams.collateralToken][getAddress(sourceChain, "morphoBlue")] = true;
            }
        }
        // Approve morpho blue to spend loan token.
        if (!ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][marketParams.collateralToken][getAddress(sourceChain, "morphoBlue")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: marketParams.loanToken,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve MorhoBlue to spend ", loanToken.symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "morphoBlue");
            ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][marketParams.loanToken][getAddress(sourceChain, "morphoBlue")] = true;
        }
        // Supply collateral to MorphoBlue.

        if (address(collateralToken) != address(0)) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "morphoBlue"),
                canSendValue: false,
                signature: "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)",
                argumentAddresses: new address[](5),
                description: string.concat("Supply ", collateralToken.symbol(), " to ", morphoBlueMarketName),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
        }

        // Borrow loan token from MorphoBlue.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "morphoBlue"),
            canSendValue: false,
            signature: "borrow((address,address,address,address,uint256),uint256,uint256,address,address)",
            argumentAddresses: new address[](6),
            description: string.concat("Borrow ", loanToken.symbol(), " from ", morphoBlueMarketName),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
        leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
        leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
        leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
        leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[5] = getAddress(sourceChain, "boringVault");

        // Repay loan token to MorphoBlue.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "morphoBlue"),
            canSendValue: false,
            signature: "repay((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            argumentAddresses: new address[](5),
            description: string.concat("Repay ", loanToken.symbol(), " to ", morphoBlueMarketName),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
        leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
        leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
        leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
        leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");

        // Withdraw collateral from MorphoBlue.
        if (address(collateralToken) != address(0)) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "morphoBlue"),
                canSendValue: false,
                signature: "withdrawCollateral((address,address,address,address,uint256),uint256,address,address)",
                argumentAddresses: new address[](6),
                description: string.concat("Withdraw ", collateralToken.symbol(), " from ", morphoBlueMarketName),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[5] = getAddress(sourceChain, "boringVault");
        }
    }

    function _addMorphoBlueRepayLeafs(ManageLeaf[] memory leafs, bytes32 marketId) internal {
        IMB.MarketParams memory marketParams = IMB(getAddress(sourceChain, "morphoBlue")).idToMarketParams(marketId);
        ERC20 loanToken = ERC20(marketParams.loanToken);
        ERC20 collateralToken = ERC20(marketParams.collateralToken);
        uint256 leftSideLLTV = marketParams.lltv / 1e16;
        uint256 rightSideLLTV = (marketParams.lltv / 1e14) % 100;

        string memory morphoBlueMarketName = string.concat(
            "MorphoBlue ",
            collateralToken.symbol(),
            "/",
            loanToken.symbol(),
            " ",
            vm.toString(leftSideLLTV),
            ".",
            vm.toString(rightSideLLTV),
            " LLTV market"
        );

        // Approve morpho blue to spend loan token.
        if (!ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][marketParams.collateralToken][getAddress(sourceChain, "morphoBlue")]) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf({
                target: marketParams.loanToken,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve MorhoBlue to spend ", loanToken.symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "morphoBlue");
            ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][marketParams.loanToken][getAddress(sourceChain, "morphoBlue")] = true;
        }

        // repay morpho loan
        leafIndex++;
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "morphoBlue"),
            canSendValue: false,
            signature: "repay((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            argumentAddresses: new address[](5),
            description: string.concat("Repay ", loanToken.symbol(), " to ", morphoBlueMarketName),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
        leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
        leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
        leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
        leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
    }

    function _addMorphoRewardWrapperLeafs(ManageLeaf[] memory leafs) internal {
        address legacyToken = getAddress(sourceChain, "legacyMorpho");
        address newToken = getAddress(sourceChain, "newMorpho");
        address wrapper = getAddress(sourceChain, "morphoRewardsWrapper");
        // Approve morpho rewards wrapper to spend legacy morpho.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: legacyToken,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Approve morpho rewards wrapper to spend legacy morpho",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "morphoRewardsWrapper");

        // Approve morpho rewards wrapper to spend new morpho.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: newToken,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Approve morpho rewards wrapper to spend new morpho",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "morphoRewardsWrapper");

        // Wrapping
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: wrapper,
            canSendValue: false,
            signature: "depositFor(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Wrap legacy morpho for new morpho",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Unwrapping
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: wrapper,
            canSendValue: false,
            signature: "withdrawTo(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Unwrap new morpho for legacy morpho",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    function _addMorphoRewardMerkleClaimerLeafs(ManageLeaf[] memory leafs, address universalRewardsDistributor)
        internal
    {
        // Claim morpho rewards.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: universalRewardsDistributor,
            canSendValue: false,
            signature: "claim(address,address,uint256,bytes32[])",
            argumentAddresses: new address[](1),
            description: "Claim morpho rewards",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= ERC4626 =========================================

    function _addERC4626Leafs(ManageLeaf[] memory leafs, ERC4626 vault) internal {
        ERC20 asset = vault.asset();
        // Approvals
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(asset),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve ", vault.symbol(), " to spend ", asset.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = address(vault);
        // Depositing
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(vault),
            canSendValue: false,
            signature: "deposit(uint256,address)",
            argumentAddresses: new address[](1),
            description: string.concat("Deposit ", asset.symbol(), " for ", vault.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        // Withdrawing
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(vault),
            canSendValue: false,
            signature: "withdraw(uint256,address,address)",
            argumentAddresses: new address[](2),
            description: string.concat("Withdraw ", asset.symbol(), " from ", vault.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        // Minting
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(vault),
            canSendValue: false,
            signature: "mint(uint256,address)",
            argumentAddresses: new address[](1),
            description: string.concat("Mint ", vault.symbol(), " using ", asset.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Redeeming
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(vault),
            canSendValue: false,
            signature: "redeem(uint256,address,address)",
            argumentAddresses: new address[](2),
            description: string.concat("Redeem ", vault.symbol(), " for ", asset.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
    }

    function _addERC4626SubaccountLeafs(ManageLeaf[] memory leafs, ERC4626 vault, address subaccount) internal {
        ERC20 asset = vault.asset();
        // Approvals
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(asset),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve ", vault.symbol(), " to spend ", asset.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = address(vault);
        // Depositing
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(vault),
            canSendValue: false,
            signature: "deposit(uint256,address)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Deposit ", asset.symbol(), " for ", vault.symbol(), " for ", vm.toString(subaccount)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = subaccount;
        // Withdrawing
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(vault),
            canSendValue: false,
            signature: "withdraw(uint256,address,address)",
            argumentAddresses: new address[](2),
            description: string.concat(
                "Withdraw ", asset.symbol(), " from ", vault.symbol(), " for ", vm.toString(subaccount)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = subaccount;

        // Minting
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(vault),
            canSendValue: false,
            signature: "mint(uint256,address)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Mint ", vault.symbol(), " using ", asset.symbol(), " for ", vm.toString(subaccount)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = subaccount;

        // Redeeming
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(vault),
            canSendValue: false,
            signature: "redeem(uint256,address,address)",
            argumentAddresses: new address[](2),
            description: string.concat(
                "Redeem ", vault.symbol(), " for ", asset.symbol(), " for ", vm.toString(subaccount)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = subaccount;
    }

    // ========================================= Vault Craft =========================================

    function _addVaultCraftLeafs(ManageLeaf[] memory leafs, ERC4626 vault, address gauge) internal {
        _addERC4626Leafs(leafs, vault);

        // Add leafs for gauge.
        // Approve gauge to spend vault share.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(vault),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve ", vault.symbol(), " gauge to spend", vault.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = gauge;

        // Deposit vault share into gauge.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: gauge,
            canSendValue: false,
            signature: "deposit(uint256,address)",
            argumentAddresses: new address[](1),
            description: string.concat("Deposit ", vault.symbol(), " share into gauge"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Withdraw vault share from gauge.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: gauge,
            canSendValue: false,
            signature: "withdraw(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Withdraw ", vault.symbol(), " share from gauge"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        // Claim rewards from gauge.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: gauge,
            canSendValue: false,
            signature: "claim_rewards(address)",
            argumentAddresses: new address[](1),
            description: string.concat("Claim rewards from gauge"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Gearbox =========================================

    function _addGearboxLeafs(ManageLeaf[] memory leafs, ERC4626 dieselVault, address dieselStaking) internal {
        _addERC4626Leafs(leafs, dieselVault);
        string memory dieselVaultSymbol = dieselVault.symbol();

        if (dieselStaking == address(0)) return;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(dieselVault),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve s", dieselVaultSymbol, " to spend ", dieselVaultSymbol),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = dieselStaking;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: dieselStaking,
            canSendValue: false,
            signature: "deposit(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Deposit ", dieselVaultSymbol, " for s", dieselVaultSymbol),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: dieselStaking,
            canSendValue: false,
            signature: "withdraw(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Withdraw ", dieselVaultSymbol, " from s", dieselVaultSymbol),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: dieselStaking,
            canSendValue: false,
            signature: "claim()",
            argumentAddresses: new address[](0),
            description: string.concat("Claim rewards from s", dieselVaultSymbol),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= Atomic Queue =========================================

    function _addAtomicQueueLeafs(ManageLeaf[] memory leafs, address queue, ERC20 offer, ERC20 want) internal {
        // approve
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(offer),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve queue to spend ", offer.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = queue;
        // updateAtomicRequest
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: queue,
            canSendValue: false,
            signature: "updateAtomicRequest(address,address,(uint64,uint88,uint96,bool))",
            argumentAddresses: new address[](2),
            description: string.concat("Update Atomic Request offer: ", offer.symbol(), " want: ", want.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = address(offer);
        leafs[leafIndex].argumentAddresses[1] = address(want);
    }

    // ========================================= EIGEN LAYER LST =========================================

    function _addLeafsForEigenLayerLST(
        ManageLeaf[] memory leafs,
        address lst,
        address strategy,
        address _strategyManager,
        address _delegationManager,
        address operator,
        address rewardsContract,
        address claimerFor
    ) internal {
        // Approvals.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: lst,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Eigen Layer Strategy Manager to spend ", ERC20(lst).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = _strategyManager;
        ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][lst][_strategyManager] = true;
        // Depositing.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: _strategyManager,
            canSendValue: false,
            signature: "depositIntoStrategy(address,address,uint256)",
            argumentAddresses: new address[](2),
            description: string.concat("Deposit ", ERC20(lst).symbol(), " into Eigen Layer Strategy Manager"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = strategy;
        leafs[leafIndex].argumentAddresses[1] = lst;
        // Request withdraw.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: _delegationManager,
            canSendValue: false,
            signature: "queueWithdrawals((address[],uint256[],address)[])",
            argumentAddresses: new address[](2),
            description: string.concat(
                "Request withdraw of ", ERC20(lst).symbol(), " from Eigen Layer Delegation Manager"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = strategy;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        // Complete withdraw.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: _delegationManager,
            canSendValue: false,
            signature: "completeQueuedWithdrawals((address,address,address,uint256,uint32,address[],uint256[])[],address[][],uint256[],bool[])",
            argumentAddresses: new address[](5),
            description: string.concat(
                "Complete withdraw of ", ERC20(lst).symbol(), " from Eigen Layer Delegation Manager"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = address(0);
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[3] = strategy;
        leafs[leafIndex].argumentAddresses[4] = lst;

        //new leaf version
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: _delegationManager,
            canSendValue: false,
            signature: "completeQueuedWithdrawals((address,address,address,uint256,uint32,address[],uint256[])[],address[][],bool[])",
            argumentAddresses: new address[](5),
            description: string.concat(
                "Complete withdraw of ", ERC20(lst).symbol(), " from Eigen Layer Delegation Manager"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = address(0);
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[3] = strategy;
        leafs[leafIndex].argumentAddresses[4] = lst;

        //new leaf version
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: _delegationManager,
            canSendValue: false,
            signature: "completeQueuedWithdrawals((address,address,address,uint256,uint32,address[],uint256[])[],address[][],bool[])",
            argumentAddresses: new address[](5),
            description: string.concat(
                "Complete withdraw of ",
                ERC20(lst).symbol(),
                " from Eigen Layer Delegation Manager from ",
                vm.toString(operator)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = operator;
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[3] = strategy;
        leafs[leafIndex].argumentAddresses[4] = lst;

        // Delegation.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: _delegationManager,
            canSendValue: false,
            signature: "delegateTo(address,(bytes,uint256),bytes32)",
            argumentAddresses: new address[](1),
            description: string.concat("Delegate to ", vm.toString(operator)),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = operator;

        // Undelegate
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: _delegationManager,
            canSendValue: false,
            signature: "undelegate(address)",
            argumentAddresses: new address[](1),
            description: string.concat("Undelegate from ", vm.toString(operator)),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Handle reward claiming.
        if (claimerFor != address(0)) {
            // Add setClaimerFor leaf.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: rewardsContract,
                canSendValue: false,
                signature: "setClaimerFor(address)",
                argumentAddresses: new address[](1),
                description: string.concat("Set rewards claimer to ", vm.toString(claimerFor)),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = claimerFor;
        }

        // Add processClaim leaf.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: rewardsContract,
            canSendValue: false,
            signature: "processClaim((uint32,uint32,bytes,(address,bytes32),uint32[],bytes[],(address,uint256)[]),address)",
            argumentAddresses: new address[](1),
            description: string.concat("Process claim for EIGEN Rewards"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Swell Simple Staking =========================================

    function _addSwellSimpleStakingLeafs(ManageLeaf[] memory leafs, address asset, address _swellSimpleStaking)
        internal
    {
        // Approval
        if (!ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][asset][_swellSimpleStaking])
        {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: asset,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Swell Simple Staking to spend ", ERC20(asset).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = _swellSimpleStaking;
            ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][asset][_swellSimpleStaking] =
                true;
        }
        // deposit
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: _swellSimpleStaking,
            canSendValue: false,
            signature: "deposit(address,uint256,address)",
            argumentAddresses: new address[](2),
            description: string.concat("Deposit ", ERC20(asset).symbol(), " into Swell Simple Staking"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = asset;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        // withdraw
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: _swellSimpleStaking,
            canSendValue: false,
            signature: "withdraw(address,uint256,address)",
            argumentAddresses: new address[](2),
            description: string.concat("Withdraw ", ERC20(asset).symbol(), " from Swell Simple Staking"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = asset;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Hyperlane =========================================

    function _addLeafsForHyperlane(
        ManageLeaf[] memory leafs,
        uint32 destinationDomain,
        bytes32 recipient,
        ERC20 asset,
        address hyperlaneTokenRouter
    ) internal {
        // Approve hyperlane contract to spend asset.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(asset),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Hyperlane Token Router to spend ", asset.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = hyperlaneTokenRouter;

        // Call transferRemote on hyperlaneTokenRouter
        // forge-lint: disable-next-line(unsafe-typecast)
        address recipient0 = address(bytes20(bytes16(recipient)));
        // forge-lint: disable-next-line(unsafe-typecast)
        address recipient1 = address(bytes20(bytes16(recipient << 128)));
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: hyperlaneTokenRouter,
            canSendValue: true,
            signature: "transferRemote(uint32,bytes32,uint256)",
            argumentAddresses: new address[](3),
            description: string.concat(
                "Bridge ", asset.symbol(), " to ", vm.toString(destinationDomain), " via Hyperlane Token Router"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = address(uint160(destinationDomain));
        leafs[leafIndex].argumentAddresses[1] = recipient0;
        leafs[leafIndex].argumentAddresses[2] = recipient1;
    }

    // ========================================= Avalanche C-Chain Bridge / Core Bridge =========================================
    // @dev note that ERC20 is fine here as ETH is not supported and must be converted to WETH first
    function _addAvalancheBridgeLeafs(ManageLeaf[] memory leafs, ERC20[] memory assets) internal {
        if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mainnet))) {
            for (uint256 i = 0; i < assets.length; i++) {
                console.log("RUNNING");
                //approve USDC if there
                if (address(assets[i]) == getAddress(sourceChain, "USDC")) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: address(assets[i]),
                        canSendValue: false,
                        signature: "approve(address,uint256)",
                        argumentAddresses: new address[](1),
                        description: string.concat("Approve USDC Token Router to spend ", assets[i].symbol()),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "usdcTokenRouter");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "usdcTokenRouter"),
                        canSendValue: false,
                        signature: "transferTokens(uint256,uint32,address,address)",
                        argumentAddresses: new address[](3),
                        description: string.concat("Transfer USDC to TokenRouter to bridge"),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = address(1);
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "USDC");
                }

                if (address(assets[i]) != getAddress(sourceChain, "USDC")) {
                    //@dev add regular transfer leaves for all assets that are not USDC
                    //@notice must be supported by bridge in the first place
                    _addTransferLeafs(leafs, assets[i], getAddress(sourceChain, "avalancheBridge"));
                }
            }
        }

        if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(avalanche))) {
            for (uint256 i = 0; i < assets.length; i++) {
                console.log("RUNNING AVALANCHE");
                //approve USDC if there
                if (address(assets[i]) == getAddress(sourceChain, "USDC")) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: address(assets[i]),
                        canSendValue: false,
                        signature: "approve(address,uint256)",
                        argumentAddresses: new address[](1),
                        description: string.concat("Approve USDC Token Router to spend ", assets[i].symbol()),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "usdcTokenRouter");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "usdcTokenRouter"),
                        canSendValue: false,
                        signature: "transferTokens(uint256,uint32,address,address)",
                        argumentAddresses: new address[](3),
                        description: string.concat("Transfer USDC to TokenRouter to bridge"),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = address(0);
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "USDC");
                }

                if (address(assets[i]) != getAddress(sourceChain, "USDC")) {
                    revert("Contracts not supported for assets other than USDC");
                    //unchecked {
                    //    leafIndex++;
                    //}
                    //leafs[leafIndex] = ManageLeaf(
                    //    address(assets[i]),
                    //    false,
                    //    "unwrap(uint256,uint256)",
                    //    new address[](1),
                    //    string.concat("Unwrap ", assets[i].symbol(), " and bridge to Ethereum"),
                    //    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    //);
                    //leafs[leafIndex].argumentAddresses[0] = address(0);
                }
            }
        }
    }

    // ========================================= Corn Staking =========================================

    function _addLeafsForCornStaking(ManageLeaf[] memory leafs, ERC20[] memory assets) internal {
        for (uint256 i; i < assets.length; ++i) {
            // Approve cornSilo to spend asset.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(assets[i]),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Corn Silo to spend ", assets[i].symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "cornSilo");

            if (address(assets[i]) == getAddress(sourceChain, "WBTC")) {
                // Need to add special bitcorn leafs.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "cornSilo"),
                    canSendValue: false,
                    signature: "mintAndDepositBitcorn(uint256)",
                    argumentAddresses: new address[](0),
                    description: string.concat("Deposit ", assets[i].symbol(), " into cornSilo for Bitcorn"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "cornSilo"),
                    canSendValue: false,
                    signature: "redeemBitcorn(uint256)",
                    argumentAddresses: new address[](0),
                    description: string.concat("Burn Bitcorn from cornSilo for ", assets[i].symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
            } else {
                // use generic deposit and withdraw
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "cornSilo"),
                    canSendValue: false,
                    signature: "deposit(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Deposit ", assets[i].symbol(), " into cornSilo"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(assets[i]);

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "cornSilo"),
                    canSendValue: false,
                    signature: "redeemToken(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Withdraw ", assets[i].symbol(), " from cornSilo"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
            }
        }
    }

    // ========================================= Pump Staking =========================================

    function _addLeafsForPumpStaking(ManageLeaf[] memory leafs, address pumpStaking, ERC20 asset) internal {
        // Approve
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(asset),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Pump Staking to spend ", asset.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = pumpStaking;

        // Stake
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: pumpStaking,
            canSendValue: false,
            signature: "stake(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Stake ", asset.symbol(), " into Pump Staking"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        // Unstake Request
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: pumpStaking,
            canSendValue: false,
            signature: "unstakeRequest(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Request unstake of ", asset.symbol(), " from Pump Staking"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        // Claim Slot
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: pumpStaking,
            canSendValue: false,
            signature: "claimSlot(uint8)",
            argumentAddresses: new address[](0),
            description: string.concat("Claim slot from Pump Staking"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        // Claim All
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: pumpStaking,
            canSendValue: false,
            signature: "claimAll()",
            argumentAddresses: new address[](0),
            description: string.concat("Claim all withdraws from Pump Staking"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        // Unstake Instant
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: pumpStaking,
            canSendValue: false,
            signature: "unstakeInstant(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Unstake ", asset.symbol(), " instantly from Pump Staking"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= Satlayer Staking =========================================

    function _addSatlayerStakingLeafs(ManageLeaf[] memory leafs, ERC20[] memory assets) internal {
        address satlayerPool = getAddress(sourceChain, "satlayerPool");
        for (uint256 i; i < assets.length; ++i) {
            // Approval
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(assets[i]),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Satlayer Pool to spend ", ERC20(assets[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = satlayerPool;
            // deposit
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: satlayerPool,
                canSendValue: false,
                signature: "depositFor(address,address,uint256)",
                argumentAddresses: new address[](2),
                description: string.concat("Deposit ", ERC20(assets[i]).symbol(), " into Satlayer Pool"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            // withdraw
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: satlayerPool,
                canSendValue: false,
                signature: "withdraw(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Withdraw ", ERC20(assets[i]).symbol(), " from Satlayer Pool"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
        }
    }

    // ========================================= Zircuit Staking =========================================

    function _addZircuitLeafs(ManageLeaf[] memory leafs, address asset, address _zircuitSimpleStaking) internal {
        // Approval
        if (!ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][asset][_zircuitSimpleStaking]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: asset,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Zircuit simple staking to spend ", ERC20(asset).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = _zircuitSimpleStaking;
            ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][asset][_zircuitSimpleStaking] = true;
        }
        // deposit
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: _zircuitSimpleStaking,
            canSendValue: false,
            signature: "depositFor(address,address,uint256)",
            argumentAddresses: new address[](2),
            description: string.concat("Deposit ", ERC20(asset).symbol(), " into Zircuit simple staking"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = asset;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        // withdraw
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: _zircuitSimpleStaking,
            canSendValue: false,
            signature: "withdraw(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Withdraw ", ERC20(asset).symbol(), " from Zircuit simple staking"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = asset;
    }

    // ========================================= Ethena Withdraws =========================================

    function _addEthenaSUSDeWithdrawLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "SUSDE"),
            canSendValue: false,
            signature: "cooldownAssets(uint256)",
            argumentAddresses: new address[](0),
            description: "Withdraw from sUSDe specifying asset amount.",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "SUSDE"),
            canSendValue: false,
            signature: "cooldownShares(uint256)",
            argumentAddresses: new address[](0),
            description: "Withdraw from sUSDe specifying share amount.",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "SUSDE"),
            canSendValue: false,
            signature: "unstake(address)",
            argumentAddresses: new address[](1),
            description: "Complete withdraw from sUSDe.",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Ethena Minting =========================================
    function _addEthenaMintingLeafs(ManageLeaf[] memory leafs, address signer) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "USDE"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Ethena Minter V2 to spend ", getERC20(sourceChain, "USDE").symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "ethenaMinterV2");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "ethenaMinterV2"),
            canSendValue: false,
            signature: "setDelegatedSigner(address)",
            argumentAddresses: new address[](1),
            description: string.concat("Set ", vm.toString(signer), " as delegated EthenaMinter Signer"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = signer;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "ethenaMinterV2"),
            canSendValue: false,
            signature: "removeDelegatedSigner(address)",
            argumentAddresses: new address[](1),
            description: string.concat("Remove ", vm.toString(signer), " as delegated EthenaMinter Signer"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = signer;

        address[] memory stables = new address[](2);
        stables[0] = getAddress(sourceChain, "USDT");
        stables[1] = getAddress(sourceChain, "USDC");

        for (uint256 i = 0; i < stables.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: stables[i],
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Ethena Minter V2 to spend ", ERC20(stables[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "ethenaMinterV2");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "ethenaMinterV2"),
                canSendValue: false,
                signature: "mint((string,uint8,uint120,uint128,address,address,address,uint128,uint128),(address[],uint128[]),(uint8,bytes))",
                argumentAddresses: new address[](3),
                description: string.concat("Mint USDE with ", ERC20(stables[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = stables[i];

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "ethenaMinterV2"),
                canSendValue: false,
                signature: "redeem((string,uint8,uint120,uint128,address,address,address,uint128,uint128),(uint8,bytes))",
                argumentAddresses: new address[](3),
                description: string.concat("Redeem USDE for ", ERC20(stables[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = stables[i];
        }
    }

    // ========================================= Level Withdraws =========================================

    function _addSLvlUSDWithdrawLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "slvlUSD"),
            canSendValue: false,
            signature: "cooldownAssets(uint256)",
            argumentAddresses: new address[](0),
            description: "Withdraw from slvlUSD specifying asset amount.",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "slvlUSD"),
            canSendValue: false,
            signature: "cooldownShares(uint256)",
            argumentAddresses: new address[](0),
            description: "Withdraw from slvlUSD specifying share amount.",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "slvlUSD"),
            canSendValue: false,
            signature: "unstake(address)",
            argumentAddresses: new address[](1),
            description: "Complete withdraw from slvlUSD.",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Elixir Withdraws =========================================

    function _addElixirSdeUSDWithdrawLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "sdeUSD"),
            canSendValue: false,
            signature: "cooldownAssets(uint256)",
            argumentAddresses: new address[](0),
            description: "Withdraw from sdeUSD specifying asset amount.",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "sdeUSD"),
            canSendValue: false,
            signature: "cooldownShares(uint256)",
            argumentAddresses: new address[](0),
            description: "Withdraw from sdeUSD specifying share amount.",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "sdeUSD"),
            canSendValue: false,
            signature: "unstake(address)",
            argumentAddresses: new address[](1),
            description: "Complete withdraw from sdeUSD.",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Fluid FToken =========================================

    function _addFluidFTokenLeafs(ManageLeaf[] memory leafs, address fToken) internal {
        ERC20 asset = ERC4626(fToken).asset();
        // Approval.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(asset),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Fluid ", ERC20(fToken).symbol(), " to spend ", asset.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = fToken;

        // Depositing
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: fToken,
            canSendValue: false,
            signature: "deposit(uint256,address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Deposit ", asset.symbol(), " for ", ERC20(fToken).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        // Withdrawing
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: fToken,
            canSendValue: false,
            signature: "withdraw(uint256,address,address,uint256)",
            argumentAddresses: new address[](2),
            description: string.concat("Withdraw ", asset.symbol(), " from ", ERC20(fToken).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        // Minting
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: fToken,
            canSendValue: false,
            signature: "mint(uint256,address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Mint ", ERC20(fToken).symbol(), " using ", asset.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Redeeming
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: fToken,
            canSendValue: false,
            signature: "redeem(uint256,address,address,uint256)",
            argumentAddresses: new address[](2),
            description: string.concat("Redeem ", ERC20(fToken).symbol(), " for ", asset.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Fluid Dex =========================================

    // @notice dex borrows happen against a vault, but each dex type is different, ranging from T1 to T4 indicating either smart collateral or smart debt (see docs for more)
    // @param dexType 2000, 3000, 4000. Used by Instadapp for types of pools. They have different operate functions, but each pool will only need it's specific type
    function _addFluidDexLeafs(
        ManageLeaf[] memory leafs,
        address dex,
        uint256 dexType,
        ERC20[] memory supplyTokens,
        ERC20[] memory borrowTokens,
        bool addNative
    ) internal {
        // Approvals for token
        for (uint256 i = 0; i < supplyTokens.length; i++) {
            if (address(supplyTokens[i]) != getAddress(sourceChain, "ETH")) {
                unchecked {
                    leafIndex++;
                }

                leafs[leafIndex] = ManageLeaf({
                    target: address(supplyTokens[i]),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Fluid Dex to spend ", supplyTokens[i].symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = dex;
            }
        }

        for (uint256 i = 0; i < borrowTokens.length; i++) {
            if (address(borrowTokens[i]) != getAddress(sourceChain, "ETH")) {
                unchecked {
                    leafIndex++;
                }

                leafs[leafIndex] = ManageLeaf({
                    target: address(borrowTokens[i]),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Fluid Dex to spend ", borrowTokens[i].symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = dex;
            }
        }

        if (dexType == 1000) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(dex),
                canSendValue: false,
                signature: "operate(uint256,int256,int256,address)",
                argumentAddresses: new address[](1),
                description: string.concat("Operate on Fluid Dex Vault"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }

        //t2 and t3 leaves
        if (dexType == 2000 || dexType == 3000) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(dex),
                canSendValue: false,
                signature: "operate(uint256,int256,int256,int256,int256,address)",
                argumentAddresses: new address[](1),
                description: string.concat("Operate on Fluid Dex Vault"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(dex),
                canSendValue: false,
                signature: "operatePerfect(uint256,int256,int256,int256,int256,address)",
                argumentAddresses: new address[](1),
                description: string.concat("Operate Perfect on Fluid Dex Vault"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            if (addNative) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(dex),
                    canSendValue: true,
                    signature: "operate(uint256,int256,int256,int256,int256,address)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Operate on Fluid Dex Vault with native ETH"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(dex),
                    canSendValue: true,
                    signature: "operatePerfect(uint256,int256,int256,int256,int256,address)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Operate Perfect on Fluid Dex Vault with native ETH"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            }
        }

        //t4 leaves
        if (dexType == 4000) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(dex),
                canSendValue: false,
                signature: "operate(uint256,int256,int256,int256,int256,int256,int256,address)",
                argumentAddresses: new address[](1),
                description: string.concat("Operate on Fluid Dex Vault"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(dex),
                canSendValue: false,
                signature: "operatePerfect(uint256,int256,int256,int256,int256,int256,int256,address)",
                argumentAddresses: new address[](1),
                description: string.concat("Operate Perfect on Fluid Dex Vault"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            if (addNative) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(dex),
                    canSendValue: true,
                    signature: "operate(uint256,int256,int256,int256,int256,int256,int256,address)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Operate on Fluid Dex Vault with native ETH"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(dex),
                    canSendValue: true,
                    signature: "operatePerfect(uint256,int256,int256,int256,int256,int256,int256,address)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Operate Perfect on Fluid Dex Vault with native ETH"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            }
        }
    }

    // ========================================= Symbiotic =========================================

    function _addSymbioticApproveAndDepositLeaf(ManageLeaf[] memory leafs, address defaultCollateral) internal {
        ERC4626 dc = ERC4626(defaultCollateral);
        ERC20 depositAsset = dc.asset();
        // Approve
        if (!ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][address(depositAsset)][defaultCollateral]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(depositAsset),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Symbiotic ", dc.name(), " to spend ", depositAsset.symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = defaultCollateral;
            ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][address(depositAsset)][defaultCollateral] = true;
        }
        // Deposit
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: defaultCollateral,
            canSendValue: false,
            signature: "deposit(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Deposit ", depositAsset.symbol(), " into Symbiotic ", ERC20(defaultCollateral).name()
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    function _addSymbioticLeafs(ManageLeaf[] memory leafs, address[] memory defaultCollaterals) internal {
        for (uint256 i; i < defaultCollaterals.length; i++) {
            _addSymbioticApproveAndDepositLeaf(leafs, defaultCollaterals[i]);
            // Withdraw
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: defaultCollaterals[i],
                canSendValue: false,
                signature: "withdraw(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat(
                    "Withdraw ",
                    ERC20(defaultCollaterals[i]).symbol(),
                    " from Symbiotic ",
                    ERC20(defaultCollaterals[i]).name()
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }
    }

    function _addSymbioticVaultLeafs(
        ManageLeaf[] memory leafs,
        address[] memory vaults,
        ERC20[] memory assets,
        address[] memory vaultRewards
    ) internal {
        for (uint256 i; i < assets.length; i++) {
            // Approve
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(assets[i])][vaults[i]]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(assets[i]),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat(
                        "Approve Symbiotic Vault ", vm.toString(vaults[i]), " to spend ", assets[i].symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = vaults[i];
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(assets[i])][vaults[i]] = true;
            }
            // Deposit
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: vaults[i],
                canSendValue: false,
                signature: "deposit(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat(
                    "Deposit ", assets[i].symbol(), " into Symbiotic Vault ", vm.toString(vaults[i])
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            // Withdraw
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: vaults[i],
                canSendValue: false,
                signature: "withdraw(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat(
                    "Withdraw ", assets[i].symbol(), " from Symbiotic Vault ", vm.toString(vaults[i])
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Claim
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: vaults[i],
                canSendValue: false,
                signature: "claim(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Claim withdraw from Symbiotic Vault ", vm.toString(vaults[i])),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // ClaimBatch
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: vaults[i],
                canSendValue: false,
                signature: "claimBatch(address,uint256[])",
                argumentAddresses: new address[](1),
                description: string.concat("Claim batch withdraw from Symbiotic Vault ", vm.toString(vaults[i])),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Only add rewards leaf if vaultRewards array is provided and has a valid address
            if (vaultRewards.length > i && vaultRewards[i] != address(0)) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: vaultRewards[i],
                    canSendValue: false,
                    signature: "claimRewards(address,address,bytes)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Claim rewards from Symbiotic Vault ", vm.toString(vaults[i])),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            }
        }
    }

    // ========================================= ITB Karak =========================================

    function _addLeafsForITBKarakPositionManager(
        ManageLeaf[] memory leafs,
        address itbDecoderAndSanitizer,
        address positionManager,
        address _karakVault,
        address _vaultSupervisor
    ) internal {
        ERC20 underlying = ERC4626(_karakVault).asset();
        // acceptOwnership
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: positionManager,
            canSendValue: false,
            signature: "acceptOwnership()",
            argumentAddresses: new address[](0),
            description: string.concat("Accept ownership of the ITB Contract: ", vm.toString(positionManager)),
            decoderAndSanitizer: itbDecoderAndSanitizer
        });
        // Transfer all tokens to the ITB contract.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(underlying),
            canSendValue: false,
            signature: "transfer(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Transfer ", underlying.symbol(), " to ITB Contract: ", vm.toString(positionManager)
            ),
            decoderAndSanitizer: itbDecoderAndSanitizer
        });
        leafs[leafIndex].argumentAddresses[0] = positionManager;
        // Approval Karak Vault to spend all tokens.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: positionManager,
            canSendValue: false,
            signature: "approveToken(address,address,uint256)",
            argumentAddresses: new address[](2),
            description: string.concat("Approve ", ERC20(_karakVault).name(), " to spend ", underlying.symbol()),
            decoderAndSanitizer: itbDecoderAndSanitizer
        });
        leafs[leafIndex].argumentAddresses[0] = address(underlying);
        leafs[leafIndex].argumentAddresses[1] = _karakVault;
        // Withdraw all tokens
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: positionManager,
            canSendValue: false,
            signature: "withdraw(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Withdraw ", underlying.symbol(), " from ITB Contract: ", vm.toString(positionManager)
            ),
            decoderAndSanitizer: itbDecoderAndSanitizer
        });
        leafs[leafIndex].argumentAddresses[0] = address(underlying);

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: positionManager,
            canSendValue: false,
            signature: "withdrawAll(address)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Withdraw all ", underlying.symbol(), " from the ITB Contract: ", vm.toString(positionManager)
            ),
            decoderAndSanitizer: itbDecoderAndSanitizer
        });
        leafs[leafIndex].argumentAddresses[0] = address(underlying);
        // Update Vault Supervisor.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: positionManager,
            canSendValue: false,
            signature: "updateVaultSupervisor(address)",
            argumentAddresses: new address[](1),
            description: "Update the vault supervisor",
            decoderAndSanitizer: itbDecoderAndSanitizer
        });
        leafs[leafIndex].argumentAddresses[0] = _vaultSupervisor;
        // Update position config.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: positionManager,
            canSendValue: false,
            signature: "updatePositionConfig(address,address)",
            argumentAddresses: new address[](2),
            description: "Update the position config",
            decoderAndSanitizer: itbDecoderAndSanitizer
        });
        leafs[leafIndex].argumentAddresses[0] = address(underlying);
        leafs[leafIndex].argumentAddresses[1] = _karakVault;
        // Deposit
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: positionManager,
            canSendValue: false,
            signature: "deposit(uint256,uint256)",
            argumentAddresses: new address[](0),
            description: "Deposit",
            decoderAndSanitizer: itbDecoderAndSanitizer
        });
        // Start Withdrawal
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: positionManager,
            canSendValue: false,
            signature: "startWithdrawal(uint256)",
            argumentAddresses: new address[](0),
            description: "Start Withdrawal",
            decoderAndSanitizer: itbDecoderAndSanitizer
        });
        // Complete Withdrawal
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: positionManager,
            canSendValue: false,
            signature: "completeWithdrawal(uint256,uint256)",
            argumentAddresses: new address[](0),
            description: "Complete Withdrawal",
            decoderAndSanitizer: itbDecoderAndSanitizer
        });
        // Complete Next Withdrawal
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: positionManager,
            canSendValue: false,
            signature: "completeNextWithdrawal(uint256)",
            argumentAddresses: new address[](0),
            description: "Complete Next Withdrawal",
            decoderAndSanitizer: itbDecoderAndSanitizer
        });
        // Complete Next Withdrawals
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: positionManager,
            canSendValue: false,
            signature: "completeNextWithdrawals(uint256)",
            argumentAddresses: new address[](0),
            description: "Complete Next Withdrawals",
            decoderAndSanitizer: itbDecoderAndSanitizer
        });
        // Override Withdrawal Indexes
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: positionManager,
            canSendValue: false,
            signature: "overrideWithdrawalIndexes(uint256,uint256)",
            argumentAddresses: new address[](0),
            description: "Override Withdrawal Indexes",
            decoderAndSanitizer: itbDecoderAndSanitizer
        });
        // Assemble
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: positionManager,
            canSendValue: false,
            signature: "assemble(uint256)",
            argumentAddresses: new address[](0),
            description: "Assemble",
            decoderAndSanitizer: itbDecoderAndSanitizer
        });
        // Disassemble
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: positionManager,
            canSendValue: false,
            signature: "disassemble(uint256,uint256)",
            argumentAddresses: new address[](0),
            description: "Disassemble",
            decoderAndSanitizer: itbDecoderAndSanitizer
        });
        // Full Disassemble
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: positionManager,
            canSendValue: false,
            signature: "fullDisassemble(uint256)",
            argumentAddresses: new address[](0),
            description: "Full Disassemble",
            decoderAndSanitizer: itbDecoderAndSanitizer
        });
    }

    // ========================================= ITB Position Manager =========================================

    function _addLeafsForITBPositionManager(
        ManageLeaf[] memory leafs,
        address itbPositionManager,
        ERC20[] memory tokensUsed,
        string memory itbContractName
    ) internal {
        // acceptOwnership
        leafIndex++;
        leafs[leafIndex] = ManageLeaf({
            target: itbPositionManager,
            canSendValue: false,
            signature: "acceptOwnership()",
            argumentAddresses: new address[](0),
            description: string.concat("Accept ownership of the ", itbContractName, " contract"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        // removeExecutor
        leafIndex++;
        leafs[leafIndex] = ManageLeaf({
            target: itbPositionManager,
            canSendValue: false,
            signature: "removeExecutor(address)",
            argumentAddresses: new address[](0),
            description: string.concat("Remove executor from the ", itbContractName, " contract"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        for (uint256 i; i < tokensUsed.length; ++i) {
            // Transfer
            leafIndex++;
            leafs[leafIndex] = ManageLeaf({
                target: address(tokensUsed[i]),
                canSendValue: false,
                signature: "transfer(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat(
                    "Transfer ", tokensUsed[i].symbol(), " to the ", itbContractName, " contract"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = itbPositionManager;
            // Withdraw
            leafIndex++;
            leafs[leafIndex] = ManageLeaf({
                target: itbPositionManager,
                canSendValue: false,
                signature: "withdraw(address,uint256)",
                argumentAddresses: new address[](0),
                description: string.concat(
                    "Withdraw ", tokensUsed[i].symbol(), " from the ", itbContractName, " contract"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            // WithdrawAll
            leafIndex++;
            leafs[leafIndex] = ManageLeaf({
                target: itbPositionManager,
                canSendValue: false,
                signature: "withdrawAll(address)",
                argumentAddresses: new address[](0),
                description: string.concat(
                    "Withdraw all ", tokensUsed[i].symbol(), " from the ", itbContractName, " contract"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
        }
    }

    // ========================================= Fee Claiming =========================================
    function _addLeafsForFeeClaiming(
        ManageLeaf[] memory leafs,
        address accountant,
        ERC20[] memory feeAssets,
        bool addYieldClaiming
    ) internal {
        // Approvals.
        for (uint256 i; i < feeAssets.length; ++i) {
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(feeAssets[i])][getAddress(sourceChain, "accountantAddress")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(feeAssets[i]),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Accountant to spend ", feeAssets[i].symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = accountant;
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][address(feeAssets[i])][accountant] = true;
            }
        }
        // Claiming fees.
        for (uint256 i; i < feeAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: accountant,
                canSendValue: false,
                signature: "claimFees(address)",
                argumentAddresses: new address[](1),
                description: string.concat("Claim fees in ", feeAssets[i].symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(feeAssets[i]);

            if (addYieldClaiming) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: accountant,
                    canSendValue: false,
                    signature: "claimYield(address)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Claim yield in ", feeAssets[i].symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(feeAssets[i]);
            }
        }
    }

    // ========================================= Transfer =========================================

    function _addTransferLeafs(ManageLeaf[] memory leafs, ERC20 token, address to) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(token),
            canSendValue: false,
            signature: "transfer(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Transfer ", token.symbol(), " to ", vm.toString(to)),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = to;
    }

    function _addApprovalLeafs(ManageLeaf[] memory leafs, ERC20 token, address spender) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(token),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve ", vm.toString(spender), " to spend ", token.name()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = spender;
    }

    // ========================================= Rings Voter =========================================

    function _addRingsVoterLeafs(ManageLeaf[] memory leafs, address ringsVoterContract, ERC20 underlying) internal {
        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: address(underlying),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve ", vm.toString(ringsVoterContract), " to spend ", underlying.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = ringsVoterContract;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: ringsVoterContract,
            canSendValue: false,
            signature: "depositBudget(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat(
                "Deposit Budget of ", underlying.symbol(), " into ", vm.toString(ringsVoterContract)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= LayerZero =========================================

    function _addLayerZeroLeafsOldDecoder(ManageLeaf[] memory leafs, ERC20 asset, address oftAdapter, uint32 endpoint)
        internal
    {
        if (address(asset) != oftAdapter) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(asset),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve LayerZero to spend ", asset.symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = oftAdapter;
        }
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: oftAdapter,
            canSendValue: true,
            signature: "send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)",
            argumentAddresses: new address[](3),
            description: string.concat("Bridge ", asset.symbol(), " to LayerZero endpoint: ", vm.toString(endpoint)),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = address(uint160(endpoint));
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
    }

    function _addLayerZeroLeafs(ManageLeaf[] memory leafs, ERC20 asset, address oftAdapter, uint32 endpoint, bytes32 to)
        internal
    {
        if (address(asset) != oftAdapter) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(asset),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve LayerZero to spend ", asset.symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = oftAdapter;
        }
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: oftAdapter,
            canSendValue: true,
            signature: "send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)",
            argumentAddresses: new address[](4),
            description: string.concat("Bridge ", asset.symbol(), " to LayerZero endpoint: ", vm.toString(endpoint)),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = address(uint160(endpoint));
        // forge-lint: disable-next-line(unsafe-typecast)
        leafs[leafIndex].argumentAddresses[1] = address(bytes20(bytes16(to)));
        // forge-lint: disable-next-line(unsafe-typecast)
        leafs[leafIndex].argumentAddresses[2] = address(bytes20(bytes16(to << 128)));
        leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
    }

    function _addLayerZeroMultiHopLeafs(
        ManageLeaf[] memory leafs,
        ERC20 asset,
        address oftAdapter,
        uint32 firstHopEndpoint,
        bytes32 firstHopTo,
        uint32 finalDestEndpoint,
        bytes32 finalDestTo
    ) internal {
        if (address(asset) != oftAdapter) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(asset),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve LayerZero to spend ", asset.symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = oftAdapter;
        }
        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: oftAdapter,
            canSendValue: true,
            signature: "send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)",
            argumentAddresses: new address[](6),
            description: string.concat(
                "Bridge ", asset.symbol(), " to LayerZero MultiHop endpoint: ", vm.toString(firstHopEndpoint)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] =
            address(uint160((uint256(firstHopEndpoint) << 32) | uint256(finalDestEndpoint)));
        // forge-lint: disable-next-line(unsafe-typecast)
        leafs[leafIndex].argumentAddresses[1] = address(bytes20(bytes16(firstHopTo)));
        // forge-lint: disable-next-line(unsafe-typecast)
        leafs[leafIndex].argumentAddresses[2] = address(bytes20(bytes16(firstHopTo << 128)));
        // forge-lint: disable-next-line(unsafe-typecast)
        leafs[leafIndex].argumentAddresses[3] = address(bytes20(bytes16(finalDestTo)));
        // forge-lint: disable-next-line(unsafe-typecast)
        leafs[leafIndex].argumentAddresses[4] = address(bytes20(bytes16(finalDestTo << 128)));
        leafs[leafIndex].argumentAddresses[5] = getAddress(sourceChain, "boringVault");
    }

    function _addLayerZeroLeafNative(ManageLeaf[] memory leafs, address oftAdapter, uint32 endpoint, bytes32 to)
        internal
    {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: oftAdapter,
            canSendValue: true,
            signature: "send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)",
            argumentAddresses: new address[](4),
            description: string.concat("Bridge Native Asset to LayerZero endpoint: ", vm.toString(endpoint)),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = address(uint160(endpoint));
        // forge-lint: disable-next-line(unsafe-typecast)
        leafs[leafIndex].argumentAddresses[1] = address(bytes20(bytes16(to)));
        // forge-lint: disable-next-line(unsafe-typecast)
        leafs[leafIndex].argumentAddresses[2] = address(bytes20(bytes16(to << 128)));
        leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Compound V2 =========================================
    // NOTE: other forks may have different reward claiming functions
    function _addCompoundV2Leafs(
        ManageLeaf[] memory leafs,
        ERC20[] memory collateralAssets,
        address[] memory cTokens,
        address unitroller
    ) internal {
        require(collateralAssets.length == cTokens.length, "Arrays must be of equal length");

        for (uint256 i; i < collateralAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: unitroller,
                canSendValue: false,
                signature: "enterMarkets(address[])",
                argumentAddresses: new address[](1),
                description: string.concat("Enter Compound V2 market ", ERC20(cTokens[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = cTokens[i];

            if (address(collateralAssets[i]) != 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(collateralAssets[i]),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Compound to spend ", collateralAssets[i].symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = cTokens[i];

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: cTokens[i],
                    canSendValue: false,
                    signature: "mint(uint256)",
                    argumentAddresses: new address[](0),
                    description: string.concat("Mint ", ERC20(cTokens[i]).symbol(), " on Compound"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: cTokens[i],
                    canSendValue: false,
                    signature: "repayBorrow(uint256)",
                    argumentAddresses: new address[](0),
                    description: string.concat("Repay ", collateralAssets[i].symbol(), " on Compound"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
            } else {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: cTokens[i],
                    canSendValue: true,
                    signature: "mint()",
                    argumentAddresses: new address[](0),
                    description: string.concat("Mint ", ERC20(cTokens[i]).symbol(), " using Native Asset on Compound"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: cTokens[i],
                    canSendValue: true,
                    signature: "repayBorrow()",
                    argumentAddresses: new address[](0),
                    description: string.concat("Repay Native Asset on Compound"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
            }

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: cTokens[i],
                canSendValue: false,
                signature: "borrow(uint256)",
                argumentAddresses: new address[](0),
                description: string.concat("Borrow from Compound, ", ERC20(cTokens[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: cTokens[i],
                canSendValue: false,
                signature: "redeem(uint256)",
                argumentAddresses: new address[](0),
                description: string.concat("Redeem ", ERC20(cTokens[i]).symbol(), " on Compound"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: cTokens[i],
                canSendValue: false,
                signature: "redeemUnderlying(uint256)",
                argumentAddresses: new address[](0),
                description: string.concat("Redeem underlying from Compound ", ERC20(cTokens[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: unitroller,
                canSendValue: false,
                signature: "claimReward(uint8,address)",
                argumentAddresses: new address[](1),
                description: string.concat("Claim rewards from Compound fork"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: unitroller,
                canSendValue: false,
                signature: "exitMarket(address)",
                argumentAddresses: new address[](1),
                description: string.concat("Exit Market", ERC20(cTokens[i]).symbol(), " on Compound"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = cTokens[i];
        }
    }

    // ========================================= Compound V3 =========================================

    function _addCompoundV3Leafs(
        ManageLeaf[] memory leafs,
        ERC20[] memory collateralAssets,
        address cometAddress,
        address cometRewards
    ) internal {
        IComet comet = IComet(cometAddress);
        ERC20 baseToken = ERC20(comet.baseToken());
        // Handle base token
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(baseToken),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Comet to spend ", baseToken.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = cometAddress;

        // Supply base token
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: cometAddress,
            canSendValue: false,
            signature: "supply(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Supply ", baseToken.symbol(), " to Comet"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = address(baseToken);

        // Withdraw base token
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: cometAddress,
            canSendValue: false,
            signature: "withdraw(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Withdraw ", baseToken.symbol(), " from Comet"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = address(baseToken);

        // Handle collateral assets
        for (uint256 i; i < collateralAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(collateralAssets[i]),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Comet to spend ", collateralAssets[i].symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = cometAddress;

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: cometAddress,
                canSendValue: false,
                signature: "supply(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Supply ", collateralAssets[i].symbol(), " to Comet"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(collateralAssets[i]);

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: cometAddress,
                canSendValue: false,
                signature: "withdraw(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Withdraw ", collateralAssets[i].symbol(), " from Comet"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(collateralAssets[i]);
        }

        // Claim rewards.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: cometRewards,
            canSendValue: false,
            signature: "claim(address,address,bool)",
            argumentAddresses: new address[](2),
            description: "Claim rewards from Comet",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = cometAddress;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Merkl =========================================

    function _addMerklLeafs(ManageLeaf[] memory leafs, address merklDistributor, address operator) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: merklDistributor,
            canSendValue: false,
            signature: "toggleOperator(address,address)",
            argumentAddresses: new address[](2),
            description: string.concat("Allow ", vm.toString(operator), " to claim merkl rewards"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = operator;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: merklDistributor,
            canSendValue: false,
            signature: "claim(address[],address[],uint256[],bytes32[][])",
            argumentAddresses: new address[](1),
            description: string.concat("Claim merkl rewards"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // only ability to claim, not other merkl functions
    function _addMerklClaimLeaf(ManageLeaf[] memory leafs, address merklDistributor) internal {
        leafIndex++;
        leafs[leafIndex] = ManageLeaf({
            target: merklDistributor,
            canSendValue: false,
            signature: "claim(address[],address[],uint256[],bytes32[][])",
            argumentAddresses: new address[](1),
            description: string.concat("Claim merkl rewards"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= VELODROME =========================================
    function _addVelodromeV3Leafs(
        ManageLeaf[] memory leafs,
        address[] memory token0,
        address[] memory token1,
        address nonfungiblePositionManager,
        address[] memory gauges
    ) internal {
        require(token0.length == token1.length && token0.length == gauges.length, "Arrays must be of equal length");
        for (uint256 i; i < token0.length; ++i) {
            (token0[i], token1[i]) = token0[i] < token1[i] ? (token0[i], token1[i]) : (token1[i], token0[i]);
            // Approvals
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][nonfungiblePositionManager]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token0[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat(
                        "Approve Velodrome NonFungible Position Manager to spend ", ERC20(token0[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = nonfungiblePositionManager;
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0[i]][nonfungiblePositionManager] = true;
            }
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1[i]][nonfungiblePositionManager]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token1[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat(
                        "Approve Velodrome NonFungible Position Manager to spend ", ERC20(token1[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = nonfungiblePositionManager;
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1[i]][nonfungiblePositionManager] = true;
            }

            // Minting
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: nonfungiblePositionManager,
                canSendValue: false,
                signature: "mint((address,address,int24,int24,int24,uint256,uint256,uint256,uint256,address,uint256,uint160))",
                argumentAddresses: new address[](3),
                description: string.concat(
                    "Mint VelodromeV3 ", ERC20(token0[i]).symbol(), " ", ERC20(token1[i]).symbol(), " position"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            // Increase liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: nonfungiblePositionManager,
                canSendValue: false,
                signature: "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
                argumentAddresses: new address[](4),
                description: string.concat(
                    "Add liquidity to VelodromeV3 ",
                    ERC20(token0[i]).symbol(),
                    " ",
                    ERC20(token1[i]).symbol(),
                    " position"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(0);
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = token1[i];
            leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");

            // Approve gauge to spend NFT.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: nonfungiblePositionManager,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: "Approve gauge to spend VelodromeV3 position",
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = gauges[i];
        }

        // Decrease liquidity
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: nonfungiblePositionManager,
            canSendValue: false,
            signature: "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            argumentAddresses: new address[](1),
            description: "Remove liquidity from VelodromeV3 position",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: nonfungiblePositionManager,
            canSendValue: false,
            signature: "collect((uint256,address,uint128,uint128))",
            argumentAddresses: new address[](2),
            description: "Collect fees from VelodromeV3 position",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        // burn
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: nonfungiblePositionManager,
            canSendValue: false,
            signature: "burn(uint256)",
            argumentAddresses: new address[](0),
            description: "Burn VelodromeV3 position",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        for (uint256 i; i < gauges.length; ++i) {
            // Deposit into Gauge
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: gauges[i],
                canSendValue: false,
                signature: "deposit(uint256)",
                argumentAddresses: new address[](0),
                description: string.concat("Deposit into VelodromeV3 gauge ", vm.toString(gauges[i])),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            // Withdraw from Gauge
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: gauges[i],
                canSendValue: false,
                signature: "withdraw(uint256)",
                argumentAddresses: new address[](0),
                description: string.concat("Withdraw from VelodromeV3 gauge ", vm.toString(gauges[i])),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            // Get reward
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: gauges[i],
                canSendValue: false,
                signature: "getReward(uint256)",
                argumentAddresses: new address[](0),
                description: string.concat("Get reward from VelodromeV3 gauge ", vm.toString(gauges[i])),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: gauges[i],
                canSendValue: false,
                signature: "getReward(address)",
                argumentAddresses: new address[](1),
                description: string.concat("Get reward from VelodromeV3 gauge ", vm.toString(gauges[i])),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }
    }

    function _addVelodromeV2Leafs(
        ManageLeaf[] memory leafs,
        address[] memory token0,
        address[] memory token1,
        address router,
        address[] memory gauges
    ) internal {
        require(token0.length == token1.length && token0.length == gauges.length, "Arrays must be of equal length");

        for (uint256 i; i < token0.length; ++i) {
            (token0[i], token1[i]) = token0[i] < token1[i] ? (token0[i], token1[i]) : (token1[i], token0[i]);

            if (!ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][router]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token0[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Velodrome Router to spend ", ERC20(token0[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = router;
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][router] = true;
            }
            if (!ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][router]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token1[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Velodrome Router to spend ", ERC20(token1[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = router;
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][router] = true;
            }

            // Add liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: router,
                canSendValue: false,
                signature: "addLiquidity(address,address,bool,uint256,uint256,uint256,uint256,address,uint256)",
                argumentAddresses: new address[](3),
                description: string.concat(
                    "Add liquidity to VelodromeV2 ", ERC20(token0[i]).symbol(), "/", ERC20(token1[i]).symbol()
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // Remove liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: router,
                canSendValue: false,
                signature: "removeLiquidity(address,address,bool,uint256,uint256,uint256,address,uint256)",
                argumentAddresses: new address[](3),
                description: string.concat(
                    "Remove liquidity from VelodromeV2 ", ERC20(token0[i]).symbol(), "/", ERC20(token1[i]).symbol()
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        }

        for (uint256 i; i < gauges.length; ++i) {
            // Approve gauge to spend staking token.
            address stakingToken = VelodromV2Gauge(gauges[i]).stakingToken();
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: stakingToken,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve VelodromeV2 Gauge to spend ", ERC20(stakingToken).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = gauges[i];

            // Approve router to spend staking token.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: stakingToken,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Velodrome Router to spend ", ERC20(stakingToken).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = router;

            // Deposit into Gauge
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: gauges[i],
                canSendValue: false,
                signature: "deposit(uint256)",
                argumentAddresses: new address[](0),
                description: string.concat("Deposit into VelodromeV2 gauge ", vm.toString(gauges[i])),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            // Withdraw from Gauge
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: gauges[i],
                canSendValue: false,
                signature: "withdraw(uint256)",
                argumentAddresses: new address[](0),
                description: string.concat("Withdraw from VelodromeV2 gauge ", vm.toString(gauges[i])),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            // Get reward
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: gauges[i],
                canSendValue: false,
                signature: "getReward(address)",
                argumentAddresses: new address[](1),
                description: string.concat("Get reward from VelodromeV2 gauge ", vm.toString(gauges[i])),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }
    }

    // ========================================= Karak =========================================

    function _addKarakLeafs(ManageLeaf[] memory leafs, address vaultSupervisor, address vault) internal {
        address delegationSupervisor = VaultSupervisor(vaultSupervisor).delegationSupervisor();
        ERC20 underlying = ERC4626(vault).asset();

        // Add leaf to approve karak vault to spend underlying.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(underlying),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Karak Vault to spend ", underlying.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = vault;

        // Approve vault supervisor to spend vault shares
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vault,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Vault Supervisor to spend ", ERC4626(vault).symbol(), " shares"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = vaultSupervisor;

        // Add deposit leafs
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vaultSupervisor,
            canSendValue: false,
            signature: "deposit(address,uint256,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Deposit ", underlying.symbol(), " into ", ERC4626(vault).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = vault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vaultSupervisor,
            canSendValue: false,
            signature: "gimmieShares(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Gimmie shares into ", ERC4626(vault).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = vault;

        // Add withdraw leafs
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vaultSupervisor,
            canSendValue: false,
            signature: "returnShares(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Return shares from ", ERC4626(vault).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = vault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: delegationSupervisor,
            canSendValue: false,
            signature: "startWithdraw((address[],uint256[],address)[])",
            argumentAddresses: new address[](2),
            description: string.concat("Start withdraw of ", underlying.symbol(), " from ", ERC4626(vault).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = vault;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: delegationSupervisor,
            canSendValue: false,
            signature: "finishWithdraw((address,address,uint256,uint256,(address[],uint256[],address))[])",
            argumentAddresses: new address[](4),
            description: string.concat("Finish withdraw of ", underlying.symbol(), " from ", ERC4626(vault).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = address(0); // Delegation not implemented yet.
        leafs[leafIndex].argumentAddresses[2] = vault;
        leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Reclamation =========================================

    function _addReclamationLeafs(ManageLeaf[] memory leafs, address target, address reclamationDecoder) internal {
        /// @notice These leafs are generic, in that they are allowing any execturo address to be removed, and any asset to be withdrawn
        /// BACK to the boring vault.
        // Add in generic `removeExecutor(address executor)` leaf.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: target,
            canSendValue: false,
            signature: "removeExecutor(address)",
            argumentAddresses: new address[](0),
            description: string.concat("Remove any executor from ", vm.toString(target)),
            decoderAndSanitizer: reclamationDecoder
        });
        // Add in generic `withdraw(address asset, uint256 amount)` and generic `withdrawAll(address asset)` leafs.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: target,
            canSendValue: false,
            signature: "withdraw(address,uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Withdraw any asset from ", vm.toString(target)),
            decoderAndSanitizer: reclamationDecoder
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: target,
            canSendValue: false,
            signature: "withdrawAll(address)",
            argumentAddresses: new address[](0),
            description: string.concat("Withdraw all of any asset from ", vm.toString(target)),
            decoderAndSanitizer: reclamationDecoder
        });
    }

    // ========================================= Puppet =========================================

    function _createPuppetLeafs(ManageLeaf[] memory leafs, address puppet)
        internal
        pure
        returns (ManageLeaf[] memory puppetLeafs)
    {
        puppetLeafs = new ManageLeaf[](leafs.length);

        // Iterate through every leaf, and
        // 1) Take the existing target and append it to the end of the argumentAddresses array.
        // 2) Change the target to the puppet contract.

        for (uint256 i; i < leafs.length; ++i) {
            puppetLeafs[i].argumentAddresses = new address[](leafs[i].argumentAddresses.length + 1);
            // Copy over argumentAddresses.
            for (uint256 j; j < leafs[i].argumentAddresses.length; ++j) {
                puppetLeafs[i].argumentAddresses[j] = leafs[i].argumentAddresses[j];
            }
            // Append the target to the end of the argumentAddresses array.
            puppetLeafs[i].argumentAddresses[leafs[i].argumentAddresses.length] = leafs[i].target;
            // Change the target to the puppet contract.
            puppetLeafs[i].target = puppet;
            // Copy over remaning values.
            puppetLeafs[i].canSendValue = leafs[i].canSendValue;
            puppetLeafs[i].signature = leafs[i].signature;
            puppetLeafs[i].description = leafs[i].description;
            puppetLeafs[i].decoderAndSanitizer = leafs[i].decoderAndSanitizer;
        }
    }

    // ========================================= Drone =========================================

    function _addLeafsForDroneTransfers(ManageLeaf[] memory leafs, address drone, ERC20[] memory assets) internal {
        for (uint256 i; i < assets.length; ++i) {
            // Add leaf for BoringVault to transfer to drone.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(assets[i]),
                canSendValue: false,
                signature: "transfer(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Transfer ", assets[i].symbol(), " to drone: ", vm.toString(drone)),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = drone;

            // Add leaf for drone to transfer to BoringVault.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: drone,
                canSendValue: false,
                signature: "transfer(address,uint256)",
                argumentAddresses: new address[](2),
                description: string.concat("Transfer ", assets[i].symbol(), " to BoringVault"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = address(assets[i]);
        }

        // Add leaf so boringVault can withdraw native from drone.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: drone,
            canSendValue: false,
            signature: "withdrawNativeFromDrone()",
            argumentAddresses: new address[](0),
            description: string.concat("Withdraw native from drone: ", vm.toString(drone)),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    function _createDroneLeafs(ManageLeaf[] memory leafs, address drone, uint256 startIndex, uint256 endIndex)
        internal
    {
        address boringVault = getAddress(sourceChain, "boringVault");
        // Update boringVault address to be drone, so leafs work as expected.
        // setAddress(true, sourceChain, "boringVault", drone);

        // Iterate through every leaf, and
        // 1) Take the existing target and append it to the end of the argumentAddresses array.
        // 2) Change the target to the drone contract.

        for (uint256 i = startIndex; i < endIndex; ++i) {
            uint256 newLength = leafs[i].argumentAddresses.length + 1;
            address[] memory temp = new address[](newLength);
            // Copy argumentAddresses into temporary array.
            for (uint256 j; j < leafs[i].argumentAddresses.length; ++j) {
                if (leafs[i].argumentAddresses[j] == address(boringVault)) {
                    temp[j] = drone;
                } else {
                    temp[j] = leafs[i].argumentAddresses[j];
                }
            }

            // Expand argumentAddresses array by 1.
            leafs[i].argumentAddresses = new address[](newLength);

            // Copy over argumentAddresses into leaf address arguments array.
            for (uint256 j; j < leafs[i].argumentAddresses.length; ++j) {
                leafs[i].argumentAddresses[j] = temp[j];
            }

            // Append the target to the end of the argumentAddresses array.
            leafs[i].argumentAddresses[newLength - 1] = leafs[i].target;

            // Change the target to the puppet contract.
            leafs[i].target = drone;

            // Update Description.
            leafs[i].description = string.concat("(Drone: ", vm.toString(drone), ") ", leafs[i].description);
        }

        // Change boringVault address back to original.
        setAddress(true, sourceChain, "boringVault", boringVault);
    }

    // ========================================= Term Finance =========================================
    // TODO need to use this in the test suite.
    function _addTermFinanceLockOfferLeafs(
        ManageLeaf[] memory leafs,
        ERC20[] memory purchaseTokens,
        address[] memory termAuctionOfferLockerAddresses,
        address[] memory termRepoLockers
    ) internal {
        for (uint256 i; i < purchaseTokens.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(purchaseTokens[i]),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Term Repo Locker to spend ", purchaseTokens[i].symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = termRepoLockers[i];
            ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][address(purchaseTokens[i])][termRepoLockers[i]] = true;
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: termAuctionOfferLockerAddresses[i],
                canSendValue: false,
                signature: "lockOffers((bytes32,address,bytes32,uint256,address)[])",
                argumentAddresses: new address[](2),
                description: string.concat(
                    "Submit offer submission to offer locker ", vm.toString(termAuctionOfferLockerAddresses[i])
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = address(purchaseTokens[i]);
        }
    }

    // TODO need to use this in the test suite.
    function _addTermFinanceUnlockOfferLeafs(
        ManageLeaf[] memory leafs,
        address[] memory termAuctionOfferLockerAddresses
    ) internal {
        for (uint256 i; i < termAuctionOfferLockerAddresses.length; i++) {
            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf({
                target: termAuctionOfferLockerAddresses[i],
                canSendValue: false,
                signature: "unlockOffers(bytes32[])",
                argumentAddresses: new address[](0),
                description: string.concat(
                    "Unlock existing offer from offer locker ", vm.toString(termAuctionOfferLockerAddresses[i])
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
        }
    }

    // TODO need to use this in the test suite.
    function _addTermFinanceRevealOfferLeafs(
        ManageLeaf[] memory leafs,
        address[] memory termAuctionOfferLockerAddresses
    ) internal {
        for (uint256 i; i < termAuctionOfferLockerAddresses.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: termAuctionOfferLockerAddresses[i],
                canSendValue: false,
                signature: "revealOffers(bytes32[],uint256[],uint256[])",
                argumentAddresses: new address[](0),
                description: string.concat(
                    "Unlock existing offer from offer locker ", vm.toString(termAuctionOfferLockerAddresses[i])
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
        }
    }

    // TODO need to use this in the test suite.
    function _addTermFinanceRedeemTermRepoTokensLeafs(ManageLeaf[] memory leafs, address[] memory termRepoServicers)
        internal
    {
        for (uint256 i; i < termRepoServicers.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: termRepoServicers[i],
                canSendValue: false,
                signature: "redeemTermRepoTokens(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Redeem TermRepo Tokens from servicer ", vm.toString(termRepoServicers[i])),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }
    }
    // ========================================= Euler Finance =========================================

    function _addEulerDepositLeafs(
        ManageLeaf[] memory leafs,
        ERC4626[] memory depositVaults,
        address[] memory subaccounts
    ) internal {
        for (uint256 i = 0; i < subaccounts.length; i++) {
            for (uint256 j = 0; j < depositVaults.length; j++) {
                //approval leaf is handled by ERC4626, including for ERC20 deposit asset
                _addERC4626SubaccountLeafs(leafs, depositVaults[j], subaccounts[i]);

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "ethereumVaultConnector"),
                    canSendValue: false,
                    signature: "enableCollateral(address,address)",
                    argumentAddresses: new address[](2),
                    description: string.concat(
                        "Enable Collateral of ",
                        ERC20(depositVaults[j].asset()).name(),
                        " on Euler for account #",
                        vm.toString(i),
                        " ",
                        vm.toString(subaccounts[i])
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = subaccounts[i];
                leafs[leafIndex].argumentAddresses[1] = address(depositVaults[j]);

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "ethereumVaultConnector"),
                    canSendValue: false,
                    signature: "disableCollateral(address,address)",
                    argumentAddresses: new address[](2),
                    description: string.concat(
                        "Disable Collateral of ",
                        ERC20(depositVaults[j].asset()).name(),
                        " on Euler for account #",
                        vm.toString(i),
                        " : ",
                        vm.toString(subaccounts[i])
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = subaccounts[i];
                leafs[leafIndex].argumentAddresses[1] = address(depositVaults[j]);

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "ethereumVaultConnector"),
                    canSendValue: false,
                    signature: "call(address,address,uint256,bytes)",
                    argumentAddresses: new address[](5),
                    description: string.concat(
                        "Call Withdraw on ",
                        depositVaults[j].name(),
                        " via EVC on behalf of ",
                        vm.toString(subaccounts[i])
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(depositVaults[j]);
                leafs[leafIndex].argumentAddresses[1] = subaccounts[i];
                leafs[leafIndex].argumentAddresses[2] = address(0xb460af94); //withdraw
                leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault"); //receiver must be vault
                leafs[leafIndex].argumentAddresses[4] = subaccounts[i]; //owner must be subaccount

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "ethereumVaultConnector"),
                    canSendValue: false,
                    signature: "call(address,address,uint256,bytes)",
                    argumentAddresses: new address[](5),
                    description: string.concat(
                        "Call Redeem on ",
                        depositVaults[j].name(),
                        " via EVC on behalf of ",
                        vm.toString(subaccounts[i])
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(depositVaults[j]);
                leafs[leafIndex].argumentAddresses[1] = subaccounts[i];
                leafs[leafIndex].argumentAddresses[2] = address(0xba087652); //redeem
                leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault"); //receiver must be vault
                leafs[leafIndex].argumentAddresses[4] = subaccounts[i]; //owner must be subaccount
            }
        }
    }

    function _addEulerBorrowLeafs(
        ManageLeaf[] memory leafs,
        ERC4626[] memory borrowVaults,
        address[] memory subaccounts
    ) internal {
        for (uint256 i = 0; i < subaccounts.length; i++) {
            for (uint256 j = 0; j < borrowVaults.length; j++) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(borrowVaults[j].asset()),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve ", ERC20(borrowVaults[j].asset()).name(), " to be repaid."),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(borrowVaults[j]);

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "ethereumVaultConnector"),
                    canSendValue: false,
                    signature: "enableController(address,address)",
                    argumentAddresses: new address[](2),
                    description: string.concat(
                        "Enable ",
                        borrowVaults[j].name(),
                        " as controller for subaccount #",
                        vm.toString(i),
                        " : ",
                        vm.toString(subaccounts[i])
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = subaccounts[i];
                leafs[leafIndex].argumentAddresses[1] = address(borrowVaults[j]);

                unchecked {
                    leafIndex++;
                }

                leafs[leafIndex] = ManageLeaf({
                    target: address(borrowVaults[j]),
                    canSendValue: false,
                    signature: "borrow(uint256,address)",
                    argumentAddresses: new address[](1),
                    description: string.concat(
                        "Borrow ",
                        ERC20(borrowVaults[j].asset()).name(),
                        " from ",
                        borrowVaults[j].name(),
                        " for account #",
                        vm.toString(i)
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = subaccounts[i];

                unchecked {
                    leafIndex++;
                }

                leafs[leafIndex] = ManageLeaf({
                    target: address(borrowVaults[j]),
                    canSendValue: false,
                    signature: "repay(uint256,address)",
                    argumentAddresses: new address[](1),
                    description: string.concat(
                        "Repay ",
                        ERC20(borrowVaults[j].asset()).name(),
                        " to ",
                        borrowVaults[j].name(),
                        " for account #",
                        vm.toString(i)
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = subaccounts[i];

                unchecked {
                    leafIndex++;
                }

                leafs[leafIndex] = ManageLeaf({
                    target: address(borrowVaults[j]),
                    canSendValue: false,
                    signature: "repayWithShares(uint256,address)",
                    argumentAddresses: new address[](1),
                    description: string.concat(
                        "Repay ",
                        ERC20(borrowVaults[j].asset()).name(),
                        " with shares ",
                        borrowVaults[j].name(),
                        " for account #",
                        vm.toString(i)
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = subaccounts[i];

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: address(borrowVaults[j]),
                    canSendValue: false,
                    signature: "disableController()",
                    argumentAddresses: new address[](0),
                    description: string.concat(
                        "Disable ", borrowVaults[j].name(), " as controller for account #", vm.toString(i)
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                //leafs[leafIndex].argumentAddresses[0] = subaccounts[i];

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "ethereumVaultConnector"),
                    canSendValue: false,
                    signature: "call(address,address,uint256,bytes)",
                    argumentAddresses: new address[](4),
                    description: string.concat(
                        "Call Borrow on ", borrowVaults[j].name(), " via EVC on behalf of ", vm.toString(subaccounts[i])
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(borrowVaults[j]);
                leafs[leafIndex].argumentAddresses[1] = subaccounts[i];
                leafs[leafIndex].argumentAddresses[2] = address(0x4b3fd148); //borrow
                leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
            }
        }
    }

    // ========================================= Royco =========================================

    function _addRoycoWeirollLeafs(
        ManageLeaf[] memory leafs,
        ERC20 asset,
        bytes32 marketHash,
        address frontendFeeRecipient
    ) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(asset),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Recipe Market Hub to spend ", asset.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "recipeMarketHub");

        unchecked {
            leafIndex++;
        }

        // forge-lint: disable-next-line(unsafe-typecast)
        address marketHash0 = address(bytes20(bytes16(marketHash)));
        // forge-lint: disable-next-line(unsafe-typecast)
        address marketHash1 = address(bytes20(bytes16(marketHash << 128)));

        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "recipeMarketHub"),
            canSendValue: false,
            signature: "fillIPOffers(bytes32[],uint256[],address,address)",
            argumentAddresses: new address[](4),
            description: string.concat("Fill IP Offer using market hash"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = marketHash0;
        leafs[leafIndex].argumentAddresses[1] = marketHash1;
        leafs[leafIndex].argumentAddresses[2] = address(0); //pull funds from boringVault
        leafs[leafIndex].argumentAddresses[3] = frontendFeeRecipient;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "recipeMarketHub"),
            canSendValue: false,
            signature: "executeWithdrawalScript(address)",
            argumentAddresses: new address[](1),
            description: string.concat("Execute the weiroll withdraw script and retrieve funds from recipe market"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "recipeMarketHub"),
            canSendValue: false,
            signature: "forfeit(address,bool)",
            argumentAddresses: new address[](1),
            description: string.concat("Forfeit rewards and unlock wallet early"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "recipeMarketHub"),
            canSendValue: false,
            signature: "claim(address,address)",
            argumentAddresses: new address[](2),
            description: string.concat("Claim incentive rewards"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        //TODO add merkleWithdraw leaves once testing is available
    }

    function _addRoyco4626VaultLeafs(ManageLeaf[] memory leafs, ERC4626 vault) internal {
        _addERC4626Leafs(leafs, vault);

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(vault),
            canSendValue: false,
            signature: "claim(address)",
            argumentAddresses: new address[](1),
            description: string.concat("Claim incentive rewards"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(vault),
            canSendValue: false,
            signature: "claimFees(address)",
            argumentAddresses: new address[](1),
            description: string.concat("Claim vault fees"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    function _addYuzuLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "USDT0"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve yzUSD to spend USDT0"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "yzUSD");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "yzUSD"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve syzUSD to spend yzUSD"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "syzUSD");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "yzUSD"),
            canSendValue: false,
            signature: "deposit(uint256,address)",
            argumentAddresses: new address[](1),
            description: string.concat("mint yzUSD with USDT0"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "yzUSD"),
            canSendValue: false,
            signature: "createRedeemOrder(uint256,address,address)",
            argumentAddresses: new address[](2),
            description: string.concat("request redemption of yzUSD for USDT0"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "yzUSD"),
            canSendValue: false,
            signature: "cancelRedeemOrder(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("cancel redemption of yzUSD for USDT0"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "yzUSD"),
            canSendValue: false,
            signature: "finalizeRedeemOrder(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("finalize redemption of yzUSD for USDT0"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "syzUSD"),
            canSendValue: false,
            signature: "deposit(uint256,address)",
            argumentAddresses: new address[](1),
            description: string.concat("stake yzUSD for syzUSD"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "syzUSD"),
            canSendValue: false,
            signature: "initiateRedeem(uint256,address,address)",
            argumentAddresses: new address[](2),
            description: string.concat("initiate unstaking syzUSD for yzUSD"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "syzUSD"),
            canSendValue: false,
            signature: "finalizeRedeem(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("finalize a ready syzUSD unstaking request"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    function _addRoycoRecipeAPOfferLeafs(
        ManageLeaf[] memory leafs,
        address baseAsset,
        bytes32 targetMarketHash,
        address fundingVault,
        address[] memory incentivesRequested
    ) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: baseAsset,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Approve RecipeMarketHub to spend ", ERC20(baseAsset).symbol(), " (spent when offer is filled)"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "recipeMarketHub");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "recipeMarketHub"),
            canSendValue: false,
            signature: "createAPOffer(bytes32,address,uint256,uint256,address[],uint256[])",
            argumentAddresses: new address[](3 + incentivesRequested.length),
            description: string.concat("Create AP Offer for Recipe Market"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        // forge-lint: disable-next-line(unsafe-typecast)
        leafs[leafIndex].argumentAddresses[0] = address(bytes20(bytes16(targetMarketHash)));
        // forge-lint: disable-next-line(unsafe-typecast)
        leafs[leafIndex].argumentAddresses[1] = address(bytes20(bytes16(targetMarketHash << 128)));
        leafs[leafIndex].argumentAddresses[2] = fundingVault;
        for (uint256 i = 0; i < incentivesRequested.length; i++) {
            leafs[leafIndex].argumentAddresses[3 + i] = incentivesRequested[i];
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "recipeMarketHub"),
            canSendValue: false,
            signature: "cancelAPOffer((uint256,bytes32,address,address,uint256,uint256,address[],uint256[]))",
            argumentAddresses: new address[](4 + incentivesRequested.length),
            description: string.concat("Cancel AP Offer for Recipe Market"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        // forge-lint: disable-next-line(unsafe-typecast)
        leafs[leafIndex].argumentAddresses[0] = address(bytes20(bytes16(targetMarketHash)));
        // forge-lint: disable-next-line(unsafe-typecast)
        leafs[leafIndex].argumentAddresses[1] = address(bytes20(bytes16(targetMarketHash << 128)));
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault"); // AP address is caller of create, boringVault
        leafs[leafIndex].argumentAddresses[3] = fundingVault;
        for (uint256 i = 0; i < incentivesRequested.length; i++) {
            leafs[leafIndex].argumentAddresses[4 + i] = incentivesRequested[i];
        }
    }

    function _addRoycoVaultMarketLeafs(
        ManageLeaf[] memory leafs,
        address baseAsset,
        address targetVault,
        address fundingVault,
        address[] memory incentivesRequested
    ) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: baseAsset,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Wrapped Vault to spend ", ERC20(baseAsset).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = targetVault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: targetVault,
            canSendValue: false,
            signature: "safeDeposit(uint256,address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Deposit into WrappedVault using safeDeposit"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: baseAsset,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Approve VaultMarketHub to spend ", ERC20(baseAsset).symbol(), " (spent when offer is filled)"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "vaultMarketHub");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "vaultMarketHub"),
            canSendValue: false,
            signature: "createAPOffer(address,address,uint256,uint256,address[],uint256[])",
            argumentAddresses: new address[](2 + incentivesRequested.length),
            description: string.concat("Create AP Offer for Vault Market"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = targetVault;
        leafs[leafIndex].argumentAddresses[1] = fundingVault;
        for (uint256 i = 0; i < incentivesRequested.length; i++) {
            leafs[leafIndex].argumentAddresses[2 + i] = incentivesRequested[i];
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "vaultMarketHub"),
            canSendValue: false,
            signature: "cancelOffer((uint256,address,address,address,uint256,address[],uint256[]))",
            argumentAddresses: new address[](3 + incentivesRequested.length),
            description: string.concat("Create AP Offer for Vault Market"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = targetVault;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[2] = fundingVault;
        for (uint256 i = 0; i < incentivesRequested.length; i++) {
            leafs[leafIndex].argumentAddresses[3 + i] = incentivesRequested[i];
        }
    }

    function _addRoycoWithdrawMerkleDepositLeafs(ManageLeaf[] memory leafs, address[] memory weirollWallets) internal {
        for (uint256 i; i < weirollWallets.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "roycoDepositExecutor"),
                canSendValue: false,
                signature: "withdrawMerkleDeposit(address,uint256,uint256,bytes32[])",
                argumentAddresses: new address[](1),
                description: string.concat("Withdraw Weiroll deposit from ", vm.toString(weirollWallets[i])),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = weirollWallets[i];
        }
    }

    // ========================================= Resolv =========================================

    function _addAllResolvLeafs(ManageLeaf[] memory leafs, ERC20[] memory assets) internal {
        _addResolvUsrExternalRequestsManagerLeafs(leafs, assets);
        _addResolvStUSRLeafs(leafs);
        _addResolvWstUSRLeafs(leafs);
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "wstUSR")));
    }

    function _addResolvUsrExternalRequestsManagerLeafs(ManageLeaf[] memory leafs, ERC20[] memory assets) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "USR"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve USR to be spent by USR External Requests Manager"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "UsrExternalRequestsManager");

        for (uint256 i = 0; i < assets.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(assets[i]),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat(
                    "Approve ", assets[i].symbol(), " to be spent by USR External Requests Manager"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "UsrExternalRequestsManager");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "UsrExternalRequestsManager"),
                canSendValue: false,
                signature: "requestMint(address,uint256,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Convert ", assets[i].symbol(), " to USR"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "UsrExternalRequestsManager"),
                canSendValue: false,
                signature: "requestBurn(uint256,address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Convert USR to ", assets[i].symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "UsrExternalRequestsManager"),
            canSendValue: false,
            signature: "cancelMint(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Cancel USR mint request"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "UsrExternalRequestsManager"),
            canSendValue: false,
            signature: "cancelBurn(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Cancel USR burn request"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    function _addResolvStUSRLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "USR"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve USR to be converted to stUSR"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "stUSR");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "stUSR"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve stUSR to be converted to USR"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "stUSR");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "stUSR"),
            canSendValue: false,
            signature: "deposit(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Convert USR to stUSR"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "stUSR"),
            canSendValue: false,
            signature: "withdraw(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Convert stUSR to USR"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    function _addResolvWstUSRLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "stUSR"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve stUSR to be converted to wstUSR"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "wstUSR");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "USR"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve USR to be converted to wstUSR"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "wstUSR");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "wstUSR"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve wstUSR to be converted to stUSR"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "wstUSR");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "wstUSR"),
            canSendValue: false,
            signature: "wrap(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Convert stUSR to wstUSR"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "wstUSR"),
            canSendValue: false,
            signature: "deposit(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Stake + Wrap USR for wstUSR"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "wstUSR"),
            canSendValue: false,
            signature: "unwrap(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Convert wstUSR to stUSR"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "wstUSR"),
            canSendValue: false,
            signature: "withdraw(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Unwrap + Unstake wstUSR for USR"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= Lombard BTC  =========================================

    // @notice to avoid having an extra unneeded approval leaf for base vs bnb merkle trees
    function _addLombardBTCLeafs(ManageLeaf[] memory leafs, ERC20 BTCB_or_CBBtc, ERC20 LBTC) internal {
        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: address(BTCB_or_CBBtc),
            canSendValue: //target
            false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve BTCB to be staked into LBTC"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "LBTC");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(LBTC),
            canSendValue: //target
            false,
            signature: "mint(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Mint LBTC if permissioned"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(LBTC),
            canSendValue: //target
            false,
            signature: "mint(bytes,bytes)",
            argumentAddresses: new address[](1),
            description: string.concat("Mint LBTC"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        //set the swap leaf based on if we are on bnc or base
        if (getAddress("base", "cbBTC") == address(BTCB_or_CBBtc)) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(BTCB_or_CBBtc),
                canSendValue: //target
                false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve cbBTC to be swapped for LBTC"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "cbBTCPMM");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "cbBTCPMM"),
                canSendValue: //target
                false,
                signature: "swapCBBTCToLBTC(uint256)",
                argumentAddresses: new address[](0),
                description: string.concat("Swap cbBTC to LBTC"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
        } else {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(BTCB_or_CBBtc),
                canSendValue: //target
                false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve BTCB to be swapped for LBTC via swap contract"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "BTCBPMM");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "BTCBPMM"),
                canSendValue: //target
                false,
                signature: "swapBTCBToLBTC(uint256)",
                argumentAddresses: new address[](0),
                description: string.concat("Swap BTCB to LBTC"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
        }
    }

    // ========================================= BTCK =========================================
    function _addBTCKLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "LBTC"),
            canSendValue: //target
            false,
            signature: "deposit(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Deposit BTCK for LBTC payload"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "LBTC"),
            canSendValue: //target
            false,
            signature: "mint(bytes,bytes)",
            argumentAddresses: new address[](0),
            description: string.concat("Mint LBTC with payload"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "LBTC"),
            canSendValue: //target
            false,
            signature: "redeem(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Redeem LBTC for BTCK payload"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "BTCK"),
            canSendValue: //target
            false,
            signature: "mintV1(bytes,bytes)",
            argumentAddresses: new address[](0),
            description: string.concat("Mint BTCK with payload"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= BTC.b =========================================
    function _addBTCbLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "LBTC"),
            canSendValue: //target
            false,
            signature: "deposit(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Deposit BTC.b for LBTC payload"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "LBTC"),
            canSendValue: //target
            false,
            signature: "mint(bytes,bytes)",
            argumentAddresses: new address[](0),
            description: string.concat("Mint LBTC with payload"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "LBTC"),
            canSendValue: //target
            false,
            signature: "redeem(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Redeem LBTC for BTC.b payload"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "BTCb"),
            canSendValue: //target
            false,
            signature: "mintV1(bytes,bytes)",
            argumentAddresses: new address[](0),
            description: string.concat("Mint BTC.b with payload"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ============================================= BTCN Corn ==================================================

    function _addBTCNLeafs(ManageLeaf[] memory leafs, ERC20 collateralToken, ERC20 BTCN, address cornSwapFacility)
        internal
    {
        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: address(collateralToken),
            canSendValue: //target
            false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Approve ", collateralToken.symbol(), " to be swapped for BTCN by the Corn SwapFacility Contract"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = cornSwapFacility;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: address(BTCN),
            canSendValue: //target
            false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Approve BTCN to be swapped for ", collateralToken.symbol(), " by the Corn SwapFacility Contract"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = cornSwapFacility;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: cornSwapFacility,
            canSendValue: //target
            false,
            signature: "swapExactCollateralForDebt(uint256,uint256,address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Swap ", collateralToken.symbol(), " for BTCN"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: cornSwapFacility,
            canSendValue: //target
            false,
            signature: "swapExactDebtForCollateral(uint256,uint256,address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Swap BTCN for ", collateralToken.symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // =================================== USDD ====================================================

    function _addUSDDPSMLeafs(ManageLeaf[] memory leafs) internal {
        // XXX: Approvals are not symmetrical. Need to approve JoinAuth when minting (sellGem) but, PSM when exiting (buyGem)
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "USDD"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve USDD to be swapped for USDT"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "usddPsmUsdt");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "USDT"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve USDT to be swapped for USDD"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "usddJoinAuth");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "usddPsmUsdt"),
            canSendValue: false,
            signature: "sellGem(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Swap USDT for USDD"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "usddPsmUsdt"),
            canSendValue: false,
            signature: "buyGem(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Swap USDD for USDT"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    function _addSUSDDLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "USDD"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve USDD to be staked for sUSDD"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "sUSDD");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "sUSDD"),
            canSendValue: false,
            signature: "deposit(uint256,address)",
            argumentAddresses: new address[](1),
            description: string.concat("stake USDD for sUSDD"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "sUSDD"),
            canSendValue: false,
            signature: "redeem(uint256,address,address)",
            argumentAddresses: new address[](2),
            description: string.concat("unstake sUSDD for USDD"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Sky Money =========================================
    function _addAllSkyMoneyLeafs(ManageLeaf[] memory leafs) internal {
        _addSkyDaiConverterLeafs(leafs);
        _addSkyUSDSLitePSMUSDCLeafs(leafs);
        _addSkyDAILitePSMUSDCLeafs(leafs);
    }

    function _addSkyDaiConverterLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "DAI"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve DAI to be spent by SKY Dai Converter"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "daiConverter");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "USDS"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve USDS to be spent by SKY Dai Converter"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "daiConverter");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "daiConverter"),
            canSendValue: false,
            signature: "daiToUsds(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Convert DAI to USDS"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "daiConverter"),
            canSendValue: false,
            signature: "usdsToDai(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Convert DAI to USDS"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    function _addSkyUSDSLitePSMUSDCLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "USDS"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve USDS to be swapped for USDC"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "usdsLitePsmUsdc");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "USDC"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve USDC to be swapped for USDS"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "usdsLitePsmUsdc");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "usdsLitePsmUsdc"),
            canSendValue: false,
            signature: "sellGem(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Swap USDC for USDS"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "usdsLitePsmUsdc"),
            canSendValue: false,
            signature: "buyGem(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Swap USDS for USDC"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    function _addSkyDAILitePSMUSDCLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "DAI"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve DAI to be swapped for USDC"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "daiLitePsmUsdc");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "USDC"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve USDC to be swapped for DAI"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "daiLitePsmUsdc");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "daiLitePsmUsdc"),
            canSendValue: false,
            signature: "sellGem(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Swap USDC for DAI"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "daiLitePsmUsdc"),
            canSendValue: false,
            signature: "buyGem(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Swap DAI for USDC"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Syrup =========================================
    function _addAllSyrupLeafs(ManageLeaf[] memory leafs, address[] memory tokens) internal {
        _addSyrupRouterLeafs(leafs, tokens);
        _addSyrupPoolLeafs(leafs, tokens);
    }

    function _addSyrupRouterLeafs(ManageLeaf[] memory leafs, address[] memory tokens) internal {
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i] != getAddress(sourceChain, "USDC") && tokens[i] != getAddress(sourceChain, "USDT")) {
                revert("Must be USDC or USDT");
            }

            if (tokens[i] == getAddress(sourceChain, "USDC")) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "USDC"),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve USDC to be spent by USDC syrupRouter"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "syrupRouterUSDC");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "syrupRouterUSDC"),
                    canSendValue: false,
                    signature: "deposit(uint256,bytes32)",
                    argumentAddresses: new address[](0),
                    description: string.concat("Deposit USDC to syrupUSDC"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
            }

            if (tokens[i] == getAddress(sourceChain, "USDT")) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "USDT"),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve USDT to be spent by USDT syrupRouter"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "syrupRouterUSDT");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "syrupRouterUSDT"),
                    canSendValue: false,
                    signature: "deposit(uint256,bytes32)",
                    argumentAddresses: new address[](0),
                    description: string.concat("Deposit USDT to syrupUSDT"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
            }
        }
    }

    function _addSyrupPoolLeafs(ManageLeaf[] memory leafs, address[] memory tokens) internal {
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i] != getAddress(sourceChain, "USDC") && tokens[i] != getAddress(sourceChain, "USDT")) {
                revert("Must be USDC or USDT");
            }

            if (tokens[i] == getAddress(sourceChain, "USDC")) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "syrupUSDC"),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve syrupUSDC to be redeemed for USDC"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "syrupUSDC");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "syrupUSDC"),
                    canSendValue: false,
                    signature: "requestRedeem(uint256,address)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Request redeem syrupUSDC for USDC"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "syrupUSDC"),
                    canSendValue: false,
                    signature: "removeShares(uint256,address)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Cancel syrupUSDC for USDC redemption request"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            }

            if (tokens[i] == getAddress(sourceChain, "USDT")) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "syrupUSDT"),
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve syrupUSDT to be redeemed for USDT"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "syrupUSDT");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "syrupUSDT"),
                    canSendValue: false,
                    signature: "requestRedeem(uint256,address)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Request redeem syrupUSDT for USDT"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "syrupUSDT"),
                    canSendValue: false,
                    signature: "removeShares(uint256,address)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Cancel syrupUSDT for USDT redemption request"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            }
        }
    }

    // ========================================= Golilocks =========================================
    function _addGoldiVaultLeafs(ManageLeaf[] memory leafs, address[] memory vaults) internal {
        for (uint256 i = 0; i < vaults.length; i++) {
            address depositToken = IGoldiVault(vaults[i]).depositToken();
            address OT = IGoldiVault(vaults[i]).ot();
            address YT = IGoldiVault(vaults[i]).yt();

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: depositToken,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat(
                    "Approve ", vm.toString(vaults[i]), " to spend ", ERC20(depositToken).symbol()
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = vaults[i];

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: OT,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve ", vm.toString(vaults[i]), " to spend ", ERC20(OT).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = vaults[i];

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: YT,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve ", vm.toString(vaults[i]), " to spend ", ERC20(YT).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = vaults[i];

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: vaults[i],
                canSendValue: false,
                signature: "deposit(uint256)",
                argumentAddresses: new address[](0),
                description: string.concat(
                    "Deposit ", ERC20(depositToken).symbol(), " into GoldiVault ", vm.toString(vaults[i])
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: vaults[i],
                canSendValue: false,
                signature: "redeemOwnership(uint256)",
                argumentAddresses: new address[](0),
                description: string.concat("Redeem OT in ", ERC20(depositToken).symbol(), " GoldiVault"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: vaults[i],
                canSendValue: false,
                signature: "redeemYield(uint256)",
                argumentAddresses: new address[](0),
                description: string.concat("Redeem YT in ", ERC20(depositToken).symbol(), " GoldiVault"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: vaults[i],
                canSendValue: false,
                signature: "compound()",
                argumentAddresses: new address[](0),
                description: string.concat("Compound rewards in ", ERC20(depositToken).symbol(), " GoldiVault"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: vaults[i],
                canSendValue: false,
                signature: "buyYT(uint256,uint256,uint256)",
                argumentAddresses: new address[](0),
                description: string.concat("Buy YT ", ERC20(depositToken).symbol(), " via GoldiVault"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: vaults[i],
                canSendValue: false,
                signature: "sellYT(uint256,uint256,uint256)",
                argumentAddresses: new address[](0),
                description: string.concat("Sell YT ", ERC20(depositToken).symbol(), " via GoldiVault"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
        }
    }

    // ========================================= Sonic Gateway =========================================
    // To be used on ETH mainnet.
    function _addSonicGatewayLeafsEth(ManageLeaf[] memory leafs, ERC20[] memory assets) internal {
        for (uint256 i = 0; i < assets.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(assets[i]),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Sonic Gateway L1 to spend", assets[i].symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "sonicGateway");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "sonicGateway"),
                canSendValue: false,
                signature: "deposit(uint96,address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Deposit ", assets[i].symbol(), " into Sonic Gateway"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "sonicGateway"),
                canSendValue: false,
                signature: "claim(uint256,address,uint256,bytes)",
                argumentAddresses: new address[](1),
                description: string.concat("Claim ", assets[i].symbol(), " from Sonic Gateway"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "sonicGateway"),
                canSendValue: false,
                signature: "cancelDepositWhileDead(uint256,address,uint256,bytes)",
                argumentAddresses: new address[](1),
                description: string.concat("Cancel deposit of ", assets[i].symbol(), " from Sonic Gateway while dead"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
        }
    }

    // To be used on Sonic L2.
    // NOTE: sonic bridge uses the mainnet token address to match with their bridged versions, so we need both.
    // The mainnet token address is the one sanitized and the one that needs to be passed into the bridge itself, but the sonic address will be used in the leaf to (hopefully) minimize confusion. It is also used for approvals. However, this is still confusing, so I am leaving this comment.
    function _addSonicGatewayLeafsSonic(
        ManageLeaf[] memory leafs,
        address[] memory assetsMainnet,
        address[] memory assetsSonic
    ) internal {
        require(assetsSonic.length == assetsMainnet.length, "Asset length mismatch");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "USDC"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Circle Token Adapter to burn USDC"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "circleTokenAdapter");

        for (uint256 i = 0; i < assetsMainnet.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(assetsSonic[i]),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Sonic Gateway L2 to spend ", vm.toString(assetsSonic[i])),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });

            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "sonicGateway");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "sonicGateway"),
                canSendValue: false,
                signature: "withdraw(uint96,address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Withdraw ", vm.toString(assetsSonic[i]), " from Sonic"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(assetsMainnet[i]);

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "sonicGateway"),
                canSendValue: false,
                signature: "claim(uint256,address,uint256,bytes)",
                argumentAddresses: new address[](1),
                description: string.concat("Claim ", vm.toString(assetsSonic[i]), " from Sonic Gateway"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(assetsMainnet[i]);
        }
    }

    // ========================================= BoringVault Teller =========================================

    function _addTellerLeafs(
        ManageLeaf[] memory leafs,
        address teller,
        ERC20[] memory assets,
        bool addNativeDeposit,
        bool addBulkWithdraw
    ) internal {
        ERC20 boringVault = ITellerVaultGetter(teller).vault();

        for (uint256 i; i < assets.length; ++i) {
            // Approve BoringVault to spend all assets.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(assets[i]),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve ", boringVault.name(), ", to spend ", assets[i].symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(boringVault);

            // BulkDeposit asset.
            if (addBulkWithdraw) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: teller,
                    canSendValue: false,
                    signature: "bulkDeposit(address,uint256,uint256,address)",
                    argumentAddresses: new address[](2),
                    description: string.concat("Bulk deposit ", assets[i].symbol(), " into ", boringVault.name()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

                // BulkWithdraw asset.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: teller,
                    canSendValue: false,
                    signature: "bulkWithdraw(address,uint256,uint256,address)",
                    argumentAddresses: new address[](2),
                    description: string.concat("Bulk withdraw ", assets[i].symbol(), " from ", boringVault.name()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            }

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: teller,
                canSendValue: false,
                signature: "deposit(address,uint256,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Deposit ", assets[i].symbol(), " into ", boringVault.name()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
        }

        if (addNativeDeposit) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: teller,
                canSendValue: true,
                signature: //can send value
                "deposit(address,uint256,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Deposit ETH into ", boringVault.name()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "ETH");
        }
    }

    // ========================================= Teller with referrer =========================================
    function _addTellerLeafsWithReferral(
        ManageLeaf[] memory leafs,
        address teller,
        ERC20[] memory assets,
        bool addNativeDeposit,
        bool addBulkWithdraw,
        address referrer
    ) internal {
        ERC20 boringVault = ITellerVaultGetter(teller).vault();

        for (uint256 i; i < assets.length; ++i) {
            // Approve BoringVault to spend all assets.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: address(assets[i]),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve ", boringVault.name(), ", to spend ", assets[i].symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(boringVault);

            // BulkDeposit asset.
            if (addBulkWithdraw) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: teller,
                    canSendValue: false,
                    signature: "bulkDeposit(address,uint256,uint256,address)",
                    argumentAddresses: new address[](2),
                    description: string.concat("Bulk deposit ", assets[i].symbol(), " into ", boringVault.name()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

                // BulkWithdraw asset.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: teller,
                    canSendValue: false,
                    signature: "bulkWithdraw(address,uint256,uint256,address)",
                    argumentAddresses: new address[](2),
                    description: string.concat("Bulk withdraw ", assets[i].symbol(), " from ", boringVault.name()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            }

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: teller,
                canSendValue: false,
                signature: "deposit(address,uint256,uint256,address)",
                argumentAddresses: new address[](2),
                description: string.concat("Deposit ", assets[i].symbol(), " into ", boringVault.name()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
            leafs[leafIndex].argumentAddresses[1] = referrer;

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: teller,
                canSendValue: false,
                signature: "withdraw(address,uint256,uint256,address)",
                argumentAddresses: new address[](2),
                description: string.concat("Withdraw ", assets[i].symbol(), " from ", boringVault.name()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }

        if (addNativeDeposit) {
            // Deposite ETH with referrer
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: teller,
                canSendValue: true,
                signature: "deposit(address,uint256,uint256,address)",
                argumentAddresses: new address[](2),
                description: string.concat("Deposit ETH into ", boringVault.name()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "ETH");
            leafs[leafIndex].argumentAddresses[1] = referrer;
        }
    }
    // ========================================= CrossChain Teller =========================================

    function _addCrossChainTellerLeafs(
        ManageLeaf[] memory leafs,
        address teller,
        address[] memory depositAssets,
        address[] memory feeAssets,
        bytes memory destChain
    ) internal {
        address boringVault = ITeller(teller).vault();

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: boringVault,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve CrossChain Teller to spend ", ERC20(boringVault).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = teller;

        for (uint256 i = 0; i < feeAssets.length; i++) {
            if (feeAssets[i] != getAddress(sourceChain, "ETH")) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: feeAssets[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve CrossChain Teller to spend ", ERC20(feeAssets[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = teller;
            }
        }

        for (uint256 i = 0; i < depositAssets.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: depositAssets[i],
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve CrossChain Teller to spend ", ERC20(depositAssets[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = boringVault;
        }

        // Extract first 16 bytes and convert to address
        //require(destChain.length == 32, "Invalid input length");
        address destChain0;

        if (destChain.length >= 20) {
            assembly {
                // Skip the 32-byte length prefix of memory arrays
                let word := mload(add(destChain, 32))
                destChain0 := word
            }
            destChain0 = address(uint160(destChain0)); // cast outside assembly
        }

        for (uint256 i = 0; i < depositAssets.length; i++) {
            for (uint256 j = 0; j < feeAssets.length; j++) {
                if (feeAssets[j] == getAddress(sourceChain, "ETH")) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: teller,
                        canSendValue: true,
                        signature: "depositAndBridge(address,uint256,uint256,address,bytes,address,uint256)",
                        argumentAddresses: new address[](4),
                        description: string.concat(
                            "Deposit and bridge ", ERC20(depositAssets[i]).symbol(), " with ETH as fee"
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = depositAssets[i];
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[2] = destChain0;
                    leafs[leafIndex].argumentAddresses[3] = feeAssets[j];
                } else {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: teller,
                        canSendValue: false,
                        signature: "depositAndBridge(address,uint256,uint256,address,bytes,address,uint256)",
                        argumentAddresses: new address[](4),
                        description: string.concat(
                            "Deposit and bridge ",
                            ERC20(depositAssets[i]).symbol(),
                            " with ",
                            ERC20(feeAssets[j]).symbol(),
                            " as fee"
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = depositAssets[i];
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[2] = destChain0;
                    leafs[leafIndex].argumentAddresses[3] = feeAssets[j];
                }
            }
        }

        for (uint256 i = 0; i < feeAssets.length; i++) {
            if (feeAssets[i] == getAddress(sourceChain, "ETH")) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: teller,
                    canSendValue: true,
                    signature: "bridge(uint96,address,bytes,address,uint256)",
                    argumentAddresses: new address[](3),
                    description: string.concat("Bridge ", ERC20(ITeller(teller).vault()).symbol(), " with ETH as fee"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
                leafs[leafIndex].argumentAddresses[1] = destChain0;
                leafs[leafIndex].argumentAddresses[2] = feeAssets[i];
            } else {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: teller,
                    canSendValue: false,
                    signature: "bridge(uint96,address,bytes,address,uint256)",
                    argumentAddresses: new address[](4),
                    description: string.concat(
                        "Bridge ",
                        ERC20(ITeller(teller).vault()).symbol(),
                        " with ",
                        ERC20(feeAssets[i]).symbol(),
                        " as fee"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
                leafs[leafIndex].argumentAddresses[1] = destChain0;
                leafs[leafIndex].argumentAddresses[2] = feeAssets[i];
            }
        }
    }

    // ========================================= CrossChain Teller with referral =========================================

    function _addCrossChainTellerLeafsWithReferral(
        ManageLeaf[] memory leafs,
        address teller,
        address[] memory depositAssets,
        address[] memory feeAssets,
        bytes memory destChain,
        address referrer
    ) internal {
        address boringVault = ITeller(teller).vault();

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: boringVault,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve CrossChain Teller to spend ", ERC20(boringVault).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = teller;

        for (uint256 i = 0; i < feeAssets.length; i++) {
            if (feeAssets[i] != getAddress(sourceChain, "ETH")) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: feeAssets[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve CrossChain Teller to spend ", ERC20(feeAssets[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = teller;
            }
        }

        for (uint256 i = 0; i < depositAssets.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: depositAssets[i],
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve CrossChain Teller to spend ", ERC20(depositAssets[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = boringVault;
        }

        // Extract first 16 bytes and convert to address
        //require(destChain.length == 32, "Invalid input length");
        address destChain0;

        if (destChain.length >= 20) {
            assembly {
                // Skip the 32-byte length prefix of memory arrays
                let word := mload(add(destChain, 32))
                destChain0 := word
            }
            destChain0 = address(uint160(destChain0)); // cast outside assembly
        }

        for (uint256 i = 0; i < depositAssets.length; i++) {
            for (uint256 j = 0; j < feeAssets.length; j++) {
                if (feeAssets[j] == getAddress(sourceChain, "ETH")) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: teller,
                        canSendValue: true,
                        signature: "depositAndBridge(address,uint256,uint256,address,bytes,address,uint256,address)",
                        argumentAddresses: new address[](5),
                        description: string.concat(
                            "Deposit and bridge ", ERC20(depositAssets[i]).symbol(), " with ETH as fee"
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = depositAssets[i];
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[2] = destChain0;
                    leafs[leafIndex].argumentAddresses[3] = feeAssets[j];
                    leafs[leafIndex].argumentAddresses[4] = referrer;
                } else {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: teller,
                        canSendValue: false,
                        signature: "depositAndBridge(address,uint256,uint256,address,bytes,address,uint256,address)",
                        argumentAddresses: new address[](5),
                        description: string.concat(
                            "Deposit and bridge ",
                            ERC20(depositAssets[i]).symbol(),
                            " with ",
                            ERC20(feeAssets[j]).symbol(),
                            " as fee"
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = depositAssets[i];
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[2] = destChain0;
                    leafs[leafIndex].argumentAddresses[3] = feeAssets[j];
                    leafs[leafIndex].argumentAddresses[4] = referrer;
                }
            }
        }

        for (uint256 i = 0; i < feeAssets.length; i++) {
            if (feeAssets[i] == getAddress(sourceChain, "ETH")) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: teller,
                    canSendValue: true,
                    signature: "bridge(uint96,address,bytes,address,uint256)",
                    argumentAddresses: new address[](3),
                    description: string.concat("Bridge ", ERC20(ITeller(teller).vault()).symbol(), " with ETH as fee"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
                leafs[leafIndex].argumentAddresses[1] = destChain0;
                leafs[leafIndex].argumentAddresses[2] = feeAssets[i];
            } else {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: teller,
                    canSendValue: false,
                    signature: "bridge(uint96,address,bytes,address,uint256)",
                    argumentAddresses: new address[](4),
                    description: string.concat(
                        "Bridge ",
                        ERC20(ITeller(teller).vault()).symbol(),
                        " with ",
                        ERC20(feeAssets[i]).symbol(),
                        " as fee"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
                leafs[leafIndex].argumentAddresses[1] = destChain0;
                leafs[leafIndex].argumentAddresses[2] = feeAssets[i];
            }
        }
    }

    // ========================================= beraETH =========================================
    function _addBeraETHLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "WETH"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve rberaETH to spend WETH"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "rberaETH");

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "rberaETH"),
            canSendValue: false,
            signature: "depositAndWrap(address,uint256,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Deposit and wrap WETH into beraETH"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "WETH");

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "beraETH"),
            canSendValue: false,
            signature: "unwrap(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Unwrap beraETH"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= Infrared  =========================================
    function _addInfraredVaultLeafs(ManageLeaf[] memory leafs, address vault) internal {
        address stakingToken = IInfraredVault(vault).stakingToken();

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: stakingToken,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Infrared Vault to spend ", ERC20(stakingToken).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = vault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vault,
            canSendValue: false,
            signature: "stake(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Stake ", ERC20(stakingToken).symbol(), " into Infrared Vault"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vault,
            canSendValue: false,
            signature: "withdraw(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Withdraw ", ERC20(stakingToken).symbol(), " from Infrared Vault"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vault,
            canSendValue: false,
            signature: "getRewardForUser(address)",
            argumentAddresses: new address[](1),
            description: string.concat("Get Reward for user from ", ERC20(stakingToken).symbol(), " Infrared Vault"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vault,
            canSendValue: false,
            signature: "getReward()",
            argumentAddresses: new address[](0),
            description: string.concat("Get Reward for ", ERC20(stakingToken).symbol(), " Infrared Vault"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vault,
            canSendValue: false,
            signature: "exit()",
            argumentAddresses: new address[](0),
            description: string.concat("Exit from ", ERC20(stakingToken).symbol(), " Infrared Vault"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= BoringVault WithdrawQueue =========================================
    function _addWithdrawQueueLeafs(
        ManageLeaf[] memory leafs,
        address withdrawQueue,
        address boringVault,
        ERC20[] memory assets
    ) internal {
        for (uint256 i = 0; i < assets.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: boringVault,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve BoringOnChainQueue to spend ", ERC20(boringVault).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = withdrawQueue;

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: withdrawQueue,
                canSendValue: false,
                signature: "requestOnChainWithdraw(address,uint128,uint16,uint24)",
                argumentAddresses: new address[](1),
                description: string.concat("Request Withdraw of ", assets[i].symbol(), ", from queue"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: withdrawQueue,
                canSendValue: false,
                signature: "cancelOnChainWithdraw((uint96,address,address,uint128,uint128,uint40,uint24,uint24))",
                argumentAddresses: new address[](2),
                description: string.concat("Cancel Withdraw of ", assets[i].symbol(), ", from queue"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = address(assets[i]);

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: withdrawQueue,
                canSendValue: false,
                signature: "replaceOnChainWithdraw((uint96,address,address,uint128,uint128,uint40,uint24,uint24),uint16,uint24)",
                argumentAddresses: new address[](2),
                description: string.concat("Replace Withdraw of ", assets[i].symbol(), ", from queue"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = address(assets[i]);
        }
    }

    // ========================================= Honey =========================================

    function _addHoneyLeafs(ManageLeaf[] memory leafs) internal {
        ERC20[] memory assets = new ERC20[](1);
        assets[0] = getERC20(sourceChain, "USDC");
        // assets[1] = getERC20(sourceChain, "USDT");
        // assets[2] = getERC20(sourceChain, "DAI");

        for (uint256 i = 0; i < assets.length; i++) {
            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf({
                target: address(assets[i]),
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Honey Factory to spend ", assets[i].symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "honeyFactory");

            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "honeyFactory"),
                canSendValue: false,
                signature: "mint(address,uint256,address)",
                argumentAddresses: new address[](2),
                description: string.concat("Mint Honey using ", assets[i].symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "honeyFactory"),
                canSendValue: false,
                signature: "redeem(address,uint256,address)",
                argumentAddresses: new address[](2),
                description: string.concat("Redeem Honey for ", assets[i].symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
    }

    // ========================================= Kodiak Finance =========================================
    function _addKodiakIslandLeafs(ManageLeaf[] memory leafs, address[] memory islands) internal {
        _addKodiakIslandLeafs(leafs, islands, false);
    }

    function _addKodiakIslandLeafs(ManageLeaf[] memory leafs, address[] memory islands, bool includeNativeLeaves)
        internal
    {
        for (uint256 i = 0; i < islands.length; i++) {
            address token0 = IKodiakIsland(islands[i]).token0();
            address token1 = IKodiakIsland(islands[i]).token1();

            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0][getAddress(sourceChain, "kodiakIslandRouter")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token0,
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Kodiak router to spend ", ERC20(token0).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "kodiakIslandRouter");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token0][getAddress(sourceChain, "kodiakIslandRouter")] = true;
            }

            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1][getAddress(sourceChain, "kodiakIslandRouter")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: token1,
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Kodiak router to spend ", ERC20(token1).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "kodiakIslandRouter");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1][getAddress(sourceChain, "kodiakIslandRouter")] = true;
            }

            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][islands[i]][getAddress(sourceChain, "kodiakIslandRouter")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: islands[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Kodiak router to spend ", ERC20(islands[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "kodiakIslandRouter");
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][token1][getAddress(sourceChain, "kodiakIslandRouter")] = true;
            }

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "kodiakIslandRouter"),
                canSendValue: false,
                signature: "addLiquidity(address,uint256,uint256,uint256,uint256,uint256,address)",
                argumentAddresses: new address[](2),
                description: string.concat("Add Liquidity in ", IKodiakIsland(islands[i]).name()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = islands[i];
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            if (includeNativeLeaves) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "kodiakIslandRouter"),
                    canSendValue: true,
                    signature: "addLiquidityNative(address,uint256,uint256,uint256,uint256,uint256,address)",
                    argumentAddresses: new address[](2),
                    description: string.concat("Add Liquidity Native in ", IKodiakIsland(islands[i]).name()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = islands[i];
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            }

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "kodiakIslandRouter"),
                canSendValue: false,
                signature: "removeLiquidity(address,uint256,uint256,uint256,address)",
                argumentAddresses: new address[](2),
                description: string.concat("Remove Liquidity from ", IKodiakIsland(islands[i]).name()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = islands[i];
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            if (includeNativeLeaves) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "kodiakIslandRouter"),
                    canSendValue: false,
                    signature: "removeLiquidityNative(address,uint256,uint256,uint256,address)",
                    argumentAddresses: new address[](2),
                    description: string.concat("Remove Liquidity Native from ", IKodiakIsland(islands[i]).name()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = islands[i];
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            }
        }
    }

    // ========================================= Beraborrow =========================================
    function _addBeraborrowLeafs(
        ManageLeaf[] memory leafs,
        address[] memory collateralVaultAssets,
        address[] memory denManagers,
        bool addNative
    ) internal {
        //approve NCTR once
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "NECT"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Beraborrow CollVaultRouter to spend NECT"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "collVaultRouter");

        require(collateralVaultAssets.length == denManagers.length, "beraborrow: length mismatch");

        for (uint256 i = 0; i < collateralVaultAssets.length; i++) {
            address asset = address(ERC4626(collateralVaultAssets[i]).asset());

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: asset,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Beraborrow CollVaultRouter to spend ", ERC20(asset).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "collVaultRouter");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "collVaultRouter"),
                canSendValue: false,
                signature: "openDenVault((address,address,uint256,uint256,uint256,address,address,uint256,uint256,bytes))",
                argumentAddresses: new address[](2),
                description: string.concat(
                    "Open Den Vault with ", ERC20(collateralVaultAssets[i]).symbol(), " as collateral"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = denManagers[i];
            leafs[leafIndex].argumentAddresses[1] = collateralVaultAssets[i];

            if (addNative) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "collVaultRouter"),
                    canSendValue: true,
                    signature: "openDenVault((address,address,uint256,uint256,uint256,address,address,uint256,uint256,bytes))",
                    argumentAddresses: new address[](2),
                    description: string.concat(
                        "Open Den Vault with ", ERC20(collateralVaultAssets[i]).symbol(), " as collateral"
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = denManagers[i];
                leafs[leafIndex].argumentAddresses[1] = collateralVaultAssets[i];
            }

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "collVaultRouter"),
                canSendValue: false,
                signature: "adjustDenVault((address,address,uint256,uint256,uint256,uint256,bool,address,address,bool,uint256,uint256,uint256,bytes))",
                argumentAddresses: new address[](2),
                description: string.concat("Adjust Den Vault ", ERC20(collateralVaultAssets[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = denManagers[i];
            leafs[leafIndex].argumentAddresses[1] = collateralVaultAssets[i];

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "collVaultRouter"),
                canSendValue: false,
                signature: "closeDenVault(address,address,uint256,uint256,bool)",
                argumentAddresses: new address[](2),
                description: string.concat("Close Den Vault ", ERC20(collateralVaultAssets[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = denManagers[i];
            leafs[leafIndex].argumentAddresses[1] = collateralVaultAssets[i];
        }
    }

    // Note: add 4626 leafs separately if you need access to the regular deposit function that 0s out the params,
    // mint,redeem,withdraw all will not work at all
    function _addBeraborrowManagedVaultLeafs(ManageLeaf[] memory leafs, address[] memory managedVaults) internal {
        for (uint256 i = 0; i < managedVaults.length; i++) {
            ERC4626 managedVault = ERC4626(managedVaults[i]);
            address asset = address(managedVault.asset());

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: asset,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat(
                    "Approve ", ERC20(asset).symbol(), " for ", ERC20(managedVaults[i]).symbol()
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = managedVaults[i];

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: managedVaults[i],
                canSendValue: false,
                signature: "deposit(uint256,address,(address,address,uint256,uint256))",
                argumentAddresses: new address[](1),
                description: string.concat("Deposit into ", ERC20(managedVaults[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: managedVaults[i],
                canSendValue: false,
                signature: "redeemIntent(uint256,address,address)",
                argumentAddresses: new address[](2),
                description: string.concat("Redeem Intent for ", ERC20(managedVaults[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: managedVaults[i],
                canSendValue: false,
                signature: "cancelWithdrawalIntent(uint256,uint256,address)",
                argumentAddresses: new address[](1),
                description: string.concat("Cancel Withdrawal Intent for ", ERC20(managedVaults[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: managedVaults[i],
                canSendValue: false,
                signature: "withdrawFromEpoch(uint256,address,(address,bytes,uint256))",
                argumentAddresses: new address[](2),
                description: string.concat("Withdraw From Epoch ", ERC20(managedVaults[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "collVaultUnwrapper");
        }
    }

    // ========================================= Dolomite Finance =========================================

    function _addDolomiteDepositLeafs(ManageLeaf[] memory leafs, address token, bool addNative) internal {
        uint256 marketId = IDolomiteMargin(getAddress(sourceChain, "dolomiteMargin")).getMarketIdByTokenAddress(token);

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: token,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Dolomite DepositWithdraw Router to spend ", ERC20(token).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "dolomiteMargin");

        // Wad Scaled Functions

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
            canSendValue: false,
            signature: "depositWei(uint256,uint256,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Deposit ",
                ERC20(token).symbol(),
                " into Dolomite DepositWithdraw Router Market ID: ",
                vm.toString(marketId)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = token;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
            canSendValue: false,
            signature: "depositWeiIntoDefaultAccount(uint256,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Deposit ",
                ERC20(token).symbol(),
                " into Dolomite DepositWithdraw Router Market ID: ",
                vm.toString(marketId),
                " Default Account"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = token;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
            canSendValue: false,
            signature: "withdrawWei(uint256,uint256,uint256,uint8)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Withdraw ",
                ERC20(token).symbol(),
                " from Dolomite DepositWithdraw Router Market ID: ",
                vm.toString(marketId)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = token;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
            canSendValue: false,
            signature: "withdrawWeiFromDefaultAccount(uint256,uint256,uint8)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Withdraw ",
                ERC20(token).symbol(),
                " from Dolomite DepositWithdraw Router Market ID: ",
                vm.toString(marketId),
                " default account"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = token;

        // Native ETH Functions
        if (addNative) {
            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
                canSendValue: true,
                signature: "depositETH(uint256)",
                argumentAddresses: new address[](0),
                description: string.concat("Deposit ETH into Dolomite ETH Market"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });

            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
                canSendValue: true,
                signature: "depositETHIntoDefaultAccount()",
                argumentAddresses: new address[](0),
                description: string.concat("Deposit ETH into Dolomite ETH Market in default account"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });

            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
                canSendValue: false,
                signature: "withdrawETH(uint256,uint256,uint8)",
                argumentAddresses: new address[](0),
                description: string.concat("Withdraw ETH from Dolomite ETH Market"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });

            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
                canSendValue: false,
                signature: "withdrawETHFromDefaultAccount(uint256,uint8)",
                argumentAddresses: new address[](0),
                description: string.concat("Withdraw ETH from Dolomite ETH Market default account"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
        }

        // Par Scaled Functions

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
            canSendValue: false,
            signature: "depositPar(uint256,uint256,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Deposit Par scaled ",
                ERC20(token).symbol(),
                " into Dolomite DepositWithdraw Router Market ID: ",
                vm.toString(marketId)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = token;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
            canSendValue: false,
            signature: "depositParIntoDefaultAccount(uint256,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Deposit Par scaled ",
                ERC20(token).symbol(),
                " into Dolomite DepositWithdraw Router Market ID: ",
                vm.toString(marketId),
                " in default account"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = token;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
            canSendValue: false,
            signature: "withdrawPar(uint256,uint256,uint256,uint8)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Withdraw Par scaled ",
                ERC20(token).symbol(),
                " from Dolomite DepositWithdraw Router Market ID: ",
                vm.toString(marketId)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = token;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
            canSendValue: false,
            signature: "withdrawParFromDefaultAccount(uint256,uint256,uint8)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Withdraw Par scaled ",
                ERC20(token).symbol(),
                " from Dolomite DepositWithdraw Router Market ID: ",
                vm.toString(marketId)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = token;
    }

    function _addDolomiteBorrowLeafs(ManageLeaf[] memory leafs, address borrowToken) internal {
        uint256 marketId =
            IDolomiteMargin(getAddress(sourceChain, "dolomiteMargin")).getMarketIdByTokenAddress(borrowToken);

        //Main Borrow Position Functions

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "dolomiteBorrowProxy"),
            canSendValue: false,
            signature: "openBorrowPosition(uint256,uint256,uint256,uint256,uint8)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Use ",
                ERC20(borrowToken).symbol(),
                " as collateral on Dolomite BorrowPosition Market ID: ",
                vm.toString(marketId)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = borrowToken;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "dolomiteBorrowProxy"),
            canSendValue: false,
            signature: "closeBorrowPosition(uint256,uint256,uint256[])",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Close Borrow Position of ",
                ERC20(borrowToken).symbol(),
                " in Dolomite BorrowPosition Market ID: ",
                vm.toString(marketId)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = borrowToken;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "dolomiteBorrowProxy"),
            canSendValue: false,
            signature: "repayAllForBorrowPosition(uint256,uint256,uint256,uint8)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Repay Borrow Position of ",
                ERC20(borrowToken).symbol(),
                " in Dolomite BorrowPosition Market ID: ",
                vm.toString(marketId)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = borrowToken;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "dolomiteBorrowProxy"),
            canSendValue: false,
            signature: "transferBetweenAccounts(uint256,uint256,uint256,uint256,uint8)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Transfer Borrow Position of ",
                ERC20(borrowToken).symbol(),
                " in Dolomite BorrowPosition Market ID: ",
                vm.toString(marketId),
                " to additional subaccount"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = borrowToken;
    }

    function _addDolomiteExtraAccountLeafs(ManageLeaf[] memory leafs, address borrowToken, address from, address to)
        internal
    {
        uint256 marketId =
            IDolomiteMargin(getAddress(sourceChain, "dolomiteMargin")).getMarketIdByTokenAddress(borrowToken);

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "dolomiteBorrowProxy"),
            canSendValue: false,
            signature: "openBorrowPositionWithDifferentAccounts(address,uint256,address,uint256,uint256,uint256,uint8)",
            argumentAddresses: new address[](3),
            description: string.concat(
                "Open Borrow Position of ",
                ERC20(borrowToken).symbol(),
                " in Dolomite BorrowPosition Market ID: ",
                vm.toString(marketId),
                " from ",
                vm.toString(from),
                " to ",
                vm.toString(to)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = from;
        leafs[leafIndex].argumentAddresses[1] = to;
        leafs[leafIndex].argumentAddresses[2] = borrowToken;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "dolomiteBorrowProxy"),
            canSendValue: false,
            signature: "closeBorrowPositionWithDifferentAccounts(address,uint256,address,uint256,uint256[])",
            argumentAddresses: new address[](3),
            description: string.concat(
                "Close Borrow Position of ",
                ERC20(borrowToken).symbol(),
                " in Dolomite BorrowPosition Market ID: ",
                vm.toString(marketId),
                " from ",
                vm.toString(from),
                " to ",
                vm.toString(to)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = from; //borrowAccountOwner
        leafs[leafIndex].argumentAddresses[1] = to;
        leafs[leafIndex].argumentAddresses[2] = borrowToken;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "dolomiteBorrowProxy"),
            canSendValue: false,
            signature: "transferBetweenAccountsWithDifferentAccounts(address,uint256,address,uint256,uint256,uint256,uint8)",
            argumentAddresses: new address[](3),
            description: string.concat(
                "Transfer ",
                ERC20(borrowToken).symbol(),
                " in Dolomite BorrowPosition Market ID: ",
                vm.toString(marketId),
                " from ",
                vm.toString(from),
                " to ",
                vm.toString(to)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = to; //TODO check this
        leafs[leafIndex].argumentAddresses[1] = from; //TODO this too
        leafs[leafIndex].argumentAddresses[2] = borrowToken;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "dolomiteBorrowProxy"),
            canSendValue: false,
            signature: "repayAllForBorrowPositionWithDifferentAccounts(address,uint256,address,uint256,uint256,uint8)",
            argumentAddresses: new address[](3),
            description: string.concat(
                "Repay ",
                ERC20(borrowToken).symbol(),
                " in Dolomite BorrowPosition Market ID: ",
                vm.toString(marketId),
                " from ",
                vm.toString(from),
                " to ",
                vm.toString(to)
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = from;
        leafs[leafIndex].argumentAddresses[1] = to;
        leafs[leafIndex].argumentAddresses[2] = borrowToken;
    }

    // ========================================= BGT Reward Vault =========================================
    function _addBGTRewardVaultLeafs(ManageLeaf[] memory leafs, address vault, address delegateStaker, address operator)
        internal
    {
        address stakingToken = IBGTRewardVault(vault).stakeToken();

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: stakingToken,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve BGT Reward Vault to spend: ", ERC20(stakingToken).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = vault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vault,
            canSendValue: false,
            signature: "stake(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Stake ", ERC20(stakingToken).symbol(), " in BGT Vault"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vault,
            canSendValue: false,
            signature: "withdraw(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Withdraw ", ERC20(stakingToken).symbol(), " from BGT Vault"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vault,
            canSendValue: false,
            signature: "getReward(address,address)",
            argumentAddresses: new address[](2),
            description: string.concat("Get reward for ", ERC20(stakingToken).symbol(), " BGT Vault"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vault,
            canSendValue: false,
            signature: "exit(address)",
            argumentAddresses: new address[](1),
            description: string.concat("Exit ", ERC20(stakingToken).symbol(), " BGT Vault"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        if (delegateStaker != address(0)) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: vault,
                canSendValue: false,
                signature: "delegateStake(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat(
                    "Delegate stake for ", ERC20(stakingToken).symbol(), " BGT Vault to: ", vm.toString(delegateStaker)
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = delegateStaker;

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: vault,
                canSendValue: false,
                signature: "delegateWithdraw(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat(
                    "Delegate withdraw for ",
                    ERC20(stakingToken).symbol(),
                    " BGT Vault from: ",
                    vm.toString(delegateStaker)
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = delegateStaker;
        }

        if (operator != address(0)) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: vault,
                canSendValue: false,
                signature: "setOperator(address)",
                argumentAddresses: new address[](1),
                description: string.concat("Get reward for ", ERC20(stakingToken).symbol(), " BGT Vault"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = operator;
        }
    }

    // ========================================= Silo Finance V2 =========================================
    function _addSiloV2Leafs(ManageLeaf[] memory leafs, address siloMarket, address[] memory incentivesControllers)
        internal
    {
        (address silo0, address silo1) = ISilo(siloMarket).getSilos();
        address[] memory silos = new address[](2);
        silos[0] = silo0;
        silos[1] = silo1;

        for (uint256 i = 0; i < silos.length; i++) {
            string memory underlyingName = ERC20(ERC4626(silos[i]).asset()).name();

            _addERC4626Leafs(leafs, ERC4626(silos[i]));

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: silos[i],
                canSendValue: false,
                signature: "deposit(uint256,address,uint8)",
                argumentAddresses: new address[](1),
                description: string.concat("Deposit ", underlyingName, " with type into Silo"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: silos[i],
                canSendValue: false,
                signature: "mint(uint256,address,uint8)",
                argumentAddresses: new address[](1),
                description: string.concat("Mint ", underlyingName, " with type into Silo"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: silos[i],
                canSendValue: false,
                signature: "withdraw(uint256,address,address,uint8)",
                argumentAddresses: new address[](2),
                description: string.concat("Withdraw ", underlyingName, " with type from Silo"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: silos[i],
                canSendValue: false,
                signature: "redeem(uint256,address,address,uint8)",
                argumentAddresses: new address[](2),
                description: string.concat("Redeem ", underlyingName, " with type from Silo"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: silos[i],
                canSendValue: false,
                signature: "borrow(uint256,address,address)",
                argumentAddresses: new address[](2),
                description: string.concat("Borrow ", underlyingName, " from Silo"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: silos[i],
                canSendValue: false,
                signature: "borrowShares(uint256,address,address)",
                argumentAddresses: new address[](2),
                description: string.concat("Borrow shares of ", underlyingName, " from Silo"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: silos[i],
                canSendValue: false,
                signature: "borrowSameAsset(uint256,address,address)",
                argumentAddresses: new address[](2),
                description: string.concat("Borrow same asset ", underlyingName, " from Silo"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: silos[i],
                canSendValue: false,
                signature: "repay(uint256,address)",
                argumentAddresses: new address[](1),
                description: string.concat("Repay ", underlyingName, " to Silo"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: silos[i],
                canSendValue: false,
                signature: "repayShares(uint256,address)",
                argumentAddresses: new address[](1),
                description: string.concat("Repay shares of ", underlyingName, " to Silo"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: silos[i],
                canSendValue: false,
                signature: "transitionCollateral(uint256,address,uint8)",
                argumentAddresses: new address[](1),
                description: string.concat("Transition Collateral in ", underlyingName, " Silo"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: silos[i],
                canSendValue: false,
                signature: "switchCollateralToThisSilo()",
                argumentAddresses: new address[](0),
                description: string.concat("Switch Collateral to ", underlyingName, " Silo"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: silos[i],
                canSendValue: false,
                signature: "accrueInterest()",
                argumentAddresses: new address[](0),
                description: string.concat("Accrue interest on ", underlyingName, " Silo"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
        }

        for (uint256 i = 0; i < incentivesControllers.length; i++) {
            if (incentivesControllers[i] != address(0)) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: incentivesControllers[i],
                    canSendValue: false,
                    signature: "claimRewards(address)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Claim All Rewards from Silo Incentives Controller"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: incentivesControllers[i],
                    canSendValue: false,
                    signature: "claimRewards(address,string[])",
                    argumentAddresses: new address[](1),
                    description: string.concat("Claim Rewards from market from Silo Incentives Controller"),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            }
        }
    }

    function _addSiloVaultLeafs(ManageLeaf[] memory leafs, address vault) internal {
        _addERC4626Leafs(leafs, ERC4626(vault));

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf({
            target: vault,
            canSendValue: false,
            signature: "claimRewards()",
            argumentAddresses: new address[](0),
            description: string.concat("Claim rewards from ", ERC4626(vault).name()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= LBTC Bridge =========================================
    function _addLBTCBridgeLeafs(ManageLeaf[] memory leafs, bytes32 toChain) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "LBTC"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve LBTC Bridge Wrapper to spend LBTC"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "lbtcBridge");

        // forge-lint: disable-next-line(unsafe-typecast)
        address toChain0 = address(bytes20(bytes16(toChain)));
        // forge-lint: disable-next-line(unsafe-typecast)
        address toChain1 = address(bytes20(bytes16(toChain << 128)));

        //kinda scuffed, can maybe just use one address?
        bytes32 boringVaultBytes = getBytes32(sourceChain, "boringVault");
        // forge-lint: disable-next-line(unsafe-typecast)
        address toAddress0 = address(bytes20(bytes16(boringVaultBytes)));
        // forge-lint: disable-next-line(unsafe-typecast)
        address toAddress1 = address(bytes20(bytes16(boringVaultBytes << 128)));

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "lbtcBridge"),
            canSendValue: true,
            signature: "deposit(bytes32,bytes32,uint64)",
            argumentAddresses: new address[](4),
            description: string.concat("Deposit LBTC to ChainID: ", vm.toString(toChain)),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = toChain0;
        leafs[leafIndex].argumentAddresses[1] = toChain1;
        leafs[leafIndex].argumentAddresses[2] = toAddress0;
        leafs[leafIndex].argumentAddresses[3] = toAddress1;
    }

    // ========================================= Spectra Finance =========================================

    function _addSpectraLeafs(
        ManageLeaf[] memory leafs,
        address spectraPool, //curve pool
        address PT,
        address YT,
        address swToken //spectra wrapped erc4626 or IBT
    )
        internal
    {
        address asset = address(ERC4626(swToken).asset());
        address vaultShare;
        try ISpectraVault(swToken).vaultShare() returns (address share) {
            vaultShare = share;
        } catch {
            vaultShare = swToken;
        }

        // approvals
        // asset -> swToken (wrap, unwrap)
        // vaultShare -> PT (IBT functions)
        // swToken -> approve curve pool
        // ptToken -> approve curve pool

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: asset,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve ", ERC4626(PT).symbol(), " to spend ", ERC20(asset).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = PT;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vaultShare,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve ", ERC4626(swToken).symbol(), " to spend ", ERC20(vaultShare).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = swToken;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vaultShare,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve ", ERC20(PT).symbol(), " to spend IBT ", ERC20(vaultShare).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = PT;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: swToken,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve ", ERC20(PT).symbol(), " to spend IBT ", ERC20(swToken).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = PT;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: swToken,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Spectra Curve Pool to spend ", ERC20(swToken).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = spectraPool;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: PT,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Spectra Curve Pool to spend ", ERC20(PT).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = spectraPool;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: swToken,
            canSendValue: false,
            signature: "wrap(uint256,address)",
            argumentAddresses: new address[](1),
            description: string.concat("Wrap ", ERC20(asset).symbol(), " into ", ERC4626(swToken).name()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: swToken,
            canSendValue: false,
            signature: "unwrap(uint256,address,address)",
            argumentAddresses: new address[](2),
            description: string.concat("Unwrap ", ERC20(asset).symbol(), " from ", ERC4626(swToken).name()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: PT,
            canSendValue: false,
            signature: "deposit(uint256,address,address,uint256)",
            argumentAddresses: new address[](2),
            description: string.concat(
                "Deposit ", ERC20(asset).symbol(), " into ", ERC4626(PT).name(), " with slippage check"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: PT,
            canSendValue: false,
            signature: "depositIBT(uint256,address)",
            argumentAddresses: new address[](1),
            description: string.concat("Deposit ", ERC20(vaultShare).symbol(), " into ", ERC4626(PT).name()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: PT,
            canSendValue: false,
            signature: "depositIBT(uint256,address,address,uint256)",
            argumentAddresses: new address[](2),
            description: string.concat(
                "Deposit ", ERC20(vaultShare).symbol(), " into ", ERC4626(PT).name(), " with slippage check"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: PT,
            canSendValue: false,
            signature: "redeem(uint256,address,address,uint256)",
            argumentAddresses: new address[](2),
            description: string.concat(
                "Redeem ", ERC4626(PT).name(), " for ", ERC20(asset).symbol(), " with slippage check"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: PT,
            canSendValue: false,
            signature: "redeemForIBT(uint256,address,address)",
            argumentAddresses: new address[](2),
            description: string.concat("Redeem ", ERC4626(PT).name(), " for ", ERC20(vaultShare).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: PT,
            canSendValue: false,
            signature: "redeemForIBT(uint256,address,address,uint256)",
            argumentAddresses: new address[](2),
            description: string.concat(
                "Redeem ", ERC4626(PT).name(), " for ", ERC20(vaultShare).symbol(), " with slippage check"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: PT,
            canSendValue: false,
            signature: "withdraw(uint256,address,address,uint256)",
            argumentAddresses: new address[](2),
            description: string.concat(
                "Withdraw ", ERC20(asset).symbol(), " from ", ERC4626(PT).name(), " with slippage check"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: PT,
            canSendValue: false,
            signature: "withdrawIBT(uint256,address,address)",
            argumentAddresses: new address[](2),
            description: string.concat("Withdraw ", ERC20(vaultShare).symbol(), " from ", ERC4626(PT).name()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: PT,
            canSendValue: false,
            signature: "withdrawIBT(uint256,address,address,uint256)",
            argumentAddresses: new address[](2),
            description: string.concat(
                "Withdraw ", ERC20(vaultShare).symbol(), " from ", ERC4626(PT).name(), " with slippage check"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: PT,
            canSendValue: false,
            signature: "updateYield(address)",
            argumentAddresses: new address[](1),
            description: string.concat("Update yield for Boring Vault"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: PT,
            canSendValue: false,
            signature: "claimYield(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Claim yield for Boring Vault"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: YT,
            canSendValue: false,
            signature: "burn(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Claim yield for Boring Vault"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: spectraPool,
            canSendValue: false,
            signature: "exchange(uint256,uint256,uint256,uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Exchange tokens in Spectra Pool"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: spectraPool,
            canSendValue: false,
            signature: "add_liquidity(uint256[2],uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Add liquidity in Spectra Pool"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: spectraPool,
            canSendValue: false,
            signature: "remove_liquidity(uint256,uint256[2])",
            argumentAddresses: new address[](0),
            description: string.concat("Remove liquidity from Spectra Pool"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        _addERC4626Leafs(leafs, ERC4626(swToken));
    }

    // ========================================= Cap =========================================
    function _addCapLeafs(ManageLeaf[] memory leafs, address[] memory assets) internal {
        for (uint256 i = 0; i < assets.length; i++) {
            // add approval for cUSD to accept each collateral token
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][assets[i]][getAddress(sourceChain, "cUSD")]) {
                ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][assets[i]][getAddress(sourceChain, "cUSD")] = true;
                leafIndex++;
                leafs[leafIndex] = ManageLeaf({
                    target: assets[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("approve cUSD to mint with ", ERC20(assets[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "cUSD");
            }

            // ability to mint cUSD with each input asset
            leafIndex++;
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "cUSD"),
                canSendValue: false,
                signature: "mint(address,uint256,uint256,address,uint256)",
                argumentAddresses: new address[](2),
                description: string.concat("mint cUSD with ", ERC20(assets[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = assets[i];
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            // ability to burn cUSD for each input asset
            leafIndex++;
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "cUSD"),
                canSendValue: false,
                signature: "burn(address,uint256,uint256,address,uint256)",
                argumentAddresses: new address[](2),
                description: string.concat("burn cUSD for ", ERC20(assets[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = assets[i];
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }

        // approval for stcUSD to stake cUSD
        leafIndex++;
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "cUSD"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("approve stcUSD to stake cUSD"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "stcUSD");

        // stake cUSD for stcUSD (ERC4626)
        {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "stcUSD"),
                canSendValue: false,
                signature: "deposit(uint256,address)",
                argumentAddresses: new address[](1),
                description: string.concat("stake (ERC4626 deposit) cUSD for stcUSD"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            leafIndex++;
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "stcUSD"),
                canSendValue: false,
                signature: "mint(uint256,address)",
                argumentAddresses: new address[](1),
                description: string.concat("stake (ERC4626 mint) cUSD for stcUSD"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }

        // unstake stcUSD for cUSD (ERC4626)
        {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "stcUSD"),
                canSendValue: false,
                signature: "withdraw(uint256,address,address)",
                argumentAddresses: new address[](2),
                description: string.concat("unstake (ERC4626 withdraw) stcUSD for cUSD"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            leafIndex++;
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "stcUSD"),
                canSendValue: false,
                signature: "redeem(uint256,address,address)",
                argumentAddresses: new address[](2),
                description: string.concat("unstake (ERC4626 redeem) stcUSD for cUSD"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
    }

    function _addCapWithdrawLeafs(ManageLeaf[] memory leafs, address[] memory assets) internal {
        for (uint256 i = 0; i < assets.length; i++) {
            // ability to burn/withdraw cUSD for each input asset
            leafIndex++;
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "cUSD"),
                canSendValue: false,
                signature: "burn(address,uint256,uint256,address,uint256)",
                argumentAddresses: new address[](2),
                description: string.concat("burn cUSD for ", ERC20(assets[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = assets[i];
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }

        // unstake stcUSD for cUSD (ERC4626)
        {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "stcUSD"),
                canSendValue: false,
                signature: "withdraw(uint256,address,address)",
                argumentAddresses: new address[](2),
                description: string.concat("unstake (ERC4626 withdraw) stcUSD for cUSD"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            leafIndex++;
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "stcUSD"),
                canSendValue: false,
                signature: "redeem(uint256,address,address)",
                argumentAddresses: new address[](2),
                description: string.concat("unstake (ERC4626 redeem) stcUSD for cUSD"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
    }

    // ========================================= Odos =========================================

    function _addOdosSwapLeafs(ManageLeaf[] memory leafs, address[] memory tokens, SwapKind[] memory kind) internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][tokens[i]][getAddress(sourceChain, "odosRouterV2")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: tokens[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Odos Router V2 to spend ", ERC20(tokens[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "odosRouterV2");
            }

            for (uint256 j = 0; j < tokens.length; j++) {
                if (i == j) continue;

                if (
                    !ownerToOdosSellTokenToBuyTokenToInTree[
                            getAddress(sourceChain, "boringVault")
                        ][tokens[i]][tokens[j]] && kind[j] != SwapKind.Sell
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "odosRouterV2"),
                        canSendValue: false,
                        signature: "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)",
                        argumentAddresses: new address[](4),
                        description: string.concat(
                            "Swap ", ERC20(tokens[i]).symbol(), " for ", ERC20(tokens[j]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = tokens[i];
                    leafs[leafIndex].argumentAddresses[1] = tokens[j];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "odosExecutor");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "odosRouterV2"),
                        canSendValue: false,
                        signature: "swapCompact()",
                        argumentAddresses: new address[](4),
                        description: string.concat(
                            "Swap Compact ", ERC20(tokens[i]).symbol(), " for ", ERC20(tokens[j]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = tokens[i];
                    leafs[leafIndex].argumentAddresses[1] = tokens[j];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "odosExecutor");

                    ownerToOdosSellTokenToBuyTokenToInTree[
                        getAddress(sourceChain, "boringVault")
                    ][tokens[i]][tokens[j]] = true;
                }

                if (
                    kind[i] == SwapKind.BuyAndSell
                        && !ownerToOdosSellTokenToBuyTokenToInTree[
                            getAddress(sourceChain, "boringVault")
                        ][tokens[j]][tokens[i]]
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "odosRouterV2"),
                        canSendValue: false,
                        signature: "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)",
                        argumentAddresses: new address[](4),
                        description: string.concat(
                            "Swap ", ERC20(tokens[j]).symbol(), " for ", ERC20(tokens[i]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = tokens[j];
                    leafs[leafIndex].argumentAddresses[1] = tokens[i];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "odosExecutor");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "odosRouterV2"),
                        canSendValue: false,
                        signature: "swapCompact()",
                        argumentAddresses: new address[](4),
                        description: string.concat(
                            "Swap Compact ", ERC20(tokens[j]).symbol(), " for ", ERC20(tokens[i]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = tokens[j];
                    leafs[leafIndex].argumentAddresses[1] = tokens[i];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "odosExecutor");

                    ownerToOdosSellTokenToBuyTokenToInTree[
                        getAddress(sourceChain, "boringVault")
                    ][tokens[j]][tokens[i]] = true;
                }
            }
        }
    }

    function _addOdosOwnedSwapLeafs(ManageLeaf[] memory leafs, address[] memory tokens, SwapKind[] memory kind)
        internal
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][tokens[i]][getAddress(sourceChain, "odosRouterV2")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: tokens[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Odos Router V2 to spend ", ERC20(tokens[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "odosRouterV2");
            }

            for (uint256 j = 0; j < tokens.length; j++) {
                if (i == j) continue;

                if (
                    !ownerToOdosSellTokenToBuyTokenToInTree[
                            getAddress(sourceChain, "boringVault")
                        ][tokens[i]][tokens[j]] && kind[j] != SwapKind.Sell
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "odosRouterV2"),
                        canSendValue: false,
                        signature: "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)",
                        argumentAddresses: new address[](3),
                        description: string.concat(
                            "Swap ", ERC20(tokens[i]).symbol(), " for ", ERC20(tokens[j]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = tokens[i];
                    leafs[leafIndex].argumentAddresses[1] = tokens[j];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "odosRouterV2"),
                        canSendValue: false,
                        signature: "swapCompact()",
                        argumentAddresses: new address[](3),
                        description: string.concat(
                            "Swap Compact ", ERC20(tokens[i]).symbol(), " for ", ERC20(tokens[j]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = tokens[i];
                    leafs[leafIndex].argumentAddresses[1] = tokens[j];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                    ownerToOdosSellTokenToBuyTokenToInTree[
                        getAddress(sourceChain, "boringVault")
                    ][tokens[i]][tokens[j]] = true;
                }

                if (
                    kind[i] == SwapKind.BuyAndSell
                        && !ownerToOdosSellTokenToBuyTokenToInTree[
                            getAddress(sourceChain, "boringVault")
                        ][tokens[j]][tokens[i]]
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "odosRouterV2"),
                        canSendValue: false,
                        signature: "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)",
                        argumentAddresses: new address[](3),
                        description: string.concat(
                            "Swap ", ERC20(tokens[j]).symbol(), " for ", ERC20(tokens[i]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = tokens[j];
                    leafs[leafIndex].argumentAddresses[1] = tokens[i];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "odosRouterV2"),
                        canSendValue: false,
                        signature: "swapCompact()",
                        argumentAddresses: new address[](3),
                        description: string.concat(
                            "Swap Compact ", ERC20(tokens[j]).symbol(), " for ", ERC20(tokens[i]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = tokens[j];
                    leafs[leafIndex].argumentAddresses[1] = tokens[i];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                    ownerToOdosSellTokenToBuyTokenToInTree[
                        getAddress(sourceChain, "boringVault")
                    ][tokens[j]][tokens[i]] = true;
                }
            }
        }
    }

    function _addOdosOneWaySwapLeafs(ManageLeaf[] memory leafs, address tokenA, address tokenB) internal {
        // add approval if not already added
        if (!ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][tokenA][getAddress(sourceChain, "odosRouterV2")]) {
            ownerToTokenToSpenderToApprovalInTree[
                getAddress(sourceChain, "boringVault")
            ][tokenA][getAddress(sourceChain, "odosRouterV2")] = true;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf({
                target: tokenA,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve Odos Router V2 to spend ", ERC20(tokenA).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "odosRouterV2");
        }

        // add swap from tokenA to tokenB
        if (!ownerToOdosSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokenA][tokenB]) {
            ownerToOdosSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokenA][tokenB] = true;

            leafIndex++;
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "odosRouterV2"),
                canSendValue: false,
                signature: "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)",
                argumentAddresses: new address[](4),
                description: string.concat("Swap ", ERC20(tokenA).symbol(), " for ", ERC20(tokenB).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = tokenA;
            leafs[leafIndex].argumentAddresses[1] = tokenB;
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "odosExecutor");

            leafIndex++;
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "odosRouterV2"),
                canSendValue: false,
                signature: "swapCompact()",
                argumentAddresses: new address[](4),
                description: string.concat("Swap Compact ", ERC20(tokenA).symbol(), " for ", ERC20(tokenB).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = tokenA;
            leafs[leafIndex].argumentAddresses[1] = tokenB;
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "odosExecutor");
        }
    }

    // ========================================= GlueX =========================================
    function _addGlueXLeafs(ManageLeaf[] memory leafs, address[] memory tokens, SwapKind[] memory kind) internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][tokens[i]][getAddress(sourceChain, "glueXRouter")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: tokens[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve GlueX Router to spend ", ERC20(tokens[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "glueXRouter");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: tokens[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Permit2 to spend ", ERC20(tokens[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "permit2");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: getAddress(sourceChain, "permit2"),
                    canSendValue: false,
                    signature: "approve(address,address,uint160,uint48)",
                    argumentAddresses: new address[](2),
                    description: string.concat(
                        "Use Permit2 to approve GlueX Router to spend ", ERC20(tokens[i]).symbol()
                    ),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = tokens[i];
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "glueXRouter");
            }

            for (uint256 j = 0; j < tokens.length; j++) {
                if (i == j) continue;

                if (
                    !ownerToGlueXSellTokenToBuyTokenToInTree[
                            getAddress(sourceChain, "boringVault")
                        ][tokens[i]][tokens[j]] && kind[j] != SwapKind.Sell
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "glueXRouter"),
                        canSendValue: false,
                        signature: "swap(address,(address,address,address,address,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,bool,bytes32),(address,uint256,bytes)[])",
                        argumentAddresses: new address[](5),
                        description: string.concat(
                            "Swap ", ERC20(tokens[i]).symbol(), " for ", ERC20(tokens[j]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "glueXExecutor");
                    leafs[leafIndex].argumentAddresses[1] = tokens[i];
                    leafs[leafIndex].argumentAddresses[2] = tokens[j];
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[4] = address(0);

                    ownerToGlueXSellTokenToBuyTokenToInTree[
                        getAddress(sourceChain, "boringVault")
                    ][tokens[j]][tokens[i]] = true;
                }

                if (
                    kind[i] == SwapKind.BuyAndSell
                        && !ownerToGlueXSellTokenToBuyTokenToInTree[
                            getAddress(sourceChain, "boringVault")
                        ][tokens[j]][tokens[i]]
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "glueXRouter"),
                        canSendValue: false,
                        signature: "swap(address,(address,address,address,address,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,bool,bytes32),(address,uint256,bytes)[])",
                        argumentAddresses: new address[](5),
                        description: string.concat(
                            "Swap ", ERC20(tokens[j]).symbol(), " for ", ERC20(tokens[i]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "glueXExecutor");
                    leafs[leafIndex].argumentAddresses[1] = tokens[j];
                    leafs[leafIndex].argumentAddresses[2] = tokens[i];
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[4] = address(0);

                    ownerToGlueXSellTokenToBuyTokenToInTree[
                        getAddress(sourceChain, "boringVault")
                    ][tokens[j]][tokens[i]] = true;
                }
            }
        }
    }

    // ========================================= Ooga Booga =========================================

    function _addOogaBoogaSwapLeafs(ManageLeaf[] memory leafs, address[] memory tokens, SwapKind[] memory kind)
        internal
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][tokens[i]][getAddress(sourceChain, "OBRouter")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: tokens[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Ooga Booga Router to spend ", ERC20(tokens[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "OBRouter");
            }

            for (uint256 j = 0; j < tokens.length; j++) {
                if (i == j) continue;

                if (
                    !ownerToOogaBoogaSellTokenToBuyTokenToInTree[
                            getAddress(sourceChain, "boringVault")
                        ][tokens[i]][tokens[j]] && kind[j] != SwapKind.Sell
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "OBRouter"),
                        canSendValue: false,
                        signature: "swap((address,uint256,address,uint256,uint256,address),bytes,address,uint32)",
                        argumentAddresses: new address[](4),
                        description: string.concat(
                            "Swap ", ERC20(tokens[i]).symbol(), " for ", ERC20(tokens[j]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = tokens[i];
                    leafs[leafIndex].argumentAddresses[1] = tokens[j];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "OBExecutor");

                    ownerToOogaBoogaSellTokenToBuyTokenToInTree[
                        getAddress(sourceChain, "boringVault")
                    ][tokens[i]][tokens[j]] = true;
                }

                if (
                    kind[i] == SwapKind.BuyAndSell
                        && !ownerToOogaBoogaSellTokenToBuyTokenToInTree[
                            getAddress(sourceChain, "boringVault")
                        ][tokens[j]][tokens[i]]
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "OBRouter"),
                        canSendValue: false,
                        signature: "swap((address,uint256,address,uint256,uint256,address),bytes,address,uint32)",
                        argumentAddresses: new address[](4),
                        description: string.concat(
                            "Swap ", ERC20(tokens[j]).symbol(), " for ", ERC20(tokens[i]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = tokens[j];
                    leafs[leafIndex].argumentAddresses[1] = tokens[i];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "OBExecutor");

                    ownerToOogaBoogaSellTokenToBuyTokenToInTree[
                        getAddress(sourceChain, "boringVault")
                    ][tokens[j]][tokens[i]] = true;
                }
            }
        }
    }

    // ========================================= Sushi Snwapper =========================================

    function _addSnwapLeafs(ManageLeaf[] memory leafs, address[] memory tokens, SwapKind[] memory kind) internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (!ownerToTokenToSpenderToApprovalInTree[
                    getAddress(sourceChain, "boringVault")
                ][tokens[i]][getAddress(sourceChain, "redSnwapperRouter")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf({
                    target: tokens[i],
                    canSendValue: false,
                    signature: "approve(address,uint256)",
                    argumentAddresses: new address[](1),
                    description: string.concat("Approve Red Snwapper Router to spend ", ERC20(tokens[i]).symbol()),
                    decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                });
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "redSnwapperRouter");
            }

            for (uint256 j = 0; j < tokens.length; j++) {
                if (i == j) continue;

                if (
                    !ownerToSushiSellTokenToBuyTokenToInTree[
                            getAddress(sourceChain, "boringVault")
                        ][tokens[i]][tokens[j]] && kind[j] != SwapKind.Sell
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "redSnwapperRouter"),
                        canSendValue: false,
                        signature: "snwap(address,uint256,address,address,uint256,address,bytes)",
                        argumentAddresses: new address[](4),
                        description: string.concat(
                            "Swap ", ERC20(tokens[i]).symbol(), " for ", ERC20(tokens[j]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = tokens[i];
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[2] = tokens[j];
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "redSnwapperExecutor");

                    ownerToSushiSellTokenToBuyTokenToInTree[
                        getAddress(sourceChain, "boringVault")
                    ][tokens[i]][tokens[j]] = true;
                }

                if (
                    kind[i] == SwapKind.BuyAndSell
                        && !ownerToSushiSellTokenToBuyTokenToInTree[
                            getAddress(sourceChain, "boringVault")
                        ][tokens[j]][tokens[i]]
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf({
                        target: getAddress(sourceChain, "redSnwapperRouter"),
                        canSendValue: false,
                        signature: "snwap(address,uint256,address,address,uint256,address,bytes)",
                        argumentAddresses: new address[](4),
                        description: string.concat(
                            "Swap ", ERC20(tokens[j]).symbol(), " for ", ERC20(tokens[i]).symbol()
                        ),
                        decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    });
                    leafs[leafIndex].argumentAddresses[0] = tokens[j];
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[2] = tokens[i];
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "redSnwapperExecutor");

                    ownerToSushiSellTokenToBuyTokenToInTree[
                        getAddress(sourceChain, "boringVault")
                    ][tokens[j]][tokens[i]] = true;
                }
            }
        }
    }

    // ========================================= Ambient =========================================

    /// @dev baseToken/quoteToken
    /// these are not interchangeable and must be exact for the pool being swapped or minting liq. ie USDE/ETH is not the same as ETH/USDE
    function _addAmbientLPLeafs(ManageLeaf[] memory leafs, address baseToken, address quoteToken) internal {
        if (baseToken != getAddress(sourceChain, "ETH")) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: baseToken,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve CrocSwapDex (Ambient) to spend ", ERC20(baseToken).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "crocSwapDex");
        }

        if (quoteToken != getAddress(sourceChain, "ETH")) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: quoteToken,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve CrocSwapDex (Ambient) to spend ", ERC20(quoteToken).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "crocSwapDex");
        }

        if (baseToken != getAddress(sourceChain, "ETH") && quoteToken != getAddress(sourceChain, "ETH")) {
            //used for every command that includes the warm path
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "crocSwapDex"),
                canSendValue: false,
                signature: "userCmd(uint16,bytes)",
                argumentAddresses: new address[](3),
                description: string.concat("Call usrCmd using 'WarmPath' with no ETH"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = baseToken; //base (these are set by pool maybe?)
            leafs[leafIndex].argumentAddresses[1] = quoteToken; //quote
            leafs[leafIndex].argumentAddresses[2] = address(0); //lp conduit (user owned)

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "crocSwapDex"),
                canSendValue: false,
                signature: "userCmd(uint16,bytes)",
                argumentAddresses: new address[](2),
                description: string.concat("Call userCmd using 'HotPath' or 'KnockoutPath' without ETH "),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = baseToken; //base (these are set by pool maybe?)
            leafs[leafIndex].argumentAddresses[1] = quoteToken; //quote
        } else {
            if (baseToken == getAddress(sourceChain, "ETH")) baseToken = address(0);
            if (quoteToken == getAddress(sourceChain, "ETH")) quoteToken = address(0);

            // used for minting positions
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "crocSwapDex"),
                canSendValue: true,
                signature: "userCmd(uint16,bytes)",
                argumentAddresses: new address[](3),
                description: string.concat("Call userCmd using 'WarmPath' with ETH "),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = baseToken; //base (these are set by pool maybe?)
            leafs[leafIndex].argumentAddresses[1] = quoteToken; //quote
            leafs[leafIndex].argumentAddresses[2] = address(0); //lp conduit (user owned)

            //Used for commands that don't include sending ETH (harvest, burn)
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "crocSwapDex"),
                canSendValue: false,
                signature: "userCmd(uint16,bytes)",
                argumentAddresses: new address[](3),
                description: string.concat("Call userCmd using 'WarmPath' without ETH"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = baseToken; //base (these are set by pool maybe?)
            leafs[leafIndex].argumentAddresses[1] = quoteToken; //quote
            leafs[leafIndex].argumentAddresses[2] = address(0); //lp conduit (user owned)

            //swapping eth to token, using knockout
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "crocSwapDex"),
                canSendValue: true,
                signature: "userCmd(uint16,bytes)",
                argumentAddresses: new address[](2),
                description: string.concat("Call userCmd using 'HotPath' or 'KnockoutPath' with ETH "),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = baseToken; //base (these are set by pool maybe?)
            leafs[leafIndex].argumentAddresses[1] = quoteToken; //quote

            //swapping token to eth, using knockout
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "crocSwapDex"),
                canSendValue: false,
                signature: "userCmd(uint16,bytes)",
                argumentAddresses: new address[](2),
                description: string.concat("Call userCmd using 'HotPath' or 'KnockoutPath' without ETH "),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = baseToken; //base (these are set by pool maybe?)
            leafs[leafIndex].argumentAddresses[1] = quoteToken; //quote
        }
    }

    function _addAmbientSwapLeafs(ManageLeaf[] memory leafs, address baseToken, address quoteToken) internal {
        if (baseToken != getAddress(sourceChain, "ETH")) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: baseToken,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve CrocSwapDex (Ambient) to spend ", ERC20(baseToken).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "crocSwapDex");
        }

        if (quoteToken != getAddress(sourceChain, "ETH")) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: quoteToken,
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve CrocSwapDex (Ambient) to spend ", ERC20(quoteToken).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "crocSwapDex");
        }

        // address base,
        // address quote,
        // uint256, /*poolIdx*/
        // bool, /*isBuy*/
        // bool, /*inBaseQty*/
        // uint128, /*qty*/
        // uint16, /*tip*/
        // uint128, /*limitPrice*/
        // uint128, /*minOut*/
        // uint8 /*reserveFlags*/
        if (baseToken != getAddress(sourceChain, "ETH") && quoteToken != getAddress(sourceChain, "ETH")) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "crocSwapDex"),
                canSendValue: false,
                signature: "swap(address,address,uint256,bool,bool,uint128,uint16,uint128,uint128,uint8)",
                argumentAddresses: new address[](2),
                description: string.concat(
                    "Swap using CrocSwapDex (Ambient) between ",
                    ERC20(baseToken).symbol(),
                    " and ",
                    ERC20(quoteToken).symbol()
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = baseToken;
            leafs[leafIndex].argumentAddresses[1] = quoteToken;
        } else {
            if (baseToken == getAddress(sourceChain, "ETH")) baseToken = address(0);
            if (quoteToken == getAddress(sourceChain, "ETH")) quoteToken = address(0);

            //add correct swap symbol if eth is quote or base (since it can be either)
            address erc20Token = baseToken == address(0) ? quoteToken : baseToken;

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "crocSwapDex"),
                canSendValue: true,
                signature: "swap(address,address,uint256,bool,bool,uint128,uint16,uint128,uint128,uint8)",
                argumentAddresses: new address[](2),
                description: string.concat(
                    "Swap using CrocSwapDex (Ambient) between ETH and ", ERC20(erc20Token).symbol()
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = baseToken;
            leafs[leafIndex].argumentAddresses[1] = quoteToken;

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "crocSwapDex"),
                canSendValue: false,
                signature: "swap(address,address,uint256,bool,bool,uint128,uint16,uint128,uint128,uint8)",
                argumentAddresses: new address[](2),
                description: string.concat(
                    "Swap using CrocSwapDex (Ambient) between ", ERC20(erc20Token).symbol(), " and ETH"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = baseToken;
            leafs[leafIndex].argumentAddresses[1] = quoteToken;
        }
    }

    // ========================================= Level Money / LevelUSD =========================================

    function _addLevelLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "USDC"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve USDC to be spent by Level Minter"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "levelShares");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "USDT"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve USDT to be spent by Level Minter"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "levelShares");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "lvlUSD"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve lvlUSD to be spent by Level Minter"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "levelMinter");

        //mintDefault
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "levelMinter"),
            canSendValue: false,
            signature: "mint((address,address,uint256,uint256))",
            argumentAddresses: new address[](2),
            description: string.concat("Mint lvlUSD with USDC"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "USDC");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "levelMinter"),
            canSendValue: false,
            signature: "mint((address,address,uint256,uint256))",
            argumentAddresses: new address[](2),
            description: string.concat("Mint lvlUSD with USDT"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "USDT");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "levelMinter"),
            canSendValue: false,
            signature: "initiateRedeem(address,uint256,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Initiate Redeem for USDC from lvlUSD"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDC");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "levelMinter"),
            canSendValue: false,
            signature: "initiateRedeem(address,uint256,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Initiate Redeem for USDT from lvlUSD"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDT");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "levelMinter"),
            canSendValue: false,
            signature: "completeRedeem(address,address)",
            argumentAddresses: new address[](2),
            description: string.concat("Complete Redeem for USDC"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDC");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "levelMinter"),
            canSendValue: false,
            signature: "completeRedeem(address,address)",
            argumentAddresses: new address[](2),
            description: string.concat("Complete Redeem for USDT"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDT");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "levelMinter"),
            canSendValue: false,
            signature: "redeem((uint8,address,address,address,uint256,uint256))",
            argumentAddresses: new address[](3),
            description: string.concat("Redeem for USDC (only if cooldown is off)"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "USDC");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "levelMinter"),
            canSendValue: false,
            signature: "redeem((uint8,address,address,address,uint256,uint256))",
            argumentAddresses: new address[](3),
            description: string.concat("Redeem for USDT (only if cooldown is off)"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "USDT");

        //add remaining functionality from exisiting helper functions
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "slvlUSD")));
        _addSLvlUSDWithdrawLeafs(leafs);
    }

    // ============================================= WeETH ==================================================

    function _addWeETHLeafs(ManageLeaf[] memory leafs, address ETH, address referral) internal {
        //if not native eth
        if (ETH != getAddress(sourceChain, "ETH") && ETH != address(0)) {
            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf({
                target: ETH,
                canSendValue: //will be weth on beraChain
                false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve etherFiL2SyncPool to spend WETH"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "etherFiL2SyncPool");

            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "etherFiL2SyncPool"),
                canSendValue: //target
                false,
                signature: "deposit(address,uint256,uint256,address)",
                argumentAddresses: new address[](2),
                description: string.concat("Deposit ETH into WeETH"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = ETH;
            leafs[leafIndex].argumentAddresses[1] = referral;
        } else {
            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf({
                target: getAddress(sourceChain, "etherFiL2SyncPool"),
                canSendValue: //target
                true,
                signature: "deposit(address,uint256,uint256,address)",
                argumentAddresses: new address[](2),
                description: string.concat("Deposit ETH into WeETH"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = ETH;
            leafs[leafIndex].argumentAddresses[1] = referral;
        }
    }

    // ========================================= ELX Claiming =========================================
    function _addELXClaimingLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "elxTokenDistributor"),
            canSendValue: false,
            signature: "claim(uint256,bytes32[],bytes)",
            argumentAddresses: new address[](0),
            description: string.concat("Claim ELX Airdrop"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= FLUID Claiming =========================================
    function _addFluidRewardsClaiming(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "fluidMerkleDistributor"),
            canSendValue: false,
            signature: "claim(address,uint256,uint8,bytes32,uint256,bytes32[],bytes)",
            argumentAddresses: new address[](1),
            description: string.concat("Claim FLUID rewards"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= KING Claiming =========================================
    function _addKingRewardsClaimingLeafs(ManageLeaf[] memory leafs, address[] memory depositTokens, address claimFor)
        internal
    {
        for (uint256 i = 0; i < depositTokens.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: depositTokens[i],
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve KING to spend ", ERC20(depositTokens[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "KING");
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "KING"),
            canSendValue: false,
            signature: "deposit(address[],uint256[],address)",
            argumentAddresses: new address[](1),
            description: string.concat("Deposit tokens for KING"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "KING"),
            canSendValue: false,
            signature: "redeem(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Redeem KING"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "kingMerkleDistributor"),
            canSendValue: false,
            signature: "claim(address,uint256,bytes32,bytes32[])",
            argumentAddresses: new address[](1),
            description: string.concat("Claim KING rewards"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = claimFor; //in practice should be boringVault
    }

    // ========================================= Derive =========================================

    function _addDeriveVaultLeafs(
        ManageLeaf[] memory leafs,
        address depositVault,
        address depositConnector,
        address withdrawVault,
        address withdrawConnector,
        address connectorPlugOnDeriveChain,
        address controllerOnMainnet,
        address deriveWalletOwnedByBoringVault
    ) internal {
        address deriveDepositToken = IDeriveVault(depositVault).token();
        string memory depositName = ERC20(deriveDepositToken).name();

        address deriveWithdrawToken = IDeriveVault(withdrawVault).token();
        string memory withdrawName = ERC20(deriveDepositToken).name();

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: deriveDepositToken,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Approve Derive ", depositName, " Deposit Vault to spend ", ERC20(deriveDepositToken).symbol()
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = depositVault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: deriveWithdrawToken,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Approve Derive ", withdrawName, " Withdraw Vault to spend ", ERC20(deriveWithdrawToken).symbol()
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = withdrawVault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: depositVault,
            canSendValue: true,
            signature: //fees
            "bridge(address,uint256,uint256,address,bytes,bytes)",
            argumentAddresses: new address[](4),
            description: string.concat(
                "Deposit ", ERC20(deriveDepositToken).symbol(), " into Derive ", depositName, " Vault"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = deriveWalletOwnedByBoringVault;
        leafs[leafIndex].argumentAddresses[1] = depositConnector;
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[3] = connectorPlugOnDeriveChain;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: withdrawVault,
            canSendValue: true,
            signature: //fees
            "bridge(address,uint256,uint256,address,bytes,bytes)",
            argumentAddresses: new address[](4),
            description: string.concat(
                "Withdraw ", ERC20(deriveWithdrawToken).symbol(), " From Derive ", withdrawName, " Vault"
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = deriveWalletOwnedByBoringVault;
        leafs[leafIndex].argumentAddresses[1] = withdrawConnector;
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[3] = controllerOnMainnet;
    }

    function _addDeriveClaimLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "rewardDistributor"),
            canSendValue: false,
            signature: "claimAll()",
            argumentAddresses: new address[](0),
            description: string.concat("Claim rewards on Derive"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        //====== stDRV ======

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "stDRV"),
            canSendValue: false,
            signature: "redeem(uint256,uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Claim rewards on Derive"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "stDRV"),
            canSendValue: false,
            signature: "cancelRedeem(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Cancel Redeem of Staked Derive"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "stDRV"),
            canSendValue: false,
            signature: "finalizeRedeem(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Finalize Redeem of Staked Derive"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    function _addDeriveBridgeLeafs(
        ManageLeaf[] memory leafs,
        address mintableERC20OnDerive,
        address socketControllerOnDerive,
        address connectorPlugOnDeriveChain
    ) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: mintableERC20OnDerive,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Withdraw Wrapper to spend ", ERC20(mintableERC20OnDerive).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "deriveWithdrawWrapper");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: mintableERC20OnDerive,
            canSendValue: false,
            signature: "withdrawToChain(address,uint256,address,address,address,uint256)",
            argumentAddresses: new address[](4),
            description: string.concat("Approve Withdraw Wrapper to spend ", ERC20(mintableERC20OnDerive).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = mintableERC20OnDerive;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[2] = socketControllerOnDerive;
        leafs[leafIndex].argumentAddresses[3] = connectorPlugOnDeriveChain;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: mintableERC20OnDerive,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Socket Controller to spend ", ERC20(mintableERC20OnDerive).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = socketControllerOnDerive;

        //bridge "token" back to mainnet
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: socketControllerOnDerive,
            canSendValue: true,
            signature: "bridge(address,uint256,uint256,address,bytes,bytes)",
            argumentAddresses: new address[](4),
            description: string.concat("Bridge using controller"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault"); //NOTE: this should be the address of the mainnet vault so make sure they match across chains
        leafs[leafIndex].argumentAddresses[1] = connectorPlugOnDeriveChain;
        leafs[leafIndex].argumentAddresses[2] = address(0);
        leafs[leafIndex].argumentAddresses[3] = address(0);
    }

    // ========================================= Agglayer Bridge =========================================
    // using `bridge` as a param here because we can swap out the bridge to work with any agglayer compatible network
    function _addAgglayerTokenLeafs(
        ManageLeaf[] memory leafs,
        address bridge,
        address token,
        uint32 fromChain,
        uint32 toChain
    ) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: token,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve zkEVM Compatible Bridge to spend", ERC20(token).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = bridge;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: bridge,
            canSendValue: false,
            signature: "bridgeAsset(uint32,address,uint256,address,bool,bytes)",
            argumentAddresses: new address[](3),
            description: string.concat("Bridge ", ERC20(token).symbol(), " using zkEVM Compatible Bridge"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = address(uint160(toChain));
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[2] = token;

        if (token == getAddress(sourceChain, "ETH")) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: bridge,
                canSendValue: true,
                signature: "bridgeAsset(uint32,address,uint256,address,bool,bytes)",
                argumentAddresses: new address[](3),
                description: string.concat("Bridge ETH using zkEVM Compatible Bridge"),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = address(uint160(toChain));
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = address(uint160(fromChain)); //zkEVM bridge expects native eth to be address(0)
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: bridge,
            canSendValue: false,
            signature: "claimAsset(bytes32[32],bytes32[32],uint256,bytes32,bytes32,uint32,address,uint32,address,uint256,bytes)",
            argumentAddresses: new address[](4),
            description: string.concat("Claim  ", ERC20(token).symbol(), " from zkEVM Compatible Bridge"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        leafs[leafIndex].argumentAddresses[0] = address(uint160(fromChain));
        leafs[leafIndex].argumentAddresses[1] = token;
        leafs[leafIndex].argumentAddresses[2] = address(uint160(fromChain));
        leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");

        ////bridge message
        ////unused for bridging assets, per agglayer team
        //unchecked {
        //    leafIndex++;
        //}
        //leafs[leafIndex] = ManageLeaf(
        //    bridge,
        //    false,
        //    "bridgeMessage(uint32,address,bool,bytes)",
        //    new address[](3),
        //    string.concat("Bridge message from zkEVM Compatible Bridge"),
        //    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        //);
        //leafs[leafIndex].argumentAddresses[0] = address(uint160(toChain));
        //leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain,  "boringVault");
        //leafs[leafIndex].argumentAddresses[2] = token;
        //
        ////claim message
        //unchecked {
        //    leafIndex++;
        //}
        //leafs[leafIndex] = ManageLeaf(
        //    bridge,
        //    false,
        //    "claimMessage(bytes32[32],bytes32[32],uint256,bytes32,bytes32,uint32,address,uint32,address,uint256,bytes)",
        //    new address[](4),
        //    string.concat("Claim message from zkEVM Compatible Bridge"),
        //    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        //);
        //leafs[leafIndex].argumentAddresses[0] = address(uint160(toChain));
        //leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain,  "boringVault");
        //leafs[leafIndex].argumentAddresses[2] = token;
    }

    // ========================================= CCTP Bridge =========================================
    // using `bridge` as a param here because we can swap out the bridge to work with any agglayer compatible network
    function _addCCTPBridgeLeafs(ManageLeaf[] memory leafs, uint32 toChain) internal {
        //approve USDC
        //bridge USDC depositForBurn
        //receiveMessage

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "USDC"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve USDC to be spent by USDC TokenMessengerV2"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "usdcTokenMessengerV2");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "usdcTokenMessengerV2"),
            canSendValue: false,
            signature: "depositForBurn(uint256,uint32,bytes32,address,bytes32,uint256,uint32)",
            argumentAddresses: new address[](4),
            description: string.concat("Bridge USDC to ", vm.toString(toChain)),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = address(uint160(toChain));
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "USDC");
        leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "usdcMessageTransmitterV2"),
            canSendValue: false,
            signature: "receiveMessage(bytes,bytes)",
            argumentAddresses: new address[](0),
            description: string.concat("Receive USDC from ", vm.toString(toChain)),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= Tac CrossChainLayer =========================================
    function _addTacCrossChainLeafs(ManageLeaf[] memory leafs, ERC20 tokenToBridge, string memory tvmAddress) internal {
        //approve CCL
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(tokenToBridge),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve USDT to be spent by CrossChainLayer"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "crossChainLayer");

        bytes memory tvmBytes = bytes(tvmAddress);

        require(tvmBytes.length >= 20, "tvmTarget too short");

        // Extract first address (bytes 0-19)
        address tvmTarget0;
        assembly {
            tvmTarget0 := mload(add(tvmBytes, 20)) // Read 32 bytes, take rightmost 20 (bytes 0-19)
        }

        // Extract second address (bytes 20-39) if available
        address tvmTarget1;
        if (tvmBytes.length > 20) {
            assembly {
                tvmTarget1 := mload(add(tvmBytes, 40)) // Read 32 bytes, take rightmost 20 (bytes 20-39)
            }
        }

        // Extract third address (bytes 40+) if available
        address tvmTarget2;
        if (tvmBytes.length > 40) {
            assembly {
                tvmTarget2 := mload(add(tvmBytes, 60)) // Read 32 bytes, take rightmost 20 (bytes 40-59)
            }
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "crossChainLayer"),
            canSendValue: true,
            signature: "sendMessage(uint256,bytes)",
            argumentAddresses: new address[](4),
            description: string.concat("Send message via CrossChainLayer"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = tvmTarget0;
        leafs[leafIndex].argumentAddresses[1] = tvmTarget1;
        leafs[leafIndex].argumentAddresses[2] = tvmTarget2;
        leafs[leafIndex].argumentAddresses[3] = address(tokenToBridge);

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "crossChainLayer"),
            canSendValue: false,
            signature: "sendMessage(uint256,bytes)",
            argumentAddresses: new address[](4),
            description: string.concat("Send message via CrossChainLayer"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = tvmTarget0;
        leafs[leafIndex].argumentAddresses[1] = tvmTarget1;
        leafs[leafIndex].argumentAddresses[2] = tvmTarget2;
        leafs[leafIndex].argumentAddresses[2] = address(tokenToBridge);
    }

    // ========================================= BoringChef =========================================
    function _addBoringChefClaimLeaf(ManageLeaf[] memory leafs, address boringChef) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: boringChef,
            canSendValue: false,
            signature: "claimRewards(uint256[])",
            argumentAddresses: new address[](0),
            description: string.concat("Claim rewards from BoringChef"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    function _addBoringChefClaimOnBehalfOfLeaf(ManageLeaf[] memory leafs, address boringChef, address user) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: boringChef,
            canSendValue: false,
            signature: "claimRewardsOnBehalfOfUser(uint256[],address)",
            argumentAddresses: new address[](1),
            description: string.concat("Claim rewards from BoringChef on behalf of user"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = user;
    }

    function _addBoringChefApproveRewardsLeafs(ManageLeaf[] memory leafs, address boringChef, address[] memory tokens)
        internal
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: tokens[i],
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat(
                    "Approve BoringChef to spend ", ERC20(tokens[i]).symbol(), " rewards owned by itself"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = boringChef;
        }
    }

    function _addBoringChefDistributeRewardsLeaf(ManageLeaf[] memory leafs, address boringChef, address[] memory tokens)
        internal
    {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: boringChef,
            canSendValue: false,
            signature: "distributeRewards(address[],uint256[],uint48[],uint48[])",
            argumentAddresses: new address[](tokens.length),
            description: string.concat("Distribute rewards from BoringChef"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        for (uint256 i = 0; i < tokens.length; i++) {
            leafs[leafIndex].argumentAddresses[i] = tokens[i];
        }
    }

    // ========================================= dvStETH  =========================================
    function _addDvStETHLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "WETH"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve Whitelisted Eth Wrapper to spend WETH"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "dvStethWhitelistedEthWrapper");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "dvStethWhitelistedEthWrapper"),
            canSendValue: false,
            signature: "deposit(address,uint256,address,address,address)",
            argumentAddresses: new address[](4),
            description: string.concat("Deposit into dvStETH "),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "WETH");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "dvstETH");
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[3] = address(0);

        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "dvStETHVault")));
    }

    function _addWSwellUnwrappingLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "WSWELL"),
            canSendValue: false,
            signature: "withdrawToByLockTimestamp(address,uint256,bool)",
            argumentAddresses: new address[](1),
            description: string.concat("Unwrap wSwell for Swell"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "WSWELL"),
            canSendValue: false,
            signature: "withdrawToByLockTimestamps(address,uint256[],bool)",
            argumentAddresses: new address[](1),
            description: string.concat("Unwrap wSwell for Swell with multiple lock timestamps"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    function _addrEULWrappingLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "rEUL"),
            canSendValue: false,
            signature: "withdrawToByLockTimestamp(address,uint256,bool)",
            argumentAddresses: new address[](1),
            description: string.concat("Unwrap rEUL for EUL"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "rEUL"),
            canSendValue: false,
            signature: "withdrawToByLockTimestamps(address,uint256[],bool)",
            argumentAddresses: new address[](1),
            description: string.concat("Unwrap rEUL for EUL with multiple lock timestamps"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= StakeStone =========================================

    function _addStoneLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "stoneVault"),
            canSendValue: true,
            signature: "deposit()",
            argumentAddresses: new address[](0),
            description: string.concat("Deposit Native ETH to STONE"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "stoneVault"),
            canSendValue: false,
            signature: "instantWithdraw(uint256,uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Instant withdraw Native ETH from STONE"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "STONE"),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve StoneVault to spend STONE for requestWithdraw"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "stoneVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "stoneVault"),
            canSendValue: false,
            signature: "requestWithdraw(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Request Withdraw Native ETH from STONE"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: getAddress(sourceChain, "stoneVault"),
            canSendValue: false,
            signature: "cancelWithdraw(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Cancel ETH withdraw request from STONE"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    function _addUltraYieldLeafs(ManageLeaf[] memory leafs, address vault) internal {
        _addERC4626Leafs(leafs, ERC4626(vault));
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vault,
            canSendValue: false,
            signature: "deposit(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Deposit to UltraYield Vault ", ERC20(vault).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vault,
            canSendValue: false,
            signature: "withdraw(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Withdraw from UltraYield Vault ", ERC20(vault).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vault,
            canSendValue: false,
            signature: "mint(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Redeem from UltraYield Vault ", ERC20(vault).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vault,
            canSendValue: false,
            signature: "redeem(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Redeem from UltraYield Vault ", ERC20(vault).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vault,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat(
                "Approve UltraYield Vault ", ERC20(vault).symbol(), " to spend", ERC20(vault).symbol()
            ),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = vault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: vault,
            canSendValue: false,
            signature: "requestRedeem(uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Request redeem from UltraYield Vault ", ERC20(vault).symbol()),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    function _addrFLRLeafs(ManageLeaf[] memory leafs, address rFLR) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: rFLR,
            canSendValue: false,
            signature: "claimRewards(uint256[],uint256)",
            argumentAddresses: new address[](0),
            description: string.concat("Claim rewards from rFLR"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: rFLR,
            canSendValue: false,
            signature: "withdraw(uint128,bool)",
            argumentAddresses: new address[](0),
            description: string.concat("Withdraw FLR/WFLR from rFLR"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: rFLR,
            canSendValue: false,
            signature: "withdrawAll(bool)",
            argumentAddresses: new address[](0),
            description: string.concat("Claim All FLR/WFLR from rFLR"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
    }

    // ========================================= Yearn V3 =========================================
    /// @notice uses the spectra decoder for these functions
    function _addYearnLeafs(ManageLeaf[] memory leafs, ERC4626 vault) internal {
        _addERC4626Leafs(leafs, vault);

        ERC20 asset = ERC20(vault.asset());

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(vault),
            canSendValue: false,
            signature: "redeem(uint256,address,address,uint256)",
            argumentAddresses: new address[](2),
            description: string.concat("Redeem ", vault.name(), " for ", asset.symbol(), " with slippage check"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(vault),
            canSendValue: false,
            signature: "withdraw(uint256,address,address,uint256)",
            argumentAddresses: new address[](2),
            description: string.concat("Withdraw ", asset.symbol(), " from ", vault.name(), " with slippage check"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Valantis =========================================

    function _addValantisLSTLeafs(ManageLeaf[] memory leafs, address pool, bool isUniversalPool) internal {
        address[] memory poolTokens = ISovereignPool(pool).getTokens();

        //approve STEXAMM (tokenIn, tokenOut)
        for (uint256 i = 0; i < poolTokens.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: poolTokens[i],
                canSendValue: false,
                signature: "approve(address,uint256)",
                argumentAddresses: new address[](1),
                description: string.concat("Approve STEXAMM to spend ", ERC20(poolTokens[i]).symbol()),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = pool;
        }

        require(poolTokens.length == 2, "pool tokens length > 2, leaves need fixing");

        if (!isUniversalPool) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: pool,
                canSendValue: false,
                signature: "swap((bool,bool,uint256,uint256,uint256,address,address,(bytes,bytes,bytes,bytes)))",
                argumentAddresses: new address[](2),
                description: string.concat(
                    "Swap ",
                    ERC20(poolTokens[0]).symbol(),
                    " for ",
                    ERC20(poolTokens[1]).symbol(),
                    "using Valantis Pool"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = poolTokens[1];

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf({
                target: pool,
                canSendValue: false,
                signature: "swap((bool,bool,uint256,uint256,uint256,address,address,(bytes,bytes,bytes,bytes)))",
                argumentAddresses: new address[](2),
                description: string.concat(
                    "Swap ",
                    ERC20(poolTokens[1]).symbol(),
                    " for ",
                    ERC20(poolTokens[0]).symbol(),
                    "using Valantis Pool"
                ),
                decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            });
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = poolTokens[0];
        } else {
            revert("universal pools not supported");
        }
    }

    // ========================================= JSON FUNCTIONS =========================================
    // TODO this should pass in a bool or something to generate leafs indicating that we want leaf indexes printed.
    bool addLeafIndex = false;

    function _generateTestLeafs(ManageLeaf[] memory leafs, bytes32[][] memory manageTree) internal {
        string memory filePath = "./leafs/TemporaryLeafs.json";
        addLeafIndex = true;
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
        addLeafIndex = false;
    }
    // TODO look at how deployment json is made, and refactor this to work that way, so files dont need to be formatted.

    function _generateLeafs(
        string memory filePath,
        ManageLeaf[] memory leafs,
        bytes32 manageRoot,
        bytes32[][] memory manageTree
    ) internal {
        if (vm.exists(filePath)) {
            // Need to delete it
            vm.removeFile(filePath);
        }
        vm.writeLine(filePath, "{ \"metadata\": ");
        string[] memory composition = new string[](5);
        composition[0] = "Bytes20(DECODER_AND_SANITIZER_ADDRESS)";
        composition[1] = "Bytes20(TARGET_ADDRESS)";
        composition[2] = "Bytes1(CAN_SEND_VALUE)";
        composition[3] = "Bytes4(TARGET_FUNCTION_SELECTOR)";
        composition[4] = "Bytes{N*20}(ADDRESS_ARGUMENT_0,...,ADDRESS_ARGUMENT_N)";
        string memory metadata = "ManageRoot";
        {
            // Determine how many leafs are used.
            uint256 usedLeafCount;
            for (uint256 i; i < leafs.length; ++i) {
                if (leafs[i].target != address(0)) {
                    usedLeafCount++;
                }
            }
            vm.serializeUint(metadata, "LeafCount", usedLeafCount);
        }
        vm.serializeUint(metadata, "TreeCapacity", leafs.length);
        vm.serializeString(metadata, "DigestComposition", composition);
        vm.serializeAddress(metadata, "BoringVaultAddress", getAddress(sourceChain, "boringVault"));
        vm.serializeAddress(
            metadata, "DecoderAndSanitizerAddress", getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        vm.serializeAddress(metadata, "ManagerAddress", getAddress(sourceChain, "managerAddress"));
        vm.serializeAddress(metadata, "AccountantAddress", getAddress(sourceChain, "accountantAddress"));
        string memory finalMetadata = vm.serializeBytes32(metadata, "ManageRoot", manageRoot);

        vm.writeLine(filePath, finalMetadata);
        vm.writeLine(filePath, ",");
        vm.writeLine(filePath, "\"leafs\": [");

        for (uint256 i; i < leafs.length; ++i) {
            string memory leaf = "leaf";
            if (addLeafIndex) vm.serializeUint(leaf, "LeafIndex", i);
            vm.serializeAddress(leaf, "TargetAddress", leafs[i].target);
            vm.serializeAddress(leaf, "DecoderAndSanitizerAddress", leafs[i].decoderAndSanitizer);
            vm.serializeBool(leaf, "CanSendValue", leafs[i].canSendValue);
            vm.serializeString(leaf, "FunctionSignature", leafs[i].signature);
            bytes4 sel = bytes4(keccak256(abi.encodePacked(leafs[i].signature)));
            string memory selector = Strings.toHexString(uint32(sel), 4);
            vm.serializeString(leaf, "FunctionSelector", selector);
            bytes memory packedData;
            for (uint256 j; j < leafs[i].argumentAddresses.length; ++j) {
                packedData = abi.encodePacked(packedData, leafs[i].argumentAddresses[j]);
            }
            vm.serializeBytes(leaf, "PackedArgumentAddresses", packedData);
            vm.serializeAddress(leaf, "AddressArguments", leafs[i].argumentAddresses);
            bytes32 digest = keccak256(
                abi.encodePacked(leafs[i].decoderAndSanitizer, leafs[i].target, leafs[i].canSendValue, sel, packedData)
            );
            vm.serializeBytes32(leaf, "LeafDigest", digest);

            string memory finalJson = vm.serializeString(leaf, "Description", leafs[i].description);

            // vm.writeJson(finalJson, filePath);
            vm.writeLine(filePath, finalJson);
            if (i != leafs.length - 1) {
                vm.writeLine(filePath, ",");
            }
        }
        vm.writeLine(filePath, "],");

        string memory merkleTreeName = "MerkleTree";
        string[][] memory merkleTree = new string[][](manageTree.length);
        for (uint256 k; k < manageTree.length; ++k) {
            merkleTree[k] = new string[](manageTree[k].length);
        }

        for (uint256 i; i < manageTree.length; ++i) {
            for (uint256 j; j < manageTree[i].length; ++j) {
                merkleTree[i][j] = vm.toString(manageTree[i][j]);
            }
        }

        string memory finalMerkleTree;
        for (uint256 i; i < merkleTree.length; ++i) {
            string memory layer = Strings.toString(merkleTree.length - (i + 1));
            finalMerkleTree = vm.serializeString(merkleTreeName, layer, merkleTree[i]);
        }
        vm.writeLine(filePath, "\"MerkleTree\": ");
        vm.writeLine(filePath, finalMerkleTree);
        vm.writeLine(filePath, "}");
    }

    // ========================================= HELPER FUNCTIONS =========================================

    struct ManageLeaf {
        address target;
        bool canSendValue;
        string signature;
        address[] argumentAddresses;
        string description;
        address decoderAndSanitizer;
    }

    error MerkleTreeHelper__DecoderAndSanitizerMissingFunction(string signature);

    function _verifyDecoderImplementsLeafsFunctionSelectors(ManageLeaf[] memory leafs) internal view {
        for (uint256 i; i < leafs.length; ++i) {
            bytes4 selector = bytes4(keccak256(abi.encodePacked(leafs[i].signature)));
            // This is the "selector" for an empty leaf.
            if (selector == 0xc5d24601) continue;
            (bool success, bytes memory returndata) =
                leafs[i].decoderAndSanitizer.staticcall(abi.encodePacked(selector));
            if (!success && returndata.length > 0) {
                // Make sure we did not revert from the `BaseDecoderAndSanitizer__FunctionSelectorNotSupported()` error.
                if (keccak256(returndata) == keccak256(abi.encodePacked(BASE_DECODER_UNSUPPORTED_SELECTOR))) {
                    revert MerkleTreeHelper__DecoderAndSanitizerMissingFunction(leafs[i].signature);
                }
            }
        }
    }

    function _buildTrees(bytes32[][] memory merkleTreeIn) internal pure returns (bytes32[][] memory merkleTreeOut) {
        // We are adding another row to the merkle tree, so make merkleTreeOut be 1 longer.
        uint256 merkleTreeIn_length = merkleTreeIn.length;
        merkleTreeOut = new bytes32[][](merkleTreeIn_length + 1);
        uint256 layer_length;
        // Iterate through merkleTreeIn to copy over data.
        for (uint256 i; i < merkleTreeIn_length; ++i) {
            layer_length = merkleTreeIn[i].length;
            merkleTreeOut[i] = new bytes32[](layer_length);
            for (uint256 j; j < layer_length; ++j) {
                merkleTreeOut[i][j] = merkleTreeIn[i][j];
            }
        }

        uint256 next_layer_length;
        if (layer_length % 2 != 0) {
            next_layer_length = (layer_length + 1) / 2;
        } else {
            next_layer_length = layer_length / 2;
        }
        merkleTreeOut[merkleTreeIn_length] = new bytes32[](next_layer_length);
        uint256 count;
        for (uint256 i; i < layer_length; i += 2) {
            if (i + 1 < layer_length) {
                merkleTreeOut[merkleTreeIn_length][count] =
                    _hashPair(merkleTreeIn[merkleTreeIn_length - 1][i], merkleTreeIn[merkleTreeIn_length - 1][i + 1]);
            } else {
                // Odd leaf: duplicate it to form its own pair.
                merkleTreeOut[merkleTreeIn_length][count] =
                    _hashPair(merkleTreeIn[merkleTreeIn_length - 1][i], merkleTreeIn[merkleTreeIn_length - 1][i]);
            }
            count++;
        }

        if (next_layer_length > 1) {
            // We need to process the next layer of leaves.
            merkleTreeOut = _buildTrees(merkleTreeOut);
        }
    }

    function _generateMerkleTree(ManageLeaf[] memory manageLeafs) internal pure returns (bytes32[][] memory tree) {
        uint256 leafsLength = manageLeafs.length;
        bytes32[][] memory leafs = new bytes32[][](1);
        leafs[0] = new bytes32[](leafsLength);
        for (uint256 i; i < leafsLength; ++i) {
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(
                manageLeafs[i].decoderAndSanitizer, manageLeafs[i].target, manageLeafs[i].canSendValue, selector
            );
            uint256 argumentAddressesLength = manageLeafs[i].argumentAddresses.length;
            for (uint256 j; j < argumentAddressesLength; ++j) {
                rawDigest = abi.encodePacked(rawDigest, manageLeafs[i].argumentAddresses[j]);
            }
            leafs[0][i] = keccak256(rawDigest);
        }
        tree = _buildTrees(leafs);
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }

    function _getPoolAddressFromPoolId(bytes32 poolId) internal pure returns (address) {
        return address(uint160(uint256(poolId >> 96)));
    }

    function _getProofsUsingTree(ManageLeaf[] memory manageLeafs, bytes32[][] memory tree)
        internal
        view
        returns (bytes32[][] memory proofs)
    {
        proofs = new bytes32[][](manageLeafs.length);
        for (uint256 i; i < manageLeafs.length; ++i) {
            // Generate manage proof.
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(
                getAddress(sourceChain, "rawDataDecoderAndSanitizer"),
                manageLeafs[i].target,
                manageLeafs[i].canSendValue,
                selector
            );
            uint256 argumentAddressesLength = manageLeafs[i].argumentAddresses.length;
            for (uint256 j; j < argumentAddressesLength; ++j) {
                rawDigest = abi.encodePacked(rawDigest, manageLeafs[i].argumentAddresses[j]);
            }
            bytes32 leaf = keccak256(rawDigest);
            proofs[i] = _generateProof(leaf, tree);
        }
    }

    // ========================================= sGHO Staking =========================================

    function _addSGHOLeafs(ManageLeaf[] memory leafs) internal {
        address stkGHO = getAddress(sourceChain, "stkGHO");
        address gho = getAddress(sourceChain, "GHO");
        address boringVault_ = getAddress(sourceChain, "boringVault");

        // Approve GHO for stkGHO
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: gho,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Approve stkGHO to spend GHO",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = stkGHO;

        // Stake GHO for sGHO
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: stkGHO,
            canSendValue: false,
            signature: "stake(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Stake GHO into stkGHO",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = boringVault_;

        // Cooldown
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: stkGHO,
            canSendValue: false,
            signature: "cooldown()",
            argumentAddresses: new address[](0),
            description: "Activate stkGHO cooldown",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });

        // Redeem sGHO for GHO
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: stkGHO,
            canSendValue: false,
            signature: "redeem(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Redeem stkGHO for GHO",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = boringVault_;
    }

    // ========================================= GHO GSM =========================================

    function _addGHOGSMLeafs(ManageLeaf[] memory leafs, address gsm, ERC20 underlying) internal {
        address gho = getAddress(sourceChain, "GHO");
        address boringVault_ = getAddress(sourceChain, "boringVault");
        string memory underlyingSymbol = underlying.symbol();

        // Approve GHO for GSM
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: gho,
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: "Approve GSM to spend GHO",
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = gsm;

        // Approve underlying for GSM
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: address(underlying),
            canSendValue: false,
            signature: "approve(address,uint256)",
            argumentAddresses: new address[](1),
            description: string.concat("Approve GSM to spend ", underlyingSymbol),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = gsm;

        // buyAsset
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: gsm,
            canSendValue: false,
            signature: "buyAsset(uint256,address)",
            argumentAddresses: new address[](1),
            description: string.concat("Buy ", underlyingSymbol, " from GSM with GHO"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = boringVault_;

        // sellAsset
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf({
            target: gsm,
            canSendValue: false,
            signature: "sellAsset(uint256,address)",
            argumentAddresses: new address[](1),
            description: string.concat("Sell ", underlyingSymbol, " to GSM for GHO"),
            decoderAndSanitizer: getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        });
        leafs[leafIndex].argumentAddresses[0] = boringVault_;
    }

    function _generateProof(bytes32 leaf, bytes32[][] memory tree) internal pure returns (bytes32[] memory proof) {
        // The length of each proof is the height of the tree - 1.
        uint256 tree_length = tree.length;
        proof = new bytes32[](tree_length - 1);

        // Build the proof
        for (uint256 i; i < tree_length - 1; ++i) {
            // For each layer we need to find the leaf.
            for (uint256 j; j < tree[i].length; ++j) {
                if (leaf == tree[i][j]) {
                    // We have found the leaf, so now figure out if the proof needs the next leaf or the previous one.
                    if (j % 2 == 0) {
                        // Even index: pair with next element, or self if last in odd-length layer.
                        proof[i] = (j + 1 < tree[i].length) ? tree[i][j + 1] : tree[i][j];
                    } else {
                        proof[i] = tree[i][j - 1];
                    }
                    leaf = _hashPair(leaf, proof[i]);
                    break;
                } else if (j == tree[i].length - 1) {
                    // We have reached the end of the layer and have not found the leaf.
                    revert("Leaf not found in tree");
                }
            }
        }
    }
}

interface IMB {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function idToMarketParams(bytes32 id) external view returns (MarketParams memory);
}

interface PendleMarket {
    function readTokens() external view returns (address, address, address);
}

interface PendleSy {
    function getTokensIn() external view returns (address[] memory);
    function getTokensOut() external view returns (address[] memory);
    function assetInfo() external view returns (uint8, ERC20, uint8);
}

interface UniswapV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
}

interface CurvePool {
    function coins(uint256 i) external view returns (address);
}

interface ICurveGauge {
    function lp_token() external view returns (address);
}

interface BalancerVault {
    function getPoolTokens(bytes32) external view returns (ERC20[] memory, uint256[] memory, uint256);
}

interface VelodromV2Gauge {
    function stakingToken() external view returns (address);
}

interface VaultSupervisor {
    function delegationSupervisor() external view returns (address);
}

interface IInfraredVault {
    function stakingToken() external view returns (address);
}

interface IKodiakIsland {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function name() external view returns (string memory);
}

interface IUniswapV2Factory {
    function getPair(address token0, address token1) external view returns (address);
}

interface IDolomiteMargin {
    function getMarketIdByTokenAddress(address token) external view returns (uint256);
}

interface ISilo {
    function SILO_ID() external view returns (uint256);
    function getSilos() external view returns (address, address);
}

interface IGoldiVault {
    function depositToken() external view returns (address);
    function ot() external view returns (address);
    function yt() external view returns (address);
}

interface ISpectraVault {
    function vaultShare() external view returns (address);
    function underlying() external view returns (address);
}

interface IConvexFXVault {
    function stakingToken() external view returns (address);
}

interface IVaultExplorer {
    function getPoolTokens(address _pool) external view returns (address[] memory tokens);
}

interface IBalancerV3Pool {
    function name() external view returns (string memory);
}

interface IBGTRewardVault {
    function stakeToken() external view returns (address);
}

interface IDeriveVault {
    function token() external view returns (address);
}

interface ITeller {
    function vault() external view returns (address);
}

interface IScrollGateway {
    function getERC20Gateway(address token) external view returns (address);
}

interface ISovereignPool {
    function getTokens() external view returns (address[] memory);
}
