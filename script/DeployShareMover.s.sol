// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

/**
 * @title ShareMoverScript
 * @notice Unified script that deploys and configures `LayerZeroShareMover` using
 *         data pulled from a per-chain JSON configuration.
 *
 * Environment variables expected:
 *   SHARE_MOVER_DEPLOYER_KEY   Private key used for broadcast
 *   SHARE_MOVER_CONFIG_FILE    Path to the JSON config (e.g. deployments/configurations/scroll-min.json)
 *   DEPLOYER_CONTRACT          Address of `Deployer` helper already on chain
 *   BORING_VAULT               Address of an existing Boring Vault
 *   ROLES_AUTHORITY            Address of the RolesAuthority governing the vault
 *
 * Example (Scroll):
 *   source .env && \
 *   forge script script/share-mover/ShareMover.s.sol:ShareMoverScript \
 *        --sig "deploy()" \
 *        --broadcast --with-gas-price 3000000000 \
 *        --rpc-url $SCROLL_RPC_URL
 */

import {LayerZeroShareMover} from "src/base/Roles/CrossChain/ShareMover/LayerZeroShareMover.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

// Mirror of Endpoint structs used by LayerZero ULN V2
struct SetConfigParam {
    uint32 eid;
    uint32 configType;
    bytes  config;
}

// Interface must come after struct definition
interface IEndpointCfg {
    function setConfig(address oApp, address lib, SetConfigParam[] calldata params) external;
    function getReceiveLibrary(address receiver, uint32 eid) external view returns (address lib, bool isDefault);
}

