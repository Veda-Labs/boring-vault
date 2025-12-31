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
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {AaveV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV3DecoderAndSanitizer.sol";
import {AgglayerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AgglayerDecoderAndSanitizer.sol";
import {AlgebraV4DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AlgebraV4DecoderAndSanitizer.sol";
import {AmbientDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AmbientDecoderAndSanitizer.sol";
import {ArbitrumNativeBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ArbitrumNativeBridgeDecoderAndSanitizer.sol";
import {AtomicQueueDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AtomicQueueDecoderAndSanitizer.sol";
import {AuraDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AuraDecoderAndSanitizer.sol";
import {AvalancheBridgeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AvalancheBridgeDecoderAndSanitizer.sol";
import {BalancerV2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BalancerV2DecoderAndSanitizer.sol";
import {BalancerV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BalancerV3DecoderAndSanitizer.sol";
import {BeraborrowDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BeraborrowDecoderAndSanitizer.sol";
import {BeraETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BeraETHDecoderAndSanitizer.sol";
import {BGTRewardVaultDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/BGTRewardVaultDecoderAndSanitizer.sol";
import {BoringChefDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BoringChefDecoderAndSanitizer.sol";
import {BTCKDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BTCKDecoderAndSanitizer.sol";
import {BTCNMinterDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BTCNMinterDecoderAndSanitizer.sol";
import {CamelotDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CamelotDecoderAndSanitizer.sol";
import {CapDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CapDecoderAndSanitizer.sol";
import {CCIPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCIPDecoderAndSanitizer.sol";
import {CCTPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCTPDecoderAndSanitizer.sol";
import {CompoundV2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CompoundV2DecoderAndSanitizer.sol";
import {CompoundV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CompoundV3DecoderAndSanitizer.sol";
import {ConvexDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ConvexDecoderAndSanitizer.sol";
import {ConvexFXDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ConvexFXDecoderAndSanitizer.sol";
import {CornStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/CornStakingDecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol";
import {DeriveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DeriveDecoderAndSanitizer.sol";
import {DeriveWithdrawDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DeriveWithdrawDecoderAndSanitizer.sol";
import {DolomiteDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DolomiteDecoderAndSanitizer.sol";
import {DvStETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DvStETHDecoderAndSanitizer.sol";
import {EigenLayerLSTStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/EigenLayerLSTStakingDecoderAndSanitizer.sol";
import {ElixirClaimingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ElixirClaimingDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
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
import {GlueXDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/GlueXDecoderAndSanitizer.sol";
import {GoldiVaultDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/GoldiVaultDecoderAndSanitizer.sol";
import {HoneyDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/HoneyDecoderAndSanitizer.sol";
import {HyperlaneDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/HyperlaneDecoderAndSanitizer.sol";
import {InfraredDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/InfraredDecoderAndSanitizer.sol";
import {KarakDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/KarakDecoderAndSanitizer.sol";
import {KinetiqDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/KinetiqDecoderAndSanitizer.sol";
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
import {MFOneDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MFOneDecoderAndSanitizer.sol";
import {MorphoBlueDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MorphoBlueDecoderAndSanitizer.sol";
import {MorphoRewardsMerkleClaimerDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/MorphoRewardsMerkleClaimerDecoderAndSanitizer.sol";
import {MorphoRewardsWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/MorphoRewardsWrapperDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {OogaBoogaDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OogaBoogaDecoderAndSanitizer.sol";
import {PancakeSwapV3DecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/PancakeSwapV3DecoderAndSanitizer.sol";
import {PendleRouterDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/PendleRouterDecoderAndSanitizer.sol";
import {Permit2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/Permit2DecoderAndSanitizer.sol";
import {PumpStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/PumpStakingDecoderAndSanitizer.sol";
import {RedSnwapperDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/RedSnwapperDecoderAndSanitizer.sol";
import {ResolvDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ResolvDecoderAndSanitizer.sol";
import {rFLRDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/rFLRDecoderAndSanitizer.sol";
import {RoycoWeirollDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/RoycoDecoderAndSanitizer.sol";
import {SatlayerStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SatlayerStakingDecoderAndSanitizer.sol";
import {ScrollBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ScrollBridgeDecoderAndSanitizer.sol";
import {SiloDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SiloDecoderAndSanitizer.sol";
import {SiloVaultDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SiloVaultDecoderAndSanitizer.sol";
import {SkyMoneyDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SkyMoneyDecoderAndSanitizer.sol";
import {SonicDepositDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SonicDepositDecoderAndSanitizer.sol";
import {SonicGatewayDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SonicGatewayDecoderAndSanitizer.sol";
import {SpectraDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SpectraDecoderAndSanitizer.sol";
import {StakeStoneDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/StakeStoneDecoderAndSanitizer.sol";
import {StandardBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/StandardBridgeDecoderAndSanitizer.sol";
import {SwellDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SwellDecoderAndSanitizer.sol";
import {SwellSimpleStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SwellSimpleStakingDecoderAndSanitizer.sol";
import {SymbioticDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SymbioticDecoderAndSanitizer.sol";
import {SymbioticVaultDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SymbioticVaultDecoderAndSanitizer.sol";
import {SyrupDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SyrupDecoderAndSanitizer.sol";
import {TacCrossChainLayerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TacCrossChainLayerDecoderAndSanitizer.sol";
// import {TacProxyDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TacProxyDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {TermFinanceDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/TermFinanceDecoderAndSanitizer.sol";
import {TreehouseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TreehouseDecoderAndSanitizer.sol";
import {UltraYieldDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UltraYieldDecoderAndSanitizer.sol";
import {UniswapV2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV2DecoderAndSanitizer.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {UniswapV3SwapRouter02DecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/UniswapV3SwapRouter02DecoderAndSanitizer.sol";
import {UniswapV4DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV4DecoderAndSanitizer.sol";
import {UsualMoneyDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UsualMoneyDecoderAndSanitizer.sol";
import {ValantisDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ValantisDecoderAndSanitizer.sol";
import {VaultCraftDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/VaultCraftDecoderAndSanitizer.sol";
import {VelodromeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/VelodromeDecoderAndSanitizer.sol";
import {WeETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/WeEthDecoderAndSanitizer.sol";
import {WithdrawQueueDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/WithdrawQueueDecoderAndSanitizer.sol";
import {wSwellUnwrappingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/wSwellUnwrappingDecoderAndSanitizer.sol";
import {ZircuitSimpleStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ZircuitSimpleStakingDecoderAndSanitizer.sol";
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

    uint256 constant DESIRED_NUMBER_OF_DEPLOYMENT_TXS = 10;

    string[] addressKeys;

    Deployer.Tx[] internal txs;

    function getTxs() public view returns (Deployer.Tx[] memory) {
        return txs;
    }

    function _addTx(address target, bytes memory data, uint256 value) internal {
        txs.push(Deployer.Tx(target, data, value));
    }

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("plasma");
        setSourceChainName("plasma");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;

        creationCode = type(BaseDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        address _contract = deployContract("Base Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("BaseDecoderAndSanitizer", _contract);

        // Deploy AaveV3DecoderAndSanitizer
        creationCode = type(AaveV3DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Aave V3 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("AaveV3DecoderAndSanitizer", _contract);

        // Deploy AuraDecoderAndSanitizer
        creationCode = type(AuraDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Aura Decoder and Sanitizer V0.2", creationCode, constructorArgs, 0);
        // console.log("AuraDecoderAndSanitizer", _contract);

        // Deploy BalancerV2DecoderAndSanitizer
        creationCode = type(BalancerV2DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Balancer V2 Decoder and Sanitizer V0.2", creationCode, constructorArgs, 0);
        // console.log("BalancerV2DecoderAndSanitizer", _contract);

        // Deploy ERC4626DecoderAndSanitizer
        creationCode = type(ERC4626DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("ERC4626 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("ERC4626DecoderAndSanitizer", _contract);

        // Deploy AmbientDecoderAndSanitizer
        creationCode = type(AmbientDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Ambient Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("AmbientDecoderAndSanitizer", _contract);

        // Deploy ArbitrumNativeBridgeDecoderAndSanitizer
        creationCode = type(ArbitrumNativeBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Arbitrum Native Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("ArbitrumNativeBridgeDecoderAndSanitizer", _contract);

        // Deploy AtomicQueueDecoderAndSanitizer
        creationCode = type(AtomicQueueDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode(0.9e4, 1.1e4);
        _contract = deployContract("Atomic Queue Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("AtomicQueueDecoderAndSanitizer", _contract);

        // Deploy AgglayerDecoderAndSanitizer
        creationCode = type(AgglayerDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Agglayer Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("AgglayerDecoderAndSanitizer", _contract);

        // Deploy BalancerV3DecoderAndSanitizer
        creationCode = type(BalancerV3DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Balancer V3 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("BalancerV3DecoderAndSanitizer", _contract);

        // Deploy BeraETHDecoderAndSanitizer
        creationCode = type(BeraETHDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Bera ETH Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("BeraETHDecoderAndSanitizer", _contract);

        // Deploy BeraborrowDecoderAndSanitizer
        creationCode = type(BeraborrowDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Beraborrow Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("BeraborrowDecoderAndSanitizer", _contract);

        // Deploy BGTRewardVaultDecoderAndSanitizer
        creationCode = type(BGTRewardVaultDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("BGT Reward Vault Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("BGTRewardVaultDecoderAndSanitizer", _contract);

        // Deploy BoringChefDecoderAndSanitizer
        creationCode = type(BoringChefDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Boring Chef Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("BoringChefDecoderAndSanitizer", _contract);

        // Deploy BTCNMinterDecoderAndSanitizer
        creationCode = type(BTCNMinterDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("BTCN Minter Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("BTCNMinterDecoderAndSanitizer", _contract);

        // Deploy CamelotDecoderAndSanitizer
        creationCode = type(CamelotDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        addressKeys = ["camelotNonFungiblePositionManager"];
        _contract = deployContract("Camelot Decoder and Sanitizer V0.0", creationCode, 0);
        // console.log("CamelotDecoderAndSanitizer", _contract);

        // Deploy CapDecoderAndSanitizer
        creationCode = type(CapDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Cap Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0);
        // console.log("CapDecoderAndSanitizer", _contract);

        // Deploy CCIPDecoderAndSanitizer
        creationCode = type(CCIPDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("CCIP Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("CCIPDecoderAndSanitizer", _contract);

        // Deploy CompoundV3DecoderAndSanitizer
        creationCode = type(CompoundV3DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Compound V3 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("CompoundV3DecoderAndSanitizer", _contract);

        // Deploy ConvexDecoderAndSanitizer
        creationCode = type(ConvexDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Convex Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("ConvexDecoderAndSanitizer", _contract);

        // Deploy ConvexFXDecoderAndSanitizer
        creationCode = type(ConvexFXDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        addressKeys = ["convexFXPoolRegistry"];
        _contract = deployContract("Convex FX Decoder and Sanitizer V0.0", creationCode, 0);
        // console.log("ConvexFXDecoderAndSanitizer", _contract);

        // Deploy CornStakingDecoderAndSanitizer
        creationCode = type(CornStakingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Corn Staking Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("CornStakingDecoderAndSanitizer", _contract);

        // Deploy CurveDecoderAndSanitizer
        creationCode = type(CurveDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Curve Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("CurveDecoderAndSanitizer", _contract);

        // Deploy DeriveDecoderAndSanitizer
        creationCode = type(DeriveDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Derive Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0);
        // console.log("DeriveDecoderAndSanitizer", _contract);

        // Deploy DeriveWithdrawDecoderAndSanitizer
        creationCode = type(DeriveWithdrawDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Derive Withdraw Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("DeriveWithdrawDecoderAndSanitizer", _contract);

        // Deploy DolomiteDecoderAndSanitizer
        creationCode = type(DolomiteDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        addressKeys = ["dolomiteMargin"];
        _contract = deployContract("Dolomite Decoder and Sanitizer V0.0", creationCode, 0);
        // console.log("DolomiteDecoderAndSanitizer", _contract);

        // Deploy DvStETHDecoderAndSanitizer
        creationCode = type(DvStETHDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        addressKeys = ["dvStETHVault"];
        _contract = deployContract("Dv St ETH Decoder and Sanitizer V0.2", creationCode, 0);
        // console.log("DvStETHDecoderAndSanitizer", _contract);

        // Deploy EigenLayerLSTStakingDecoderAndSanitizer
        creationCode = type(EigenLayerLSTStakingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Eigen Layer LST Staking Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("EigenLayerLSTStakingDecoderAndSanitizer", _contract);

        // Deploy ElixirClaimingDecoderAndSanitizer
        creationCode = type(ElixirClaimingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Elixir Claiming Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("ElixirClaimingDecoderAndSanitizer", _contract);

        // Deploy EthenaWithdrawDecoderAndSanitizer
        creationCode = type(EthenaWithdrawDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Ethena Withdraw Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("EthenaWithdrawDecoderAndSanitizer", _contract);

        // Deploy EtherFiDecoderAndSanitizer
        creationCode = type(EtherFiDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Ether Fi Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0);
        // console.log("EtherFiDecoderAndSanitizer", _contract);

        // Deploy EulerEVKDecoderAndSanitizer
        creationCode = type(EulerEVKDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Euler EVK Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("EulerEVKDecoderAndSanitizer", _contract);

        // Deploy FluidDexDecoderAndSanitizer
        creationCode = type(FluidDexDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Fluid Dex Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0);
        // console.log("FluidDexDecoderAndSanitizer", _contract);

        // Deploy FluidFTokenDecoderAndSanitizer
        creationCode = type(FluidFTokenDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Fluid F Token Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("FluidFTokenDecoderAndSanitizer", _contract);

        // Deploy FluidRewardsClaimingDecoderAndSanitizer
        creationCode = type(FluidRewardsClaimingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Fluid Rewards Claiming Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("FluidRewardsClaimingDecoderAndSanitizer", _contract);

        // Deploy FraxDecoderAndSanitizer
        creationCode = type(FraxDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Frax Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("FraxDecoderAndSanitizer", _contract);

        // Deploy GearboxDecoderAndSanitizer
        creationCode = type(GearboxDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Gearbox Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("GearboxDecoderAndSanitizer", _contract);

        // Deploy GoldiVaultDecoderAndSanitizer
        creationCode = type(GoldiVaultDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Goldi Vault Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("GoldiVaultDecoderAndSanitizer", _contract);

        // Deploy HoneyDecoderAndSanitizer
        creationCode = type(HoneyDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Honey Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("HoneyDecoderAndSanitizer", _contract);

        // Deploy HyperlaneDecoderAndSanitizer
        creationCode = type(HyperlaneDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Hyperlane Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0);
        // console.log("HyperlaneDecoderAndSanitizer", _contract);

        // Deploy InfraredDecoderAndSanitizer
        creationCode = type(InfraredDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Infrared Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("InfraredDecoderAndSanitizer", _contract);

        // Deploy KarakDecoderAndSanitizer
        creationCode = type(KarakDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Karak Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("KarakDecoderAndSanitizer", _contract);

        // Deploy KingClaimingDecoderAndSanitizer
        creationCode = type(KingClaimingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("King Claiming Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("KingClaimingDecoderAndSanitizer", _contract);

        // Deploy KodiakIslandDecoderAndSanitizer
        creationCode = type(KodiakIslandDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Kodiak Island Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("KodiakIslandDecoderAndSanitizer", _contract);

        // Deploy LBTCBridgeDecoderAndSanitizer
        creationCode = type(LBTCBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("LBTC Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("LBTCBridgeDecoderAndSanitizer", _contract);

        // Deploy LevelDecoderAndSanitizer
        creationCode = type(LevelDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Level Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0);
        // console.log("LevelDecoderAndSanitizer", _contract);

        // Deploy LidoDecoderAndSanitizer
        creationCode = type(LidoDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Lido Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("LidoDecoderAndSanitizer", _contract);

        // Deploy LidoStandardBridgeDecoderAndSanitizer
        creationCode = type(LidoStandardBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Lido Standard Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("LidoStandardBridgeDecoderAndSanitizer", _contract);

        // Deploy LineaBridgeDecoderAndSanitizer
        creationCode = type(LineaBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Linea Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("LineaBridgeDecoderAndSanitizer", _contract);

        // Deploy LombardBTCMinterDecoderAndSanitizer
        creationCode = type(LombardBTCMinterDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Lombard Btc Minter Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("LombardBTCMinterDecoderAndSanitizer", _contract);

        // Deploy MantleDecoderAndSanitizer
        creationCode = type(MantleDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Mantle Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("MantleDecoderAndSanitizer", _contract);

        // Deploy MantleStandardBridgeDecoderAndSanitizer
        creationCode = type(MantleStandardBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Mantle Standard Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("MantleStandardBridgeDecoderAndSanitizer", _contract);

        // Deploy MerklDecoderAndSanitizer
        creationCode = type(MerklDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Merkl Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("MerklDecoderAndSanitizer", _contract);

        // Deploy MFOneDecoderAndSanitizer
        creationCode = type(MFOneDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("MF One Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("MFOneDecoderAndSanitizer", _contract);

        // Deploy MorphoBlueDecoderAndSanitizer
        creationCode = type(MorphoBlueDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Morpho Blue Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("MorphoBlueDecoderAndSanitizer", _contract);

        // Deploy MorphoRewardsMerkleClaimerDecoderAndSanitizer
        creationCode = type(MorphoRewardsMerkleClaimerDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract(
            "Morpho Rewards Merkle Claimer Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0
        );
        // console.log("MorphoRewardsMerkleClaimerDecoderAndSanitizer", _contract);

        // We don't use this directly in boring-tools as the MorphoRewardsMerkleClaimerDecoderAndSanitizer inherits from it
        // Deploy MorphoRewardsWrapperDecoderAndSanitizer
        // creationCode = type(MorphoRewardsWrapperDecoderAndSanitizer).creationCode;
        // constructorArgs = hex"";
        // _contract = deployContract("Morpho Rewards Wrapper Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy NativeWrapperDecoderAndSanitizer
        creationCode = type(NativeWrapperDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Native Wrapper Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("NativeWrapperDecoderAndSanitizer", _contract);

        // Deploy OdosDecoderAndSanitizer
        creationCode = type(OdosDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        addressKeys = ["odosRouterV2"];
        _contract = deployContract("Odos Decoder and Sanitizer V0.0", creationCode, 0);
        // console.log("OdosDecoderAndSanitizer", _contract);

        // Deploy OFTDecoderAndSanitizer
        creationCode = type(OFTDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("OFT Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("OFTDecoderAndSanitizer", _contract);

        // Deploy OneInchDecoderAndSanitizer
        creationCode = type(OneInchDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("One Inch Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("OneInchDecoderAndSanitizer", _contract);

        // Deploy OogaBoogaDecoderAndSanitizer
        creationCode = type(OogaBoogaDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Ooga Booga Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("OogaBoogaDecoderAndSanitizer", _contract);

        // Deploy PancakeSwapV3DecoderAndSanitizer
        creationCode = type(PancakeSwapV3DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        addressKeys = ["pancakeSwapV3NonFungiblePositionManager", "pancakeSwapV3MasterChefV3"];
        _contract = deployContract("Pancake Swap V3 Decoder and Sanitizer V0.0", creationCode, 0);
        // console.log("PancakeSwapV3DecoderAndSanitizer", _contract);

        // Deploy PendleRouterDecoderAndSanitizer
        creationCode = type(PendleRouterDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Pendle Router Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("PendleRouterDecoderAndSanitizer", _contract);

        // Deploy Permit2DecoderAndSanitizer
        creationCode = type(Permit2DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Permit2 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("Permit2DecoderAndSanitizer", _contract);

        // Deploy PumpStakingDecoderAndSanitizer
        creationCode = type(PumpStakingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Pump Staking Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("PumpStakingDecoderAndSanitizer", _contract);

        // Deploy ResolvDecoderAndSanitizer
        creationCode = type(ResolvDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Resolv Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0);
        // console.log("ResolvDecoderAndSanitizer", _contract);

        // Deploy RoycoWeirollDecoderAndSanitizer
        creationCode = type(RoycoWeirollDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        addressKeys = ["recipeMarketHub"];
        _contract = deployContract("Royco Decoder and Sanitizer V0.0", creationCode, 0);
        // console.log("RoycoWeirollDecoderAndSanitizer", _contract);

        // Deploy SatlayerStakingDecoderAndSanitizer
        creationCode = type(SatlayerStakingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Satlayer Staking Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("SatlayerStakingDecoderAndSanitizer", _contract);

        // Deploy ScrollBridgeDecoderAndSanitizer
        creationCode = type(ScrollBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Scroll Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("ScrollBridgeDecoderAndSanitizer", _contract);

        // Deploy SiloDecoderAndSanitizer
        creationCode = type(SiloDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Silo Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("SiloDecoderAndSanitizer", _contract);

        // Deploy SiloVaultDecoderAndSanitizer
        creationCode = type(SiloVaultDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Silo Vault Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("SiloVaultDecoderAndSanitizer", _contract);

        // Deploy SkyMoneyDecoderAndSanitizer
        creationCode = type(SkyMoneyDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Sky Money Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("SkyMoneyDecoderAndSanitizer", _contract);

        // Deploy SonicDepositDecoderAndSanitizer
        creationCode = type(SonicDepositDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Sonic Deposit Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("SonicDepositDecoderAndSanitizer", _contract);

        // Deploy SonicGatewayDecoderAndSanitizer
        creationCode = type(SonicGatewayDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Sonic Gateway Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("SonicGatewayDecoderAndSanitizer", _contract);

        // Deploy SpectraDecoderAndSanitizer
        creationCode = type(SpectraDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Spectra Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0);
        // console.log("SpectraDecoderAndSanitizer", _contract);

        // Deploy StandardBridgeDecoderAndSanitizer
        creationCode = type(StandardBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Standard Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("StandardBridgeDecoderAndSanitizer", _contract);

        // Deploy SwellDecoderAndSanitizer
        creationCode = type(SwellDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Swell Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("SwellDecoderAndSanitizer", _contract);

        // Deploy SwellSimpleStakingDecoderAndSanitizer
        creationCode = type(SwellSimpleStakingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Swell Simple Staking Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("SwellSimpleStakingDecoderAndSanitizer", _contract);

        // Deploy SymbioticDecoderAndSanitizer
        creationCode = type(SymbioticDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Symbiotic Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("SymbioticDecoderAndSanitizer", _contract);

        // Deploy SymbioticVaultDecoderAndSanitizer
        creationCode = type(SymbioticVaultDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Symbiotic Vault Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("SymbioticVaultDecoderAndSanitizer", _contract);

        // Deploy SyrupDecoderAndSanitizer
        creationCode = type(SyrupDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Syrup Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("SyrupDecoderAndSanitizer", _contract);

        // Deploy TellerDecoderAndSanitizer
        creationCode = type(TellerDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Teller Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0);
        // console.log("TellerDecoderAndSanitizer", _contract);

        // Deploy TreehouseDecoderAndSanitizer
        creationCode = type(TreehouseDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Treehouse Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("TreehouseDecoderAndSanitizer", _contract);

        // Deploy UniswapV2DecoderAndSanitizer
        creationCode = type(UniswapV2DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Uniswap V2 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("UniswapV2DecoderAndSanitizer", _contract);

        // Deploy UniswapV3DecoderAndSanitizer
        creationCode = type(UniswapV3DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        addressKeys = ["uniswapV3NonFungiblePositionManager"];
        _contract = deployContract("Uniswap V3 Decoder and Sanitizer V0.0", creationCode, 0);
        // console.log("UniswapV3DecoderAndSanitizer", _contract);

        // Deploy UniswapV3SwapRouter02DecoderAndSanitizer
        creationCode = type(UniswapV3SwapRouter02DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        addressKeys = ["uniswapV3NonFungiblePositionManager"];
        _contract = deployContract("Uniswap V3 Swap Router02 Decoder and Sanitizer V0.1", creationCode, 0);
        // console.log("UniswapV3SwapRouter02DecoderAndSanitizer", _contract);

        // Deploy UniswapV4DecoderAndSanitizer
        creationCode = type(UniswapV4DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        addressKeys = ["uniV4PositionManager"];
        _contract = deployContract("Uniswap V4 Decoder and Sanitizer V0.1", creationCode, 0);
        // console.log("UniswapV4DecoderAndSanitizer", _contract);

        // Deploy UsualMoneyDecoderAndSanitizer
        creationCode = type(UsualMoneyDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Usual Money Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("UsualMoneyDecoderAndSanitizer", _contract);

        // Deploy VaultCraftDecoderAndSanitizer
        creationCode = type(VaultCraftDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Vault Craft Decoder and Sanitizer V0.2", creationCode, constructorArgs, 0);
        // console.log("VaultCraftDecoderAndSanitizer", _contract);

        // Deploy VelodromeDecoderAndSanitizer
        creationCode = type(VelodromeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        addressKeys = ["velodromeNonFungiblePositionManager"];
        _contract = deployContract("Velodrome Decoder and Sanitizer V0.2", creationCode, 0);
        // console.log("VelodromeDecoderAndSanitizer", _contract);

        // Deploy WithdrawQueueDecoderAndSanitizer
        creationCode = type(WithdrawQueueDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Withdraw Queue Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("WithdrawQueueDecoderAndSanitizer", _contract);

        // Deploy ZircuitSimpleStakingDecoderAndSanitizer
        creationCode = type(ZircuitSimpleStakingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Zircuit Simple Staking Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("ZircuitSimpleStakingDecoderAndSanitizer", _contract);

        // Deploy WeETHDecoderAndSanitizer
        creationCode = type(WeETHDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("We Eth Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("WeETHDecoderAndSanitizer", _contract);

        // Deploy TermFinanceDecoderAndSanitizer
        creationCode = type(TermFinanceDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Term Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("TermFinanceDecoderAndSanitizer", _contract);

        // Deploy UltraYieldDecoderAndSanitizer
        creationCode = type(UltraYieldDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Ultra Yield Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("UltraYieldDecoderAndSanitizer", _contract);

        // Deploy CCTPDecoderAndSanitizer
        creationCode = type(CCTPDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("CCTP Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("CCTPDecoderAndSanitizer", _contract);

        // Deploy CompoundV2DecoderAndSanitizer
        creationCode = type(CompoundV2DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Compound V2 Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("CompoundV2DecoderAndSanitizer", _contract);

        // Deploy AvalancheBridgeDecoderAndSanitizer
        creationCode = type(AvalancheBridgeDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Avalanche Bridge Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("AvalancheBridgeDecoderAndSanitizer", _contract);

        // Deploy rFLRDecoderAndSanitizer
        creationCode = type(rFLRDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("rFLR Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("rFLRDecoderAndSanitizer", _contract);

        // Deploy wSwellUnwrappingDecoderAndSanitizer
        creationCode = type(wSwellUnwrappingDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("wSwell Unwrapping Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("wSwellUnwrappingDecoderAndSanitizer", _contract);

        // Deploy StakeStoneDecoderAndSanitizer
        creationCode = type(StakeStoneDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Stake Stone Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        console.log("StakeStoneDecoderAndSanitizer", _contract);

        // Deploy TacCrossChainLayerDecoderAndSanitizer
        creationCode = type(TacCrossChainLayerDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Tac Cross Chain Layer Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("TacCrossChainLayerDecoderAndSanitizer", _contract);

        // Deploy AlgebraV4DecoderAndSanitizer
        creationCode = type(AlgebraV4DecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        addressKeys = ["algebraNonFungiblePositionManager"];
        _contract = deployContract("Algebra V4 Decoder and Sanitizer V0.0", creationCode, 0);
        // console.log("AlgebraV4DecoderAndSanitizer", _contract);

        // Deploy KinetiqDecoderAndSanitizer
        creationCode = type(KinetiqDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Kinetiq Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("KinetiqDecoderAndSanitizer", _contract);

        // Deploy ValantisDecoderAndSanitizer
        creationCode = type(ValantisDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Valantis Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("ValantisDecoderAndSanitizer", _contract);

        // Deploy GlueXDecoderAndSanitizer
        creationCode = type(GlueXDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("GlueX Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("GlueXDecoderAndSanitizer", _contract);

        // Deploy RedSnwapperDecoderAndSanitizer
        creationCode = type(RedSnwapperDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        _contract = deployContract("Red Snwapper Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        // console.log("RedSnwapperDecoderAndSanitizer", _contract);

        _bundleTxs();
    }

    function deployContract(string memory name, bytes memory creationCode, uint256 value) internal returns (address _contract) {
        _contract = deployer.getAddress(name);
        if (_contract.code.length > 0) {
            console.log(name, "already deployed at", _contract);
            return _contract;
        }

        bytes memory constructorArgs;
        for (uint256 i = 0; i < addressKeys.length; i++) {
            if (values[sourceChain][addressKeys[i]] != bytes32(0)) {
                constructorArgs = abi.encodePacked(constructorArgs, abi.encode(getAddress(sourceChain, addressKeys[i])));
            } else {
                console.log(string.concat("Skipping ", name, " because ", addressKeys[i], " is not set"));
                return _contract;
            }
        }

        _addTx(address(deployer), abi.encodeWithSelector(deployer.deployContract.selector, name, creationCode, constructorArgs, value), value);
        console.log(string.concat(unicode"✅", name, "deployment to"), _contract, ": TX added");
        console.logBytes(constructorArgs);
    }

    function deployContract(string memory name, bytes memory creationCode, bytes memory constructorArgs, uint256 value) internal returns (address _contract) {
        _contract = deployer.getAddress(name);
        if (_contract.code.length > 0) {
            console.log(name, "already deployed at", _contract);
            return _contract;
        }

        _addTx(address(deployer), abi.encodeWithSelector(deployer.deployContract.selector, name, creationCode, constructorArgs, value), value);
        console.log(string.concat(unicode"✅", name, "deployment to"), _contract, ": TX added");
    }

    function _bundleTxs() internal {
        Deployer.Tx[] memory txsToSend = getTxs();
        uint256 txsLength = txsToSend.length;

        if (txsLength == 0) {
            console.log("No txs to bundle");
            return;
        }

        // Determine how many txs to send
        uint256 desiredNumberOfDeploymentTxs = DESIRED_NUMBER_OF_DEPLOYMENT_TXS;
        if (desiredNumberOfDeploymentTxs == 0) {
            console.log("Desired number of deployment txs is 0");
        }
        desiredNumberOfDeploymentTxs =
            desiredNumberOfDeploymentTxs > txsLength ? txsLength : desiredNumberOfDeploymentTxs;
        uint256 txsPerBundle = txsLength / desiredNumberOfDeploymentTxs;
        uint256 lastIndexDeployed;
        Deployer.Tx[][] memory txBundles = new Deployer.Tx[][](desiredNumberOfDeploymentTxs);

        console.log(string.concat("Tx bundles to send: ", vm.toString(desiredNumberOfDeploymentTxs)));
        console.log(string.concat("Total txs: ", vm.toString(txsLength)));

        for (uint256 i; i < desiredNumberOfDeploymentTxs; i++) {
            uint256 txsInBundle;
            if (i == desiredNumberOfDeploymentTxs - 1 && txsLength % txsPerBundle != 0) {
                txsInBundle = txsLength - lastIndexDeployed;
            } else {
                txsInBundle = txsPerBundle;
            }
            txBundles[i] = new Deployer.Tx[](txsInBundle);
            for (uint256 j; j < txBundles[i].length; j++) {
                txBundles[i][j] = txsToSend[lastIndexDeployed + j];
            }
            lastIndexDeployed += txsInBundle;
        }

        // Read tx bundler address from configuration file.
        address txBundler = getAddress(sourceChain, "txBundlerAddress");

        // TODO maybe I could have this save the txs to a json if it fails?
        vm.startBroadcast(privateKey);
        for (uint256 i; i < desiredNumberOfDeploymentTxs; i++) {
            console.log(string.concat("Sending bundle: ", vm.toString(i)));
            Deployer(txBundler).bundleTxs(txBundles[i]);
        }
        vm.stopBroadcast();
    }
}
