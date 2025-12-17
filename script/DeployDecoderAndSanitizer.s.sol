// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {ChainValues} from "test/resources/ChainValues.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {
    ITBPositionDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/ITB/ITBPositionDecoderAndSanitizer.sol";
import {
    EtherFiLiquidUsdDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EtherFiLiquidUsdDecoderAndSanitizer.sol";
import {
    PancakeSwapV3FullDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/PancakeSwapV3FullDecoderAndSanitizer.sol";
import {AerodromeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/AerodromeDecoderAndSanitizer.sol";
import {SyUsdDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyUsdDecoderAndSanitizer.sol";
import {FullUniswapV4DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/FullUniswapV4DecoderAndSanitizer.sol";
import {SyUsdArbitrumDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyUsdArbitrumDecoderAndSanitizer.sol";
import {SyUsdPlasmaDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyUsdPlasmaDecoderAndSanitizer.sol";
import {SyEthArbitrumDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyEthArbitrumDecoderAndSanitizer.sol";
import {SyBtcArbitrumDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyBtcArbitrumDecoderAndSanitizer.sol";
import {SyHlpBaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyHlpArbitrumDecoderAndSanitizer.sol";
import {
    TestVaultArbitrumDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/TestVaultArbitrumDecoderAndSanitizer.sol";
import {SyUsdBaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyUsdBaseDecoderAndSanitizer01.sol";
import {OnlyKarakDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/OnlyKarakDecoderAndSanitizer.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {PointFarmingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/PointFarmingDecoderAndSanitizer.sol";
import {OnlyHyperlaneDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/OnlyHyperlaneDecoderAndSanitizer.sol";
import {
    SwellEtherFiLiquidEthDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/SwellEtherFiLiquidEthDecoderAndSanitizer.sol";
import {sBTCNMaizenetDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/sBTCNMaizenetDecoderAndSanitizer.sol";
import {UniBTCDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/UniBTCDecoderAndSanitizer.sol";
import {EdgeCapitalDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EdgeCapitalDecoderAndSanitizer.sol";
import {
    EtherFiLiquidBtcDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EtherFiLiquidBtcDecoderAndSanitizer.sol";
import {
    SonicEthMainnetDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/SonicEthMainnetDecoderAndSanitizer.sol";
import {AaveV3FullDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/AaveV3FullDecoderAndSanitizer.sol";
import {LombardBtcDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LombardBtcDecoderAndSanitizer.sol";
import {StakedSonicUSDDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/StakedSonicUSDDecoderAndSanitizer.sol";
import {TestVaultDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/TestVaultDecoderAndSanitizer.sol";
import {LiquidBeraEthDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LiquidBeraEthDecoderAndSanitizer.sol";
import {
    SonicIncentivesHandlerDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/SonicIncentivesHandlerDecoderAndSanitizer.sol";
import {AaveV3FullDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/AaveV3FullDecoderAndSanitizer.sol";
import {EtherFiBtcDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EtherFiBtcDecoderAndSanitizer.sol";
import {SymbioticLRTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SymbioticLRTDecoderAndSanitizer.sol";
import {
    SonicLBTCvSonicDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/SonicLBTCvSonicDecoderAndSanitizer.sol";
import {eBTCBerachainDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/eBTCBerachainDecoderAndSanitizer.sol";
import {SonicBTCDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SonicBTCDecoderAndSanitizer.sol";
import {BerachainDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BerachainDecoderAndSanitizer.sol";
import {
    PrimeLiquidBeraBtcDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/PrimeLiquidBeraBtcDecoderAndSanitizer.sol";
import {StakedSonicDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/StakedSonicDecoderAndSanitizer.sol";
import {HybridBtcBobDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/HybridBtcBobDecoderAndSanitizer.sol";
import {HybridBtcDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/HybridBtcDecoderAndSanitizer.sol";
import {SonicVaultDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SonicVaultDecoderAndSanitizer.sol";
import {LBTCvBNBDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LBTCvBNBDecoderAndSanitizer.sol";
import {LBTCvBaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LBTCvBaseDecoderAndSanitizer.sol";
import {
    SonicLBTCvSonicDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/SonicLBTCvSonicDecoderAndSanitizer.sol";
import {RoyUSDCMainnetDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RoyUSDCMainnetDecoderAndSanitizer.sol";
import {RoyUSDCSonicDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RoyUSDCSonicDecoderAndSanitizer.sol";
import {RoySonicUSDCDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RoySonicUSDCDecoderAndSanitizer.sol";
import {TacETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/TacETHDecoderAndSanitizer.sol";
import {TacUSDDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/TacUSDDecoderAndSanitizer.sol";
import {TacLBTCvDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/TacLBTCvDecoderAndSanitizer.sol";
import {sBTCNDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/sBTCNDecoderAndSanitizer.sol";
import {CamelotFullDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/CamelotFullDecoderAndSanitizer.sol";
import {EtherFiEigenDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EtherFiEigenDecoderAndSanitizer.sol";
import {
    UnichainEtherFiLiquidEthDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/UnichainEtherFiLiquidEthDecoderAndSanitizer.sol";
import {LiquidBeraDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LiquidBeraDecoderAndSanitizer.sol";
import {
    LiquidBeraEthBerachainDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/LiquidBeraEthBerachainDecoderAndSanitizer.sol";
import {
    FullCorkDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/ITB/cork/FullCorkDecoderAndSanitizer.sol";

import {BoringDrone} from "src/base/Drones/BoringDrone.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployDecoderAndSanitizer.s.sol:DeployDecoderAndSanitizerScript --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify --with-gas-price 30000000000
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployDecoderAndSanitizerScript is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    uint256 public privateKey;
    Deployer public deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;

        // vm.createSelectFork("mainnet");
        // setSourceChainName("mainnet");
        // vm.startBroadcast(privateKey);
        // creationCode = type(SyUsdDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(
        //     getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"), getAddress(sourceChain, "odosRouterV2")
        // );
        // deployer.deployContract("SyUsd Ethereum DecodersAndSanitizers Batch 5", creationCode, constructorArgs, 0);
        // vm.stopBroadcast();

        vm.createSelectFork("base");
        setSourceChainName("base");
        vm.startBroadcast(privateKey);
        creationCode = type(SyUsdBaseDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode(
            getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"), getAddress(sourceChain, "odosRouterV2")
        );
        deployer.deployContract("SyUsd Base DecodersAndSanitizers Batch 2", creationCode, constructorArgs, 0);
        vm.stopBroadcast();

        // vm.createSelectFork("arbitrum");
        // setSourceChainName("arbitrum");
        // vm.startBroadcast(privateKey);
        // creationCode = type(SyUsdBaseDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"));
        // deployer.deployContract("SyUsd Base DecodersAndSanitizers Batch 1", creationCode, constructorArgs, 0);
        // vm.stopBroadcast();
    }
}

contract DeploySyHlpDecoderAndSanitizer is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    uint256 public privateKey;
    Deployer public deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;

        vm.createSelectFork("arbitrum");
        setSourceChainName("arbitrum");
        vm.startBroadcast(privateKey);
        creationCode = type(SyHlpBaseDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode(getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"));
        deployer.deployContract("SyUsd Base DecodersAndSanitizers Batch 1", creationCode, constructorArgs, 0);
        vm.stopBroadcast();
    }
}

contract DeployTestVaultArbitrumDecoderAndSanitizer is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    uint256 public privateKey;
    Deployer public deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;

        vm.createSelectFork("arbitrum");
        setSourceChainName("arbitrum");
        vm.startBroadcast(privateKey);
        new TestVaultArbitrumDecoderAndSanitizer(
            getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
            getAddress(sourceChain, "odosRouterV2"),
            getAddress(sourceChain, "MagpieRouterV3")
        );
        vm.stopBroadcast();
    }
}

contract DeploySyEthArbitrumDecoderAndSanitizer is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    uint256 public privateKey;
    Deployer public deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;

        vm.createSelectFork("arbitrum");
        setSourceChainName("arbitrum");
        vm.startBroadcast(privateKey);
        creationCode = type(SyEthArbitrumDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode(
            getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"), getAddress(sourceChain, "odosRouterV2")
        );
        deployer.deployContract("SyEth Arbitrum DecodersAndSanitizers Batch 1", creationCode, constructorArgs, 0);
        vm.stopBroadcast();
    }
}

contract DeploySyBtcArbitrumDecoderAndSanitizer is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    uint256 public privateKey;
    Deployer public deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;

        vm.createSelectFork("arbitrum");
        setSourceChainName("arbitrum");
        vm.startBroadcast(privateKey);
        creationCode = type(SyBtcArbitrumDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode(
            getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"), getAddress(sourceChain, "odosRouterV2")
        );
        deployer.deployContract("SyBtc Arbitrum DecodersAndSanitizers Batch 1", creationCode, constructorArgs, 0);
        vm.stopBroadcast();
    }
}

contract DeploySyUsdArbitrumDecoderAndSanitizer is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    uint256 public privateKey;
    Deployer public deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;

        vm.createSelectFork("arbitrum");
        setSourceChainName("arbitrum");
        vm.startBroadcast(privateKey);
        creationCode = type(SyUsdArbitrumDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode(
            getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"), getAddress(sourceChain, "odosRouterV2")
        );
        deployer.deployContract("SyUsd Arbitrum DecodersAndSanitizers Batch 2", creationCode, constructorArgs, 0);
        vm.stopBroadcast();
    }
}

contract DeploySyUsdPlasmaDecoderAndSanitizer is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    uint256 public privateKey;
    Deployer public deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;

        vm.createSelectFork("plasma");
        setSourceChainName(plasma);
        vm.startBroadcast(privateKey);
        creationCode = type(SyUsdPlasmaDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode(getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"));
        deployer.deployContract("SyUsd Plasma DecodersAndSanitizers Batch 1", creationCode, constructorArgs, 0);
        vm.stopBroadcast();
    }
}

contract DeployUniswapV4DecoderAndSanitizer is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    function run() external {
        vm.createSelectFork("monad");
        setSourceChainName(monad);
        vm.startBroadcast(vm.envUint("BORING_DEVELOPER"));
        new FullUniswapV4DecoderAndSanitizer(getAddress(sourceChain, "uniV4PositionManager"));
        vm.stopBroadcast();
    }
}

// contract DeployLpUsdcArbitrumDecoderAndSanitizer {
//     uint256 public privateKey;
//     Deployer public deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);
//
//     function setUp() external {
//         privateKey = vm.envUint("BORING_DEVELOPER");
//     }

//     function run() external {
//         bytes memory creationCode;
//         bytes memory constructorArgs;

//         vm.createSelectFork("arbitrum");
//         setSourceChainName("arbitrum");
//         vm.startBroadcast(privateKey);
//         creationCode = type(SyUsdBaseDecoderAndSanitizer).creationCode;
//         constructorArgs = abi.encode(getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"));
//         deployer.deployContract("SyUsd Base DecodersAndSanitizers Batch 1", creationCode, constructorArgs, 0);
//         vm.stopBroadcast();
//     }
// }
