// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {ChainValues} from "test/resources/ChainValues.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {AerodromeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/AerodromeDecoderAndSanitizer.sol";
import {SyUsdDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyUsdDecoderAndSanitizer.sol";
import {
    EthereumUsdStrategyDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EthereumUsdStrategyDecoderAndSanitizer.sol";
import {FullUniswapV4DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/FullUniswapV4DecoderAndSanitizer.sol";
import {GenericUniswapDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/GenericUniswapDecoderAndSanitizer.sol";
import {SyUsdArbitrumDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyUsdArbitrumDecoderAndSanitizer.sol";
import {SyUsdPlasmaDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyUsdPlasmaDecoderAndSanitizer.sol";
import {SyEthArbitrumDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyEthArbitrumDecoderAndSanitizer.sol";
import {SyBtcArbitrumDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyBtcArbitrumDecoderAndSanitizer.sol";
import {SyHlpBaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyHlpArbitrumDecoderAndSanitizer.sol";
import {
    TestVaultArbitrumDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/TestVaultArbitrumDecoderAndSanitizer.sol";
import {SyUsdBaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyUsdBaseDecoderAndSanitizer01.sol";
import {SyUsdKatanaDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyUsdKatanaDecoderAndSanitizer.sol";

import {Deployer} from "src/helper/Deployer.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {
    BaseStablecoinStrategyDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/BaseStablecoinStrategyDecoderAndSanitizer.sol";
import {
    MonadStablecoinStrategyDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/MonStablecoinStrategyDecoderAndSanitizer.sol";
import {HlCoreVaultDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/HlCoreVaultDecoderAndSanitizer.sol";

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

contract DeployKatanaDecoderAndSanitizer is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    uint256 public privateKey;
    Deployer public deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function setUp() external {}

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;

        vm.createSelectFork("katana");
        setSourceChainName("katana");

        vm.startBroadcast(vm.envUint("BORING_DEVELOPER"));

        creationCode = type(SyUsdKatanaDecoderAndSanitizer).creationCode;
        deployer.deployContract("SyUsdKatanaDecodersAndSanitizerV0.1", creationCode, constructorArgs, 0);

        // new HlCoreVaultDecoderAndSanitizer();

        vm.stopBroadcast();
    }
}

contract DeployHlCoreVaultDecoderAndSanitizer is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    uint256 public privateKey;
    Deployer public deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function setUp() external {}

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;

        vm.createSelectFork("hyperevm");
        setSourceChainName("hyperevm");

        vm.startBroadcast(vm.envUint("BORING_DEVELOPER"));

        creationCode = type(HlCoreVaultDecoderAndSanitizer).creationCode;
        // deployer.deployContract("HlCoreVaultDecodersAndSanitizerV0.1", creationCode, constructorArgs, 0);

        new HlCoreVaultDecoderAndSanitizer();

        vm.stopBroadcast();
    }
}

contract DeployEthUsdDecoderAndSanitizer is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    uint256 public privateKey;
    Deployer public deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function setUp() external {}

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;

        vm.createSelectFork("mainnet");
        setSourceChainName("mainnet");

        vm.startBroadcast(vm.envUint("BORING_DEVELOPER"));

        creationCode = type(EthereumUsdStrategyDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode(
            getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
            getAddress(sourceChain, "odosRouterV2"),
            getAddress(sourceChain, "magpieRouterV3")
        );
        deployer.deployContract("EthUsdStrategyDecodersAndSanitizerV1", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
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

    function setUp() external {}

    function run() external {
        vm.createSelectFork("arbitrum");
        setSourceChainName("arbitrum");

        vm.startBroadcast(vm.envUint("BORING_DEVELOPER"));

        deployer.deployContract(
            "SyBtc Arbitrum DecodersAndSanitizers Batch 2",
            type(SyBtcArbitrumDecoderAndSanitizer).creationCode,
            abi.encode(
                getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
                getAddress(sourceChain, "magpieRouterV3")
            ),
            0
        );

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

contract DeployGenericUniswapDecoderAndSanitizer is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    function run() external {
        vm.createSelectFork("monad");
        setSourceChainName(monad);
        vm.startBroadcast(vm.envUint("BORING_DEVELOPER"));
        new GenericUniswapDecoderAndSanitizer(
            getAddress(sourceChain, "uniV4PositionManager"),
            getAddress(sourceChain, "uniswapV3NonFungiblePositionManager")
        );
        vm.stopBroadcast();
    }
}

contract DeployBaseStableStrategyDecoderAndSanitizer is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    function run() external {
        vm.createSelectFork("base");
        setSourceChainName(base);
        vm.startBroadcast(vm.envUint("PRIVATE_KEY_1"));
        new BaseStablecoinStrategyDecoderAndSanitizer(
            getAddress(sourceChain, "aerodromeNonFungiblePositionManager"), getAddress(sourceChain, "magpieRouterV3")
        );
        vm.stopBroadcast();
    }
}

contract DeployMonadStableStrategyDecoderAndSanitizer is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    function run() external {
        vm.createSelectFork("monad");
        setSourceChainName(monad);
        vm.startBroadcast(vm.envUint("BORING_DEVELOPER"));
        new MonadStablecoinStrategyDecoderAndSanitizer(
            getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"), getAddress(sourceChain, "magpieRouterV3")
        );
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

