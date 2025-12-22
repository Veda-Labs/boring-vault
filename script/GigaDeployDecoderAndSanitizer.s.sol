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
import {
    BalancerV2DecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/BalancerV2DecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {AmbientDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AmbientDecoderAndSanitizer.sol";
import {
    ArbitrumNativeBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/ArbitrumNativeBridgeDecoderAndSanitizer.sol";
import {
    BalancerV3DecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/BalancerV3DecoderAndSanitizer.sol";
import {BeraETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BeraETHDecoderAndSanitizer.sol";
import {
    BeraborrowDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/BeraborrowDecoderAndSanitizer.sol";
import {
    BGTRewardVaultDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/BGTRewardVaultDecoderAndSanitizer.sol";
import {
    BoringChefDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/BoringChefDecoderAndSanitizer.sol";
import {
    BTCNMinterDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/BTCNMinterDecoderAndSanitizer.sol";
import {CamelotDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CamelotDecoderAndSanitizer.sol";
import {CCIPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCIPDecoderAndSanitizer.sol";
import {
    CompoundV3DecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/CompoundV3DecoderAndSanitizer.sol";
import {ConvexDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ConvexDecoderAndSanitizer.sol";
import {ConvexFXDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ConvexFXDecoderAndSanitizer.sol";
import {
    CornStakingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/CornStakingDecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol";
import {
    DeriveDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/DeriveWithdrawDecoderAndSanitizer.sol";
import {DolomiteDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DolomiteDecoderAndSanitizer.sol";
import {DvStETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DvStETHDecoderAndSanitizer.sol";
import {
    EigenLayerLSTStakingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/EigenLayerLSTStakingDecoderAndSanitizer.sol";
import {
    ElixirClaimingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/ElixirClaimingDecoderAndSanitizer.sol";
import {
    EthenaWithdrawDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/EthenaWithdrawDecoderAndSanitizer.sol";
import {EtherFiDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EtherFiDecoderAndSanitizer.sol";
import {EulerEVKDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EulerEVKDecoderAndSanitizer.sol";
import {FluidDexDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/FluidDexDecoderAndSanitizer.sol";
import {
    FluidFTokenDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/FluidFTokenDecoderAndSanitizer.sol";
import {
    FluidRewardsClaimingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/FluidRewardsClaimingDecoderAndSanitizer.sol";
import {FraxDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/FraxDecoderAndSanitizer.sol";
import {GearboxDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/GearboxDecoderAndSanitizer.sol";
import {
    GoldiVaultDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/GoldiVaultDecoderAndSanitizer.sol";
import {HoneyDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/HoneyDecoderAndSanitizer.sol";
import {HyperlaneDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/HyperlaneDecoderAndSanitizer.sol";
import {InfraredDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/InfraredDecoderAndSanitizer.sol";
import {KarakDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/KarakDecoderAndSanitizer.sol";
import {
    KingClaimingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/KingClaimingDecoderAndSanitizer.sol";
import {
    KodiakIslandDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/KodiakIslandDecoderAndSanitizer.sol";
import {
    LBTCBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/LBTCBridgeDecoderAndSanitizer.sol";
import {LevelDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LevelDecoderAndSanitizer.sol";
import {LidoDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LidoDecoderAndSanitizer.sol";
import {
    LidoStandardBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/LidoStandardBridgeDecoderAndSanitizer.sol";
import {
    LineaBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/LineaBridgeDecoderAndSanitizer.sol";
// import {LombardBTCMinterDecoderAndSanitizer} from
//     "src/base/DecodersAndSanitizers/Protocols/LombardBTCMinterDecoderAndSanitizer.sol";
import {MantleDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MantleDecoderAndSanitizer.sol";
import {
    MantleStandardBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/MantleStandardBridgeDecoderAndSanitizer.sol";
import {MerklDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MerklDecoderAndSanitizer.sol";
import {
    MorphoBlueDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/MorphoBlueDecoderAndSanitizer.sol";
import {
    MorphoRewardsMerkleClaimerDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/MorphoRewardsMerkleClaimerDecoderAndSanitizer.sol";
import {
    MorphoRewardsWrapperDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/MorphoRewardsWrapperDecoderAndSanitizer.sol";
import {
    NativeWrapperDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {OogaBoogaDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OogaBoogaDecoderAndSanitizer.sol";
import {
    PancakeSwapV3DecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/PancakeSwapV3DecoderAndSanitizer.sol";
import {
    PendleRouterDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/PendleRouterDecoderAndSanitizer.sol";
import {Permit2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/Permit2DecoderAndSanitizer.sol";
import {
    PumpStakingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/PumpStakingDecoderAndSanitizer.sol";
import {ResolvDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ResolvDecoderAndSanitizer.sol";
import {RoycoWeirollDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/RoycoDecoderAndSanitizer.sol";
import {
    SatlayerStakingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/SatlayerStakingDecoderAndSanitizer.sol";
import {
    ScrollBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/ScrollBridgeDecoderAndSanitizer.sol";
import {SiloDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SiloDecoderAndSanitizer.sol";
import {SkyMoneyDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SkyMoneyDecoderAndSanitizer.sol";
import {
    SonicDepositDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/SonicDepositDecoderAndSanitizer.sol";
import {
    SonicGatewayDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/SonicGatewayDecoderAndSanitizer.sol";
import {SpectraDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SpectraDecoderAndSanitizer.sol";
import {
    StandardBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/StandardBridgeDecoderAndSanitizer.sol";
import {SwellDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SwellDecoderAndSanitizer.sol";
import {
    SwellSimpleStakingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/SwellSimpleStakingDecoderAndSanitizer.sol";
import {SymbioticDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SymbioticDecoderAndSanitizer.sol";
import {
    SymbioticVaultDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/SymbioticVaultDecoderAndSanitizer.sol";
import {SyrupDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SyrupDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {TreehouseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TreehouseDecoderAndSanitizer.sol";
import {UniswapV2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV2DecoderAndSanitizer.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {
    UniswapV3SwapRouter02DecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3SwapRouter02DecoderAndSanitizer.sol";
import {UniswapV4DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV4DecoderAndSanitizer.sol";
import {
    UsualMoneyDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/UsualMoneyDecoderAndSanitizer.sol";
import {VelodromeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/VelodromeDecoderAndSanitizer.sol";
import {WeETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/WeEthDecoderAndSanitizer.sol";
import {
    WithdrawQueueDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/WithdrawQueueDecoderAndSanitizer.sol";
import {
    ZircuitSimpleStakingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/ZircuitSimpleStakingDecoderAndSanitizer.sol";
import {
    TermFinanceDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/TermFinanceDecoderAndSanitizer.sol";
// import {ITBBasePositionDecoderAndSanitizer} from
//     "src/base/DecodersAndSanitizers/Protocols/ITB/ITBBasePositionDecoderAndSanitizer.sol";
// import {ITBAaveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ITB/ITBAaveDecoderAndSanitizer.sol";
// import {ITBCorkDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ITB/ITBCorkDecoderAndSanitizer.sol";
// import {ITBCurveAndConvexDecoderAndSanitizer} from
//     "src/base/DecodersAndSanitizers/Protocols/ITB/ITBCurveAndConvexDecoderAndSanitizer.sol";
// import {ITBEigenLayerDecoderAndSanitizer} from
//     "src/base/DecodersAndSanitizers/Protocols/ITB/ITBEigenLayerDecoderAndSanitizer.sol";
// import {ITBGearboxDecoderAndSanitizer} from
//     "src/base/DecodersAndSanitizers/Protocols/ITB/ITBGearboxDecoderAndSanitizer.sol";
// import {ITBKarakDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ITB/ITBKarakDecoderAndSanitizer.sol";
// import {ITBReserveDecoderAndSanitizer} from
//     "src/base/DecodersAndSanitizers/Protocols/ITB/ITBReserveDecoderAndSanitizer.sol";
// import {ITBReserveWrapperDecoderAndSanitizer} from
//     "src/base/DecodersAndSanitizers/Protocols/ITB/ITBReserveWrapperDecoderAndSanitizer.sol";
// import {ITBSyrupDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ITB/ITBSyrupDecoderAndSanitizer.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  forge script script/GigaDeployDecoderAndSanitizer.s.sol:GigaDeployDecoderAndSanitizerScript --broadcast --verify --with-gas-price 30000000000
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract GigaDeployDecoderAndSanitizerScript is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
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
        deployer.deployContract("Aave V3 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy AuraDecoderAndSanitizer
        creationCode = type(AuraDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Aura Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy BalancerV2DecoderAndSanitizer
        creationCode = type(BalancerV2DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Balancer V2 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy ERC4626DecoderAndSanitizer
        // Already deployed
        // creationCode = type(ERC4626DecoderAndSanitizer).creationCode;
        // constructorArgs = hex"";
        // deployer.deployContract("ERC4626 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy AmbientDecoderAndSanitizer
        creationCode = type(AmbientDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Ambient Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy ArbitrumNativeBridgeDecoderAndSanitizer
        creationCode = type(ArbitrumNativeBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Arbitrum Native Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy BalancerV3DecoderAndSanitizer
        creationCode = type(BalancerV3DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Balancer V3 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy BeraETHDecoderAndSanitizer
        creationCode = type(BeraETHDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Bera ETH Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy BeraborrowDecoderAndSanitizer
        creationCode = type(BeraborrowDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Beraborrow Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy BGTRewardVaultDecoderAndSanitizer
        creationCode = type(BGTRewardVaultDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("BGT Reward Vault Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy BoringChefDecoderAndSanitizer
        creationCode = type(BoringChefDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Boring Chef Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy BTCNMinterDecoderAndSanitizer
        creationCode = type(BTCNMinterDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("BTCN Minter Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy CamelotDecoderAndSanitizer
        // TODO constructor args
        // creationCode = type(CamelotDecoderAndSanitizer).creationCode;
        // constructorArgs = hex"";
        // deployer.deployContract("Camelot Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy CCIPDecoderAndSanitizer
        creationCode = type(CCIPDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("CCIP Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy CompoundV3DecoderAndSanitizer
        creationCode = type(CompoundV3DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Compound V3 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy ConvexDecoderAndSanitizer
        creationCode = type(ConvexDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Convex Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy ConvexFXDecoderAndSanitizer
        // TODO contstructor args
        // creationCode = type(ConvexFXDecoderAndSanitizer).creationCode;
        // constructorArgs = hex"";
        // deployer.deployContract("Convex FX Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy CornStakingDecoderAndSanitizer
        creationCode = type(CornStakingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Corn Staking Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy CurveDecoderAndSanitizer
        creationCode = type(CurveDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Curve Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy DeriveDecoderAndSanitizer
        // TODO constructor args
        // creationCode = type(DeriveDecoderAndSanitizer).creationCode;
        // constructorArgs = hex"";
        // deployer.deployContract("Derive Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy DolomiteDecoderAndSanitizer
        // TODO constructor args
        // creationCode = type(DolomiteDecoderAndSanitizer).creationCode;
        // constructorArgs = hex"";
        // deployer.deployContract("Dolomite Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy DvStETHDecoderAndSanitizer
        // TODO constructor args
        // creationCode = type(DvStETHDecoderAndSanitizer).creationCode;
        // constructorArgs = hex"";
        // deployer.deployContract("Dv St ETH Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy EigenLayerLSTStakingDecoderAndSanitizer
        creationCode = type(EigenLayerLSTStakingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Eigen Layer LST Staking Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy ElixirClaimingDecoderAndSanitizer
        creationCode = type(ElixirClaimingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Elixir Claiming Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy EthenaWithdrawDecoderAndSanitizer
        creationCode = type(EthenaWithdrawDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Ethena Withdraw Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy EtherFiDecoderAndSanitizer
        creationCode = type(EtherFiDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Ether Fi Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy EulerEVKDecoderAndSanitizer
        creationCode = type(EulerEVKDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Euler EVK Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy FluidDexDecoderAndSanitizer
        creationCode = type(FluidDexDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Fluid Dex Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy FluidFTokenDecoderAndSanitizer
        creationCode = type(FluidFTokenDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Fluid F Token Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy FluidRewardsClaimingDecoderAndSanitizer
        creationCode = type(FluidRewardsClaimingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Fluid Rewards Claiming Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy FraxDecoderAndSanitizer
        creationCode = type(FraxDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Frax Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy GearboxDecoderAndSanitizer
        creationCode = type(GearboxDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Gearbox Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy GoldiVaultDecoderAndSanitizer
        creationCode = type(GoldiVaultDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Goldi Vault Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy HoneyDecoderAndSanitizer
        creationCode = type(HoneyDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Honey Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy HyperlaneDecoderAndSanitizer
        creationCode = type(HyperlaneDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Hyperlane Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0);

        // Deploy InfraredDecoderAndSanitizer
        creationCode = type(InfraredDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Infrared Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy KarakDecoderAndSanitizer
        creationCode = type(KarakDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Karak Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy KingClaimingDecoderAndSanitizer
        creationCode = type(KingClaimingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("King Claiming Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy KodiakIslandDecoderAndSanitizer
        creationCode = type(KodiakIslandDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Kodiak Island Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy LBTCBridgeDecoderAndSanitizer
        creationCode = type(LBTCBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("LBTC Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy LevelDecoderAndSanitizer
        creationCode = type(LevelDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Level Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy LidoDecoderAndSanitizer
        creationCode = type(LidoDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Lido Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy LidoStandardBridgeDecoderAndSanitizer
        creationCode = type(LidoStandardBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Lido Standard Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy LineaBridgeDecoderAndSanitizer
        creationCode = type(LineaBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Linea Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy LombardBTCMinterDecoderAndSanitizer
        // creationCode = type(LombardBTCMinterDecoderAndSanitizer).creationCode;
        // constructorArgs = hex"";
        // deployer.deployContract("Lombard Btc Minter Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy MantleDecoderAndSanitizer
        creationCode = type(MantleDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Mantle Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy MantleStandardBridgeDecoderAndSanitizer
        creationCode = type(MantleStandardBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Mantle Standard Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy MerklDecoderAndSanitizer
        creationCode = type(MerklDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Merkl Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy MorphoBlueDecoderAndSanitizer
        creationCode = type(MorphoBlueDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Morpho Blue Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy MorphoRewardsMerkleClaimerDecoderAndSanitizer
        creationCode = type(MorphoRewardsMerkleClaimerDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract(
            "Morpho Rewards Merkle Claimer Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0
        );

        // Deploy MorphoRewardsWrapperDecoderAndSanitizer
        creationCode = type(MorphoRewardsWrapperDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Morpho Rewards Wrapper Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy NativeWrapperDecoderAndSanitizer
        creationCode = type(NativeWrapperDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Native Wrapper Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy OdosDecoderAndSanitizer
        // TODO constructor args
        // creationCode = type(OdosDecoderAndSanitizer).creationCode;
        // constructorArgs = hex"";
        // deployer.deployContract("Odos Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy OFTDecoderAndSanitizer
        creationCode = type(OFTDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("OFT Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy OneInchDecoderAndSanitizer
        creationCode = type(OneInchDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("One Inch Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy OogaBoogaDecoderAndSanitizer
        creationCode = type(OogaBoogaDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Ooga Booga Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy PancakeSwapV3DecoderAndSanitizer
        // TODO constructor args
        // creationCode = type(PancakeSwapV3DecoderAndSanitizer).creationCode;
        // constructorArgs = hex"";
        // deployer.deployContract("Pancake Swap V3 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy PendleRouterDecoderAndSanitizer
        creationCode = type(PendleRouterDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Pendle Router Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy Permit2DecoderAndSanitizer
        creationCode = type(Permit2DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Permit2 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy PumpStakingDecoderAndSanitizer
        creationCode = type(PumpStakingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Pump Staking Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy ResolvDecoderAndSanitizer
        creationCode = type(ResolvDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Resolv Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy RoycoWeirollDecoderAndSanitizer
        // TODO constructor args
        // creationCode = type(RoycoWeirollDecoderAndSanitizer).creationCode;
        // constructorArgs = hex"";
        // deployer.deployContract("Royco Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SatlayerStakingDecoderAndSanitizer
        creationCode = type(SatlayerStakingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Satlayer Staking Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy ScrollBridgeDecoderAndSanitizer
        creationCode = type(ScrollBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Scroll Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SiloDecoderAndSanitizer
        creationCode = type(SiloDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Silo Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SkyMoneyDecoderAndSanitizer
        creationCode = type(SkyMoneyDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Sky Money Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SonicDepositDecoderAndSanitizer
        creationCode = type(SonicDepositDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Sonic Deposit Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SonicGatewayDecoderAndSanitizer
        creationCode = type(SonicGatewayDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Sonic Gateway Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SpectraDecoderAndSanitizer
        creationCode = type(SpectraDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Spectra Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy StandardBridgeDecoderAndSanitizer
        creationCode = type(StandardBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Standard Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SwellDecoderAndSanitizer
        creationCode = type(SwellDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Swell Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SwellSimpleStakingDecoderAndSanitizer
        creationCode = type(SwellSimpleStakingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Swell Simple Staking Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SymbioticDecoderAndSanitizer
        creationCode = type(SymbioticDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Symbiotic Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SymbioticVaultDecoderAndSanitizer
        creationCode = type(SymbioticVaultDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Symbiotic Vault Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy SyrupDecoderAndSanitizer
        creationCode = type(SyrupDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Syrup Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy TellerDecoderAndSanitizer
        creationCode = type(TellerDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Teller Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy TreehouseDecoderAndSanitizer
        creationCode = type(TreehouseDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Treehouse Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy UniswapV2DecoderAndSanitizer
        creationCode = type(UniswapV2DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Uniswap V2 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy UniswapV3DecoderAndSanitizer
        // TODO constructor args
        // creationCode = type(UniswapV3DecoderAndSanitizer).creationCode;
        // constructorArgs = hex"";
        // deployer.deployContract("Uniswap V3 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy UniswapV3SwapRouter02DecoderAndSanitizer
        // TODO constructor args
        // creationCode = type(UniswapV3SwapRouter02DecoderAndSanitizer).creationCode;
        // constructorArgs = hex"";
        // deployer.deployContract("Uniswap V3 Swap Router02 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy UniswapV4DecoderAndSanitizer
        // TODO constructor args
        // creationCode = type(UniswapV4DecoderAndSanitizer).creationCode;
        // constructorArgs = hex"";
        // deployer.deployContract("Uniswap V4 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy UsualMoneyDecoderAndSanitizer
        creationCode = type(UsualMoneyDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Usual Money Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy VelodromeDecoderAndSanitizer
        // TODO constructor args
        // creationCode = type(VelodromeDecoderAndSanitizer).creationCode;
        // constructorArgs = hex"";
        // deployer.deployContract("Velodrome Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy WithdrawQueueDecoderAndSanitizer
        creationCode = type(WithdrawQueueDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Withdraw Queue Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy ZircuitSimpleStakingDecoderAndSanitizer
        creationCode = type(ZircuitSimpleStakingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Zircuit Simple Staking Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy WeETHDecoderAndSanitizer
        creationCode = type(WeETHDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("We Eth Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy TermFinanceDecoderAndSanitizer
        creationCode = type(TermFinanceDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        deployer.deployContract("Term Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }
}
