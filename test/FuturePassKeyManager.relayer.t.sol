// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC725X} from "@erc725/smart-contracts/contracts/interfaces/IERC725X.sol";
import {IERC725Y} from "@erc725/smart-contracts/contracts/interfaces/IERC725Y.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {EIP191Signer} from "@lukso/lsp-smart-contracts/contracts/Custom/EIP191Signer.sol";
import {ILSP1UniversalReceiver} from
  "@lukso/lsp-smart-contracts/contracts/LSP1UniversalReceiver/ILSP1UniversalReceiver.sol";
import {LSP6_VERSION} from "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6Constants.sol";
import {ILSP6KeyManager} from "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/ILSP6KeyManager.sol";
import {ERC1155Holder, IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import {IFuturePassIdentityRegistry} from "../src/interfaces/IFuturePassIdentityRegistry.sol";
import {FuturePassIdentityRegistry} from "../src/FuturePassIdentityRegistry.sol";
import {FuturePass} from "../src/FuturePass.sol";
import {FuturePassKeyManager} from "../src/FuturePassKeyManager.sol";

import "../src/libraries/Utils.sol";
import "./helpers/MockContracts.t.sol";

contract FVIdentityRegistryTest is Test, ERC721Holder, ERC1155Holder {
  address private constant ADMIN = address(0x000000000000000000000000000000000000dEaD);
  address private constant NON_ADMIN = address(0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045);

  IFuturePassIdentityRegistry public futurePassIdentityRegistry;
  IFuturePassIdentityRegistry private registryImpl;
  FuturePass private futurePassImpl;
  FuturePassKeyManager private keyManagerImpl;

  function setUp() public {
    // deploy upgradable contract
    registryImpl = new FuturePassIdentityRegistry();

    // deploy fv account implementation
    futurePassImpl = new FuturePass();

    // deploy key manager implementation
    keyManagerImpl = new FuturePassKeyManager();

    // deploy proxy with dead address as proxy admin, initialize upgradable future pass identity registry
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      address(registryImpl),
      ADMIN,
      abi.encodeWithSignature("initialize(address,address)", address(futurePassImpl), address(keyManagerImpl))
    );

    // note: admin can call additional functions on proxy
    futurePassIdentityRegistry = FuturePassIdentityRegistry(address(proxy)); // set proxy as futurePassIdentityRegistry
  }

  function testCallRelayERC721Transfer() public {
    uint256 eoaKey = 0xabfa816b2d044fca73f609721c7811b3876e69f915a5398bdb88b3ce5bf28a61;
    address eoa = vm.addr(eoaKey);

    ILSP6KeyManager userKeyManager = ILSP6KeyManager(futurePassIdentityRegistry.register(eoa));
    FuturePass futurePass = FuturePass(payable(userKeyManager.target()));

    MockERC721 mockERC721 = new MockERC721();
    mockERC721.safeMint(address(futurePass), 0);
    mockERC721.safeMint(address(futurePass), 1);

    assertEq(mockERC721.balanceOf(eoa), 0);
    assertEq(mockERC721.balanceOf(address(futurePass)), 2);

    bytes memory transferCall = abi.encodeWithSignature("transferFrom(address,address,uint256)", address(futurePass), eoa, 1);
    // vm.prank(address(futurePass));
    // mockERC721.transferFrom(address(futurePass), eoa, 1);
    // (bool success, ) = address(mockERC721).call(transferCall);
    // assertEq(success, true);
    // assertEq(mockERC721.balanceOf(eoa), 1);

    bytes memory payload = abi.encodeWithSignature(
      "execute(uint256,address,uint256,bytes)", // operationType, target, value, data
      0, // CALL
      address(mockERC721),
      0,
      transferCall
    );
    // bytes memory signature = signForRelayCall(payload, 0, 0, eoaKey, vm, address(userKeyManager));

    (uint256 nonce, uint256 msgValue) = (0, 0);
    bytes memory encodedMessage = abi.encodePacked(LSP6_VERSION, block.chainid, nonce, msgValue, payload);
    bytes32 signedPayload = EIP191Signer.toDataWithIntendedValidator(address(userKeyManager), encodedMessage);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(eoaKey, signedPayload);
    bytes memory signature = abi.encodePacked(r, s, v);

    userKeyManager.executeRelayCall(signature, 0, payload);

    assertEq(mockERC721.balanceOf(address(futurePass)), 1);
    assertEq(mockERC721.ownerOf(1), eoa);
  }
}