contract ShareMoverScript is Script {
    using stdJson for string;

    // ────────────────────────────────────────────────────────────────────────────
    //  Constants / role ids
    // ────────────────────────────────────────────────────────────────────────────
    uint8 internal constant MINTER_ROLE = 2;
    uint8 internal constant BURNER_ROLE = 3;

    // ────────────────────────────────────────────────────────────────────────────
    //  Internal state
    // ────────────────────────────────────────────────────────────────────────────
    // These are populated by _loadConfig per call
    uint256 private deployerKey;
    address private deployerContract;
    address private boringVault;
    address private rolesAuthorityAddr;

    // Parsed from JSON (populated by _loadConfig)
    address private lzEndpoint;
    address private lzToken;
    address private owner;

    string private cfgJson;

    function setUp() external {
        // No-op: everything comes from JSON now
    }

    /* Internal: load config and populate globals */
    function _loadConfig(string memory cfgPath) internal {
        cfgJson = vm.readFile(cfgPath);

        // Resolve deployer contract from JSON directly
        deployerContract = cfgJson.readAddress(".deploymentParameters.deployerContractAddressOrName.address");
        Deployer deployer = Deployer(deployerContract);

        // Read key name and pull private key
        string memory pkName = cfgJson.readString(".deploymentParameters.privateKeyEnvName");
        deployerKey = vm.envUint(pkName);

        // Resolve vault & rolesAuthority via deterministic names
        string memory vaultName = cfgJson.readString(".boringVaultConfiguration.boringVaultDeploymentName");
        boringVault = deployer.getAddress(vaultName);

        string memory rolesName = cfgJson.readString(".rolesAuthorityConfiguration.rolesAuthorityDeploymentName");
        rolesAuthorityAddr = deployer.getAddress(rolesName);

        // ShareMover global params
        lzEndpoint = cfgJson.readAddress(".shareMoverConfiguration.lzEndpointAddressOrName.address");
        lzToken    = cfgJson.readAddress(".shareMoverConfiguration.lzTokenAddressOrName.address");
        owner      = cfgJson.readAddress(".shareMoverConfiguration.ownerAddressOrName.address");
    }

    /*──────────────────────────────────────────────────────────────────────────*
     *  ACTION: DEPLOY
     *──────────────────────────────────────────────────────────────────────────*/

    function deploy(string memory cfgPath) external {
        _loadConfig(cfgPath);

        vm.startBroadcast(deployerKey);

        Deployer       deployer   = Deployer(deployerContract);
        RolesAuthority rolesAuth  = RolesAuthority(rolesAuthorityAddr);

        bytes memory creationCode   = type(LayerZeroShareMover).creationCode;
        bytes memory constructorArgs = abi.encode(
            owner,                // _owner
            rolesAuthorityAddr,   // _authority
            boringVault,          // _vault
            lzEndpoint,           // _lzEndpoint
            owner,                // _delegate (owner for now)
            lzToken               // _lzToken (0x0 = pay native)
        );

        address shareMoverAddress = deployer.deployContract(
            "ShareMover",        // Deterministic salt / name
            creationCode,
            constructorArgs,
            0                     // value
        );

        // Grant mint / burn roles so ShareMover can sync vault shares cross-chain
        Deployer.Tx[] memory txs = new Deployer.Tx[](2);
        txs[0] = Deployer.Tx({
            target: rolesAuthorityAddr,
            data: abi.encodeWithSelector(rolesAuth.setUserRole.selector, shareMoverAddress, MINTER_ROLE, true),
            value: 0
        });
        txs[1] = Deployer.Tx({
            target: rolesAuthorityAddr,
            data: abi.encodeWithSelector(rolesAuth.setUserRole.selector, shareMoverAddress, BURNER_ROLE, true),
            value: 0
        });
        deployer.bundleTxs(txs);

        vm.stopBroadcast();

        console2.log("ShareMover deployed at", shareMoverAddress);
    }

    /*──────────────────────────────────────────────────────────────────────────*
     *  ACTION: ADD CHAIN (placeholder – to be completed)
     *──────────────────────────────────────────────────────────────────────────*/

    function addChain(string memory cfgPath, uint256 index) external {
        _loadConfig(cfgPath);
        // Pull ShareMover address from deterministic deployment
        Deployer deployer = Deployer(deployerContract);
        address moverAddr = deployer.getAddress("ShareMover");
        require(moverAddr != address(0), "ShareMover not deployed");
        LayerZeroShareMover mover = LayerZeroShareMover(moverAddr);

        // Build JSON path prefix for the desired chain entry
        string memory idx = vm.toString(index);
        string memory prefix = string.concat(".shareMoverConfiguration.chains[", idx, "]");

        uint32  eid       = uint32(cfgJson.readUint(string.concat(prefix, ".eid")));
        bytes32 peer      = cfgJson.readBytes32(string.concat(prefix, ".peer"));
        uint128 gasLimit  = uint128(cfgJson.readUint(string.concat(prefix, ".gasLimit")));
        uint8   decimals  = uint8(cfgJson.readUint(string.concat(prefix, ".decimals")));
        bool allowFrom    = cfgJson.readBool(string.concat(prefix, ".allowMessagesFrom"));
        bool allowTo      = cfgJson.readBool(string.concat(prefix, ".allowMessagesTo"));

        // Map text -> enum
        string memory typeStr = cfgJson.readString(string.concat(prefix, ".type"));
        LayerZeroShareMover.ChainType cType;
        if (keccak256(bytes(typeStr)) == keccak256("SOLANA")) {
            cType = LayerZeroShareMover.ChainType.SOLANA;
        } else {
            cType = LayerZeroShareMover.ChainType.EVM; // default fallback
        }

        vm.startBroadcast(deployerKey);
        mover.addChain(eid, allowFrom, allowTo, peer, gasLimit, decimals, cType);

        // Ensure flags are flipped (idempotent)
        if (allowFrom) mover.allowMessagesFromChain(eid, peer);
        if (allowTo)   mover.allowMessagesToChain(eid, peer, gasLimit);
        vm.stopBroadcast();

        console2.log("Chain added:", eid);
    }

    /*──────────────────────────────────────────────────────────────────────────*
     *  ULN CONFIG
     *──────────────────────────────────────────────────────────────────────────*/

    struct ExecutorConfig {
        uint32 maxMessageSize;
        address executor;
    }
    struct UlnConfig {
        uint64 confirmations;
        uint8  requiredDVNCount;
        uint8  optionalDVNCount;
        uint8  optionalDVNThreshold;
        address[] requiredDVNs;
        address[] optionalDVNs;
    }

    uint32 constant CONFIG_TYPE_EXECUTOR = 1;
    uint32 constant CONFIG_TYPE_ULN      = 2;

    function setUlnConfig(string memory cfgPath, uint256 index) external {
        _loadConfig(cfgPath);
        // Pull ShareMover address & endpoint
        Deployer deployer = Deployer(deployerContract);
        address moverAddr = deployer.getAddress("ShareMover");
        require(moverAddr != address(0), "ShareMover not deployed");

        string memory idx = vm.toString(index);
        string memory prefix = string.concat(".shareMoverConfiguration.chains[", idx, "]");

        uint32 eid = uint32(cfgJson.readUint(string.concat(prefix, ".eid")));
        address executor = cfgJson.readAddress(string.concat(prefix, ".executor"));
        address dvn0     = cfgJson.readAddress(string.concat(prefix, ".dvn0"));
        require(executor != address(0) && dvn0 != address(0), "executor/dvn missing");

        IEndpointCfg ep = IEndpointCfg(lzEndpoint);

        // Build params
        ExecutorConfig memory execCfg = ExecutorConfig({
            maxMessageSize: 100000,
            executor: executor
        });

        address[] memory reqDvns = new address[](1);
        reqDvns[0] = dvn0;
        UlnConfig memory ulnCfg = UlnConfig({
            confirmations: 1,
            requiredDVNCount: 1,
            optionalDVNCount: 0,
            optionalDVNThreshold: 0,
            requiredDVNs: reqDvns,
            optionalDVNs: new address[](0)
        });

        SetConfigParam[] memory params = new SetConfigParam[](2);
        params[0] = SetConfigParam({ eid: eid, configType: CONFIG_TYPE_EXECUTOR, config: abi.encode(execCfg) });
        params[1] = SetConfigParam({ eid: eid, configType: CONFIG_TYPE_ULN, config: abi.encode(ulnCfg) });

        vm.startBroadcast(deployerKey);
        (address recvLib,) = ep.getReceiveLibrary(moverAddr, eid);
        require(recvLib != address(0), "recvLib=0");
        ep.setConfig(moverAddr, recvLib, params);
        vm.stopBroadcast();

        console2.log("ULN config set for eid", eid);
    }
} 