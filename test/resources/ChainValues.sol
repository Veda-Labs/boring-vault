// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";

contract ChainValues {
    using AddressToBytes32Lib for address;
    using AddressToBytes32Lib for bytes32;

    string public constant mainnet = "mainnet";
    string public constant polygon = "polygon";
    string public constant bsc = "bsc";
    string public constant avalanche = "avalanche";
    string public constant arbitrum = "arbitrum";
    string public constant optimism = "optimism";
    string public constant base = "base";
    string public constant zircuit = "zircuit";
    string public constant mantle = "mantle";
    string public constant linea = "linea";
    string public constant scroll = "scroll";
    string public constant fraxtal = "fraxtal";
    string public constant corn = "corn";
    string public constant swell = "swell";
    string public constant sonicMainnet = "sonicMainnet";
    string public constant berachain = "berachain";
    string public constant bob = "bob";
    string public constant derive = "derive";
    string public constant unichain = "unichain";
    string public constant ink = "ink";
    string public constant holesky = "holesky";
    string public constant sepolia = "sepolia";
    string public constant sonicTestnet = "sonicTestnet";
    string public constant sonicBlaze = "sonicBlaze";
    string public constant berachainTestnet = "berachainTestnet";
    string public constant bartio = "bartio";
    string public constant hyperEVM = "hyperEVM";
    string public constant tacTestnet = "tacTestnet";
    string public constant flare = "flare";
    string public constant plume = "plume";
    string public constant katana = "katana";
    string public constant tac = "tac";
    string public constant plasma = "plasma";
    string public constant inkSepolia = "inkSepolia";

    // Bridging constants.
    uint64 public constant ccipArbitrumChainSelector = 4949039107694359620;
    uint64 public constant ccipMainnetChainSelector = 5009297550715157269;
    uint64 public constant ccipBobChainSelector = 3849287863852499584;
    uint64 public constant ccipBaseChainSelector = 15971525489660198786;
    uint64 public constant ccipBscChainSelector = 11344663589394136015;
    uint64 public constant ccipKatanaChainSelector = 2459028469735686113;
    uint32 public constant layerZeroBaseEndpointId = 30184;
    uint32 public constant layerZeroMainnetEndpointId = 30101;
    uint32 public constant layerZeroOptimismEndpointId = 30111;
    uint32 public constant layerZeroArbitrumEndpointId = 30110;
    uint32 public constant layerZeroLineaEndpointId = 30183;
    uint32 public constant layerZeroScrollEndpointId = 30214;
    uint32 public constant layerZeroCornEndpointId = 30331;
    uint32 public constant layerZeroSwellEndpointId = 30335;
    uint32 public constant layerZeroSonicMainnetEndpointId = 30332;
    uint32 public constant layerZeroUnichainEndpointId = 30320;
    uint32 public constant layerZeroBerachainEndpointId = 30362;
    uint32 public constant layerZeroSepoliaEndpointId = 40161;
    uint32 public constant layerZeroSonicBlazeEndpointId = 40349;
    uint32 public constant layerZeroMovementEndpointId = 30325;
    uint32 public constant layerZeroFlareEndpointId = 30295;
    uint32 public constant layerZeroInkEndpointId = 30339;
    uint32 public constant hyperlaneMainnetEndpointId = 1;
    uint32 public constant hyperlaneEclipseEndpointId = 1408864445;
    uint32 public constant HyperEVMEndpointId = 30367;
    uint32 public constant layerZeroPlumeEndpointId = 30370;
    uint32 public constant layerZeroKatanaEndpointId = 30375;
    uint32 public constant layerZeroTACEndpointId = 30377;
    uint32 public constant layerZeroTONEndpointId = 30343;
    uint32 public constant layerZeroPlasmaEndpointId = 30383;

    error ChainValues__ZeroAddress(string chainName, string valueName);
    error ChainValues__ZeroBytes32(string chainName, string valueName);
    error ChainValues__ValueAlreadySet(string chainName, string valueName);

    mapping(string => mapping(string => bytes32)) public values;

    function getAddress(string memory chainName, string memory valueName) public view returns (address a) {
        a = values[chainName][valueName].toAddress();
        if (a == address(0)) {
            revert ChainValues__ZeroAddress(chainName, valueName);
        }
    }

    function getERC20(string memory chainName, string memory valueName) public view returns (ERC20 erc20) {
        address a = getAddress(chainName, valueName);
        erc20 = ERC20(a);
    }

    function getBytes32(string memory chainName, string memory valueName) public view returns (bytes32 b) {
        b = values[chainName][valueName];
        if (b == bytes32(0)) {
            revert ChainValues__ZeroBytes32(chainName, valueName);
        }
    }

    function setValue(bool overrideOk, string memory chainName, string memory valueName, bytes32 value) public {
        if (!overrideOk && values[chainName][valueName] != bytes32(0)) {
            revert ChainValues__ValueAlreadySet(chainName, valueName);
        }
        values[chainName][valueName] = value;
    }

    function setAddress(bool overrideOk, string memory chainName, string memory valueName, address value) public {
        setValue(overrideOk, chainName, valueName, value.toBytes32());
    }

    constructor() {
        // Add mainnet values
        _addMainnetValues();
        _addBaseValues();
        _addArbitrumValues();
        _addOptimismValues();
        _addMantleValues();
        _addZircuitValues();
        _addLineaValues();
        _addScrollValues();
        _addFraxtalValues();
        _addBscValues();
        _addCornValues();
        _addSwellValues();
        _addSonicMainnetValues();
        _addBerachainValues();
        _addBobValues();
        _addDeriveValues();
        _addUnichainValues();
        _addHyperEVMValues();
        _addFlareValues();
        _addInkValues();
        _addAvalancheValues();
        _addPlumeValues();
        _addKatanaValues();
        _addTACValues();
        _addPlasmaValues();
        // Add testnet values
        _addHoleskyValues();
        _addSepoliaValues();
        _addSonicTestnetValues();
        _addSonicBlazeValues();
        _addBerachainTestnetValues();
        _addBartioValues();
        _addTACTestnetValues();
        _addInkSepoliaValues();
    }

    function _addMainnetValues() private {
        values[mainnet]["boringDeployerContract"] = 0xFD65ADF7d2f9ea09287543520a703522E0a360C9.toBytes32();
        // Liquid Ecosystem
        values[mainnet]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[mainnet]["deployerAddress2"] = 0xF3d0672a91Fd56C9ef04C79ec67d60c34c6148a0.toBytes32();
        values[mainnet]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[mainnet]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[mainnet]["dev3Address"] = 0xBBc5569B0b32403037F37255f4ff50B8Bb825b2A.toBytes32();
        values[mainnet]["dev4Address"] = 0xD3d742a82524b6de30E54315E471264dc4CF2BcC.toBytes32();
        values[mainnet]["dev5Address"] = 0x1cdF47387358A1733968df92f7cC14546D9E1047.toBytes32();
        values[mainnet]["liquidV1PriceRouter"] = 0x693799805B502264f9365440B93C113D86a4fFF5.toBytes32();
        values[mainnet]["liquidPayoutAddress"] = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A.toBytes32();
        values[mainnet]["liquidMultisig"] = 0xCEA8039076E35a825854c5C2f85659430b06ec96.toBytes32();
        values[mainnet]["liquidEth"] = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C.toBytes32();
        values[mainnet]["liquidEthStrategist"] = 0x41DFc53B13932a2690C9790527C1967d8579a6ae.toBytes32();
        values[mainnet]["liquidEthManager"] = 0x227975088C28DBBb4b421c6d96781a53578f19a8.toBytes32();
        values[mainnet]["liquidEthDelayedWithdraw"] = 0xA1177Bc62E42eF2f9225a6cBF1CfE5CbC360C33A.toBytes32();
        values[mainnet]["superSymbiotic"] = 0x917ceE801a67f933F2e6b33fC0cD1ED2d5909D88.toBytes32();
        values[mainnet]["superSymbioticTeller"] = 0x99dE9e5a3eC2750a6983C8732E6e795A35e7B861.toBytes32();
        values[mainnet]["weETHs"] = 0x917ceE801a67f933F2e6b33fC0cD1ED2d5909D88.toBytes32();
        values[mainnet]["txBundlerAddress"] = 0x47Cec90FACc9364D7C21A8ab5e2aD9F1f75D740C.toBytes32();
        values[mainnet]["eBTCVault"] = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642.toBytes32();
        values[mainnet]["eBTCDelayedWithdraw"] = 0x75E3f26Ceff44258CE8cB451D7d2cC8966Ef3554.toBytes32();
        values[mainnet]["eBTCOnChainQueue"] = 0x74EC75fb641ec17B04007733d9efBE2D1dA5CA2C.toBytes32();
        values[mainnet]["eBTCOnChainQueueFast"] = 0x686696A3e59eE16e8A8533d84B62cfA504827135.toBytes32();
        values[mainnet]["eBTCTeller"] = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268.toBytes32();
        values[mainnet]["etherfiRewardClaimer"] = 0xBdA9e965CdA04eD5Bfc841E54573Dc083447E15a.toBytes32();

        // Tellers
        values[mainnet]["eBTCTeller"] = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268.toBytes32();
        values[mainnet]["liquidBeraBTCTeller"] = 0xe238e253b67f42ee3aF194BaF7Aba5E2eaddA1B8.toBytes32();
        values[mainnet]["sBTCNTeller"] = 0xeAd024098eE05e8e975043eCc6189b49CfBe35fd.toBytes32();
        values[mainnet]["sonicLBTCTeller"] = 0x258f532CB41393c505554228e66eaf580B0171b2.toBytes32();
        values[mainnet]["sonicBTCTeller"] = 0x258f532CB41393c505554228e66eaf580B0171b2.toBytes32();
        values[mainnet]["tacLBTCvTeller"] = 0xAe499dAa7350b78746681931c47394eB7cC4Cf7F.toBytes32();
        values[mainnet]["TACTeller"] = 0xBbf9E8718D83CF67b568bfFd9d3034BfF02A0103.toBytes32();
        values[mainnet]["TACLBTCvTeller"] = 0xAe499dAa7350b78746681931c47394eB7cC4Cf7F.toBytes32();
        values[mainnet]["TurtleTACBTCTeller"] = 0x7C75cbb851D321B2Ec8034D58A9B5075e991E584.toBytes32();
        values[mainnet]["katanaLBTCTeller"] = 0x38d4066cC4B42E2B6615aE15cAa6e347114779E2.toBytes32();
        values[mainnet]["sLBTCTeller"] = 0x97Deb8Fb02A2553976DCD3d25FaA1501Eef4585b.toBytes32();
        values[mainnet]["ethenaRWATeller"] = 0xDEa662f24389eB7CaFA9b3B10021884FCe7314f0.toBytes32();

        // Withdraw Queues
        values[mainnet]["sBTCNWithdrawQueue"] = 0xB316940529B85234ec7C4F48CD8Bef8d1BAe5F7f.toBytes32();
        values[mainnet]["tacLBTCvWithdrawQueue"] = 0xa6F5Aa413DdF0Ca1c57102Dbe0Badb2233798007.toBytes32();
        values[mainnet]["eBTCOnChainQueueFast"] = 0x686696A3e59eE16e8A8533d84B62cfA504827135.toBytes32();
        values[mainnet]["TACOnChainQueue"] = 0x850EeD781C538849E8cc86a1a080327ECBeBff9c.toBytes32();
        values[mainnet]["TurtleTACBTCQueue"] = 0x9A214cDD8967d7616cfaf7b92A10B2116a0c39A7.toBytes32();
        values[mainnet]["TACLBTCvQueue"] = 0xa6F5Aa413DdF0Ca1c57102Dbe0Badb2233798007.toBytes32();
        values[mainnet]["sonicLBTCWithdrawQueue"] = 0xAea73B51380Fa5C0f76F0611c4346af4090ED2D7.toBytes32();
        values[mainnet]["katanaLBTCWithdrawQueue"] = 0xa0fE75799583F4591552cd26c605e0FD3a763682.toBytes32();
        values[mainnet]["sLBTCWithdrawQueue"] = 0x7db0E2540F58743c5A97f11964aED611BdcAE10F.toBytes32();

        // Boring Vaults
        values[mainnet]["liquidMove"] = 0xca8711dAF13D852ED2121E4bE3894Dae366039E4.toBytes32();
        values[mainnet]["sBTCN"] = 0x5E272ca4bD94e57Ec5C51D26703621Ccac1A7089.toBytes32();
        values[mainnet]["tacLBTCv"] = 0xD86fC1CaA0a5B82cC16B16B70DFC59F6f034C348.toBytes32();
        values[mainnet]["TurtleTACUSD"] = 0x699e04F98dE2Fc395a7dcBf36B48EC837A976490.toBytes32();
        values[mainnet]["TurtleTACETH"] = 0x294eecec65A0142e84AEdfD8eB2FBEA8c9a9fbad.toBytes32();
        values[mainnet]["TACLBTCv"] = 0xD86fC1CaA0a5B82cC16B16B70DFC59F6f034C348.toBytes32();
        values[mainnet]["TurtleTACBTC"] = 0x6Bf340dB729d82af1F6443A0Ea0d79647b1c3DDf.toBytes32();
        values[mainnet]["sonicLBTC"] = 0x309f25d839A2fe225E80210e110C99150Db98AAF.toBytes32();
        values[mainnet]["katanaLBTC"] = 0x75231079973C23e9eB6180fa3D2fc21334565aB5.toBytes32();
        values[mainnet]["turtleKatanaETH"] = 0x69d210d3b60E939BFA6E87cCcC4fAb7e8F44C16B.toBytes32();
        values[mainnet]["sLBTC"] = 0x13Cc1b39cb259BA10cd174EAe42012e698ed7c51.toBytes32();
        values[mainnet]["ethenaRWA"] = 0x6fDcB0654B4814c2eC1E7e9dbC4cEBf1a2038a84.toBytes32();

        // Decoders
        values[mainnet]["rewardTokenUnwrappingDecoder"] = 0x3fF425c112d4363a7e21934a5D1EE09b1D2F8c91.toBytes32();

        // DeFi Ecosystem
        values[mainnet]["ETH"] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE.toBytes32();
        values[mainnet]["NATIVE"] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE.toBytes32();
        values[mainnet]["uniV3Router"] = 0xE592427A0AEce92De3Edee1F18E0157C05861564.toBytes32();
        values[mainnet]["uniV2Router"] = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D.toBytes32();
        values[mainnet]["uniV2Factory"] = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f.toBytes32();
        values[mainnet]["uniV4PoolManager"] = 0x000000000004444c5dc75cB358380D2e3dE08A90.toBytes32();
        values[mainnet]["uniV4PositionManager"] = 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e.toBytes32();
        values[mainnet]["uniV4UniversalRouter"] = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af.toBytes32();
        values[mainnet]["permit2"] = 0x000000000022D473030F116dDEE9F6B43aC78BA3.toBytes32();

        // ERC20s
        values[mainnet]["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48.toBytes32();
        values[mainnet]["WETH"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2.toBytes32();
        values[mainnet]["WBTC"] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599.toBytes32();
        values[mainnet]["USDT"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7.toBytes32();
        values[mainnet]["TUSD"] = 0x0000000000085d4780B73119b644AE5ecd22b376.toBytes32();
        values[mainnet]["DAI"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F.toBytes32();
        values[mainnet]["WSTETH"] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0.toBytes32();
        values[mainnet]["STETH"] = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84.toBytes32();
        values[mainnet]["FRAX"] = 0x853d955aCEf822Db058eb8505911ED77F175b99e.toBytes32();
        values[mainnet]["BAL"] = 0xba100000625a3754423978a60c9317c58a424e3D.toBytes32();
        values[mainnet]["COMP"] = 0xc00e94Cb662C3520282E6f5717214004A7f26888.toBytes32();
        values[mainnet]["LINK"] = 0x514910771AF9Ca656af840dff83E8264EcF986CA.toBytes32();
        values[mainnet]["rETH"] = 0xae78736Cd615f374D3085123A210448E74Fc6393.toBytes32();
        values[mainnet]["RETH"] = 0xae78736Cd615f374D3085123A210448E74Fc6393.toBytes32();
        values[mainnet]["cbETH"] = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704.toBytes32();
        values[mainnet]["RPL"] = 0xD33526068D116cE69F19A9ee46F0bd304F21A51f.toBytes32();
        values[mainnet]["BOND"] = 0x0391D2021f89DC339F60Fff84546EA23E337750f.toBytes32();
        values[mainnet]["SWETH"] = 0xf951E335afb289353dc249e82926178EaC7DEd78.toBytes32();
        values[mainnet]["AURA"] = 0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF.toBytes32();
        values[mainnet]["GHO"] = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f.toBytes32();
        values[mainnet]["LUSD"] = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0.toBytes32();
        values[mainnet]["OHM"] = 0x64aa3364F17a4D01c6f1751Fd97C2BD3D7e7f1D5.toBytes32();
        values[mainnet]["MKR"] = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2.toBytes32();
        values[mainnet]["APE"] = 0x4d224452801ACEd8B2F0aebE155379bb5D594381.toBytes32();
        values[mainnet]["UNI"] = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984.toBytes32();
        values[mainnet]["CRV"] = 0xD533a949740bb3306d119CC777fa900bA034cd52.toBytes32();
        values[mainnet]["CVX"] = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B.toBytes32();
        values[mainnet]["FRXETH"] = 0x5E8422345238F34275888049021821E8E08CAa1f.toBytes32();
        values[mainnet]["CRVUSD"] = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E.toBytes32();
        values[mainnet]["OETH"] = 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3.toBytes32();
        values[mainnet]["MKUSD"] = 0x4591DBfF62656E7859Afe5e45f6f47D3669fBB28.toBytes32();
        values[mainnet]["YETH"] = 0x1BED97CBC3c24A4fb5C069C6E311a967386131f7.toBytes32();
        values[mainnet]["ETHX"] = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b.toBytes32();
        values[mainnet]["weETH"] = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee.toBytes32();
        values[mainnet]["WEETH"] = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee.toBytes32();
        values[mainnet]["EETH"] = 0x35fA164735182de50811E8e2E824cFb9B6118ac2.toBytes32();
        values[mainnet]["EZETH"] = 0xbf5495Efe5DB9ce00f80364C8B423567e58d2110.toBytes32();
        values[mainnet]["RSETH"] = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7.toBytes32();
        values[mainnet]["OSETH"] = 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38.toBytes32();
        values[mainnet]["RSWETH"] = 0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0.toBytes32();
        values[mainnet]["PENDLE"] = 0x808507121B80c02388fAd14726482e061B8da827.toBytes32();
        values[mainnet]["SUSDE"] = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497.toBytes32();
        values[mainnet]["USDE"] = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3.toBytes32();
        values[mainnet]["GEAR"] = 0xBa3335588D9403515223F109EdC4eB7269a9Ab5D.toBytes32();
        values[mainnet]["SDAI"] = 0x83F20F44975D03b1b09e64809B757c47f942BEeA.toBytes32();
        values[mainnet]["PYUSD"] = 0x6c3ea9036406852006290770BEdFcAbA0e23A0e8.toBytes32();
        values[mainnet]["METH"] = 0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa.toBytes32();
        values[mainnet]["TBTC"] = 0x18084fbA666a33d37592fA2633fD49a74DD93a88.toBytes32();
        values[mainnet]["INST"] = 0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb.toBytes32();
        values[mainnet]["LBTC"] = 0x8236a87084f8B84306f72007F36F2618A5634494.toBytes32();
        values[mainnet]["EBTC"] = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642.toBytes32();
        values[mainnet]["RSR"] = 0x320623b8E4fF03373931769A31Fc52A4E78B5d70.toBytes32();
        values[mainnet]["SFRXETH"] = 0xac3E018457B222d93114458476f3E3416Abbe38F.toBytes32();
        values[mainnet]["WBETH"] = 0xa2E3356610840701BDf5611a53974510Ae27E2e1.toBytes32();
        values[mainnet]["UNIETH"] = 0xF1376bceF0f78459C0Ed0ba5ddce976F1ddF51F4.toBytes32();
        values[mainnet]["CBETH"] = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704.toBytes32();
        values[mainnet]["USD0"] = 0x73A15FeD60Bf67631dC6cd7Bc5B6e8da8190aCF5.toBytes32();
        values[mainnet]["USD0_plus"] = 0x35D8949372D46B7a3D5A56006AE77B215fc69bC0.toBytes32();
        values[mainnet]["deUSD"] = 0x15700B564Ca08D9439C58cA5053166E8317aa138.toBytes32();
        values[mainnet]["sdeUSD"] = 0x5C5b196aBE0d54485975D1Ec29617D42D9198326.toBytes32();
        values[mainnet]["pumpBTC"] = 0xF469fBD2abcd6B9de8E169d128226C0Fc90a012e.toBytes32();
        values[mainnet]["CAKE"] = 0x152649eA73beAb28c5b49B26eb48f7EAD6d4c898.toBytes32();
        values[mainnet]["cbBTC"] = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf.toBytes32();
        values[mainnet]["fBTC"] = 0xC96dE26018A54D51c097160568752c4E3BD6C364.toBytes32();
        values[mainnet]["EIGEN"] = 0xec53bF9167f50cDEB3Ae105f56099aaaB9061F83.toBytes32();
        values[mainnet]["wcUSDCv3"] = 0x27F2f159Fe990Ba83D57f39Fd69661764BEbf37a.toBytes32();
        values[mainnet]["ZRO"] = 0x6985884C4392D348587B19cb9eAAf157F13271cd.toBytes32();
        values[mainnet]["eBTC"] = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642.toBytes32();
        values[mainnet]["USDS"] = 0xdC035D45d973E3EC169d2276DDab16f1e407384F.toBytes32();
        values[mainnet]["sUSDS"] = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD.toBytes32();
        values[mainnet]["uniBTC"] = 0x004E9C3EF86bc1ca1f0bB5C7662861Ee93350568.toBytes32();
        values[mainnet]["BTCN"] = 0x386E7A3a0c0919c9d53c3b04FF67E73Ff9e45Fb6.toBytes32();
        values[mainnet]["sUSDs"] = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD.toBytes32();
        values[mainnet]["USR"] = 0x66a1E37c9b0eAddca17d3662D6c05F4DECf3e110.toBytes32();
        values[mainnet]["WSTUSR"] = 0x1202F5C7b4B9E47a1A484E8B270be34dbbC75055.toBytes32();
        values[mainnet]["USUAL"] = 0xC4441c2BE5d8fA8126822B9929CA0b81Ea0DE38E.toBytes32();
        values[mainnet]["MORPHO"] = 0x58D97B57BB95320F9a05dC918Aef65434969c2B2.toBytes32();
        values[mainnet]["ETHFI"] = 0xFe0c30065B384F05761f15d0CC899D4F9F9Cc0eB.toBytes32();
        values[mainnet]["USR"] = 0x66a1E37c9b0eAddca17d3662D6c05F4DECf3e110.toBytes32();
        values[mainnet]["scBTC"] = 0xBb30e76d9Bb2CC9631F7fC5Eb8e87B5Aff32bFbd.toBytes32();
        values[mainnet]["beraSTONE"] = 0x97Ad75064b20fb2B2447feD4fa953bF7F007a706.toBytes32();
        values[mainnet]["solvBTC"] = 0x7A56E1C57C7475CCf742a1832B028F0456652F97.toBytes32();
        values[mainnet]["solvBTC.BBN"] = 0xd9D920AA40f578ab794426F5C90F6C731D159DEf.toBytes32();
        values[mainnet]["xsolvBTC"] = 0xd9D920AA40f578ab794426F5C90F6C731D159DEf.toBytes32();
        values[mainnet]["STONE"] = 0x7122985656e38BDC0302Db86685bb972b145bD3C.toBytes32();
        values[mainnet]["SWBTC"] = 0x8DB2350D78aBc13f5673A411D4700BCF87864dDE.toBytes32();
        values[mainnet]["enzoBTC"] = 0x6A9A65B84843F5fD4aC9a0471C4fc11AFfFBce4a.toBytes32();
        values[mainnet]["SBTC"] = 0x094c0e36210634c3CfA25DC11B96b562E0b07624.toBytes32();
        values[mainnet]["USR"] = 0x66a1E37c9b0eAddca17d3662D6c05F4DECf3e110.toBytes32();
        values[mainnet]["stUSR"] = 0x6c8984bc7DBBeDAf4F6b2FD766f16eBB7d10AAb4.toBytes32();
        values[mainnet]["wstUSR"] = 0x1202F5C7b4B9E47a1A484E8B270be34dbbC75055.toBytes32();
        values[mainnet]["stkGHO"] = 0x1a88Df1cFe15Af22B3c4c783D4e6F7F9e0C1885d.toBytes32();
        values[mainnet]["lvlUSD"] = 0x7C1156E515aA1A2E851674120074968C905aAF37.toBytes32();
        values[mainnet]["slvlUSD"] = 0x4737D9b4592B40d51e110b94c9C043c6654067Ae.toBytes32();
        values[mainnet]["PXETH"] = 0x04C154b66CB340F3Ae24111CC767e0184Ed00Cc6.toBytes32();
        values[mainnet]["FXUSD"] = 0x085780639CC2cACd35E474e71f4d000e2405d8f6.toBytes32();
        values[mainnet]["FXN"] = 0x365AccFCa291e7D3914637ABf1F7635dB165Bb09.toBytes32();
        values[mainnet]["RLUSD"] = 0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD.toBytes32();
        values[mainnet]["syrupUSDC"] = 0x80ac24aA929eaF5013f6436cdA2a7ba190f5Cc0b.toBytes32();
        values[mainnet]["syrupUSDT"] = 0x356B8d89c1e1239Cbbb9dE4815c39A1474d5BA7D.toBytes32();
        values[mainnet]["ELX"] = 0x89A8c847f41C0dfA6c8B88638bACca8a0b777Da7.toBytes32();
        values[mainnet]["FRXUSD"] = 0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29.toBytes32();
        values[mainnet]["sfrxUSD"] = 0xac3E018457B222d93114458476f3E3416Abbe38F.toBytes32();
        values[mainnet]["EUSDE"] = 0x90D2af7d622ca3141efA4d8f1F24d86E5974Cc8F.toBytes32();
        values[mainnet]["SUSDS"] = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD.toBytes32();
        values[mainnet]["KING"] = 0x8F08B70456eb22f6109F57b8fafE862ED28E6040.toBytes32();
        values[mainnet]["rEUL"] = 0xf3e621395fc714B90dA337AA9108771597b4E696.toBytes32();
        values[mainnet]["EUL"] = 0xd9Fcd98c322942075A5C3860693e9f4f03AAE07b.toBytes32();
        values[mainnet]["FLUID"] = 0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb.toBytes32();
        values[mainnet]["rUSD"] = 0x09D4214C03D01F49544C0448DBE3A27f768F2b34.toBytes32();
        values[mainnet]["srUSD"] = 0x738d1115B90efa71AE468F1287fc864775e23a31.toBytes32();
        values[mainnet]["sUSDC"] = 0xBc65ad17c5C0a2A4D159fa5a503f4992c7B545FE.toBytes32();
        values[mainnet]["frxUSD"] = 0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29.toBytes32();
        values[mainnet]["sfrxUSD"] = 0xcf62F905562626CfcDD2261162a51fd02Fc9c5b6.toBytes32();
        values[mainnet]["SYRUP"] = 0x643C4E15d7d62Ad0aBeC4a9BD4b001aA3Ef52d66.toBytes32();
        values[mainnet]["KBTC"] = 0x73E0C0d45E048D25Fc26Fa3159b0aA04BfA4Db98.toBytes32();
        values[mainnet]["BTCN"] = 0x386E7A3a0c0919c9d53c3b04FF67E73Ff9e45Fb6.toBytes32();
        values[mainnet]["scrvUSD"] = 0x0655977FEb2f289A4aB78af67BAB0d17aAb84367.toBytes32();
        values[mainnet]["vbETH"] = 0x2DC70fb75b88d2eB4715bc06E1595E6D97c34DFF.toBytes32();
        values[mainnet]["SWELL"] = 0x0a6E7Ba5042B38349e437ec6Db6214AEC7B35676.toBytes32();
        values[mainnet]["vbWBTC"] = 0x2C24B57e2CCd1f273045Af6A5f632504C432374F.toBytes32();
        values[mainnet]["MF-ONE"] = 0x238a700eD6165261Cf8b2e544ba797BC11e466Ba.toBytes32();
        values[mainnet]["USDtb"] = 0xC139190F447e929f090Edeb554D95AbB8b18aC1C.toBytes32();
        values[mainnet]["ETHPlus"] = 0xE72B141DF173b999AE7c1aDcbF60Cc9833Ce56a8.toBytes32();
        values[mainnet]["eEigen"] = 0xE77076518A813616315EaAba6cA8e595E845EeE9.toBytes32();
        values[mainnet]["USCC"] = 0x14d60E7FDC0D71d8611742720E4C50E7a974020c.toBytes32();

        // Rate providers
        values[mainnet]["WEETH_RATE_PROVIDER"] = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee.toBytes32();
        values[mainnet]["ETHX_RATE_PROVIDER"] = 0xAAE054B9b822554dd1D9d1F48f892B4585D3bbf0.toBytes32();
        values[mainnet]["UNIETH_RATE_PROVIDER"] = 0x2c3b8c5e98A6e89AAAF21Deebf5FF9d08c4A9FF7.toBytes32();
        values[mainnet]["WSTETH_RATE_PROVIDER"] = 0x06FF289EdCE4b9021d7eCbF9FE01198cfc4E1282.toBytes32();
        values[mainnet]["RSETH_RATE_PROVIDER"] = 0xf1b71B1Ce00e0f91ac92bD5a0d24eB75F0cA69Ad.toBytes32();

        // Chainlink Datafeeds
        values[mainnet]["WETH_USD_FEED"] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419.toBytes32();
        values[mainnet]["USDC_USD_FEED"] = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6.toBytes32();
        values[mainnet]["WBTC_USD_FEED"] = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c.toBytes32();
        values[mainnet]["TUSD_USD_FEED"] = 0xec746eCF986E2927Abd291a2A1716c940100f8Ba.toBytes32();
        values[mainnet]["STETH_USD_FEED"] = 0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8.toBytes32();
        values[mainnet]["DAI_USD_FEED"] = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9.toBytes32();
        values[mainnet]["USDT_USD_FEED"] = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D.toBytes32();
        values[mainnet]["COMP_USD_FEED"] = 0xdbd020CAeF83eFd542f4De03e3cF0C28A4428bd5.toBytes32();
        values[mainnet]["fastGasFeed"] = 0x169E633A2D1E6c10dD91238Ba11c4A708dfEF37C.toBytes32();
        values[mainnet]["FRAX_USD_FEED"] = 0xB9E1E3A9feFf48998E45Fa90847ed4D467E8BcfD.toBytes32();
        values[mainnet]["RETH_ETH_FEED"] = 0x536218f9E9Eb48863970252233c8F271f554C2d0.toBytes32();
        values[mainnet]["BOND_ETH_FEED"] = 0xdd22A54e05410D8d1007c38b5c7A3eD74b855281.toBytes32();
        values[mainnet]["CBETH_ETH_FEED"] = 0xF017fcB346A1885194689bA23Eff2fE6fA5C483b.toBytes32();
        values[mainnet]["STETH_ETH_FEED"] = 0x86392dC19c0b719886221c78AB11eb8Cf5c52812.toBytes32();
        values[mainnet]["BAL_USD_FEED"] = 0xdF2917806E30300537aEB49A7663062F4d1F2b5F.toBytes32();
        values[mainnet]["GHO_USD_FEED"] = 0x3f12643D3f6f874d39C2a4c9f2Cd6f2DbAC877FC.toBytes32();
        values[mainnet]["LUSD_USD_FEED"] = 0x3D7aE7E594f2f2091Ad8798313450130d0Aba3a0.toBytes32();
        values[mainnet]["OHM_ETH_FEED"] = 0x9a72298ae3886221820B1c878d12D872087D3a23.toBytes32();
        values[mainnet]["MKR_USD_FEED"] = 0xec1D1B3b0443256cc3860e24a46F108e699484Aa.toBytes32();
        values[mainnet]["UNI_ETH_FEED"] = 0xD6aA3D25116d8dA79Ea0246c4826EB951872e02e.toBytes32();
        values[mainnet]["APE_USD_FEED"] = 0xD10aBbC76679a20055E167BB80A24ac851b37056.toBytes32();
        values[mainnet]["CRV_USD_FEED"] = 0xCd627aA160A6fA45Eb793D19Ef54f5062F20f33f.toBytes32();
        values[mainnet]["CVX_USD_FEED"] = 0xd962fC30A72A84cE50161031391756Bf2876Af5D.toBytes32();
        values[mainnet]["CVX_ETH_FEED"] = 0xC9CbF687f43176B302F03f5e58470b77D07c61c6.toBytes32();
        values[mainnet]["CRVUSD_USD_FEED"] = 0xEEf0C605546958c1f899b6fB336C20671f9cD49F.toBytes32();
        values[mainnet]["LINK_USD_FEED"] = 0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c.toBytes32();

        // Aave V2 Tokens
        values[mainnet]["aV2WETH"] = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e.toBytes32();
        values[mainnet]["aV2USDC"] = 0xBcca60bB61934080951369a648Fb03DF4F96263C.toBytes32();
        values[mainnet]["dV2USDC"] = 0x619beb58998eD2278e08620f97007e1116D5D25b.toBytes32();
        values[mainnet]["dV2WETH"] = 0xF63B34710400CAd3e044cFfDcAb00a0f32E33eCf.toBytes32();
        values[mainnet]["aV2WBTC"] = 0x9ff58f4fFB29fA2266Ab25e75e2A8b3503311656.toBytes32();
        values[mainnet]["aV2TUSD"] = 0x101cc05f4A51C0319f570d5E146a8C625198e636.toBytes32();
        values[mainnet]["aV2STETH"] = 0x1982b2F5814301d4e9a8b0201555376e62F82428.toBytes32();
        values[mainnet]["aV2DAI"] = 0x028171bCA77440897B824Ca71D1c56caC55b68A3.toBytes32();
        values[mainnet]["dV2DAI"] = 0x6C3c78838c761c6Ac7bE9F59fe808ea2A6E4379d.toBytes32();
        values[mainnet]["aV2USDT"] = 0x3Ed3B47Dd13EC9a98b44e6204A523E766B225811.toBytes32();
        values[mainnet]["dV2USDT"] = 0x531842cEbbdD378f8ee36D171d6cC9C4fcf475Ec.toBytes32();

        // Aave V3 Tokens
        values[mainnet]["aV3WETH"] = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8.toBytes32();
        values[mainnet]["aV3USDC"] = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c.toBytes32();
        values[mainnet]["dV3USDC"] = 0x72E95b8931767C79bA4EeE721354d6E99a61D004.toBytes32();
        values[mainnet]["aV3DAI"] = 0x018008bfb33d285247A21d44E50697654f754e63.toBytes32();
        values[mainnet]["dV3DAI"] = 0xcF8d0c70c850859266f5C338b38F9D663181C314.toBytes32();
        values[mainnet]["dV3WETH"] = 0xeA51d7853EEFb32b6ee06b1C12E6dcCA88Be0fFE.toBytes32();
        values[mainnet]["aV3WBTC"] = 0x5Ee5bf7ae06D1Be5997A1A72006FE6C607eC6DE8.toBytes32();
        values[mainnet]["aV3USDT"] = 0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a.toBytes32();
        values[mainnet]["dV3USDT"] = 0x6df1C1E379bC5a00a7b4C6e67A203333772f45A8.toBytes32();
        values[mainnet]["aV3sDAI"] = 0x4C612E3B15b96Ff9A6faED838F8d07d479a8dD4c.toBytes32();
        values[mainnet]["aV3CrvUsd"] = 0xb82fa9f31612989525992FCfBB09AB22Eff5c85A.toBytes32();
        values[mainnet]["dV3CrvUsd"] = 0x028f7886F3e937f8479efaD64f31B3fE1119857a.toBytes32();
        values[mainnet]["aV3WeETH"] = 0xBdfa7b7893081B35Fb54027489e2Bc7A38275129.toBytes32();
        values[mainnet]["aRLUSD"] = 0xFa82580c16A31D0c1bC632A36F82e83EfEF3Eec0.toBytes32();

        // Balancer V2 Addresses
        values[mainnet]["BB_A_USD"] = 0xfeBb0bbf162E64fb9D0dfe186E517d84C395f016.toBytes32();
        values[mainnet]["BB_A_USD_V3"] = 0xc443C15033FCB6Cf72cC24f1BDA0Db070DdD9786.toBytes32();
        values[mainnet]["vanillaUsdcDaiUsdt"] = 0x79c58f70905F734641735BC61e45c19dD9Ad60bC.toBytes32();
        values[mainnet]["BB_A_WETH"] = 0x60D604890feaa0b5460B28A424407c24fe89374a.toBytes32();
        values[mainnet]["wstETH_bbaWETH"] = 0xE0fCBf4d98F0aD982DB260f86cf28b49845403C5.toBytes32();
        values[mainnet]["new_wstETH_bbaWETH"] = 0x41503C9D499ddbd1dCdf818a1b05e9774203Bf46.toBytes32();
        values[mainnet]["GHO_LUSD_BPT"] = 0x3FA8C89704e5d07565444009e5d9e624B40Be813.toBytes32();
        values[mainnet]["swETH_bbaWETH"] = 0xaE8535c23afeDdA9304B03c68a3563B75fc8f92b.toBytes32();
        values[mainnet]["swETH_wETH"] = 0x02D928E68D8F10C0358566152677Db51E1e2Dc8C.toBytes32();
        values[mainnet]["deUSD_sdeUSD_ECLP"] = 0x41FDbea2E52790c0a1Dc374F07b628741f2E062D.toBytes32();
        values[mainnet]["deUSD_sdeUSD_ECLP_Gauge"] = 0xA00DB7d9c465e95e4AA814A9340B9A161364470a.toBytes32();
        values[mainnet]["deUSD_sdeUSD_ECLP_id"] = 0x41fdbea2e52790c0a1dc374f07b628741f2e062d0002000000000000000006be;
        values[mainnet]["aura_deUSD_sdeUSD_ECLP"] = 0x7405Bf405185391525Ab06fABcdFf51fdc656A46.toBytes32();

        values[mainnet]["rETH_weETH_id"] = 0x05ff47afada98a98982113758878f9a8b9fdda0a000000000000000000000645;
        values[mainnet]["rETH_weETH"] = 0x05ff47AFADa98a98982113758878F9A8B9FddA0a.toBytes32();
        values[mainnet]["rETH_weETH_gauge"] = 0xC859BF9d7B8C557bBd229565124c2C09269F3aEF.toBytes32();
        values[mainnet]["aura_reth_weeth"] = 0x07A319A023859BbD49CC9C38ee891c3EA9283Cc5.toBytes32();

        values[mainnet]["ezETH_wETH"] = 0x596192bB6e41802428Ac943D2f1476C1Af25CC0E.toBytes32();
        values[mainnet]["ezETH_wETH_gauge"] = 0xa8B309a75f0D64ED632d45A003c68A30e59A1D8b.toBytes32();
        values[mainnet]["aura_ezETH_wETH"] = 0x95eC73Baa0eCF8159b4EE897D973E41f51978E50.toBytes32();

        values[mainnet]["rsETH_ETHx"] = 0x7761b6E0Daa04E70637D81f1Da7d186C205C2aDE.toBytes32();
        values[mainnet]["rsETH_ETHx_gauge"] = 0x0BcDb6d9b27Bd62d3De605393902C7d1a2c71Aab.toBytes32();
        values[mainnet]["aura_rsETH_ETHx"] = 0xf618102462Ff3cf7edbA4c067316F1C3AbdbA193.toBytes32();

        values[mainnet]["rETH_wETH_id"] = 0x1e19cf2d73a72ef1332c882f20534b6519be0276000200000000000000000112;
        values[mainnet]["rETH_wETH"] = 0x1E19CF2D73a72Ef1332C882F20534B6519Be0276.toBytes32();
        values[mainnet]["rETH_wETH_gauge"] = 0x79eF6103A513951a3b25743DB509E267685726B7.toBytes32();
        values[mainnet]["aura_reth_weth"] = 0xDd1fE5AD401D4777cE89959b7fa587e569Bf125D.toBytes32();

        values[mainnet]["rsETH_wETH_id"] = 0x58aadfb1afac0ad7fca1148f3cde6aedf5236b6d00000000000000000000067f;
        values[mainnet]["rsETH_wETH"] = 0x58AAdFB1Afac0ad7fca1148f3cdE6aEDF5236B6D.toBytes32();
        values[mainnet]["rsETH_wETH_gauge"] = 0xdf04E3a7ab9857a16FB97174e0f1001aa44380AF.toBytes32();
        values[mainnet]["aura_rsETH_wETH"] = 0xB5FdB4f75C26798A62302ee4959E4281667557E0.toBytes32();

        values[mainnet]["ezETH_weETH_rswETH"] = 0x848a5564158d84b8A8fb68ab5D004Fae11619A54.toBytes32();
        values[mainnet]["ezETH_weETH_rswETH_gauge"] = 0x253ED65fff980AEE7E94a0dC57BE304426048b35.toBytes32();
        values[mainnet]["aura_ezETH_weETH_rswETH"] = 0xce98eb8b2Fb98049b3F2dB0A212Ba7ca3Efd63b0.toBytes32();

        values[mainnet]["BAL_wETH"] = 0x5c6Ee304399DBdB9C8Ef030aB642B10820DB8F56.toBytes32();
        values[mainnet]["PENDLE_wETH"] = 0xFD1Cf6FD41F229Ca86ada0584c63C49C3d66BbC9.toBytes32();
        values[mainnet]["wETH_AURA"] = 0xCfCA23cA9CA720B6E98E3Eb9B6aa0fFC4a5C08B9.toBytes32();

        // values[mainnet]["ezETH_wETH"] = 0x596192bB6e41802428Ac943D2f1476C1Af25CC0E.toBytes32();
        // values[mainnet]["ezETH_wETH_gauge"] = 0xa8B309a75f0D64ED632d45A003c68A30e59A1D8b.toBytes32();
        // values[mainnet]["aura_ezETH_wETH"] = 0x95eC73Baa0eCF8159b4EE897D973E41f51978E50.toBytes32();

        // Balancer V3
        values[mainnet]["balancerV3Router"] = 0x5C6fb490BDFD3246EB0bB062c168DeCAF4bD9FDd.toBytes32();
        values[mainnet]["balancerV3Router2"] = 0xAE563E3f8219521950555F5962419C8919758Ea2.toBytes32();
        values[mainnet]["balancerV3Vault"] = 0xbA1333333333a1BA1108E8412f11850A5C319bA9.toBytes32();
        values[mainnet]["balancerV3VaultExplorer"] = 0x774cB66e2B2dB59A9daF175e9b2B7A142E17EB94.toBytes32();

        // Balancer V3 Pools & Gauges
        values[mainnet]["balancerV3_USDC_GHO_USDT"] = 0x85B2b559bC2D21104C4DEFdd6EFcA8A20343361D.toBytes32();
        values[mainnet]["balancerV3_USDC_GHO_USDT_gauge"] = 0x9fdD52eFEb601E4Bc78b89C6490505B8aC637E9f.toBytes32();
        values[mainnet]["aura_USDC_GHO_USDT_gauge"] = 0x8e89d41c563e6C3d9901ad75B75e2d8e140DEF04.toBytes32();
        values[mainnet]["balancerV3_WETH_WSTETH_boosted"] = 0xc4Ce391d82D164c166dF9c8336DDF84206b2F812.toBytes32();
        values[mainnet]["balancerV3_WSTETH_TETH_stablesurge"] = 0x9ED5175aeCB6653C1BDaa19793c16fd74fBeEB37.toBytes32();
        values[mainnet]["balancerV3_WETH_WSTETH_boosted_gauge"] = 0x4B891340b51889f438a03DC0e8aAAFB0Bc89e7A6.toBytes32();
        values[mainnet]["balancerV3_Surge_Fluid_wstETH-wETH_boosted"] =
            0x6b31a94029fd7840d780191B6D63Fa0D269bd883.toBytes32();
        values[mainnet]["balancerV3_Surge_Fluid_wstETH-wETH_boosted_gauge"] =
            0x1CCE9d493224A19FcB5f7fBade8478630141CB54.toBytes32();

        // Aura
        values[mainnet]["auraBooster"] = 0xA57b8d98dAE62B26Ec3bcC4a365338157060B234.toBytes32();

        // Linear Pools.
        values[mainnet]["bb_a_dai"] = 0x6667c6fa9f2b3Fc1Cc8D85320b62703d938E4385.toBytes32();
        values[mainnet]["bb_a_usdt"] = 0xA1697F9Af0875B63DdC472d6EeBADa8C1fAB8568.toBytes32();
        values[mainnet]["bb_a_usdc"] = 0xcbFA4532D8B2ade2C261D3DD5ef2A2284f792692.toBytes32();

        values[mainnet]["BB_A_USD_GAUGE"] = 0x0052688295413b32626D226a205b95cDB337DE86.toBytes32(); // query subgraph for gauges wrt to poolId: https://docs.balancer.fi/reference/vebal-and-gauges/gauges.html#query-gauge-by-l2-sidechain-pool:~:text=%23-,Query%20Pending%20Tokens%20for%20a%20Given%20Pool,-The%20process%20differs
        values[mainnet]["BB_A_USD_GAUGE_ADDRESS"] = 0x0052688295413b32626D226a205b95cDB337DE86.toBytes32();
        values[mainnet]["wstETH_bbaWETH_GAUGE_ADDRESS"] = 0x5f838591A5A8048F0E4C4c7fCca8fD9A25BF0590.toBytes32();

        // Mainnet Balancer Specific Addresses
        values[mainnet]["vault"] = 0xBA12222222228d8Ba445958a75a0704d566BF2C8.toBytes32();
        values[mainnet]["balancerVault"] = 0xBA12222222228d8Ba445958a75a0704d566BF2C8.toBytes32();
        values[mainnet]["relayer"] = 0xfeA793Aa415061C483D2390414275AD314B3F621.toBytes32();
        values[mainnet]["minter"] = 0x239e55F427D44C3cc793f49bFB507ebe76638a2b.toBytes32();
        values[mainnet]["USDC_DAI_USDT_BPT"] = 0x79c58f70905F734641735BC61e45c19dD9Ad60bC.toBytes32();
        values[mainnet]["rETH_wETH_BPT"] = 0x1E19CF2D73a72Ef1332C882F20534B6519Be0276.toBytes32();
        values[mainnet]["wstETH_wETH_BPT"] = 0x32296969Ef14EB0c6d29669C550D4a0449130230.toBytes32();
        values[mainnet]["wstETH_cbETH_BPT"] = 0x9c6d47Ff73e0F5E51BE5FD53236e3F595C5793F2.toBytes32();
        values[mainnet]["bb_a_USD_BPT"] = 0xfeBb0bbf162E64fb9D0dfe186E517d84C395f016.toBytes32();
        values[mainnet]["bb_a_USDC_BPT"] = 0xcbFA4532D8B2ade2C261D3DD5ef2A2284f792692.toBytes32();
        values[mainnet]["bb_a_DAI_BPT"] = 0x6667c6fa9f2b3Fc1Cc8D85320b62703d938E4385.toBytes32();
        values[mainnet]["bb_a_USDT_BPT"] = 0xA1697F9Af0875B63DdC472d6EeBADa8C1fAB8568.toBytes32();
        values[mainnet]["aura_rETH_wETH_BPT"] = 0xDd1fE5AD401D4777cE89959b7fa587e569Bf125D.toBytes32();
        values[mainnet]["GHO_bb_a_USD_BPT"] = 0xc2B021133D1b0cF07dba696fd5DD89338428225B.toBytes32();

        values[mainnet]["wstETH_wETH_BPT"] = 0x93d199263632a4EF4Bb438F1feB99e57b4b5f0BD.toBytes32();
        values[mainnet]["wstETH_wETH_Id"] = 0x93d199263632a4ef4bb438f1feb99e57b4b5f0bd0000000000000000000005c2;
        values[mainnet]["wstETH_wETH_Gauge"] = 0x5C0F23A5c1be65Fa710d385814a7Fd1Bda480b1C.toBytes32();
        values[mainnet]["aura_wstETH_wETH"] = 0x2a14dB8D09dB0542f6A371c0cB308A768227D67D.toBytes32();

        // Rate Providers
        values[mainnet]["cbethRateProvider"] = 0x7311E4BB8a72e7B300c5B8BDE4de6CdaA822a5b1.toBytes32();
        values[mainnet]["rethRateProvider"] = 0x1a8F81c256aee9C640e14bB0453ce247ea0DFE6F.toBytes32();
        values[mainnet]["sDaiRateProvider"] = 0xc7177B6E18c1Abd725F5b75792e5F7A3bA5DBC2c.toBytes32();
        values[mainnet]["rsETHRateProvider"] = 0x746df66bc1Bb361b9E8E2a794C299c3427976e6C.toBytes32();

        // Compound V2
        // Cvalues[mainnet]["cDAI"] = C0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643.toBytes32();
        // Cvalues[mainnet]["cUSDC"] = C0x39AA39c021dfbaE8faC545936693aC917d5E7563.toBytes32();
        // Cvalues[mainnet]["cTUSD"] = C0x12392F67bdf24faE0AF363c24aC620a2f67DAd86.toBytes32();

        // Chainlink Automation Registry
        values[mainnet]["automationRegistry"] = 0x02777053d6764996e594c3E88AF1D58D5363a2e6.toBytes32();
        values[mainnet]["automationRegistryV2"] = 0x6593c7De001fC8542bB1703532EE1E5aA0D458fD.toBytes32();
        values[mainnet]["automationRegistrarV2"] = 0x6B0B234fB2f380309D47A7E9391E29E9a179395a.toBytes32();

        // FraxLend Pairs
        values[mainnet]["FXS_FRAX_PAIR"] = 0xDbe88DBAc39263c47629ebbA02b3eF4cf0752A72.toBytes32();
        values[mainnet]["FPI_FRAX_PAIR"] = 0x74F82Bd9D0390A4180DaaEc92D64cf0708751759.toBytes32();
        values[mainnet]["SFRXETH_FRAX_PAIR"] = 0x78bB3aEC3d855431bd9289fD98dA13F9ebB7ef15.toBytes32();
        values[mainnet]["CRV_FRAX_PAIR"] = 0x3835a58CA93Cdb5f912519ad366826aC9a752510.toBytes32(); // FraxlendV1
        values[mainnet]["WBTC_FRAX_PAIR"] = 0x32467a5fc2d72D21E8DCe990906547A2b012f382.toBytes32(); // FraxlendV1
        values[mainnet]["WETH_FRAX_PAIR"] = 0x794F6B13FBd7EB7ef10d1ED205c9a416910207Ff.toBytes32(); // FraxlendV1
        values[mainnet]["CVX_FRAX_PAIR"] = 0xa1D100a5bf6BFd2736837c97248853D989a9ED84.toBytes32(); // FraxlendV1
        values[mainnet]["MKR_FRAX_PAIR"] = 0x82Ec28636B77661a95f021090F6bE0C8d379DD5D.toBytes32(); // FraxlendV2
        values[mainnet]["APE_FRAX_PAIR"] = 0x3a25B9aB8c07FfEFEe614531C75905E810d8A239.toBytes32(); // FraxlendV2
        values[mainnet]["UNI_FRAX_PAIR"] = 0xc6CadA314389430d396C7b0C70c6281e99ca7fe8.toBytes32(); // FraxlendV2

        /// From Crispy's curve tests

        // Curve Pools and Tokens
        values[mainnet]["TriCryptoPool"] = 0xD51a44d3FaE010294C616388b506AcdA1bfAAE46.toBytes32();
        values[mainnet]["CRV_3_CRYPTO"] = 0xc4AD29ba4B3c580e6D59105FFf484999997675Ff.toBytes32();
        values[mainnet]["daiUsdcUsdtPool"] = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7.toBytes32();
        values[mainnet]["CRV_DAI_USDC_USDT"] = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490.toBytes32();
        values[mainnet]["frax3CrvPool"] = 0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B.toBytes32();
        values[mainnet]["CRV_FRAX_3CRV"] = 0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B.toBytes32();
        values[mainnet]["wethCrvPool"] = 0x8301AE4fc9c624d1D396cbDAa1ed877821D7C511.toBytes32();
        values[mainnet]["CRV_WETH_CRV"] = 0xEd4064f376cB8d68F770FB1Ff088a3d0F3FF5c4d.toBytes32();
        values[mainnet]["aave3Pool"] = 0xDeBF20617708857ebe4F679508E7b7863a8A8EeE.toBytes32();
        values[mainnet]["CRV_AAVE_3CRV"] = 0xFd2a8fA60Abd58Efe3EeE34dd494cD491dC14900.toBytes32();
        values[mainnet]["stETHWethNg"] = 0x21E27a5E5513D6e65C4f830167390997aA84843a.toBytes32();
        values[mainnet]["EthFrxEthCurvePool"] = 0xa1F8A6807c402E4A15ef4EBa36528A3FED24E577.toBytes32();
        values[mainnet]["triCrypto2"] = 0xD51a44d3FaE010294C616388b506AcdA1bfAAE46.toBytes32();
        values[mainnet]["weETH_wETH_ng"] = 0xDB74dfDD3BB46bE8Ce6C33dC9D82777BCFc3dEd5.toBytes32();
        values[mainnet]["weETH_wETH_ng_gauge"] = 0x053df3e4D0CeD9a3Bf0494F97E83CE1f13BdC0E2.toBytes32();
        values[mainnet]["USD0_USD0++_CurvePool"] = 0x1d08E7adC263CfC70b1BaBe6dC5Bb339c16Eec52.toBytes32();
        values[mainnet]["USD0_USD0++_CurveGauge"] = 0x5C00817B67b40f3b347bD4275B4BBA4840c8127a.toBytes32();

        values[mainnet]["UsdcCrvUsdPool"] = 0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E.toBytes32();
        values[mainnet]["UsdcCrvUsdToken"] = 0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E.toBytes32();
        values[mainnet]["UsdcCrvUsdGauge"] = 0x95f00391cB5EebCd190EB58728B4CE23DbFa6ac1.toBytes32();
        values[mainnet]["WethRethPool"] = 0x0f3159811670c117c372428D4E69AC32325e4D0F.toBytes32();
        values[mainnet]["WethRethToken"] = 0x6c38cE8984a890F5e46e6dF6117C26b3F1EcfC9C.toBytes32();
        values[mainnet]["WethRethGauge"] = 0x9d4D981d8a9066f5db8532A5816543dE8819d4A8.toBytes32();
        values[mainnet]["UsdtCrvUsdPool"] = 0x390f3595bCa2Df7d23783dFd126427CCeb997BF4.toBytes32();
        values[mainnet]["UsdtCrvUsdToken"] = 0x390f3595bCa2Df7d23783dFd126427CCeb997BF4.toBytes32();
        values[mainnet]["UsdtCrvUsdGauge"] = 0x4e6bB6B7447B7B2Aa268C16AB87F4Bb48BF57939.toBytes32();
        values[mainnet]["EthStethPool"] = 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022.toBytes32();
        values[mainnet]["EthStethToken"] = 0x06325440D014e39736583c165C2963BA99fAf14E.toBytes32();
        values[mainnet]["EthStethGauge"] = 0x182B723a58739a9c974cFDB385ceaDb237453c28.toBytes32();
        values[mainnet]["FraxUsdcPool"] = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2.toBytes32();
        values[mainnet]["FraxUsdcToken"] = 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC.toBytes32();
        values[mainnet]["FraxUsdcGauge"] = 0xCFc25170633581Bf896CB6CDeE170e3E3Aa59503.toBytes32();
        values[mainnet]["WethFrxethPool"] = 0x9c3B46C0Ceb5B9e304FCd6D88Fc50f7DD24B31Bc.toBytes32();
        values[mainnet]["WethFrxethToken"] = 0x9c3B46C0Ceb5B9e304FCd6D88Fc50f7DD24B31Bc.toBytes32();
        values[mainnet]["WethFrxethGauge"] = 0x4E21418095d32d15c6e2B96A9910772613A50d50.toBytes32();
        values[mainnet]["EthFrxethPool"] = 0xa1F8A6807c402E4A15ef4EBa36528A3FED24E577.toBytes32();
        values[mainnet]["EthFrxethToken"] = 0xf43211935C781D5ca1a41d2041F397B8A7366C7A.toBytes32();
        values[mainnet]["EthFrxethGauge"] = 0x2932a86df44Fe8D2A706d8e9c5d51c24883423F5.toBytes32();
        values[mainnet]["StethFrxethPool"] = 0x4d9f9D15101EEC665F77210cB999639f760F831E.toBytes32();
        values[mainnet]["StethFrxethToken"] = 0x4d9f9D15101EEC665F77210cB999639f760F831E.toBytes32();
        values[mainnet]["StethFrxethGauge"] = 0x821529Bb07c83803C9CC7763e5974386e9eFEdC7.toBytes32();
        values[mainnet]["WethCvxPool"] = 0xB576491F1E6e5E62f1d8F26062Ee822B40B0E0d4.toBytes32();
        values[mainnet]["WethCvxToken"] = 0x3A283D9c08E8b55966afb64C515f5143cf907611.toBytes32();
        values[mainnet]["WethCvxGauge"] = 0x7E1444BA99dcdFfE8fBdb42C02F0005D14f13BE1.toBytes32();
        values[mainnet]["EthStethNgPool"] = 0x21E27a5E5513D6e65C4f830167390997aA84843a.toBytes32();
        values[mainnet]["EthStethNgToken"] = 0x21E27a5E5513D6e65C4f830167390997aA84843a.toBytes32();
        values[mainnet]["EthStethNgGauge"] = 0x79F21BC30632cd40d2aF8134B469a0EB4C9574AA.toBytes32();
        values[mainnet]["EthOethPool"] = 0x94B17476A93b3262d87B9a326965D1E91f9c13E7.toBytes32();
        values[mainnet]["EthOethToken"] = 0x94B17476A93b3262d87B9a326965D1E91f9c13E7.toBytes32();
        values[mainnet]["EthOethGauge"] = 0xd03BE91b1932715709e18021734fcB91BB431715.toBytes32();
        values[mainnet]["FraxCrvUsdPool"] = 0x0CD6f267b2086bea681E922E19D40512511BE538.toBytes32();
        values[mainnet]["FraxCrvUsdToken"] = 0x0CD6f267b2086bea681E922E19D40512511BE538.toBytes32();
        values[mainnet]["FraxCrvUsdGauge"] = 0x96424E6b5eaafe0c3B36CA82068d574D44BE4e3c.toBytes32();
        values[mainnet]["mkUsdFraxUsdcPool"] = 0x0CFe5C777A7438C9Dd8Add53ed671cEc7A5FAeE5.toBytes32();
        values[mainnet]["mkUsdFraxUsdcToken"] = 0x0CFe5C777A7438C9Dd8Add53ed671cEc7A5FAeE5.toBytes32();
        values[mainnet]["mkUsdFraxUsdcGauge"] = 0xF184d80915Ba7d835D941BA70cDdf93DE36517ee.toBytes32();
        values[mainnet]["WethYethPool"] = 0x69ACcb968B19a53790f43e57558F5E443A91aF22.toBytes32();
        values[mainnet]["WethYethToken"] = 0x69ACcb968B19a53790f43e57558F5E443A91aF22.toBytes32();
        values[mainnet]["WethYethGauge"] = 0x138cC21D15b7A06F929Fc6CFC88d2b830796F4f1.toBytes32();
        values[mainnet]["EthEthxPool"] = 0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492.toBytes32();
        values[mainnet]["EthEthxToken"] = 0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492.toBytes32();
        values[mainnet]["EthEthxGauge"] = 0x7671299eA7B4bbE4f3fD305A994e6443b4be680E.toBytes32();
        values[mainnet]["CrvUsdSdaiPool"] = 0x1539c2461d7432cc114b0903f1824079BfCA2C92.toBytes32();
        values[mainnet]["CrvUsdSdaiToken"] = 0x1539c2461d7432cc114b0903f1824079BfCA2C92.toBytes32();
        values[mainnet]["CrvUsdSdaiGauge"] = 0x2B5a5e182768a18C70EDd265240578a72Ca475ae.toBytes32();
        values[mainnet]["CrvUsdSfraxPool"] = 0xfEF79304C80A694dFd9e603D624567D470e1a0e7.toBytes32();
        values[mainnet]["CrvUsdSfraxToken"] = 0xfEF79304C80A694dFd9e603D624567D470e1a0e7.toBytes32();
        values[mainnet]["CrvUsdSfraxGauge"] = 0x62B8DA8f1546a092500c457452fC2d45fa1777c4.toBytes32();
        values[mainnet]["LusdCrvUsdPool"] = 0x9978c6B08d28d3B74437c917c5dD7C026df9d55C.toBytes32();
        values[mainnet]["LusdCrvUsdToken"] = 0x9978c6B08d28d3B74437c917c5dD7C026df9d55C.toBytes32();
        values[mainnet]["LusdCrvUsdGauge"] = 0x66F65323bdE835B109A92045Aa7c655559dbf863.toBytes32();
        values[mainnet]["WstethEthXPool"] = 0x14756A5eD229265F86990e749285bDD39Fe0334F.toBytes32();
        values[mainnet]["WstethEthXToken"] = 0xfffAE954601cFF1195a8E20342db7EE66d56436B.toBytes32();
        values[mainnet]["WstethEthXGauge"] = 0xc1394d6c89cf8F553da8c8256674C778ccFf3E80.toBytes32();
        values[mainnet]["EthEthXPool"] = 0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492.toBytes32();
        values[mainnet]["EthEthXToken"] = 0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492.toBytes32();
        values[mainnet]["EthEthXGauge"] = 0x7671299eA7B4bbE4f3fD305A994e6443b4be680E.toBytes32();
        values[mainnet]["weETH_wETH_Curve_LP"] = 0x13947303F63b363876868D070F14dc865C36463b.toBytes32();
        values[mainnet]["weETH_wETH_Curve_Gauge"] = 0x1CAC1a0Ed47E2e0A313c712b2dcF85994021a365.toBytes32();
        values[mainnet]["weETH_wETH_Convex_Reward"] = 0x2D159E01A5cEe7498F84Be68276a5266b3cb3774.toBytes32();

        values[mainnet]["weETH_wETH_Pool"] = 0x13947303F63b363876868D070F14dc865C36463b.toBytes32();
        values[mainnet]["weETH_wETH_NG_Pool"] = 0xDB74dfDD3BB46bE8Ce6C33dC9D82777BCFc3dEd5.toBytes32();
        values[mainnet]["weETH_wETH_NG_Convex_Reward"] = 0x5411CC583f0b51104fA523eEF9FC77A29DF80F58.toBytes32();

        values[mainnet]["pyUsd_Usdc_Curve_Pool"] = 0x383E6b4437b59fff47B619CBA855CA29342A8559.toBytes32();
        values[mainnet]["pyUsd_Usdc_Curve_Gauge"] = 0x9da75997624C697444958aDeD6790bfCa96Af19A.toBytes32();
        values[mainnet]["pyUsd_Usdc_Convex_Id"] = address(270).toBytes32();
        values[mainnet]["frax_Usdc_Curve_Pool"] = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2.toBytes32();
        values[mainnet]["frax_Usdc_Convex_Id"] = address(100).toBytes32();
        values[mainnet]["usdc_CrvUsd_Curve_Pool"] = 0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E.toBytes32();
        values[mainnet]["usdc_CrvUsd_Convex_Id"] = address(182).toBytes32();
        values[mainnet]["sDai_sUsde_Curve_Pool"] = 0x167478921b907422F8E88B43C4Af2B8BEa278d3A.toBytes32();
        values[mainnet]["sDai_sUsde_Curve_Gauge"] = 0x330Cfd12e0E97B0aDF46158D2A81E8Bd2985c6cB.toBytes32();

        values[mainnet]["USDC_RLUSD_Curve_Pool"] = 0xD001aE433f254283FeCE51d4ACcE8c53263aa186.toBytes32();
        values[mainnet]["USDC_RLUSD_Curve_Gauge"] = 0xFc3212Bd9Ad9A28Da6B2bd50a2918969C126894F.toBytes32();

        //FXUSD_USDC
        values[mainnet]["fxUSD_USDC_Curve_Pool"] = 0x5018BE882DccE5E3F2f3B0913AE2096B9b3fB61f.toBytes32();
        values[mainnet]["fxUSD_USDC_Curve_Gauge"] = 0xD7f9111D529ed8859A0d5A1DC1BA7a021b61f22A.toBytes32();

        //FXUSD_GHO
        values[mainnet]["FXUSD_GHO_Curve_Pool"] = 0x74345504Eaea3D9408fC69Ae7EB2d14095643c5b.toBytes32(); //lp token
        values[mainnet]["FXUSD_GHO_Curve_Gauge"] = 0xec303960CF0456aC304Af45C0aDDe34921a10Fdf.toBytes32();
        values[mainnet]["FXUSD_GHO_Convex_Rewards"] = 0x77e69Dc146C6044b996ad5c93D88D104Ee13F186.toBytes32();

        //WETH_PXETH
        values[mainnet]["WETH_PXETH_Curve_Pool"] = 0xC8Eb2Cf2f792F77AF0Cd9e203305a585E588179D.toBytes32();
        values[mainnet]["WETH_PXETH_Curve_Gauge"] = 0xABaD903647511a0EC755a118849f733f7d2Ba002.toBytes32();
        values[mainnet]["WETH_PXETH_Convex_Rewards"] = 0x3B793E505A3C7dbCb718Fe871De8eBEf7854e74b.toBytes32();

        //STETH_PXETH
        values[mainnet]["STETH_PXETH_Curve_Pool"] = 0x6951bDC4734b9f7F3E1B74afeBC670c736A0EDB6.toBytes32();
        values[mainnet]["STETH_PXETH_Curve_Gauge"] = 0x58215F083882A5eb7056Ac34a0fdDA9D3b5665d2.toBytes32();
        values[mainnet]["STETH_PXETH_Convex_Rewards"] = 0x633556C8413FCFd45D83656290fF8d64EE41A7c1.toBytes32();

        //TBTC_EBTC
        values[mainnet]["TBTC_EBTC_Curve_Pool"] = 0x272BF7e4Ce3308B1Fb5e54d6a1Fc32113619c401.toBytes32(); //lp token
        values[mainnet]["TBTC_EBTC_Curve_Gauge"] = 0x48727018D010Dc2e414C5A14D588385Ae112869e.toBytes32();
        values[mainnet]["TBTC_EBTC_Convex_Rewards"] = 0xDbd17Dc03a442D4349de988533737db3fBb5eC39.toBytes32();

        //TBTC/CBBTC
        values[mainnet]["TBTC_CBBTC_Curve_Pool"] = 0xAE6Ee608b297305AbF3EB609B81FEBbb8F6A0bb3.toBytes32(); //lp token
        values[mainnet]["TBTC_CBBTC_Curve_Gauge"] = 0xc11B5bAD6Ef7b1BDC90c85d5498a91D7F19B5806.toBytes32();
        values[mainnet]["TBTC_CBBTC_Convex_Rewards"] = 0xB683a3D855D016A1c78c3e7887812A7CAB3989B0.toBytes32();

        //frxUSD/FRAX
        values[mainnet]["frxUSD_FRAX_Curve_Pool"] = 0xBBaf8B2837CBbc7146F5bC978D6F84db0BE1CAcc.toBytes32();

        //frxUSD/SUSDS
        values[mainnet]["frxUSD_SUSDS_Curve_Pool"] = 0x81A2612F6dEA269a6Dd1F6DeAb45C5424EE2c4b7.toBytes32();
        values[mainnet]["frxUSD_SUSDS_Curve_Gauge"] = 0x52618C40dDBA3cBbb69F3aAA4CB26Ae649844B17.toBytes32();
        values[mainnet]["frxUSD_SUSDS_Convex_Rewards"] = 0x44be1A72619eDDDccAb744eE9e1E69A0B639F85f.toBytes32();

        //frxUSD/USDE
        values[mainnet]["frxUSD_USDE_Curve_Pool"] = 0xdBb1d219d84eaCEFb850ee04caCf2f1830934580.toBytes32();
        values[mainnet]["frxUSD_USDE_Curve_Gauge"] = 0xbD7ddCe4D5a97F102DE674Ef56823b600e843C8A.toBytes32();
        values[mainnet]["frxUSD_USDE_Convex_Rewards"] = 0xb5a97cFB06f9005005a79dAA27EB44106b7ad79A.toBytes32();

        //triBTCFi
        values[mainnet]["triBTCFi_Curve_Pool"] = 0xabaf76590478F2fE0b396996f55F0b61101e9502.toBytes32();
        values[mainnet]["triBTCFi_Curve_Gauge"] = 0x8D666daED20B502e5Cf692B101028fc0058a5d4E.toBytes32();

        values[mainnet]["ezETH_wETH_Curve_Pool"] = 0x85dE3ADd465a219EE25E04d22c39aB027cF5C12E.toBytes32();
        values[mainnet]["weETH_rswETH_Curve_Pool"] = 0x278cfB6f06B1EFc09d34fC7127d6060C61d629Db.toBytes32();
        values[mainnet]["rswETH_wETH_Curve_Pool"] = 0xeE04382c4cA6c450213923fE0f0daB19b0ff3939.toBytes32();
        values[mainnet]["USDe_USDC_Curve_Pool"] = 0x02950460E2b9529D0E00284A5fA2d7bDF3fA4d72.toBytes32();
        values[mainnet]["USDe_DAI_Curve_Pool"] = 0xF36a4BA50C603204c3FC6d2dA8b78A7b69CBC67d.toBytes32();
        values[mainnet]["sDAI_sUSDe_Curve_Pool"] = 0x167478921b907422F8E88B43C4Af2B8BEa278d3A.toBytes32();
        values[mainnet]["deUSD_USDC_Curve_Pool"] = 0x5F6c431AC417f0f430B84A666a563FAbe681Da94.toBytes32();
        values[mainnet]["deUSD_USDT_Curve_Pool"] = 0x7C4e143B23D72E6938E06291f705B5ae3D5c7c7C.toBytes32();
        values[mainnet]["deUSD_DAI_Curve_Pool"] = 0xb478Bf40dD622086E0d0889eeBbAdCb63806ADde.toBytes32();
        values[mainnet]["deUSD_FRAX_Curve_Pool"] = 0x88DFb9370fE350aA51ADE31C32549d4d3A24fAf2.toBytes32();
        values[mainnet]["deUSD_FRAX_Curve_Gauge"] = 0x7C634909DDbfd5C6EEd7Ccf3611e8C4f3643635d.toBytes32();
        values[mainnet]["eBTC_LBTC_WBTC_Curve_Pool"] = 0xabaf76590478F2fE0b396996f55F0b61101e9502.toBytes32();
        values[mainnet]["eBTC_LBTC_WBTC_Curve_Gauge"] = 0x8D666daED20B502e5Cf692B101028fc0058a5d4E.toBytes32();

        values[mainnet]["lBTC_wBTC_Curve_Pool"] = 0x2f3bC4c27A4437AeCA13dE0e37cdf1028f3706F0.toBytes32();

        values[mainnet]["WethMkUsdPool"] = 0xc89570207c5BA1B0E3cD372172cCaEFB173DB270.toBytes32();

        // Convex-Curve Platform Specifics
        values[mainnet]["convexCurveMainnetBooster"] = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31.toBytes32();
        values[mainnet]["convexCurveMainnetRewardsContract"] = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31.toBytes32();
        values[mainnet]["convexFXPoolRegistry"] = 0xdB95d646012bB87aC2E6CD63eAb2C42323c1F5AF.toBytes32();
        values[mainnet]["convexFXBooster"] = 0xAffe966B27ba3E4Ebb8A0eC124C7b7019CC762f8.toBytes32();

        values[mainnet]["convexFX_gauge_USDC_fxUSD"] = 0xf1E141C804BA39b4a031fDF46e8c08dBa7a0df60.toBytes32();
        values[mainnet]["convexFX_lp_USDC_fxUSD"] = 0x5018BE882DccE5E3F2f3B0913AE2096B9b3fB61f.toBytes32();

        values[mainnet]["convexFX_gauge_fxUSD_GHO"] = 0xf0A3ECed42Dbd8353569639c0eaa833857aA0A75.toBytes32();
        values[mainnet]["convexFX_lp_fxUSD_GHO"] = 0x74345504Eaea3D9408fC69Ae7EB2d14095643c5b.toBytes32();

        values[mainnet]["ethFrxethBaseRewardPool"] = 0xbD5445402B0a287cbC77cb67B2a52e2FC635dce4.toBytes32();
        values[mainnet]["ethStethNgBaseRewardPool"] = 0x6B27D7BC63F1999D14fF9bA900069ee516669ee8.toBytes32();
        values[mainnet]["fraxCrvUsdBaseRewardPool"] = 0x3CfB4B26dc96B124D15A6f360503d028cF2a3c00.toBytes32();
        values[mainnet]["mkUsdFraxUsdcBaseRewardPool"] = 0x35FbE5520E70768DCD6E3215Ed54E14CBccA10D2.toBytes32();
        values[mainnet]["wethYethBaseRewardPool"] = 0xB0867ADE998641Ab1Ff04cF5cA5e5773fA92AaE3.toBytes32();
        values[mainnet]["ethEthxBaseRewardPool"] = 0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20.toBytes32();
        values[mainnet]["crvUsdSFraxBaseRewardPool"] = 0x73eA73C3a191bd05F3266eB2414609dC5Fe777a2.toBytes32();
        values[mainnet]["usdtCrvUsdBaseRewardPool"] = 0xD1DdB0a0815fD28932fBb194C84003683AF8a824.toBytes32();
        values[mainnet]["lusdCrvUsdBaseRewardPool"] = 0x633D3B227696B3FacF628a197f982eF68d26c7b5.toBytes32();
        values[mainnet]["wstethEthxBaseRewardPool"] = 0x85b118e0Fa5706d99b270be43d782FBE429aD409.toBytes32();

        // Uniswap V3
        values[mainnet]["WSTETH_WETH_100"] = 0x109830a1AAaD605BbF02a9dFA7B0B92EC2FB7dAa.toBytes32();
        values[mainnet]["WSTETH_WETH_500"] = 0xD340B57AAcDD10F96FC1CF10e15921936F41E29c.toBytes32();
        values[mainnet]["DAI_USDC_100"] = 0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168.toBytes32();
        values[mainnet]["uniswapV3NonFungiblePositionManager"] = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88.toBytes32();

        // Uniswap V4
        values[mainnet]["uniV4UniversalRouter"] = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af.toBytes32();
        values[mainnet]["uniswapV4PositionManager"] = 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e.toBytes32();
        // Redstone
        values[mainnet]["swEthAdapter"] = 0x68ba9602B2AeE30847412109D2eE89063bf08Ec2.toBytes32();
        values[mainnet]["swEthDataFeedId"] = 0x5357455448000000000000000000000000000000000000000000000000000000;
        values[mainnet]["swEthEthDataFeedId"] = 0x53574554482f4554480000000000000000000000000000000000000000000000;

        values[mainnet]["ethXEthAdapter"] = 0xc799194cAa24E2874Efa89b4Bf5c92a530B047FF.toBytes32();
        values[mainnet]["ethXEthDataFeedId"] = 0x455448782f455448000000000000000000000000000000000000000000000000;

        values[mainnet]["ethXAdapter"] = 0xF3eB387Ac1317fBc7E2EFD82214eE1E148f0Fe00.toBytes32();
        values[mainnet]["ethXUsdDataFeedId"] = 0x4554487800000000000000000000000000000000000000000000000000000000;

        values[mainnet]["weEthEthAdapter"] = 0x8751F736E94F6CD167e8C5B97E245680FbD9CC36.toBytes32();
        values[mainnet]["weEthDataFeedId"] = 0x77654554482f4554480000000000000000000000000000000000000000000000;
        values[mainnet]["weethAdapter"] = 0xdDb6F90fFb4d3257dd666b69178e5B3c5Bf41136.toBytes32();
        values[mainnet]["weethUsdDataFeedId"] = 0x7765455448000000000000000000000000000000000000000000000000000000;

        values[mainnet]["osEthEthAdapter"] = 0x66ac817f997Efd114EDFcccdce99F3268557B32C.toBytes32();
        values[mainnet]["osEthEthDataFeedId"] = 0x6f734554482f4554480000000000000000000000000000000000000000000000;

        values[mainnet]["rsEthEthAdapter"] = 0xA736eAe8805dDeFFba40cAB8c99bCB309dEaBd9B.toBytes32();
        values[mainnet]["rsEthEthDataFeedId"] = 0x72734554482f4554480000000000000000000000000000000000000000000000;

        values[mainnet]["ezEthEthAdapter"] = 0xF4a3e183F59D2599ee3DF213ff78b1B3b1923696.toBytes32();
        values[mainnet]["ezEthEthDataFeedId"] = 0x657a4554482f4554480000000000000000000000000000000000000000000000;

        // Maker
        values[mainnet]["dsrManager"] = 0x373238337Bfe1146fb49989fc222523f83081dDb.toBytes32();

        // Maker
        values[mainnet]["savingsDaiAddress"] = 0x83F20F44975D03b1b09e64809B757c47f942BEeA.toBytes32();
        values[mainnet]["sDAI"] = 0x83F20F44975D03b1b09e64809B757c47f942BEeA.toBytes32();

        // Frax
        values[mainnet]["sFRAX"] = 0xA663B02CF0a4b149d2aD41910CB81e23e1c41c32.toBytes32();

        // Lido
        values[mainnet]["unstETH"] = 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1.toBytes32();

        // Stader
        values[mainnet]["stakePoolManagerAddress"] = 0xcf5EA1b38380f6aF39068375516Daf40Ed70D299.toBytes32();
        values[mainnet]["userWithdrawManagerAddress"] = 0x9F0491B32DBce587c50c4C43AB303b06478193A7.toBytes32();
        values[mainnet]["staderConfig"] = 0x4ABEF2263d5A5ED582FC9A9789a41D85b68d69DB.toBytes32();

        // Etherfi
        values[mainnet]["EETH_LIQUIDITY_POOL"] = 0x308861A430be4cce5502d0A12724771Fc6DaF216.toBytes32();
        values[mainnet]["withdrawalRequestNft"] = 0x7d5706f6ef3F89B3951E23e557CDFBC3239D4E2c.toBytes32();
        values[mainnet]["etherFiVampirePool"] = 0x9FFDF407cDe9a93c47611799DA23924Af3EF764F.toBytes32();

        // Renzo
        values[mainnet]["restakeManager"] = 0x74a09653A083691711cF8215a6ab074BB4e99ef5.toBytes32();

        // Kelp DAO
        values[mainnet]["lrtDepositPool"] = 0x036676389e48133B63a802f8635AD39E752D375D.toBytes32();
        // Compound V3
        values[mainnet]["cUSDCV3"] = 0xc3d688B66703497DAA19211EEdff47f25384cdc3.toBytes32();
        values[mainnet]["cUSDTV3"] = 0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840.toBytes32();
        values[mainnet]["cWETHV3"] = 0xA17581A9E3356d9A858b789D68B4d866e593aE94.toBytes32();
        values[mainnet]["cometRewards"] = 0x1B0e765F6224C21223AeA2af16c1C46E38885a40.toBytes32();
        // Morpho Blue
        values[mainnet]["morphoBlue"] = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb.toBytes32();
        values[mainnet]["ezEthOracle"] = 0x61025e2B0122ac8bE4e37365A4003d87ad888Cc3.toBytes32();
        values[mainnet]["ezEthIrm"] = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC.toBytes32();
        values[mainnet]["weETH_wETH_86_market"] = 0x698fe98247a40c5771537b5786b2f3f9d78eb487b4ce4d75533cd0e94d88a115;
        values[mainnet]["LBTC_WBTC_945"] = 0xf6a056627a51e511ec7f48332421432ea6971fc148d8f3c451e14ea108026549;
        values[mainnet]["sUSDePT03_USDC_915"] = 0x346afa2b6d528222a2f9721ded6e7e2c40ac94877a598f5dae5013c651d2a462;
        values[mainnet]["USD0_plusPT03_USDC_915"] = 0x8411eeb07c8e32de0b3784b6b967346a45593bfd8baeb291cc209dc195c7b3ad;
        values[mainnet]["sUSDePT_03_27_DAI_915"] = 0x5e3e6b1e01c5708055548d82d01db741e37d03b948a7ef9f3d4b962648bcbfa7;
        values[mainnet]["eUSDePT_05_28_25_USDC_915"] =
            0x21e55c99123958ff5667f824948c97d0f64dfaa6e2848062e72bc68d200d35f9;
        values[mainnet]["eUSDePT_05_28_25_DAI_915"] = 0xae4571cdcad4191b9a59d1bb27a10a1b05c92c84fe423e4886d5781a30a9c8f1;
        values[mainnet]["syrupUSDC_USDC_915"] = 0x729badf297ee9f2f6b3f717b96fd355fc6ec00422284ce1968e76647b258cf44;

        values[mainnet]["WBTC_USDC_86"] = 0x3a85e619751152991742810df6ec69ce473daef99e28a64ab2340d7b7ccfee49;
        values[mainnet]["WBTC_USDT_86"] = 0xa921ef34e2fc7a27ccc50ae7e4b154e16c9799d3387076c421423ef52ac4df99;
        values[mainnet]["Corn_eBTC_PT03_LBTC_915"] = 0x17af0be1f59e3eb8e3de2ed7655ed544c9465d089f21b89c465874a6447f2590;
        values[mainnet]["LBTC_PT03_LBTC_915"] = 0x3170feb9e3c0172beb9901f6035e4e005f42177c5c14e8c0538c27078864654e;
        values[mainnet]["LBTC_PT03_WBTC_915"] = 0xa39263bf7275f772863c464ef4e9e972aaa0f1a6a1bf2a47f92bf57a542d2458;
        values[mainnet]["LBTC_PT03_WBTC_86"] = 0x198132864e7974fb451dfebeb098b3b7e7e65566667fb1cf1116db4fb2ad23f9;
        values[mainnet]["EBTC_USDC_86"] = 0xb6f4eebd60871f99bf464ae0b67045a26797cf7ef57c458d57e08c205f84feac;
        values[mainnet]["wstUSR_PT03_USR_915"] = 0x1e1ae51d4be670307788612599a46a73649ef85e28bab194d3ae00c3cd693ea7;
        values[mainnet]["WBTC_USR_86"] = 0xf84288cdcf652627f66cd7a6d4c43c3ee43ca7146d9a9cfab3a136a861144d6f;
        values[mainnet]["EBTC_USR_86"] = 0xa4577bf93e8c70d9f91b6e000ae084ae0a7a29d4ebe28cbfea24975c28dccfb5;
        values[mainnet]["Corn_eBTC_PT03_2025_WETH_915"] =
            0x4758ddbbcb96c8d0c10f46ca260d505e32399c2dd995380a832578ee84ef2d54;
        values[mainnet]["Corn_eBTC_PT03_2025_WBTC_915"] =
            0x9dd533d05afa8dfce6a2ed82219e1c1dcebb16fe7722fb5912b989ef69df487f;
        values[mainnet]["eUSDe_PT05_2025_USDC_915"] = 0x21e55c99123958ff5667f824948c97d0f64dfaa6e2848062e72bc68d200d35f9;
        values[mainnet]["MCUSR_USD0_915"] = 0xcc39b6c92fd03ac608b9239618db8b80a4a2034b0450bdf47b404229571312da;
        values[mainnet]["MCUSR_USDC_915"] = 0x3889dee51674c6e728f7d05f11a3407c6853e433a0e63f8febbc45887a26a475;
        values[mainnet]["EBTC_PT06_26_25_LBTC_915"] = 0xdbabefcc4e7f2fce9b6dd3843df46a92b74819453cf2f92092542e43f68b40ea;
        values[mainnet]["sdeUSD_USDC_915"] = 0x0f9563442d64ab3bd3bcb27058db0b0d4046a4c46f0acd811dacae9551d2b129;
        values[mainnet]["sUSDePT_07_30_25_DAI_915"] = 0xb81eaed0df42ff6646c8daf4fe38afab93b13b6a89c9750d08e705223a45e2ef;
        values[mainnet]["sUSDePT_07_30_25_USDC_915"] =
            0xbc552f0b14dd6f8e60b760a534ac1d8613d3539153b4d9675d697e048f2edc7e;
        values[mainnet]["WEETH_WETH_915"] = 0x37e7484d642d90f14451f1910ba4b7b8e4c3ccdd0ec28f8b2bdb35479e472ba7;
        values[mainnet]["WSTETH_WETH_965"] = 0xb8fc70e82bc5bb53e773626fcc6a23f7eefa036918d7ef216ecfb1950a94a85e;
        values[mainnet]["WSTETH_WETH_945"] = 0xd0e50cdac92fe2172043f5e0c36532c6369d24947e40968f34a5e8819ca9ec5d;
        values[mainnet]["sUSDe_USDC_915"] = 0x85c7f4374f3a403b36d54cc284983b2b02bbd8581ee0f3c36494447b87d9fcab;
        values[mainnet]["sUSDe_USDT_915"] = 0xdc5333039bcf15f1237133f74d5806675d83d9cf19cfd4cfdd9be674842651bf;
        values[mainnet]["MF-ONE_USDC_915"] = 0xef2c308b5abecf5c8750a1aa82b47c558005feb7a03f4f8e1ad682d71ac8d0ba;
        values[mainnet]["USDe_PT09_25_25_USDtb_915"] =
            0x3462a9442ec1aa46fc38bf91472b593b8fb86bf18eac47ebf82493dc4bed5b1b; //USDe
        values[mainnet]["sUSDe_PT07_31_25_USDC_915"] =
            0xbc552f0b14dd6f8e60b760a534ac1d8613d3539153b4d9675d697e048f2edc7e;
        values[mainnet]["sUSDe_PT_07_31_25_USDT_945"] =
            0x83e10b446f0f2013bb5417fbab8de0371808da605d9d88bdd3ad9de4e7303048;
        values[mainnet]["sUSDe_PT09_25_25_USDtb_915"] =
            0xbf2526a242545bbf0f3d42ffb879fa1eb562ed74704bce0a319b975818dd525a; //sUSDe

        // MetaMorpho
        values[mainnet]["usualBoostedUSDC"] = 0xd63070114470f685b75B74D60EEc7c1113d33a3D.toBytes32();
        values[mainnet]["gauntletUSDCcore"] = 0x8eB67A509616cd6A7c1B3c8C21D48FF57df3d458.toBytes32();
        values[mainnet]["gauntletUSDCprime"] = 0xdd0f28e19C1780eb6396170735D45153D261490d.toBytes32();
        values[mainnet]["gauntletUSDCfrontier"] = 0xc582F04d8a82795aa2Ff9c8bb4c1c889fe7b754e.toBytes32();
        values[mainnet]["steakhouseUSDC"] = 0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB.toBytes32();
        values[mainnet]["smokehouseUSDC"] = 0xBEeFFF209270748ddd194831b3fa287a5386f5bC.toBytes32();
        values[mainnet]["steakhouseUSDT"] = 0xbEef047a543E45807105E51A8BBEFCc5950fcfBa.toBytes32();
        values[mainnet]["smokehouseUSDT"] = 0xA0804346780b4c2e3bE118ac957D1DB82F9d7484.toBytes32();
        values[mainnet]["steakhouseUSDCRWA"] = 0x6D4e530B8431a52FFDA4516BA4Aadc0951897F8C.toBytes32();
        values[mainnet]["gauntletWBTCcore"] = 0x443df5eEE3196e9b2Dd77CaBd3eA76C3dee8f9b2.toBytes32();
        values[mainnet]["Re7WBTC"] = 0xE0C98605f279e4D7946d25B75869c69802823763.toBytes32();
        values[mainnet]["MCwBTC"] = 0x1c530D6de70c05A81bF1670157b9d928e9699089.toBytes32();
        values[mainnet]["MCUSR"] = 0xD50DA5F859811A91fD1876C9461fD39c23C747Ad.toBytes32();
        values[mainnet]["Re7cbBTC"] = 0xA02F5E93f783baF150Aa1F8b341Ae90fe0a772f7.toBytes32();
        values[mainnet]["gauntletCbBTCcore"] = 0xF587f2e8AfF7D76618d3B6B4626621860FbD54e3.toBytes32();
        values[mainnet]["MCcbBTC"] = 0x98cF0B67Da0F16E1F8f1a1D23ad8Dc64c0c70E0b.toBytes32();
        values[mainnet]["gauntletLBTCcore"] = 0xdC94785959B73F7A168452b3654E44fEc6A750e4.toBytes32();
        values[mainnet]["gauntletWETHPrime"] = 0x2371e134e3455e0593363cBF89d3b6cf53740618.toBytes32();
        values[mainnet]["gauntletWETHCore"] = 0x4881Ef0BF6d2365D3dd6499ccd7532bcdBCE0658.toBytes32();
        values[mainnet]["mevCapitalwWeth"] = 0x9a8bC3B04b7f3D87cfC09ba407dCED575f2d61D8.toBytes32();
        values[mainnet]["steakhouseETH"] = 0xBEEf050ecd6a16c4e7bfFbB52Ebba7846C4b8cD4.toBytes32();
        values[mainnet]["Re7WETH"] = 0x78Fc2c2eD1A4cDb5402365934aE5648aDAd094d0.toBytes32();
        values[mainnet]["PendleWBTC"] = 0x2f1aBb81ed86Be95bcf8178bA62C8e72D6834775.toBytes32();

        // Morpho Rewards
        values[mainnet]["universalRewardsDistributor"] = 0x330eefa8a787552DC5cAd3C3cA644844B1E61Ddb.toBytes32();

        values[mainnet]["uniswapV3PositionManager"] = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88.toBytes32();

        // 1Inch
        values[mainnet]["aggregationRouterV5"] = 0x1111111254EEB25477B68fb85Ed929f73A960582.toBytes32();
        values[mainnet]["oneInchExecutor"] = 0x8C864D0c8E476Bf9eb9d620C10E1296fb0E2F940.toBytes32();
        values[mainnet]["wETHweETH5bps"] = 0x7A415B19932c0105c82FDB6b720bb01B0CC2CAe3.toBytes32();

        // Gearbox
        values[mainnet]["dWETHV3"] = 0xda0002859B2d05F66a753d8241fCDE8623f26F4f.toBytes32();
        values[mainnet]["sdWETHV3"] = 0x0418fEB7d0B25C411EB77cD654305d29FcbFf685.toBytes32();
        values[mainnet]["dUSDCV3"] = 0xda00000035fef4082F78dEF6A8903bee419FbF8E.toBytes32();
        values[mainnet]["sdUSDCV3"] = 0x9ef444a6d7F4A5adcd68FD5329aA5240C90E14d2.toBytes32();
        values[mainnet]["dDAIV3"] = 0xe7146F53dBcae9D6Fa3555FE502648deb0B2F823.toBytes32();
        values[mainnet]["sdDAIV3"] = 0xC853E4DA38d9Bd1d01675355b8c8f3BBC1451973.toBytes32();
        values[mainnet]["dUSDTV3"] = 0x05A811275fE9b4DE503B3311F51edF6A856D936e.toBytes32();
        values[mainnet]["sdUSDTV3"] = 0x16adAb68bDEcE3089D4f1626Bb5AEDD0d02471aD.toBytes32();
        values[mainnet]["dWBTCV3"] = 0xda00010eDA646913F273E10E7A5d1F659242757d.toBytes32();
        values[mainnet]["sdWBTCV3"] = 0xA8cE662E45E825DAF178DA2c8d5Fae97696A788A.toBytes32();
        values[mainnet]["dGHOV3"] = 0x4d56c9cBa373AD39dF69Eb18F076b7348000AE09.toBytes32();
        values[mainnet]["sdGHOV3"] = 0xE2037090f896A858E3168B978668F22026AC52e7.toBytes32();
        values[mainnet]["dWSTETHV3"] = 0xFF94993fA7EA27Efc943645F95Adb36C1b81244b.toBytes32();
        values[mainnet]["sdWSTETHV3"] = 0x8C719A40c705B988c50e76a3cBB18551ab8296CC.toBytes32();
        values[mainnet]["rstEthwstETH"] = 0x7a4EffD87C2f3C55CA251080b1343b605f327E3a.toBytes32();
        values[mainnet]["dvstETH"] = 0x5E362eb2c0706Bd1d134689eC75176018385430B.toBytes32();

        // Pendle
        values[mainnet]["pendleMarketFactory"] = 0x1A6fCc85557BC4fB7B534ed835a03EF056552D52.toBytes32();
        values[mainnet]["pendleRouter"] = 0x888888888889758F76e7103c6CbF23ABbF58F946.toBytes32();
        values[mainnet]["pendleOracle"] = 0x66a1096C6366b2529274dF4f5D8247827fe4CEA8.toBytes32();
        values[mainnet]["pendleLimitOrderRouter"] = 0x000000000000c9B3E2C3Ec88B1B4c0cD853f4321.toBytes32();

        values[mainnet]["pendleWeETHMarket"] = 0xF32e58F92e60f4b0A37A69b95d642A471365EAe8.toBytes32();
        values[mainnet]["pendleWeethSy"] = 0xAC0047886a985071476a1186bE89222659970d65.toBytes32();
        values[mainnet]["pendleEethPt"] = 0xc69Ad9baB1dEE23F4605a82b3354F8E40d1E5966.toBytes32();
        values[mainnet]["pendleEethYt"] = 0xfb35Fd0095dD1096b1Ca49AD44d8C5812A201677.toBytes32();

        values[mainnet]["pendleZircuitWeETHMarket"] = 0xe26D7f9409581f606242300fbFE63f56789F2169.toBytes32();
        values[mainnet]["pendleZircuitWeethSy"] = 0xD7DF7E085214743530afF339aFC420c7c720BFa7.toBytes32();
        values[mainnet]["pendleZircuitEethPt"] = 0x4AE5411F3863CdB640309e84CEDf4B08B8b33FfF.toBytes32();
        values[mainnet]["pendleZircuitEethYt"] = 0x7C2D26182adeEf96976035986cF56474feC03bDa.toBytes32();

        values[mainnet]["pendleUSDeMarket"] = 0x19588F29f9402Bb508007FeADd415c875Ee3f19F.toBytes32();
        values[mainnet]["pendleUSDeSy"] = 0x42862F48eAdE25661558AFE0A630b132038553D0.toBytes32();
        values[mainnet]["pendleUSDePt"] = 0xa0021EF8970104c2d008F38D92f115ad56a9B8e1.toBytes32();
        values[mainnet]["pendleUSDeYt"] = 0x1e3d13932C31d7355fCb3FEc680b0cD159dC1A07.toBytes32();

        values[mainnet]["pendleZircuitUSDeMarket"] = 0x90c98ab215498B72Abfec04c651e2e496bA364C0.toBytes32();
        values[mainnet]["pendleZircuitUSDeSy"] = 0x293C6937D8D82e05B01335F7B33FBA0c8e256E30.toBytes32();
        values[mainnet]["pendleZircuitUSDePt"] = 0x3d4F535539A33FEAd4D76D7b3B7A9cB5B21C73f1.toBytes32();
        values[mainnet]["pendleZircuitUSDeYt"] = 0x40357b9f22B4DfF0Bf56A90661b8eC106C259d29.toBytes32();

        values[mainnet]["pendleSUSDeMarketSeptember"] = 0xd1D7D99764f8a52Aff007b7831cc02748b2013b5.toBytes32();
        values[mainnet]["pendleSUSDeMarketJuly"] = 0x107a2e3cD2BB9a32B9eE2E4d51143149F8367eBa.toBytes32();
        values[mainnet]["pendleKarakSUSDeMarket"] = 0xB1f587B354a4a363f5332e88effbbC2E4961250A.toBytes32();
        values[mainnet]["pendleKarakUSDeMarket"] = 0x1BCBDB8c8652345A5ACF04e6E74f70086c68FEfC.toBytes32();

        values[mainnet]["pendleWeETHMarketSeptember"] = 0xC8eDd52D0502Aa8b4D5C77361D4B3D300e8fC81c.toBytes32();
        values[mainnet]["pendleWeethSySeptember"] = 0xAC0047886a985071476a1186bE89222659970d65.toBytes32();
        values[mainnet]["pendleEethPtSeptember"] = 0x1c085195437738d73d75DC64bC5A3E098b7f93b1.toBytes32();
        values[mainnet]["pendleEethYtSeptember"] = 0xA54Df645A042D24121a737dAA89a57EbF8E0b71c.toBytes32();

        values[mainnet]["pendleWeETHMarketDecember"] = 0x7d372819240D14fB477f17b964f95F33BeB4c704.toBytes32();
        values[mainnet]["pendleWeethSyDecember"] = 0xAC0047886a985071476a1186bE89222659970d65.toBytes32();
        values[mainnet]["pendleEethPtDecember"] = 0x6ee2b5E19ECBa773a352E5B21415Dc419A700d1d.toBytes32();
        values[mainnet]["pendleEethYtDecember"] = 0x129e6B5DBC0Ecc12F9e486C5BC9cDF1a6A80bc6A.toBytes32();

        values[mainnet]["pendleUSDeZircuitMarketAugust"] = 0xF148a0B15712f5BfeefAdb4E6eF9739239F88b07.toBytes32();
        values[mainnet]["pendleKarakWeETHMarketSeptember"] = 0x18bAFcaBf2d5898956AE6AC31543d9657a604165.toBytes32();
        values[mainnet]["pendleKarakWeETHMarketDecember"] = 0xFF694CC3f74E080637008B3792a9D7760cB456Ca.toBytes32();

        values[mainnet]["pendleSwethMarket"] = 0x0e1C5509B503358eA1Dac119C1D413e28Cc4b303.toBytes32();

        values[mainnet]["pendleZircuitWeETHMarketAugust"] = 0x6c269DFc142259c52773430b3c78503CC994a93E.toBytes32();
        values[mainnet]["pendleWeETHMarketJuly"] = 0xe1F19CBDa26b6418B0C8E1EE978a533184496066.toBytes32();
        values[mainnet]["pendleWeETHkSeptember"] = 0x905A5a4792A0C27a2AdB2777f98C577D320079EF.toBytes32();
        values[mainnet]["pendleWeETHkDecember"] = 0x792b9eDe7a18C26b814f87Eb5E0c8D26AD189780.toBytes32();

        values[mainnet]["pendle_sUSDe_08_23_24"] = 0xbBf399db59A845066aAFce9AE55e68c505FA97B7.toBytes32();
        values[mainnet]["pendle_sUSDe_12_25_24"] = 0xa0ab94DeBB3cC9A7eA77f3205ba4AB23276feD08.toBytes32();
        values[mainnet]["pendle_USDe_08_23_24"] = 0x3d1E7312dE9b8fC246ddEd971EE7547B0a80592A.toBytes32();
        values[mainnet]["pendle_USDe_12_25_24"] = 0x8a49f2AC2730ba15AB7EA832EdaC7f6BA22289f8.toBytes32();
        values[mainnet]["pendle_sUSDe_03_26_25"] = 0xcDd26Eb5EB2Ce0f203a84553853667aE69Ca29Ce.toBytes32();
        values[mainnet]["pendle_sUSDe_karak_01_29_25"] = 0xDbE4D359D4E48087586Ec04b93809bA647343548.toBytes32();
        values[mainnet]["pendle_USDe_karak_01_29_25"] = 0x6C06bBFa3B63eD344ceb3312Df795eDC8d29BDD5.toBytes32();
        values[mainnet]["pendle_USDe_03_26_25"] = 0xB451A36c8B6b2EAc77AD0737BA732818143A0E25.toBytes32();
        values[mainnet]["pendle_eUSDe_market_05_28_25"] = 0x85667e484a32d884010Cf16427D90049CCf46e97.toBytes32();
        values[mainnet]["pendle_eUSDe_05_28_25_pt"] = 0x50D2C7992b802Eef16c04FeADAB310f31866a545.toBytes32();
        values[mainnet]["pendle_sUSDe_05_28_25"] = 0xB162B764044697cf03617C2EFbcB1f42e31E4766.toBytes32();
        values[mainnet]["pendle_sUSDe_market_07_30_25"] = 0x4339Ffe2B7592Dc783ed13cCE310531aB366dEac.toBytes32();
        values[mainnet]["pendle_sUSDe_market_07_31_25"] = 0x4339Ffe2B7592Dc783ed13cCE310531aB366dEac.toBytes32();
        values[mainnet]["pendle_sUSDe_market_09_25_25"] = 0xA36b60A14A1A5247912584768C6e53E1a269a9F7.toBytes32();

        values[mainnet]["pendle_weETHs_market_08_28_24"] = 0xcAa8ABB72A75C623BECe1f4D5c218F425d47A0D0.toBytes32();
        values[mainnet]["pendle_weETHs_sy_08_28_24"] = 0x9e8f10574ACc2c62C6e5d19500CEd39163Da37A9.toBytes32();
        values[mainnet]["pendle_weETHs_pt_08_28_24"] = 0xda6530EfaFD63A42d7b9a0a5a60A03839CDb813A.toBytes32();
        values[mainnet]["pendle_weETHs_yt_08_28_24"] = 0x28cE264D0938C1051687FEbDCeFacc2242BA9E0E.toBytes32();
        values[mainnet]["pendle_weETHs_market_12_25_24"] = 0x40789E8536C668c6A249aF61c81b9dfaC3EB8F32.toBytes32();
        values[mainnet]["pendle_weETHs_market_6_25_25"] = 0xcbA3B226cA62e666042Cb4a1e6E4681053885F75.toBytes32();

        values[mainnet]["pendleUSD0PlusMarketOctober"] = 0x00b321D89A8C36B3929f20B7955080baeD706D1B.toBytes32();
        values[mainnet]["pendle_USD0Plus_market_01_29_2025"] = 0x64506968E80C9ed07bFF60C8D9d57474EFfFF2c9.toBytes32();
        values[mainnet]["pendle_USD0Plus_market_02_26_2025"] = 0x22a72B0C504cBb7f8245208f84D8f035c311aDec.toBytes32();
        values[mainnet]["pendle_USD0Plus_market_03_26_2025"] = 0xaFDC922d0059147486cC1F0f32e3A2354b0d35CC.toBytes32();
        values[mainnet]["pendle_USD0++_market_01_29_25"] = 0x64506968E80C9ed07bFF60C8D9d57474EFfFF2c9.toBytes32();
        values[mainnet]["pendle_USD0++_market_06_25_25"] = 0x048680F64d6DFf1748ba6D9a01F578433787e24B.toBytes32();
        values[mainnet]["pendle_USD0Plus_market_04_23_2025"] = 0x81f3a11dB1DE16f4F9ba8Bf46B71D2B168c64899.toBytes32();
        values[mainnet]["pendle_USD0Plus_market_06_25_2025"] = 0x048680F64d6DFf1748ba6D9a01F578433787e24B.toBytes32();

        values[mainnet]["pendle_eBTC_market_12_26_24"] = 0x36d3ca43ae7939645C306E26603ce16e39A89192.toBytes32();
        values[mainnet]["pendle_eBTC_market_06_25_25"] = 0x523f9441853467477b4dDE653c554942f8E17162.toBytes32();
        values[mainnet]["pendle_LBTC_corn_market_12_26_24"] = 0xCaE62858DB831272A03768f5844cbe1B40bB381f.toBytes32();
        values[mainnet]["pendle_LBTC_market_03_26_25"] = 0x70B70Ac0445C3eF04E314DFdA6caafd825428221.toBytes32();
        values[mainnet]["pendle_LBTC_market_06_25_25"] = 0x931F7eA0c31c14914a452d341bc5Cb5d996BE71d.toBytes32();
        values[mainnet]["pendle_LBTC_market_12_17_25"] = 0xefA9339980fFEE3304Af4822B80484BfcC6f35Ee.toBytes32();
        values[mainnet]["pendle_LBTC_corn_market_02_26_25"] = 0xC118635bcde024c5B01C6be2B0569a2608A8032C.toBytes32();
        values[mainnet]["pendle_eBTC_corn_market_3_26_25"] = 0x2C71Ead7ac9AE53D05F8664e77031d4F9ebA064B.toBytes32();
        values[mainnet]["pendle_LBTC_concrete_market_04_09_25"] = 0x83916356556f51dcBcB226202c3efeEfc88d5eaA.toBytes32();
        values[mainnet]["pendle_LBTC_corn_concrete_market_05_21_25"] =
            0x08946D1070bab757931d39285C12FEf4313b667B.toBytes32();
        values[mainnet]["pendle_WBTC_concrete_market_04_09_25"] = 0x9471d9c5B57b59d42B739b00389a6d520c33A7a9.toBytes32();
        values[mainnet]["pendle_eBTC_market_06_25_25"] = 0x523f9441853467477b4dDE653c554942f8E17162.toBytes32();
        values[mainnet]["pendle_zeBTC_market_03_26_25"] = 0x98ffeFd1a51D322c8DeF6d0Ba183e71547216F7f.toBytes32();

        values[mainnet]["pendle_pumpBTC_market_03_26_25"] = 0x8098B48a1c4e4080b30A43a7eBc0c87b52F17222.toBytes32();
        values[mainnet]["pendle_pumpBTC_market_05_28_25"] = 0x2D8F5997Af9bc7AE4047287425355518EF01fcfC.toBytes32();
        values[mainnet]["pendle_corn_pumpBTC_market_12_25_24"] = 0xf8208fB52BA80075aF09840A683143C22DC5B4dd.toBytes32();

        values[mainnet]["pendle_uniBTC_market_03_26_25"] = 0x380C751BD0412f47Ca560B6AFeB566d88dc18630.toBytes32();
        values[mainnet]["pendle_corn_uniBTC_market_12_26_24"] = 0x40dEAE18c3CE932Fdd5Df1f44b54D8Cf3902787B.toBytes32();
        values[mainnet]["pendle_sUSDs_market_03_26_25"] = 0x21D85Ff3BEDFF031EF466C7d5295240C8AB2a2b8.toBytes32();

        values[mainnet]["pendle_liquid_bera_eth_04_09_25"] = 0x46E6b4A950Eb1AbBa159517DEA956Afd01ea9497.toBytes32();
        values[mainnet]["pendle_liquidBeraBTC_04_09_25"] = 0xEbf5c58b74A836F1e51d08e9C909c4A4530AFD41.toBytes32();
        values[mainnet]["pendle_wstUSR_market_03_26_25"] = 0x353d0B2EFB5B3a7987fB06D30Ad6160522d08426.toBytes32();

        values[mainnet]["pendle_tETH_03_28_2025"] = 0xBDb8F9729d3194f75fD1A3D9bc4FFe0DDe3A404c.toBytes32();

        values[mainnet]["pendle_beraSTONE_04_09_2025"] = 0x7561C5CCfe41A26B33944B58C70D6a3CB63E881c.toBytes32();

        values[mainnet]["pendle_syrupUSDC_04_23_2025"] = 0x580E40c15261F7Baf18eA50F562118aE99361096.toBytes32();

        values[mainnet]["pendle_eUSDe_05_28_2025"] = 0x85667e484a32d884010Cf16427D90049CCf46e97.toBytes32();

        values[mainnet]["pendle_lvlUSD_05_28_25"] = 0xE45d2CE15aBbA3c67b9fF1E7A69225C855d3DA82.toBytes32();
        values[mainnet]["pendle_lvlUSD_05_28_25_sy"] = 0x8b9D898327C0Ac74b946Ca3cA9FcfCBE9bc29c48.toBytes32();
        values[mainnet]["pendle_lvlUSD_05_28_25_pt"] = 0x9BcA74F805AB0a22DDD0886dB0942199a0feBa71.toBytes32();
        values[mainnet]["pendle_lvlUSD_05_28_25_yt"] = 0x65901Ac9EFA7CdAf1Bdb4dbce4c53B151ae8d014.toBytes32();
        values[mainnet]["pendle_slvlUSD_05_28_25"] = 0x1C71752a6C10D66375702aaFAd4B6D20393702Cf.toBytes32();
        values[mainnet]["pendle_slvlUSD_05_28_25_sy"] = 0x10222f882F3594455343Abc9831213854902eD8e.toBytes32();
        values[mainnet]["pendle_slvlUSD_05_28_25_pt"] = 0x4D4062bAD41E03b1cdee4C06263F96EB81832341.toBytes32();
        values[mainnet]["pendle_slvlUSD_05_28_25_yt"] = 0x4d74Ad0287f5A3A799659AAd542e4D9d9f31D443.toBytes32();

        values[mainnet]["pendle_sUSDe_03_26_25_sy"] = 0x3Ee118EFC826d30A29645eAf3b2EaaC9E8320185.toBytes32();
        values[mainnet]["pendle_sUSDe_03_26_25_pt"] = 0xE00bd3Df25fb187d6ABBB620b3dfd19839947b81.toBytes32();
        values[mainnet]["pendle_sUSDe_03_26_25_yt"] = 0x96512230bF0Fa4E20Cf02C3e8A7d983132cd2b9F.toBytes32();
        values[mainnet]["pendle_sUSDe_07_30_25_sy"] = 0xF541AA4d6f29ec2423A0D306dBc677021A02DBC0.toBytes32();
        values[mainnet]["pendle_sUSDe_07_30_25_pt"] = 0x3b3fB9C57858EF816833dC91565EFcd85D96f634.toBytes32();
        values[mainnet]["pendle_sUSDe_07_30_25_yt"] = 0xb7E51D15161C49C823f3951D579DEd61cD27272B.toBytes32();

        values[mainnet]["pendle_sUSDe_05_28_25"] = 0xB162B764044697cf03617C2EFbcB1f42e31E4766.toBytes32();
        values[mainnet]["pendle_sUSDe_05_28_25_sy"] = 0xE877B2A8a53763C8B0534a15e87da28f3aC1257e.toBytes32();
        values[mainnet]["pendle_sUSDe_05_28_25_pt"] = 0xb7de5dFCb74d25c2f21841fbd6230355C50d9308.toBytes32();
        values[mainnet]["pendle_sUSDe_05_28_25_yt"] = 0x1de6Ff19FDA7496DdC12f2161f6ad6427c52aBBe.toBytes32();
        values[mainnet]["pendle_syrupUSDC_04_23_25"] = 0x580E40c15261F7Baf18eA50F562118aE99361096.toBytes32();
        values[mainnet]["pendle_syrupUSDC_04_23_25_sy"] = 0xc9e9C85B33E87fde85c44DBf72b4B842A071551D.toBytes32();
        values[mainnet]["pendle_syrupUSDC_04_23_25_pt"] = 0x2beEb2c4809954e5b514a3205afbDC097eb810B4.toBytes32();
        values[mainnet]["pendle_syrupUSDC_04_23_25_yt"] = 0x01eCe02951395b7AdBa57cA3281C4d6a565d347e.toBytes32();

        values[mainnet]["pendle_eUSDe_market_08_14_25"] = 0xE93B4A93e80BD3065B290394264af5d82422ee70.toBytes32();
        values[mainnet]["pendle_eUSDe_08_14_25_pt"] = 0x14Bdc3A3AE09f5518b923b69489CBcAfB238e617.toBytes32();
        values[mainnet]["pendle_eUSDe_08_14_25_sy"] = 0x7ac8ca87959b1d5EDfe2df5325A37c304DCea4D0.toBytes32();
        values[mainnet]["pendle_eUSDe_08_14_25_yt"] = 0xe8eF806c8aaDc541408dcAd36107c7d26a391712.toBytes32();

        values[mainnet]["pendle_USDe_market_07_31_25"] = 0x9Df192D13D61609D1852461c4850595e1F56E714.toBytes32();
        values[mainnet]["pendle_USDe_07_31_25_pt"] = 0x917459337CaAC939D41d7493B3999f571D20D667.toBytes32();
        values[mainnet]["pendle_USDe_07_31_25_sy"] = 0xb47CBF6697A6518222c7Af4098A43AEFe2739c8c.toBytes32();
        values[mainnet]["pendle_USDe_07_31_25_yt"] = 0x733Ee9Ba88f16023146EbC965b7A1Da18a322464.toBytes32();

        values[mainnet]["pendle_USDe_market_09_25_25"] = 0x6d98a2b6CDbF44939362a3E99793339Ba2016aF4.toBytes32();
        values[mainnet]["pendle_USDe_09_25_25_pt"] = 0xBC6736d346a5eBC0dEbc997397912CD9b8FAe10a.toBytes32();
        values[mainnet]["pendle_USDe_09_25_25_sy"] = 0xf3DbdE762E5B67FaD09d88da3dfD38A83f753FFe.toBytes32();

        values[mainnet]["pendle_USDe_market_11_26_25"] = 0x4eaA571EaFCD96f51728756BD7F396459BB9B869.toBytes32();
        values[mainnet]["pendle_USDe_11_26_25_pt"] = 0x62C6E813b9589C3631Ba0Cdb013acdB8544038B7.toBytes32();
        values[mainnet]["pendle_USDe_11_26_25_sy"] = 0x925a15bD6A1582fa7c0EbbFc3Dbd29c34f58340e.toBytes32();

        values[mainnet]["pendle_sUSDe_market_09_25_25"] = 0xA36b60A14A1A5247912584768C6e53E1a269a9F7.toBytes32();
        values[mainnet]["pendle_sUSDe_09_25_25_pt"] = 0x9F56094C450763769BA0EA9Fe2876070c0fD5F77.toBytes32();
        values[mainnet]["pendle_sUSDe_09_25_25_sy"] = 0xC01cde799245a25e6EabC550b36A47F6F83cc0f1.toBytes32();


        values[mainnet]["pendle_sUSDe_market_11_26_25"] = 0xb6aC3d5da138918aC4E84441e924a20daA60dBdd.toBytes32();
        values[mainnet]["pendle_sUSDe_11_26_25_pt"] = 0xe6A934089BBEe34F832060CE98848359883749B3.toBytes32();
        values[mainnet]["pendle_sUSDe_11_26_25_sy"] = 0xAbf8165dD7a90ab75878161db15Bf85F6F781d9b.toBytes32();

        // Aave V3 Core
        values[mainnet]["v3Pool"] = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2.toBytes32();
        values[mainnet]["v3RewardsController"] = 0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb.toBytes32();

        //Aave v3 Prime
        values[mainnet]["v3PrimePool"] = 0x4e033931ad43597d96D6bcc25c280717730B58B1.toBytes32();

        // Aave V3 Lido
        values[mainnet]["v3LidoPool"] = 0x4e033931ad43597d96D6bcc25c280717730B58B1.toBytes32();

        // Aave V3 Horizon
        values[mainnet]["v3HorizonPool"] = 0xAe05Cd22df81871bc7cC2a04BeCfb516bFe332C8.toBytes32();

        // SparkLend
        values[mainnet]["sparkLendPool"] = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987.toBytes32();

        // Uniswap V3 Pools
        values[mainnet]["wETH_weETH_05"] = 0x7A415B19932c0105c82FDB6b720bb01B0CC2CAe3.toBytes32();
        values[mainnet]["wstETH_wETH_01"] = 0x109830a1AAaD605BbF02a9dFA7B0B92EC2FB7dAa.toBytes32();
        values[mainnet]["rETH_wETH_01"] = 0x553e9C493678d8606d6a5ba284643dB2110Df823.toBytes32();
        values[mainnet]["rETH_wETH_05"] = 0xa4e0faA58465A2D369aa21B3e42d43374c6F9613.toBytes32();
        values[mainnet]["wstETH_rETH_05"] = 0x18319135E02Aa6E02D412C98cCb16af3a0a9CB57.toBytes32();
        values[mainnet]["wETH_rswETH_05"] = 0xC410573Af188f56062Ee744cC3D6F2843f5bC13b.toBytes32();
        values[mainnet]["wETH_rswETH_30"] = 0xE62627326d7794E20bB7261B24985294de1579FE.toBytes32();
        values[mainnet]["ezETH_wETH_01"] = 0xBE80225f09645f172B079394312220637C440A63.toBytes32();
        values[mainnet]["PENDLE_wETH_30"] = 0x57aF956d3E2cCa3B86f3D8C6772C03ddca3eAacB.toBytes32();
        values[mainnet]["USDe_USDT_01"] = 0x435664008F38B0650fBC1C9fc971D0A3Bc2f1e47.toBytes32();
        values[mainnet]["USDe_USDC_01"] = 0xE6D7EbB9f1a9519dc06D557e03C522d53520e76A.toBytes32();
        values[mainnet]["USDe_DAI_01"] = 0x5B3a0f1acBE8594a079FaFeB1c84DEA9372A5Aad.toBytes32();
        values[mainnet]["sUSDe_USDT_05"] = 0x867B321132B18B5BF3775c0D9040D1872979422E.toBytes32();
        values[mainnet]["GEAR_wETH_100"] = 0xaEf52f72583E6c4478B220Da82321a6a023eEE50.toBytes32();
        values[mainnet]["GEAR_USDT_30"] = 0x349eE001D80f896F24571616932f54cBD66B18C9.toBytes32();
        values[mainnet]["DAI_USDC_01"] = 0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168.toBytes32();
        values[mainnet]["DAI_USDC_05"] = 0x6c6Bc977E13Df9b0de53b251522280BB72383700.toBytes32();
        values[mainnet]["USDC_USDT_01"] = 0x3416cF6C708Da44DB2624D63ea0AAef7113527C6.toBytes32();
        values[mainnet]["USDC_USDT_05"] = 0x7858E59e0C01EA06Df3aF3D20aC7B0003275D4Bf.toBytes32();
        values[mainnet]["USDC_wETH_05"] = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640.toBytes32();
        values[mainnet]["FRAX_USDC_05"] = 0xc63B0708E2F7e69CB8A1df0e1389A98C35A76D52.toBytes32();
        values[mainnet]["FRAX_USDC_01"] = 0x9A834b70C07C81a9fcD6F22E842BF002fBfFbe4D.toBytes32();
        values[mainnet]["DAI_FRAX_05"] = 0x97e7d56A0408570bA1a7852De36350f7713906ec.toBytes32();
        values[mainnet]["FRAX_USDT_05"] = 0xc2A856c3afF2110c1171B8f942256d40E980C726.toBytes32();
        values[mainnet]["PYUSD_USDC_01"] = 0x13394005C1012e708fCe1EB974F1130fDc73a5Ce.toBytes32();

        // EigenLayer
        values[mainnet]["strategyManager"] = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A.toBytes32();
        values[mainnet]["delegationManager"] = 0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A.toBytes32();
        values[mainnet]["mETHStrategy"] = 0x298aFB19A105D59E74658C4C334Ff360BadE6dd2.toBytes32();
        values[mainnet]["USDeStrategy"] = 0x298aFB19A105D59E74658C4C334Ff360BadE6dd2.toBytes32();
        values[mainnet]["testOperator"] = 0xDbEd88D83176316fc46797B43aDeE927Dc2ff2F5.toBytes32();
        values[mainnet]["eigenStrategy"] = 0xaCB55C530Acdb2849e6d4f36992Cd8c9D50ED8F7.toBytes32();
        values[mainnet]["eEigenOperator"] = 0xDcAE4FAf7C7d0f4A78abe147244c6e9d60cFD202.toBytes32();
        values[mainnet]["eigenRewards"] = 0x7750d328b314EfFa365A0402CcfD489B80B0adda.toBytes32();
        values[mainnet]["ethfiStrategy"] = 0x7079A4277eAF578cbe9682ac7BC3EfFF8635ebBf.toBytes32();

        // Swell
        values[mainnet]["swellSimpleStaking"] = 0x38D43a6Cb8DA0E855A42fB6b0733A0498531d774.toBytes32();
        values[mainnet]["swEXIT"] = 0x48C11b86807627AF70a34662D4865cF854251663.toBytes32();
        values[mainnet]["rswEXIT"] = 0x58749C46Ffe97e4d79508a2C781C440f4756f064.toBytes32();
        values[mainnet]["accessControlManager"] = 0x625087d72c762254a72CB22cC2ECa40da6b95EAC.toBytes32();
        values[mainnet]["depositManager"] = 0xb3D9cf8E163bbc840195a97E81F8A34E295B8f39.toBytes32();

        // Frax
        values[mainnet]["frxETHMinter"] = 0xbAFA44EFE7901E04E39Dad13167D089C559c1138.toBytes32();
        values[mainnet]["frxETHRedemptionTicket"] = 0x82bA8da44Cd5261762e629dd5c605b17715727bd.toBytes32();

        // Zircuit
        values[mainnet]["zircuitSimpleStaking"] = 0xF047ab4c75cebf0eB9ed34Ae2c186f3611aEAfa6.toBytes32();

        // Mantle
        values[mainnet]["mantleLspStaking"] = 0xe3cBd06D7dadB3F4e6557bAb7EdD924CD1489E8f.toBytes32();
        values[mainnet]["MNT"] = 0x3c3a81e81dc49A522A592e7622A7E711c06bf354.toBytes32();
        // Fluid
        values[mainnet]["fUSDT"] = 0x5C20B550819128074FD538Edf79791733ccEdd18.toBytes32();
        values[mainnet]["fUSDTStakingRewards"] = 0x490681095ed277B45377d28cA15Ac41d64583048.toBytes32();
        values[mainnet]["fUSDC"] = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33.toBytes32();
        values[mainnet]["fWETH"] = 0x90551c1795392094FE6D29B758EcCD233cFAa260.toBytes32();
        values[mainnet]["fWSTETH"] = 0x2411802D8BEA09be0aF8fD8D08314a63e706b29C.toBytes32();
        values[mainnet]["fGHO"] = 0x6A29A46E21C730DcA1d8b23d637c101cec605C5B.toBytes32();
        values[mainnet]["fwstETH"] = 0x2411802D8BEA09be0aF8fD8D08314a63e706b29C.toBytes32();

        // Fluid Rewards
        values[mainnet]["fluidMerkleDistributor"] = 0x7060FE0Dd3E31be01EFAc6B28C8D38018fD163B0.toBytes32();

        // Fluid Dex
        values[mainnet]["WeETHDexUSDC-USDT"] = 0x01F0D07fdE184614216e76782c6b7dF663F5375e.toBytes32();
        values[mainnet]["wBTC-cbBTCDex-USDT"] = 0xf7FA55D14C71241e3c970E30C509Ff58b5f5D557.toBytes32();
        values[mainnet]["weETH_ETHDex_wstETH"] = 0xb4a15526d427f4d20b0dAdaF3baB4177C85A699A.toBytes32();
        values[mainnet]["GHO_USDCDex_GHO_USDCDex"] = 0x20b32C597633f12B44CFAFe0ab27408028CA0f6A.toBytes32();
        values[mainnet]["LBTC_cbBTCDex_WBTC"] = 0x96B2A29823d475468eE6f15e07878adf79E8199b.toBytes32();
        values[mainnet]["wBTC_cbBTCDex_wBTC_cbBTC"] = 0xDCe03288F9A109150f314ED0Ca9b59a690300d9d.toBytes32();
        values[mainnet]["sUSDe_DEX-USDC-USDT"] = 0xe210d8ded13Abe836a10E8Aa956dd424658d0034.toBytes32(); //T3
        values[mainnet]["wstETH_ETH"] = 0x82B27fA821419F5689381b565a8B0786aA2548De.toBytes32(); //T1
        values[mainnet]["DEX-wstETH-ETH_DEX-wstETH-ETH"] = 0x528CF7DBBff878e02e48E83De5097F8071af768D.toBytes32(); //T4
        values[mainnet]["wstUSR-USDC"] = 0xee327311D8640156E87eC33ea55FcbF2309e0ce6.toBytes32(); //T1
        values[mainnet]["wstUSR-USDT"] = 0x984636a30ed2B4A61FB7150CED644096349275d3.toBytes32();
        // Symbiotic
        values[mainnet]["wstETHDefaultCollateral"] = 0xC329400492c6ff2438472D4651Ad17389fCb843a.toBytes32();
        values[mainnet]["cbETHDefaultCollateral"] = 0xB26ff591F44b04E78de18f43B46f8b70C6676984.toBytes32();
        values[mainnet]["wBETHDefaultCollateral"] = 0x422F5acCC812C396600010f224b320a743695f85.toBytes32();
        values[mainnet]["rETHDefaultCollateral"] = 0x03Bf48b8A1B37FBeAd1EcAbcF15B98B924ffA5AC.toBytes32();
        values[mainnet]["mETHDefaultCollateral"] = 0x475D3Eb031d250070B63Fa145F0fCFC5D97c304a.toBytes32();
        values[mainnet]["swETHDefaultCollateral"] = 0x38B86004842D3FA4596f0b7A0b53DE90745Ab654.toBytes32();
        values[mainnet]["sfrxETHDefaultCollateral"] = 0x5198CB44D7B2E993ebDDa9cAd3b9a0eAa32769D2.toBytes32();
        values[mainnet]["ETHxDefaultCollateral"] = 0xBdea8e677F9f7C294A4556005c640Ee505bE6925.toBytes32();
        values[mainnet]["uniETHDefaultCollateral"] = 0x1C57ea879dd3e8C9fefa8224fdD1fa20dd54211E.toBytes32();
        values[mainnet]["sUSDeDefaultCollateral"] = 0x19d0D8e6294B7a04a2733FE433444704B791939A.toBytes32();
        values[mainnet]["wBTCDefaultCollateral"] = 0x971e5b5D4baa5607863f3748FeBf287C7bf82618.toBytes32();
        values[mainnet]["tBTCDefaultCollateral"] = 0x0C969ceC0729487d264716e55F232B404299032c.toBytes32();
        values[mainnet]["ethfiDefaultCollateral"] = 0x21DbBA985eEA6ba7F27534a72CCB292eBA1D2c7c.toBytes32();
        values[mainnet]["LBTCDefaultCollateral"] = 0x9C0823D3A1172F9DdF672d438dec79c39a64f448.toBytes32();

        values[mainnet]["wstETHSymbioticVault"] = 0xBecfad885d8A89A0d2f0E099f66297b0C296Ea21.toBytes32();
        values[mainnet]["wstETHSymbioticVaultRewards"] = 0xe34DcEA5aB7c4f3c4AD2F5f144Fc7fc3D5b0137C.toBytes32();
        values[mainnet]["EtherFi_LBTCSymbioticVault"] = 0xd4E20ECA1f996Dab35883dC0AD5E3428AF888D45.toBytes32();
        values[mainnet]["EtherFi_wstETHSymbioticVault"] = 0x450a90fdEa8B87a6448Ca1C87c88Ff65676aC45b.toBytes32();

        values[mainnet]["EtherFi_ETHFISymbioticVault"] = 0x2Bcfa0283C92b7845ECE12cEaDc521414BeF1067.toBytes32();

        // Karak
        values[mainnet]["vaultSupervisor"] = 0x54e44DbB92dBA848ACe27F44c0CB4268981eF1CC.toBytes32();
        values[mainnet]["delegationSupervisor"] = 0xAfa904152E04aBFf56701223118Be2832A4449E0.toBytes32();

        values[mainnet]["kmETH"] = 0x7C22725d1E0871f0043397c9761AD99A86ffD498.toBytes32();
        values[mainnet]["kweETH"] = 0x2DABcea55a12d73191AeCe59F508b191Fb68AdaC.toBytes32();
        values[mainnet]["kwstETH"] = 0xa3726beDFD1a8AA696b9B4581277240028c4314b.toBytes32();
        values[mainnet]["krETH"] = 0x8E475A4F7820A4b6c0FF229f74fB4762f0813C47.toBytes32();
        values[mainnet]["kcbETH"] = 0xbD32b8aA6ff34BEDc447e503195Fb2524c72658f.toBytes32();
        values[mainnet]["kwBETH"] = 0x04BB50329A1B7D943E7fD2368288b674c8180d5E.toBytes32();
        values[mainnet]["kswETH"] = 0xc585DF3a8C9ca0c614D023A812624bE36161502B.toBytes32();
        values[mainnet]["kETHx"] = 0x989Ab830C6e2BdF3f28214fF54C9B7415C349a3F.toBytes32();
        values[mainnet]["ksfrxETH"] = 0x1751e1e4d2c9Fa99479C0c5574136F0dbD8f3EB8.toBytes32();
        values[mainnet]["krswETH"] = 0x1B4d88f5f38988BEA334C79f48aa69BEEeFE2e1e.toBytes32();
        values[mainnet]["krsETH"] = 0x9a23e79a8E6D77F940F2C30eb3d9282Af2E4036c.toBytes32();
        values[mainnet]["kETHFI"] = 0xB26bD8D1FD5415eED4C99f9fB6A278A42E7d1BA8.toBytes32();
        values[mainnet]["ksUSDe"] = 0xDe5Bff0755F192C333B126A449FF944Ee2B69681.toBytes32();
        values[mainnet]["kUSDe"] = 0xBE3cA34D0E877A1Fc889BD5231D65477779AFf4e.toBytes32();
        values[mainnet]["kWBTC"] = 0x126d4dBf752AaF61f3eAaDa24Ab0dB84FEcf6891.toBytes32();
        values[mainnet]["kFBTC"] = 0x40328669Bc9e3780dFa0141dBC87450a4af6EA11.toBytes32();
        values[mainnet]["kLBTC"] = 0x468c34703F6c648CCf39DBaB11305D17C70ba011.toBytes32();

        // CCIP token transfers.
        values[mainnet]["ccipRouter"] = 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D.toBytes32();

        // PancakeSwap V3
        values[mainnet]["pancakeSwapV3NonFungiblePositionManager"] =
            0x46A15B0b27311cedF172AB29E4f4766fbE7F4364.toBytes32();
        values[mainnet]["pancakeSwapV3MasterChefV3"] = 0x556B9306565093C855AEA9AE92A594704c2Cd59e.toBytes32();
        values[mainnet]["pancakeSwapV3Router"] = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4.toBytes32();
        // Arbitrum Bridge
        values[mainnet]["arbitrumDelayedInbox"] = 0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f.toBytes32();
        values[mainnet]["arbitrumOutbox"] = 0x0B9857ae2D4A3DBe74ffE1d7DF045bb7F96E4840.toBytes32();
        values[mainnet]["arbitrumL1GatewayRouter"] = 0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef.toBytes32();
        values[mainnet]["arbitrumL1ERC20Gateway"] = 0x0F25c1DC2a9922304f2eac71DCa9B07E310e8E5a.toBytes32();
        values[mainnet]["arbitrumWethGateway"] = 0xd92023E9d9911199a6711321D1277285e6d4e2db.toBytes32();

        // Base Standard Bridge.
        values[mainnet]["baseStandardBridge"] = 0x3154Cf16ccdb4C6d922629664174b904d80F2C35.toBytes32();
        values[mainnet]["basePortal"] = 0x49048044D57e1C92A77f79988d21Fa8fAF74E97e.toBytes32();
        values[mainnet]["baseResolvedDelegate"] = 0x866E82a600A1414e583f7F13623F1aC5d58b0Afa.toBytes32();

        // Optimism Standard Bridge.
        values[mainnet]["optimismStandardBridge"] = 0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1.toBytes32();
        values[mainnet]["optimismPortal"] = 0xbEb5Fc579115071764c7423A4f12eDde41f106Ed.toBytes32();
        values[mainnet]["optimismResolvedDelegate"] = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1.toBytes32();

        // Swell Standard Bridge.
        values[mainnet]["swellStandardBridge"] = 0x7aA4960908B13D104bf056B23E2C76B43c5AACc8.toBytes32();
        values[mainnet]["swellPortal"] = 0x758E0EE66102816F5C3Ec9ECc1188860fbb87812.toBytes32();
        values[mainnet]["swellResolvedDelegate"] = 0xe6a99Ef12995DeFC5ff47EC0e13252f0E6903759.toBytes32();

        // Mantle Standard Bridge.
        values[mainnet]["mantleStandardBridge"] = 0x95fC37A27a2f68e3A647CDc081F0A89bb47c3012.toBytes32();
        values[mainnet]["mantlePortal"] = 0xc54cb22944F2bE476E02dECfCD7e3E7d3e15A8Fb.toBytes32();
        values[mainnet]["mantleResolvedDelegate"] = 0x676A795fe6E43C17c668de16730c3F690FEB7120.toBytes32(); // TODO update this.

        // Zircuit Standard Bridge.
        values[mainnet]["zircuitStandardBridge"] = 0x386B76D9cA5F5Fb150B6BFB35CF5379B22B26dd8.toBytes32();
        values[mainnet]["zircuitPortal"] = 0x17bfAfA932d2e23Bd9B909Fd5B4D2e2a27043fb1.toBytes32();
        values[mainnet]["zircuitResolvedDelegate"] = 0x2a721cBE81a128be0F01040e3353c3805A5EA091.toBytes32();

        // Fraxtal Standard Bridge.
        values[mainnet]["fraxtalStandardBridge"] = 0x34C0bD5877A5Ee7099D0f5688D65F4bB9158BDE2.toBytes32();
        values[mainnet]["fraxtalPortal"] = 0x36cb65c1967A0Fb0EEE11569C51C2f2aA1Ca6f6D.toBytes32();
        values[mainnet]["fraxtalResolvedDelegate"] = 0x2a721cBE81a128be0F01040e3353c3805A5EA091.toBytes32(); // TODO update this

        // Lido Base Standard Bridge.
        values[mainnet]["lidoBaseStandardBridge"] = 0x9de443AdC5A411E83F1878Ef24C3F52C61571e72.toBytes32();
        values[mainnet]["lidoBasePortal"] = 0x49048044D57e1C92A77f79988d21Fa8fAF74E97e.toBytes32();
        values[mainnet]["lidoBaseResolvedDelegate"] = 0x866E82a600A1414e583f7F13623F1aC5d58b0Afa.toBytes32();

        // Lido Unichain Standard Bridge.
        values[mainnet]["lidoUnichainStandardBridge"] = 0x755610f5Be536Ad7afBAa7c10F3E938Ea3aa1877.toBytes32();
        values[mainnet]["lidoUnichainPortal"] = 0x0bd48f6B86a26D3a217d0Fa6FfE2B491B956A7a2.toBytes32();
        values[mainnet]["lidoUnichainResolvedDelegate"] = 0x9A3D64E386C18Cb1d6d5179a9596A4B5736e98A6.toBytes32();

        // Lido Optimism Standard Bridge.
        values[mainnet]["lidoOptimismStandardBridge"] = 0x76943C0D61395d8F2edF9060e1533529cAe05dE6.toBytes32();
        values[mainnet]["lidoOptimismPortal"] = 0xbEb5Fc579115071764c7423A4f12eDde41f106Ed.toBytes32();
        values[mainnet]["lidoOptimismResolvedDelegate"] = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1.toBytes32();

        // Bob Standard Bridge
        values[mainnet]["bobStandardBridge"] = 0x3F6cE1b36e5120BBc59D0cFe8A5aC8b6464ac1f7.toBytes32();
        values[mainnet]["bobPortal"] = 0x8AdeE124447435fE03e3CD24dF3f4cAE32E65a3E.toBytes32();
        values[mainnet]["bobResolvedDelegate"] = 0xE3d981643b806FB8030CDB677D6E60892E547EdA.toBytes32();

        // Unichain Standard Bridge.
        values[mainnet]["unichainStandardBridge"] = 0x81014F44b0a345033bB2b3B21C7a1A308B35fEeA.toBytes32();
        values[mainnet]["unichainPortal"] = 0x0bd48f6B86a26D3a217d0Fa6FfE2B491B956A7a2.toBytes32();
        values[mainnet]["unichainResolvedDelegate"] = 0x9A3D64E386C18Cb1d6d5179a9596A4B5736e98A6.toBytes32();

        // Ink Standard Bridge.
        values[mainnet]["inkStandardBridge"] = 0x88FF1e5b602916615391F55854588EFcBB7663f0.toBytes32();
        values[mainnet]["inkPortal"] = 0x5d66C1782664115999C47c9fA5cd031f495D3e4F.toBytes32();
        values[mainnet]["inkResolvedDelegate"] = 0x69d3Cf86B2Bf1a9e99875B7e2D9B6a84426c171f.toBytes32();

        // Layer Zero.
        values[mainnet]["LayerZeroEndPoint"] = 0x1a44076050125825900e736c501f859c50fE728c.toBytes32();
        values[mainnet]["EtherFiOFTAdapter"] = 0xcd2eb13D6831d4602D80E5db9230A57596CDCA63.toBytes32();
        values[mainnet]["weETHOFTAdapterMovement"] = 0x6FFcE32713417569237786cbeFBe355090642bF9.toBytes32();
        values[mainnet]["LBTCOFTAdapter"] = 0x6bc15D7930839Ec18A57F6f7dF72aE1B439D077f.toBytes32();
        values[mainnet]["WBTCOFTAdapter"] = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c.toBytes32();
        values[mainnet]["frxUSDOFTAdapter"] = 0x566a6442A5A6e9895B9dCA97cC7879D632c6e4B0.toBytes32();
        values[mainnet]["usdt0OFTAdapter"] = 0x6C96dE32CEa08842dcc4058c14d3aaAD7Fa41dee.toBytes32();
        values[mainnet]["LBTCOFTAdapterTAC"] = 0xA7c4d94F98b6e94C139c4645e4E9a94CD7C0Abf7.toBytes32();
        values[mainnet]["WSTETHOFTAdapterTAC"] = 0x6ceA302B297bB8C49E56d04cC080480822795848.toBytes32();
        values[mainnet]["WETHOFTAdapterTAC"] = 0xf211D3B40A74632162F45F4d42A461b663694a9D.toBytes32();
        values[mainnet]["CBBTCOFTAdapterTAC"] = 0x59Ea2825d8Ad7D60cC6Aa77FFbDD0E89c0fBF539.toBytes32();
        values[mainnet]["USDEOFTAdapter"] = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34.toBytes32();
        values[mainnet]["USDTOFTAdapter2"] = 0x1F748c76dE468e9D11bd340fA9D5CBADf315dFB0.toBytes32();
        values[mainnet]["SUSDEOFTAdapter"] = 0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2.toBytes32();

        // Stargate OFTs
        values[mainnet]["stargateUSDC"] = 0xc026395860Db2d07ee33e05fE50ed7bD583189C7.toBytes32();
        values[mainnet]["stargateSolvBTC"] = 0xB12979Ff302Ac903849948037A51792cF7186E8e.toBytes32();
        values[mainnet]["stargatesrUSD"] = 0x316cd39632Cac4F4CdfC21757c4500FE12f64514.toBytes32();
        values[mainnet]["stargateUSDe"] = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34.toBytes32();
        values[mainnet]["stargateNative"] = 0x77b2043768d28E9C9aB44E1aBfC95944bcE57931.toBytes32();

        // Merkl
        values[mainnet]["merklDistributor"] = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae.toBytes32();

        // Pump Staking
        values[mainnet]["pumpStaking"] = 0x1fCca65fb6Ae3b2758b9b2B394CB227eAE404e1E.toBytes32();

        // Linea Bridging
        values[mainnet]["tokenBridge"] = 0x051F1D88f0aF5763fB888eC4378b4D8B29ea3319.toBytes32(); // approve, bridge token
        values[mainnet]["lineaMessageService"] = 0xd19d4B5d358258f05D7B411E21A1460D11B0876F.toBytes32(); // claim message, sendMessage

        // Scroll Bridging
        values[mainnet]["scrollGatewayRouter"] = 0xF8B1378579659D8F7EE5f3C929c2f3E332E41Fd6.toBytes32(); // approve, depositERC20
        values[mainnet]["scrollMessenger"] = 0x6774Bcbd5ceCeF1336b5300fb5186a12DDD8b367.toBytes32(); // sendMessage
        values[mainnet]["scrollCustomERC20Gateway"] = 0x67260A8B73C5B77B55c1805218A42A7A6F98F515.toBytes32(); // sendMessage

        // Syrup
        values[mainnet]["syrupRouter"] = 0x134cCaaA4F1e4552eC8aEcb9E4A2360dDcF8df76.toBytes32(); // keep nomenclature for compatibility
        values[mainnet]["syrupRouterUSDC"] = 0x134cCaaA4F1e4552eC8aEcb9E4A2360dDcF8df76.toBytes32();
        values[mainnet]["syrupRouterUSDT"] = 0xF007476Bb27430795138C511F18F821e8D1e5Ee2.toBytes32();

        // Satlayer
        values[mainnet]["satlayerPool"] = 0x42a856dbEBB97AbC1269EAB32f3bb40C15102819.toBytes32();

        // corn
        values[mainnet]["cornSilo"] = 0x8bc93498b861fd98277c3b51d240e7E56E48F23c.toBytes32();
        values[mainnet]["cornSwapFacilityWBTC"] = 0xBf5eB70b93d5895C839B8BeB3C27dc36f6B56fea.toBytes32();
        values[mainnet]["cornSwapFacilitycbBTC"] = 0x554335b8C994E47e6dbfDC08Fa8aca0510e66BA1.toBytes32();

        values[mainnet]["LBTCOFTAdapter"] = 0x6bc15D7930839Ec18A57F6f7dF72aE1B439D077f.toBytes32();

        // Treehouse
        values[mainnet]["TreehouseRedemption"] = 0xcd63a29FAfF07130d3Af89bB4f40778938AaBB85.toBytes32();
        values[mainnet]["TreehouseRouter"] = 0xeFA3fa8e85D2b3CfdB250CdeA156c2c6C90628F5.toBytes32();
        values[mainnet]["tETH"] = 0xD11c452fc99cF405034ee446803b6F6c1F6d5ED8.toBytes32();
        values[mainnet]["tETH_wstETH_curve_pool"] = 0xA10d15538E09479186b4D3278BA5c979110dDdB1.toBytes32();

        // Term Finance
        values[mainnet]["termAuctionOfferLocker"] = 0xa557a6099d1a85d7569EA4B6d8ad59a94a8162CC.toBytes32();
        values[mainnet]["termRepoLocker"] = 0xFD9033C9A97Bc3Ec8a44439Cb6512516c5053076.toBytes32();
        values[mainnet]["termRepoServicer"] = 0xaD2401Dd7518Fac6C868c86442922E2236797e32.toBytes32();
        values[mainnet]["termRepoToken"] = 0x3A1427da14F8A57CEe76a5E85fB465ed72De8EC7.toBytes32();

        // Hyperlane
        values[mainnet]["hyperlaneUsdcRouter"] = 0xe1De9910fe71cC216490AC7FCF019e13a34481D7.toBytes32();
        values[mainnet]["hyperlaneTestRecipient"] = 0xfb53392bf4a0590a317ca716c28c29ace7c448bc132d7f8188ca234f595aa121;

        // Euler
        values[mainnet]["ethereumVaultConnector"] = 0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383.toBytes32();
        values[mainnet]["evkWEETH"] = 0xe846ca062aB869b66aE8DcD811973f628BA82eAf.toBytes32();
        values[mainnet]["eulerPrimeWETH"] = 0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2.toBytes32();
        values[mainnet]["evkUSDC"] = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9.toBytes32(); //Euler Prime
        values[mainnet]["evkLBTC"] = 0xbC35161043EE2D74816d421EfD6a45fDa73B050A.toBytes32(); //Euler Prime
        values[mainnet]["evkDAI"] = 0x83C266bdf990574a05EE62831a266a3891817B5B.toBytes32();
        values[mainnet]["evkDAIDebt"] = 0x1796526a7705cBBe76dEdd4b13959A48c674A6cD.toBytes32();

        values[mainnet]["evkWETH"] = 0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2.toBytes32();
        values[mainnet]["evkeWETH-2"] = 0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2.toBytes32();

        values[mainnet]["evkeUSDC-2"] = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9.toBytes32();
        values[mainnet]["evkeUSDC-22"] = 0xe0a80d35bB6618CBA260120b279d357978c42BCE.toBytes32();
        values[mainnet]["evkeUSD0-3"] = 0xdEd27A6da244a5f3Ff74525A2cfaD4ed9E5B0957.toBytes32();
        values[mainnet]["evkeUSD0++-2"] = 0x6D671B9c618D5486814FEb777552BA723F1A235C.toBytes32();
        values[mainnet]["evkeUSDT-2"] = 0x313603FA690301b0CaeEf8069c065862f9162162.toBytes32();
        values[mainnet]["evkeUSDT-9"] = 0x7c280DBDEf569e96c7919251bD2B0edF0734C5A8.toBytes32();
        values[mainnet]["evkeUSDe-6"] = 0x2daCa71Cb58285212Dc05D65Cfd4f59A82BC4cF6.toBytes32();
        values[mainnet]["evkeDAI-4"] = 0x83C266bdf990574a05EE62831a266a3891817B5B.toBytes32();
        values[mainnet]["evkeLBTC-2"] = 0xbC35161043EE2D74816d421EfD6a45fDa73B050A.toBytes32();
        values[mainnet]["evkecbBTC-3"] = 0x056f3a2E41d2778D3a0c0714439c53af2987718E.toBytes32();
        values[mainnet]["evkeWBTC-3"] = 0x998D761eC1BAdaCeb064624cc3A1d37A46C88bA4.toBytes32();
        values[mainnet]["evkesUSDe-3"] = 0x498c014dE23f19700F51e85a384AB1B059F0672e.toBytes32();
        values[mainnet]["evkeeBTC-3"] = 0x34716B7026D9e6247D21e37Da1f1b157b62a16e0.toBytes32();
        values[mainnet]["evkesDAI-2"] = 0x8E4AF2F36ed6fb03E5E02Ab9f3C724B6E44C13b4.toBytes32();
        values[mainnet]["evkePYUSD-3"] = 0x6121591077Dc6898Ffd7216eA1b56cb890b3F84d.toBytes32();
        values[mainnet]["evkeUSR-1"] = 0x3A8992754E2EF51D8F90620d2766278af5C59b90.toBytes32();
        values[mainnet]["evkeUSDC-17"] = 0xE0c1bdab9A7d487c4fEcd402cb9b4f8B347e73c3.toBytes32();
        values[mainnet]["evkeUSDC-19"] = 0xcBC9B61177444A793B85442D3a953B90f6170b7D.toBytes32();
        values[mainnet]["evkeLBTC-3"] = 0xA2038a5B7Ce1C195F0C52b77134c5369CCfe0148.toBytes32();
        values[mainnet]["evkePT-wstUSR-27MAR2025-1"] = 0x81fa50cBe6C7Ed61961fE601B7c5AC334c2c84bB.toBytes32();
        values[mainnet]["evkePT-LBTC-27MAR2025-1"] = 0xBc99605074737d36266f45E0d192dDe6CFDFd72a.toBytes32();
        values[mainnet]["evkeWBTC-5"] = 0x82D2CE1f71cbe391c05E21132811e5172d51A6EE.toBytes32();
        values[mainnet]["evkewstUSR-1"] = 0x9f12d29c7CC72bb3d237E2D042A6D890421f9899.toBytes32();
        values[mainnet]["evkecbBTC-4"] = 0x29A9E5A004002Ff9E960bb8BB536E076F53cbDF1.toBytes32();
        values[mainnet]["evkeeBTC-1"] = 0xC605471aE09e0b7daA9e8813707d0DDbf9429Ad2.toBytes32();
        values[mainnet]["eulerCBTC"] = 0x056f3a2E41d2778D3a0c0714439c53af2987718E.toBytes32();
        values[mainnet]["evkeRLUSD-1"] = 0xe1Ce9AF672f8854845E5474400B6ddC7AE458a10.toBytes32();
        values[mainnet]["evkesUSDS-4"] = 0x1cA03621265D9092dC0587e1b50aB529f744aacB.toBytes32();
        values[mainnet]["evkWSTETH"] = 0xbC4B4AC47582c3E38Ce5940B80Da65401F4628f1.toBytes32();

        //values[mainnet]["USR"] = 0x66a1E37c9b0eAddca17d3662D6c05F4DECf3e110.toBytes32();
        //values[mainnet]["wstUSR"] = 0x1202F5C7b4B9E47a1A484E8B270be34dbbC75055.toBytes32();

        // Royco
        values[mainnet]["vaultMarketHub"] = 0xa97eCc6Bfda40baf2fdd096dD33e88bd8e769280.toBytes32();
        values[mainnet]["recipeMarketHub"] = 0x783251f103555068c1E9D755f69458f39eD937c0.toBytes32();
        values[mainnet]["supplyUSDCAaveWrappedVault"] = 0x2120ADcdCF8e0ed9D6dd3Df683F076402B79E3bd.toBytes32();

        // Usual
        values[mainnet]["usualSwapperEngine"] = 0xB969B0d14F7682bAF37ba7c364b351B830a812B2.toBytes32();

        // Sky
        values[mainnet]["daiConverter"] = 0x3225737a9Bbb6473CB4a45b7244ACa2BeFdB276A.toBytes32(); //converts dai to USDS
        values[mainnet]["usdsLitePsmUsdc"] = 0xA188EEC8F81263234dA3622A406892F3D630f98c.toBytes32();
        values[mainnet]["daiLitePsmUsdc"] = 0xf6e72Db5454dd049d0788e411b06CfAF16853042.toBytes32();

        // Resolv
        values[mainnet]["UsrExternalRequestsManager"] = 0xAC85eF29192487E0a109b7f9E40C267a9ea95f2e.toBytes32();

        //Sonic Gateway
        values[mainnet]["sonicGateway"] = 0xa1E2481a9CD0Cb0447EeB1cbc26F1b3fff3bec20.toBytes32();

        // Incentives Distributors
        values[mainnet]["beraUsual_incentives_distributor"] = 0x4a610757352d63D45B0a1680e95158887955582C.toBytes32();

        // Morpho Rewards
        values[mainnet]["morphoRewardsWrapper"] = 0x9D03bb2092270648d7480049d0E58d2FcF0E5123.toBytes32();
        values[mainnet]["legacyMorpho"] = 0x9994E35Db50125E0DF82e4c2dde62496CE330999.toBytes32();
        values[mainnet]["newMorpho"] = 0x58D97B57BB95320F9a05dC918Aef65434969c2B2.toBytes32();

        // Lombard
        values[mainnet]["lbtcBridge"] = 0xA869817b48b25EeE986bdF4bE04062e6fd2C418B.toBytes32();

        // Spectra
        values[mainnet]["ysUSDC"] = 0xF7DE3c70F2db39a188A81052d2f3C8e3e217822a.toBytes32(); //SuperUSDC Vault
        values[mainnet]["ysUSDC_PT"] = 0x3b9739eE0c3b5bD7b392a801DEaC1dc68cfB0C48.toBytes32();
        values[mainnet]["ysUSDC_YT"] = 0x9b9968Ba66B06c4340e60cB4dEa237CC6e3E5999.toBytes32();
        values[mainnet]["ysUSDC_Pool"] = 0xd7e163a91D11cfa2B4059f1626cCd6e33b143cbc.toBytes32();
        values[mainnet]["sRLP_Pool"] = 0x75c91a79Faf0fe64AcCdBd51e3fA6321d8952D84.toBytes32();
        values[mainnet]["sRLP_PT"] = 0x1F7Aa7104db822987E1F44A66dF709A8C4Fb301a.toBytes32();
        values[mainnet]["sRLP_YT"] = 0xC07cF8e6D7F6F47E196D36a4c18287E86f76b046.toBytes32();
        values[mainnet]["sRLP"] = 0x4eaFef6149C5B0c3E42fF444F79675B3E3125cb7.toBytes32();

        values[mainnet]["spectra_stkGHO_Pool"] = 0x9429E06FFD09Cf97007791B8bF3845171f1425E8.toBytes32();
        values[mainnet]["spectra_stkGHO_PT"] = 0x0F7454c4537AFe1243df65842C7919b5d6d6198C.toBytes32();
        values[mainnet]["spectra_stkGHO_YT"] = 0xdfB8D94C25C8Cfc4df171077fAd479AdAaef51c9.toBytes32();
        values[mainnet]["spectra_stkGHO"] = 0xa94ec39c91DF334DCAb55aDaA8EdD9C1dAF67cA7.toBytes32();

        values[mainnet]["spectra_stkGHO_Pool_04_28_25"] = 0xd527aED4030C5034825A69A7AEBF7EC241Aac024.toBytes32();
        values[mainnet]["spectra_stkGHO_PT_04_28_25"] = 0x2598Ba9fed26B6C10C5BE98Ae38f06BB28CFB814.toBytes32();
        values[mainnet]["spectra_stkGHO_YT_04_28_25"] = 0x477F0EA1bA96724f2c0BF42B589d8dC1BAB464C9.toBytes32();
        values[mainnet]["spectra_stkGHO_IBT_04_28_25"] = 0xa94ec39c91DF334DCAb55aDaA8EdD9C1dAF67cA7.toBytes32();

        values[mainnet]["spectra_lvlUSD_Pool"] = 0xAd6Cd1Aceb6E919E4C4918503C22a3F531cf8276.toBytes32();
        values[mainnet]["spectra_lvlUSD_PT"] = 0xBC30e564052a622d6b50170b73fF14ee49eEaDE0.toBytes32();
        values[mainnet]["spectra_lvlUSD_YT"] = 0xA6676B5d6D56F905d084914b70B2cC9C383f1A23.toBytes32();
        values[mainnet]["spectra_lvlUSD_IBT"] = 0x4737D9b4592B40d51e110b94c9C043c6654067Ae.toBytes32();
        values[mainnet]["spectra_sdeUSD_Pool"] = 0xFb7c3C95f4C2C05F6eC7dcFE3e368a40eB338603.toBytes32();
        values[mainnet]["spectra_sdeUSD_PT"] = 0xb4B8925c4CBce692F37C9D946883f2E330a042a9.toBytes32();
        values[mainnet]["spectra_sdeUSD_YT"] = 0xE9677Bfde5830B100281178681C7e78c7d861D1C.toBytes32();
        values[mainnet]["spectra_sdeUSD_IBT"] = 0x5C5b196aBE0d54485975D1Ec29617D42D9198326.toBytes32();
        values[mainnet]["spectra_wstUSR_Pool"] = 0x16D050778B6599ce94993d2Ff83F8dA7136421A9.toBytes32();
        values[mainnet]["spectra_wstUSR_PT"] = 0x4A977653c58CFD82d42fd706cf68A0c1B6d0ca56.toBytes32();
        values[mainnet]["spectra_wstUSR_YT"] = 0x4aA2D6c3d8c0FD28C968057DBc109ddf00a0b281.toBytes32();
        values[mainnet]["spectra_wstUSR_IBT"] = 0x1202F5C7b4B9E47a1A484E8B270be34dbbC75055.toBytes32();

        // Odos
        values[mainnet]["odosRouterV2"] = 0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559.toBytes32();
        values[mainnet]["odosExecutor"] = 0x365084B05Fa7d5028346bD21D842eD0601bAB5b8.toBytes32();

        // GlueX
        values[mainnet]["glueXRouter"] = 0xe95F6EAeaE1E4d650576Af600b33D9F7e5f9f7fd.toBytes32();
        values[mainnet]["glueXExecutor"] = 0x2102Ab11A3c74B1D543891020969dc3D46C132AB.toBytes32();

        // Sushi/Swnapper/RedSnwapper
        values[mainnet]["redSnwapperRouter"] = 0xAC4c6e212A361c968F1725b4d055b47E63F80b75.toBytes32();
        values[mainnet]["redSnwapperExecutor"] = 0xd2b37aDE14708bf18904047b1E31F8166d39612b.toBytes32();

        // Level
        values[mainnet]["levelMinter"] = 0x9136aB0294986267b71BeED86A75eeb3336d09E1.toBytes32();
        values[mainnet]["levelShares"] = 0x834D9c7688ca1C10479931dE906bCC44879A0446.toBytes32();

        // Permit2
        values[mainnet]["permit2"] = 0x000000000022D473030F116dDEE9F6B43aC78BA3.toBytes32();

        // ELX Claiming
        values[mainnet]["elxTokenDistributor"] = 0xeb5D4b79e95Edb5567f3f9703FbD56a107905c0C.toBytes32();

        // Derive
        values[mainnet]["derive_LBTC_basis_deposit"] = 0x76624ff43D610F64177Bb9c194A2503642e9B803.toBytes32();
        values[mainnet]["derive_LBTC_basis_deposit_connector"] = 0x457379de638CAFeB1759a22457fe893b288E2e89.toBytes32();
        values[mainnet]["derive_LBTC_basis_token"] = 0xdFd366D941A51e1f53Fbddb19FB4eE3af17FF991.toBytes32();
        values[mainnet]["derive_LBTC_basis_withdraw"] = 0x954bE1803546150bfd887c9ff70fd221F2F505d3.toBytes32();
        values[mainnet]["derive_LBTC_basis_withdraw_connector"] = 0x5E72430EC945CCc183c34e2860FFC2b5bac712c2.toBytes32();
        values[mainnet]["derive_controller"] = 0x52CB41109b637F03B81b3FD6Dce4E3948b2F0923.toBytes32();
        values[mainnet]["derive_LBTC_connectorPlugOnDeriveChain"] =
            0x2E1245D57a304C7314687E529D610071628117f3.toBytes32();
        //values[mainnet]["derive_boringTestVault_wallet"] = .toBytes32();

        // Mellow
        values[mainnet]["dvStETHVault"] = 0x5E362eb2c0706Bd1d134689eC75176018385430B.toBytes32();
        values[mainnet]["rstETHRestakingVault"] = 0x7b276aAD6D2ebfD7e270C5a2697ac79182D9550E.toBytes32();

        // King
        values[mainnet]["kingMerkleDistributor"] = 0x6Db24Ee656843E3fE03eb8762a54D86186bA6B64.toBytes32();

        // STONE
        values[mainnet]["stoneVault"] = 0xA62F9C5af106FeEE069F38dE51098D9d81B90572.toBytes32();

        // CCTP USDC Bridge
        values[mainnet]["usdcTokenMessengerV2"] = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d.toBytes32();
        values[mainnet]["usdcMessageTransmitterV2"] = 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64.toBytes32();

        // Yearn
        values[mainnet]["yKatanaPredepositWETH"] = 0xcc6a16Be713f6a714f68b0E1f4914fD3db15fBeF.toBytes32();

        // Avalanche Bridge
        values[mainnet]["usdcTokenRouter"] = 0xD835dbD135AD8a27214ecdEE79E7a41337865648.toBytes32();
        values[mainnet]["avalancheBridge"] = 0x8EB8a3b98659Cce290402893d0123abb75E3ab28.toBytes32();

        // Agglayer Katana
        values[mainnet]["agglayerBridgeKatana"] = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe.toBytes32();

        // MF-ONE 
        values[mainnet]["mfOneDepositVault"] = 0x41438435c20B1C2f1fcA702d387889F346A0C3DE.toBytes32();
        values[mainnet]["mfOneRedemptionVault"] = 0x44b0440e35c596e858cEA433D0d82F5a985fD19C.toBytes32();

        // Ethena
        values[mainnet]["ethenaMinterV2"] = 0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3.toBytes32();
    
        //Mellow DVstETH 
        values[mainnet]["dvStethWhitelistedEthWrapper"] = 0xfD4a4922d1AFe70000Ce0Ec6806454e78256504e.toBytes32();
    
    }

    function _addBaseValues() private {
        // Liquid Ecosystem
        values[base]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[base]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[base]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[base]["dev5Address"] = 0x1cdF47387358A1733968df92f7cC14546D9E1047.toBytes32();
        values[base]["txBundlerAddress"] = 0x633ccAFEF3F42F87a457c44ffF826a5b6fc99706.toBytes32();
        values[base]["liquidPayoutAddress"] = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A.toBytes32();
        values[base]["permit2"] = 0x000000000022D473030F116dDEE9F6B43aC78BA3.toBytes32();

        // DeFi Ecosystem
        values[base]["ETH"] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE.toBytes32();
        values[base]["uniswapV3NonFungiblePositionManager"] = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1.toBytes32();

        values[base]["USDC"] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913.toBytes32();
        values[base]["USDT"] = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2.toBytes32();
        values[base]["WETH"] = 0x4200000000000000000000000000000000000006.toBytes32();
        values[base]["WEETH"] = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A.toBytes32(); //also OFT
        values[base]["weETH"] = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A.toBytes32();
        values[base]["WSTETH"] = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452.toBytes32();
        values[base]["AERO"] = 0x940181a94A35A4569E4529A3CDfB74e38FD98631.toBytes32();
        values[base]["CBETH"] = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22.toBytes32();
        values[base]["AURA"] = 0x1509706a6c66CA549ff0cB464de88231DDBe213B.toBytes32();
        values[base]["BAL"] = 0x4158734D47Fc9692176B5085E0F52ee0Da5d47F1.toBytes32();
        values[base]["CRV"] = 0x8Ee73c484A26e0A5df2Ee2a4960B789967dd0415.toBytes32();
        values[base]["LINK"] = 0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196.toBytes32();
        values[base]["UNI"] = 0xc3De830EA07524a0761646a6a4e4be0e114a3C83.toBytes32();
        values[base]["RETH"] = 0xB6fe221Fe9EeF5aBa221c348bA20A1Bf5e73624c.toBytes32();
        values[base]["BSDETH"] = 0xCb327b99fF831bF8223cCEd12B1338FF3aA322Ff.toBytes32();
        values[base]["SFRXETH"] = 0x1f55a02A049033E3419a8E2975cF3F572F4e6E9A.toBytes32();
        values[base]["cbBTC"] = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf.toBytes32();
        values[base]["tBTC"] = 0x236aa50979D5f3De3Bd1Eeb40E81137F22ab794b.toBytes32();
        values[base]["dlcBTC"] = 0x12418783e860997eb99e8aCf682DF952F721cF62.toBytes32();
        values[base]["PENDLE"] = 0xA99F6e6785Da0F5d6fB42495Fe424BCE029Eeb3E.toBytes32();
        values[base]["MORPHO"] = 0xBAa5CC21fd487B8Fcc2F632f3F4E8D37262a0842.toBytes32();
        values[base]["LBTC"] = 0xecAc9C5F704e954931349Da37F60E39f515c11c1.toBytes32();
        values[base]["WBTC"] = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c.toBytes32();
        values[base]["ZRO"] = 0x6985884C4392D348587B19cb9eAAf157F13271cd.toBytes32();

        values[base]["LayerZeroEndPoint"] = 0x1a44076050125825900e736c501f859c50fE728c.toBytes32();

        // Balancer vault
        values[base]["balancerV3VaultExplorer"] = 0xaD89051bEd8d96f045E8912aE1672c6C0bF8a85E.toBytes32();
        values[base]["balancerV3Router"] = 0x3f170631ed9821Ca51A59D996aB095162438DC10.toBytes32();
        values[base]["vault"] = 0xBA12222222228d8Ba445958a75a0704d566BF2C8.toBytes32();
        values[base]["balancerVault"] = 0xBA12222222228d8Ba445958a75a0704d566BF2C8.toBytes32();
        values[base]["wstETH-fWETH-pool"] = 0x9972c4f21b5Ae6062233031314aDbBddA7513Ed2.toBytes32();
        values[base]["wstETH-fWETH-pool-guage"] = 0xf63c00BeAd3A6bcB970B55864c8E0BAB9A56Bd47.toBytes32();

        // Standard Bridge.
        values[base]["standardBridge"] = 0x4200000000000000000000000000000000000010.toBytes32();
        values[base]["crossDomainMessenger"] = 0x4200000000000000000000000000000000000007.toBytes32();

        // Lido Standard Bridge.
        values[base]["l2ERC20TokenBridge"] = 0xac9D11cD4D7eF6e54F14643a393F68Ca014287AB.toBytes32();

        values[base]["weETH_ETH_ExchangeRate"] = 0x35e9D7001819Ea3B39Da906aE6b06A62cfe2c181.toBytes32();

        // Aave V3
        values[base]["v3Pool"] = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5.toBytes32();
        values[base]["v3RewardsController"] = 0xf9cc4F0D883F1a1eb2c253bdb46c254Ca51E1F44.toBytes32();

        // Merkl
        values[base]["merklDistributor"] = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae.toBytes32();

        // Aerodrome
        values[base]["aerodromeRouter"] = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43.toBytes32();
        values[base]["aerodromeNonFungiblePositionManager"] = 0x827922686190790b37229fd06084350E74485b72.toBytes32();
        values[base]["aerodrome_Weth_Wsteth_v3_1_gauge"] = 0x2A1f7bf46bd975b5004b61c6040597E1B6117040.toBytes32();
        values[base]["aerodrome_Weth_Bsdeth_v3_1_gauge"] = 0x0b537aC41400433F09d97Cd370C1ea9CE78D8a74.toBytes32();
        values[base]["aerodrome_Cbeth_Weth_v3_1_gauge"] = 0xF5550F8F0331B8CAA165046667f4E6628E9E3Aac.toBytes32();
        values[base]["aerodrome_Weth_Wsteth_v2_30_gauge"] = 0xDf7c8F17Ab7D47702A4a4b6D951d2A4c90F99bf4.toBytes32();
        values[base]["aerodrome_Weth_Weeth_v2_30_gauge"] = 0xf8d47b641eD9DF1c924C0F7A6deEEA2803b9CfeF.toBytes32();
        values[base]["aerodrome_Weth_Reth_v2_05_gauge"] = 0xAa3D51d36BfE7C5C63299AF71bc19988BdBa0A06.toBytes32();
        values[base]["aerodrome_Sfrxeth_Wsteth_v2_30_gauge"] = 0xCe7Cb6260fCBf17485cd2439B89FdDf8B0Eb39cC.toBytes32();
        values[base]["aerodrome_LBTC_cbBTC_gauge"] = 0xc3f97660D0b47F0E05C3c513f73eeff7c1bd6c7a.toBytes32();

        // MorphoBlue
        values[base]["morphoBlue"] = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb.toBytes32();
        values[base]["weETH_wETH_915"] = 0x78d11c03944e0dc298398f0545dc8195ad201a18b0388cb8058b1bcb89440971;
        values[base]["wstETH_wETH_945"] = 0x3a4048c64ba1b375330d376b1ce40e4047d03b47ab4d48af484edec9fec801ba;
        values[base]["cbETH_wETH_965"] = 0x6600aae6c56d242fa6ba68bd527aff1a146e77813074413186828fd3f1cdca91;
        values[base]["cbETH_wETH_945"] = 0x84662b4f95b85d6b082b68d32cf71bb565b3f22f216a65509cc2ede7dccdfe8c;

        // MetaMorpho
        values[base]["gauntletCbBTCcore"] = 0x6770216aC60F634483Ec073cBABC4011c94307Cb.toBytes32();
        values[base]["gauntletLBTCcore"] = 0x0D05e6ec0A10f9fFE9229EAA785c11606a1d13Fb.toBytes32();
        values[base]["seamlessCbBTC"] = 0x5a47C803488FE2BB0A0EAaf346b420e4dF22F3C7.toBytes32();
        values[base]["moonwellCbBTC"] = 0x543257eF2161176D7C8cD90BA65C2d4CaEF5a796.toBytes32();

        values[base]["uniV3Router"] = 0x2626664c2603336E57B271c5C0b26F421741e481.toBytes32();

        values[base]["aggregationRouterV5"] = 0x1111111254EEB25477B68fb85Ed929f73A960582.toBytes32();
        values[base]["oneInchExecutor"] = 0x8C864D0c8E476Bf9eb9d620C10E1296fb0E2F940.toBytes32();

        // Compound V3
        values[base]["cWETHV3"] = 0x46e6b214b524310239732D51387075E0e70970bf.toBytes32();
        values[base]["cometRewards"] = 0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1.toBytes32();

        // Instadapp Fluid
        values[base]["fWETH"] = 0x9272D6153133175175Bc276512B2336BE3931CE9.toBytes32();
        values[base]["fWSTETH"] = 0x896E39f0E9af61ECA9dD2938E14543506ef2c2b5.toBytes32();

        // Fluid Dex
        values[base]["weETH_ETHDex_wstETH"] = 0xE6b5D1CdC4935295c84772C4700932b4BFC93274.toBytes32();

        // Pendle
        values[base]["pendleMarketFactory"] = 0x59968008a703dC13E6beaECed644bdCe4ee45d13.toBytes32();
        values[base]["pendleRouter"] = 0x888888888889758F76e7103c6CbF23ABbF58F946.toBytes32();
        values[base]["pendleOracle"] = 0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2.toBytes32();
        values[base]["pendleLimitOrderRouter"] = 0x000000000000c9B3E2C3Ec88B1B4c0cD853f4321.toBytes32();

        values[base]["pendle_LBTC_05_28_25"] = 0x727cEbAcfb10fFd353Fc221D06A862B437eC1735.toBytes32();
        values[base]["pendle_LBTC_09_24_25"] = 0x4EaE2e40C6612005214ea919cc7653dA853Ed409.toBytes32();

        // Odos
        values[base]["odosRouterV2"] = 0x19cEeAd7105607Cd444F5ad10dd51356436095a1.toBytes32();
        values[base]["odosExecutor"] = 0x2a8466a3135d1E4D51B2eBe07bfb9D1f6797795b.toBytes32();

        // LBTC Bridge
        values[base]["lbtcBridge"] = 0xA869817b48b25EeE986bdF4bE04062e6fd2C418B.toBytes32();
    }

    function _addArbitrumValues() private {
        // Liquid Ecosystem
        values[arbitrum]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[arbitrum]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[arbitrum]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[arbitrum]["dev5Address"] = 0x1cdF47387358A1733968df92f7cC14546D9E1047.toBytes32();
        values[arbitrum]["liquidPayoutAddress"] = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A.toBytes32();
        values[arbitrum]["txBundlerAddress"] = 0x87D51666Da1b56332b216D456D1C2ba3Aed6089c.toBytes32();

        // DeFi Ecosystem
        values[arbitrum]["ETH"] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE.toBytes32();
        values[arbitrum]["permit2"] = 0x000000000022D473030F116dDEE9F6B43aC78BA3.toBytes32();
        values[arbitrum]["uniV3Router"] = 0xE592427A0AEce92De3Edee1F18E0157C05861564.toBytes32();
        values[arbitrum]["uniV2Router"] = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D.toBytes32();
        values[arbitrum]["uniswapV3NonFungiblePositionManager"] = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88.toBytes32();
        values[arbitrum]["ccipRouter"] = 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8.toBytes32();
        values[arbitrum]["vault"] = 0xBA12222222228d8Ba445958a75a0704d566BF2C8.toBytes32();
        values[arbitrum]["LayerZeroEndPoint"] = 0x1a44076050125825900e736c501f859c50fE728c.toBytes32();

        values[arbitrum]["USDC"] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831.toBytes32();
        values[arbitrum]["USDCe"] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8.toBytes32();
        values[arbitrum]["WETH"] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1.toBytes32();
        values[arbitrum]["WBTC"] = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f.toBytes32();
        values[arbitrum]["USDT"] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9.toBytes32();
        values[arbitrum]["DAI"] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1.toBytes32();
        values[arbitrum]["WSTETH"] = 0x5979D7b546E38E414F7E9822514be443A4800529.toBytes32();
        values[arbitrum]["FRAX"] = 0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F.toBytes32();
        values[arbitrum]["BAL"] = 0x040d1EdC9569d4Bab2D15287Dc5A4F10F56a56B8.toBytes32();
        values[arbitrum]["COMP"] = 0x354A6dA3fcde098F8389cad84b0182725c6C91dE.toBytes32();
        values[arbitrum]["LINK"] = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4.toBytes32();
        values[arbitrum]["rETH"] = 0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8.toBytes32();
        values[arbitrum]["RETH"] = 0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8.toBytes32();
        values[arbitrum]["cbETH"] = 0x1DEBd73E752bEaF79865Fd6446b0c970EaE7732f.toBytes32();
        values[arbitrum]["LUSD"] = 0x93b346b6BC2548dA6A1E7d98E9a421B42541425b.toBytes32();
        values[arbitrum]["UNI"] = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0.toBytes32();
        values[arbitrum]["CRV"] = 0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978.toBytes32();
        values[arbitrum]["FRXETH"] = 0x178412e79c25968a32e89b11f63B33F733770c2A.toBytes32();
        values[arbitrum]["SFRXETH"] = 0x95aB45875cFFdba1E5f451B950bC2E42c0053f39.toBytes32();
        values[arbitrum]["ARB"] = 0x912CE59144191C1204E64559FE8253a0e49E6548.toBytes32();
        values[arbitrum]["WEETH"] = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe.toBytes32();
        values[arbitrum]["weETH"] = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe.toBytes32();
        values[arbitrum]["USDE"] = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34.toBytes32();
        values[arbitrum]["AURA"] = 0x1509706a6c66CA549ff0cB464de88231DDBe213B.toBytes32();
        values[arbitrum]["PENDLE"] = 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8.toBytes32();
        values[arbitrum]["RSR"] = 0xCa5Ca9083702c56b481D1eec86F1776FDbd2e594.toBytes32();
        values[arbitrum]["CBETH"] = 0x1DEBd73E752bEaF79865Fd6446b0c970EaE7732f.toBytes32();
        values[arbitrum]["OSETH"] = 0xf7d4e7273E5015C96728A6b02f31C505eE184603.toBytes32();
        values[arbitrum]["RSETH"] = 0x4186BFC76E2E237523CBC30FD220FE055156b41F.toBytes32();
        values[arbitrum]["GRAIL"] = 0x3d9907F9a368ad0a51Be60f7Da3b97cf940982D8.toBytes32();
        values[arbitrum]["cbBTC"] = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf.toBytes32();
        values[arbitrum]["ZRO"] = address(1).toBytes32();

        // Aave V3
        values[arbitrum]["v3Pool"] = 0x794a61358D6845594F94dc1DB02A252b5b4814aD.toBytes32();
        values[arbitrum]["v3RewardsController"] = 0x929EC64c34a17401F460460D4B9390518E5B473e.toBytes32();

        // 1Inch
        values[arbitrum]["aggregationRouterV5"] = 0x1111111254EEB25477B68fb85Ed929f73A960582.toBytes32();
        values[arbitrum]["oneInchExecutor"] = 0x8C864D0c8E476Bf9eb9d620C10E1296fb0E2F940.toBytes32();

        // Odos
        values[arbitrum]["odosRouterV2"] = 0xa669e7A0d4b3e4Fa48af2dE86BD4CD7126Be4e13.toBytes32();
        values[arbitrum]["odosExecutor"] = 0x03222a2b261a12091bBE271e763A7E26b64E25e2.toBytes32();

        values[arbitrum]["balancerVault"] = 0xBA12222222228d8Ba445958a75a0704d566BF2C8.toBytes32();
        values[arbitrum]["balancerV3VaultExplorer"] = 0x22625eEDd92c81a219A83e1dc48f88d54786B017.toBytes32();
        values[arbitrum]["balancerV3Router"] = 0xEAedc32a51c510d35ebC11088fD5fF2b47aACF2E.toBytes32();
        // TODO This Balancer on L2s use a different minting logic so minter is not used
        // but the merkle tree should be refactored for L2s
        values[arbitrum]["minter"] = address(1).toBytes32();

        // Arbitrum native bridging.
        values[arbitrum]["arbitrumL2GatewayRouter"] = 0x5288c571Fd7aD117beA99bF60FE0846C4E84F933.toBytes32();
        values[arbitrum]["arbitrumSys"] = 0x0000000000000000000000000000000000000064.toBytes32();
        values[arbitrum]["arbitrumRetryableTx"] = 0x000000000000000000000000000000000000006E.toBytes32();
        values[arbitrum]["arbitrumL2Sender"] = 0x09e9222E96E7B4AE2a407B98d48e330053351EEe.toBytes32();

        // Pendle
        values[arbitrum]["pendleMarketFactory"] = 0x2FCb47B58350cD377f94d3821e7373Df60bD9Ced.toBytes32();
        values[arbitrum]["pendleRouter"] = 0x888888888889758F76e7103c6CbF23ABbF58F946.toBytes32();
        values[arbitrum]["pendleLimitOrderRouter"] = 0x000000000000c9B3E2C3Ec88B1B4c0cD853f4321.toBytes32();
        values[arbitrum]["pendleWeETHMarketSeptember"] = 0xf9F9779d8fF604732EBA9AD345E6A27EF5c2a9d6.toBytes32();
        values[arbitrum]["pendle_weETH_market_12_25_24"] = 0x6b92feB89ED16AA971B096e247Fe234dB4Aaa262.toBytes32();

        // Gearbox
        values[arbitrum]["dWETHV3"] = 0x04419d3509f13054f60d253E0c79491d9E683399.toBytes32();
        values[arbitrum]["sdWETHV3"] = 0xf3b7994e4dA53E04155057Fd61dc501599d57877.toBytes32();
        values[arbitrum]["dUSDCV3"] = 0x890A69EF363C9c7BdD5E36eb95Ceb569F63ACbF6.toBytes32();
        values[arbitrum]["sdUSDCV3"] = 0xD0181a36B0566a8645B7eECFf2148adE7Ecf2BE9.toBytes32();
        values[arbitrum]["dUSDCeV3"] = 0xa76c604145D7394DEc36C49Af494C144Ff327861.toBytes32();
        values[arbitrum]["sdUSDCeV3"] = 0x608F9e2E8933Ce6b39A8CddBc34a1e3E8D21cE75.toBytes32();

        // Uniswap V3 pools
        values[arbitrum]["wstETH_wETH_01"] = 0x35218a1cbaC5Bbc3E57fd9Bd38219D37571b3537.toBytes32();
        values[arbitrum]["wstETH_wETH_05"] = 0xb93F8a075509e71325c1c2fc8FA6a75f2d536A13.toBytes32();
        values[arbitrum]["PENDLE_wETH_30"] = 0xdbaeB7f0DFe3a0AAFD798CCECB5b22E708f7852c.toBytes32();
        values[arbitrum]["wETH_weETH_30"] = 0xA169d1aB5c948555954D38700a6cDAA7A4E0c3A0.toBytes32();
        values[arbitrum]["wETH_weETH_05"] = 0xd90660A0b8Ad757e7C1d660CE633776a0862b087.toBytes32();
        values[arbitrum]["wETH_weETH_01"] = 0x14353445c8329Df76e6f15e9EAD18fA2D45A8BB6.toBytes32();

        // Chainlink feeds
        values[arbitrum]["weETH_ETH_ExchangeRate"] = 0x20bAe7e1De9c596f5F7615aeaa1342Ba99294e12.toBytes32();

        // Fluid fTokens
        values[arbitrum]["fUSDC"] = 0x1A996cb54bb95462040408C06122D45D6Cdb6096.toBytes32();
        values[arbitrum]["fUSDT"] = 0x4A03F37e7d3fC243e3f99341d36f4b829BEe5E03.toBytes32();
        values[arbitrum]["fWETH"] = 0x45Df0656F8aDf017590009d2f1898eeca4F0a205.toBytes32();
        values[arbitrum]["fWSTETH"] = 0x66C25Cd75EBdAA7E04816F643d8E46cecd3183c9.toBytes32();

        // Merkl
        values[arbitrum]["merklDistributor"] = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae.toBytes32();

        // Vault Craft
        values[arbitrum]["compoundV3Weth"] = 0xC4bBbbAF12B1bE472E6E7B1A76d2756d5C763F95.toBytes32();
        values[arbitrum]["compoundV3WethGauge"] = 0x5E6A9859Dc1b393a82a5874F9cBA22E92d9fbBd2.toBytes32();

        // Camelot
        values[arbitrum]["camelotRouterV2"] = 0xc873fEcbd354f5A56E00E710B90EF4201db2448d.toBytes32();
        values[arbitrum]["camelotRouterV3"] = 0x1F721E2E82F6676FCE4eA07A5958cF098D339e18.toBytes32();
        values[arbitrum]["camelotNonFungiblePositionManager"] = 0x00c7f3082833e796A5b3e4Bd59f6642FF44DCD15.toBytes32();

        // AlgebraV4 / CamelotV4
        values[arbitrum]["algebraV4Router"] = 0xa555826C9a26E13238F657dB06E0A02431839Ef5.toBytes32();
        values[arbitrum]["algebraNonFungiblePositionManager"] = 0x368435A76B1a855D054D3CDf4c20f5E0B2bABBC8.toBytes32();

        // Compound V3
        values[arbitrum]["cWETHV3"] = 0x6f7D514bbD4aFf3BcD1140B7344b32f063dEe486.toBytes32();
        values[arbitrum]["cometRewards"] = 0x88730d254A2f7e6AC8388c3198aFd694bA9f7fae.toBytes32();

        // Balancer
        values[arbitrum]["rsETH_wETH_BPT"] = 0x90e6CB5249f5e1572afBF8A96D8A1ca6aCFFd739.toBytes32();
        values[arbitrum]["rsETH_wETH_Id"] = 0x90e6cb5249f5e1572afbf8a96d8a1ca6acffd73900000000000000000000055c;
        values[arbitrum]["rsETH_wETH_Gauge"] = 0x59907f88C360D576Aa38dba84F26578367F96b6C.toBytes32();
        values[arbitrum]["aura_rsETH_wETH"] = 0x90cedFDb5284a274720f1dB339eEe9798f4fa29d.toBytes32();
        values[arbitrum]["wstETH_sfrxETH_BPT"] = 0xc2598280bFeA1Fe18dFcaBD21C7165c40c6859d3.toBytes32();
        values[arbitrum]["wstETH_sfrxETH_Id"] = 0xc2598280bfea1fe18dfcabd21c7165c40c6859d30000000000000000000004f3;
        values[arbitrum]["wstETH_sfrxETH_Gauge"] = 0x06eaf7bAabEac962301eE21296e711B3052F2c0d.toBytes32();
        values[arbitrum]["aura_wstETH_sfrxETH"] = 0x83D37cbA332ffd53A4336Ee06f3c301B8929E684.toBytes32();
        values[arbitrum]["wstETH_wETH_Gyro_BPT"] = 0x7967FA58B9501600D96bD843173b9334983EE6E6.toBytes32();
        values[arbitrum]["wstETH_wETH_Gyro_Id"] = 0x7967fa58b9501600d96bd843173b9334983ee6e600020000000000000000056e;
        values[arbitrum]["wstETH_wETH_Gyro_Gauge"] = 0x96d7C70c80518Ee189CB6ba672FbD22E4fDD9c19.toBytes32();
        values[arbitrum]["aura_wstETH_wETH_Gyro"] = 0x93e567b423ED470562911078b4d7A902d4E0BEea.toBytes32();
        values[arbitrum]["weETH_wstETH_Gyro_BPT"] = 0xCDCef9765D369954a4A936064535710f7235110A.toBytes32();
        values[arbitrum]["weETH_wstETH_Gyro_Id"] = 0xcdcef9765d369954a4a936064535710f7235110a000200000000000000000558;
        values[arbitrum]["weETH_wstETH_Gyro_Gauge"] = 0xdB66fFFf713B1FA758E348e69E2f2e24595111cF.toBytes32();
        values[arbitrum]["aura_weETH_wstETH_Gyro"] = 0x40bF10900a55c69c9dADdc3dC52465e01AcEF4A4.toBytes32();
        values[arbitrum]["osETH_wETH_BPT"] = 0x42f7Cfc38DD1583fFdA2E4f047F4F6FA06CEFc7c.toBytes32();
        values[arbitrum]["osETH_wETH_Id"] = 0x42f7cfc38dd1583ffda2e4f047f4f6fa06cefc7c000000000000000000000553;
        values[arbitrum]["osETH_wETH_Gauge"] = 0x5DA32F4724373c91Fdc657E0AD7B1836c70A4E52.toBytes32();

        // Karak
        values[arbitrum]["vaultSupervisor"] = 0x399f22ae52a18382a67542b3De9BeD52b7B9A4ad.toBytes32();
        values[arbitrum]["kETHFI"] = 0xc9A908402C7f0e343691cFB8c8Fc637449333ce0.toBytes32();

        // Dolomite
        values[arbitrum]["dolomiteMargin"] = 0x6Bd780E7fDf01D77e4d475c821f1e7AE05409072.toBytes32();
        values[arbitrum]["dolomiteDepositWithdrawRouter"] = 0xAdB9D68c613df4AA363B42161E1282117C7B9594.toBytes32();
        values[arbitrum]["dolomiteBorrowProxy"] = 0x38E49A617305101216eC6306e3a18065D14Bf3a7.toBytes32(); //V2
    }

    function _addOptimismValues() private {
        values[optimism]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[optimism]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[optimism]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[optimism]["dev5Address"] = 0x1cdF47387358A1733968df92f7cC14546D9E1047.toBytes32();
        values[optimism]["liquidPayoutAddress"] = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A.toBytes32();
        values[optimism]["uniV3Router"] = 0xE592427A0AEce92De3Edee1F18E0157C05861564.toBytes32();
        values[optimism]["aggregationRouterV5"] = 0x1111111254EEB25477B68fb85Ed929f73A960582.toBytes32();
        values[optimism]["oneInchExecutor"] = 0x8C864D0c8E476Bf9eb9d620C10E1296fb0E2F940.toBytes32();
        values[optimism]["txBundlerAddress"] = 0xd249755C0E79dF8F3A05C2398A73333eFDb6EB59.toBytes32();
        values[optimism]["LayerZeroEndPoint"] = 0x1a44076050125825900e736c501f859c50fE728c.toBytes32();

        values[optimism]["WETH"] = 0x4200000000000000000000000000000000000006.toBytes32();
        values[optimism]["WEETH"] = 0x346e03F8Cce9fE01dCB3d0Da3e9D00dC2c0E08f0.toBytes32();
        values[optimism]["WSTETH"] = 0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb.toBytes32();
        values[optimism]["RETH"] = 0x9Bcef72be871e61ED4fBbc7630889beE758eb81D.toBytes32();
        values[optimism]["WEETH_OFT"] = 0x5A7fACB970D094B6C7FF1df0eA68D99E6e73CBFF.toBytes32();
        values[optimism]["OP"] = 0x4200000000000000000000000000000000000042.toBytes32();
        values[optimism]["CRV"] = 0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53.toBytes32();
        values[optimism]["AURA"] = 0x1509706a6c66CA549ff0cB464de88231DDBe213B.toBytes32();
        values[optimism]["BAL"] = 0xFE8B128bA8C78aabC59d4c64cEE7fF28e9379921.toBytes32();
        values[optimism]["UNI"] = 0x6fd9d7AD17242c41f7131d257212c54A0e816691.toBytes32();
        values[optimism]["CBETH"] = 0xadDb6A0412DE1BA0F936DCaeb8Aaa24578dcF3B2.toBytes32();
        values[optimism]["ZRO"] = 0x6985884C4392D348587B19cb9eAAf157F13271cd.toBytes32();
        values[optimism]["ETH"] = 0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000.toBytes32();

        values[optimism]["vault"] = 0xBA12222222228d8Ba445958a75a0704d566BF2C8.toBytes32();
        values[optimism]["balancerVault"] = 0xBA12222222228d8Ba445958a75a0704d566BF2C8.toBytes32();
        values[optimism]["minter"] = 0x239e55F427D44C3cc793f49bFB507ebe76638a2b.toBytes32();

        values[optimism]["uniswapV3NonFungiblePositionManager"] = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88.toBytes32();
        values[optimism]["ccipRouter"] = 0x3206695CaE29952f4b0c22a169725a865bc8Ce0f.toBytes32();
        values[optimism]["weETH_ETH_ExchangeRate"] = 0x72EC6bF88effEd88290C66DCF1bE2321d80502f5.toBytes32();

        // Gearbox
        values[optimism]["dWETHV3"] = 0x42dB77B3103c71059F4b997d6441cFB299FD0d94.toBytes32();
        values[optimism]["sdWETHV3"] = 0x704c4C9F0d29257E5b0E526b20b48EfFC8f758b2.toBytes32();

        // Standard Bridge
        values[optimism]["standardBridge"] = 0x4200000000000000000000000000000000000010.toBytes32();
        values[optimism]["crossDomainMessenger"] = 0x4200000000000000000000000000000000000007.toBytes32();

        // Lido Standard Bridge
        values[optimism]["l2ERC20TokenBridge"] = 0x8E01013243a96601a86eb3153F0d9Fa4fbFb6957.toBytes32();

        // Aave V3
        values[optimism]["v3Pool"] = 0x794a61358D6845594F94dc1DB02A252b5b4814aD.toBytes32();

        // Merkl
        values[optimism]["merklDistributor"] = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae.toBytes32();

        // Beethoven
        values[optimism]["wstETH_weETH_BPT"] = 0x2Bb4712247D5F451063b5E4f6948abDfb925d93D.toBytes32();
        values[optimism]["wstETH_weETH_Id"] = 0x2bb4712247d5f451063b5e4f6948abdfb925d93d000000000000000000000136;
        values[optimism]["wstETH_weETH_Gauge"] = 0xF3B314B1D2bd7d9afa8eC637716A9Bb81dBc79e5.toBytes32();
        values[optimism]["aura_wstETH_weETH"] = 0xe351a69EB84a22E113E92A4C683391C95448d7d4.toBytes32();

        // Velodrome
        values[optimism]["velodromeRouter"] = 0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858.toBytes32();
        values[optimism]["velodromeNonFungiblePositionManager"] = 0x416b433906b1B72FA758e166e239c43d68dC6F29.toBytes32();
        values[optimism]["velodrome_Weth_Wsteth_v3_1_gauge"] = 0xb2218A2cFeF38Ca30AE8C88B41f2E2BdD9347E3e.toBytes32();

        // Odos
        values[optimism]["odosRouterV2"] = 0xCa423977156BB05b13A2BA3b76Bc5419E2fE9680.toBytes32();
        values[optimism]["odosExecutor"] = 0xB8fc6Bf89E16e66b5FA9aA44b8393a588Cf1e77c.toBytes32();

        // Aave V3 Rewards Controller (v3Pool already defined above at line 1780)
        values[optimism]["v3RewardsController"] = 0x929EC64c34a17401F460460D4B9390518E5B473e.toBytes32();

        // Compound V3
        values[optimism]["cWETHV3"] = 0xE36A30D249f7761327fd973001A32010b521b6Fd.toBytes32();
        values[optimism]["cometRewards"] = 0x443EA0340cb75a160F31A440722dec7b5bc3C2E9.toBytes32();
    }

    function _addHoleskyValues() private {
        // ERC20
        values[holesky]["WSTETH"] = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D.toBytes32();

        // Symbiotic
        values[holesky]["wstETHSymbioticVault"] = 0xd88dDf98fE4d161a66FB836bee4Ca469eb0E4a75.toBytes32();
    }

    function _addMantleValues() private {
        values[mantle]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[mantle]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[mantle]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[mantle]["liquidPayoutAddress"] = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A.toBytes32();
        values[mantle]["balancerVault"] = address(1).toBytes32();

        // ERC20
        values[mantle]["WETH"] = 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111.toBytes32();
        values[mantle]["USDC"] = 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9.toBytes32();
        values[mantle]["METH"] = 0xcDA86A272531e8640cD7F1a92c01839911B90bb0.toBytes32();

        // Standard Bridge.
        values[mantle]["standardBridge"] = 0x4200000000000000000000000000000000000010.toBytes32();
        values[mantle]["crossDomainMessenger"] = 0x4200000000000000000000000000000000000007.toBytes32();
    }

    function _addZircuitValues() private {
        values[zircuit]["deployerAddress"] = 0xFD65ADF7d2f9ea09287543520a703522E0a360C9.toBytes32();
        values[zircuit]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[zircuit]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[zircuit]["liquidPayoutAddress"] = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A.toBytes32();
        values[zircuit]["balancerVault"] = address(1).toBytes32();

        values[zircuit]["WETH"] = 0x4200000000000000000000000000000000000006.toBytes32();
        values[zircuit]["METH"] = 0x91a0F6EBdCa0B4945FbF63ED4a95189d2b57163D.toBytes32();

        // Standard Bridge.
        values[zircuit]["standardBridge"] = 0x4200000000000000000000000000000000000010.toBytes32();
        values[zircuit]["crossDomainMessenger"] = 0x4200000000000000000000000000000000000007.toBytes32();
    }

    function _addLineaValues() private {
        values[linea]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[linea]["txBundlerAddress"] = 0x04fc9C685961934f552b5e01F15CBBa66B61D92c.toBytes32(); 
        values[linea]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[linea]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[linea]["dev5Address"] = 0x1cdF47387358A1733968df92f7cC14546D9E1047.toBytes32();
        values[linea]["liquidPayoutAddress"] = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A.toBytes32();
        values[linea]["balancerVault"] = address(1).toBytes32();
        // ERC20
        values[linea]["DAI"] = 0x4AF15ec2A0BD43Db75dd04E62FAA3B8EF36b00d5.toBytes32();
        values[linea]["WETH"] = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f.toBytes32();
        values[linea]["WEETH"] = 0x1Bf74C010E6320bab11e2e5A532b5AC15e0b8aA6.toBytes32();
        //values[linea]["STETH"] = .toBytes32();
        values[linea]["WSTETH"] = 0xB5beDd42000b71FddE22D3eE8a79Bd49A568fC8F.toBytes32();
        values[linea]["REX"] = 0xEfD81eeC32B9A8222D1842ec3d99c7532C31e348.toBytes32();
        values[linea]["ZRO"] = address(1).toBytes32();
        values[linea]["USDC"] = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff.toBytes32();
        values[linea]["USDT"] = 0xA219439258ca9da29E9Cc4cE5596924745e12B93.toBytes32();

        // Linea Bridge.
        values[linea]["tokenBridge"] = 0x353012dc4a9A6cF55c941bADC267f82004A8ceB9.toBytes32(); //approve, also bridge token
        values[linea]["lineaMessageService"] = 0x508Ca82Df566dCD1B0DE8296e70a96332cD644ec.toBytes32(); // claim message, sendMessage

        values[linea]["LayerZeroEndPoint"] = 0x1a44076050125825900e736c501f859c50fE728c.toBytes32();

        // Euler
        values[linea]["ethereumVaultConnector"] = 0xd8CeCEe9A04eA3d941a959F68fb4486f23271d09.toBytes32();
        values[linea]["evkewstETH-1"] = 0x359e363c11fC619BE76EEC8BaAa01e61D521aA18.toBytes32();
        values[linea]["evkewETH-1"] = 0xa8A02E6a894a490D04B6cd480857A19477854968.toBytes32();
        values[linea]["evkewstETH-3"] =  0xB770dc4be757Ad72BCb7b8FF4958FB5c6Ee5Aa49.toBytes32();
        values[linea]["evkewETH-7"] = 0xb135dcF653DAFB5ddAa93F926D7000Aa3222EFEE.toBytes32();
        values[linea]["evkeUSDC-1"] = 0xfB6448B96637d90FcF2E4Ad2c622A487d0496e6f.toBytes32();
        values[linea]["evkeUSDT-1"] = 0xCBeF9be95738290188B25ca9A6Dd2bEc417a578c.toBytes32();

        // Odos
        values[linea]["odosRouterV2"] = 0x2d8879046f1559E53eb052E949e9544bCB72f414.toBytes32();
        values[linea]["odosExecutor"] = 0xFB66e944021bf915cFb4dAC2b20653930Bf7d35A.toBytes32();

        // Aave
        values[linea]["v3Pool"] = 0xc47b8C00b0f69a36fa203Ffeac0334874574a8Ac.toBytes32();
        values[linea]["v3RewardsController"] = 0xc67bb8F2314fA0df50cBa314c6509A7bdAD500C0.toBytes32();

    }

    function _addScrollValues() private {
        values[scroll]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[scroll]["txBundlerAddress"] = 0x534b64608E601B581AB0cbF0b03ec9f4c65f3360.toBytes32();
        values[scroll]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[scroll]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[scroll]["liquidPayoutAddress"] = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A.toBytes32();
        values[scroll]["balancerVault"] = address(1).toBytes32();

        // ERC20
        values[scroll]["ETH"] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE.toBytes32();
        values[scroll]["DAI"] = 0xcA77eB3fEFe3725Dc33bccB54eDEFc3D9f764f97.toBytes32();
        values[scroll]["WETH"] = 0x5300000000000000000000000000000000000004.toBytes32();
        values[scroll]["WEETH"] = 0x01f0a31698C4d065659b9bdC21B3610292a1c506.toBytes32(); //also OFT
        values[scroll]["WBTC"] = 0x3C1BCa5a656e69edCD0D4E36BEbb3FcDAcA60Cf1.toBytes32();
        values[scroll]["USDC"] = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4.toBytes32();
        values[scroll]["USDT"] = 0xf55BEC9cafDbE8730f096Aa55dad6D22d44099Df.toBytes32();
        values[scroll]["EBTC"] = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642.toBytes32();
        values[scroll]["ZRO"] = address(1).toBytes32();

        // Layer Zero
        values[scroll]["LayerZeroEndPoint"] = 0x1a44076050125825900e736c501f859c50fE728c.toBytes32();
        values[scroll]["stargateUSDC"] = 0x3Fc69CC4A842838bCDC9499178740226062b14E4.toBytes32();

        // Scroll Bridge.
        values[scroll]["scrollGatewayRouter"] = 0x4C0926FF5252A435FD19e10ED15e5a249Ba19d79.toBytes32(); // withdrawERC20
        values[scroll]["scrollMessenger"] = 0x781e90f1c8Fc4611c9b7497C3B47F99Ef6969CbC.toBytes32(); // sendMessage
        values[scroll]["scrollCustomERC20Gateway"] = 0xaC78dff3A87b5b534e366A93E785a0ce8fA6Cc62.toBytes32(); // sendMessage
        values[scroll]["scrollUSDCGateway"] = 0x33B60d5Dd260d453cAC3782b0bDC01ce84672142.toBytes32();
        values[scroll]["scrollUSDTGateway"] = 0xE2b4795039517653c5Ae8C2A9BFdd783b48f447A.toBytes32();
        values[scroll]["scrollDAIGateway"] = 0xaC78dff3A87b5b534e366A93E785a0ce8fA6Cc62.toBytes32();
        values[scroll]["scrollWBTCGateway"] = 0xE2b4795039517653c5Ae8C2A9BFdd783b48f447A.toBytes32();
        values[scroll]["scrollWETHGateway"] = 0x7003E7B7186f0E6601203b99F7B8DECBfA391cf9.toBytes32();

        // Tellers
        values[scroll]["EBTCTeller"] = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268.toBytes32();
    }

    function _addFraxtalValues() private {
        values[fraxtal]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[fraxtal]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[fraxtal]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[fraxtal]["liquidPayoutAddress"] = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A.toBytes32();
        values[fraxtal]["balancerVault"] = address(1).toBytes32();
        // ERC20
        values[fraxtal]["wfrxETH"] = 0xFC00000000000000000000000000000000000006.toBytes32();

        // Standard Bridge.
        // values[fraxtal]["standardBridge"] = 0x4200000000000000000000000000000000000010.toBytes32();
        // values[fraxtal]["crossDomainMessenger"] = 0x4200000000000000000000000000000000000007.toBytes32();
    }

    function _addBscValues() private {
        values[bsc]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[bsc]["txBundlerAddress"] = 0x633ccAFEF3F42F87a457c44ffF826a5b6fc99706.toBytes32();
        values[bsc]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[bsc]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();

        values[bsc]["LBTC"] = 0xecAc9C5F704e954931349Da37F60E39f515c11c1.toBytes32();
        values[bsc]["WBTC"] = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c.toBytes32();
        values[bsc]["WBNB"] = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c.toBytes32();
        values[bsc]["BTCB"] = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c.toBytes32();
        values[bsc]["USDT"] = 0x55d398326f99059fF775485246999027B3197955.toBytes32(); // 18 decimals weird one
        values[bsc]["mUSD"] = 0xacA92E438df0B2401fF60dA7E4337B687a2435DA.toBytes32();
        values[bsc]["EUL"] = 0x2117E8b79e8E176A670c9fCf945d4348556bfFad.toBytes32();
        values[bsc]["rEUL"] = 0x5e13d41913aDF18bb2acAe34228E8D21f3c2f2Eb.toBytes32();

        // 1Inch
        values[bsc]["aggregationRouterV5"] = 0x1111111254EEB25477B68fb85Ed929f73A960582.toBytes32();
        values[bsc]["oneInchExecutor"] = 0x8C864D0c8E476Bf9eb9d620C10E1296fb0E2F940.toBytes32();

        // PancakeSwapV3
        values[bsc]["pancakeSwapV3NonFungiblePositionManager"] = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364.toBytes32();
        values[bsc]["pancakeSwapV3MasterChefV3"] = 0x556B9306565093C855AEA9AE92A594704c2Cd59e.toBytes32();
        values[bsc]["pancakeSwapV3Router"] = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4.toBytes32();

        // Odos
        values[bsc]["odosRouterV2"] = 0x89b8AA89FDd0507a99d334CBe3C808fAFC7d850E.toBytes32();
        values[bsc]["odosExecutor"] = 0xda4F2e8041aa91A93B1D46Cf224Bbd4e9134a9EC.toBytes32();

        // Balancer Vault
        values[bsc]["balancerVault"] = address(1).toBytes32();

        // Euler
        values[bsc]["ethereumVaultConnector"] = 0xb2E5a73CeE08593d1a076a2AE7A6e02925a640ea.toBytes32();
        values[bsc]["euler-emUSD-1"] = 0x4602269A321650aBb5fB3bCD311b4478469263C6.toBytes32();
        values[bsc]["euler-eUSDT-3"] = 0x5fd02479F938929F6b9fE1b7Af6430cfD4afa6Aa.toBytes32();

        // Merkl
        values[bsc]["merklDistributor"] = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae.toBytes32();

        // LBTC Bridge
        values[bsc]["lbtcBridge"] = 0xA869817b48b25EeE986bdF4bE04062e6fd2C418B.toBytes32();

        // Pendle
        values[bsc]["pendleRouter"] = 0x888888888889758F76e7103c6CbF23ABbF58F946.toBytes32();
        values[bsc]["pendleLimitOrderRouter"] = 0x000000000000c9B3E2C3Ec88B1B4c0cD853f4321.toBytes32();
        values[bsc]["pendleMusdMarket"] = 0x2d1Ee953d17e68673af1401b34FA9A21E5e830F6.toBytes32();
        values[bsc]["pendleMusdSy"] = 0xa809c9814d04282490c0078200a7597452A9452D.toBytes32();
        values[bsc]["pendleMusdPt"] = 0x44fe4959331A07608A13a9a711F86213367b7235.toBytes32();
        values[bsc]["pendleMusdYt"] = 0x9AF5fD2039792b7e9207F8C6bf379AD03c1150e6.toBytes32();

        // Layer Zero
        values[bsc]["LayerZeroEndPoint"] = 0x1a44076050125825900e736c501f859c50fE728c.toBytes32();
        values[bsc]["ZRO"] = address(1).toBytes32();
    }

    function _addCornValues() private {
        values[corn]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[corn]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[corn]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[corn]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[corn]["dev4Address"] = 0x1cdF47387358A1733968df92f7cC14546D9E1047.toBytes32();

        // Tokens
        values[corn]["WBTCN"] = 0xda5dDd7270381A7C2717aD10D1c0ecB19e3CDFb2.toBytes32();
        values[corn]["LBTC"] = 0xecAc9C5F704e954931349Da37F60E39f515c11c1.toBytes32();
        values[corn]["EBTC"] = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642.toBytes32();
        values[corn]["USDT0"] = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642.toBytes32();

        values[corn]["balancerVault"] = address(1).toBytes32();

        values[corn]["ZRO"] = address(69).toBytes32();
        values[corn]["LBTC"] = 0xecAc9C5F704e954931349Da37F60E39f515c11c1.toBytes32();

        // Layer Zero
        values[corn]["LayerZeroEndPoint"] = 0xcb566e3B6934Fa77258d68ea18E931fa75e1aaAa.toBytes32();
        values[corn]["WBTCN_OFT"] = 0x386E7A3a0c0919c9d53c3b04FF67E73Ff9e45Fb6.toBytes32();
        values[corn]["LBTC_OFT"] = 0xfc7B20D9B59A8A466f4fC3d34aA69a7D98e71d7A.toBytes32();

        // Curve
        values[corn]["curve_pool_LBTC_WBTCN"] = 0xAB3291b73a1087265E126E330cEDe0cFd4B8A693.toBytes32();
        values[corn]["curve_gauge_LBTC_WBTCN"] = 0xaE8f74c9eD7F72CA3Ea16955369f13D3d4b78Cd6.toBytes32();

        values[corn]["curve_pool_LBTC_WBTCN_2"] = 0xc77478B0e4eeCEE34EbE2fC4be7eC9Bba20a5ccD.toBytes32();
        values[corn]["curve_gauge_LBTC_WBTCN_2"] = 0xF481735c5e6Dc7C467236aF7D7C7b9c82893c0e4.toBytes32();

        values[corn]["curve_pool_LBTC_WBTCN_EBTC"] = 0xebe423b5466f9675669B2a4521b6E9F852Dd1f52.toBytes32();
        values[corn]["curve_gauge_LBTC_WBTCN_EBTC"] = 0x1AECbE26fA95D63df3F294Ba8C2ee214970df96f.toBytes32();

        // Zerolend
        values[corn]["zeroLendPool"] = 0x927b3A8e5068840C9758b0b88207b28aeeb7a3fd.toBytes32();
        values[corn]["v3RewardsController"] = 0xd9f43fa0ff772b806cbcDd36d0B264fCAd46d677.toBytes32();

        // UniswapV3
        values[corn]["uniswapV3NonFungiblePositionManager"] = 0x743E03cceB4af2efA3CC76838f6E8B50B63F184c.toBytes32();
        values[corn]["uniV3Router"] = 0x807F4E281B7A3B324825C64ca53c69F0b418dE40.toBytes32();

        // CamelotV3
        values[corn]["camelotNonFungiblePositionManager"] = 0x9CC2B9F9a6194C5CC827C88571E42cEAA76FDF47.toBytes32();
        values[corn]["camelotRouterV3"] = 0x30A4bD5b1a9e9C0D80e9a45ef486bc1f1bc8e230.toBytes32();

        // Tellers
        //values[corn]["sBTCNTeller"] = .toBytes32();
        values[corn]["eBTCTeller"] = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268.toBytes32();
        values[corn]["eBTCOnChainQueueFast"] = 0x686696A3e59eE16e8A8533d84B62cfA504827135.toBytes32();

        // Morpho Blue
        values[corn]["morphoBlue"] = 0xc2B1E031540e3F3271C5F3819F0cC7479a8DdD90.toBytes32();
        values[corn]["WBTCN_IDLE_915"] = 0xe0ce6aa148f70d89eda3c051c53a6e2f02f7ee0d1dd06af582ab4c8878ceed23;
        values[corn]["WBTCN_LBTC_915"] = 0x2547ba491a7ff9e8cfcaa3e1c0da739f4fdc1be9fe4a37bfcdf570002153a0de;
        values[corn]["USDT0_IDLE_915"] = 0x1c6b87ae1b97071ef444eedcba9f5a92cfe974edbbcaa1946644fc7ab0e283af;
        values[corn]["WBTCN_USDT0_915"] = 0x9039bf8b5c3cd6f2d3f937e8a2e59ef6af0109a0d0f3499e7dbf75be0aef75ec;
        values[corn]["smokehouseBTCN"] = 0xa7Ba08CFc37e7CC67404d4996FFBB3E977490115.toBytes32();
    }

    function _addSonicMainnetValues() private {
        values[sonicMainnet]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[sonicMainnet]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[sonicMainnet]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[sonicMainnet]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();

        //Withdraw Queues
        values[sonicMainnet]["eBTCOnChainQueueFast"] = 0x686696A3e59eE16e8A8533d84B62cfA504827135.toBytes32();

        // ERC20
        values[sonicMainnet]["ETH"] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE.toBytes32(); //$S token
        values[sonicMainnet]["WETH"] = 0x50c42dEAcD8Fc9773493ED674b675bE577f2634b.toBytes32();
        values[sonicMainnet]["USDC"] = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894.toBytes32();
        values[sonicMainnet]["USDT"] = 0x6047828dc181963ba44974801FF68e538dA5eaF9.toBytes32();
        values[sonicMainnet]["wS"] = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38.toBytes32();
        values[sonicMainnet]["stS"] = 0xE5DA20F15420aD15DE0fa650600aFc998bbE3955.toBytes32();
        values[sonicMainnet]["scUSD"] = 0xd3DCe716f3eF535C5Ff8d041c1A41C3bd89b97aE.toBytes32();
        values[sonicMainnet]["scETH"] = 0x3bcE5CB273F0F148010BbEa2470e7b5df84C7812.toBytes32();
        values[sonicMainnet]["scBTC"] = 0xBb30e76d9Bb2CC9631F7fC5Eb8e87B5Aff32bFbd.toBytes32();
        values[sonicMainnet]["stkscUSD"] = 0x4D85bA8c3918359c78Ed09581E5bc7578ba932ba.toBytes32();
        values[sonicMainnet]["EBTC"] = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642.toBytes32();
        values[sonicMainnet]["LBTC"] = 0xecAc9C5F704e954931349Da37F60E39f515c11c1.toBytes32();
        values[sonicMainnet]["WBTC"] = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c.toBytes32(); //also OFT
        values[sonicMainnet]["BEETS"] = 0x2D0E0814E62D80056181F5cd932274405966e4f0.toBytes32();
        values[sonicMainnet]["rEUL"] = 0x09E6cab47B7199b9d3839A2C40654f246d518a80.toBytes32();
        values[sonicMainnet]["EUL"] = 0x8e15C8D399e86d4FD7B427D42f06c60cDD9397e7.toBytes32();
        values[sonicMainnet]["ZRO"] = address(1).toBytes32();
        values[sonicMainnet]["OS"] = 0xb1e25689D55734FD3ffFc939c4C3Eb52DFf8A794.toBytes32();
        values[sonicMainnet]["roysonicUSDC"] = 0x45088fb2FfEBFDcf4dFf7b7201bfA4Cd2077c30E.toBytes32();
        values[sonicMainnet]["SILO"] = 0x53f753E4B17F4075D6fa2c6909033d224b81e698.toBytes32();
        values[sonicMainnet]["BEETSFRAGMENTSS1"] = 0x3419966bC74fa8f951108d15b053bEd233974d3D.toBytes32();
        values[sonicMainnet]["CRV"] = 0x5Af79133999f7908953E94b7A5CF367740Ebee35.toBytes32();
        values[sonicMainnet]["frxUSD"] = 0x80Eede496655FB9047dd39d9f418d5483ED600df.toBytes32(); //also OFT
        values[sonicMainnet]["UNI"] = 0x2fb960611bdC322A9a4A994252658Cae9fe2eeA1.toBytes32();

        values[sonicMainnet]["balancerVault"] = address(1).toBytes32();
        values[sonicMainnet]["vault"] = address(1).toBytes32();

        // UniswapV3
        values[sonicMainnet]["uniswapV3NonFungiblePositionManager"] =
            0x743E03cceB4af2efA3CC76838f6E8B50B63F184c.toBytes32();
        values[sonicMainnet]["uniV3Router"] = 0xaa52bB8110fE38D0d2d2AF0B85C3A3eE622CA455.toBytes32();

        // Beets/Balancer
        values[sonicMainnet]["balancerVault"] = 0xBA12222222228d8Ba445958a75a0704d566BF2C8.toBytes32();

        values[sonicMainnet]["scUSD_USDC_gauge"] = 0x33B29bcf17e866A35941e07CbAd54f1807B337f5.toBytes32();
        values[sonicMainnet]["scETH_WETH_gauge"] = 0x8828a6e3166cac78F3C90A5b5bf17618BDAf1Deb.toBytes32();
        values[sonicMainnet]["scBTC_LBTC_gauge"] = 0x11c43F630b52F1271a5005839d34b07C0C125e72.toBytes32();

        values[sonicMainnet]["scUSD_USDC_PoolId"] = 0xcd4d2b142235d5650ffa6a38787ed0b7d7a51c0c000000000000000000000037;
        values[sonicMainnet]["scETH_WETH_PoolId"] = 0xe54dd58a6d4e04687f2034dd4ddab49da55f8aff00000000000000000000007c;
        values[sonicMainnet]["USDC_stS_PoolId"] = 0x713fb5036dc70012588d77a5b066f1dd05c712d7000200000000000000000041;
        values[sonicMainnet]["USDC_wS_PoolId"] = 0xfc127dfc32b7739a7cfff7ed19e4c4ab3221953a0002000000000000000000a4;
        values[sonicMainnet]["stS_BEETS_PoolId"] = 0x10ac2f9dae6539e77e372adb14b1bf8fbd16b3e8000200000000000000000005;
        values[sonicMainnet]["USDC_WETH_PoolId"] = 0x308ebea1dc4ead75f0aebd1569e39354e26ae9e600020000000000000000009c;
        values[sonicMainnet]["scBTC_LBTC_PoolId"] = 0x83952912178aa33c3853ee5d942c96254b235dcc0002000000000000000000ab;

        values[sonicMainnet]["scBTC_LBTC_PoolId"] = 0x83952912178aa33c3853ee5d942c96254b235dcc0002000000000000000000ab;

        // Tellers
        values[sonicMainnet]["scUSDTeller"] = 0x358CFACf00d0B4634849821BB3d1965b472c776a.toBytes32();
        values[sonicMainnet]["scETHTeller"] = 0x31A5A9F60Dc3d62fa5168352CaF0Ee05aA18f5B8.toBytes32();
        values[sonicMainnet]["stkscUSDTeller"] = 0x5e39021Ae7D3f6267dc7995BB5Dd15669060DAe0.toBytes32();
        values[sonicMainnet]["stkscETHTeller"] = 0x49AcEbF8f0f79e1Ecb0fd47D684DAdec81cc6562.toBytes32();
        values[sonicMainnet]["roysonicUSDCTeller"] = 0x0F75c8176d4eBDff78d9a0c486B35d8F94b00A42.toBytes32();

        // Queues
        values[sonicMainnet]["roysonicUSDCQueue"] = 0xd0885A285f9a00aa2d9734d2D26be1186f850E38.toBytes32();

        // Accountant
        values[sonicMainnet]["scUSDAccountant"] = 0xA76E0F54918E39A63904b51F688513043242a0BE.toBytes32();
        values[sonicMainnet]["scETHAccountant"] = 0x3a592F9Ea2463379c4154d03461A73c484993668.toBytes32();
        values[sonicMainnet]["stkscUSDAccountant"] = 0x13cCc810DfaA6B71957F2b87060aFE17e6EB8034.toBytes32();
        values[sonicMainnet]["stkscETHAccountant"] = 0x61bE1eC20dfE0197c27B80bA0f7fcdb1a6B236E2.toBytes32();

        // Layer Zero
        values[sonicMainnet]["LayerZeroEndPoint"] = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B.toBytes32();
        values[sonicMainnet]["LBTC_OFT"] = 0x630e12D53D4E041b8C5451aD035Ea841E08391d7.toBytes32();
        values[sonicMainnet]["stargateUSDC"] = 0xA272fFe20cFfe769CdFc4b63088DCD2C82a2D8F9.toBytes32();

        // Sonic Gateway
        values[sonicMainnet]["sonicGateway"] = 0x9Ef7629F9B930168b76283AdD7120777b3c895b3.toBytes32();
        values[sonicMainnet]["circleTokenAdapter"] = 0xe6DCD54B4CDe2e9E935C22F57EBBBaaF5cc3BC8a.toBytes32();

        //Rings
        values[sonicMainnet]["scUSDVoter"] = 0xF365C45B6913BE7Ab74C970D9227B9D0dfF44aFb.toBytes32();
        values[sonicMainnet]["scETHVoter"] = 0x9842be0f52569155fA58fff36E772bC79D92706e.toBytes32();

        // Silo
        values[sonicMainnet]["siloRouter"] = 0x22AacdEc57b13911dE9f188CF69633cC537BdB76.toBytes32();
        values[sonicMainnet]["silo_stS_wS_config"] = 0x78C246f67c8A6cE03a1d894d4Cf68004Bd55Deea.toBytes32();
        values[sonicMainnet]["silo_S_scUSD_config"] = 0xFe514E71F0933F63B374056557AED3dBB381C646.toBytes32();
        values[sonicMainnet]["silo_S_USDC_config"] = 0x4915F6d3C9a7B20CedFc5d3854f2802f30311d13.toBytes32();
        values[sonicMainnet]["silo_wS_USDC_id8_config"] = 0x4915F6d3C9a7B20CedFc5d3854f2802f30311d13.toBytes32();
        values[sonicMainnet]["silo_wS_USDC_id8_USDC_IncentivesController"] =
            0x0dd368Cd6D8869F2b21BA3Cb4fd7bA107a2e3752.toBytes32();
        values[sonicMainnet]["silo_wS_USDC_id8_wS_IncentivesController"] =
            0x89a10bFb6b57AD89b2270d80175914C517E547D9.toBytes32();

        values[sonicMainnet]["silo_wS_USDC_id20_config"] = 0x062A36Bbe0306c2Fd7aecdf25843291fBAB96AD2.toBytes32();
        values[sonicMainnet]["silo_wS_USDC_id20_USDC_IncentivesController"] =
            0x2D3d269334485d2D876df7363e1A50b13220a7D8.toBytes32();

        values[sonicMainnet]["silo_USDC_wstkscUSD_id23_config"] = 0xbC24c0F594ECA381956895957c771437D61400D3.toBytes32();
        values[sonicMainnet]["silo_USDC_wstkscUSD_id23_USDC_IncentivesController"] =
            0xD4599CC9Bb91E84e55620A4E550DF0868aC45175.toBytes32();

        values[sonicMainnet]["silo_S_ETH_config"] = 0x9603Af53dC37F4BB6386f358A51a04fA8f599101.toBytes32();

        values[sonicMainnet]["silo_ETH_wstkscETH_id26_config"] = 0xefA367570B11f8745B403c0D458b9D2EAf424686.toBytes32();

        values[sonicMainnet]["silo_S_scUSD_id15_config"] = 0xFe514E71F0933F63B374056557AED3dBB381C646.toBytes32();
        values[sonicMainnet]["silo_LBTC_scBTC_id32_config"] = 0xe67cce118e9CcEaE51996E4d290f9B77D960E3d7.toBytes32();
        values[sonicMainnet]["silo_LBTC_WBTC_id31_config"] = 0x91D87099fA714a201297856D29380195adB62962.toBytes32();

        values[sonicMainnet]["silo_PT-aUSDC_scUSD_id46_config"] = 0xDa6787a3543a01Bf770DDF3953bE5B9C99c1cBD0.toBytes32();
        values[sonicMainnet]["silo_PT-aUSDC_scUSD_id46_scUSD_IncentivesController"] =
            0xeA3602cD66D09b2B0D887758Dc57c67aBCd9BeEF.toBytes32();

        values[sonicMainnet]["silo_sfrxUSD_scUSD_id48_config"] = 0x6452b9aE8011800457b42C4fBBDf4579afB96228.toBytes32();

        // Silo Vaults
        values[sonicMainnet]["silo_USDC_vault"] = 0xF6F87073cF8929C206A77b0694619DC776F89885.toBytes32();
        values[sonicMainnet]["silo_Mithras_vault"] = 0x391b3F70E254d582588B27e97E48D1CFcdf0BE7e.toBytes32();
        values[sonicMainnet]["silo_RE7_vault"] = 0x592D1e187729C76EfacC6dfFB9355bd7BF47B2a7.toBytes32();

        // Curve
        values[sonicMainnet]["curve_CRV_claiming"] = 0xf3A431008396df8A8b2DF492C913706BDB0874ef.toBytes32();
        values[sonicMainnet]["curve_USDC_scUSD_pool"] = 0x2Fd7CCDa50ED88fe17E15f3d5D8d51da4CCB43F3.toBytes32();
        values[sonicMainnet]["curve_USDC_scUSD_gauge"] = 0x12F89168C995e54Ec2ce9ee461D663a6dC72793A.toBytes32();

        // Euler
        values[sonicMainnet]["ethereumVaultConnector"] = 0x4860C903f6Ad709c3eDA46D3D502943f184D4315.toBytes32();
        values[sonicMainnet]["euler_scETH_MEV"] = 0x0806af1762Bdd85B167825ab1a64E31CF9497038.toBytes32();
        values[sonicMainnet]["euler_WETH_MEV"] = 0xa5cd24d9792F4F131f5976Af935A505D19c8Db2b.toBytes32();
        values[sonicMainnet]["euler_scUSD_MEV"] = 0xB38D431e932fEa77d1dF0AE0dFE4400c97e597B8.toBytes32();
        values[sonicMainnet]["euler_USDC_MEV"] = 0x196F3C7443E940911EE2Bb88e019Fd71400349D9.toBytes32();
        values[sonicMainnet]["euler_USDC_RE7"] = 0x3D9e5462A940684073EED7e4a13d19AE0Dcd13bc.toBytes32();
        values[sonicMainnet]["euler_scUSD_RE7"] = 0xeEb1DC1Ca7ffC5b54aD1cc4c1088Db4E5657Cb6c.toBytes32();

        // Curve
        values[sonicMainnet]["curve_WETH_scETH_pool"] = 0xfF11f56281247EaD18dB76fD23b252156738FA94.toBytes32();
        values[sonicMainnet]["curve_WETH_scETH_gauge"] = 0x4F7Fc3F5112eAef10495B04b5dd376E50c42dA51.toBytes32();

        // Odos
        values[sonicMainnet]["odosRouterV2"] = 0xaC041Df48dF9791B0654f1Dbbf2CC8450C5f2e9D.toBytes32();
        values[sonicMainnet]["odosExecutor"] = 0x3A5D6A7aAb7C1b681892bDc3667C76A5E4116Ba3.toBytes32();

        // Aave
        values[sonicMainnet]["v3Pool"] = 0x5362dBb1e601abF3a4c14c22ffEdA64042E5eAA3.toBytes32();
        values[sonicMainnet]["v3RewardsController"] = 0x24bD6e9ca54F1737467DEf82dCA9702925B3Aa59.toBytes32();
        values[sonicMainnet]["awS"] = 0x6C5E14A212c1C3e4Baf6f871ac9B1a969918c131.toBytes32();

        // Merkl
        values[sonicMainnet]["merklDistributor"] = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae.toBytes32();

        // Royco
        values[sonicMainnet]["recipeMarketHub"] = 0xFcc593aD3705EBcd72eC961c63eb484BE795BDbD.toBytes32();
        values[sonicMainnet]["vaultMarketHub"] = 0x1e3fCccbafDBdf3cB17b7470c8A6cC64eb5f94A2.toBytes32();
        values[sonicMainnet]["originSonicWrappedVault"] = 0x7F24390EF4F8c1a372524fF1fA3a1d79D66D86cA.toBytes32();

        // Permit2
        values[sonicMainnet]["permit2"] = 0x000000000022D473030F116dDEE9F6B43aC78BA3.toBytes32();

        // BalancerV3
        values[sonicMainnet]["balancerV3Router"] = 0x6077b9801B5627a65A5eeE70697C793751D1a71c.toBytes32();
        values[sonicMainnet]["balancerV3Vault"] = 0xbA1333333333a1BA1108E8412f11850A5C319bA9.toBytes32();
        values[sonicMainnet]["balancerV3VaultExplorer"] = 0x6F6CD1a69A19d45df0C300A57829b21713637300.toBytes32();

        values[sonicMainnet]["balancerV3_USDC_scUSD_boosted"] = 0x43026d483f42fB35efe03c20B251142D022783f2.toBytes32();
        values[sonicMainnet]["balancerV3_USDC_scUSD_boosted_gauge"] =
            0x5D9e8B588F1D9e28ea1963681180d8b5938D26BA.toBytes32();
        values[sonicMainnet]["lbtcBridge"] = 0xA869817b48b25EeE986bdF4bE04062e6fd2C418B.toBytes32();

        // CCTP USDC Bridge
        values[sonicMainnet]["usdcTokenMessengerV2"] = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d.toBytes32();
        values[sonicMainnet]["usdcMessageTransmitterV2"] = 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64.toBytes32();
    }

    function _addSepoliaValues() private {
        values[sepolia]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[sepolia]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[sepolia]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[sepolia]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();

        values[sepolia]["WETH"] = 0xb16F35c0Ae2912430DAc15764477E179D9B9EbEa.toBytes32();
        values[sepolia]["CrispyUSD"] = 0x867F14Da2EcD4B582812d76D94c4B10cB00b507C.toBytes32();
        values[sepolia]["USDC"] = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238.toBytes32(); //AAVEv3 USDC
        values[sepolia]["ZRO"] = address(1).toBytes32();
        values[sepolia]["CrispyCoin"] = 0x0c959E3AA0A74E972d1A8F759c198e660CcCebcB.toBytes32();
        values[sepolia]["WETH9"] = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14.toBytes32();
        values[sepolia]["USDT"] = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0.toBytes32(); //AAVEv3 USDT
        values[sepolia]["v3Pool"] = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951.toBytes32(); //AAVEv3 Pool
        values[sepolia]["v3RewardsController"] = 0x4DA5c4da71C5a167171cC839487536d86e083483.toBytes32(); //AAVEv3 Rewards Controller

        values[sepolia]["UltraYieldWETH"] = 0x22C24D6C6CF64B799ce936f86aBfA8984F3F804d.toBytes32();

        values[sepolia]["balancerVault"] = address(1).toBytes32();

        values[sepolia]["LayerZeroEndPoint"] = 0x6EDCE65403992e310A62460808c4b910D972f10f.toBytes32();
        values[sepolia]["uniswapV3NonFungiblePositionManager"] = 0x1238536071E1c677A632429e3655c799b22cDA52.toBytes32();
        values[sepolia]["uniV3Router"] = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E.toBytes32();
    }

    function _addSonicTestnetValues() private {
        values[sonicTestnet]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[sonicTestnet]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[sonicTestnet]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[sonicTestnet]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();

        values[sonicTestnet]["WETH"] = address(1).toBytes32();
        values[sonicTestnet]["CrispyUSD"] = 0x867F14Da2EcD4B582812d76D94c4B10cB00b507C.toBytes32();
        values[sonicTestnet]["ZRO"] = address(1).toBytes32();

        values[sonicTestnet]["balancerVault"] = address(1).toBytes32();

        values[sonicTestnet]["LayerZeroEndPoint"] = 0x6C7Ab2202C98C4227C5c46f1417D81144DA716Ff.toBytes32();
    }

    function _addSonicBlazeValues() private {
        values[sonicBlaze]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[sonicBlaze]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[sonicBlaze]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[sonicBlaze]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();

        values[sonicBlaze]["WETH"] = address(1).toBytes32();
        values[sonicBlaze]["CrispyUSD"] = 0x867F14Da2EcD4B582812d76D94c4B10cB00b507C.toBytes32();
        values[sonicBlaze]["ZRO"] = address(1).toBytes32();

        values[sonicBlaze]["balancerVault"] = address(1).toBytes32();

        values[sonicBlaze]["LayerZeroEndPoint"] = 0x6C7Ab2202C98C4227C5c46f1417D81144DA716Ff.toBytes32();
    }

    function _addBartioValues() private {
        values[bartio]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[bartio]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[bartio]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[bartio]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();

        values[bartio]["balancerVault"] = address(1).toBytes32();
        values[bartio]["vault"] = address(1).toBytes32();

        // ERC20s
        values[bartio]["WBERA"] = 0x7507c1dc16935B82698e4C63f2746A2fCf994dF8.toBytes32();
        values[bartio]["YEET"] = 0x8c245484890a61Eb2d1F81114b1a7216dCe2752b.toBytes32();
        values[bartio]["USDC"] = 0xd6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727c.toBytes32();
        values[bartio]["USDT"] = 0x05D0dD5135E3eF3aDE32a9eF9Cb06e8D37A6795D.toBytes32();
        values[bartio]["DAI"] = 0x806Ef538b228844c73E8E692ADCFa8Eb2fCF729c.toBytes32();
        values[bartio]["iBGT"] = 0x46eFC86F0D7455F135CC9df501673739d513E982.toBytes32();
        values[bartio]["WEETH"] = 0x7Cc43d94818005499D2740975D2aEFD3893E940E.toBytes32();

        // Kodiak
        values[bartio]["kodiakIslandRouterOld"] = 0x5E51894694297524581353bc1813073C512852bf.toBytes32(); //old
        values[bartio]["kodiakIslandRouter"] = 0x35c98A9bA533218155f9324585914e916066A153.toBytes32(); //new

        values[bartio]["kodiak_v1_WBERA_YEET"] = 0xE5A2ab5D2fb268E5fF43A5564e44c3309609aFF9.toBytes32(); //old island
        values[bartio]["kodiak_island_WBERA_YEET_1%"] = 0x0001513F4a1f86da0f02e647609E9E2c630B3a14.toBytes32(); //new island

        // Honey
        values[bartio]["honeyFactory"] = 0xAd1782b2a7020631249031618fB1Bd09CD926b31.toBytes32();

        // Infrared
        values[bartio]["infrared_kodiak_WBERA_YEET_vault"] = 0x89DAFF790313d0Cc5cC9971472f0C73A19D9C167.toBytes32();

        // Goldilocks
        values[bartio]["goldivault_weeth"] = 0xEE4A91F5BFA0Bf54124CF00cc7e144427cCE1162.toBytes32();
        values[bartio]["weethOT"] = 0x6218379852D5609870e91f168B81cbB4532f0346.toBytes32();
        values[bartio]["weethYT"] = 0x401CBe777E8BE57a426A5B5F13Ca4d73200BD95B.toBytes32();
    }

    function _addSwellValues() private {
        values[swell]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[swell]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[swell]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[swell]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();

        values[swell]["balancerVault"] = address(1).toBytes32();
        values[swell]["vault"] = address(1).toBytes32();

        // ERC20s
        values[swell]["ETH"] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE.toBytes32();
        values[swell]["WETH"] = 0x4200000000000000000000000000000000000006.toBytes32();
        values[swell]["WEETH"] = 0xA6cB988942610f6731e664379D15fFcfBf282b44.toBytes32(); //also OFT
        values[swell]["WSWELL"] = 0xda1F8EA667dc5600F5f654DF44b47F1639a83DD1.toBytes32();
        values[swell]["SWELL"] = 0x2826D136F5630adA89C1678b64A61620Aab77Aea.toBytes32();
        values[swell]["USDE"] = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34.toBytes32(); //also OFT

        // Standard Bridge
        values[swell]["standardBridge"] = 0x4200000000000000000000000000000000000010.toBytes32();
        values[swell]["crossDomainMessenger"] = 0x4200000000000000000000000000000000000007.toBytes32();

        // Euler
        values[swell]["ethereumVaultConnector"] = 0x08739CBede6E28E387685ba20e6409bD16969Cde.toBytes32();
        values[swell]["eulerWETH"] = 0x49C077B74292aA8F589d39034Bf9C1Ed1825a608.toBytes32();
        values[swell]["eulerWEETH"] = 0x10D0D11A8B693F4E3e33d09BBab7D4aFc3C03ef3.toBytes32();

        // Merkl
        values[swell]["merklDistributor"] = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae.toBytes32();

        // Velodrome
        values[swell]["velodromeRouter"] = 0x3a63171DD9BebF4D07BC782FECC7eb0b890C2A45.toBytes32();
        values[swell]["velodromeNonFungiblePositionManager"] = 0x991d5546C4B442B4c5fdc4c8B8b8d131DEB24702.toBytes32();

        values[swell]["velodrome_weth_weeth_v3_gauge"] = 0x14bAD0eE354c0161178bAcC59340Bb223F66b76C.toBytes32();

        // Ambient
        values[swell]["crocSwapDex"] = 0xaAAaAaaa82812F0a1f274016514ba2cA933bF24D.toBytes32();
    }

    function _addBerachainTestnetValues() private {
        values[berachainTestnet]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[berachainTestnet]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[berachainTestnet]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[berachainTestnet]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();

        values[berachainTestnet]["WETH"] = 0x4200000000000000000000000000000000000006.toBytes32();
        values[berachainTestnet]["balancerVault"] = address(1).toBytes32();
        values[berachainTestnet]["USDC"] = 0x015fd589F4f1A33ce4487E12714e1B15129c9329.toBytes32();
        values[berachainTestnet]["ZRO"] = address(1).toBytes32();

        // ERC20s
        values[berachainTestnet]["WEETH"] = 0xA6cB988942610f6731e664379D15fFcfBf282b44.toBytes32(); //also OFT

        values[berachainTestnet]["LayerZeroEndPoint"] = 0x6C7Ab2202C98C4227C5c46f1417D81144DA716Ff.toBytes32();
    }

    function _addBerachainValues() private {
        values[berachain]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[berachain]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[berachain]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[berachain]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();

        // ERC20s
        values[berachain]["ETH"] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE.toBytes32();
        values[berachain]["WBERA"] = 0x6969696969696969696969696969696969696969.toBytes32();
        values[berachain]["WETH"] = 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590.toBytes32();
        values[berachain]["WEETH"] = 0x7DCC39B4d1C53CB31e1aBc0e358b43987FEF80f7.toBytes32();
        values[berachain]["LBTC"] = 0xecAc9C5F704e954931349Da37F60E39f515c11c1.toBytes32();
        values[berachain]["WBTC"] = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c.toBytes32(); //also OFT
        values[berachain]["EBTC"] = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642.toBytes32();
        values[berachain]["eBTC"] = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642.toBytes32();
        values[berachain]["rberaETH"] = 0x3B0145f3CFA64BC66F5742F512f871665309075d.toBytes32(); //LST
        values[berachain]["beraETH"] = 0x6fc6545d5cDE268D5C7f1e476D444F39c995120d.toBytes32(); //wrapped LST
        values[berachain]["WEETH_OT"] = 0x46C7BdE4422b6798A09e76B555F2fea8D7FfADdc.toBytes32();
        values[berachain]["WEETH_YT"] = 0x98577aC3C6b376fc9Ee56377FEcAb6D751e40610.toBytes32();
        values[berachain]["BGT"] = 0x656b95E550C07a9ffe548bd4085c72418Ceb1dba.toBytes32();
        values[berachain]["iBGT"] = 0xac03CABA51e17c86c921E1f6CBFBdC91F8BB2E6b.toBytes32();
        values[berachain]["USDC"] = 0x549943e04f40284185054145c6E4e9568C1D3241.toBytes32();
        values[berachain]["srUSD"] = 0x5475611Dffb8ef4d697Ae39df9395513b6E947d7.toBytes32();
        values[berachain]["NECT"] = 0x1cE0a25D13CE4d52071aE7e02Cf1F6606F4C79d3.toBytes32();
        values[berachain]["solvBTC"] = 0x541FD749419CA806a8bc7da8ac23D346f2dF8B77.toBytes32();
        values[berachain]["HONEY"] = 0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce.toBytes32();
        values[berachain]["ZRO"] = address(1).toBytes32();
        values[berachain]["rUSD"] = 0x09D4214C03D01F49544C0448DBE3A27f768F2b34.toBytes32();
        values[berachain]["USDT"] = 0x779Ded0c9e1022225f8E0630b35a9b54bE713736.toBytes32(); // USDT0

        // Balancer
        values[berachain]["balancerVault"] = address(1).toBytes32();
        values[berachain]["vault"] = address(1).toBytes32();

        // Kodiak
        values[berachain]["kodiakRouter"] = 0xe301E48F77963D3F7DbD2a4796962Bd7f3867Fb4.toBytes32(); //swapRouter02, doesn't work with univ3 leaves for whatever reason
        values[berachain]["uniV3Router"] = 0xEd158C4b336A6FCb5B193A5570e3a571f6cbe690.toBytes32(); //for compatability w/ existing univ3 functions (swapRouter01)
        values[berachain]["kodiakNonFungiblePositionManager"] = 0xFE5E8C83FFE4d9627A75EaA7Fee864768dB989bD.toBytes32();
        values[berachain]["uniswapV3NonFungiblePositionManager"] =
            0xFE5E8C83FFE4d9627A75EaA7Fee864768dB989bD.toBytes32(); //for compatability w/ existing univ3 functions
        values[berachain]["kodiakIslandRouter"] = 0x679a7C63FC83b6A4D9C1F931891d705483d4791F.toBytes32(); //for kodiak specific islands

        values[berachain]["kodiak_island_EBTC_WBTC_005%"] = 0xfC4994e0A4780ba7536d7e79611468B6bde14CaE.toBytes32();
        values[berachain]["kodiak_island_WETH_WEETH_005%"] = 0xA0cAbFc04Fc420b3d31BA431d18eB5bD33B3f334.toBytes32();
        values[berachain]["kodiak_island_WETH_beraETH_005%"] = 0x03bCcF796cDef61064c4a2EffdD21f1AC8C29E92.toBytes32();
        values[berachain]["kodiak_island_WEETH_WEETH_OT_005%"] = 0xAd63328f4F4b8681dB713ce2eB353596628fc3B2.toBytes32();
        values[berachain]["kodiak_island_WBTC_EBTC_005%"] = 0xfC4994e0A4780ba7536d7e79611468B6bde14CaE.toBytes32();
        values[berachain]["kodiak_island_EBTC_LBTC_005%"] = 0xc3E64469e1c333360Ddb6BF0eA9B0c18E69410f0.toBytes32();
        values[berachain]["kodiak_island_EBTC_EBTC_OT_005%"] = 0x6E29Ec043103fF346450763AC364a22fc7fd4a7C.toBytes32();
        values[berachain]["kodiak_island_EBTC_WBTC_005%"] = 0xfC4994e0A4780ba7536d7e79611468B6bde14CaE.toBytes32();
        values[berachain]["kodiak_island_beraETH_WEETH_005%"] = 0x2f8C651E2F576C8c4B6DE3c32210d9b4A4461d5c.toBytes32();
        values[berachain]["kodiak_island_WBTC_solvBTC_005%"] = 0x3879451f4f69F0c2d37CaD45319cFf2E7d29C596.toBytes32();
        values[berachain]["kodiak_island_rUSD_HONEY_005%"] = 0x7fd165B73775884a38AA8f2B384A53A3Ca7400E6.toBytes32();

        // Infrared
        values[berachain]["infrared_vault_wbtc_solvbtc"] = 0x5969494e13E8FA51f8223152A86f14C02860AFD3.toBytes32();
        values[berachain]["infrared_vault_wbtc_ebtc"] = 0x5C5FCb568a98DA28C9D2DF4852b102aa814c3a4c.toBytes32();
        values[berachain]["infrared_vault_weth_weeth"] = 0x16ed36cB22b298085d10b119030408C7BbfFC24E.toBytes32();
        values[berachain]["infrared_vault_rUSD_honey"] = 0x1C5879B75be9E817B1607AFb6f24F632eE6F8820.toBytes32();
        values[berachain]["infrared_vault_primeLiquidBeraETH"] = 0xc9d8Bc7428059219f3D19Da7F17ad468254D4D7e.toBytes32();
        values[berachain]["infrared_vault_primeLiquidBeraBTC"] = 0x4bA0a69621eA72870F9fcf2D974D39B8609343cC.toBytes32();
        values[berachain]["infrared_vault_iBGT"] = 0x75F3Be06b02E235f6d0E7EF2D462b29739168301.toBytes32();

        // Dolomite
        values[berachain]["dolomiteMargin"] = 0x003Ca23Fd5F0ca87D01F6eC6CD14A8AE60c2b97D.toBytes32();
        values[berachain]["dolomiteDepositWithdrawRouter"] = 0xd6a31B6AeA4d26A19bF479b5032D9DDc481187e6.toBytes32();
        values[berachain]["dolomiteBorrowProxy"] = 0xC06271eb97d960F4034DDF953e16271CcB2B10BD.toBytes32();

        // dTokens
        values[berachain]["dWETH"] = 0xf7b5127B510E568fdC39e6Bb54e2081BFaD489AF.toBytes32();
        values[berachain]["dWEETH"] = 0x48282e3B990625CBDcb885E4a4D83B6e9D5C8442.toBytes32();
        values[berachain]["dWBTC"] = 0x29cF6e8eCeFb8d3c9dd2b727C1b7d1df1a754F6f.toBytes32();
        values[berachain]["dEBTC"] = 0x6B21026e1Fe8be7F23660B5fBFb1885dbd1147E6.toBytes32();

        // Goldilocks Vaults
        values[berachain]["goldivault_weETH"] = 0x0B8B5e0ec1dc908E0d8513cC03E91Eb479Ab6Ea9.toBytes32();
        values[berachain]["goldivault_eBTC"] = 0x0c3F856b93d6D7B46C76296f073A1357738d238C.toBytes32();

        // Tellers
        values[berachain]["eBTCTeller"] = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268.toBytes32();
        values[berachain]["primeLiquidBeraETHTeller"] = 0xB745B293468df7B06330472fBCee5412FF44750B.toBytes32();

        // Queues
        values[berachain]["eBTCQueue"] = 0x686696A3e59eE16e8A8533d84B62cfA504827135.toBytes32();

        // dTokens
        values[berachain]["dWETH"] = 0xf7b5127B510E568fdC39e6Bb54e2081BFaD489AF.toBytes32();
        values[berachain]["dWEETH"] = 0x48282e3B990625CBDcb885E4a4D83B6e9D5C8442.toBytes32();

        // etherFi
        values[berachain]["etherFiL2SyncPool"] = 0xC9475e18E2C5C26EA6ADCD55fabE07920beA887e.toBytes32();

        // Layer Zero
        values[berachain]["LayerZeroEndPoint"] = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B.toBytes32();
        values[berachain]["ZRO"] = address(1).toBytes32();

        // OFTs
        values[berachain]["LBTC_OFT"] = 0x630e12D53D4E041b8C5451aD035Ea841E08391d7.toBytes32();
        values[berachain]["solvBTC_OFT"] = 0xB12979Ff302Ac903849948037A51792cF7186E8e.toBytes32();

        // Stargate
        values[berachain]["stargateUSDC"] = 0xAF54BE5B6eEc24d6BFACf1cce4eaF680A8239398.toBytes32();
        values[berachain]["stargatesrUSD"] = 0x5475611Dffb8ef4d697Ae39df9395513b6E947d7.toBytes32();
        values[berachain]["stargateWETH"] = 0x45f1A95A4D3f3836523F5c83673c797f4d4d263B.toBytes32();

        // BGT Reward Vaults
        values[berachain]["WBERA_HONEY_reward_vault"] = 0xC2BaA8443cDA8EBE51a640905A8E6bc4e1f9872c.toBytes32();

        // Ooga Booga
        values[berachain]["OBRouter"] = 0xFd88aD4849BA0F729D6fF4bC27Ff948Ab1Ac3dE7.toBytes32();
        values[berachain]["OBExecutor"] = 0x415744995e9D35A00189C216c37546E9139F5C2c.toBytes32();

        // Royco
        values[berachain]["depositExecutor"] = 0xEC1F64Cd852c65A22bCaA778b2ed76Bc5502645C.toBytes32();
        values[berachain]["roycoDepositExecutor"] = 0xEC1F64Cd852c65A22bCaA778b2ed76Bc5502645C.toBytes32();

        // Beraborrow
        values[berachain]["collVaultUnwrapper"] = 0xcE46cefd82eb0e9572E4618dD1E6E6233b1F6Cb6.toBytes32();
        values[berachain]["collVaultRouter"] = 0x5f1619FfAEfdE17F7e54f850fe90AD5EE44dbf47.toBytes32();
        values[berachain]["bWETH"] = 0x6Ddbc255bFfD2D394F3b31c543283c01D69D4Ba2.toBytes32();
        values[berachain]["WETHDenManager"] = 0xD80AB5da2507008c8ede90648407BE098F1F1521.toBytes32();

        values[berachain]["bbWBTC"] = 0xAA2cBDe9f11f09ee9774D6d6C98dbB4792d9549a.toBytes32();
        values[berachain]["bbLBTC"] = 0x458CbA0D42896659fbb69872212Ec7Aa01b8DBEf.toBytes32();
        values[berachain]["bbeBTC"] = 0xA7dFa250Ea71ee410C3deEAF1599Cc864B958b0D.toBytes32();
        values[berachain]["bbeBTC-WBTC"] = 0x23D7DdCE723531bE8F2D26d2539d672Bd30f4CE1.toBytes32();

        values[berachain]["WBTCDenManager"] = 0x053EEbc21D5129CDB1abf7EAf09D59b19e75B8ce.toBytes32();
        values[berachain]["LBTCDenManager"] = 0x2d430a7c2Af78682A78F65580f42B32d47A14030.toBytes32();
        values[berachain]["eBTCDenManager"] = 0xA1C9fbDF853617Fa27E2c39EE830703A3Fa9D2A3.toBytes32();
        values[berachain]["eBTC-WBTCDenManager"] = 0xF9dB1b321CF012f9a1189Fdf5b9aE97864a96c8C.toBytes32();

        values[berachain]["sNECT"] = 0x597877Ccf65be938BD214C4c46907669e3E62128.toBytes32();
        values[berachain]["vaultedsNECT"] = 0x1d22592F66Fc92e0a64eE9300eAeca548cd466c5.toBytes32();

        values[berachain]["bbWBTCManagedVault"] = 0xEC5F6Cf02731B1a76CdF11E83bC8Ca9922ef9439.toBytes32();
        values[berachain]["bbLBTCManagedVault"] = 0x68c761eeb006d91D0e6eFcB8Bc490a22d8D95010.toBytes32();
        values[berachain]["bbeBTCManagedVault"] = 0x5929Fa7F900C2Ec72C45DF985508CE1ac3B54c71.toBytes32();
        values[berachain]["bbeBTC-WBTCManagedVault"] = 0x0642e5Ea445b5e572E95c381ef67eF3160572f43.toBytes32();

        // Honey
        values[berachain]["honeyFactory"] = 0xA4aFef880F5cE1f63c9fb48F661E27F8B4216401.toBytes32();
    }

    function _addBobValues() private {
        values[bob]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[bob]["deployerAddress2"] = 0xF3d0672a91Fd56C9ef04C79ec67d60c34c6148a0.toBytes32();
        values[bob]["txBundlerAddress"] = 0xF3d0672a91Fd56C9ef04C79ec67d60c34c6148a0.toBytes32();
        values[bob]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[bob]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();

        // ERC20s
        values[bob]["WETH"] = 0x4200000000000000000000000000000000000006.toBytes32();
        values[bob]["WBTC"] = 0x03C7054BCB39f7b2e5B2c7AcB37583e32D70Cfa3.toBytes32();
        values[bob]["solvBTC"] = 0x541FD749419CA806a8bc7da8ac23D346f2dF8B77.toBytes32();
        values[bob]["solvBTC.BBN"] = 0xCC0966D8418d412c599A6421b760a847eB169A8c.toBytes32();
        values[bob]["xsolvBTC"] = 0xCC0966D8418d412c599A6421b760a847eB169A8c.toBytes32();
        values[bob]["LBTC"] = 0xA45d4121b3D47719FF57a947A9d961539Ba33204.toBytes32();

        values[bob]["balancerVault"] = address(1).toBytes32();
        values[bob]["vault"] = address(1).toBytes32();

        values[bob]["ZRO"] = address(1).toBytes32();
        values[bob]["LayerZeroEndPoint"] = 0x1a44076050125825900e736c501f859c50fE728c.toBytes32();

        // OFTs

        // Standard Bridge
        values[bob]["standardBridge"] = 0x4200000000000000000000000000000000000010.toBytes32();
        values[bob]["crossDomainMessenger"] = 0x4200000000000000000000000000000000000007.toBytes32();

        // Euler
        values[bob]["ethereumVaultConnector"] = 0x59f0FeEc4fA474Ad4ffC357cC8d8595B68abE47d.toBytes32();
        values[bob]["eulerWBTC"] = 0x11DA346d3Fdb62641BDbfebfd54b81CAA871aEf6.toBytes32();

        // Uniswap V3
        values[bob]["uniswapV3NonFungiblePositionManager"] = 0x743E03cceB4af2efA3CC76838f6E8B50B63F184c.toBytes32();
        values[bob]["uniV3Router"] = 0x807F4E281B7A3B324825C64ca53c69F0b418dE40.toBytes32();
    }

    function _addDeriveValues() private {
        values[derive]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[derive]["deployerAddress2"] = 0xF3d0672a91Fd56C9ef04C79ec67d60c34c6148a0.toBytes32();
        values[derive]["txBundlerAddress"] = 0xF3d0672a91Fd56C9ef04C79ec67d60c34c6148a0.toBytes32();
        values[derive]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[derive]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();

        // ERC20s
        values[derive]["WETH"] = 0x4200000000000000000000000000000000000006.toBytes32();
        values[derive]["LBTC"] = 0x36b5C126A3D7B25F6032653A0d18823Ee48a890e.toBytes32();
        values[derive]["stDRV"] = 0x7499d654422023a407d92e1D83D387d81BC68De1.toBytes32();
        values[derive]["DRV"] = 0x2EE0fd70756EDC663AcC9676658A1497C247693A.toBytes32();

        values[derive]["balancerVault"] = address(1).toBytes32();
        values[derive]["vault"] = address(1).toBytes32();

        values[derive]["ZRO"] = address(1).toBytes32();

        // Reward Distributor
        values[derive]["rewardDistributor"] = 0x2f8C5a3BBd69443B6e462F563bA0EaB4317F995b.toBytes32();

        // Standard Bridge
        values[derive]["standardBridge"] = 0x4200000000000000000000000000000000000010.toBytes32();
        values[derive]["crossDomainMessenger"] = 0x4200000000000000000000000000000000000007.toBytes32();
        values[derive]["uniswapV3NonFungiblePositionManager"] = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88.toBytes32();

        // Derive
        values[derive]["deriveWithdrawWrapper"] = 0xea8E683D8C46ff05B871822a00461995F93df800.toBytes32();
        values[derive]["derive_LBTC_controller"] = 0x5eFC527B2640681289E31E1e29f94EA397b6c589.toBytes32();
    }

    function _addUnichainValues() private {
        values[unichain]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[unichain]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[unichain]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[unichain]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();

        // ERC20s
        values[unichain]["ETH"] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE.toBytes32();
        values[unichain]["WETH"] = 0x4200000000000000000000000000000000000006.toBytes32();
        values[unichain]["USDC"] = 0x078D782b760474a361dDA0AF3839290b0EF57AD6.toBytes32();
        values[unichain]["weETH"] = 0x7DCC39B4d1C53CB31e1aBc0e358b43987FEF80f7.toBytes32();
        values[unichain]["WEETH"] = 0x7DCC39B4d1C53CB31e1aBc0e358b43987FEF80f7.toBytes32();
        values[unichain]["WSTETH"] = 0xc02fE7317D4eb8753a02c35fe019786854A92001.toBytes32();

        values[unichain]["balancerVault"] = address(1).toBytes32();
        values[unichain]["vault"] = address(1).toBytes32();

        values[unichain]["ZRO"] = address(1).toBytes32();

        // Standard Bridge
        values[unichain]["standardBridge"] = 0x4200000000000000000000000000000000000010.toBytes32();
        values[unichain]["crossDomainMessenger"] = 0x4200000000000000000000000000000000000007.toBytes32();

        // Lido Standard Bridge
        values[unichain]["l2ERC20TokenBridge"] = 0x1A513e9B6434a12C7bB5B9AF3B21963308DEE372.toBytes32();

        // Uniswap V4
        values[unichain]["uniV4PoolManager"] = 0x1F98400000000000000000000000000000000004.toBytes32();
        values[unichain]["uniV4PositionManager"] = 0x4529A01c7A0410167c5740C487A8DE60232617bf.toBytes32();
        values[unichain]["uniV4UniversalRouter"] = 0xEf740bf23aCaE26f6492B10de645D6B98dC8Eaf3.toBytes32();
        values[unichain]["permit2"] = 0x000000000022D473030F116dDEE9F6B43aC78BA3.toBytes32();
        values[unichain]["uniV2Router"] = 0x284F11109359a7e1306C3e447ef14D38400063FF.toBytes32();
        values[unichain]["uniV2Factory"] = 0x1F98400000000000000000000000000000000002.toBytes32();

        // LayerZero
        values[unichain]["LayerZeroEndPoint"] = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B.toBytes32();

        // Stargate
        values[unichain]["stargateNative"] = 0xe9aBA835f813ca05E50A6C0ce65D0D74390F7dE7.toBytes32();

        values[unichain]["odosRouterV2"] = 0x6409722F3a1C4486A3b1FE566cBDd5e9D946A1f3.toBytes32();
        values[unichain]["odosExecutor"] = 0xAA8C506Ce5e087c81ABb44Fc286106f4403FE0Ba.toBytes32();

        values[unichain]["aggregationRouterV5"] = 0x111111125421cA6dc452d289314280a0f8842A65.toBytes32();
        values[unichain]["oneInchExecutor"] = 0x8C864D0c8E476Bf9eb9d620C10E1296fb0E2F940.toBytes32();

        values[unichain]["eulerWETH"] = 0x1f3134C3f3f8AdD904B9635acBeFC0eA0D0E1ffC.toBytes32();
        values[unichain]["eulerwstETHmarket"] = 0x54ff502df96CD9B9585094EaCd86AAfCe902d06A.toBytes32();
        values[unichain]["ethereumVaultConnector"] = 0x2A1176964F5D7caE5406B627Bf6166664FE83c60.toBytes32();

        // Morpho
        values[unichain]["morphoBlue"] = 0x8f5ae9CddB9f68de460C77730b018Ae7E04a140A.toBytes32();
        values[unichain]["morphowstETHmarket"] = 0x665c97ec413f4371e1c30c71153757e9b9144dfbe4284a3e910f85dedba6527d;
        values[unichain]["morphoSmokehouseWSTETH"] = 0x9E111aCef0CF3bd8C38715B88e78BE31C1109F8a.toBytes32();
        values[unichain]["morphoSteakhouseETH"] = 0x0993Ae24a988c6925d80aD61344a76B81aA0D34c.toBytes32();
        values[unichain]["morphoK3CapitalETHMaxi"] = 0xfA355999c12C63c465c591daf9C462e14ACf470b.toBytes32();
        values[unichain]["morphoGauntletWETH"] = 0x830898200F0E8Be8Dc1C9A836f4AB29ECEdf76eb.toBytes32();

        // Euler
    }

    function _addHyperEVMValues() internal {
        values[hyperEVM]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[hyperEVM]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();

        values[hyperEVM]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[hyperEVM]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[hyperEVM]["dev5Address"] = 0x1cdF47387358A1733968df92f7cC14546D9E1047.toBytes32();

        // ERC20s
        values[hyperEVM]["WHYPE"] = 0x5555555555555555555555555555555555555555.toBytes32();
        values[hyperEVM]["KHYPE"] = 0xfD739d4e423301CE9385c1fb8850539D657C296D.toBytes32();

        // Balanacer
        values[hyperEVM]["balancerVault"] = address(1).toBytes32();
        values[hyperEVM]["vault"] = address(1).toBytes32();

        // LayerZero
        values[hyperEVM]["LayerZeroEndPoint"] = 0x3A73033C0b1407574C76BdBAc67f126f6b4a9AA9.toBytes32();

        // kHYPE
        values[hyperEVM]["kHypeStakingManager"] = 0x393D0B87Ed38fc779FD9611144aE649BA6082109.toBytes32();

        // HyperLend
        values[hyperEVM]["hyperLendPool"] = 0x00A89d7a5A02160f20150EbEA7a2b5E4879A1A8b.toBytes32();
        values[hyperEVM]["v3RewardsController"] = 0x2aF0d6754A58723c50b5e73E45D964bFDD99fE2F.toBytes32();

        // MorphoBlue
        values[hyperEVM]["morphoBlue"] = 0x68e37dE8d93d3496ae143F2E900490f6280C57cD.toBytes32();
        values[hyperEVM]["KHYPE_WHYPE_915"] = 0x64e7db7f042812d4335947a7cdf6af1093d29478aff5f1ccd93cc67f8aadfddc;

        // MetaMorpho
        values[hyperEVM]["feHYPE"] = 0x2900ABd73631b2f60747e687095537B673c06A76.toBytes32();

        // Curve Pool
        values[hyperEVM]["KHYPE_WHYPE_Curve_Pool"] = 0x98F903B279DfF5a4f05c08C22c1D34afE8514dA0.toBytes32();
        values[hyperEVM]["KHYPE_WHYPE_Curve_Gauge"] = 0x98F903B279DfF5a4f05c08C22c1D34afE8514dA0.toBytes32();

        // Pendle
        values[hyperEVM]["pendleRouter"] = 0x888888888889758F76e7103c6CbF23ABbF58F946.toBytes32();
        values[hyperEVM]["pendleLimitOrderRouter"] = 0x000000000000c9B3E2C3Ec88B1B4c0cD853f4321.toBytes32();
        values[hyperEVM]["kHypePendle"] = 0x8867d2b7aDb8609c51810237EcC9A25A2F601B97.toBytes32();
        values[hyperEVM]["pendle_kHYPE_pt_11_13_25"] = 0x311dB0FDe558689550c68355783c95eFDfe25329.toBytes32();

        // Valantis
        values[hyperEVM]["KHYPE_WHYPE_sovereign_pool"] = 0x88B214eC94276B825E641820D5C97a9042F9Dd60.toBytes32();

        // Project X
        values[hyperEVM]["uniswapV3NonFungiblePositionManager"] = 0xeaD19AE861c29bBb2101E834922B2FEee69B9091.toBytes32();
        values[hyperEVM]["uniV3Router"] = 0x1EbDFC75FfE3ba3de61E7138a3E8706aC841Af9B.toBytes32();

        // Ooga Booga
        values[hyperEVM]["OBRouter"] = 0x5fbD1B5AA82d09359C05428647871fe9aDd3F411.toBytes32();
        values[hyperEVM]["OBExecutor"] = 0x65d1eA56196B9451AE11813E44AC5b2367f93eaD.toBytes32();

    }

    function _addTACTestnetValues() private {
        values[tacTestnet]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[tacTestnet]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[tacTestnet]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[tacTestnet]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();

        values[tacTestnet]["dev4Address"] = 0xD3d742a82524b6de30E54315E471264dc4CF2BcC.toBytes32();

        // ERC20s
        values[tacTestnet]["WTAC"] = 0x07840B012d84095397Fd251Ea619cee6F866bC39.toBytes32();
        values[tacTestnet]["USDT"] = 0x7336A5a3251b9259DDf8B9D02a96dA0153e0799d.toBytes32(); // hopefully this is a good one to test with
        values[tacTestnet]["ZRO"] = address(1).toBytes32();

        // LayerZero
        values[tacTestnet]["LayerZeroEndPoint"] = address(1).toBytes32();

        // Balancer
        values[tacTestnet]["balancerVault"] = address(1).toBytes32();
    }

    function _addFlareValues() private {
        values[flare]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[flare]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[flare]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[flare]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[flare]["dev5Address"] = 0x1cdF47387358A1733968df92f7cC14546D9E1047.toBytes32();

        // ERC20s
        values[flare]["FLR"] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE.toBytes32(); // NATIVE
        values[flare]["WFLR"] = 0x1D80c49BbBCd1C0911346656B529DF9E5c2F783d.toBytes32(); // WNATIVE
        values[flare]["USDT0"] = 0xe7cd86e13AC4309349F30B3435a9d337750fC82D.toBytes32(); // USDT0
        values[flare]["USDC"] = 0xFbDa5F676cB37624f28265A144A48B0d6e87d3b6.toBytes32(); // USDC.e Stargate
        values[flare]["ZRO"] = address(1).toBytes32(); // USDC0
        values[flare]["rFLR"] = 0x26d460c3Cf931Fb2014FA436a49e3Af08619810e.toBytes32();
        values[flare]["RFLR"] = 0x26d460c3Cf931Fb2014FA436a49e3Af08619810e.toBytes32();
        // values[flare]["WBTC"] = .toBytes32();
        // values[flare]["LBTC"] = .toBytes32();

        // UniswapV3/SparkDex
        values[flare]["uniswapV3NonFungiblePositionManager"] = 0xEE5FF5Bc5F852764b5584d92A4d592A53DC527da.toBytes32();
        values[flare]["uniV3Router"] = 0x8a1E35F5c98C4E85B36B7B253222eE17773b2781.toBytes32();

        // Balancer
        values[flare]["balancerVault"] = address(1).toBytes32();
        values[flare]["vault"] = address(1).toBytes32();

        // LayerZero
        values[flare]["LayerZeroEndPoint"] = 0x1a44076050125825900e736c501f859c50fE728c.toBytes32();
        values[flare]["USDT0_OFT"] = 0x567287d2A9829215a37e3B88843d32f9221E7588.toBytes32();
        values[flare]["USDC_OFT_stargate"] = 0x77C71633C34C3784ede189d74223122422492a0f.toBytes32();

        // Kintetic
        values[flare]["kineticUnitroller"] = 0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8.toBytes32();
        values[flare]["kUSDT0"] = 0x76809aBd690B77488Ffb5277e0a8300a7e77B779.toBytes32();
        values[flare]["isoFLR"] = 0xd7291D5001693d15b6e4d56d73B5d2cD7eCfE5c6.toBytes32(); // isolated FLR for native asset testing
        values[flare]["isoUnitroller"] = 0xDcce91d46Ecb209645A26B5885500127819BeAdd.toBytes32(); // isolated unitroller for native asset testing
    }

    function _addInkValues() private {
        values[ink]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[ink]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[ink]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[ink]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[ink]["dev3Address"] = 0xBBc5569B0b32403037F37255f4ff50B8Bb825b2A.toBytes32();
        values[ink]["dev4Address"] = 0xD3d742a82524b6de30E54315E471264dc4CF2BcC.toBytes32();
        values[ink]["dev5Address"] = 0x1cdF47387358A1733968df92f7cC14546D9E1047.toBytes32();

        // ERC20s
        values[ink]["ETH"] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE.toBytes32();
        values[ink]["WETH"] = 0x4200000000000000000000000000000000000006.toBytes32();
        values[ink]["WEETH"] = 0xA3D68b74bF0528fdD07263c60d6488749044914b.toBytes32();
        values[ink]["USDT"] = 0x0200C29006150606B650577BBE7B6248F58470c1.toBytes32(); // USDT0
        values[ink]["USDC"] = 0xF1815bd50389c46847f0Bda824eC8da914045D14.toBytes32(); // Stargate USDC.e
        values[ink]["KBTC"] = 0x73E0C0d45E048D25Fc26Fa3159b0aA04BfA4Db98.toBytes32(); // Kraken Wrapped BTC

        // Standard Bridge.
        values[ink]["standardBridge"] = 0x4200000000000000000000000000000000000010.toBytes32();
        values[ink]["crossDomainMessenger"] = 0x4200000000000000000000000000000000000007.toBytes32();

        // LayerZero
        values[ink]["LayerZeroEndPoint"] = 0xca29f3A6f966Cb2fc0dE625F8f325c0C46dbE958.toBytes32();
        values[ink]["ZRO"] = address(1).toBytes32();

        // Balancer
        values[ink]["balancerVault"] = address(1).toBytes32();
        values[ink]["vault"] = address(1).toBytes32();


        // Aave/Tydro
        values[ink]["v3Pool"] = 0x2816cf15F6d2A220E789aA011D5EE4eB6c47FEbA.toBytes32();
        values[ink]["v3RewardsController"] = 0xD93e3Ae8f69D04d484d1652Ca569d4b0522414DF.toBytes32();

        // Velodrome
        values[ink]["velodromeNonFungiblePositionManager"] = 0x991d5546C4B442B4c5fdc4c8B8b8d131DEB24702.toBytes32();
        values[ink]["velodrome_WETH_WEETH_Gauge"] = 0xa9595E55A0a34f4Bf21d3a0B93aeD29a6bf3E310.toBytes32();
    }

    function _addInkSepoliaValues() private {
        values[inkSepolia]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[inkSepolia]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[inkSepolia]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[inkSepolia]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();

        values[inkSepolia]["USDC"] = 0xFabab97dCE620294D2B0b0e46C68964e326300Ac.toBytes32(); //Sepolia USDC
        values[inkSepolia]["WETH"] = 0x4200000000000000000000000000000000000006.toBytes32(); //Sepolia WETH

        values[inkSepolia]["balancerVault"] = address(1).toBytes32();

        values[inkSepolia]["LayerZeroEndPoint"] = 0x6C7Ab2202C98C4227C5c46f1417D81144DA716Ff.toBytes32();
    }

    function _addPlumeValues() private {
        values[plume]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[plume]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();

        // ERC20s
        values[plume]["USDC"] = 0x78adD880A697070c1e765Ac44D65323a0DcCE913.toBytes32();
        values[plume]["pUSD"] = 0xdddD73F5Df1F0DC31373357beAC77545dC5A6f3F.toBytes32();
        values[plume]["nINSTO"] = 0xbfC5770631641719cd1Cf809D8325B146aED19De.toBytes32();
        values[plume]["nCREDIT"] = 0xA5f78B2A0Ab85429d2DfbF8B60abc70F4CeC066c.toBytes32();
        values[plume]["opNALPHA"] = 0xe3BEFC4eAA73803774F4d878417fa5e09193a75A.toBytes32();
        values[plume]["plumeToken"] = 0xEa237441c92CAe6FC17Caaf9a7acB3f953be4bd1.toBytes32();
        values[plume]["nBASIS"] = 0x11113Ff3a60C2450F4b22515cB760417259eE94B.toBytes32();
        values[plume]["nALPHA"] = 0x593cCcA4c4bf58b7526a4C164cEEf4003C6388db.toBytes32();

        // Tellers
        values[plume]["nALPHATeller"] = 0xc9F6a492Fb1D623690Dc065BBcEd6DfB4a324A35.toBytes32();
        values[plume]["nBASISTeller"] = 0xAD60d43a33cA26e40eAcc5BBc60f1C7136FFB89b.toBytes32();
        values[plume]["nCREDITTeller"] = 0x27200293AAC3D04d2B305244f78d013B3c759F9D.toBytes32();
        values[plume]["nINSTOTeller"] = 0xF288a085622808B5c616Ff45d740459741a6551c.toBytes32();
        values[plume]["nPayfiTeller"] = 0xe0322021C957998C8Cc85E1b0abb1f58d598f06F.toBytes32();
        values[plume]["netfTeller"] = 0xF09ffBeB3afE5c21C0A197765766e6f356590646.toBytes32();
        values[plume]["opNALPHATeller"] = 0xF957E110FF8C841DDda67259E54d3d775Df40bEa.toBytes32();
        values[plume]["opBASISTeller"] = 0x0F2769877c9Fd65900a1c0Cf53Efd7D381Ba0A4f.toBytes32();
        values[plume]["pUSDTeller"] = 0x16424eDF021697E34b800e1D98857536B0f2287B.toBytes32();

        //Royco
        values[plume]["recipeMarketHub"] = 0x027ef18525876138bEc202aA4411538CE4B2f4ca.toBytes32();
        values[plume]["vaultMarketHub"] = 0xf72388EF0018953C664DA3f37e6f98BF43c96db2.toBytes32();

        //OFTs
        values[plume]["stargateUSDC"] = 0x9909fa99b7F7ee7F1c0CBf133f411D43083631E6.toBytes32();
    }

    function _addAvalancheValues() private {
        values[avalanche]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[avalanche]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[avalanche]["vault"] = address(1).toBytes32();

        // ERC20s
        values[avalanche]["USDC"] = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E.toBytes32();
        values[avalanche]["USDC.e"] = 0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664.toBytes32();
        values[avalanche]["WETH"] = 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB.toBytes32();

        // Avalanche Bridge
        values[avalanche]["usdcTokenRouter"] = 0xD835dbD135AD8a27214ecdEE79E7a41337865648.toBytes32();
    }

    function _addKatanaValues() private {
        values[katana]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[katana]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[katana]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[katana]["dev5Address"] = 0x1cdF47387358A1733968df92f7cC14546D9E1047.toBytes32();

        // ERC20s
        values[katana]["ETH"] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE.toBytes32();
        values[katana]["WETH"] = 0xEE7D8BCFb72bC1880D0Cf19822eB0A2e6577aB62.toBytes32(); // WETH == vbETH
        values[katana]["vbETH"] = 0xEE7D8BCFb72bC1880D0Cf19822eB0A2e6577aB62.toBytes32();
        values[katana]["WEETH"] = 0x9893989433e7a383Cb313953e4c2365107dc19a7.toBytes32();
        values[katana]["WSTETH"] = 0x7Fb4D0f51544F24F385a421Db6e7D4fC71Ad8e5C.toBytes32();
        values[katana]["ZRO"] = address(1).toBytes32(); // no ZRO on Katana
        values[katana]["LBTC"] = 0xecAc9C5F704e954931349Da37F60E39f515c11c1.toBytes32();
        values[katana]["BTCK"] = 0xB0F70C0bD6FD87dbEb7C10dC692a2a6106817072.toBytes32();
        values[katana]["WBTC"] = 0x0913DA6Da4b42f538B445599b46Bb4622342Cf52.toBytes32(); //WBTC == vbWBTC
        values[katana]["vbWBTC"] = 0x0913DA6Da4b42f538B445599b46Bb4622342Cf52.toBytes32();

        // Balancer
        values[katana]["balancerVault"] = address(1).toBytes32();
        values[katana]["vault"] = address(1).toBytes32();

        // CCIP
        values[katana]["ccipRouter"] = 0x7c19b79D2a054114Ab36ad758A36e92376e267DA.toBytes32();

        // LBTC Bridge
        values[katana]["lbtcBridge"] = 0xA869817b48b25EeE986bdF4bE04062e6fd2C418B.toBytes32();

        // Agglayer
        values[katana]["agglayerBridgeKatana"] = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe.toBytes32();

        // LayerZero
        values[katana]["LayerZeroEndPoint"] = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B.toBytes32();

        // Morpho Blue
        values[katana]["morphoBlue"] = 0xD50F2DffFd62f94Ee4AEd9ca05C61d0753268aBc.toBytes32();
        values[katana]["LBTC_vbWBTC_915"] = 0x60b54e17d55b765955a20908ed5143192a48df7fd3833f7f7fe86504bf6c4c1a;
        values[katana]["WEETH_vbETH_915"] = 0x1e74d36ffbda65b8a45d72754b349cdd5ce807c5fa814f91ba8e3cd27881c34b;
        // TODO: Add correct Morpho BTCK market ID (32 bytes)
        // values[katana]["BTCK_morpho_market"] = 0x...;

        // MetaMorpho
        values[katana]["gauntletWBTC"] = 0xf243523996ADbb273F0B237B53f30017C4364bBC.toBytes32();
        values[katana]["gauntletWETH"] = 0xC5e7AB07030305fc925175b25B93b285d40dCdFf.toBytes32();
        values[katana]["gauntletBTCK"] = 0x5BD1D75d45EdB622d0ea50946F2f741CE8dC5b75.toBytes32();

        // Sushi
        values[katana]["uniswapV3NonFungiblePositionManager"] = 0x2659C6085D26144117D904C46B48B6d180393d27.toBytes32();
        values[katana]["uniV3Router"] = 0x4e1d81A3E627b9294532e990109e4c21d217376C.toBytes32();

        // Yearn
        values[katana]["yvbWETH"] = 0xE007CA01894c863d7898045ed5A3B4Abf0b18f37.toBytes32();
        values[katana]["yvWSTETH"] = 0x1769111aA8EA46fee3BA23EF9B57F3CBe1873408.toBytes32();
    }

    function _addTACValues() private {
        values[tac]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[tac]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[tac]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[tac]["dev5Address"] = 0x1cdF47387358A1733968df92f7cC14546D9E1047.toBytes32();

        // ERC20s
        values[tac]["TON"] = 0xb76d91340F5CE3577f0a056D29f6e3Eb4E88B140.toBytes32();
        values[tac]["wTAC"] = 0xB63B9f0eb4A6E6f191529D71d4D88cc8900Df2C9.toBytes32();
        values[tac]["tsTON"] = 0xD44F691aeD69fe43180B95b6F82f89c18Fb93094.toBytes32();
        values[tac]["USDT0"] = 0xAF988C3f7CB2AceAbB15f96b19388a259b6C438f.toBytes32();
        values[tac]["cbBTC"] = 0x7048c9e4aBD0cf0219E95a17A8C6908dfC4f0Ee4.toBytes32(); //also OFT
        values[tac]["LBTC"] = 0xecAc9C5F704e954931349Da37F60E39f515c11c1.toBytes32();
        values[tac]["USDT"] = 0xAF988C3f7CB2AceAbB15f96b19388a259b6C438f.toBytes32();
        values[tac]["ZRO"] = address(1).toBytes32();
        values[tac]["WETH"] = 0x61D66bC21fED820938021B06e9b2291f3FB91945.toBytes32();
        values[tac]["WSTETH"] = 0xAf368c91793CB22739386DFCbBb2F1A9e4bCBeBf.toBytes32();

        // LayerZero
        values[tac]["LayerZeroEndPoint"] = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B.toBytes32();
        values[tac]["LBTCOFTAdapter"] = 0x1298131cDa718bBcA7ACB1f2411e71c05E16f269.toBytes32();

        // Balancer
        values[tac]["balancerVault"] = address(1).toBytes32();
        values[tac]["vault"] = address(1).toBytes32();

        // Curve
        values[tac]["ton_tsTON_Curve_Pool"] = 0x51d701D23E1e6a58202694352E486b3614b75946.toBytes32();
        values[tac]["ton_tsTON_Curve_Gauge"] = 0x4CaE16a407a5BAFBdF1d1e19d02159B10De6fE7B.toBytes32();
        values[tac]["cbBTC_LBTC_Curve_Pool"] = 0x9c15DC1c8991E852CEaf623b30162A98A1c83f3D.toBytes32();
        values[tac]["cbBTC_LBTC_Curve_Gauge"] = 0x9735071D0C1FB3c59440349b20241c78aA57E3F1.toBytes32();
        values[tac]["USDT_wTAC_Curve_Pool"] = 0xAaD47973427b39bE737C1154F50DD6595083FA88.toBytes32();
        values[tac]["USDT_cbBTC_Curve_Pool"] = 0xE5948A817d7A061a0eF40128E91379046Da1009e.toBytes32();

        // Euler
        values[tac]["ethereumVaultConnector"] = 0x01F594c66A5561b90Bc782dD0297f294cD668b64.toBytes32();
        values[tac]["evkeTON-1"] = 0x27324c0d445f94550b53936dBAB7fD168634f192.toBytes32();
        values[tac]["evketsTON-1"] = 0xc7F25f1c8FDB86DE3d14152034de4EB8B71eEC78.toBytes32();
        values[tac]["evkeLBTC-1"] = 0x522e6437B80B11C10AaFDB321c3610B85127E4CD.toBytes32();
        values[tac]["evkeUSDT-2"] = 0xdD6EaEf38F94d4724124cEc14c819818714537Ff.toBytes32();
        values[tac]["evkecbBTC-3"] = 0x2eF66758705426e7BF598669AEf23eE9b9CC3088.toBytes32();
        values[tac]["evkecbBTC-2"] = 0x994a7766a0e658098cA01A1ADf114abD29e5629e.toBytes32();
        values[tac]["evkeWETH-1"] = 0x4ac2478eb1DDf574b0ffF297a25BB496af1fA207.toBytes32();
        values[tac]["evkewstETH-2"] = 0xE2E106a9Ec7bc7F5dcDf5a20Ea007b833cCf4f1f.toBytes32();

        // Morpho
        values[tac]["re7TON"] = 0x84BBc0be5a6f831a4E2C28a2F3b892C70AcAa5b3.toBytes32();
        values[tac]["re7USDT"] = 0x4183Bd253Dc1918A04Bd8a8dD546BaAD58898109.toBytes32();
        values[tac]["edgeUSDT"] = 0x9A057627f023f5C37Ebc6E7959720848968d7a43.toBytes32();
        values[tac]["re7cbBTC"] = 0xf49f14Cff1bA2eE7E23222A76e0C2b3D0BDE06dC.toBytes32();
        values[tac]["re7WETH"] = 0xC5e1bD2473811bB782326006A3c03477F7834D35.toBytes32();

        // CrossChain Layer
        values[tac]["crossChainLayer"] = 0x9fee01e948353E0897968A3ea955815aaA49f58d.toBytes32();

        // ZeroLend
        values[tac]["zeroLendPool"] = 0x93A40401EB535f786C2Ae44858e1c847d0B56fc7.toBytes32();
        values[tac]["v3RewardsController"] = 0xFCC281D05cfc46953F518F2f32AaCd7b6805Efa4.toBytes32();

        // Merkl
        values[tac]["merklDistributor"] = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae.toBytes32();
    }

    function _addPlasmaValues() private {
        values[plasma]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[plasma]["deployer2Address"] = 0xbc90dbeB9e76Ff5577Bc502EBDebd0F6616ec434.toBytes32();
        values[plasma]["txBundlerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[plasma]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[plasma]["dev5Address"] = 0x1cdF47387358A1733968df92f7cC14546D9E1047.toBytes32();
        values[plasma]["etherfiRewardClaimer"] = 0xBdA9e965CdA04eD5Bfc841E54573Dc083447E15a.toBytes32();
        values[plasma]["vault"] = 0xbA1333333333a1BA1108E8412f11850A5C319bA9.toBytes32();
        
        // Factory Contracts
        values[plasma]["create2Factory"] = 0x4e59b44847b379578588920cA78FbF26c0B4956C.toBytes32();
        values[plasma]["erc1820Registry"] = 0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24.toBytes32();
        values[plasma]["eip2470SingletonFactory"] = 0xce0042B868300000d44A59004Da54A005ffdcf9f.toBytes32();
        values[plasma]["keylessCreate2Factory"] = 0x0000000000FFe8B47B3e2130213B802212439497.toBytes32();
        
        // Multicall Contracts
        values[plasma]["multicall"] = 0xeefBa1e63905eF1D7ACbA5a8513c70307C1cE441.toBytes32();
        values[plasma]["multicall2"] = 0x5BA1e12693Dc8F9c48aAD8770482f4739bEeD696.toBytes32();
        values[plasma]["multicall3"] = 0xcA11bde05977b3631167028862bE2a173976CA11.toBytes32();
        
        // Safe (Gnosis) Contracts
        values[plasma]["safeSingletonFactory"] = 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7.toBytes32();
        values[plasma]["safeL1"] = 0x41675C099F32341bf84BFc5382aF534df5C7461a.toBytes32();
        values[plasma]["safeL2"] = 0x29fcB43b46531BcA003ddC8FCB67FFE91900C762.toBytes32();
        values[plasma]["safeProxyFactory"] = 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67.toBytes32();
        values[plasma]["compatibilityFallbackHandler"] = 0xfd0732Dc9E303f09fCEf3a7388Ad10A83459Ec99.toBytes32();
        values[plasma]["createCall"] = 0x9b35Af71d77eaf8d7e40252370304687390A1A52.toBytes32();
        values[plasma]["multiSend"] = 0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526.toBytes32();
        values[plasma]["multiSendCallOnly"] = 0x9641d764fc13c8B624c04430C7356C1C7C8102e2.toBytes32();
        values[plasma]["signMessageLib"] = 0xd53cd0aB83D845Ac265BE939c57F53AD838012c9.toBytes32();
        values[plasma]["simulateTxAccessor"] = 0x3d4BA2E0884aa488718476ca2FB8Efc291A46199.toBytes32();
        values[plasma]["tokenCallbackHandler"] = 0xeDCF620325E82e3B9836eaaeFdc4283E99Dd7562.toBytes32();
        
        // Permit2
        values[plasma]["permit2"] = 0x000000000022D473030F116dDEE9F6B43aC78BA3.toBytes32();
        
        // Token
        values[plasma]["ETH"] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE.toBytes32(); // Plasma doesn't have native ETH, using common ETH placeholder to bypass fluidDex helper check
        values[mainnet]["NATIVE"] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE.toBytes32();
        values[plasma]["wXPL"] = 0x6100E367285b01F48D07953803A2d8dCA5D19873.toBytes32();
        values[plasma]["WXPL"] = 0x6100E367285b01F48D07953803A2d8dCA5D19873.toBytes32();
        values[plasma]["USDT0"] = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb.toBytes32();
        values[plasma]["USDT0_OFT"] = 0x02ca37966753bDdDf11216B73B16C1dE756A7CF9.toBytes32();
        values[plasma]["ZRO"] = address(1).toBytes32();
        values[plasma]["WETH"] = 0x9895D81bB462A195b4922ED7De0e3ACD007c32CB.toBytes32();
        values[plasma]["WEETH"] = 0xA3D68b74bF0528fdD07263c60d6488749044914b.toBytes32();
        values[plasma]["WETH_OFT_STARGATE"] = 0x0cEb237E109eE22374a567c6b09F373C73FA4cBb.toBytes32();
        values[plasma]["USDE"] = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34.toBytes32();
        values[plasma]["SUSDE"] = 0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2.toBytes32();
        values[plasma]["USDe"] = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34.toBytes32(); 
        values[plasma]["sUSDe"] = 0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2.toBytes32(); 
        values[plasma]["ENA"] = 0x58538e6A46E07434d7E7375Bc268D3cb839C0133.toBytes32(); 
        
        // Uniswap V3
        values[plasma]["uniswapV3NonFungiblePositionManager"] = 0x743E03cceB4af2efA3CC76838f6E8B50B63F184c.toBytes32();
        values[plasma]["uniV3Router"] = 0x807F4E281B7A3B324825C64ca53c69F0b418dE40.toBytes32();
        values[plasma]["universalRouter"] = 0x1b35fbA9357fD9bda7ed0429C8BbAbe1e8CC88fc.toBytes32();
        
        // Hyperlane (keeping only essential contracts based on mainnet pattern)
        values[plasma]["hyperlaneMailbox"] = 0x3a464f746D23Ab22155710f44dB16dcA53e0775E.toBytes32();
        values[plasma]["hyperlaneInterchainGasPaymaster"] = 0x1A41a365A693b6A7aED1a46316097d290f569F22.toBytes32();
        values[plasma]["hyperlaneInterchainAccountRouter"] = 0x9fE454AA2B01fc7A2a777AE561bc58Ce560CD5a9.toBytes32();
        
        // LI.FI
        values[plasma]["lifi"] = 0x026F252016A7C47CDEf1F05a3Fc9E20C92a49C37.toBytes32();
        
        // Glacis
        values[plasma]["glacisAirlift"] = 0x290D54179960984599F16F77DCDA81320301b158.toBytes32();
        
        // LayerZero
        values[plasma]["LayerZeroEndPoint"] = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B.toBytes32();

        // Aave V3
        values[plasma]["v3Pool"] = 0x925a2A7214Ed92428B5b1B090F80b25700095e12.toBytes32();
        values[plasma]["v3RewardsController"] = 0x3A57eAa3Ca3794D66977326af7991eB3F6dD5a5A.toBytes32();


        // Fluid Dex
        values[plasma]["weETH_ETHDex_wETH"] = 0x0C8C77B7FF4c2aF7F6CEBbe67350A490E3DD6cB3.toBytes32();

        // Merkl
        values[plasma]["merklDistributor"] = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae.toBytes32();
        
        // Curve
        values[plasma]["USDe_USDT0_Curve_Pool"] = 0x2D84D79C852f6842AbE0304b70bBaA1506AdD457.toBytes32();
        values[plasma]["sUSDe_USDT0_Curve_Pool"] = 0x1E8D78e9b3f0152D54d32904B7933f1cFE439Df1.toBytes32();

        // Balancer V3
        values[plasma]["balancerV3Router"] = 0x9dA18982a33FD0c7051B19F0d7C76F2d5E7e017c.toBytes32();
        values[plasma]["balancerV3Vault"] = 0xbA1333333333a1BA1108E8412f11850A5C319bA9.toBytes32();
        values[plasma]["balancerV3VaultExplorer"] = 0x043A2daD730d585C44FB79D2614F295D2d625412.toBytes32();

        // Balancer V3 Pools & Gauges
        values[plasma]["balancerV3waPlaUSDe-waPlaUSDT0"] = 0x6a74BE33B5393D8A3EbA4D69B78f9D9da947C48c.toBytes32();
        values[plasma]["balancerV3sUSDe-waPlaUSDT0"] = 0xd9c4e277c93374a9f8C877a9D06707a88092E8F0.toBytes32();
        values[plasma]["balancerV3WXPL-USDT0"] = 0xe14Ba497A7C51f34896D327ec075F3F18210a270.toBytes32();

        // Pendle
        values[plasma]["pendleMarketFactory"] = 0x28dE02Ac3c3F5ef427e55c321F73fDc7F192e8E4.toBytes32();
        values[plasma]["pendleRouter"] = 0x888888888889758F76e7103c6CbF23ABbF58F946.toBytes32();
        values[plasma]["pendleLimitOrderRouter"] = 0x000000000000c9B3E2C3Ec88B1B4c0cD853f4321.toBytes32();
        values[plasma]["pendle_market_USDe_01_15_26"] = 0xFD3eB62302fa3cBc3c7e59e887b92dBBc814285D.toBytes32();
        values[plasma]["pendle_pt_USDe_01_15_26"] = 0x93B544c330F60A2aa05ceD87aEEffB8D38FD8c9a.toBytes32();
        values[plasma]["pendle_market_sUSDe_01_15_26"] = 0xe06C3B972BA630cCF3392cEcdbe070690b4e6b55.toBytes32();
        values[plasma]["pendle_pt_sUSDe_01_15_26"] = 0x02FCC4989B4C9D435b7ceD3fE1Ba4CF77BBb5Dd8.toBytes32();

        // GlueX
        values[plasma]["glueXRouter"] = 0xe95F6EAeaE1E4d650576Af600b33D9F7e5f9f7fd.toBytes32();
        values[plasma]["glueXExecutor"] = 0x2102Ab11A3c74B1D543891020969dc3D46C132AB.toBytes32();

        // Sushi/Swnapper/RedSnwapper
        values[plasma]["redSnwapperRouter"] = 0xAC4c6e212A361c968F1725b4d055b47E63F80b75.toBytes32();
        values[plasma]["redSnwapperExecutor"] = 0xd2b37aDE14708bf18904047b1E31F8166d39612b.toBytes32();

    }

    
}
