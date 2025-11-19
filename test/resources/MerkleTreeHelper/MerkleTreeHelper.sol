// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {ChainValues} from "test/resources/ChainValues.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import "forge-std/Base.sol";
import "forge-std/Test.sol";

contract MerkleTreeHelper is CommonBase, ChainValues, Test {
    using Address for address;

    string public sourceChain;
    uint256 leafIndex = type(uint256).max;

    mapping(address => mapping(address => mapping(address => bool))) public ownerToTokenToSpenderToApprovalInTree;
    mapping(address => mapping(address => mapping(address => bool))) public ownerToOneInchSellTokenToBuyTokenToInTree;
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
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][assets[i]][getAddress(
                    sourceChain, "aggregationRouterV5"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    assets[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve 1Inch router to spend ", ERC20(assets[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "aggregationRouterV5");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][assets[i]][getAddress(
                    sourceChain, "aggregationRouterV5"
                )] = true;
            }
            // Iterate through the list again.
            for (uint256 j; j < assets.length; ++j) {
                // Skip if we are on the same index
                if (i == j) {
                    continue;
                }
                if (
                    !ownerToOneInchSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][assets[i]][assets[j]]
                        && kind[j] != SwapKind.Sell
                ) {
                    // Add sell swap.
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "aggregationRouterV5"),
                        false,
                        "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                        new address[](5),
                        string.concat(
                            "Swap ",
                            ERC20(assets[i]).symbol(),
                            " for ",
                            ERC20(assets[j]).symbol(),
                            " using 1inch router"
                        ),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "oneInchExecutor");
                    leafs[leafIndex].argumentAddresses[1] = assets[i];
                    leafs[leafIndex].argumentAddresses[2] = assets[j];
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "oneInchExecutor");
                    leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
                    ownerToOneInchSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][assets[i]][assets[j]]
                    = true;
                }

                if (
                    kind[i] == SwapKind.BuyAndSell
                        && !ownerToOneInchSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][assets[j]][assets[i]]
                ) {
                    // Add buy swap.
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "aggregationRouterV5"),
                        false,
                        "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                        new address[](5),
                        string.concat(
                            "Swap ",
                            ERC20(assets[j]).symbol(),
                            " for ",
                            ERC20(assets[i]).symbol(),
                            " using 1inch router"
                        ),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "oneInchExecutor");
                    leafs[leafIndex].argumentAddresses[1] = assets[j];
                    leafs[leafIndex].argumentAddresses[2] = assets[i];
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "oneInchExecutor");
                    leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
                    ownerToOneInchSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][assets[j]][assets[i]]
                    = true;
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
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][assets[i]][getAddress(
                    sourceChain, "aggregationRouterV5"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    assets[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve 1Inch router to spend ", ERC20(assets[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "aggregationRouterV5");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][assets[i]][getAddress(
                    sourceChain, "aggregationRouterV5"
                )] = true;
            }
            // Iterate through the list again.
            for (uint256 j; j < assets.length; ++j) {
                // Skip if we are on the same index
                if (i == j) {
                    continue;
                }
                if (
                    !ownerToOneInchSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][assets[i]][assets[j]]
                        && kind[j] != SwapKind.Sell
                ) {
                    // Add sell swap.
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "aggregationRouterV5"),
                        false,
                        "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                        new address[](3),
                        string.concat(
                            "Swap ",
                            ERC20(assets[i]).symbol(),
                            " for ",
                            ERC20(assets[j]).symbol(),
                            " using 1inch router"
                        ),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = assets[i];
                    leafs[leafIndex].argumentAddresses[1] = assets[j];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
                    ownerToOneInchSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][assets[i]][assets[j]]
                    = true;
                }

                if (
                    kind[i] == SwapKind.BuyAndSell
                        && !ownerToOneInchSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][assets[j]][assets[i]]
                ) {
                    // Add buy swap.
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "aggregationRouterV5"),
                        false,
                        "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                        new address[](3),
                        string.concat(
                            "Swap ",
                            ERC20(assets[j]).symbol(),
                            " for ",
                            ERC20(assets[i]).symbol(),
                            " using 1inch router"
                        ),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = assets[j];
                    leafs[leafIndex].argumentAddresses[1] = assets[i];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
                    ownerToOneInchSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][assets[j]][assets[i]]
                    = true;
                }
            }
        }
    }

    function _addLeafsFor1InchUniswapV3Swapping(ManageLeaf[] memory leafs, address pool) internal {
        UniswapV3Pool uniswapV3Pool = UniswapV3Pool(pool);
        address token0 = uniswapV3Pool.token0();
        address token1 = uniswapV3Pool.token1();
        // Add approval leaf if not already added
        if (
            !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0][getAddress(
                sourceChain, "aggregationRouterV5"
            )]
        ) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                token0,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve 1Inch router to spend ", ERC20(token0).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "aggregationRouterV5");
            ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0][getAddress(
                sourceChain, "aggregationRouterV5"
            )] = true;
        }
        if (
            !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1][getAddress(
                sourceChain, "aggregationRouterV5"
            )]
        ) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                token1,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve 1Inch router to spend ", ERC20(token1).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "aggregationRouterV5");
            ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1][getAddress(
                sourceChain, "aggregationRouterV5"
            )] = true;
        }
        uint256 feeInBps = uniswapV3Pool.fee() / 100;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "aggregationRouterV5"),
            false,
            "uniswapV3Swap(uint256,uint256,uint256[])",
            new address[](1),
            string.concat(
                "Swap between ",
                ERC20(token0).symbol(),
                " and ",
                ERC20(token1).symbol(),
                " with ",
                vm.toString(feeInBps),
                " bps fee on UniswapV3 using 1inch router"
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = pool;
    }

    // ========================================= Curve/Convex =========================================
    // TODO need to use this in the test suite.
    function _addCurveLeafs(ManageLeaf[] memory leafs, address poolAddress, uint256 coinCount, address gauge)
        internal
    {
        CurvePool pool = CurvePool(poolAddress);
        ERC20[] memory coins = new ERC20[](coinCount);

        // Approve pool to spend tokens.
        for (uint256 i; i < coinCount; i++) {
            coins[i] = ERC20(pool.coins(i));
            // Approvals.
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(coins[i])][poolAddress]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(coins[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Curve pool to spend ", coins[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = poolAddress;
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(coins[i])][poolAddress]
                = true;
            }
        }

        // Add liquidity.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            poolAddress,
            false,
            "add_liquidity(uint256[],uint256)",
            new address[](0),
            string.concat("Add liquidity to Curve pool"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Remove liquidity.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            poolAddress,
            false,
            "remove_liquidity(uint256,uint256[])",
            new address[](0),
            string.concat("Remove liquidity from Curve pool"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        if (gauge != address(0)) {
            address lpToken = ICurveGauge(gauge).lp_token();

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                lpToken,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Curve gauge to spend ", ERC20(lpToken).name()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = gauge;

            // Deposit into gauge.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauge,
                false,
                "deposit(uint256,address)",
                new address[](1),
                string.concat("Deposit ", ERC20(lpToken).name(), " into Curve gauge"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Withdraw from gauge.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauge,
                false,
                "withdraw(uint256)",
                new address[](0),
                string.concat("Withdraw ", ERC20(lpToken).name(), " from Curve gauge"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );

            // Claim rewards.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauge,
                false,
                "claim_rewards(address)",
                new address[](1),
                string.concat("Claim rewards from Curve gauge"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }
    }

    function _addCurveGaugeLeafs(ManageLeaf[] memory leafs, address gauge) internal {
        address lpToken = ICurveGauge(gauge).lp_token();

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            lpToken,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Curve gauge to spend ", ERC20(lpToken).name()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = gauge;

        // Deposit into gauge.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            gauge,
            false,
            "deposit(uint256,address)",
            new address[](1),
            string.concat("Deposit ", ERC20(lpToken).name(), " into Curve gauge"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Withdraw from gauge.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            gauge,
            false,
            "withdraw(uint256)",
            new address[](0),
            string.concat("Withdraw ", ERC20(lpToken).name(), " from Curve gauge"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Claim rewards.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            gauge,
            false,
            "claim_rewards(address)",
            new address[](1),
            string.concat("Claim rewards from Curve gauge"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    function _addCRVClaimingLeafs(ManageLeaf[] memory leafs, address gauge) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "curve_CRV_claiming"),
            false,
            "mint(address)",
            new address[](1),
            string.concat("Claim CRV Rewards from Curve gauge"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = gauge;
    }

    function _addConvexLeafs(ManageLeaf[] memory leafs, ERC20 token, address rewardsContract) internal {
        // Approve convexCurveMainnetBooster to spend lp tokens.
        if (
            !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(token)][getAddress(
                sourceChain, "convexCurveMainnetBooster"
            )]
        ) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(token),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Convex Curve Mainnet Booster to spend ", token.symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "convexCurveMainnetBooster");
            ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(token)][getAddress(
                sourceChain, "convexCurveMainnetBooster"
            )] = true;
        }

        // Deposit into convexCurveMainnetBooster.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "convexCurveMainnetBooster"),
            false,
            "deposit(uint256,uint256,bool)",
            new address[](0),
            "Deposit into Convex Curve Mainnet Booster",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Withdraw from rewardsContract.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            rewardsContract,
            false,
            "withdrawAndUnwrap(uint256,bool)",
            new address[](0),
            "Withdraw and unwrap from Convex Curve Rewards Contract",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Get rewards from rewardsContract.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            rewardsContract,
            false,
            "getReward(address,bool)",
            new address[](1),
            "Get rewards from Convex Curve Rewards Contract",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        leafs[leafIndex] = ManageLeaf(
            address(coins0),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Curve ", coins0.symbol(), "/", coins1.symbol(), " pool to spend ", coins0.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = curvePool;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(coins1),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Curve ", coins0.symbol(), "/", coins1.symbol(), " pool to spend ", coins1.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = curvePool;
        // Swapping.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            curvePool,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            string.concat("Swap using Curve ", coins0.symbol(), "/", coins1.symbol(), " pool"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        leafs[leafIndex] = ManageLeaf(
            address(coins0),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat(
                "Approve Curve ",
                coins0.symbol(),
                "/",
                coins1.symbol(),
                "/",
                coins2.symbol(),
                " pool to spend ",
                coins0.symbol()
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = curvePool;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(coins1),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat(
                "Approve Curve ",
                coins0.symbol(),
                "/",
                coins1.symbol(),
                "/",
                coins2.symbol(),
                " pool to spend ",
                coins1.symbol()
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = curvePool;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(coins2),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat(
                "Approve Curve ",
                coins0.symbol(),
                "/",
                coins1.symbol(),
                "/",
                coins2.symbol(),
                " pool to spend ",
                coins2.symbol()
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = curvePool;
        // Swapping.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            curvePool,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            string.concat("Swap using Curve ", coins0.symbol(), "/", coins1.symbol(), "/", coins2.symbol(), " pool"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    function _addConvexFXBoosterLeafs(ManageLeaf[] memory leafs, address stakingAddress, address stakingToken)
        internal
    {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "convexFXBooster"),
            false,
            "createVault(uint256)",
            new address[](2),
            string.concat("Create Vault for ", ERC20(stakingToken).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = stakingAddress;
        leafs[leafIndex].argumentAddresses[1] = stakingToken;
    }

    function _addConvexFXVaultLeafs(ManageLeaf[] memory leafs, address fxVault) internal {
        address stakingToken = IConvexFXVault(fxVault).stakingToken();

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            stakingToken,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Created FXVault to spend ", ERC20(stakingToken).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = fxVault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            fxVault,
            false,
            "deposit(uint256,bool)",
            new address[](0),
            string.concat("Deposit ", ERC20(stakingToken).symbol(), " into created Convex FX Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            fxVault,
            false,
            "withdraw(uint256)",
            new address[](0),
            string.concat("Withdraw ", ERC20(stakingToken).symbol(), " from created Convex FX Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            fxVault,
            false,
            "getReward(bool)",
            new address[](0),
            string.concat("Get Reward from ", ERC20(stakingToken).symbol(), " Convex FX Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            fxVault,
            false,
            "transferTokens(address[])",
            new address[](0),
            string.concat("Rescue Tokens from ", ERC20(stakingToken).symbol(), " Convex FX Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        leafs[leafIndex] = ManageLeaf(
            address(Usd0),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Usd0PP to spend ", Usd0.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(Usd0PP);

        // Approve Usd0 to be swapped in swapper engine.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(Usd0),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Swapper Engine to spend ", Usd0.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(swapperEngine);

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(USDC),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Usual Swapper Engine to spend ", USDC.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(swapperEngine);

        // Call mint on Usd0PP.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(Usd0PP),
            false,
            "mint(uint256)",
            new address[](0),
            string.concat("Mint Usd0PP"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        //Call unlock on Usd0pp
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(Usd0PP),
            false,
            "unlockUsd0ppFloorPrice(uint256)",
            new address[](0),
            string.concat("Unlock Usd0PP at the USD0 floor price"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Call unwrap on Usd0PP.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(Usd0PP),
            false,
            "unwrap()",
            new address[](0),
            string.concat("Unwrap Usd0PP"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(swapperEngine),
            false,
            "depositUSDC(uint256)",
            new address[](0),
            string.concat("Deposit USDC to swap for USD0"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(swapperEngine),
            false,
            "provideUsd0ReceiveUSDC(address,uint256,uint256[],bool)",
            new address[](1),
            string.concat("Deposit USDC to swap for USD0"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(swapperEngine),
            false,
            "swapUsd0(address,uint256,uint256[],bool)",
            new address[](1),
            string.concat("Swap USD0 for USDC"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(swapperEngine),
            false,
            "withdrawUSDC(uint256)",
            new address[](0),
            string.concat("Cancel order for USDC swap"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
            leafs[leafIndex] = ManageLeaf(
                address(routerTokensIn[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Treehouse Router to spend ", routerTokensIn[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = router;

            // Deposit into Treehouse contract using router.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                router,
                false,
                "deposit(address,uint256)",
                new address[](1),
                string.concat("Deposit into Treehouse contract using router with ", routerTokensIn[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(routerTokensIn[i]);
        }

        // Approve redemption contract to spend tAsset.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(tAsset),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve redemption contract to spend ", tAsset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = redemptionContract;

        // Redeem tAsset.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            redemptionContract,
            false,
            "redeem(uint96)",
            new address[](0),
            string.concat("Redeem ", tAsset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Finalize redeem.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            redemptionContract,
            false,
            "finalizeRedeem(uint256)",
            new address[](0),
            string.concat("Finalize redeem ", tAsset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

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
            leafs[leafIndex] = ManageLeaf(
                address(localTokens[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve StandardBridge to spend ", localTokens[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = sourceStandardBridge;
        }

        // ERC20 bridge leafs.
        for (uint256 i; i < localTokens.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                sourceStandardBridge,
                false,
                "bridgeERC20To(address,address,address,uint256,uint32,bytes)",
                new address[](3),
                string.concat("Bridge ", localTokens[i].symbol(), " from ", sourceChain, " to ", destination),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
            leafs[leafIndex] = ManageLeaf(
                sourceStandardBridge,
                false,
                "bridgeETHTo(uint256,address,uint32,bytes)",
                new address[](1),
                string.concat("Bridge ETH from ", sourceChain, " to ", destination),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        } else {
            // Bridge ETH.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                sourceStandardBridge,
                true,
                "bridgeETHTo(address,uint32,bytes)",
                new address[](1),
                string.concat("Bridge ETH from ", sourceChain, " to ", destination),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }

        // If we are generating leafs for some L2 back to mainnet, these leafs are not needed.
        if (keccak256(abi.encode(destination)) != keccak256(abi.encode(mainnet))) {
            if (keccak256(abi.encode(destination)) == keccak256(abi.encode(mantle))) {
                // Prove withdrawal transaction.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    sourcePortal,
                    false,
                    "proveWithdrawalTransaction((uint256,address,address,uint256,uint256,uint256,bytes),uint256,(bytes32,bytes32,bytes32,bytes32),bytes[])",
                    new address[](2),
                    string.concat("Prove withdrawal transaction from ", destination, " to ", sourceChain),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
                leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;

                // Finalize withdrawal transaction.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    sourcePortal,
                    false,
                    "finalizeWithdrawalTransaction((uint256,address,address,uint256,uint256,uint256,bytes))",
                    new address[](2),
                    string.concat("Finalize withdrawal transaction from ", destination, " to ", sourceChain),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
                leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;
            } else {
                // Prove withdrawal transaction.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    sourcePortal,
                    false,
                    "proveWithdrawalTransaction((uint256,address,address,uint256,uint256,bytes),uint256,(bytes32,bytes32,bytes32,bytes32),bytes[])",
                    new address[](2),
                    string.concat("Prove withdrawal transaction from ", destination, " to ", sourceChain),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
                leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;

                // Finalize withdrawal transaction.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    sourcePortal,
                    false,
                    "finalizeWithdrawalTransaction((uint256,address,address,uint256,uint256,bytes))",
                    new address[](2),
                    string.concat("Finalize withdrawal transaction from ", destination, " to ", sourceChain),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
            leafs[leafIndex] = ManageLeaf(
                address(localToken),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve StandardBridge to spend ", localToken.symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = sourceStandardBridge;

            // ERC20 bridge leafs.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                sourceStandardBridge,
                false,
                "depositERC20To(address,address,address,uint256,uint32,bytes)",
                new address[](3),
                string.concat("Bridge ", localToken.symbol(), " from ", sourceChain, " to ", destination),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(localToken);
            leafs[leafIndex].argumentAddresses[1] = address(remoteToken);
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // Prove withdrawal transaction.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                sourcePortal,
                false,
                "proveWithdrawalTransaction((uint256,address,address,uint256,uint256,bytes),uint256,(bytes32,bytes32,bytes32,bytes32),bytes[])",
                new address[](2),
                string.concat("Prove withdrawal transaction from ", destination, " to ", sourceChain),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
            leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;

            // Finalize withdrawal transaction.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                sourcePortal,
                false,
                "finalizeWithdrawalTransaction((uint256,address,address,uint256,uint256,bytes))",
                new address[](2),
                string.concat("Finalize withdrawal transaction from ", destination, " to ", sourceChain),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
            leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;
        } else if (keccak256(abi.encode(destination)) == keccak256(abi.encode(mainnet))) {
            // We are bridging back to mainnet.
            // Approve L2 ERC20 Token Bridge to spent wstETH.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(localToken),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve L2 ERC20 Token Bridge to spend ", localToken.symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = sourceStandardBridge;

            // call withdrawTo.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                sourceStandardBridge,
                false,
                "withdrawTo(address,address,uint256,uint32,bytes)",
                new address[](2),
                string.concat("Withdraw wstETH to ", destination),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(localToken);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
    }

    // ========================================= Arbitrum Native Bridge =========================================

    /// @notice When sourceChain is arbitrum bridgeAssets MUST be mainnet addresses.
    function _addArbitrumNativeBridgeLeafs(ManageLeaf[] memory leafs, ERC20[] memory bridgeAssets) internal {
        if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mainnet))) {
            // Bridge ERC20 Assets to Arbitrum
            for (uint256 i; i < bridgeAssets.length; i++) {
                address spender = address(bridgeAssets[i]) == getAddress(sourceChain, "WETH")
                    ? getAddress(sourceChain, "arbitrumWethGateway")
                    : getAddress(sourceChain, "arbitrumL1ERC20Gateway");
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(bridgeAssets[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Arbitrum L1 Gateway to spend ", bridgeAssets[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = spender;
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "arbitrumL1GatewayRouter"),
                    true,
                    "outboundTransfer(address,address,uint256,uint256,uint256,bytes)",
                    new address[](2),
                    string.concat("Bridge ", bridgeAssets[i].symbol(), " to Arbitrum"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(bridgeAssets[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "arbitrumL1GatewayRouter"),
                    true,
                    "outboundTransferCustomRefund(address,address,address,uint256,uint256,uint256,bytes)",
                    new address[](3),
                    string.concat("Bridge ", bridgeAssets[i].symbol(), " to Arbitrum"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(bridgeAssets[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            }
            // Create Retryable Ticket
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "arbitrumDelayedInbox"),
                false,
                "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
                new address[](3),
                "Create retryable ticket for Arbitrum",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // Unsafe Create Retryable Ticket
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "arbitrumDelayedInbox"),
                false,
                "unsafeCreateRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
                new address[](3),
                "Unsafe Create retryable ticket for Arbitrum",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // Create Retryable Ticket
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "arbitrumDelayedInbox"),
                true,
                "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
                new address[](3),
                "Create retryable ticket for Arbitrum",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // Unsafe Create Retryable Ticket
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "arbitrumDelayedInbox"),
                true,
                "unsafeCreateRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
                new address[](3),
                "Unsafe Create retryable ticket for Arbitrum",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // Execute Transaction For ERC20 claim.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "arbitrumOutbox"),
                false,
                "executeTransaction(bytes32[],uint256,address,address,uint256,uint256,uint256,uint256,bytes)",
                new address[](2),
                "Execute transaction to claim ERC20",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(arbitrum, "arbitrumL2Sender");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "arbitrumL1ERC20Gateway");

            // Execute Transaction For ETH claim.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "arbitrumOutbox"),
                false,
                "executeTransaction(bytes32[],uint256,address,address,uint256,uint256,uint256,uint256,bytes)",
                new address[](2),
                "Execute transaction to claim ETH",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        } else if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(arbitrum))) {
            // ERC20 bridge withdraws.
            for (uint256 i; i < bridgeAssets.length; ++i) {
                // outboundTransfer
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "arbitrumL2GatewayRouter"),
                    false,
                    "outboundTransfer(address,address,uint256,bytes)",
                    new address[](2),
                    string.concat("Withdraw ", vm.toString(address(bridgeAssets[i])), " from Arbitrum"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(bridgeAssets[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            }

            // WithdrawEth
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "arbitrumSys"),
                true,
                "withdrawEth(address)",
                new address[](1),
                "Withdraw ETH from Arbitrum",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Redeem
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "arbitrumRetryableTx"),
                false,
                "redeem(bytes32)",
                new address[](0),
                "Redeem retryable ticket on Arbitrum",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
            leafs[leafIndex] = ManageLeaf(
                address(localTokens[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Linea ", sourceChain, " tokenBridge to spend ", localTokens[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "tokenBridge");

            // Call bridgeToken to bridge the token.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "tokenBridge"),
                false,
                "bridgeToken(address,uint256,address)",
                new address[](2),
                string.concat("Bridge ", localTokens[i].symbol(), " from ", sourceChain, " to ", destination),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(localTokens[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "tokenBridge"),
                true,
                "bridgeToken(address,uint256,address)",
                new address[](2),
                string.concat("Bridge ", localTokens[i].symbol(), " from ", sourceChain, " to ", destination),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(localTokens[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }

        if (localTokens.length > 0) {
            if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mainnet))) {
                // Call claimMessageWithProof to handle claiming ERC20s.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "lineaMessageService"),
                    false,
                    "claimMessageWithProof((bytes32[],uint256,uint32,address,address,uint256,uint256,address,bytes32,bytes))",
                    new address[](3),
                    string.concat("Claim ERC20s from ", destination, " Token Bridge to ", sourceChain, " Token Bridge"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(destination, "tokenBridge");
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "tokenBridge");
                leafs[leafIndex].argumentAddresses[2] = address(0);
            } else if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(linea))) {
                // Use claimMessage Leaf instead of claimMessageWithProof.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "lineaMessageService"),
                    false,
                    "claimMessage(address,address,uint256,uint256,address,bytes,uint256)",
                    new address[](3),
                    string.concat("Claim ERC20s from ", destination, " Token Bridge to ", sourceChain, " Token Bridge"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(destination, "tokenBridge");
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "tokenBridge");
                leafs[leafIndex].argumentAddresses[2] = address(0);
            }
        }

        // Call sendMessage to send ETH.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "lineaMessageService"),
            true,
            "sendMessage(address,uint256,bytes)",
            new address[](1),
            string.concat("Send ETH from ", sourceChain, " to ", destination),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Call claimMessage to handle claiming ETH.
        if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mainnet))) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "lineaMessageService"),
                false,
                "claimMessageWithProof((bytes32[],uint256,uint32,address,address,uint256,uint256,address,bytes32,bytes))",
                new address[](3),
                string.concat("Claim ETH from ", destination, " Token Bridge to ", sourceChain, " Token Bridge"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = address(0);
        } else if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(linea))) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "lineaMessageService"),
                false,
                "claimMessage(address,address,uint256,uint256,address,bytes,uint256)",
                new address[](3),
                string.concat("Claim ETH from ", destination, " Token Bridge to ", sourceChain, " Token Bridge"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "scrollMessenger"),
                true,
                "sendMessage(address,uint256,bytes,uint256)",
                new address[](1),
                string.concat("Bridge ETH from ", sourceChain, " to ", mainnet),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Add leafs for bridging and claiming ERC20s.
            for (uint256 i; i < localTokens.length; ++i) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(localTokens[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Scroll Gateway Router to spend ", localTokens[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "scrollGatewayRouter");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "scrollGatewayRouter"),
                    true,
                    "depositERC20(address,address,uint256,uint256)",
                    new address[](2),
                    string.concat("Bridge ", localTokens[i].symbol(), " from ", sourceChain, " to ", destination),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(localTokens[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

                address mainnetGateway = IScrollGateway(getAddress(sourceChain, "scrollGatewayRouter")).getERC20Gateway(address(localTokens[i]));
                // Add leaf for ERC20 claiming.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "scrollMessenger"),
                    false,
                    "relayMessageWithProof(address,address,uint256,uint256,bytes,(uint256,bytes))",
                    new address[](2),
                    string.concat("Claim ", localTokens[i].symbol(), " from ", destination, " to ", sourceChain),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = scrollGateways[i];
                leafs[leafIndex].argumentAddresses[1] = mainnetGateway;
            }

            // Add leaf for claiming ETH.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "scrollMessenger"),
                false,
                "relayMessageWithProof(address,address,uint256,uint256,bytes,(uint256,bytes))",
                new address[](2),
                string.concat("Claim ETH from ", destination, " to ", sourceChain),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        } else if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(scroll))) {
            // Add leafs for withdrawing ETH.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "scrollMessenger"),
                true,
                "sendMessage(address,uint256,bytes,uint256)",
                new address[](1),
                string.concat("Bridge ETH from ", sourceChain, " to ", destination),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Add leafs for withdrawing ERC20s.
            for (uint256 i; i < localTokens.length; ++i) {
                address gateway = IScrollGateway(getAddress(sourceChain, "scrollGatewayRouter")).getERC20Gateway(address(localTokens[i])); 

                //most tokens won't need an approval, but some do (USDC, WETH)
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(localTokens[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve ERC20 Gateway to spend ", localTokens[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = gateway;  
                
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "scrollGatewayRouter"),
                    false,
                    "withdrawERC20(address,address,uint256,uint256)",
                    new address[](2),
                    string.concat("Withdraw ", localTokens[i].symbol(), " from ", sourceChain, " to ", destination),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(feeTokens[i])][getAddress(
                    sourceChain, "ccipRouter"
                )]
            ) {
                // Add fee token approval.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(feeTokens[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve ", sourceChain, " CCIP Router to spend ", feeTokens[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "ccipRouter");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(feeTokens[i])][getAddress(
                    sourceChain, "ccipRouter"
                )] = true;
            }
            for (uint256 j; j < bridgeAssets.length; j++) {
                if (
                    !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(
                        bridgeAssets[j]
                    )][getAddress(sourceChain, "ccipRouter")]
                ) {
                    // Add bridge asset approval.
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        address(bridgeAssets[j]),
                        false,
                        "approve(address,uint256)",
                        new address[](1),
                        string.concat("Approve ", sourceChain, " CCIP Router to spend ", bridgeAssets[j].symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "ccipRouter");
                    ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(
                        bridgeAssets[j]
                    )][getAddress(sourceChain, "ccipRouter")] = true;
                }
                // Add ccipSend leaf.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "ccipRouter"),
                    false,
                    "ccipSend(uint64,(bytes,bytes,(address,uint256)[],address,bytes))",
                    new address[](4),
                    string.concat(
                        "Bridge ",
                        bridgeAssets[j].symbol(),
                        " to chain ",
                        vm.toString(destinationChainId),
                        " using CCIP"
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                    sourceChain, "pancakeSwapV3NonFungiblePositionManager"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat(
                        "Approve PancakeSwapV3 NonFungible Position Manager to spend ", ERC20(token0[i]).symbol()
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] =
                    getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                    sourceChain, "pancakeSwapV3NonFungiblePositionManager"
                )] = true;
            }
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                    sourceChain, "pancakeSwapV3NonFungiblePositionManager"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat(
                        "Approve PancakeSwapV3 NonFungible Position Manager to spend ", ERC20(token1[i]).symbol()
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] =
                    getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                    sourceChain, "pancakeSwapV3NonFungiblePositionManager"
                )] = true;
            }
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                    sourceChain, "pancakeSwapV3MasterChefV3"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve PancakeSwapV3 Master Chef to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                    sourceChain, "pancakeSwapV3MasterChefV3"
                )] = true;
            }
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                    sourceChain, "pancakeSwapV3MasterChefV3"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve PancakeSwapV3 Master Chef to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                    sourceChain, "pancakeSwapV3MasterChefV3"
                )] = true;
            }

            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                    sourceChain, "pancakeSwapV3Router"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve PancakeSwapV3 Router to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pancakeSwapV3Router");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                    sourceChain, "pancakeSwapV3Router"
                )] = true;
            }
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                    sourceChain, "pancakeSwapV3Router"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve PancakeSwapV3 Router to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pancakeSwapV3Router");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                    sourceChain, "pancakeSwapV3Router"
                )] = true;
            }

            // Minting
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
                false,
                "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
                new address[](3),
                string.concat(
                    "Mint PancakeSwapV3 ", ERC20(token0[i]).symbol(), " ", ERC20(token1[i]).symbol(), " position"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            // Increase liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
                false,
                "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
                new address[](5),
                string.concat(
                    "Add liquidity to PancakeSwapV3 ",
                    ERC20(token0[i]).symbol(),
                    " ",
                    ERC20(token1[i]).symbol(),
                    " position"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(0);
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = token1[i];
            leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[4] = address(0);

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "pancakeSwapV3MasterChefV3"),
                false,
                "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
                new address[](5),
                string.concat(
                    "Add liquidity to PancakeSwapV3 ",
                    ERC20(token0[i]).symbol(),
                    " ",
                    ERC20(token1[i]).symbol(),
                    " staked position"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(0);
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = token1[i];
            leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");
            leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");

            // Swapping to move tick in pool.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "pancakeSwapV3Router"),
                false,
                "exactInput((bytes,address,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Swap ",
                    ERC20(token0[i]).symbol(),
                    " for ",
                    ERC20(token1[i]).symbol(),
                    " using PancakeSwapV3 router"
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
                getAddress(sourceChain, "pancakeSwapV3Router"),
                false,
                "exactInput((bytes,address,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Swap ",
                    ERC20(token1[i]).symbol(),
                    " for ",
                    ERC20(token0[i]).symbol(),
                    " using PancakeSwapV3 router"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token1[i];
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        }
        // Decrease liquidity
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](2),
            "Remove liquidity from PancakeSwapV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = address(0);

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pancakeSwapV3MasterChefV3"),
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](2),
            "Remove liquidity from PancakeSwapV3 staked position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
            false,
            "collect((uint256,address,uint128,uint128))",
            new address[](3),
            "Collect fees from PancakeSwapV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[2] = address(0);

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pancakeSwapV3MasterChefV3"),
            false,
            "collect((uint256,address,uint128,uint128))",
            new address[](3),
            "Collect fees from PancakeSwapV3 staked position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

        // burn
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
            false,
            "burn(uint256)",
            new address[](0),
            "Burn PancakeSwapV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Staking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
            false,
            "safeTransferFrom(address,address,uint256)",
            new address[](2),
            "Stake PancakeSwapV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");

        // Staking harvest.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pancakeSwapV3MasterChefV3"),
            false,
            "harvest(uint256,address)",
            new address[](1),
            "Harvest rewards from PancakeSwapV3 staked postiion",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Unstaking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pancakeSwapV3MasterChefV3"),
            false,
            "withdraw(uint256,address)",
            new address[](1),
            "Unstake PancakeSwapV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        leafs[leafIndex] = ManageLeaf(
            wrappedToken,
            true,
            "deposit()",
            new address[](0),
            string.concat("Wrap Native to ", ERC20(wrappedToken).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            wrappedToken,
            false,
            "withdraw(uint256)",
            new address[](0),
            string.concat("Unwrap ", ERC20(wrappedToken).symbol(), " to Native"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= EtherFi =========================================

    function _addEtherFiLeafs(ManageLeaf[] memory leafs) internal {
        // Approvals
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "EETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve WEETH to spend eETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "WEETH");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "EETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve EtherFi Liquidity Pool to spend eETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "EETH_LIQUIDITY_POOL");
        // Staking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "EETH_LIQUIDITY_POOL"),
            true,
            "deposit()",
            new address[](0),
            "Stake ETH for eETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        // Unstaking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "EETH_LIQUIDITY_POOL"),
            false,
            "requestWithdraw(address,uint256)",
            new address[](1),
            "Request withdrawal from eETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "withdrawalRequestNft"),
            false,
            "claimWithdraw(uint256)",
            new address[](0),
            "Claim eETH withdrawal",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        // Wrapping
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "WEETH"),
            false,
            "wrap(uint256)",
            new address[](0),
            "Wrap eETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "WEETH"),
            false,
            "unwrap(uint256)",
            new address[](0),
            "Unwrap weETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        //deposit ERC20s
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "STETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve EtherFi Vampire Pool to spend STETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "etherFiVampirePool");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "etherFiVampirePool"),
            false,
            "depositWithERC20(address,uint256,address)",
            new address[](2),
            "Deposit ERC20 for eETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "STETH");
        leafs[leafIndex].argumentAddresses[1] = address(0); 
    }

    // ========================================= LIDO =========================================

    function _addLidoLeafs(ManageLeaf[] memory leafs) internal {
        // Approvals
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "STETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve WSTETH to spend stETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "WSTETH");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "STETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve unstETH to spend stETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "unstETH");
        // Staking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "STETH"),
            true,
            "submit(address)",
            new address[](1),
            "Stake ETH for stETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(0);
        // Unstaking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "unstETH"),
            false,
            "requestWithdrawals(uint256[],address)",
            new address[](1),
            "Request withdrawals from stETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "unstETH"),
            false,
            "claimWithdrawal(uint256)",
            new address[](0),
            "Claim stETH withdrawal",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "unstETH"),
            false,
            "claimWithdrawals(uint256[],uint256[])",
            new address[](0),
            "Claim stETH withdrawals",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        // Wrapping
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "WSTETH"),
            false,
            "wrap(uint256)",
            new address[](0),
            "Wrap stETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "WSTETH"),
            false,
            "unwrap(uint256)",
            new address[](0),
            "Unwrap wstETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= MFOne =========================================
    function _addMfOneLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "USDC"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve USDC to be spent by MF-ONE Deposit Vault",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "mfOneDepositVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "MF-ONE"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve MF-ONE to be spent by MF-ONE Redemption Vault",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "mfOneRedemptionVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "mfOneDepositVault"),
            false,
            "depositInstant(address,uint256,uint256,bytes32)",
            new address[](3),
            "Deposit Instant USDC for MFONE",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDC");
        leafs[leafIndex].argumentAddresses[1] = address(0);  
        leafs[leafIndex].argumentAddresses[2] = address(0);  

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "mfOneDepositVault"),
            false,
            "depositRequest(address,uint256,bytes32)",
            new address[](3),
            "Deposit Request USDC for MFONE",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDC");
        leafs[leafIndex].argumentAddresses[1] = address(0);  
        leafs[leafIndex].argumentAddresses[2] = address(0);  

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "mfOneRedemptionVault"),
            false,
            "redeemInstant(address,uint256,uint256)",
            new address[](1),
            "Redeem Instant MFONE for USDC",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDC");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "mfOneRedemptionVault"),
            false,
            "redeemRequest(address,uint256)",
            new address[](1),
            "Redeem Request MFONE for USDC",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDC");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "mfOneRedemptionVault"),
            false,
            "redeemFiatRequest(uint256)",
            new address[](0),
            "Redeem Fiat Request MFONE",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    } 

    // ========================================= Kinetiq KHYPE =========================================
    function _addKHypeLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "KHYPE"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve kHype to be spent by kHype Staking Manager",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "kHypeStakingManager");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "kHypeStakingManager"),
            true,
            "stake()",
            new address[](0),
            "Stake HYPE for KHYPE",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "kHypeStakingManager"),
            false,
            "queueWithdrawal(uint256)",
            new address[](0),
            "Queue Withdraw on KHYPE",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "kHypeStakingManager"),
            false,
            "confirmWithdrawal(uint256)",
            new address[](0),
            "Confirm Withdraw on KHYPE and receive HYPE",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Frax =========================================

    function _addFraxLeafs(ManageLeaf[] memory leafs) internal {
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SFRXETH")));
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "FRXETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve frxETH Redemption Ticket to spend frxETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "frxETHRedemptionTicket");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "SFRXETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve frxETH Redemption Ticket to spend sfrxETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "frxETHRedemptionTicket");

        // Staking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "frxETHMinter"),
            true,
            "submit()",
            new address[](0),
            "Stake ETH for frxETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Unstaking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "frxETHRedemptionTicket"),
            false,
            "enterRedemptionQueue(address,uint120)",
            new address[](1),
            "Request withdrawal from frxETH using frxETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "frxETHRedemptionTicket"),
            false,
            "enterRedemptionQueueViaSfrxEth(address,uint120)",
            new address[](1),
            "Request withdrawal from frxETH using sfrxETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Complete withdrawal
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "frxETHRedemptionTicket"),
            false,
            "burnRedemptionTicketNft(uint256,address)",
            new address[](1),
            "Claim frxETH withdrawal",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "frxETHRedemptionTicket"),
            false,
            "earlyBurnRedemptionTicketNft(address,uint256)",
            new address[](1),
            "Cancel frxETH withdrawal with penalty",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Swell Staking =========================================

    function _addSwellStakingLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "SWETH"),
            true,
            "deposit()",
            new address[](0),
            "Stake ETH for swETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "SWETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve swEXIT to spend swETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "swEXIT");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "swEXIT"),
            false,
            "createWithdrawRequest(uint256)",
            new address[](0),
            "Create a withdraw request from swETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "swEXIT"),
            false,
            "finalizeWithdrawal(uint256)",
            new address[](0),
            "Finalize a swETH withdraw request",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    function _addRsWETHUnstakingLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "RSWETH"),
            true,
            "deposit()",
            new address[](0),
            "Stake ETH for rswETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "RSWETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve rswEXIT to spend rswETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "rswEXIT");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "rswEXIT"),
            false,
            "createWithdrawRequest(uint256)",
            new address[](0),
            "Create a withdraw request from rswETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "rswEXIT"),
            false,
            "finalizeWithdrawal(uint256)",
            new address[](0),
            "Finalize a rswETH withdraw request",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Mantle Staking =========================================

    function _addMantleStakingLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "mantleLspStaking"),
            true,
            "stake(uint256)",
            new address[](0),
            "Stake ETH for mETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "METH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Mantle LSP Staking to spend mETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "mantleLspStaking");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "mantleLspStaking"),
            false,
            "unstakeRequest(uint128,uint128)",
            new address[](0),
            "Request Unstake mETH for ETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "mantleLspStaking"),
            false,
            "claimUnstakeRequest(uint256)",
            new address[](0),
            "Claim Unstake Request for ETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        _addAaveV3ForkLeafs("Aave V3 Horizon", getAddress(sourceChain, "v3HorizonPool"), leafs, supplyAssets, borrowAssets);
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
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(supplyAssets[i])][protocolAddress]
            ) {
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
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(supplyAssets[i])][protocolAddress]
                = true;
            }
        }
        for (uint256 i; i < borrowAssets.length; ++i) {
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(borrowAssets[i])][protocolAddress]
            ) {
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
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(borrowAssets[i])][protocolAddress]
                = true;
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
        // Misc
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

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "v3RewardsController"),
            false,
            "claimRewards(address[],uint256,address,address)",
            new address[](1),
            string.concat("Claim rewards"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    function _addAaveV3RepayLeafs(
        string memory protocolName,
        address protocolAddress,
        ManageLeaf[] memory leafs,
        ERC20[] memory borrowAssets
    ) public {

        for (uint256 i; i < borrowAssets.length; ++i) {
            leafIndex++;
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
                if (
                    !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                        sourceChain, "uniV2Router"
                    )]
                ) {
                    (token0[i], token1[i]) = token0[i] < token1[i] ? (token0[i], token1[i]) : (token1[i], token0[i]);

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        token0[i],
                        false,
                        "approve(address,uint256)",
                        new address[](1),
                        string.concat("Approve UniswapV2 Router to spend ", ERC20(token0[i]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV2Router");
                    ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                        sourceChain, "uniV2Router"
                    )] = true;
                }
            }

            if (token1[i] != nativeETH) {
                if (
                    !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                        sourceChain, "uniV2Router"
                    )]
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        token1[i],
                        false,
                        "approve(address,uint256)",
                        new address[](1),
                        string.concat("Approve UniswapV2 Router to spend ", ERC20(token1[i]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV2Router");
                    ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                        sourceChain, "uniV2Router"
                    )] = true;
                }
            }

            address tokenPair = IUniswapV2Factory(getAddress(sourceChain, "uniV2Factory")).getPair(token0[i], token1[i]);
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][tokenPair][getAddress(
                    sourceChain, "uniV2Router"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    tokenPair,
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat(
                        "Approve UniswapV2 Router to spend ",
                        ERC20(tokenPair).symbol(),
                        "-",
                        ERC20(token0[i]).symbol(),
                        "-",
                        ERC20(token1[i]).symbol()
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV2Router");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][tokenPair][getAddress(
                    sourceChain, "uniV2Router"
                )] = true;
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

            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "uniV2Router"),
                false,
                "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
                new address[](3),
                string.concat("Swap exact ", ERC20(token0[i]).symbol(), " for ", ERC20(token1[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            //Swap token1 for token0
            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "uniV2Router"),
                false,
                "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
                new address[](3),
                string.concat("Swap exact ", ERC20(token1[i]).symbol(), " for ", ERC20(token0[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token1[i];
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            //Swap token0 for exact token1
            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "uniV2Router"),
                false,
                "swapTokensForExactTokens(uint256,uint256,address[],address,uint256)",
                new address[](3),
                string.concat("Swap ", ERC20(token0[i]).symbol(), " for exact ", ERC20(token1[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            //Swap token1 for exact token0
            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "uniV2Router"),
                false,
                "swapTokensForExactTokens(uint256,uint256,address[],address,uint256)",
                new address[](3),
                string.concat("Swap ", ERC20(token1[i]).symbol(), " for exact ", ERC20(token0[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token1[i];
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // LIQUIDITY FUNCTIONS
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "uniV2Router"),
                false,
                "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)",
                new address[](3),
                string.concat("Add liquidty on UniswapV2"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "uniV2Router"),
                false,
                "removeLiquidity(address,address,uint256,uint256,uint256,address,uint256)",
                new address[](3),
                string.concat("Remove liquidty on UniswapV2"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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

                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV2Router"),
                    true,
                    "swapExactETHForTokens(uint256,address[],address,uint256)",
                    new address[](3),
                    string.concat("Swap exact ETH for ", ERC20(token).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "WETH");
                leafs[leafIndex].argumentAddresses[1] = token;
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }

                //10
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV2Router"),
                    false,
                    "swapExactTokensForETH(uint256,uint256,address[],address,uint256)",
                    new address[](3),
                    string.concat("Swap exact ETH for ", ERC20(token).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = token;
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "WETH");
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }

                //11
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV2Router"),
                    false,
                    "swapTokensForExactETH(uint256,uint256,address[],address,uint256)",
                    new address[](3),
                    string.concat("Swap ", ERC20(token).symbol(), " for exact ETH"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = token;
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "WETH");
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }

                //12
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV2Router"),
                    true,
                    "swapETHForExactTokens(uint256,address[],address,uint256)",
                    new address[](3),
                    string.concat("Swap ETH for exact ", ERC20(token).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "WETH");
                leafs[leafIndex].argumentAddresses[1] = token;
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }

                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV2Router"),
                    true,
                    "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
                    new address[](2),
                    string.concat("Add liquidity for ETH and ", ERC20(token).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = token;
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }

                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV2Router"),
                    false,
                    "removeLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
                    new address[](2),
                    string.concat("Remove liquidity from ETH and ", ERC20(token).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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

            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                    sourceChain, "uniV3Router"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve UniswapV3 Router to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV3Router");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                    sourceChain, "uniV3Router"
                )] = true;
            }
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                    sourceChain, "uniV3Router"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve UniswapV3 Router to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV3Router");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                    sourceChain, "uniV3Router"
                )] = true;
            }

            //end swap only

            if (!swap_only) {
                // Approvals for position manager
                if (
                    !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                        sourceChain, "uniswapV3NonFungiblePositionManager"
                    )]
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        token0[i],
                        false,
                        "approve(address,uint256)",
                        new address[](1),
                        string.concat(
                            "Approve UniswapV3 NonFungible Position Manager to spend ", ERC20(token0[i]).symbol()
                        ),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] =
                        getAddress(sourceChain, "uniswapV3NonFungiblePositionManager");
                    ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                        sourceChain, "uniswapV3NonFungiblePositionManager"
                    )] = true;
                }
                if (
                    !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                        sourceChain, "uniswapV3NonFungiblePositionManager"
                    )]
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        token1[i],
                        false,
                        "approve(address,uint256)",
                        new address[](1),
                        string.concat(
                            "Approve UniswapV3 NonFungible Position Manager to spend ", ERC20(token1[i]).symbol()
                        ),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] =
                        getAddress(sourceChain, "uniswapV3NonFungiblePositionManager");
                    ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                        sourceChain, "uniswapV3NonFungiblePositionManager"
                    )] = true;
                }

                // Minting
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
                    false,
                    "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
                    new address[](3),
                    string.concat(
                        "Mint UniswapV3 ", ERC20(token0[i]).symbol(), " ", ERC20(token1[i]).symbol(), " position"
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                // Increase liquidity
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
                    false,
                    "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
                    new address[](4),
                    string.concat(
                        "Add liquidity to UniswapV3 ",
                        ERC20(token0[i]).symbol(),
                        " ",
                        ERC20(token1[i]).symbol(),
                        " position"
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV3Router"),
                    false,
                    "exactInput((bytes,address,uint256,uint256,uint256))",
                    new address[](3),
                    string.concat(
                        "Swap ",
                        ERC20(token0[i]).symbol(),
                        " for ",
                        ERC20(token1[i]).symbol(),
                        " using UniswapV3 router"
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
                    getAddress(sourceChain, "uniV3Router"),
                    false,
                    "exactInput((bytes,address,uint256,uint256,uint256))",
                    new address[](3),
                    string.concat(
                        "Swap ",
                        ERC20(token1[i]).symbol(),
                        " for ",
                        ERC20(token0[i]).symbol(),
                        " using UniswapV3 router"
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = token1[i];
                leafs[leafIndex].argumentAddresses[1] = token0[i];
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            }

            if (swapRouter02) {
                //SWAPROUTER02
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV3Router"),
                    false,
                    "exactInput((bytes,address,uint256,uint256))",
                    new address[](3),
                    string.concat(
                        "Swap ",
                        ERC20(token0[i]).symbol(),
                        " for ",
                        ERC20(token1[i]).symbol(),
                        " using UniswapV3 router"
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
                    getAddress(sourceChain, "uniV3Router"),
                    false,
                    "exactInput((bytes,address,uint256,uint256))",
                    new address[](3),
                    string.concat(
                        "Swap ",
                        ERC20(token1[i]).symbol(),
                        " for ",
                        ERC20(token0[i]).symbol(),
                        " using UniswapV3 router"
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
                false,
                "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
                new address[](1),
                "Remove liquidity from UniswapV3 position",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
                false,
                "collect((uint256,address,uint128,uint128))",
                new address[](2),
                "Collect fees from UniswapV3 position",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            // burn
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
                false,
                "burn(uint256)",
                new address[](0),
                "Burn UniswapV3 position",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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

            if (!ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(sourceChain, "uniV3Router")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve UniswapV3 Router to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV3Router");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(sourceChain, "uniV3Router")] = true;
            }

            if (swapRouter02) {
                leafIndex++;
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV3Router"),
                    false,
                    "exactInput((bytes,address,uint256,uint256))",
                    new address[](3),
                    string.concat(
                        "Swap ",
                        ERC20(token0[i]).symbol(),
                        " for ",
                        ERC20(token1[i]).symbol(),
                        " using UniswapV3 router"
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            } else {
                leafIndex++;
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV3Router"),
                    false,
                    "exactInput((bytes,address,uint256,uint256,uint256))",
                    new address[](3),
                    string.concat(
                        "Swap ",
                        ERC20(token0[i]).symbol(),
                        " for ",
                        ERC20(token1[i]).symbol(),
                        " using UniswapV3 router"
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
                if (
                    !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                        sourceChain, "uniV4UniversalRouter"
                    )]
                ) {
                    //approve token0 after sorting
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        token0[i],
                        false,
                        "approve(address,uint256)",
                        new address[](1),
                        string.concat("Approve UniswapV4 Pool Manager to spend ", ERC20(token0[i]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV4UniversalRouter");
                    ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                        sourceChain, "uniV4PoolManager"
                    )] = true;

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        token0[i],
                        false,
                        "approve(address,uint256)",
                        new address[](1),
                        string.concat("Approve UniswapV4 Position Manager to spend ", ERC20(token0[i]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV4PositionManager");

                    ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                        sourceChain, "uniV4PoolManager"
                    )] = true;

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        token0[i],
                        false,
                        "approve(address,uint256)",
                        new address[](1),
                        string.concat("Approve Permit2 to spend ", ERC20(token0[i]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "permit2");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "permit2"),
                        false,
                        "approve(address,address,uint160,uint48)",
                        new address[](2),
                        string.concat("Use Permit2 to approve ", ERC20(token0[i]).symbol(), " for Universal Router"),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = token0[i];
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "uniV4UniversalRouter");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "permit2"),
                        false,
                        "approve(address,address,uint160,uint48)",
                        new address[](2),
                        string.concat("Use Permit2 to approve ", ERC20(token0[i]).symbol(), " for POSM"),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = token0[i];
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "uniV4PositionManager");
                }
            }

            if (token1[i] != address(0)) {
                if (
                    !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                        sourceChain, "uniV4UniversalRouter"
                    )]
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        token1[i],
                        false,
                        "approve(address,uint256)",
                        new address[](1),
                        string.concat("Approve UniswapV4 Universal Router to spend ", ERC20(token1[i]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV4UniversalRouter");
                    ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                        sourceChain, "uniV4UniversalRouter"
                    )] = true;

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        token1[i],
                        false,
                        "approve(address,uint256)",
                        new address[](1),
                        string.concat("Approve UniswapV4 Position Manager to spend ", ERC20(token1[i]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV4PositionManager");
                    ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                        sourceChain, "uniV4PositionManager"
                    )] = true;

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        token1[i],
                        false,
                        "approve(address,uint256)",
                        new address[](1),
                        string.concat("Approve Permit2 to spend ", ERC20(token1[i]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "permit2");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "permit2"),
                        false,
                        "approve(address,address,uint160,uint48)",
                        new address[](2),
                        string.concat("Approve Permit2 to spend ", ERC20(token1[i]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = token1[i];
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "uniV4UniversalRouter");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "permit2"),
                        false,
                        "approve(address,address,uint160,uint48)",
                        new address[](2),
                        string.concat("Approve Permit2 to spend ", ERC20(token1[i]).symbol(), " for POSM"),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = token1[i];
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "uniV4PositionManager");
                } //end if
            }

            if (token0[i] != address(0)) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV4UniversalRouter"),
                    false,
                    "execute(bytes,bytes[],uint256)",
                    new address[](5),
                    string.concat("Swap ", ERC20(token0[i]).symbol(), " for ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(token0[i]);
                leafs[leafIndex].argumentAddresses[1] = address(token1[i]);
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = address(token0[i]);
                leafs[leafIndex].argumentAddresses[4] = address(token1[i]);

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV4UniversalRouter"),
                    false,
                    "execute(bytes,bytes[],uint256)",
                    new address[](5),
                    string.concat("Swap ", ERC20(token1[i]).symbol(), " for ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(token0[i]);
                leafs[leafIndex].argumentAddresses[1] = address(token1[i]);
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = address(token1[i]);
                leafs[leafIndex].argumentAddresses[4] = address(token0[i]);
            } else {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV4UniversalRouter"),
                    true,
                    "execute(bytes,bytes[],uint256)",
                    new address[](7),
                    string.concat("Swap ETH for ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );

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
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV4UniversalRouter"),
                    false,
                    "execute(bytes,bytes[],uint256)",
                    new address[](5),
                    string.concat("Swap ", ERC20(token1[i]).symbol(), " for ETH"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );

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
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV4PositionManager"),
                    false,
                    "modifyLiquidities(bytes,uint256)",
                    new address[](6),
                    string.concat(
                        "Mint UniswapV4 position for ", ERC20(token0[i]).symbol(), " and ", ERC20(token1[i]).symbol()
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV4PositionManager"),
                    true,
                    "modifyLiquidities(bytes,uint256)",
                    new address[](8),
                    string.concat("Mint UniswapV4 position for ETH and ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV4PositionManager"),
                    false,
                    "modifyLiquidities(bytes,uint256)",
                    new address[](5),
                    string.concat(
                        "Increase liquidity for UniswapV4 position for ",
                        ERC20(token0[i]).symbol(),
                        " and ",
                        ERC20(token1[i]).symbol(),
                        " using SETTLE_PAIR, CLOSE_CURRENCY (both pairs), or CLEAR_AND_TAKE (both pairs)"
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = token0[i];
                leafs[leafIndex].argumentAddresses[4] = token1[i];
            } else {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV4PositionManager"),
                    true,
                    "modifyLiquidities(bytes,uint256)",
                    new address[](7),
                    string.concat("Increase liquidity for UniswapV4 position for ETH and ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV4PositionManager"),
                    false,
                    "modifyLiquidities(bytes,uint256)",
                    new address[](6),
                    string.concat(
                        "Decrease liquidity for UniswapV4 position for ",
                        ERC20(token0[i]).symbol(),
                        " and ",
                        ERC20(token1[i]).symbol(),
                        " using SETTLE"
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = token0[i];
                leafs[leafIndex].argumentAddresses[4] = token1[i];
                leafs[leafIndex].argumentAddresses[5] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV4PositionManager"),
                    false,
                    "modifyLiquidities(bytes,uint256)",
                    new address[](5),
                    string.concat(
                        "Decrease liquidity for UniswapV4 position for ",
                        ERC20(token0[i]).symbol(),
                        " and ",
                        ERC20(token1[i]).symbol(),
                        " using CLEAR_OR_TAKE or CLOSE_CURRENCY"
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = token0[i];
                leafs[leafIndex].argumentAddresses[4] = token1[i];
            } else {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV4PositionManager"),
                    false,
                    "modifyLiquidities(bytes,uint256)",
                    new address[](6),
                    string.concat(
                        "Decrease liquidity for UniswapV4 position for ETH and ",
                        ERC20(token1[i]).symbol(),
                        " using SETTLE"
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = token0[i];
                leafs[leafIndex].argumentAddresses[1] = token1[i];
                leafs[leafIndex].argumentAddresses[2] = hooks[i];
                leafs[leafIndex].argumentAddresses[3] = token0[i];
                leafs[leafIndex].argumentAddresses[4] = token1[i];
                leafs[leafIndex].argumentAddresses[5] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV4PositionManager"),
                    false,
                    "modifyLiquidities(bytes,uint256)",
                    new address[](5),
                    string.concat(
                        "Decrease liquidity for UniswapV4 position for ETH and ",
                        ERC20(token1[i]).symbol(),
                        " using CLEAR_OR_TAKE or CLOSE_CURRENCY"
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV4PositionManager"),
                    false,
                    "modifyLiquidities(bytes,uint256)",
                    new address[](6),
                    string.concat(
                        "Burn liquidity position for UniswapV4 position for ",
                        ERC20(token0[i]).symbol(),
                        " and ",
                        ERC20(token1[i]).symbol()
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "uniV4PositionManager"),
                    false,
                    "modifyLiquidities(bytes,uint256)",
                    new address[](6),
                    string.concat(
                        "Burn liquidity position for UniswapV4 position for ETH and ", ERC20(token1[i]).symbol()
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                    sourceChain, "camelotNonFungiblePositionManager"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve CamelotV3 NonFungible Position Manager to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                    sourceChain, "camelotNonFungiblePositionManager"
                )] = true;
            }
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                    sourceChain, "camelotNonFungiblePositionManager"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve CamelotV3 NonFungible Position Manager to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                    sourceChain, "camelotNonFungiblePositionManager"
                )] = true;
            }

            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                    sourceChain, "camelotRouterV3"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve CamelotV3 Router to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "camelotRouterV3");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                    sourceChain, "camelotRouterV3"
                )] = true;
            }
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                    sourceChain, "camelotRouterV3"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve CamelotV3 Router to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "camelotRouterV3");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                    sourceChain, "camelotRouterV3"
                )] = true;
            }

            // Minting
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "camelotNonFungiblePositionManager"),
                false,
                "mint((address,address,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
                new address[](3),
                string.concat("Mint CamelotV3 ", ERC20(token0[i]).symbol(), " ", ERC20(token1[i]).symbol(), " position"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            // Increase liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "camelotNonFungiblePositionManager"),
                false,
                "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
                new address[](4),
                string.concat(
                    "Add liquidity to CamelotV3 ",
                    ERC20(token0[i]).symbol(),
                    " ",
                    ERC20(token1[i]).symbol(),
                    " position"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(0);
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = token1[i];
            leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");

            // Swapping to move tick in pool.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "camelotRouterV3"),
                false,
                "exactInput((bytes,address,uint256,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Swap ", ERC20(token0[i]).symbol(), " for ", ERC20(token1[i]).symbol(), " using CamelotV3 router"
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
                getAddress(sourceChain, "camelotRouterV3"),
                false,
                "exactInput((bytes,address,uint256,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Swap ", ERC20(token1[i]).symbol(), " for ", ERC20(token0[i]).symbol(), " using CamelotV3 router"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token1[i];
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        }
        // Decrease liquidity
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "camelotNonFungiblePositionManager"),
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](1),
            "Remove liquidity from CamelotV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "camelotNonFungiblePositionManager"),
            false,
            "collect((uint256,address,uint128,uint128))",
            new address[](2),
            "Collect fees from CamelotV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        // burn
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "camelotNonFungiblePositionManager"),
            false,
            "burn(uint256)",
            new address[](0),
            "Burn CamelotV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Algebra V4 / Camelot V4 =========================================
    
    function _addAlgebraV4Leafs(ManageLeaf[] memory leafs, address[] memory token0, address[] memory token1, address deployer) internal {
        require(token0.length == token1.length, "Token arrays must be of equal length");
        for (uint256 i; i < token0.length; ++i) {
            (token0[i], token1[i]) = token0[i] < token1[i] ? (token0[i], token1[i]) : (token1[i], token0[i]);
            // Approvals
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                    sourceChain, "algebraNonFungiblePositionManager"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve AlgebraV4 NonFungible Position Manager to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "algebraNonFungiblePositionManager");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                    sourceChain, "algebraNonFungiblePositionManager"
                )] = true;
            }
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                    sourceChain, "algebraNonFungiblePositionManager"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve AlgebraV4 NonFungible Position Manager to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "algebraNonFungiblePositionManager");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                    sourceChain, "algebraNonFungiblePositionManager"
                )] = true;
            }

            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                    sourceChain, "algebraV4Router"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve AlgebraV4 Router to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "algebraV4Router");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][getAddress(
                    sourceChain, "algebraV4Router"
                )] = true;
            }
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                    sourceChain, "algebraV4Router"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve AlgebraV4 Router to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "algebraV4Router");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][getAddress(
                    sourceChain, "algebraV4Router"
                )] = true;
            }

            // Minting
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "algebraNonFungiblePositionManager"),
                false,
                "mint((address,address,address,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
                new address[](4),
                string.concat("Mint AlgebraV4 ", ERC20(token0[i]).symbol(), " ", ERC20(token1[i]).symbol(), " position"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = deployer;
            leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
            // Increase liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "algebraNonFungiblePositionManager"),
                false,
                "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
                new address[](5),
                string.concat(
                    "Add liquidity to AlgebraV4 ",
                    ERC20(token0[i]).symbol(),
                    " ",
                    ERC20(token1[i]).symbol(),
                    " position"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(0);
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = token1[i];
            leafs[leafIndex].argumentAddresses[3] = deployer; 
            leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");

            // Swapping to move tick in pool.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "algebraV4Router"),
                false,
                "exactInput((bytes,address,uint256,uint256,uint256))",
                new address[](4),
                string.concat(
                    "Swap ", ERC20(token0[i]).symbol(), " for ", ERC20(token1[i]).symbol(), " using AlgebraV4 router"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = deployer; 
            leafs[leafIndex].argumentAddresses[2] = token1[i];
            leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "algebraV4Router"),
                false,
                "exactInput((bytes,address,uint256,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Swap ", ERC20(token1[i]).symbol(), " for ", ERC20(token0[i]).symbol(), " using AlgebraV4 router"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token1[i];
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        }
        // Decrease liquidity
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "algebraNonFungiblePositionManager"),
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](1),
            "Remove liquidity from AlgebraV4 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "algebraNonFungiblePositionManager"),
            false,
            "collect((uint256,address,uint128,uint128))",
            new address[](2),
            "Collect fees from AlgebraV4 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        // burn
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "algebraNonFungiblePositionManager"),
            false,
            "burn(uint256)",
            new address[](0),
            "Burn AlgebraV4 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Balancer V2 Flashloans =========================================

    function _addBalancerFlashloanLeafs(ManageLeaf[] memory leafs, address tokenToFlashloan) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "managerAddress"),
            false,
            "flashLoan(address,address[],uint256[],bytes)",
            new address[](2),
            string.concat("Flashloan ", ERC20(tokenToFlashloan).symbol(), " from Balancer Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
                    && !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][possibleTokensIn[i]][getAddress(
                        sourceChain, "pendleRouter"
                    )]
            ) {
                ERC20 tokenIn = ERC20(possibleTokensIn[i]);
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    possibleTokensIn[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Pendle router to spend ", tokenIn.symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleRouter");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][possibleTokensIn[i]][getAddress(
                    sourceChain, "pendleRouter"
                )] = true;
            }
        }
        // Approve router to spend LP, SY, PT, YT
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            marketAddress,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Pendle router to spend LP-", underlyingAssetDescriptor),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleRouter");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            sy,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Pendle router to spend ", ERC20(sy).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleRouter");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            pt,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Pendle router to spend ", ERC20(pt).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleRouter");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            yt,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Pendle router to spend ", ERC20(yt).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleRouter");
        // Mint SY using input token.
        for (uint256 i; i < possibleTokensIn.length; ++i) {
            if (possibleTokensIn[i] != address(0)) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "pendleRouter"),
                    false,
                    "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
                    new address[](6),
                    string.concat("Mint ", ERC20(sy).symbol(), " using ", ERC20(possibleTokensIn[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "mintPyFromSy(address,address,uint256,uint256)",
            new address[](2),
            string.concat("Mint ", ERC20(pt).symbol(), " and ", ERC20(yt).symbol(), " from ", ERC20(sy).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = yt;
        // Swap between PT and YT.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "swapExactYtForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2),
            string.concat("Swap ", ERC20(yt).symbol(), " for ", ERC20(pt).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "swapExactPtForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2),
            string.concat("Swap ", ERC20(pt).symbol(), " for ", ERC20(yt).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        // Manage Liquidity.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "addLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            new address[](2),
            string.concat(
                "Mint LP-", underlyingAssetDescriptor, " using ", ERC20(sy).symbol(), " and ", ERC20(pt).symbol()
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "removeLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            new address[](2),
            string.concat(
                "Burn LP-", underlyingAssetDescriptor, " for ", ERC20(sy).symbol(), " and ", ERC20(pt).symbol()
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        // Burn PT and YT for SY.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "redeemPyToSy(address,address,uint256,uint256)",
            new address[](2),
            string.concat("Burn ", ERC20(pt).symbol(), " and ", ERC20(yt).symbol(), " for ", ERC20(sy).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = yt;
        // Redeem SY for output token.
        for (uint256 i; i < possibleTokensOut.length; ++i) {
            if (possibleTokensOut[i] != address(0)) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "pendleRouter"),
                    false,
                    "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
                    new address[](6),
                    string.concat("Burn ", ERC20(sy).symbol(), " for ", ERC20(possibleTokensOut[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "redeemDueInterestAndRewards(address,address[],address[],address[])",
            new address[](4),
            string.concat("Redeem due interest and rewards for ", underlyingAssetDescriptor, " Pendle"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = sy;
        leafs[leafIndex].argumentAddresses[2] = yt;
        leafs[leafIndex].argumentAddresses[3] = marketAddress;

        // Swap between SY and PT
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "swapExactSyForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256),(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
            new address[](2),
            string.concat("Swap ", ERC20(sy).symbol(), " for ", ERC20(pt).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "swapExactPtForSy(address,address,uint256,uint256,(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
            new address[](2),
            string.concat("Swap ", ERC20(pt).symbol(), " for ", ERC20(sy).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;

        // Swap between SY and YT
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "swapExactSyForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256),(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
            new address[](2),
            string.concat("Swap ", ERC20(sy).symbol(), " for ", ERC20(yt).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "swapExactYtForSy(address,address,uint256,uint256,(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
            new address[](2),
            string.concat("Swap ", ERC20(yt).symbol(), " for ", ERC20(sy).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;

        if (allowLimitOrderFills) {
            // Re-add the swap between SY and PT and YT leaves, but add in the limit order router, and YT in the argumentAddresses.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "pendleRouter"),
                false,
                "swapExactSyForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256),(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
                new address[](4),
                string.concat("Swap ", ERC20(sy).symbol(), " for ", ERC20(pt).symbol(), " with limit orders"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = marketAddress;
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "pendleLimitOrderRouter");
            leafs[leafIndex].argumentAddresses[3] = yt;
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "pendleRouter"),
                false,
                "swapExactPtForSy(address,address,uint256,uint256,(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
                new address[](4),
                string.concat("Swap ", ERC20(pt).symbol(), " for ", ERC20(sy).symbol(), " with limit orders"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = marketAddress;
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "pendleLimitOrderRouter");
            leafs[leafIndex].argumentAddresses[3] = yt;

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "pendleRouter"),
                false,
                "swapExactSyForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256),(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
                new address[](4),
                string.concat("Swap ", ERC20(sy).symbol(), " for ", ERC20(yt).symbol(), " with limit orders"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = marketAddress;
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "pendleLimitOrderRouter");
            leafs[leafIndex].argumentAddresses[3] = yt;
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "pendleRouter"),
                false,
                "swapExactYtForSy(address,address,uint256,uint256,(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
                new address[](4),
                string.concat("Swap ", ERC20(yt).symbol(), " for ", ERC20(sy).symbol(), " with limit orders"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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

        if (
            !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][yt][getAddress(
                sourceChain, "pendleLimitOrderRouter"
            )]
        ) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                yt,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Pendle Limit Order Router to spend ", ERC20(yt).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleLimitOrderRouter");
            ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][yt][getAddress(
                sourceChain, "pendleLimitOrderRouter"
            )] = true;
        }

        if (
            !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][pt][getAddress(
                sourceChain, "pendleLimitOrderRouter"
            )]
        ) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                pt,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Pendle Limit Order Router to spend ", ERC20(pt).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleLimitOrderRouter");
            ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][pt][getAddress(
                sourceChain, "pendleLimitOrderRouter"
            )] = true;
        }

        if (
            !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][sy][getAddress(
                sourceChain, "pendleLimitOrderRouter"
            )]
        ) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                sy,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Pendle Limit Order Router to spend ", ERC20(sy).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleLimitOrderRouter");
            ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][sy][getAddress(
                sourceChain, "pendleLimitOrderRouter"
            )] = true;
        }

        // Add fill leaf.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleLimitOrderRouter"),
            false,
            "fill(((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],address,uint256,bytes,bytes)",
            new address[](2),
            string.concat("Fill Limit orders for ", ERC20(sy).symbol(), " Pendle market"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
                    && !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(tokens[i])][getAddress(
                        sourceChain, "balancerVault"
                    )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(tokens[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Balancer Vault to spend ", tokens[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "balancerVault");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(tokens[i])][getAddress(
                    sourceChain, "balancerVault"
                )] = true;
            }
            tokenCount++;
        }

        // Approve gauge.
        if (gauge != address(0)) {
            if (!ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][pool][gauge]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    pool,
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Balancer gauge to spend ", ERC20(pool).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "balancerVault"),
            false,
            "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](addressArguments.length),
            string.concat("Join Balancer pool ", ERC20(pool).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        for (uint256 i; i < addressArguments.length; i++) {
            leafs[leafIndex].argumentAddresses[i] = addressArguments[i];
        }

        // Exit pool
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "balancerVault"),
            false,
            "exitPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](addressArguments.length),
            string.concat("Exit Balancer pool ", ERC20(pool).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        for (uint256 i; i < addressArguments.length; i++) {
            leafs[leafIndex].argumentAddresses[i] = addressArguments[i];
        }

        // Deposit into gauge.
        if (gauge != address(0)) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauge,
                false,
                "deposit(uint256,address)",
                new address[](1),
                string.concat("Deposit ", ERC20(pool).symbol(), " into Balancer gauge"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Withdraw from gauge.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauge,
                false,
                "withdraw(uint256)",
                new address[](0),
                string.concat("Withdraw ", ERC20(pool).symbol(), " from Balancer gauge"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );

            if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mainnet))) {
                // Mint rewards.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "minter"),
                    false,
                    "mint(address)",
                    new address[](1),
                    string.concat("Mint rewards from Balancer gauge"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = gauge;
            } else {
                // Call claim_rewards(address) on gauge.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    gauge,
                    false,
                    "claim_rewards(address)",
                    new address[](1),
                    string.concat("Claim rewards from Balancer gauge"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
                    && !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(tokens[i])][getAddress(
                        sourceChain, "balancerVault"
                    )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(tokens[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Balancer Vault to spend ", tokens[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "balancerVault");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(tokens[i])][getAddress(
                    sourceChain, "balancerVault"
                )] = true;
            }
            tokenCount++;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "balancerVault"),
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            string.concat("Swap ", tokens[0].symbol(), " for ", tokens[1].symbol(), " using Balancer"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = pool;
        leafs[leafIndex].argumentAddresses[1] = address(tokens[0]);
        leafs[leafIndex].argumentAddresses[2] = address(tokens[1]);
        leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "balancerVault"),
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            string.concat("Swap ", tokens[1].symbol(), " for ", tokens[0].symbol(), " using Balancer"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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

            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(tokens[i])][_pool]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(tokens[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Permit2 to spend ", ERC20(tokens[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "permit2");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(tokens[i])][getAddress(
                    sourceChain, "permit2"
                )] = true;

                //use permit2 to approve router
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "permit2"),
                    false,
                    "approve(address,address,uint160,uint48)",
                    new address[](2),
                    string.concat("Use Permit2 to approve ", pool.name(), " to spend ", ERC20(tokens[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = tokens[i];
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "balancerV3Router");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(tokens[i])][getAddress(
                    sourceChain, "balancerV3Router"
                )] = true;
            }

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "permit2"),
                false,
                "lockdown((address,address)[])",
                new address[](2),
                string.concat("Revoke approval from BalancerV3Router for ", ERC20(tokens[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = tokens[i];
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "balancerV3Router");
        }

        if (
            !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(_pool)][getAddress(
                sourceChain, "permit2"
            )]
        ) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(_pool),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Router to spend bpt: ", ERC20(_pool).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "balancerV3Router");
            ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(_pool)][getAddress(
                sourceChain, "balancerV3Router"
            )] = true;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "balancerV3Router"),
            false,
            "addLiquidityProportional(address,uint256[],uint256,bool,bytes)",
            new address[](1),
            string.concat("Add liquidty proportional to ", pool.name(), " on BalancerV3"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = _pool;

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "balancerV3Router"),
                true,
                "addLiquidityProportional(address,uint256[],uint256,bool,bytes)",
                new address[](1),
                string.concat("Add liquidty proportional to ", pool.name(), " on BalancerV3"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "balancerV3Router"),
            false,
            "addLiquidityUnbalanced(address,uint256[],uint256,bool,bytes)",
            new address[](1),
            string.concat("Add liquidty unbalanced to ", pool.name(), " on BalancerV3"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = _pool;

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "balancerV3Router"),
                true,
                "addLiquidityUnbalanced(address,uint256[],uint256,bool,bytes)",
                new address[](1),
                string.concat("Add liquidty proportional to ", pool.name(), " on BalancerV3"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "balancerV3Router"),
            false,
            "addLiquiditySingleTokenExactOut(address,address,uint256,uint256,bool,bytes)",
            new address[](1),
            string.concat("Add liquidty unbalanced to ", pool.name(), " on BalancerV3"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = _pool;
        //leafs[leafIndex].argumentAddresses[1] = _pool;

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "balancerV3Router"),
                true,
                "addLiquiditySingleTokenExactOut(address,address,uint256,uint256,bool,bytes)",
                new address[](1),
                string.concat("Add liquidty proportional to ", pool.name(), " on BalancerV3"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "balancerV3Router"),
            false,
            "addLiquidityCustom(address,uint256[],uint256,bool,bytes)",
            new address[](1),
            string.concat("Add liquidty custom to ", pool.name(), " on BalancerV3"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = _pool;

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "balancerV3Router"),
                true,
                "addLiquidityCustom(address,uint256[],uint256,bool,bytes)",
                new address[](1),
                string.concat("Add liquidty custom to ", pool.name(), " on BalancerV3"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "balancerV3Router"),
            false,
            "removeLiquidityProportional(address,uint256,uint256[],bool,bytes)",
            new address[](1),
            string.concat("Remove liquidity proportional to ", pool.name(), " on BalancerV3"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = _pool;

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "balancerV3Router"),
                true,
                "removeLiquidityProportional(address,uint256,uint256[],bool,bytes)",
                new address[](1),
                string.concat("Remove liquidity proportional to ", pool.name(), " on BalancerV3"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "balancerV3Router"),
            false,
            "removeLiquiditySingleTokenExactIn(address,uint256,address,uint256,bool,bytes)",
            new address[](1),
            string.concat("Remove liquidty single token exact in from ", pool.name()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = _pool;

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "balancerV3Router"),
                true,
                "removeLiquiditySingleTokenExactIn(address,uint256,address,uint256,bool,bytes)",
                new address[](1),
                string.concat("Remove liquidty single token exact in from ", pool.name()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "balancerV3Router"),
            false,
            "removeLiquiditySingleTokenExactOut(address,uint256,address,uint256,bool,bytes)",
            new address[](1),
            string.concat("Remove Liquidity single token exact out from ", pool.name()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = _pool;

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "balancerV3Router"),
                true,
                "removeLiquiditySingleTokenExactOut(address,uint256,address,uint256,bool,bytes)",
                new address[](1),
                string.concat("Remove liquidty single token exact in from ", pool.name()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "balancerV3Router"),
            false,
            "removeLiquidityCustom(address,uint256,uint256[],bool,bytes)",
            new address[](1),
            string.concat("Remove Liquidity custom from ", pool.name()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = _pool;

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "balancerV3Router"),
                true,
                "removeLiquidityCustom(address,uint256,uint256[],bool,bytes)",
                new address[](1),
                string.concat("Remove Liquidity custom from ", pool.name()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "balancerV3Router"),
            false,
            "removeLiquidityRecovery(address,uint256,uint256[])",
            new address[](1),
            string.concat("Remove Liquidity in recovery mode from ", pool.name()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
            leafs[leafIndex] = ManageLeaf(
                address(tokens[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Permit2 to spend ", ERC20(tokens[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "permit2");
            ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(tokens[i])][getAddress(
                sourceChain, "permit2"
            )] = true;

            //use permit2 to approve router
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "permit2"),
                false,
                "approve(address,address,uint160,uint48)",
                new address[](2),
                string.concat("Use Permit2 to approve ", pool.name(), " to spend ", ERC20(tokens[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = tokens[i];
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "balancerV3Router");
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "balancerV3Router"),
            false,
            "swapSingleTokenExactIn(address,address,address,uint256,uint256,uint256,bool,bytes)",
            new address[](1),
            string.concat("Swap tokens using ", ERC20(_pool).name()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = _pool;
        //leafs[leafIndex].argumentAddresses[1] = tokens[0]; //token0
        //leafs[leafIndex].argumentAddresses[2] = tokens[1]; //token1...tokenN

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "balancerV3Router"),
                true,
                "swapSingleTokenExactIn(address,address,address,uint256,uint256,uint256,bool,bytes)",
                new address[](1),
                string.concat("Swap tokens using ", ERC20(_pool).name()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = _pool;
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "balancerV3Router"),
            false,
            "swapSingleTokenExactOut(address,address,address,uint256,uint256,uint256,bool,bytes)",
            new address[](1),
            string.concat("Swap tokens using ", ERC20(_pool).name()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = _pool;
        //leafs[leafIndex].argumentAddresses[1] = tokens[0]; //token0
        //leafs[leafIndex].argumentAddresses[2] = tokens[1]; //token1...tokenN

        if (hasEth) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "balancerV3Router"),
                true,
                "swapSingleTokenExactOut(address,address,address,uint256,uint256,uint256,bool,bytes)",
                new address[](1),
                string.concat("Swap tokens using ", ERC20(_pool).name()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
            leafs[leafIndex] = ManageLeaf(
                address(bpt),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve ", auraVault.symbol(), " to spend ", bpt.symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = auraDeposit;
            ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(bpt)][auraDeposit] =
                true;
        }

        // Deposit BPT into Aura vault.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            auraDeposit,
            false,
            "deposit(uint256,address)",
            new address[](1),
            string.concat("Deposit ", bpt.symbol(), " into ", auraVault.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Withdraw BPT from Aura vault.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            auraDeposit,
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            string.concat("Withdraw ", bpt.symbol(), " from ", auraVault.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        // Call getReward.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            auraDeposit,
            false,
            "getReward(address,bool)",
            new address[](1),
            string.concat("Get rewards from ", auraVault.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        if (
            !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][marketParams.loanToken][getAddress(
                sourceChain, "morphoBlue"
            )]
        ) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                marketParams.loanToken,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve MorhoBlue to spend ", loanToken.symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "morphoBlue");
            ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][marketParams.loanToken][getAddress(
                sourceChain, "morphoBlue"
            )] = true;
        }
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "morphoBlue"),
            false,
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            new address[](5),
            string.concat("Supply ", loanToken.symbol(), " to ", morphoBlueMarketName),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
        leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
        leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
        leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
        leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "morphoBlue"),
            false,
            "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            new address[](6),
            string.concat("Withdraw ", loanToken.symbol(), " from ", morphoBlueMarketName),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        if (
            !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][marketParams.collateralToken][getAddress(
                sourceChain, "morphoBlue"
            )]
        ) {
            if (address(collateralToken) != address(0)) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    marketParams.collateralToken,
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve MorhoBlue to spend ", collateralToken.symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "morphoBlue");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][marketParams
                    .collateralToken][getAddress(sourceChain, "morphoBlue")] = true;
            }
        }
        // Approve morpho blue to spend loan token.
        if (
            !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][marketParams.collateralToken][getAddress(
                sourceChain, "morphoBlue"
            )]
        ) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                marketParams.loanToken,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve MorhoBlue to spend ", loanToken.symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "morphoBlue");
            ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][marketParams.loanToken][getAddress(
                sourceChain, "morphoBlue"
            )] = true;
        }
        // Supply collateral to MorphoBlue.

        if (address(collateralToken) != address(0)) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "morphoBlue"),
                false,
                "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)",
                new address[](5),
                string.concat("Supply ", collateralToken.symbol(), " to ", morphoBlueMarketName),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "morphoBlue"),
            false,
            "borrow((address,address,address,address,uint256),uint256,uint256,address,address)",
            new address[](6),
            string.concat("Borrow ", loanToken.symbol(), " from ", morphoBlueMarketName),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "morphoBlue"),
            false,
            "repay((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            new address[](5),
            string.concat("Repay ", loanToken.symbol(), " to ", morphoBlueMarketName),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "morphoBlue"),
                false,
                "withdrawCollateral((address,address,address,address,uint256),uint256,address,address)",
                new address[](6),
                string.concat("Withdraw ", collateralToken.symbol(), " from ", morphoBlueMarketName),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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

        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "morphoBlue"),
            false,
            "repay((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            new address[](5),
            string.concat("Repay ", loanToken.symbol(), " to ", morphoBlueMarketName),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        leafs[leafIndex] = ManageLeaf(
            legacyToken,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve morpho rewards wrapper to spend legacy morpho",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "morphoRewardsWrapper");

        // Approve morpho rewards wrapper to spend new morpho.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            newToken,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve morpho rewards wrapper to spend new morpho",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "morphoRewardsWrapper");

        // Wrapping
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            wrapper,
            false,
            "depositFor(address,uint256)",
            new address[](1),
            "Wrap legacy morpho for new morpho",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Unwrapping
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            wrapper,
            false,
            "withdrawTo(address,uint256)",
            new address[](1),
            "Unwrap new morpho for legacy morpho",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }


    function _addMorphoRewardMerkleClaimerLeafs(ManageLeaf[] memory leafs, address universalRewardsDistributor)
        internal
    {
        // Claim morpho rewards.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            universalRewardsDistributor,
            false,
            "claim(address,address,uint256,bytes32[])",
            new address[](1),
            "Claim morpho rewards",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= ERC4626 =========================================

    function _addERC4626Leafs(ManageLeaf[] memory leafs, ERC4626 vault) internal {
        ERC20 asset = vault.asset();
        // Approvals
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(asset),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve ", vault.symbol(), " to spend ", asset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(vault);
        // Depositing
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "deposit(uint256,address)",
            new address[](1),
            string.concat("Deposit ", asset.symbol(), " for ", vault.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        // Withdrawing
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            string.concat("Withdraw ", asset.symbol(), " from ", vault.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        // Minting
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "mint(uint256,address)",
            new address[](1),
            string.concat("Mint ", vault.symbol(), " using ", asset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Redeeming
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "redeem(uint256,address,address)",
            new address[](2),
            string.concat("Redeem ", vault.symbol(), " for ", asset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
    }

    function _addERC4626SubaccountLeafs(ManageLeaf[] memory leafs, ERC4626 vault, address subaccount) internal {
        ERC20 asset = vault.asset();
        // Approvals
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(asset),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve ", vault.symbol(), " to spend ", asset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(vault);
        // Depositing
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "deposit(uint256,address)",
            new address[](1),
            string.concat("Deposit ", asset.symbol(), " for ", vault.symbol(), " for ", vm.toString(subaccount)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = subaccount;
        // Withdrawing
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            string.concat("Withdraw ", asset.symbol(), " from ", vault.symbol(), " for ", vm.toString(subaccount)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = subaccount;

        // Minting
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "mint(uint256,address)",
            new address[](1),
            string.concat("Mint ", vault.symbol(), " using ", asset.symbol(), " for ", vm.toString(subaccount)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = subaccount;

        // Redeeming
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "redeem(uint256,address,address)",
            new address[](2),
            string.concat("Redeem ", vault.symbol(), " for ", asset.symbol(), " for ", vm.toString(subaccount)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve ", vault.symbol(), " gauge to spend", vault.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = gauge;

        // Deposit vault share into gauge.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            gauge,
            false,
            "deposit(uint256,address)",
            new address[](1),
            string.concat("Deposit ", vault.symbol(), " share into gauge"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Withdraw vault share from gauge.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            gauge,
            false,
            "withdraw(uint256)",
            new address[](0),
            string.concat("Withdraw ", vault.symbol(), " share from gauge"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Claim rewards from gauge.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            gauge,
            false,
            "claim_rewards(address)",
            new address[](1),
            string.concat("Claim rewards from gauge"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        leafs[leafIndex] = ManageLeaf(
            address(dieselVault),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve s", dieselVaultSymbol, " to spend ", dieselVaultSymbol),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = dieselStaking;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            dieselStaking,
            false,
            "deposit(uint256)",
            new address[](0),
            string.concat("Deposit ", dieselVaultSymbol, " for s", dieselVaultSymbol),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            dieselStaking,
            false,
            "withdraw(uint256)",
            new address[](0),
            string.concat("Withdraw ", dieselVaultSymbol, " from s", dieselVaultSymbol),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            dieselStaking,
            false,
            "claim()",
            new address[](0),
            string.concat("Claim rewards from s", dieselVaultSymbol),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Atomic Queue =========================================

    function _addAtomicQueueLeafs(ManageLeaf[] memory leafs, address queue, ERC20 offer, ERC20 want) internal {
        // approve
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(offer),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve queue to spend ", offer.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = queue;
        // updateAtomicRequest
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            queue,
            false,
            "updateAtomicRequest(address,address,(uint64,uint88,uint96,bool))",
            new address[](2),
            string.concat("Update Atomic Request offer: ", offer.symbol(), " want: ", want.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        leafs[leafIndex] = ManageLeaf(
            lst,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Eigen Layer Strategy Manager to spend ", ERC20(lst).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = _strategyManager;
        ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][lst][_strategyManager] = true;
        // Depositing.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _strategyManager,
            false,
            "depositIntoStrategy(address,address,uint256)",
            new address[](2),
            string.concat("Deposit ", ERC20(lst).symbol(), " into Eigen Layer Strategy Manager"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = strategy;
        leafs[leafIndex].argumentAddresses[1] = lst;
        // Request withdraw.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _delegationManager,
            false,
            "queueWithdrawals((address[],uint256[],address)[])",
            new address[](2),
            string.concat("Request withdraw of ", ERC20(lst).symbol(), " from Eigen Layer Delegation Manager"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = strategy;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        // Complete withdraw.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _delegationManager,
            false,
            "completeQueuedWithdrawals((address,address,address,uint256,uint32,address[],uint256[])[],address[][],uint256[],bool[])",
            new address[](5),
            string.concat("Complete withdraw of ", ERC20(lst).symbol(), " from Eigen Layer Delegation Manager"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = address(0);
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[3] = strategy;
        leafs[leafIndex].argumentAddresses[4] = lst;

        //new leaf version
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _delegationManager,
            false,
            "completeQueuedWithdrawals((address,address,address,uint256,uint32,address[],uint256[])[],address[][],bool[])",
            new address[](5),
            string.concat("Complete withdraw of ", ERC20(lst).symbol(), " from Eigen Layer Delegation Manager"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = address(0);
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[3] = strategy;
        leafs[leafIndex].argumentAddresses[4] = lst;

        //new leaf version
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _delegationManager,
            false,
            "completeQueuedWithdrawals((address,address,address,uint256,uint32,address[],uint256[])[],address[][],bool[])",
            new address[](5),
            string.concat("Complete withdraw of ", ERC20(lst).symbol(), " from Eigen Layer Delegation Manager from ", vm.toString(operator)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = operator;
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[3] = strategy;
        leafs[leafIndex].argumentAddresses[4] = lst;

        // Delegation.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _delegationManager,
            false,
            "delegateTo(address,(bytes,uint256),bytes32)",
            new address[](1),
            string.concat("Delegate to ", vm.toString(operator)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = operator;

        // Undelegate
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _delegationManager,
            false,
            "undelegate(address)",
            new address[](1),
            string.concat("Undelegate from ", vm.toString(operator)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Handle reward claiming.
        if (claimerFor != address(0)) {
            // Add setClaimerFor leaf.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                rewardsContract,
                false,
                "setClaimerFor(address)",
                new address[](1),
                string.concat("Set rewards claimer to ", vm.toString(claimerFor)),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = claimerFor;
        }

        // Add processClaim leaf.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            rewardsContract,
            false,
            "processClaim((uint32,uint32,bytes,(address,bytes32),uint32[],bytes[],(address,uint256)[]),address)",
            new address[](1),
            string.concat("Process claim for EIGEN Rewards"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
            leafs[leafIndex] = ManageLeaf(
                asset,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Swell Simple Staking to spend ", ERC20(asset).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = _swellSimpleStaking;
            ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][asset][_swellSimpleStaking] =
                true;
        }
        // deposit
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _swellSimpleStaking,
            false,
            "deposit(address,uint256,address)",
            new address[](2),
            string.concat("Deposit ", ERC20(asset).symbol(), " into Swell Simple Staking"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = asset;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        // withdraw
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _swellSimpleStaking,
            false,
            "withdraw(address,uint256,address)",
            new address[](2),
            string.concat("Withdraw ", ERC20(asset).symbol(), " from Swell Simple Staking"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        leafs[leafIndex] = ManageLeaf(
            address(asset),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Hyperlane Token Router to spend ", asset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = hyperlaneTokenRouter;

        // Call transferRemote on hyperlaneTokenRouter
        address recipient0 = address(bytes20(bytes16(recipient)));
        address recipient1 = address(bytes20(bytes16(recipient << 128)));
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            hyperlaneTokenRouter,
            true,
            "transferRemote(uint32,bytes32,uint256)",
            new address[](3),
            string.concat(
                "Bridge ", asset.symbol(), " to ", vm.toString(destinationDomain), " via Hyperlane Token Router"
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
                    leafs[leafIndex] = ManageLeaf(
                        address(assets[i]),
                        false,
                        "approve(address,uint256)",
                        new address[](1),
                        string.concat("Approve USDC Token Router to spend ", assets[i].symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "usdcTokenRouter");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "usdcTokenRouter"),
                        false,
                        "transferTokens(uint256,uint32,address,address)",
                        new address[](3),
                        string.concat("Transfer USDC to TokenRouter to bridge"),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
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
                    leafs[leafIndex] = ManageLeaf(
                        address(assets[i]),
                        false,
                        "approve(address,uint256)",
                        new address[](1),
                        string.concat("Approve USDC Token Router to spend ", assets[i].symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "usdcTokenRouter");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "usdcTokenRouter"),
                        false,
                        "transferTokens(uint256,uint32,address,address)",
                        new address[](3),
                        string.concat("Transfer USDC to TokenRouter to bridge"),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
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
            leafs[leafIndex] = ManageLeaf(
                address(assets[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Corn Silo to spend ", assets[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "cornSilo");

            if (address(assets[i]) == getAddress(sourceChain, "WBTC")) {
                // Need to add special bitcorn leafs.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "cornSilo"),
                    false,
                    "mintAndDepositBitcorn(uint256)",
                    new address[](0),
                    string.concat("Deposit ", assets[i].symbol(), " into cornSilo for Bitcorn"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "cornSilo"),
                    false,
                    "redeemBitcorn(uint256)",
                    new address[](0),
                    string.concat("Burn Bitcorn from cornSilo for ", assets[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
            } else {
                // use generic deposit and withdraw
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "cornSilo"),
                    false,
                    "deposit(address,uint256)",
                    new address[](1),
                    string.concat("Deposit ", assets[i].symbol(), " into cornSilo"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(assets[i]);

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "cornSilo"),
                    false,
                    "redeemToken(address,uint256)",
                    new address[](1),
                    string.concat("Withdraw ", assets[i].symbol(), " from cornSilo"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
        leafs[leafIndex] = ManageLeaf(
            address(asset),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Pump Staking to spend ", asset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = pumpStaking;

        // Stake
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            pumpStaking,
            false,
            "stake(uint256)",
            new address[](0),
            string.concat("Stake ", asset.symbol(), " into Pump Staking"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Unstake Request
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            pumpStaking,
            false,
            "unstakeRequest(uint256)",
            new address[](0),
            string.concat("Request unstake of ", asset.symbol(), " from Pump Staking"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Claim Slot
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            pumpStaking,
            false,
            "claimSlot(uint8)",
            new address[](0),
            string.concat("Claim slot from Pump Staking"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Claim All
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            pumpStaking,
            false,
            "claimAll()",
            new address[](0),
            string.concat("Claim all withdraws from Pump Staking"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Unstake Instant
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            pumpStaking,
            false,
            "unstakeInstant(uint256)",
            new address[](0),
            string.concat("Unstake ", asset.symbol(), " instantly from Pump Staking"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Satlayer Staking =========================================

    function _addSatlayerStakingLeafs(ManageLeaf[] memory leafs, ERC20[] memory assets) internal {
        address satlayerPool = getAddress(sourceChain, "satlayerPool");
        for (uint256 i; i < assets.length; ++i) {
            // Approval
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(assets[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Satlayer Pool to spend ", ERC20(assets[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = satlayerPool;
            // deposit
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                satlayerPool,
                false,
                "depositFor(address,address,uint256)",
                new address[](2),
                string.concat("Deposit ", ERC20(assets[i]).symbol(), " into Satlayer Pool"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            // withdraw
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                satlayerPool,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                string.concat("Withdraw ", ERC20(assets[i]).symbol(), " from Satlayer Pool"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
        }
    }

    // ========================================= Zircuit Staking =========================================

    function _addZircuitLeafs(ManageLeaf[] memory leafs, address asset, address _zircuitSimpleStaking) internal {
        // Approval
        if (
            !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][asset][_zircuitSimpleStaking]
        ) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                asset,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Zircuit simple staking to spend ", ERC20(asset).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = _zircuitSimpleStaking;
            ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][asset][_zircuitSimpleStaking]
            = true;
        }
        // deposit
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _zircuitSimpleStaking,
            false,
            "depositFor(address,address,uint256)",
            new address[](2),
            string.concat("Deposit ", ERC20(asset).symbol(), " into Zircuit simple staking"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = asset;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        // withdraw
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _zircuitSimpleStaking,
            false,
            "withdraw(address,uint256)",
            new address[](1),
            string.concat("Withdraw ", ERC20(asset).symbol(), " from Zircuit simple staking"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = asset;
    }

    // ========================================= Ethena Withdraws =========================================

    function _addEthenaSUSDeWithdrawLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "SUSDE"),
            false,
            "cooldownAssets(uint256)",
            new address[](0),
            "Withdraw from sUSDe specifying asset amount.",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "SUSDE"),
            false,
            "cooldownShares(uint256)",
            new address[](0),
            "Withdraw from sUSDe specifying share amount.",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "SUSDE"),
            false,
            "unstake(address)",
            new address[](1),
            "Complete withdraw from sUSDe.",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Ethena Minting =========================================
    function _addEthenaMintingLeafs(ManageLeaf[] memory leafs, address signer) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "USDE"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Ethena Minter V2 to spend ", getERC20(sourceChain, "USDE").symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "ethenaMinterV2");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "ethenaMinterV2"),
            false,
            "setDelegatedSigner(address)",
            new address[](1),
            string.concat("Set ", vm.toString(signer), " as delegated EthenaMinter Signer"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = signer;  

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "ethenaMinterV2"),
            false,
            "removeDelegatedSigner(address)",
            new address[](1),
            string.concat("Remove ", vm.toString(signer), " as delegated EthenaMinter Signer"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = signer;  


        address[] memory stables = new address[](2); 
        stables[0] = getAddress(sourceChain, "USDT"); 
        stables[1] = getAddress(sourceChain, "USDC"); 
        
        for (uint256 i = 0; i < stables.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                stables[i],
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Ethena Minter V2 to spend ", ERC20(stables[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "ethenaMinterV2");

            
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "ethenaMinterV2"),
                false,
                "mint((string,uint8,uint120,uint128,address,address,address,uint128,uint128),(address[],uint128[]),(uint8,bytes))",
                new address[](3),
                string.concat("Mint USDE with ", ERC20(stables[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = stables[i];

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "ethenaMinterV2"),
                false,
                "redeem((string,uint8,uint120,uint128,address,address,address,uint128,uint128),(uint8,bytes))",
                new address[](3),
                string.concat("Redeem USDE for ", ERC20(stables[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "slvlUSD"),
            false,
            "cooldownAssets(uint256)",
            new address[](0),
            "Withdraw from slvlUSD specifying asset amount.",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "slvlUSD"),
            false,
            "cooldownShares(uint256)",
            new address[](0),
            "Withdraw from slvlUSD specifying share amount.",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "slvlUSD"),
            false,
            "unstake(address)",
            new address[](1),
            "Complete withdraw from slvlUSD.",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Elixir Withdraws =========================================

    function _addElixirSdeUSDWithdrawLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "sdeUSD"),
            false,
            "cooldownAssets(uint256)",
            new address[](0),
            "Withdraw from sdeUSD specifying asset amount.",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "sdeUSD"),
            false,
            "cooldownShares(uint256)",
            new address[](0),
            "Withdraw from sdeUSD specifying share amount.",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "sdeUSD"),
            false,
            "unstake(address)",
            new address[](1),
            "Complete withdraw from sdeUSD.",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Fluid FToken =========================================

    function _addFluidFTokenLeafs(ManageLeaf[] memory leafs, address fToken) internal {
        ERC20 asset = ERC4626(fToken).asset();
        // Approval.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(asset),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Fluid ", ERC20(fToken).symbol(), " to spend ", asset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = fToken;

        // Depositing
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            fToken,
            false,
            "deposit(uint256,address,uint256)",
            new address[](1),
            string.concat("Deposit ", asset.symbol(), " for ", ERC20(fToken).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        // Withdrawing
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            fToken,
            false,
            "withdraw(uint256,address,address,uint256)",
            new address[](2),
            string.concat("Withdraw ", asset.symbol(), " from ", ERC20(fToken).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        // Minting
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            fToken,
            false,
            "mint(uint256,address,uint256)",
            new address[](1),
            string.concat("Mint ", ERC20(fToken).symbol(), " using ", asset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Redeeming
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            fToken,
            false,
            "redeem(uint256,address,address,uint256)",
            new address[](2),
            string.concat("Redeem ", ERC20(fToken).symbol(), " for ", asset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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

                leafs[leafIndex] = ManageLeaf(
                    address(supplyTokens[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Fluid Dex to spend ", supplyTokens[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = dex;
            }
        }

        for (uint256 i = 0; i < borrowTokens.length; i++) {
            if (address(borrowTokens[i]) != getAddress(sourceChain, "ETH")) {
                unchecked {
                    leafIndex++;
                }

                leafs[leafIndex] = ManageLeaf(
                    address(borrowTokens[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Fluid Dex to spend ", borrowTokens[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = dex;
            }
        }

        if (dexType == 1000) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(dex),
                false,
                "operate(uint256,int256,int256,address)",
                new address[](1),
                string.concat("Operate on Fluid Dex Vault"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }

        //t2 and t3 leaves
        if (dexType == 2000 || dexType == 3000) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(dex),
                false,
                "operate(uint256,int256,int256,int256,int256,address)",
                new address[](1),
                string.concat("Operate on Fluid Dex Vault"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(dex),
                false,
                "operatePerfect(uint256,int256,int256,int256,int256,address)",
                new address[](1),
                string.concat("Operate Perfect on Fluid Dex Vault"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            if (addNative) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(dex),
                    true,
                    "operate(uint256,int256,int256,int256,int256,address)",
                    new address[](1),
                    string.concat("Operate on Fluid Dex Vault with native ETH"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(dex),
                    true,
                    "operatePerfect(uint256,int256,int256,int256,int256,address)",
                    new address[](1),
                    string.concat("Operate Perfect on Fluid Dex Vault with native ETH"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            }
        }

        //t4 leaves
        if (dexType == 4000) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(dex),
                false,
                "operate(uint256,int256,int256,int256,int256,int256,int256,address)",
                new address[](1),
                string.concat("Operate on Fluid Dex Vault"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(dex),
                false,
                "operatePerfect(uint256,int256,int256,int256,int256,int256,int256,address)",
                new address[](1),
                string.concat("Operate Perfect on Fluid Dex Vault"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            if (addNative) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(dex),
                    true,
                    "operate(uint256,int256,int256,int256,int256,int256,int256,address)",
                    new address[](1),
                    string.concat("Operate on Fluid Dex Vault with native ETH"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(dex),
                    true,
                    "operatePerfect(uint256,int256,int256,int256,int256,int256,int256,address)",
                    new address[](1),
                    string.concat("Operate Perfect on Fluid Dex Vault with native ETH"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            }
        }
    }

    // ========================================= Symbiotic =========================================

    function _addSymbioticApproveAndDepositLeaf(ManageLeaf[] memory leafs, address defaultCollateral) internal {
        ERC4626 dc = ERC4626(defaultCollateral);
        ERC20 depositAsset = dc.asset();
        // Approve
        if (
            !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(depositAsset)][defaultCollateral]
        ) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(depositAsset),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Symbiotic ", dc.name(), " to spend ", depositAsset.symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = defaultCollateral;
            ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(depositAsset)][defaultCollateral]
            = true;
        }
        // Deposit
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            defaultCollateral,
            false,
            "deposit(address,uint256)",
            new address[](1),
            string.concat("Deposit ", depositAsset.symbol(), " into Symbiotic ", ERC20(defaultCollateral).name()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    function _addSymbioticLeafs(ManageLeaf[] memory leafs, address[] memory defaultCollaterals) internal {
        for (uint256 i; i < defaultCollaterals.length; i++) {
            _addSymbioticApproveAndDepositLeaf(leafs, defaultCollaterals[i]);
            // Withdraw
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                defaultCollaterals[i],
                false,
                "withdraw(address,uint256)",
                new address[](1),
                string.concat(
                    "Withdraw ",
                    ERC20(defaultCollaterals[i]).symbol(),
                    " from Symbiotic ",
                    ERC20(defaultCollaterals[i]).name()
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(assets[i])][vaults[i]]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(assets[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Symbiotic Vault ", vm.toString(vaults[i]), " to spend ", assets[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = vaults[i];
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(assets[i])][vaults[i]]
                = true;
            }
            // Deposit
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                vaults[i],
                false,
                "deposit(address,uint256)",
                new address[](1),
                string.concat("Deposit ", assets[i].symbol(), " into Symbiotic Vault ", vm.toString(vaults[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            // Withdraw
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                vaults[i],
                false,
                "withdraw(address,uint256)",
                new address[](1),
                string.concat("Withdraw ", assets[i].symbol(), " from Symbiotic Vault ", vm.toString(vaults[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Claim
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                vaults[i],
                false,
                "claim(address,uint256)",
                new address[](1),
                string.concat("Claim withdraw from Symbiotic Vault ", vm.toString(vaults[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // ClaimBatch
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                vaults[i],
                false,
                "claimBatch(address,uint256[])",
                new address[](1),
                string.concat("Claim batch withdraw from Symbiotic Vault ", vm.toString(vaults[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Only add rewards leaf if vaultRewards array is provided and has a valid address
            if (vaultRewards.length > i && vaultRewards[i] != address(0)) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    vaultRewards[i],
                    false,
                    "claimRewards(address,address,bytes)",
                    new address[](1),
                    string.concat("Claim rewards from Symbiotic Vault ", vm.toString(vaults[i])),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "acceptOwnership()",
            new address[](0),
            string.concat("Accept ownership of the ITB Contract: ", vm.toString(positionManager)),
            itbDecoderAndSanitizer
        );
        // Transfer all tokens to the ITB contract.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(underlying),
            false,
            "transfer(address,uint256)",
            new address[](1),
            string.concat("Transfer ", underlying.symbol(), " to ITB Contract: ", vm.toString(positionManager)),
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = positionManager;
        // Approval Karak Vault to spend all tokens.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "approveToken(address,address,uint256)",
            new address[](2),
            string.concat("Approve ", ERC20(_karakVault).name(), " to spend ", underlying.symbol()),
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = address(underlying);
        leafs[leafIndex].argumentAddresses[1] = _karakVault;
        // Withdraw all tokens
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "withdraw(address,uint256)",
            new address[](1),
            string.concat("Withdraw ", underlying.symbol(), " from ITB Contract: ", vm.toString(positionManager)),
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = address(underlying);

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "withdrawAll(address)",
            new address[](1),
            string.concat(
                "Withdraw all ", underlying.symbol(), " from the ITB Contract: ", vm.toString(positionManager)
            ),
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = address(underlying);
        // Update Vault Supervisor.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "updateVaultSupervisor(address)",
            new address[](1),
            "Update the vault supervisor",
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = _vaultSupervisor;
        // Update position config.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "updatePositionConfig(address,address)",
            new address[](2),
            "Update the position config",
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = address(underlying);
        leafs[leafIndex].argumentAddresses[1] = _karakVault;
        // Deposit
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager, false, "deposit(uint256,uint256)", new address[](0), "Deposit", itbDecoderAndSanitizer
        );
        // Start Withdrawal
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "startWithdrawal(uint256)",
            new address[](0),
            "Start Withdrawal",
            itbDecoderAndSanitizer
        );
        // Complete Withdrawal
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "completeWithdrawal(uint256,uint256)",
            new address[](0),
            "Complete Withdrawal",
            itbDecoderAndSanitizer
        );
        // Complete Next Withdrawal
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "completeNextWithdrawal(uint256)",
            new address[](0),
            "Complete Next Withdrawal",
            itbDecoderAndSanitizer
        );
        // Complete Next Withdrawals
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "completeNextWithdrawals(uint256)",
            new address[](0),
            "Complete Next Withdrawals",
            itbDecoderAndSanitizer
        );
        // Override Withdrawal Indexes
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "overrideWithdrawalIndexes(uint256,uint256)",
            new address[](0),
            "Override Withdrawal Indexes",
            itbDecoderAndSanitizer
        );
        // Assemble
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager, false, "assemble(uint256)", new address[](0), "Assemble", itbDecoderAndSanitizer
        );
        // Disassemble
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "disassemble(uint256,uint256)",
            new address[](0),
            "Disassemble",
            itbDecoderAndSanitizer
        );
        // Full Disassemble
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "fullDisassemble(uint256)",
            new address[](0),
            "Full Disassemble",
            itbDecoderAndSanitizer
        );
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
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(feeAssets[i])][getAddress(
                    sourceChain, "accountantAddress"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(feeAssets[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Accountant to spend ", feeAssets[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = accountant;
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(feeAssets[i])][accountant]
                = true;
            }
        }
        // Claiming fees.
        for (uint256 i; i < feeAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                accountant,
                false,
                "claimFees(address)",
                new address[](1),
                string.concat("Claim fees in ", feeAssets[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(feeAssets[i]);

            if (addYieldClaiming) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    accountant,
                    false,
                    "claimYield(address)",
                    new address[](1),
                    string.concat("Claim yield in ", feeAssets[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(feeAssets[i]);
            }
        }
    }

    // ========================================= Transfer =========================================

    function _addTransferLeafs(ManageLeaf[] memory leafs, ERC20 token, address to) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(token),
            false,
            "transfer(address,uint256)",
            new address[](1),
            string.concat("Transfer ", token.symbol(), " to ", vm.toString(to)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = to;
    }

    function _addApprovalLeafs(ManageLeaf[] memory leafs, ERC20 token, address spender) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(token),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve ", vm.toString(spender), " to spend ", token.name()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = spender;
    }

    // ========================================= Rings Voter =========================================

    function _addRingsVoterLeafs(ManageLeaf[] memory leafs, address ringsVoterContract, ERC20 underlying) internal {
        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            address(underlying),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve ", vm.toString(ringsVoterContract), " to spend ", underlying.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = ringsVoterContract;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            ringsVoterContract,
            false,
            "depositBudget(uint256)",
            new address[](0),
            string.concat("Deposit Budget of ", underlying.symbol(), " into ", vm.toString(ringsVoterContract)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= LayerZero =========================================

    function _addLayerZeroLeafsOldDecoder(ManageLeaf[] memory leafs, ERC20 asset, address oftAdapter, uint32 endpoint)
        internal
    {
        if (address(asset) != oftAdapter) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(asset),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve LayerZero to spend ", asset.symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = oftAdapter;
        }
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            oftAdapter,
            true,
            "send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)",
            new address[](3),
            string.concat("Bridge ", asset.symbol(), " to LayerZero endpoint: ", vm.toString(endpoint)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
            leafs[leafIndex] = ManageLeaf(
                address(asset),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve LayerZero to spend ", asset.symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = oftAdapter;
        }
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            oftAdapter,
            true,
            "send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)",
            new address[](4),
            string.concat("Bridge ", asset.symbol(), " to LayerZero endpoint: ", vm.toString(endpoint)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(uint160(endpoint));
        leafs[leafIndex].argumentAddresses[1] = address(bytes20(bytes16(to)));
        leafs[leafIndex].argumentAddresses[2] = address(bytes20(bytes16(to << 128)));
        leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
    }

    function _addLayerZeroLeafNative(ManageLeaf[] memory leafs, address oftAdapter, uint32 endpoint, bytes32 to)
        internal
    {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            oftAdapter,
            true,
            "send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)",
            new address[](4),
            string.concat("Bridge Native Asset to LayerZero endpoint: ", vm.toString(endpoint)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(uint160(endpoint));
        leafs[leafIndex].argumentAddresses[1] = address(bytes20(bytes16(to)));
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
            leafs[leafIndex] = ManageLeaf(
                unitroller,
                false,
                "enterMarkets(address[])",
                new address[](1),
                string.concat("Enter Compound V2 market ", ERC20(cTokens[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = cTokens[i];

            if (address(collateralAssets[i]) != 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(collateralAssets[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Compound to spend ", collateralAssets[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = cTokens[i];

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    cTokens[i],
                    false,
                    "mint(uint256)",
                    new address[](0),
                    string.concat("Mint ", ERC20(cTokens[i]).symbol(), " on Compound"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    cTokens[i],
                    false,
                    "repayBorrow(uint256)",
                    new address[](0),
                    string.concat("Repay ", collateralAssets[i].symbol(), " on Compound"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
            } else {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    cTokens[i],
                    true,
                    "mint()",
                    new address[](0),
                    string.concat("Mint ", ERC20(cTokens[i]).symbol(), " using Native Asset on Compound"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    cTokens[i],
                    true,
                    "repayBorrow()",
                    new address[](0),
                    string.concat("Repay Native Asset on Compound"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
            }

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                cTokens[i],
                false,
                "borrow(uint256)",
                new address[](0),
                string.concat("Borrow from Compound, ", ERC20(cTokens[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                cTokens[i],
                false,
                "redeem(uint256)",
                new address[](0),
                string.concat("Redeem ", ERC20(cTokens[i]).symbol(), " on Compound"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                cTokens[i],
                false,
                "redeemUnderlying(uint256)",
                new address[](0),
                string.concat("Redeem underlying from Compound ", ERC20(cTokens[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                unitroller,
                false,
                "claimReward(uint8,address)",
                new address[](1),
                string.concat("Claim rewards from Compound fork"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                unitroller,
                false,
                "exitMarket(address)",
                new address[](1),
                string.concat("Exit Market", ERC20(cTokens[i]).symbol(), " on Compound"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
        leafs[leafIndex] = ManageLeaf(
            address(baseToken),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Comet to spend ", baseToken.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = cometAddress;

        // Supply base token
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            cometAddress,
            false,
            "supply(address,uint256)",
            new address[](1),
            string.concat("Supply ", baseToken.symbol(), " to Comet"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(baseToken);

        // Withdraw base token
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            cometAddress,
            false,
            "withdraw(address,uint256)",
            new address[](1),
            string.concat("Withdraw ", baseToken.symbol(), " from Comet"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(baseToken);

        // Handle collateral assets
        for (uint256 i; i < collateralAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(collateralAssets[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Comet to spend ", collateralAssets[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = cometAddress;

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                cometAddress,
                false,
                "supply(address,uint256)",
                new address[](1),
                string.concat("Supply ", collateralAssets[i].symbol(), " to Comet"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(collateralAssets[i]);

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                cometAddress,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                string.concat("Withdraw ", collateralAssets[i].symbol(), " from Comet"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(collateralAssets[i]);
        }

        // Claim rewards.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            cometRewards,
            false,
            "claim(address,address,bool)",
            new address[](2),
            "Claim rewards from Comet",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = cometAddress;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Merkl =========================================

    function _addMerklLeafs(
        ManageLeaf[] memory leafs,
        address merklDistributor,
        address operator
    ) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            merklDistributor,
            false,
            "toggleOperator(address,address)",
            new address[](2),
            string.concat("Allow ", vm.toString(operator), " to claim merkl rewards"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = operator;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            merklDistributor,
            false,
            "claim(address[],address[],uint256[],bytes32[][])",
            new address[](1),
            string.concat("Claim merkl rewards"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // only ability to claim, not other merkl functions
    function _addMerklClaimLeaf(
        ManageLeaf[] memory leafs,
        address merklDistributor
    ) internal {
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            merklDistributor,
            false,
            "claim(address[],address[],uint256[],bytes32[][])",
            new address[](1),
            string.concat("Claim merkl rewards"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][nonfungiblePositionManager]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Velodrome NonFungible Position Manager to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = nonfungiblePositionManager;
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][nonfungiblePositionManager]
                = true;
            }
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][nonfungiblePositionManager]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Velodrome NonFungible Position Manager to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = nonfungiblePositionManager;
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][nonfungiblePositionManager]
                = true;
            }

            // Minting
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                nonfungiblePositionManager,
                false,
                "mint((address,address,int24,int24,int24,uint256,uint256,uint256,uint256,address,uint256,uint160))",
                new address[](3),
                string.concat(
                    "Mint VelodromeV3 ", ERC20(token0[i]).symbol(), " ", ERC20(token1[i]).symbol(), " position"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            // Increase liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                nonfungiblePositionManager,
                false,
                "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
                new address[](4),
                string.concat(
                    "Add liquidity to VelodromeV3 ",
                    ERC20(token0[i]).symbol(),
                    " ",
                    ERC20(token1[i]).symbol(),
                    " position"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(0);
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = token1[i];
            leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");

            // Approve gauge to spend NFT.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                nonfungiblePositionManager,
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve gauge to spend VelodromeV3 position",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = gauges[i];
        }

        // Decrease liquidity
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            nonfungiblePositionManager,
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](1),
            "Remove liquidity from VelodromeV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            nonfungiblePositionManager,
            false,
            "collect((uint256,address,uint128,uint128))",
            new address[](2),
            "Collect fees from VelodromeV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        // burn
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            nonfungiblePositionManager,
            false,
            "burn(uint256)",
            new address[](0),
            "Burn VelodromeV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        for (uint256 i; i < gauges.length; ++i) {
            // Deposit into Gauge
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauges[i],
                false,
                "deposit(uint256)",
                new address[](0),
                string.concat("Deposit into VelodromeV3 gauge ", vm.toString(gauges[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            // Withdraw from Gauge
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauges[i],
                false,
                "withdraw(uint256)",
                new address[](0),
                string.concat("Withdraw from VelodromeV3 gauge ", vm.toString(gauges[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            // Get reward
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauges[i],
                false,
                "getReward(uint256)",
                new address[](0),
                string.concat("Get reward from VelodromeV3 gauge ", vm.toString(gauges[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauges[i],
                false,
                "getReward(address)",
                new address[](1),
                string.concat("Get reward from VelodromeV3 gauge ", vm.toString(gauges[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Velodrome Router to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = router;
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0[i]][router] = true;
            }
            if (!ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][router]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Velodrome Router to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = router;
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1[i]][router] = true;
            }

            // Add liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                router,
                false,
                "addLiquidity(address,address,bool,uint256,uint256,uint256,uint256,address,uint256)",
                new address[](3),
                string.concat(
                    "Add liquidity to VelodromeV2 ", ERC20(token0[i]).symbol(), "/", ERC20(token1[i]).symbol()
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // Remove liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                router,
                false,
                "removeLiquidity(address,address,bool,uint256,uint256,uint256,address,uint256)",
                new address[](3),
                string.concat(
                    "Remove liquidity from VelodromeV2 ", ERC20(token0[i]).symbol(), "/", ERC20(token1[i]).symbol()
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
            leafs[leafIndex] = ManageLeaf(
                stakingToken,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve VelodromeV2 Gauge to spend ", ERC20(stakingToken).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = gauges[i];

            // Approve router to spend staking token.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                stakingToken,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Velodrome Router to spend ", ERC20(stakingToken).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = router;

            // Deposit into Gauge
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauges[i],
                false,
                "deposit(uint256)",
                new address[](0),
                string.concat("Deposit into VelodromeV2 gauge ", vm.toString(gauges[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            // Withdraw from Gauge
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauges[i],
                false,
                "withdraw(uint256)",
                new address[](0),
                string.concat("Withdraw from VelodromeV2 gauge ", vm.toString(gauges[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            // Get reward
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauges[i],
                false,
                "getReward(address)",
                new address[](1),
                string.concat("Get reward from VelodromeV2 gauge ", vm.toString(gauges[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
        leafs[leafIndex] = ManageLeaf(
            address(underlying),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Karak Vault to spend ", underlying.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = vault;

        // Approve vault supervisor to spend vault shares
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Vault Supervisor to spend ", ERC4626(vault).symbol(), " shares"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = vaultSupervisor;

        // Add deposit leafs
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vaultSupervisor,
            false,
            "deposit(address,uint256,uint256)",
            new address[](1),
            string.concat("Deposit ", underlying.symbol(), " into ", ERC4626(vault).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = vault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vaultSupervisor,
            false,
            "gimmieShares(address,uint256)",
            new address[](1),
            string.concat("Gimmie shares into ", ERC4626(vault).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = vault;

        // Add withdraw leafs
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vaultSupervisor,
            false,
            "returnShares(address,uint256)",
            new address[](1),
            string.concat("Return shares from ", ERC4626(vault).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = vault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            delegationSupervisor,
            false,
            "startWithdraw((address[],uint256[],address)[])",
            new address[](2),
            string.concat("Start withdraw of ", underlying.symbol(), " from ", ERC4626(vault).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = vault;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            delegationSupervisor,
            false,
            "finishWithdraw((address,address,uint256,uint256,(address[],uint256[],address))[])",
            new address[](4),
            string.concat("Finish withdraw of ", underlying.symbol(), " from ", ERC4626(vault).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        leafs[leafIndex] = ManageLeaf(
            target,
            false,
            "removeExecutor(address)",
            new address[](0),
            string.concat("Remove any executor from ", vm.toString(target)),
            reclamationDecoder
        );
        // Add in generic `withdraw(address asset, uint256 amount)` and generic `withdrawAll(address asset)` leafs.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            target,
            false,
            "withdraw(address,uint256)",
            new address[](0),
            string.concat("Withdraw any asset from ", vm.toString(target)),
            reclamationDecoder
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            target,
            false,
            "withdrawAll(address)",
            new address[](0),
            string.concat("Withdraw all of any asset from ", vm.toString(target)),
            reclamationDecoder
        );
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
            leafs[leafIndex] = ManageLeaf(
                address(assets[i]),
                false,
                "transfer(address,uint256)",
                new address[](1),
                string.concat("Transfer ", assets[i].symbol(), " to drone: ", vm.toString(drone)),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = drone;

            // Add leaf for drone to transfer to BoringVault.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                drone,
                false,
                "transfer(address,uint256)",
                new address[](2),
                string.concat("Transfer ", assets[i].symbol(), " to BoringVault"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = address(assets[i]);
        }

        // Add leaf so boringVault can withdraw native from drone.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            drone,
            false,
            "withdrawNativeFromDrone()",
            new address[](0),
            string.concat("Withdraw native from drone: ", vm.toString(drone)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
            leafs[leafIndex] = ManageLeaf(
                address(purchaseTokens[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Term Repo Locker to spend ", purchaseTokens[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = termRepoLockers[i];
            ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][address(purchaseTokens[i])][termRepoLockers[i]]
            = true;
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                termAuctionOfferLockerAddresses[i],
                false,
                "lockOffers((bytes32,address,bytes32,uint256,address)[])",
                new address[](2),
                string.concat(
                    "Submit offer submission to offer locker ", vm.toString(termAuctionOfferLockerAddresses[i])
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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

            leafs[leafIndex] = ManageLeaf(
                termAuctionOfferLockerAddresses[i],
                false,
                "unlockOffers(bytes32[])",
                new address[](0),
                string.concat(
                    "Unlock existing offer from offer locker ", vm.toString(termAuctionOfferLockerAddresses[i])
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
            leafs[leafIndex] = ManageLeaf(
                termAuctionOfferLockerAddresses[i],
                false,
                "revealOffers(bytes32[],uint256[],uint256[])",
                new address[](0),
                string.concat(
                    "Unlock existing offer from offer locker ", vm.toString(termAuctionOfferLockerAddresses[i])
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
            leafs[leafIndex] = ManageLeaf(
                termRepoServicers[i],
                false,
                "redeemTermRepoTokens(address,uint256)",
                new address[](1),
                string.concat("Redeem TermRepo Tokens from servicer ", vm.toString(termRepoServicers[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "ethereumVaultConnector"),
                    false,
                    "enableCollateral(address,address)",
                    new address[](2),
                    string.concat(
                        "Enable Collateral of ",
                        ERC20(depositVaults[j].asset()).name(),
                        " on Euler for account #",
                        vm.toString(i),
                        " ",
                        vm.toString(subaccounts[i])
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = subaccounts[i];
                leafs[leafIndex].argumentAddresses[1] = address(depositVaults[j]);

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "ethereumVaultConnector"),
                    false,
                    "disableCollateral(address,address)",
                    new address[](2),
                    string.concat(
                        "Disable Collateral of ",
                        ERC20(depositVaults[j].asset()).name(),
                        " on Euler for account #",
                        vm.toString(i),
                        " : ",
                        vm.toString(subaccounts[i])
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = subaccounts[i];
                leafs[leafIndex].argumentAddresses[1] = address(depositVaults[j]);

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "ethereumVaultConnector"),
                    false,
                    "call(address,address,uint256,bytes)",
                    new address[](5),
                    string.concat(
                        "Call Withdraw on ",
                        depositVaults[j].name(),
                        " via EVC on behalf of ",
                        vm.toString(subaccounts[i])
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(depositVaults[j]);
                leafs[leafIndex].argumentAddresses[1] = subaccounts[i];
                leafs[leafIndex].argumentAddresses[2] = address(0xb460af94); //withdraw
                leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault"); //receiver must be vault
                leafs[leafIndex].argumentAddresses[4] = subaccounts[i]; //owner must be subaccount

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "ethereumVaultConnector"),
                    false,
                    "call(address,address,uint256,bytes)",
                    new address[](5),
                    string.concat(
                        "Call Redeem on ",
                        depositVaults[j].name(),
                        " via EVC on behalf of ",
                        vm.toString(subaccounts[i])
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
                leafs[leafIndex] = ManageLeaf(
                    address(borrowVaults[j].asset()),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve ", ERC20(borrowVaults[j].asset()).name(), " to be repaid."),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(borrowVaults[j]);

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "ethereumVaultConnector"),
                    false,
                    "enableController(address,address)",
                    new address[](2),
                    string.concat(
                        "Enable ",
                        borrowVaults[j].name(),
                        " as controller for subaccount #",
                        vm.toString(i),
                        " : ",
                        vm.toString(subaccounts[i])
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = subaccounts[i];
                leafs[leafIndex].argumentAddresses[1] = address(borrowVaults[j]);

                unchecked {
                    leafIndex++;
                }

                leafs[leafIndex] = ManageLeaf(
                    address(borrowVaults[j]),
                    false,
                    "borrow(uint256,address)",
                    new address[](1),
                    string.concat(
                        "Borrow ",
                        ERC20(borrowVaults[j].asset()).name(),
                        " from ",
                        borrowVaults[j].name(),
                        " for account #",
                        vm.toString(i)
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = subaccounts[i];

                unchecked {
                    leafIndex++;
                }

                leafs[leafIndex] = ManageLeaf(
                    address(borrowVaults[j]),
                    false,
                    "repay(uint256,address)",
                    new address[](1),
                    string.concat(
                        "Repay ",
                        ERC20(borrowVaults[j].asset()).name(),
                        " to ",
                        borrowVaults[j].name(),
                        " for account #",
                        vm.toString(i)
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = subaccounts[i];

                unchecked {
                    leafIndex++;
                }

                leafs[leafIndex] = ManageLeaf(
                    address(borrowVaults[j]),
                    false,
                    "repayWithShares(uint256,address)",
                    new address[](1),
                    string.concat(
                        "Repay ",
                        ERC20(borrowVaults[j].asset()).name(),
                        " with shares ",
                        borrowVaults[j].name(),
                        " for account #",
                        vm.toString(i)
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = subaccounts[i];

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(borrowVaults[j]),
                    false,
                    "disableController()",
                    new address[](0),
                    string.concat("Disable ", borrowVaults[j].name(), " as controller for account #", vm.toString(i)),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                //leafs[leafIndex].argumentAddresses[0] = subaccounts[i];

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "ethereumVaultConnector"),
                    false,
                    "call(address,address,uint256,bytes)",
                    new address[](4),
                    string.concat(
                        "Call Borrow on ", borrowVaults[j].name(), " via EVC on behalf of ", vm.toString(subaccounts[i])
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
        leafs[leafIndex] = ManageLeaf(
            address(asset),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Recipe Market Hub to spend ", asset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "recipeMarketHub");

        unchecked {
            leafIndex++;
        }

        address marketHash0 = address(bytes20(bytes16(marketHash)));
        address marketHash1 = address(bytes20(bytes16(marketHash << 128)));

        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "recipeMarketHub"),
            false,
            "fillIPOffers(bytes32[],uint256[],address,address)",
            new address[](4),
            string.concat("Fill IP Offer using market hash"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = marketHash0;
        leafs[leafIndex].argumentAddresses[1] = marketHash1;
        leafs[leafIndex].argumentAddresses[2] = address(0); //pull funds from boringVault
        leafs[leafIndex].argumentAddresses[3] = frontendFeeRecipient;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "recipeMarketHub"),
            false,
            "executeWithdrawalScript(address)",
            new address[](1),
            string.concat("Execute the weiroll withdraw script and retrieve funds from recipe market"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "recipeMarketHub"),
            false,
            "forfeit(address,bool)",
            new address[](1),
            string.concat("Forfeit rewards and unlock wallet early"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "recipeMarketHub"),
            false,
            "claim(address,address)",
            new address[](2),
            string.concat("Claim incentive rewards"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        //TODO add merkleWithdraw leaves once testing is available
    }

    function _addRoyco4626VaultLeafs(ManageLeaf[] memory leafs, ERC4626 vault) internal {
        _addERC4626Leafs(leafs, vault);

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "claim(address)",
            new address[](1),
            string.concat("Claim incentive rewards"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "claimFees(address)",
            new address[](1),
            string.concat("Claim vault fees"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
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
        leafs[leafIndex] = ManageLeaf(
            baseAsset,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat(
                "Approve RecipeMarketHub to spend ", ERC20(baseAsset).symbol(), " (spent when offer is filled)"
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "recipeMarketHub");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "recipeMarketHub"),
            false,
            "createAPOffer(bytes32,address,uint256,uint256,address[],uint256[])",
            new address[](3 + incentivesRequested.length),
            string.concat("Create AP Offer for Recipe Market"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(bytes20(bytes16(targetMarketHash)));
        leafs[leafIndex].argumentAddresses[1] = address(bytes20(bytes16(targetMarketHash << 128)));
        leafs[leafIndex].argumentAddresses[2] = fundingVault;
        for (uint256 i = 0; i < incentivesRequested.length; i++) {
            leafs[leafIndex].argumentAddresses[3 + i] = incentivesRequested[i];
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "recipeMarketHub"),
            false,
            "cancelAPOffer((uint256,bytes32,address,address,uint256,uint256,address[],uint256[]))",
            new address[](4 + incentivesRequested.length),
            string.concat("Cancel AP Offer for Recipe Market"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(bytes20(bytes16(targetMarketHash)));
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
        leafs[leafIndex] = ManageLeaf(
            baseAsset,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Wrapped Vault to spend ", ERC20(baseAsset).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = targetVault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            targetVault,
            false,
            "safeDeposit(uint256,address,uint256)",
            new address[](1),
            string.concat("Deposit into WrappedVault using safeDeposit"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            baseAsset,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat(
                "Approve VaultMarketHub to spend ", ERC20(baseAsset).symbol(), " (spent when offer is filled)"
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "vaultMarketHub");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "vaultMarketHub"),
            false,
            "createAPOffer(address,address,uint256,uint256,address[],uint256[])",
            new address[](2 + incentivesRequested.length),
            string.concat("Create AP Offer for Vault Market"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = targetVault;
        leafs[leafIndex].argumentAddresses[1] = fundingVault;
        for (uint256 i = 0; i < incentivesRequested.length; i++) {
            leafs[leafIndex].argumentAddresses[2 + i] = incentivesRequested[i];
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "vaultMarketHub"),
            false,
            "cancelOffer((uint256,address,address,address,uint256,address[],uint256[]))",
            new address[](3 + incentivesRequested.length),
            string.concat("Create AP Offer for Vault Market"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "roycoDepositExecutor"),
                false,
                "withdrawMerkleDeposit(address,uint256,uint256,bytes32[])",
                new address[](1),
                string.concat("Withdraw Weiroll deposit from ", vm.toString(weirollWallets[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = weirollWallets[i];
        }
    }

    // ========================================= Resolv =========================================

    function _addAllResolvLeafs(ManageLeaf[] memory leafs) internal {
        _addResolvUsrExternalRequestsManagerLeafs(leafs);
        _addResolvStUSRLeafs(leafs);
        _addResolvWstUSRLeafs(leafs);
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "wstUSR")));
    }

    function _addResolvUsrExternalRequestsManagerLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "USDC"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve USDC to be spent by USR External Requests Manager"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "UsrExternalRequestsManager");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "USDT"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve USDT to be spent by USR External Requests Manager"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "UsrExternalRequestsManager");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "USR"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve USR to be spent by USR External Requests Manager"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "UsrExternalRequestsManager");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "UsrExternalRequestsManager"),
            false,
            "requestMint(address,uint256,uint256)",
            new address[](1),
            string.concat("Convert USDC to USR"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDC");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "UsrExternalRequestsManager"),
            false,
            "requestBurn(uint256,address,uint256)",
            new address[](1),
            string.concat("Convert USR to USDC"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDC");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "UsrExternalRequestsManager"),
            false,
            "requestMint(address,uint256,uint256)",
            new address[](1),
            string.concat("Convert USDT to USR"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDT");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "UsrExternalRequestsManager"),
            false,
            "requestBurn(uint256,address,uint256)",
            new address[](1),
            string.concat("Convert USR to USDT"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDT");
    }

    function _addResolvStUSRLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "USR"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve USR to be converted to stUSR"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "stUSR");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "stUSR"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve stUSR to be converted to USR"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "stUSR");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "stUSR"),
            false,
            "deposit(uint256)",
            new address[](0),
            string.concat("Convert USR to stUSR"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "stUSR"),
            false,
            "withdraw(uint256)",
            new address[](0),
            string.concat("Convert stUSR to USR"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    function _addResolvWstUSRLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "stUSR"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve stUSR to be converted to wstUSR"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "wstUSR");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "wstUSR"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve wstUSR to be converted to stUSR"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "wstUSR");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "wstUSR"),
            false,
            "wrap(uint256)",
            new address[](0),
            string.concat("Convert stUSR to wstUSR"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "wstUSR"),
            false,
            "unwrap(uint256)",
            new address[](0),
            string.concat("Convert wstUSR to stUSR"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Lombard BTC  =========================================

    // @notice to avoid having an extra unneeded approval leaf for base vs bnb merkle trees
    function _addLombardBTCLeafs(ManageLeaf[] memory leafs, ERC20 BTCB_or_CBBtc, ERC20 LBTC) internal {
        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            address(BTCB_or_CBBtc), //target
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve BTCB to be staked into LBTC"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "LBTC");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(LBTC), //target
            false,
            "mint(address,uint256)",
            new address[](1),
            string.concat("Mint LBTC if permissioned"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(LBTC), //target
            false,
            "mint(bytes,bytes)",
            new address[](1),
            string.concat("Mint LBTC"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        //set the swap leaf based on if we are on bnc or base
        if (getAddress("base", "cbBTC") == address(BTCB_or_CBBtc)) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(BTCB_or_CBBtc), //target
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve cbBTC to be swapped for LBTC"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "cbBTCPMM");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "cbBTCPMM"), //target
                false,
                "swapCBBTCToLBTC(uint256)",
                new address[](0),
                string.concat("Swap cbBTC to LBTC"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
        } else {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(BTCB_or_CBBtc), //target
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve BTCB to be swapped for LBTC via swap contract"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "BTCBPMM");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "BTCBPMM"), //target
                false,
                "swapBTCBToLBTC(uint256)",
                new address[](0),
                string.concat("Swap BTCB to LBTC"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
        }
    }

    // ========================================= BTCK =========================================
    function _addBTCKLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "LBTC"), //target
            false,
            "deposit(uint256)",
            new address[](0),
            string.concat("Deposit BTCK for LBTC payload"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "LBTC"), //target
            false,
            "mint(bytes,bytes)",
            new address[](0),
            string.concat("Mint LBTC with payload"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "LBTC"), //target
            false,
            "redeem(uint256)",
            new address[](0),
            string.concat("Redeem LBTC for BTCK payload"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "BTCK"), //target
            false,
            "mintV1(bytes,bytes)",
            new address[](0),
            string.concat("Mint BTCK with payload"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ============================================= BTCN Corn ==================================================

    function _addBTCNLeafs(ManageLeaf[] memory leafs, ERC20 collateralToken, ERC20 BTCN, address cornSwapFacility)
        internal
    {
        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            address(collateralToken), //target
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat(
                "Approve ", collateralToken.symbol(), " to be swapped for BTCN by the Corn SwapFacility Contract"
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = cornSwapFacility;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            address(BTCN), //target
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat(
                "Approve BTCN to be swapped for ", collateralToken.symbol(), " by the Corn SwapFacility Contract"
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = cornSwapFacility;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            cornSwapFacility, //target
            false,
            "swapExactCollateralForDebt(uint256,uint256,address,uint256)",
            new address[](1),
            string.concat("Swap ", collateralToken.symbol(), " for BTCN"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            cornSwapFacility, //target
            false,
            "swapExactDebtForCollateral(uint256,uint256,address,uint256)",
            new address[](1),
            string.concat("Swap BTCN for ", collateralToken.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
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
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "DAI"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve DAI to be spent by SKY Dai Converter"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "daiConverter");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "USDS"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve USDS to be spent by SKY Dai Converter"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "daiConverter");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "daiConverter"),
            false,
            "daiToUsds(address,uint256)",
            new address[](1),
            string.concat("Convert DAI to USDS"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "daiConverter"),
            false,
            "usdsToDai(address,uint256)",
            new address[](1),
            string.concat("Convert DAI to USDS"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    function _addSkyUSDSLitePSMUSDCLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "USDS"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve USDS to be swapped for USDC"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "usdsLitePsmUsdc");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "USDC"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve USDC to be swapped for USDS"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "usdsLitePsmUsdc");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "usdsLitePsmUsdc"),
            false,
            "sellGem(address,uint256)",
            new address[](1),
            string.concat("Swap USDC for USDS"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "usdsLitePsmUsdc"),
            false,
            "buyGem(address,uint256)",
            new address[](1),
            string.concat("Swap USDS for USDC"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    function _addSkyDAILitePSMUSDCLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "DAI"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve DAI to be swapped for USDC"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "daiLitePsmUsdc");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "USDC"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve USDC to be swapped for DAI"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "daiLitePsmUsdc");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "daiLitePsmUsdc"),
            false,
            "sellGem(address,uint256)",
            new address[](1),
            string.concat("Swap USDC for DAI"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "daiLitePsmUsdc"),
            false,
            "buyGem(address,uint256)",
            new address[](1),
            string.concat("Swap DAI for USDC"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Syrup =========================================
    function _addAllSyrupLeafs(ManageLeaf[] memory leafs) internal {
        _addSyrupRouterLeafs(leafs);
        _addSyrupPoolLeafs(leafs);
    }

    function _addSyrupRouterLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "USDC"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve USDC to be spent by USDC syrupRouter"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "syrupRouterUSDC");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "USDT"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve USDT to be spent by USDT syrupRouter"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "syrupRouterUSDT");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "syrupRouterUSDC"),
            false,
            "deposit(uint256,bytes32)",
            new address[](0),
            string.concat("Deposit USDC to syrupUSDC"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "syrupRouterUSDT"),
            false,
            "deposit(uint256,bytes32)",
            new address[](0),
            string.concat("Deposit USDT to syrupUSDT"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    function _addSyrupPoolLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "syrupUSDC"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve syrupUSDC to be redeemed for USDC"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "syrupUSDC");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "syrupUSDT"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve syrupUSDT to be redeemed for USDT"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "syrupUSDT");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "syrupUSDC"),
            false,
            "requestRedeem(uint256,address)",
            new address[](1),
            string.concat("Request redeem syrupUSDC for USDC"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "syrupUSDT"),
            false,
            "requestRedeem(uint256,address)",
            new address[](1),
            string.concat("Request redeem syrupUSDT for USDT"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "syrupUSDC"),
            false,
            "removeShares(uint256,address)",
            new address[](1),
            string.concat("Cancel syrupUSDC for USDC redemption request"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "syrupUSDT"),
            false,
            "removeShares(uint256,address)",
            new address[](1),
            string.concat("Cancel syrupUSDC for USDC redemption request"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
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
            leafs[leafIndex] = ManageLeaf(
                depositToken,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve ", vm.toString(vaults[i]), " to spend ", ERC20(depositToken).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = vaults[i];

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                OT,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve ", vm.toString(vaults[i]), " to spend ", ERC20(OT).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = vaults[i];

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                YT,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve ", vm.toString(vaults[i]), " to spend ", ERC20(YT).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = vaults[i];

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                vaults[i],
                false,
                "deposit(uint256)",
                new address[](0),
                string.concat("Deposit ", ERC20(depositToken).symbol(), " into GoldiVault ", vm.toString(vaults[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                vaults[i],
                false,
                "redeemOwnership(uint256)",
                new address[](0),
                string.concat("Redeem OT in ", ERC20(depositToken).symbol(), " GoldiVault"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                vaults[i],
                false,
                "redeemYield(uint256)",
                new address[](0),
                string.concat("Redeem YT in ", ERC20(depositToken).symbol(), " GoldiVault"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                vaults[i],
                false,
                "compound()",
                new address[](0),
                string.concat("Compound rewards in ", ERC20(depositToken).symbol(), " GoldiVault"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                vaults[i],
                false,
                "buyYT(uint256,uint256,uint256)",
                new address[](0),
                string.concat("Buy YT ", ERC20(depositToken).symbol(), " via GoldiVault"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                vaults[i],
                false,
                "sellYT(uint256,uint256,uint256)",
                new address[](0),
                string.concat("Sell YT ", ERC20(depositToken).symbol(), " via GoldiVault"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
        }
    }

    // ========================================= Sonic Gateway =========================================
    // To be used on ETH mainnet.
    function _addSonicGatewayLeafsEth(ManageLeaf[] memory leafs, ERC20[] memory assets) internal {
        for (uint256 i = 0; i < assets.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(assets[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Sonic Gateway L1 to spend", assets[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "sonicGateway");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "sonicGateway"),
                false,
                "deposit(uint96,address,uint256)",
                new address[](1),
                string.concat("Deposit ", assets[i].symbol(), " into Sonic Gateway"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "sonicGateway"),
                false,
                "claim(uint256,address,uint256,bytes)",
                new address[](1),
                string.concat("Claim ", assets[i].symbol(), " from Sonic Gateway"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "sonicGateway"),
                false,
                "cancelDepositWhileDead(uint256,address,uint256,bytes)",
                new address[](1),
                string.concat("Cancel deposit of ", assets[i].symbol(), " from Sonic Gateway while dead"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "USDC"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Circle Token Adapter to burn USDC"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "circleTokenAdapter");

        for (uint256 i = 0; i < assetsMainnet.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(assetsSonic[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Sonic Gateway L2 to spend ", vm.toString(assetsSonic[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );

            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "sonicGateway");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "sonicGateway"),
                false,
                "withdraw(uint96,address,uint256)",
                new address[](1),
                string.concat("Withdraw ", vm.toString(assetsSonic[i]), " from Sonic"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(assetsMainnet[i]);

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "sonicGateway"),
                false,
                "claim(uint256,address,uint256,bytes)",
                new address[](1),
                string.concat("Claim ", vm.toString(assetsSonic[i]), " from Sonic Gateway"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
        ERC20 boringVault = TellerWithMultiAssetSupport(teller).vault();

        for (uint256 i; i < assets.length; ++i) {
            // Approve BoringVault to spend all assets.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(assets[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve ", boringVault.name(), ", to spend ", assets[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(boringVault);

            // BulkDeposit asset.
            if (addBulkWithdraw) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    teller,
                    false,
                    "bulkDeposit(address,uint256,uint256,address)",
                    new address[](2),
                    string.concat("Bulk deposit ", assets[i].symbol(), " into ", boringVault.name()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

                // BulkWithdraw asset.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    teller,
                    false,
                    "bulkWithdraw(address,uint256,uint256,address)",
                    new address[](2),
                    string.concat("Bulk withdraw ", assets[i].symbol(), " from ", boringVault.name()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            }

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                teller,
                false,
                "deposit(address,uint256,uint256)",
                new address[](1),
                string.concat("Deposit ", assets[i].symbol(), " into ", boringVault.name()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
        }

        if (addNativeDeposit) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                teller,
                true, //can send value
                "deposit(address,uint256,uint256)",
                new address[](1),
                string.concat("Deposit ETH into ", boringVault.name()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
        ERC20 boringVault = TellerWithMultiAssetSupport(teller).vault();

        for (uint256 i; i < assets.length; ++i) {
            // Approve BoringVault to spend all assets.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(assets[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve ", boringVault.name(), ", to spend ", assets[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(boringVault);

            // BulkDeposit asset.
            if (addBulkWithdraw) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    teller,
                    false,
                    "bulkDeposit(address,uint256,uint256,address)",
                    new address[](2),
                    string.concat("Bulk deposit ", assets[i].symbol(), " into ", boringVault.name()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

                // BulkWithdraw asset.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    teller,
                    false,
                    "bulkWithdraw(address,uint256,uint256,address)",
                    new address[](2),
                    string.concat("Bulk withdraw ", assets[i].symbol(), " from ", boringVault.name()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            }

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                teller,
                false,
                "deposit(address,uint256,uint256,address)",
                new address[](2),
                string.concat("Deposit ", assets[i].symbol(), " into ", boringVault.name()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
            leafs[leafIndex].argumentAddresses[1] = referrer;

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                teller,
                false,
                "withdraw(address,uint256,uint256,address)",
                new address[](2),
                string.concat("Withdraw ", assets[i].symbol(), " from ", boringVault.name()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }

        if (addNativeDeposit) {

            // Deposite ETH with referrer
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                teller,
                true,
                "deposit(address,uint256,uint256,address)",
                new address[](2),
                string.concat("Deposit ETH into ", boringVault.name()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
        leafs[leafIndex] = ManageLeaf(
            boringVault,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve CrossChain Teller to spend ", ERC20(boringVault).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = teller;

        for (uint256 i = 0; i < feeAssets.length; i++) {
            if (feeAssets[i] != getAddress(sourceChain, "ETH")) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    feeAssets[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve CrossChain Teller to spend ", ERC20(feeAssets[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = teller;
            }
        }

        for (uint256 i = 0; i < depositAssets.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                depositAssets[i],
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve CrossChain Teller to spend ", ERC20(depositAssets[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
                    leafs[leafIndex] = ManageLeaf(
                        teller,
                        true,
                        "depositAndBridge(address,uint256,uint256,address,bytes,address,uint256)",
                        new address[](4),
                        string.concat("Deposit and bridge ", ERC20(depositAssets[i]).symbol(), " with ETH as fee"),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = depositAssets[i];
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[2] = destChain0;
                    leafs[leafIndex].argumentAddresses[3] = feeAssets[j];
                } else {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        teller,
                        false,
                        "depositAndBridge(address,uint256,uint256,address,bytes,address,uint256)",
                        new address[](4),
                        string.concat(
                            "Deposit and bridge ",
                            ERC20(depositAssets[i]).symbol(),
                            " with ",
                            ERC20(feeAssets[j]).symbol(),
                            " as fee"
                        ),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
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
                leafs[leafIndex] = ManageLeaf(
                    teller,
                    true,
                    "bridge(uint96,address,bytes,address,uint256)",
                    new address[](3),
                    string.concat("Bridge ", ERC20(ITeller(teller).vault()).symbol(), " with ETH as fee"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
                leafs[leafIndex].argumentAddresses[1] = destChain0;
                leafs[leafIndex].argumentAddresses[2] = feeAssets[i];
            } else {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    teller,
                    false,
                    "bridge(uint96,address,bytes,address,uint256)",
                    new address[](4),
                    string.concat(
                        "Bridge ",
                        ERC20(ITeller(teller).vault()).symbol(),
                        " with ",
                        ERC20(feeAssets[i]).symbol(),
                        " as fee"
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
        leafs[leafIndex] = ManageLeaf(
            boringVault,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve CrossChain Teller to spend ", ERC20(boringVault).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = teller;

        for (uint256 i = 0; i < feeAssets.length; i++) {
            if (feeAssets[i] != getAddress(sourceChain, "ETH")) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    feeAssets[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve CrossChain Teller to spend ", ERC20(feeAssets[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = teller;
            }
        }

        for (uint256 i = 0; i < depositAssets.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                depositAssets[i],
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve CrossChain Teller to spend ", ERC20(depositAssets[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
                    leafs[leafIndex] = ManageLeaf(
                        teller,
                        true,
                        "depositAndBridge(address,uint256,uint256,address,bytes,address,uint256,address)",
                        new address[](5),
                        string.concat("Deposit and bridge ", ERC20(depositAssets[i]).symbol(), " with ETH as fee"),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = depositAssets[i];
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[2] = destChain0;
                    leafs[leafIndex].argumentAddresses[3] = feeAssets[j];
                    leafs[leafIndex].argumentAddresses[4] = referrer;
                } else {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        teller,
                        false,
                        "depositAndBridge(address,uint256,uint256,address,bytes,address,uint256,address)",
                        new address[](5),
                        string.concat(
                            "Deposit and bridge ",
                            ERC20(depositAssets[i]).symbol(),
                            " with ",
                            ERC20(feeAssets[j]).symbol(),
                            " as fee"
                        ),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
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
                leafs[leafIndex] = ManageLeaf(
                    teller,
                    true,
                    "bridge(uint96,address,bytes,address,uint256)",
                    new address[](3),
                    string.concat("Bridge ", ERC20(ITeller(teller).vault()).symbol(), " with ETH as fee"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
                leafs[leafIndex].argumentAddresses[1] = destChain0;
                leafs[leafIndex].argumentAddresses[2] = feeAssets[i];
            } else {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    teller,
                    false,
                    "bridge(uint96,address,bytes,address,uint256)",
                    new address[](4),
                    string.concat(
                        "Bridge ",
                        ERC20(ITeller(teller).vault()).symbol(),
                        " with ",
                        ERC20(feeAssets[i]).symbol(),
                        " as fee"
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "WETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve rberaETH to spend WETH"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "rberaETH");

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "rberaETH"),
            false,
            "depositAndWrap(address,uint256,uint256)",
            new address[](1),
            string.concat("Deposit and wrap WETH into beraETH"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "WETH");

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "beraETH"),
            false,
            "unwrap(uint256)",
            new address[](0),
            string.concat("Unwrap beraETH"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Infrared  =========================================
    function _addInfraredVaultLeafs(ManageLeaf[] memory leafs, address vault) internal {
        address stakingToken = IInfraredVault(vault).stakingToken();

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            stakingToken,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Infrared Vault to spend ", ERC20(stakingToken).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = vault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "stake(uint256)",
            new address[](0),
            string.concat("Stake ", ERC20(stakingToken).symbol(), " into Infrared Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "withdraw(uint256)",
            new address[](0),
            string.concat("Withdraw ", ERC20(stakingToken).symbol(), " from Infrared Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "getRewardForUser(address)",
            new address[](1),
            string.concat("Get Reward for user from ", ERC20(stakingToken).symbol(), " Infrared Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "getReward()",
            new address[](0),
            string.concat("Get Reward for ", ERC20(stakingToken).symbol(), " Infrared Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "exit()",
            new address[](0),
            string.concat("Exit from ", ERC20(stakingToken).symbol(), " Infrared Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
            leafs[leafIndex] = ManageLeaf(
                boringVault,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve BoringOnChainQueue to spend ", ERC20(boringVault).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = withdrawQueue;

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                withdrawQueue,
                false,
                "requestOnChainWithdraw(address,uint128,uint16,uint24)",
                new address[](1),
                string.concat("Request Withdraw of ", assets[i].symbol(), ", from queue"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                withdrawQueue,
                false,
                "cancelOnChainWithdraw((uint96,address,address,uint128,uint128,uint40,uint24,uint24))",
                new address[](2),
                string.concat("Cancel Withdraw of ", assets[i].symbol(), ", from queue"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = address(assets[i]);

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                withdrawQueue,
                false,
                "replaceOnChainWithdraw((uint96,address,address,uint128,uint128,uint40,uint24,uint24),uint16,uint24)",
                new address[](2),
                string.concat("Replace Withdraw of ", assets[i].symbol(), ", from queue"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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

            leafs[leafIndex] = ManageLeaf(
                address(assets[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Honey Factory to spend ", assets[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "honeyFactory");

            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "honeyFactory"),
                false,
                "mint(address,uint256,address)",
                new address[](2),
                string.concat("Mint Honey using ", assets[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "honeyFactory"),
                false,
                "redeem(address,uint256,address)",
                new address[](2),
                string.concat("Redeem Honey for ", assets[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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

            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0][getAddress(
                    sourceChain, "kodiakIslandRouter"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0,
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Kodiak router to spend ", ERC20(token0).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "kodiakIslandRouter");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token0][getAddress(
                    sourceChain, "kodiakIslandRouter"
                )] = true;
            }

            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1][getAddress(
                    sourceChain, "kodiakIslandRouter"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1,
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Kodiak router to spend ", ERC20(token1).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "kodiakIslandRouter");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1][getAddress(
                    sourceChain, "kodiakIslandRouter"
                )] = true;
            }

            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][islands[i]][getAddress(
                    sourceChain, "kodiakIslandRouter"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    islands[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Kodiak router to spend ", ERC20(islands[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "kodiakIslandRouter");
                ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][token1][getAddress(
                    sourceChain, "kodiakIslandRouter"
                )] = true;
            }

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "kodiakIslandRouter"),
                false,
                "addLiquidity(address,uint256,uint256,uint256,uint256,uint256,address)",
                new address[](2),
                string.concat("Add Liquidity in ", IKodiakIsland(islands[i]).name()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = islands[i];
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            if (includeNativeLeaves) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "kodiakIslandRouter"),
                    true,
                    "addLiquidityNative(address,uint256,uint256,uint256,uint256,uint256,address)",
                    new address[](2),
                    string.concat("Add Liquidity Native in ", IKodiakIsland(islands[i]).name()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = islands[i];
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            }

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "kodiakIslandRouter"),
                false,
                "removeLiquidity(address,uint256,uint256,uint256,address)",
                new address[](2),
                string.concat("Remove Liquidity from ", IKodiakIsland(islands[i]).name()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = islands[i];
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            if (includeNativeLeaves) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "kodiakIslandRouter"),
                    false,
                    "removeLiquidityNative(address,uint256,uint256,uint256,address)",
                    new address[](2),
                    string.concat("Remove Liquidity Native from ", IKodiakIsland(islands[i]).name()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
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
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "NECT"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Beraborrow CollVaultRouter to spend NECT"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "collVaultRouter");

        require(collateralVaultAssets.length == denManagers.length, "beraborrow: length mismatch");

        for (uint256 i = 0; i < collateralVaultAssets.length; i++) {
            address asset = address(ERC4626(collateralVaultAssets[i]).asset());

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                asset,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Beraborrow CollVaultRouter to spend ", ERC20(asset).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "collVaultRouter");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "collVaultRouter"),
                false,
                "openDenVault((address,address,uint256,uint256,uint256,address,address,uint256,uint256,bytes))",
                new address[](2),
                string.concat("Open Den Vault with ", ERC20(collateralVaultAssets[i]).symbol(), " as collateral"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = denManagers[i];
            leafs[leafIndex].argumentAddresses[1] = collateralVaultAssets[i];

            if (addNative) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "collVaultRouter"),
                    true,
                    "openDenVault((address,address,uint256,uint256,uint256,address,address,uint256,uint256,bytes))",
                    new address[](2),
                    string.concat("Open Den Vault with ", ERC20(collateralVaultAssets[i]).symbol(), " as collateral"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = denManagers[i];
                leafs[leafIndex].argumentAddresses[1] = collateralVaultAssets[i];
            }

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "collVaultRouter"),
                false,
                "adjustDenVault((address,address,uint256,uint256,uint256,uint256,bool,address,address,bool,uint256,uint256,uint256,bytes))",
                new address[](2),
                string.concat("Adjust Den Vault ", ERC20(collateralVaultAssets[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = denManagers[i];
            leafs[leafIndex].argumentAddresses[1] = collateralVaultAssets[i];

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "collVaultRouter"),
                false,
                "closeDenVault(address,address,uint256,uint256,bool)",
                new address[](2),
                string.concat("Close Den Vault ", ERC20(collateralVaultAssets[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
            leafs[leafIndex] = ManageLeaf(
                asset,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve ", ERC20(asset).symbol(), " for ", ERC20(managedVaults[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = managedVaults[i];

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                managedVaults[i],
                false,
                "deposit(uint256,address,(address,address,uint256,uint256))",
                new address[](1),
                string.concat("Deposit into ", ERC20(managedVaults[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                managedVaults[i],
                false,
                "redeemIntent(uint256,address,address)",
                new address[](2),
                string.concat("Redeem Intent for ", ERC20(managedVaults[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                managedVaults[i],
                false,
                "cancelWithdrawalIntent(uint256,uint256,address)",
                new address[](1),
                string.concat("Cancel Withdrawal Intent for ", ERC20(managedVaults[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                managedVaults[i],
                false,
                "withdrawFromEpoch(uint256,address,(address,bytes,uint256))",
                new address[](2),
                string.concat("Withdraw From Epoch ", ERC20(managedVaults[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
        leafs[leafIndex] = ManageLeaf(
            token,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Dolomite DepositWithdraw Router to spend ", ERC20(token).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "dolomiteMargin");

        // Wad Scaled Functions

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
            false,
            "depositWei(uint256,uint256,uint256)",
            new address[](1),
            string.concat(
                "Deposit ",
                ERC20(token).symbol(),
                " into Dolomite DepositWithdraw Router Market ID: ",
                vm.toString(marketId)
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = token;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
            false,
            "depositWeiIntoDefaultAccount(uint256,uint256)",
            new address[](1),
            string.concat(
                "Deposit ",
                ERC20(token).symbol(),
                " into Dolomite DepositWithdraw Router Market ID: ",
                vm.toString(marketId),
                " Default Account"
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = token;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
            false,
            "withdrawWei(uint256,uint256,uint256,uint8)",
            new address[](1),
            string.concat(
                "Withdraw ",
                ERC20(token).symbol(),
                " from Dolomite DepositWithdraw Router Market ID: ",
                vm.toString(marketId)
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = token;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
            false,
            "withdrawWeiFromDefaultAccount(uint256,uint256,uint8)",
            new address[](1),
            string.concat(
                "Withdraw ",
                ERC20(token).symbol(),
                " from Dolomite DepositWithdraw Router Market ID: ",
                vm.toString(marketId),
                " default account"
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = token;

        // Native ETH Functions
        if (addNative) {
            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
                true,
                "depositETH(uint256)",
                new address[](0),
                string.concat("Deposit ETH into Dolomite ETH Market"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );

            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
                true,
                "depositETHIntoDefaultAccount()",
                new address[](0),
                string.concat("Deposit ETH into Dolomite ETH Market in default account"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );

            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
                false,
                "withdrawETH(uint256,uint256,uint8)",
                new address[](0),
                string.concat("Withdraw ETH from Dolomite ETH Market"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );

            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
                false,
                "withdrawETHFromDefaultAccount(uint256,uint8)",
                new address[](0),
                string.concat("Withdraw ETH from Dolomite ETH Market default account"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
        }

        // Par Scaled Functions

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
            false,
            "depositPar(uint256,uint256,uint256)",
            new address[](1),
            string.concat(
                "Deposit Par scaled ",
                ERC20(token).symbol(),
                " into Dolomite DepositWithdraw Router Market ID: ",
                vm.toString(marketId)
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = token;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
            false,
            "depositParIntoDefaultAccount(uint256,uint256)",
            new address[](1),
            string.concat(
                "Deposit Par scaled ",
                ERC20(token).symbol(),
                " into Dolomite DepositWithdraw Router Market ID: ",
                vm.toString(marketId),
                " in default account"
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = token;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
            false,
            "withdrawPar(uint256,uint256,uint256,uint8)",
            new address[](1),
            string.concat(
                "Withdraw Par scaled ",
                ERC20(token).symbol(),
                " from Dolomite DepositWithdraw Router Market ID: ",
                vm.toString(marketId)
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = token;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "dolomiteDepositWithdrawRouter"),
            false,
            "withdrawParFromDefaultAccount(uint256,uint256,uint8)",
            new address[](1),
            string.concat(
                "Withdraw Par scaled ",
                ERC20(token).symbol(),
                " from Dolomite DepositWithdraw Router Market ID: ",
                vm.toString(marketId)
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = token;
    }

    function _addDolomiteBorrowLeafs(ManageLeaf[] memory leafs, address borrowToken) internal {
        uint256 marketId =
            IDolomiteMargin(getAddress(sourceChain, "dolomiteMargin")).getMarketIdByTokenAddress(borrowToken);

        //Main Borrow Position Functions

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "dolomiteBorrowProxy"),
            false,
            "openBorrowPosition(uint256,uint256,uint256,uint256,uint8)",
            new address[](1),
            string.concat(
                "Use ",
                ERC20(borrowToken).symbol(),
                " as collateral on Dolomite BorrowPosition Market ID: ",
                vm.toString(marketId)
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = borrowToken;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "dolomiteBorrowProxy"),
            false,
            "closeBorrowPosition(uint256,uint256,uint256[])",
            new address[](1),
            string.concat(
                "Close Borrow Position of ",
                ERC20(borrowToken).symbol(),
                " in Dolomite BorrowPosition Market ID: ",
                vm.toString(marketId)
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = borrowToken;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "dolomiteBorrowProxy"),
            false,
            "repayAllForBorrowPosition(uint256,uint256,uint256,uint8)",
            new address[](1),
            string.concat(
                "Repay Borrow Position of ",
                ERC20(borrowToken).symbol(),
                " in Dolomite BorrowPosition Market ID: ",
                vm.toString(marketId)
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = borrowToken;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "dolomiteBorrowProxy"),
            false,
            "transferBetweenAccounts(uint256,uint256,uint256,uint256,uint8)",
            new address[](1),
            string.concat(
                "Transfer Borrow Position of ",
                ERC20(borrowToken).symbol(),
                " in Dolomite BorrowPosition Market ID: ",
                vm.toString(marketId),
                " to additional subaccount"
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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

        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "dolomiteBorrowProxy"),
            false,
            "openBorrowPositionWithDifferentAccounts(address,uint256,address,uint256,uint256,uint256,uint8)",
            new address[](3),
            string.concat(
                "Open Borrow Position of ",
                ERC20(borrowToken).symbol(),
                " in Dolomite BorrowPosition Market ID: ",
                vm.toString(marketId),
                " from ",
                vm.toString(from),
                " to ",
                vm.toString(to)
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = from;
        leafs[leafIndex].argumentAddresses[1] = to;
        leafs[leafIndex].argumentAddresses[2] = borrowToken;

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "dolomiteBorrowProxy"),
            false,
            "closeBorrowPositionWithDifferentAccounts(address,uint256,address,uint256,uint256[])",
            new address[](3),
            string.concat(
                "Close Borrow Position of ",
                ERC20(borrowToken).symbol(),
                " in Dolomite BorrowPosition Market ID: ",
                vm.toString(marketId),
                " from ",
                vm.toString(from),
                " to ",
                vm.toString(to)
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = from; //borrowAccountOwner
        leafs[leafIndex].argumentAddresses[1] = to;
        leafs[leafIndex].argumentAddresses[2] = borrowToken;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "dolomiteBorrowProxy"),
            false,
            "transferBetweenAccountsWithDifferentAccounts(address,uint256,address,uint256,uint256,uint256,uint8)",
            new address[](3),
            string.concat(
                "Transfer ",
                ERC20(borrowToken).symbol(),
                " in Dolomite BorrowPosition Market ID: ",
                vm.toString(marketId),
                " from ",
                vm.toString(from),
                " to ",
                vm.toString(to)
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = to; //TODO check this
        leafs[leafIndex].argumentAddresses[1] = from; //TODO this too
        leafs[leafIndex].argumentAddresses[2] = borrowToken;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "dolomiteBorrowProxy"),
            false,
            "repayAllForBorrowPositionWithDifferentAccounts(address,uint256,address,uint256,uint256,uint8)",
            new address[](3),
            string.concat(
                "Repay ",
                ERC20(borrowToken).symbol(),
                " in Dolomite BorrowPosition Market ID: ",
                vm.toString(marketId),
                " from ",
                vm.toString(from),
                " to ",
                vm.toString(to)
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        leafs[leafIndex] = ManageLeaf(
            stakingToken,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve BGT Reward Vault to spend: ", ERC20(stakingToken).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = vault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "stake(uint256)",
            new address[](0),
            string.concat("Stake ", ERC20(stakingToken).symbol(), " in BGT Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "withdraw(uint256)",
            new address[](0),
            string.concat("Withdraw ", ERC20(stakingToken).symbol(), " from BGT Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "getReward(address,address)",
            new address[](2),
            string.concat("Get reward for ", ERC20(stakingToken).symbol(), " BGT Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "exit(address)",
            new address[](1),
            string.concat("Exit ", ERC20(stakingToken).symbol(), " BGT Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        if (delegateStaker != address(0)) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                vault,
                false,
                "delegateStake(address,uint256)",
                new address[](1),
                string.concat(
                    "Delegate stake for ", ERC20(stakingToken).symbol(), " BGT Vault to: ", vm.toString(delegateStaker)
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = delegateStaker;

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                vault,
                false,
                "delegateWithdraw(address,uint256)",
                new address[](1),
                string.concat(
                    "Delegate withdraw for ",
                    ERC20(stakingToken).symbol(),
                    " BGT Vault from: ",
                    vm.toString(delegateStaker)
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = delegateStaker;
        }

        if (operator != address(0)) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                vault,
                false,
                "setOperator(address)",
                new address[](1),
                string.concat("Get reward for ", ERC20(stakingToken).symbol(), " BGT Vault"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
            leafs[leafIndex] = ManageLeaf(
                silos[i],
                false,
                "deposit(uint256,address,uint8)",
                new address[](1),
                string.concat("Deposit ", underlyingName, " with type into Silo"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                silos[i],
                false,
                "mint(uint256,address,uint8)",
                new address[](1),
                string.concat("Mint ", underlyingName, " with type into Silo"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                silos[i],
                false,
                "withdraw(uint256,address,address,uint8)",
                new address[](2),
                string.concat("Withdraw ", underlyingName, " with type from Silo"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                silos[i],
                false,
                "redeem(uint256,address,address,uint8)",
                new address[](2),
                string.concat("Redeem ", underlyingName, " with type from Silo"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                silos[i],
                false,
                "borrow(uint256,address,address)",
                new address[](2),
                string.concat("Borrow ", underlyingName, " from Silo"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                silos[i],
                false,
                "borrowShares(uint256,address,address)",
                new address[](2),
                string.concat("Borrow shares of ", underlyingName, " from Silo"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                silos[i],
                false,
                "borrowSameAsset(uint256,address,address)",
                new address[](2),
                string.concat("Borrow same asset ", underlyingName, " from Silo"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                silos[i],
                false,
                "repay(uint256,address)",
                new address[](1),
                string.concat("Repay ", underlyingName, " to Silo"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                silos[i],
                false,
                "repayShares(uint256,address)",
                new address[](1),
                string.concat("Repay shares of ", underlyingName, " to Silo"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                silos[i],
                false,
                "transitionCollateral(uint256,address,uint8)",
                new address[](1),
                string.concat("Transition Collateral in ", underlyingName, " Silo"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                silos[i],
                false,
                "switchCollateralToThisSilo()",
                new address[](0),
                string.concat("Switch Collateral to ", underlyingName, " Silo"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                silos[i],
                false,
                "accrueInterest()",
                new address[](0),
                string.concat("Accrue interest on ", underlyingName, " Silo"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
        }

        for (uint256 i = 0; i < incentivesControllers.length; i++) {
            if (incentivesControllers[i] != address(0)) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    incentivesControllers[i],
                    false,
                    "claimRewards(address)",
                    new address[](1),
                    string.concat("Claim All Rewards from Silo Incentives Controller"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    incentivesControllers[i],
                    false,
                    "claimRewards(address,string[])",
                    new address[](1),
                    string.concat("Claim Rewards from market from Silo Incentives Controller"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            }
        }
    }

    function _addSiloVaultLeafs(ManageLeaf[] memory leafs, address vault) internal {
        _addERC4626Leafs(leafs, ERC4626(vault));

        unchecked {
            leafIndex++;
        }

        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "claimRewards()",
            new address[](0),
            string.concat("Claim rewards from ", ERC4626(vault).name()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= LBTC Bridge =========================================
    function _addLBTCBridgeLeafs(ManageLeaf[] memory leafs, bytes32 toChain) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "LBTC"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve LBTC Bridge Wrapper to spend LBTC"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "lbtcBridge");

        address toChain0 = address(bytes20(bytes16(toChain)));
        address toChain1 = address(bytes20(bytes16(toChain << 128)));

        //kinda scuffed, can maybe just use one address?
        bytes32 boringVaultBytes = getBytes32(sourceChain, "boringVault");
        address toAddress0 = address(bytes20(bytes16(boringVaultBytes)));
        address toAddress1 = address(bytes20(bytes16(boringVaultBytes << 128)));

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "lbtcBridge"),
            true,
            "deposit(bytes32,bytes32,uint64)",
            new address[](4),
            string.concat("Deposit LBTC to ChainID: ", vm.toString(toChain)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
    ) internal {
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
        leafs[leafIndex] = ManageLeaf(
            asset,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve ", ERC4626(PT).symbol(), " to spend ", ERC20(asset).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = PT;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vaultShare,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve ", ERC4626(swToken).symbol(), " to spend ", ERC20(vaultShare).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = swToken;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vaultShare,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve ", ERC20(PT).symbol(), " to spend IBT ", ERC20(vaultShare).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = PT;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            swToken,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve ", ERC20(PT).symbol(), " to spend IBT ", ERC20(swToken).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = PT;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            swToken,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Spectra Curve Pool to spend ", ERC20(swToken).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = spectraPool;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            PT,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Spectra Curve Pool to spend ", ERC20(PT).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = spectraPool;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            swToken,
            false,
            "wrap(uint256,address)",
            new address[](1),
            string.concat("Wrap ", ERC20(asset).symbol(), " into ", ERC4626(swToken).name()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            swToken,
            false,
            "unwrap(uint256,address,address)",
            new address[](2),
            string.concat("Unwrap ", ERC20(asset).symbol(), " from ", ERC4626(swToken).name()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            PT,
            false,
            "deposit(uint256,address,address,uint256)",
            new address[](2),
            string.concat("Deposit ", ERC20(asset).symbol(), " into ", ERC4626(PT).name(), " with slippage check"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            PT,
            false,
            "depositIBT(uint256,address)",
            new address[](1),
            string.concat("Deposit ", ERC20(vaultShare).symbol(), " into ", ERC4626(PT).name()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            PT,
            false,
            "depositIBT(uint256,address,address,uint256)",
            new address[](2),
            string.concat("Deposit ", ERC20(vaultShare).symbol(), " into ", ERC4626(PT).name(), " with slippage check"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            PT,
            false,
            "redeem(uint256,address,address,uint256)",
            new address[](2),
            string.concat("Redeem ", ERC4626(PT).name(), " for ", ERC20(asset).symbol(), " with slippage check"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            PT,
            false,
            "redeemForIBT(uint256,address,address)",
            new address[](2),
            string.concat("Redeem ", ERC4626(PT).name(), " for ", ERC20(vaultShare).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            PT,
            false,
            "redeemForIBT(uint256,address,address,uint256)",
            new address[](2),
            string.concat("Redeem ", ERC4626(PT).name(), " for ", ERC20(vaultShare).symbol(), " with slippage check"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            PT,
            false,
            "withdraw(uint256,address,address,uint256)",
            new address[](2),
            string.concat("Withdraw ", ERC20(asset).symbol(), " from ", ERC4626(PT).name(), " with slippage check"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            PT,
            false,
            "withdrawIBT(uint256,address,address)",
            new address[](2),
            string.concat("Withdraw ", ERC20(vaultShare).symbol(), " from ", ERC4626(PT).name()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            PT,
            false,
            "withdrawIBT(uint256,address,address,uint256)",
            new address[](2),
            string.concat("Withdraw ", ERC20(vaultShare).symbol(), " from ", ERC4626(PT).name(), " with slippage check"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            PT,
            false,
            "updateYield(address)",
            new address[](1),
            string.concat("Update yield for Boring Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            PT,
            false,
            "claimYield(address,uint256)",
            new address[](1),
            string.concat("Claim yield for Boring Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            YT,
            false,
            "burn(uint256)",
            new address[](0),
            string.concat("Claim yield for Boring Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            spectraPool,
            false,
            "exchange(uint256,uint256,uint256,uint256)",
            new address[](0),
            string.concat("Exchange tokens in Spectra Pool"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            spectraPool,
            false,
            "add_liquidity(uint256[2],uint256)",
            new address[](0),
            string.concat("Add liquidity in Spectra Pool"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            spectraPool,
            false,
            "remove_liquidity(uint256,uint256[2])",
            new address[](0),
            string.concat("Remove liquidity from Spectra Pool"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        _addERC4626Leafs(leafs, ERC4626(swToken));
    }

    // ========================================= Odos =========================================

    function _addOdosSwapLeafs(ManageLeaf[] memory leafs, address[] memory tokens, SwapKind[] memory kind) internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][tokens[i]][getAddress(
                    sourceChain, "odosRouterV2"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    tokens[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Odos Router V2 to spend ", ERC20(tokens[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "odosRouterV2");
            }

            for (uint256 j = 0; j < tokens.length; j++) {
                if (i == j) continue;

                if (
                    !ownerToOdosSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[i]][tokens[j]]
                        && kind[j] != SwapKind.Sell
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "odosRouterV2"),
                        false,
                        "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)",
                        new address[](4),
                        string.concat("Swap ", ERC20(tokens[i]).symbol(), " for ", ERC20(tokens[j]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = tokens[i];
                    leafs[leafIndex].argumentAddresses[1] = tokens[j];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "odosExecutor");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "odosRouterV2"),
                        false,
                        "swapCompact()",
                        new address[](4),
                        string.concat("Swap Compact ", ERC20(tokens[i]).symbol(), " for ", ERC20(tokens[j]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = tokens[i];
                    leafs[leafIndex].argumentAddresses[1] = tokens[j];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "odosExecutor");

                    ownerToOdosSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[i]][tokens[j]]
                    = true;
                }

                if (
                    kind[i] == SwapKind.BuyAndSell
                        && !ownerToOdosSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[j]][tokens[i]]
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "odosRouterV2"),
                        false,
                        "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)",
                        new address[](4),
                        string.concat("Swap ", ERC20(tokens[j]).symbol(), " for ", ERC20(tokens[i]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = tokens[j];
                    leafs[leafIndex].argumentAddresses[1] = tokens[i];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "odosExecutor");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "odosRouterV2"),
                        false,
                        "swapCompact()",
                        new address[](4),
                        string.concat("Swap Compact ", ERC20(tokens[j]).symbol(), " for ", ERC20(tokens[i]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = tokens[j];
                    leafs[leafIndex].argumentAddresses[1] = tokens[i];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "odosExecutor");

                    ownerToOdosSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[j]][tokens[i]]
                    = true;
                }
            }
        }
    }

    function _addOdosOwnedSwapLeafs(ManageLeaf[] memory leafs, address[] memory tokens, SwapKind[] memory kind) internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][tokens[i]][getAddress(
                    sourceChain, "odosRouterV2"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    tokens[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Odos Router V2 to spend ", ERC20(tokens[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "odosRouterV2");
            }

            for (uint256 j = 0; j < tokens.length; j++) {
                if (i == j) continue;

                if (
                    !ownerToOdosSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[i]][tokens[j]]
                        && kind[j] != SwapKind.Sell
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "odosRouterV2"),
                        false,
                        "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)",
                        new address[](3),
                        string.concat("Swap ", ERC20(tokens[i]).symbol(), " for ", ERC20(tokens[j]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = tokens[i];
                    leafs[leafIndex].argumentAddresses[1] = tokens[j];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "odosRouterV2"),
                        false,
                        "swapCompact()",
                        new address[](3),
                        string.concat("Swap Compact ", ERC20(tokens[i]).symbol(), " for ", ERC20(tokens[j]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = tokens[i];
                    leafs[leafIndex].argumentAddresses[1] = tokens[j];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                    ownerToOdosSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[i]][tokens[j]]
                    = true;
                }

                if (
                    kind[i] == SwapKind.BuyAndSell
                        && !ownerToOdosSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[j]][tokens[i]]
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "odosRouterV2"),
                        false,
                        "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)",
                        new address[](3),
                        string.concat("Swap ", ERC20(tokens[j]).symbol(), " for ", ERC20(tokens[i]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = tokens[j];
                    leafs[leafIndex].argumentAddresses[1] = tokens[i];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "odosRouterV2"),
                        false,
                        "swapCompact()",
                        new address[](3),
                        string.concat("Swap Compact ", ERC20(tokens[j]).symbol(), " for ", ERC20(tokens[i]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = tokens[j];
                    leafs[leafIndex].argumentAddresses[1] = tokens[i];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

                    ownerToOdosSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[j]][tokens[i]]
                    = true;
                }
            }
        }
    }
    
    function _addOdosOneWaySwapLeafs(ManageLeaf[] memory leafs, address tokenA, address tokenB) internal {

        // add approval if not already added
        if (!ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][tokenA][getAddress(sourceChain, "odosRouterV2")]) {
            ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][tokenA][getAddress(sourceChain, "odosRouterV2")] = true;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                tokenA,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Odos Router V2 to spend ", ERC20(tokenA).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "odosRouterV2");
        }

        // add swap from tokenA to tokenB
        if (!ownerToOdosSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokenA][tokenB]) {
            ownerToOdosSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokenA][tokenB] = true;

            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "odosRouterV2"),
                false,
                "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)",
                new address[](4),
                string.concat("Swap ", ERC20(tokenA).symbol(), " for ", ERC20(tokenB).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = tokenA;
            leafs[leafIndex].argumentAddresses[1] = tokenB;
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "odosExecutor");

            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "odosRouterV2"),
                false,
                "swapCompact()",
                new address[](4),
                string.concat("Swap Compact ", ERC20(tokenA).symbol(), " for ", ERC20(tokenB).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = tokenA;
            leafs[leafIndex].argumentAddresses[1] = tokenB;
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "odosExecutor");
        }
    }

    // ========================================= GlueX =========================================
    function _addGlueXLeafs(ManageLeaf[] memory leafs, address[] memory tokens, SwapKind[] memory kind) internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][tokens[i]][getAddress(
                    sourceChain, "glueXRouter"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    tokens[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve GlueX Router to spend ", ERC20(tokens[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "glueXRouter");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    tokens[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Permit2 to spend ", ERC20(tokens[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "permit2");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "permit2"),
                    false,
                    "approve(address,address,uint160,uint48)",
                    new address[](2),
                    string.concat("Use Permit2 to approve GlueX Router to spend ", ERC20(tokens[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = tokens[i];
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "glueXRouter");
            }

            for (uint256 j = 0; j < tokens.length; j++) {
                if (i == j) continue;

                if (
                    !ownerToGlueXSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[i]][tokens[j]]
                        && kind[j] != SwapKind.Sell
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "glueXRouter"),
                        false,
                        "swap(address,(address,address,address,address,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,bool,bytes32),(address,uint256,bytes)[])",
                        new address[](5),
                        string.concat("Swap ", ERC20(tokens[i]).symbol(), " for ", ERC20(tokens[j]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "glueXExecutor");
                    leafs[leafIndex].argumentAddresses[1] = tokens[i];
                    leafs[leafIndex].argumentAddresses[2] = tokens[j];
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[4] = address(0); 

                    ownerToGlueXSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[j]][tokens[i]]
                    = true;
                }

                if (
                    kind[i] == SwapKind.BuyAndSell
                        && !ownerToGlueXSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[j]][tokens[i]]
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "glueXRouter"),
                        false,
                        "swap(address,(address,address,address,address,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,bool,bytes32),(address,uint256,bytes)[])",
                        new address[](5),
                        string.concat("Swap ", ERC20(tokens[i]).symbol(), " for ", ERC20(tokens[j]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "glueXExecutor");
                    leafs[leafIndex].argumentAddresses[1] = tokens[i];
                    leafs[leafIndex].argumentAddresses[2] = tokens[j];
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[4] = address(0); 

                    ownerToGlueXSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[j]][tokens[i]]
                    = true;
                }
            }
        }
    }

    

    // ========================================= Ooga Booga =========================================

    function _addOogaBoogaSwapLeafs(ManageLeaf[] memory leafs, address[] memory tokens, SwapKind[] memory kind)
        internal
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][tokens[i]][getAddress(
                    sourceChain, "OBRouter"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    tokens[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Ooga Booga Router to spend ", ERC20(tokens[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "OBRouter");
            }

            for (uint256 j = 0; j < tokens.length; j++) {
                if (i == j) continue;

                if (
                    !ownerToOogaBoogaSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[i]][tokens[j]]
                        && kind[j] != SwapKind.Sell
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "OBRouter"),
                        false,
                        "swap((address,uint256,address,uint256,uint256,address),bytes,address,uint32)",
                        new address[](4),
                        string.concat("Swap ", ERC20(tokens[i]).symbol(), " for ", ERC20(tokens[j]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = tokens[i];
                    leafs[leafIndex].argumentAddresses[1] = tokens[j];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "OBExecutor");

                    ownerToOogaBoogaSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[i]][tokens[j]]
                    = true;
                }

                if (
                    kind[i] == SwapKind.BuyAndSell
                        && !ownerToOogaBoogaSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[j]][tokens[i]]
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "OBRouter"),
                        false,
                        "swap((address,uint256,address,uint256,uint256,address),bytes,address,uint32)",
                        new address[](4),
                        string.concat("Swap ", ERC20(tokens[j]).symbol(), " for ", ERC20(tokens[i]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = tokens[j];
                    leafs[leafIndex].argumentAddresses[1] = tokens[i];
                    leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "OBExecutor");

                    ownerToOogaBoogaSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[j]][tokens[i]]
                    = true;
                }
            }
        }
    }

    // ========================================= Sushi Snwapper =========================================

    function _addSnwapLeafs(ManageLeaf[] memory leafs, address[] memory tokens, SwapKind[] memory kind)
        internal
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (
                !ownerToTokenToSpenderToApprovalInTree[getAddress(sourceChain, "boringVault")][tokens[i]][getAddress(
                    sourceChain, "redSnwapperRouter"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    tokens[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Red Snwapper Router to spend ", ERC20(tokens[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "redSnwapperRouter");
            }

            for (uint256 j = 0; j < tokens.length; j++) {
                if (i == j) continue;

                if (
                    !ownerToSushiSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[i]][tokens[j]]
                        && kind[j] != SwapKind.Sell
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "redSnwapperRouter"),
                        false,
                        "snwap(address,uint256,address,address,uint256,address,bytes)",
                        new address[](4),
                        string.concat("Swap ", ERC20(tokens[i]).symbol(), " for ", ERC20(tokens[j]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = tokens[i];
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[2] = tokens[j];
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "redSnwapperExecutor");

                    ownerToSushiSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[i]][tokens[j]]
                    = true;
                }

                if (
                    kind[i] == SwapKind.BuyAndSell
                        && !ownerToSushiSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[j]][tokens[i]]
                ) {
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "redSnwapperRouter"),
                        false,
                        "snwap(address,uint256,address,address,uint256,address,bytes)",
                        new address[](4),
                        string.concat("Swap ", ERC20(tokens[j]).symbol(), " for ", ERC20(tokens[i]).symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = tokens[j];
                    leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                    leafs[leafIndex].argumentAddresses[2] = tokens[i];
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "redSnwapperExecutor");

                    ownerToSushiSellTokenToBuyTokenToInTree[getAddress(sourceChain, "boringVault")][tokens[j]][tokens[i]]
                    = true;
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
            leafs[leafIndex] = ManageLeaf(
                baseToken,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve CrocSwapDex (Ambient) to spend ", ERC20(baseToken).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "crocSwapDex");
        }

        if (quoteToken != getAddress(sourceChain, "ETH")) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                quoteToken,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve CrocSwapDex (Ambient) to spend ", ERC20(quoteToken).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "crocSwapDex");
        }

        if (baseToken != getAddress(sourceChain, "ETH") && quoteToken != getAddress(sourceChain, "ETH")) {
            //used for every command that includes the warm path
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "crocSwapDex"),
                false,
                "userCmd(uint16,bytes)",
                new address[](3),
                string.concat("Call usrCmd using 'WarmPath' with no ETH"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = baseToken; //base (these are set by pool maybe?)
            leafs[leafIndex].argumentAddresses[1] = quoteToken; //quote
            leafs[leafIndex].argumentAddresses[2] = address(0); //lp conduit (user owned)

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "crocSwapDex"),
                false,
                "userCmd(uint16,bytes)",
                new address[](2),
                string.concat("Call userCmd using 'HotPath' or 'KnockoutPath' without ETH "),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = baseToken; //base (these are set by pool maybe?)
            leafs[leafIndex].argumentAddresses[1] = quoteToken; //quote
        } else {
            if (baseToken == getAddress(sourceChain, "ETH")) baseToken = address(0);
            if (quoteToken == getAddress(sourceChain, "ETH")) quoteToken = address(0);

            // used for minting positions
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "crocSwapDex"),
                true,
                "userCmd(uint16,bytes)",
                new address[](3),
                string.concat("Call userCmd using 'WarmPath' with ETH "),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = baseToken; //base (these are set by pool maybe?)
            leafs[leafIndex].argumentAddresses[1] = quoteToken; //quote
            leafs[leafIndex].argumentAddresses[2] = address(0); //lp conduit (user owned)

            //Used for commands that don't include sending ETH (harvest, burn)
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "crocSwapDex"),
                false,
                "userCmd(uint16,bytes)",
                new address[](3),
                string.concat("Call userCmd using 'WarmPath' without ETH"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = baseToken; //base (these are set by pool maybe?)
            leafs[leafIndex].argumentAddresses[1] = quoteToken; //quote
            leafs[leafIndex].argumentAddresses[2] = address(0); //lp conduit (user owned)

            //swapping eth to token, using knockout
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "crocSwapDex"),
                true,
                "userCmd(uint16,bytes)",
                new address[](2),
                string.concat("Call userCmd using 'HotPath' or 'KnockoutPath' with ETH "),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = baseToken; //base (these are set by pool maybe?)
            leafs[leafIndex].argumentAddresses[1] = quoteToken; //quote

            //swapping token to eth, using knockout
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "crocSwapDex"),
                false,
                "userCmd(uint16,bytes)",
                new address[](2),
                string.concat("Call userCmd using 'HotPath' or 'KnockoutPath' without ETH "),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = baseToken; //base (these are set by pool maybe?)
            leafs[leafIndex].argumentAddresses[1] = quoteToken; //quote
        }
    }

    function _addAmbientSwapLeafs(ManageLeaf[] memory leafs, address baseToken, address quoteToken) internal {
        if (baseToken != getAddress(sourceChain, "ETH")) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                baseToken,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve CrocSwapDex (Ambient) to spend ", ERC20(baseToken).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "crocSwapDex");
        }

        if (quoteToken != getAddress(sourceChain, "ETH")) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                quoteToken,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve CrocSwapDex (Ambient) to spend ", ERC20(quoteToken).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "crocSwapDex"),
                false,
                "swap(address,address,uint256,bool,bool,uint128,uint16,uint128,uint128,uint8)",
                new address[](2),
                string.concat(
                    "Swap using CrocSwapDex (Ambient) between ",
                    ERC20(baseToken).symbol(),
                    " and ",
                    ERC20(quoteToken).symbol()
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "crocSwapDex"),
                true,
                "swap(address,address,uint256,bool,bool,uint128,uint16,uint128,uint128,uint8)",
                new address[](2),
                string.concat("Swap using CrocSwapDex (Ambient) between ETH and ", ERC20(erc20Token).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = baseToken;
            leafs[leafIndex].argumentAddresses[1] = quoteToken;

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "crocSwapDex"),
                false,
                "swap(address,address,uint256,bool,bool,uint128,uint16,uint128,uint128,uint8)",
                new address[](2),
                string.concat("Swap using CrocSwapDex (Ambient) between ", ERC20(erc20Token).symbol(), " and ETH"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = baseToken;
            leafs[leafIndex].argumentAddresses[1] = quoteToken;
        }
    }

    // ========================================= Level Money / LevelUSD =========================================

    function _addLevelLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "USDC"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve USDC to be spent by Level Minter"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "levelShares");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "USDT"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve USDT to be spent by Level Minter"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "levelShares");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "lvlUSD"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve lvlUSD to be spent by Level Minter"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "levelMinter");

        //mintDefault
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "levelMinter"),
            false,
            "mint((address,address,uint256,uint256))",
            new address[](2),
            string.concat("Mint lvlUSD with USDC"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "USDC");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "levelMinter"),
            false,
            "mint((address,address,uint256,uint256))",
            new address[](2),
            string.concat("Mint lvlUSD with USDT"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "USDT");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "levelMinter"),
            false,
            "initiateRedeem(address,uint256,uint256)",
            new address[](1),
            string.concat("Initiate Redeem for USDC from lvlUSD"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDC");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "levelMinter"),
            false,
            "initiateRedeem(address,uint256,uint256)",
            new address[](1),
            string.concat("Initiate Redeem for USDT from lvlUSD"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDT");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "levelMinter"),
            false,
            "completeRedeem(address,address)",
            new address[](2),
            string.concat("Complete Redeem for USDC"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDC");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "levelMinter"),
            false,
            "completeRedeem(address,address)",
            new address[](2),
            string.concat("Complete Redeem for USDT"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDT");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "levelMinter"),
            false,
            "redeem((uint8,address,address,address,uint256,uint256))",
            new address[](3),
            string.concat("Redeem for USDC (only if cooldown is off)"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "USDC");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "levelMinter"),
            false,
            "redeem((uint8,address,address,address,uint256,uint256))",
            new address[](3),
            string.concat("Redeem for USDT (only if cooldown is off)"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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

            leafs[leafIndex] = ManageLeaf(
                ETH, //will be weth on beraChain
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve etherFiL2SyncPool to spend WETH"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "etherFiL2SyncPool");

            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "etherFiL2SyncPool"), //target
                false,
                "deposit(address,uint256,uint256,address)",
                new address[](2),
                string.concat("Deposit ETH into WeETH"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = ETH;
            leafs[leafIndex].argumentAddresses[1] = referral;
        } else {
            unchecked {
                leafIndex++;
            }

            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "etherFiL2SyncPool"), //target
                true,
                "deposit(address,uint256,uint256,address)",
                new address[](2),
                string.concat("Deposit ETH into WeETH"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = ETH;
            leafs[leafIndex].argumentAddresses[1] = referral;
        }
    }

    // ========================================= ELX Claiming =========================================
    function _addELXClaimingLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "elxTokenDistributor"),
            false,
            "claim(uint256,bytes32[],bytes)",
            new address[](0),
            string.concat("Claim ELX Airdrop"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= FLUID Claiming =========================================
    function _addFluidRewardsClaiming(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "fluidMerkleDistributor"),
            false,
            "claim(address,uint256,uint8,bytes32,uint256,bytes32[],bytes)",
            new address[](1),
            string.concat("Claim FLUID rewards"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
            leafs[leafIndex] = ManageLeaf(
                depositTokens[i],
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve KING to spend ", ERC20(depositTokens[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "KING");
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "KING"),
            false,
            "deposit(address[],uint256[],address)",
            new address[](1),
            string.concat("Deposit tokens for KING"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "KING"),
            false,
            "redeem(uint256)",
            new address[](0),
            string.concat("Redeem KING"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "kingMerkleDistributor"),
            false,
            "claim(address,uint256,bytes32,bytes32[])",
            new address[](1),
            string.concat("Claim KING rewards"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        leafs[leafIndex] = ManageLeaf(
            deriveDepositToken,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat(
                "Approve Derive ", depositName, " Deposit Vault to spend ", ERC20(deriveDepositToken).symbol()
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = depositVault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            deriveWithdrawToken,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat(
                "Approve Derive ", withdrawName, " Withdraw Vault to spend ", ERC20(deriveWithdrawToken).symbol()
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = withdrawVault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            depositVault,
            true, //fees
            "bridge(address,uint256,uint256,address,bytes,bytes)",
            new address[](4),
            string.concat("Deposit ", ERC20(deriveDepositToken).symbol(), " into Derive ", depositName, " Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = deriveWalletOwnedByBoringVault;
        leafs[leafIndex].argumentAddresses[1] = depositConnector;
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[3] = connectorPlugOnDeriveChain;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            withdrawVault,
            true, //fees
            "bridge(address,uint256,uint256,address,bytes,bytes)",
            new address[](4),
            string.concat("Withdraw ", ERC20(deriveWithdrawToken).symbol(), " From Derive ", withdrawName, " Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = deriveWalletOwnedByBoringVault;
        leafs[leafIndex].argumentAddresses[1] = withdrawConnector;
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[3] = controllerOnMainnet;
    }

    function _addDeriveClaimLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "rewardDistributor"),
            false,
            "claimAll()",
            new address[](0),
            string.concat("Claim rewards on Derive"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        //====== stDRV ======

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "stDRV"),
            false,
            "redeem(uint256,uint256)",
            new address[](0),
            string.concat("Claim rewards on Derive"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "stDRV"),
            false,
            "cancelRedeem(uint256)",
            new address[](0),
            string.concat("Cancel Redeem of Staked Derive"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "stDRV"),
            false,
            "finalizeRedeem(uint256)",
            new address[](0),
            string.concat("Finalize Redeem of Staked Derive"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        leafs[leafIndex] = ManageLeaf(
            mintableERC20OnDerive,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Withdraw Wrapper to spend ", ERC20(mintableERC20OnDerive).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "deriveWithdrawWrapper");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            mintableERC20OnDerive,
            false,
            "withdrawToChain(address,uint256,address,address,address,uint256)",
            new address[](4),
            string.concat("Approve Withdraw Wrapper to spend ", ERC20(mintableERC20OnDerive).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = mintableERC20OnDerive;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[2] = socketControllerOnDerive;
        leafs[leafIndex].argumentAddresses[3] = connectorPlugOnDeriveChain;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            mintableERC20OnDerive,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Socket Controller to spend ", ERC20(mintableERC20OnDerive).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = socketControllerOnDerive;

        //bridge "token" back to mainnet
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            socketControllerOnDerive,
            true,
            "bridge(address,uint256,uint256,address,bytes,bytes)",
            new address[](4),
            string.concat("Bridge using controller"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        leafs[leafIndex] = ManageLeaf(
            token,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve zkEVM Compatible Bridge to spend", ERC20(token).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = bridge;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            bridge,
            false,
            "bridgeAsset(uint32,address,uint256,address,bool,bytes)",
            new address[](3),
            string.concat("Bridge ", ERC20(token).symbol(), " using zkEVM Compatible Bridge"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(uint160(toChain));
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[2] = token;

        if (token == getAddress(sourceChain, "ETH")) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                bridge,
                true,
                "bridgeAsset(uint32,address,uint256,address,bool,bytes)",
                new address[](3),
                string.concat("Bridge ETH using zkEVM Compatible Bridge"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(uint160(toChain)); 
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault"); 
            leafs[leafIndex].argumentAddresses[2] = address(uint160(fromChain)); //zkEVM bridge expects native eth to be address(0)
        }

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            bridge,
            false,
            "claimAsset(bytes32[32],bytes32[32],uint256,bytes32,bytes32,uint32,address,uint32,address,uint256,bytes)",
            new address[](4),
            string.concat("Claim  ", ERC20(token).symbol(), " from zkEVM Compatible Bridge"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        leafs[leafIndex].argumentAddresses[0] = address(uint160(fromChain)); 
        leafs[leafIndex].argumentAddresses[1] = token; 
        leafs[leafIndex].argumentAddresses[2] = address(uint160(fromChain)); 
        leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain,  "boringVault"); 
    
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
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "USDC"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve USDC to be spent by USDC TokenMessengerV2"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "usdcTokenMessengerV2"); 

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "usdcTokenMessengerV2"),
            false,
            "depositForBurn(uint256,uint32,bytes32,address,bytes32,uint256,uint32)",
            new address[](4),
            string.concat("Bridge USDC to ", vm.toString(toChain)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(uint160(toChain)); 
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");  
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "USDC");  
        leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");  

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "usdcMessageTransmitterV2"),
            false,
            "receiveMessage(bytes,bytes)",
            new address[](0),
            string.concat("Receive USDC from ", vm.toString(toChain)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Tac CrossChainLayer =========================================
    function _addTacCrossChainLeafs(ManageLeaf[] memory leafs, ERC20 tokenToBridge, string memory tvmAddress) internal {
        //approve CCL
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(tokenToBridge),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve USDT to be spent by CrossChainLayer"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "crossChainLayer"),
            true,
            "sendMessage(uint256,bytes)",
            new address[](4),
            string.concat("Send message via CrossChainLayer"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = tvmTarget0; 
        leafs[leafIndex].argumentAddresses[1] = tvmTarget1; 
        leafs[leafIndex].argumentAddresses[2] = tvmTarget2; 
        leafs[leafIndex].argumentAddresses[3] = address(tokenToBridge);  
        
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "crossChainLayer"),
            false,
            "sendMessage(uint256,bytes)",
            new address[](4),
            string.concat("Send message via CrossChainLayer"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        leafs[leafIndex] = ManageLeaf(
            boringChef,
            false,
            "claimRewards(uint256[])",
            new address[](0),
            string.concat("Claim rewards from BoringChef"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    function _addBoringChefClaimOnBehalfOfLeaf(ManageLeaf[] memory leafs, address boringChef, address user) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            boringChef,
            false,
            "claimRewardsOnBehalfOfUser(uint256[],address)",
            new address[](1),
            string.concat("Claim rewards from BoringChef on behalf of user"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = user;
    }

    function _addBoringChefApproveRewardsLeafs(ManageLeaf[] memory leafs, address boringChef, address[] memory tokens)
        internal
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                tokens[i],
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve BoringChef to spend ", ERC20(tokens[i]).symbol(), " rewards owned by itself"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = boringChef;
        }
    }

    function _addBoringChefDistributeRewardsLeaf(ManageLeaf[] memory leafs, address boringChef, address[] memory tokens)
        internal
    {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            boringChef,
            false,
            "distributeRewards(address[],uint256[],uint48[],uint48[])",
            new address[](tokens.length),
            string.concat("Distribute rewards from BoringChef"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        for (uint256 i = 0; i < tokens.length; i++) {
            leafs[leafIndex].argumentAddresses[i] = tokens[i];
        }
    }

    // ========================================= dvStETH  =========================================
    function _addDvStETHLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "WETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Whitelisted Eth Wrapper to spend WETH"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "dvStethWhitelistedEthWrapper");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "dvStethWhitelistedEthWrapper"),
            false,
            "deposit(address,uint256,address,address,address)",
            new address[](4),
            string.concat("Deposit into dvStETH "),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "WSWELL"),
            false,
            "withdrawToByLockTimestamp(address,uint256,bool)",
            new address[](1),
            string.concat("Unwrap wSwell for Swell"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "WSWELL"),
            false,
            "withdrawToByLockTimestamps(address,uint256[],bool)",
            new address[](1),
            string.concat("Unwrap wSwell for Swell with multiple lock timestamps"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    function _addrEULWrappingLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "rEUL"),
            false,
            "withdrawToByLockTimestamp(address,uint256,bool)",
            new address[](1),
            string.concat("Unwrap rEUL for EUL"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault"); 

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "rEUL"),
            false,
            "withdrawToByLockTimestamps(address,uint256[],bool)",
            new address[](1),
            string.concat("Unwrap rEUL for EUL with multiple lock timestamps"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault"); 
    }

    // ========================================= StakeStone =========================================

    function _addStoneLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "stoneVault"),
            true,
            "deposit()",
            new address[](0),
            string.concat("Deposit Native ETH to STONE"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "stoneVault"),
            false,
            "instantWithdraw(uint256,uint256)",
            new address[](0),
            string.concat("Instant withdraw Native ETH from STONE"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "STONE"),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve StoneVault to spend STONE for requestWithdraw"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "stoneVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "stoneVault"),
            false,
            "requestWithdraw(uint256)",
            new address[](0),
            string.concat("Request Withdraw Native ETH from STONE"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "stoneVault"),
            false,
            "cancelWithdraw(uint256)",
            new address[](0),
            string.concat("Cancel ETH withdraw request from STONE"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    function _addUltraYieldLeafs(ManageLeaf[] memory leafs, address vault) internal {
        _addERC4626Leafs(leafs, ERC4626(vault));
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "deposit(uint256)",
            new address[](0),
            string.concat("Deposit to UltraYield Vault ", ERC20(vault).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "withdraw(uint256)",
            new address[](0),
            string.concat("Withdraw from UltraYield Vault ", ERC20(vault).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "mint(uint256)",
            new address[](0),
            string.concat("Redeem from UltraYield Vault ", ERC20(vault).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "redeem(uint256)",
            new address[](0),
            string.concat("Redeem from UltraYield Vault ", ERC20(vault).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve UltraYield Vault ", ERC20(vault).symbol(), " to spend", ERC20(vault).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = vault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "requestRedeem(uint256)",
            new address[](0),
            string.concat("Request redeem from UltraYield Vault ", ERC20(vault).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    function _addrFLRLeafs(ManageLeaf[] memory leafs, address rFLR) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            rFLR,
            false,
            "claimRewards(uint256[],uint256)",
            new address[](0),
            string.concat("Claim rewards from rFLR"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            rFLR,
            false,
            "withdraw(uint128,bool)",
            new address[](0),
            string.concat("Withdraw FLR/WFLR from rFLR"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            rFLR,
            false,
            "withdrawAll(bool)",
            new address[](0),
            string.concat("Claim All FLR/WFLR from rFLR"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Yearn V3 =========================================
    /// @notice uses the spectra decoder for these functions 
    function _addYearnLeafs(ManageLeaf[] memory leafs, ERC4626 vault) internal {
        _addERC4626Leafs(leafs, vault); 
        
        ERC20 asset = ERC20(vault.asset()); 

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "redeem(uint256,address,address,uint256)",
            new address[](2),
            string.concat("Redeem ", vault.name(), " for ", asset.symbol(), " with slippage check"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "withdraw(uint256,address,address,uint256)",
            new address[](2),
            string.concat("Withdraw ", asset.symbol(), " from ", vault.name(), " with slippage check"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
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
            leafs[leafIndex] = ManageLeaf(
                poolTokens[i],
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve STEXAMM to spend ", ERC20(poolTokens[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = pool; 
        }
        
        require(poolTokens.length == 2, "pool tokens length > 2, leaves need fixing");  
    
        if (!isUniversalPool) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                pool,
                false,
                "swap((bool,bool,uint256,uint256,uint256,address,address,(bytes,bytes,bytes,bytes)))",
                new address[](2),
                string.concat("Swap ", ERC20(poolTokens[0]).symbol(), " for ", ERC20(poolTokens[1]).symbol(), "using Valantis Pool"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault"); 
            leafs[leafIndex].argumentAddresses[1] = poolTokens[1]; 

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                pool,
                false,
                "swap((bool,bool,uint256,uint256,uint256,address,address,(bytes,bytes,bytes,bytes)))",
                new address[](2),
                string.concat("Swap ", ERC20(poolTokens[1]).symbol(), " for ", ERC20(poolTokens[0]).symbol(), "using Valantis Pool"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
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
                if (
                    keccak256(returndata)
                        == keccak256(
                            abi.encodePacked(
                                BaseDecoderAndSanitizer.BaseDecoderAndSanitizer__FunctionSelectorNotSupported.selector
                            )
                        )
                ) {
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
            merkleTreeOut[merkleTreeIn_length][count] =
                _hashPair(merkleTreeIn[merkleTreeIn_length - 1][i], merkleTreeIn[merkleTreeIn_length - 1][i + 1]);
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
                    proof[i] = j % 2 == 0 ? tree[i][j + 1] : tree[i][j - 1];
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
