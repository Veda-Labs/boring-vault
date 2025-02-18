// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateStakedEthfiMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateStakedEthfiMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x86B5780b606940Eb59A062aA85a07959518c0161;
    address public managerAddress = 0xb623FaF559b414A1C7EF2d15f3260CA0Fd239431;
    address public accountantAddress = 0x05A1552c5e18F5A0BB9571b5F2D6a4765ebdA32b;
    address public rawDataDecoderAndSanitizer = 0x52ED1F19592aE32580619Eb5BaA3f67530d99F5c;

    address public itbDecoderAndSanitizer = 0xcfa57ea1b1E138cf89050253CcF5d0836566C06D;

    address public itbKETHFIPositionManager = 0xCF413A1989e33C8Ef59fbA79935d93205C9BE4c7;

    address drone0 = 0x15CBAF5ca8859A8623306a99528d38E077337CF0; 
    address drone1 = 0xC4AF99074450d7c9569853b09Cf8402faFd71d19; 
    address drone2 = 0x87Dd519F85697d7dA46603869985c46a381ecDfa;  

    address operator0 = 0xDd777e5158Cb11DB71B4AF93C75A96eA11A2A615; 
    address operator1 = 0x2c7cB7d5dC4aF9caEE654553a144C76F10D4b320;  
    address operator2 = 0x72F4EDd19a96Bcd796d2ba49C6AC534680785619; 

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateKarakVaultStrategistMerkleRoot();
    }

    function generateKarakVaultStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== Symbiotic ==========================
        address[] memory defaultCollaterals = new address[](1);
        defaultCollaterals[0] = getAddress(sourceChain, "ethfiDefaultCollateral");
        _addSymbioticLeafs(leafs, defaultCollaterals);

        // ========================== ITB Karak Position Managers ==========================
        _addLeafsForITBKarakPositionManager(
            leafs,
            itbDecoderAndSanitizer,
            itbKETHFIPositionManager,
            getAddress(sourceChain, "kETHFI"),
            getAddress(sourceChain, "vaultSupervisor")
        );

        // ========================== Karak ==========================
        _addKarakLeafs(leafs, getAddress(sourceChain, "vaultSupervisor"), getAddress(sourceChain, "kETHFI"));

        // ========================== Reclamation ==========================
        {
            address reclamationDecoder = 0xd7335170816912F9D06e23d23479589ed63b3c33;
            address target = 0xCF413A1989e33C8Ef59fbA79935d93205C9BE4c7;
            _addReclamationLeafs(leafs, target, reclamationDecoder);
        }

        // ========================== Symbiotic ==========================
        address[] memory vaults = new address[](1); 
        vaults[0] = getAddress(sourceChain, "EtherFi_ETHFISymbioticVault"); 
        ERC20[] memory assets = new ERC20[](1); 
        assets[0] = getERC20(sourceChain, "ETHFI"); 
        address[] memory rewards = new address[](1); 
        _addSymbioticVaultLeafs(leafs, vaults, assets, rewards); 

        // ========================== Drone Transfers ==========================
        ERC20[] memory localTokens = new ERC20[](1);
        localTokens[0] = getERC20("mainnet", "ETHFI");

        _addLeafsForDroneTransfers(leafs, drone0, localTokens);
        _addLeafsForDroneTransfers(leafs, drone1, localTokens);
        _addLeafsForDroneTransfers(leafs, drone2, localTokens);

        // ========================== Drone0 Leafs ==========================

        uint256 drone0StartIndex = leafIndex + 1;
        setAddress(true, sourceChain, "boringVault", drone0);
        
        // ========================== Drone0 Leafs ==========================
        
        _addLeafsForEigenLayerLST(
            leafs,
            getAddress(sourceChain, "ETHFI"), 
            getAddress(sourceChain, "ethfiStrategy"), //strategy
            getAddress(sourceChain, "strategyManager"),
            getAddress(sourceChain, "delegationManager"),            
            operator0, //operator
            getAddress(sourceChain, "eigenRewards"), //eigenRewards
            getAddress(sourceChain, "dev1Address") //claimerFor
        );  


        // ========================== Drone Functions ==========================
        _createDroneLeafs(leafs, drone0, drone0StartIndex, leafIndex + 1);


        // ========================== Drone1 Leafs ==========================

        uint256 drone1StartIndex = leafIndex + 1;
        setAddress(true, sourceChain, "boringVault", drone1);
        
        // ========================== Drone1 Leafs ==========================
        
        _addLeafsForEigenLayerLST(
            leafs,
            getAddress(sourceChain, "ETHFI"), 
            getAddress(sourceChain, "ethfiStrategy"), //strategy
            getAddress(sourceChain, "strategyManager"),
            getAddress(sourceChain, "delegationManager"),            
            operator1, //operator
            getAddress(sourceChain, "eigenRewards"), //eigenRewards
            getAddress(sourceChain, "dev1Address") //claimerFor
        );  

        // ========================== Drone Functions ==========================
        _createDroneLeafs(leafs, drone1, drone1StartIndex, leafIndex + 1);


        // ========================== Drone2 Leafs ==========================

        uint256 drone2StartIndex = leafIndex + 1;
        setAddress(true, sourceChain, "boringVault", drone2);
        
        // ========================== Drone2 Leafs ==========================
        
        _addLeafsForEigenLayerLST(
            leafs,
            getAddress(sourceChain, "ETHFI"), 
            getAddress(sourceChain, "ethfiStrategy"), //strategy
            getAddress(sourceChain, "strategyManager"),
            getAddress(sourceChain, "delegationManager"),            
            operator2, //operator
            getAddress(sourceChain, "eigenRewards"), //eigenRewards
            getAddress(sourceChain, "dev1Address") //claimerFor
        );  

        // ========================== Drone Functions ==========================
        _createDroneLeafs(leafs, drone2, drone2StartIndex, leafIndex + 1);
        
        
        // ========================== Verify ==========================
        
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/StakedETHFIStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
