// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ChainValues} from "test/resources/ChainValues.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";

// Import decoders and sanitizers
import {AaveV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV3DecoderAndSanitizer.sol";
import {AuraDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AuraDecoderAndSanitizer.sol";
import {BalancerV2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BalancerV2DecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {AmbientDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AmbientDecoderAndSanitizer.sol";
import {ArbitrumNativeBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ArbitrumNativeBridgeDecoderAndSanitizer.sol";
import {BalancerV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BalancerV3DecoderAndSanitizer.sol";
import {BeraETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BeraETHDecoderAndSanitizer.sol";
import {BeraborrowDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BeraborrowDecoderAndSanitizer.sol";
import {BGTRewardVaultDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/BGTRewardVaultDecoderAndSanitizer.sol";
import {BoringChefDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BoringChefDecoderAndSanitizer.sol";
import {BTCNMinterDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BTCNMinterDecoderAndSanitizer.sol";
import {CCIPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCIPDecoderAndSanitizer.sol";
import {CompoundV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CompoundV3DecoderAndSanitizer.sol";
import {ConvexDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ConvexDecoderAndSanitizer.sol";
import {CornStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/CornStakingDecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol";
import {DeriveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DeriveDecoderAndSanitizer.sol";
import {DeriveWithdrawDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DeriveWithdrawDecoderAndSanitizer.sol";
import {EigenLayerLSTStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/EigenLayerLSTStakingDecoderAndSanitizer.sol";
import {ElixirClaimingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ElixirClaimingDecoderAndSanitizer.sol";
import {EthenaWithdrawDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/EthenaWithdrawDecoderAndSanitizer.sol";
import {EtherFiDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EtherFiDecoderAndSanitizer.sol";
import {EulerEVKDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EulerEVKDecoderAndSanitizer.sol";
import {FluidDexDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/FluidDexDecoderAndSanitizer.sol";
import {FluidFTokenDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/FluidFTokenDecoderAndSanitizer.sol";
import {FluidRewardsClaimingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/FluidRewardsClaimingDecoderAndSanitizer.sol";
import {FraxDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/FraxDecoderAndSanitizer.sol";
import {GearboxDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/GearboxDecoderAndSanitizer.sol";
import {GoldiVaultDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/GoldiVaultDecoderAndSanitizer.sol";
import {HoneyDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/HoneyDecoderAndSanitizer.sol";
import {HyperlaneDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/HyperlaneDecoderAndSanitizer.sol";
import {InfraredDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/InfraredDecoderAndSanitizer.sol";
import {KarakDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/KarakDecoderAndSanitizer.sol";
import {KingClaimingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/KingClaimingDecoderAndSanitizer.sol";
import {KodiakIslandDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/KodiakIslandDecoderAndSanitizer.sol";
import {LBTCBridgeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LBTCBridgeDecoderAndSanitizer.sol";
import {LevelDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LevelDecoderAndSanitizer.sol";
import {LidoDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LidoDecoderAndSanitizer.sol";
import {LidoStandardBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/LidoStandardBridgeDecoderAndSanitizer.sol";
import {LineaBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/LineaBridgeDecoderAndSanitizer.sol";
import {LombardBTCMinterDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/LombardBtcMinterDecoderAndSanitizer.sol";
import {MantleDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MantleDecoderAndSanitizer.sol";
import {MantleStandardBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/MantleStandardBridgeDecoderAndSanitizer.sol";
import {MerklDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MerklDecoderAndSanitizer.sol";
import {MorphoBlueDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MorphoBlueDecoderAndSanitizer.sol";
import {MorphoRewardsMerkleClaimerDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/MorphoRewardsMerkleClaimerDecoderAndSanitizer.sol";
import {MorphoRewardsWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/MorphoRewardsWrapperDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {OogaBoogaDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OogaBoogaDecoderAndSanitizer.sol";
import {PendleRouterDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/PendleRouterDecoderAndSanitizer.sol";
import {Permit2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/Permit2DecoderAndSanitizer.sol";
import {PumpStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/PumpStakingDecoderAndSanitizer.sol";
import {ResolvDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ResolvDecoderAndSanitizer.sol";
import {SatlayerStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SatlayerStakingDecoderAndSanitizer.sol";
import {ScrollBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ScrollBridgeDecoderAndSanitizer.sol";
import {SiloDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SiloDecoderAndSanitizer.sol";
import {SkyMoneyDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SkyMoneyDecoderAndSanitizer.sol";
import {SonicDepositDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SonicDepositDecoderAndSanitizer.sol";
import {SonicGatewayDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SonicGatewayDecoderAndSanitizer.sol";
import {SpectraDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SpectraDecoderAndSanitizer.sol";
import {StandardBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/StandardBridgeDecoderAndSanitizer.sol";
import {SwellDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SwellDecoderAndSanitizer.sol";
import {SwellSimpleStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SwellSimpleStakingDecoderAndSanitizer.sol";
import {SymbioticDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SymbioticDecoderAndSanitizer.sol";
import {SymbioticVaultDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SymbioticVaultDecoderAndSanitizer.sol";
import {SyrupDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SyrupDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {TreehouseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TreehouseDecoderAndSanitizer.sol";
import {UniswapV2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV2DecoderAndSanitizer.sol";
import {UsualMoneyDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UsualMoneyDecoderAndSanitizer.sol";
import {WeETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/WeEthDecoderAndSanitizer.sol";
import {WithdrawQueueDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/WithdrawQueueDecoderAndSanitizer.sol";
import {ZircuitSimpleStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ZircuitSimpleStakingDecoderAndSanitizer.sol";
import {TermFinanceDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/TermFinanceDecoderAndSanitizer.sol";
import {ITBBasePositionDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ITB/ITBBasePositionDecoderAndSanitizer.sol";
import {ITBAaveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ITB/aave/AaveDecoderAndSanitizer.sol";
import {ITBCorkDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ITB/cork/CorkDecoderAndSanitizer.sol";
import {ITBCurveAndConvexNoConfigDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ITB/curve_and_convex/CurveAndConvexNoConfigDecoderAndSanitizer.sol";
import {ITBEigenLayerDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ITB/eigen_layer/EigenLayerDecoderAndSanitizer.sol";
import {ITBGearboxDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ITB/gearbox/GearboxDecoderAndSanitizer.sol";
import {ITBKarakDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ITB/karak/KarakDecoderAndSanitizer.sol";
import {ITBReserveDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ITB/reserve/ReserveDecoderAndSanitizer.sol";
import {ITBReserveERC20WrappedDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ITB/reserve/ReserveERC20WrappedDecoderAndSanitizer.sol";
import {ITBSyrupDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ITB/syrup/SyrupDecoderAndSanitizer.sol";
import {UltraYieldDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UltraYieldDecoderAndSanitizer.sol";
import {CCTPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCTPDecoderAndSanitizer.sol";
import {CompoundV2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CompoundV2DecoderAndSanitizer.sol";
import {AvalancheBridgeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AvalancheBridgeDecoderAndSanitizer.sol";
import {rFLRDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/rFLRDecoderAndSanitizer.sol";
import {AgglayerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AgglayerDecoderAndSanitizer.sol";
import {wSwellUnwrappingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/wSwellUnwrappingDecoderAndSanitizer.sol";
import {StakeStoneDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/StakeStoneDecoderAndSanitizer.sol";
import {TacCrossChainLayerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TacCrossChainLayerDecoderAndSanitizer.sol";
import {KinetiqDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/KinetiqDecoderAndSanitizer.sol";
import {KHypeHyperEVMDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/KHypeHyperEVMDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  forge script script/DeployDecodersAndSanitizersWithNoConstructorArgs.s.sol:DeployDecodersAndSanitizersWithNoConstructorArgsScript --broadcast --verify --with-gas-price 30000000000
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployDecodersAndSanitizersWithNoConstructorArgsScript is
    Script,
    ContractNames,
    MainnetAddresses,
    MerkleTreeHelper
{
    uint256 public privateKey;
    Deployer public deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d);

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
        setSourceChainName("mainnet");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        creationCode = type(AaveV3DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Aave V3 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy AuraDecoderAndSanitizer
        creationCode = type(AuraDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Aura Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0);

        // Deploy BalancerV2DecoderAndSanitizer
        creationCode = type(BalancerV2DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Balancer V2 Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0);

        // Deploy ERC4626DecoderAndSanitizer
        creationCode = type(ERC4626DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("ERC4626 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy AmbientDecoderAndSanitizer
        creationCode = type(AmbientDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Ambient Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy ArbitrumNativeBridgeDecoderAndSanitizer
        creationCode = type(ArbitrumNativeBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Arbitrum Native Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy BalancerV3DecoderAndSanitizer
        creationCode = type(BalancerV3DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Balancer V3 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy BeraETHDecoderAndSanitizer
        creationCode = type(BeraETHDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Bera ETH Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy BeraborrowDecoderAndSanitizer
        creationCode = type(BeraborrowDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Beraborrow Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy BGTRewardVaultDecoderAndSanitizer
        creationCode = type(BGTRewardVaultDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("BGT Reward Vault Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy BoringChefDecoderAndSanitizer
        creationCode = type(BoringChefDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Boring Chef Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy BTCNMinterDecoderAndSanitizer
        creationCode = type(BTCNMinterDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("BTCN Minter Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy CCIPDecoderAndSanitizer
        creationCode = type(CCIPDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("CCIP Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy CompoundV3DecoderAndSanitizer
        creationCode = type(CompoundV3DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Compound V3 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy ConvexDecoderAndSanitizer
        creationCode = type(ConvexDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Convex Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy CornStakingDecoderAndSanitizer
        creationCode = type(CornStakingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Corn Staking Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy CurveDecoderAndSanitizer
        creationCode = type(CurveDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Curve Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy EigenLayerLSTStakingDecoderAndSanitizer
        creationCode = type(EigenLayerLSTStakingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Eigen Layer LST Staking Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy ElixirClaimingDecoderAndSanitizer
        creationCode = type(ElixirClaimingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Elixir Claiming Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy EthenaWithdrawDecoderAndSanitizer
        creationCode = type(EthenaWithdrawDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Ethena Withdraw Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy EtherFiDecoderAndSanitizer
        creationCode = type(EtherFiDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Ether Fi Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy EulerEVKDecoderAndSanitizer
        creationCode = type(EulerEVKDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Euler EVK Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy FluidDexDecoderAndSanitizer
        creationCode = type(FluidDexDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Fluid Dex Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy FluidFTokenDecoderAndSanitizer
        creationCode = type(FluidFTokenDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Fluid F Token Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy FluidRewardsClaimingDecoderAndSanitizer
        creationCode = type(FluidRewardsClaimingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Fluid Rewards Claiming Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy FraxDecoderAndSanitizer
        creationCode = type(FraxDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Frax Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy GearboxDecoderAndSanitizer
        creationCode = type(GearboxDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Gearbox Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy GoldiVaultDecoderAndSanitizer
        creationCode = type(GoldiVaultDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Goldi Vault Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy HoneyDecoderAndSanitizer
        creationCode = type(HoneyDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Honey Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy HyperlaneDecoderAndSanitizer
        creationCode = type(HyperlaneDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Hyperlane Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0);

        // Deploy InfraredDecoderAndSanitizer
        creationCode = type(InfraredDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Infrared Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy KarakDecoderAndSanitizer
        creationCode = type(KarakDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Karak Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy KingClaimingDecoderAndSanitizer
        creationCode = type(KingClaimingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("King Claiming Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy KodiakIslandDecoderAndSanitizer
        creationCode = type(KodiakIslandDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Kodiak Island Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy LBTCBridgeDecoderAndSanitizer
        creationCode = type(LBTCBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("LBTC Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy LevelDecoderAndSanitizer
        creationCode = type(LevelDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Level Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy LidoDecoderAndSanitizer
        creationCode = type(LidoDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Lido Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy LidoStandardBridgeDecoderAndSanitizer
        creationCode = type(LidoStandardBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Lido Standard Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy LineaBridgeDecoderAndSanitizer
        creationCode = type(LineaBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Linea Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy LombardBTCMinterDecoderAndSanitizer
        creationCode = type(LombardBTCMinterDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Lombard Btc Minter Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy MantleDecoderAndSanitizer
        creationCode = type(MantleDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Mantle Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy MantleStandardBridgeDecoderAndSanitizer
        creationCode = type(MantleStandardBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Mantle Standard Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy MerklDecoderAndSanitizer
        creationCode = type(MerklDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Merkl Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy MorphoBlueDecoderAndSanitizer
        creationCode = type(MorphoBlueDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Morpho Blue Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy MorphoRewardsMerkleClaimerDecoderAndSanitizer
        creationCode = type(MorphoRewardsMerkleClaimerDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Morpho Rewards Merkle Claimer Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy MorphoRewardsWrapperDecoderAndSanitizer
        creationCode = type(MorphoRewardsWrapperDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Morpho Rewards Wrapper Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy NativeWrapperDecoderAndSanitizer
        creationCode = type(NativeWrapperDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Native Wrapper Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy OFTDecoderAndSanitizer
        creationCode = type(OFTDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("OFT Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy OneInchDecoderAndSanitizer
        creationCode = type(OneInchDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("One Inch Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy OogaBoogaDecoderAndSanitizer
        creationCode = type(OogaBoogaDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Ooga Booga Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy PendleRouterDecoderAndSanitizer
        creationCode = type(PendleRouterDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Pendle Router Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy Permit2DecoderAndSanitizer
        creationCode = type(Permit2DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Permit2 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy PumpStakingDecoderAndSanitizer
        creationCode = type(PumpStakingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Pump Staking Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy ResolvDecoderAndSanitizer
        creationCode = type(ResolvDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Resolv Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SatlayerStakingDecoderAndSanitizer
        creationCode = type(SatlayerStakingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Satlayer Staking Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy ScrollBridgeDecoderAndSanitizer
        creationCode = type(ScrollBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Scroll Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SiloDecoderAndSanitizer
        creationCode = type(SiloDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Silo Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SkyMoneyDecoderAndSanitizer
        creationCode = type(SkyMoneyDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Sky Money Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SonicDepositDecoderAndSanitizer
        creationCode = type(SonicDepositDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Sonic Deposit Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SonicGatewayDecoderAndSanitizer
        creationCode = type(SonicGatewayDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Sonic Gateway Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SpectraDecoderAndSanitizer
        creationCode = type(SpectraDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Spectra Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy StandardBridgeDecoderAndSanitizer
        creationCode = type(StandardBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Standard Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SwellDecoderAndSanitizer
        creationCode = type(SwellDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Swell Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SwellSimpleStakingDecoderAndSanitizer
        creationCode = type(SwellSimpleStakingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Swell Simple Staking Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SymbioticDecoderAndSanitizer
        creationCode = type(SymbioticDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Symbiotic Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SymbioticVaultDecoderAndSanitizer
        creationCode = type(SymbioticVaultDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Symbiotic Vault Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SyrupDecoderAndSanitizer
        creationCode = type(SyrupDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Syrup Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy TellerDecoderAndSanitizer
        creationCode = type(TellerDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Teller Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy TreehouseDecoderAndSanitizer
        creationCode = type(TreehouseDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Treehouse Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy UniswapV2DecoderAndSanitizer
        creationCode = type(UniswapV2DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Uniswap V2 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy UsualMoneyDecoderAndSanitizer
        creationCode = type(UsualMoneyDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Usual Money Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy WithdrawQueueDecoderAndSanitizer
        creationCode = type(WithdrawQueueDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Withdraw Queue Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy ZircuitSimpleStakingDecoderAndSanitizer
        creationCode = type(ZircuitSimpleStakingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Zircuit Simple Staking Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy WeETHDecoderAndSanitizer
        creationCode = type(WeETHDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("We Eth Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy TermFinanceDecoderAndSanitizer
        creationCode = type(TermFinanceDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Term Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        creationCode = type(UltraYieldDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Ultra Yield Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        creationCode = type(CCTPDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("CCTP Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        creationCode = type(CompoundV2DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Compound V2 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        creationCode = type(AvalancheBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Avalanche Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        creationCode = type(rFLRDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("rFLR Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        creationCode = type(DeriveDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Derive Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0);

        creationCode = type(DeriveWithdrawDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Derive Withdraw Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        creationCode = type(AgglayerDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Agglayer Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        creationCode = type(wSwellUnwrappingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("wSwell Unwrapping Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        creationCode = type(StakeStoneDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Stake Stone Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        creationCode = type(TacCrossChainLayerDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Tac Cross Chain Layer Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        creationCode = type(ITBBasePositionDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("ITB Base Position Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        creationCode = type(ITBAaveDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("ITB Aave Decoder and Sanitizer V0.0", creationCode,constructorArgs, 0);

        creationCode = type(ITBCorkDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("ITB Cork Decoder and Sanitizer V0.0", creationCode,constructorArgs, 0);

        creationCode = type(ITBCurveAndConvexNoConfigDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("ITB Curve and Convex Decoder and Sanitizer V0.0", creationCode,constructorArgs, 0);

        creationCode = type(ITBEigenLayerDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("ITB Eigen Layer Decoder and Sanitizer V0.0", creationCode,constructorArgs, 0);

        creationCode = type(ITBGearboxDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("ITB Gearbox Decoder and Sanitizer V0.0", creationCode,constructorArgs, 0);

        creationCode = type(ITBKarakDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("ITB Karak Decoder and Sanitizer V0.0", creationCode,constructorArgs, 0);

        creationCode = type(ITBReserveDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("ITB Reserve Decoder and Sanitizer V0.0", creationCode,constructorArgs, 0);

        creationCode = type(ITBReserveERC20WrappedDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("ITB Reserve Wrapper Decoder and Sanitizer V0.0", creationCode,constructorArgs, 0);

        creationCode = type(ITBSyrupDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("ITB Syrup Decoder and Sanitizer V0.0", creationCode,constructorArgs, 0);

        creationCode = type(KinetiqDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Kinetiq Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        creationCode = type(KHypeHyperEVMDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode();
        deployContract("KHype HyperEVM Decoder And Sanitizer V0.2", creationCode, constructorArgs, 0);

        creationCode = type(BaseDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployContract("Base Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }

    function deployContract(string memory name, bytes memory creationCode, bytes memory constructorArgs, uint256 value) internal {
        if (constructorArgs.length > 0) {
            revert("pls use the other script for constructor args");
        }

        address _contract = deployer.getAddress(name);
        if (_contract.code.length > 0) {
            console.log(name, "already deployed at", _contract);
            return;
        }

        address deployed = deployer.deployContract(name, creationCode, constructorArgs, value);
        console.log(unicode"✅", name, "deployed to", deployed);
    }
}
