// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC725X} from "@erc725/smart-contracts/contracts/interfaces/IERC725X.sol";
import {IERC725Y} from "@erc725/smart-contracts/contracts/interfaces/IERC725Y.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {ILSP1UniversalReceiver} from
  "@lukso/lsp-smart-contracts/contracts/LSP1UniversalReceiver/ILSP1UniversalReceiver.sol";
import {ILSP6KeyManager} from "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/ILSP6KeyManager.sol";
import {ERC1155Holder, IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import {IFVIdentityRegistry} from "../src/interfaces/IFVIdentityRegistry.sol";
import {FVIdentityRegistry} from "../src/FVIdentityRegistry.sol";
import {FVIdentity} from "../src/FVIdentity.sol";
import {FVKeyManager} from "../src/FVKeyManager.sol";

import "../src/libraries/Utils.sol";
import "./helpers/MockContracts.t.sol";

contract FVIdentityRegistryTest is Test, ERC721Holder, ERC1155Holder {
  address private constant ADMIN = address(0x000000000000000000000000000000000000dEaD);
  address private constant NON_ADMIN = address(0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045);

  IFVIdentityRegistry public fvIdentityRegistry;
  IFVIdentityRegistry private registryImpl;
  FVIdentity private fvAccountImpl;
  FVKeyManager private keyManagerImpl;

  function setUp() public {
    // deploy upgradable contract
    registryImpl = new FVIdentityRegistry();

    // deploy fv account implementation
    fvAccountImpl = new FVIdentity();

    // deploy key manager implementation
    keyManagerImpl = new FVKeyManager();

    // deploy proxy with dead address as proxy admin, initialize upgradable identity registry
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      address(registryImpl),
      ADMIN,
      abi.encodeWithSignature("initialize(address,address)", address(fvAccountImpl), address(keyManagerImpl))
    );

    // note: admin can call additional functions on proxy
    fvIdentityRegistry = FVIdentityRegistry(address(proxy)); // set proxy as fvIdentityRegistry
  }

  //
  // Interfaces
  //
  function testIdentityInterfaces() public {
    address userKeyManager = fvIdentityRegistry.register(address(0));
    IERC165 userFVWalletProxy = IERC165(ILSP6KeyManager(userKeyManager).target());

    assertTrue(userFVWalletProxy.supportsInterface(type(IERC165).interfaceId), "ERC165 support");
    assertTrue(userFVWalletProxy.supportsInterface(type(IERC1271).interfaceId), "ERC1271 support");
    assertTrue(userFVWalletProxy.supportsInterface(type(ILSP1UniversalReceiver).interfaceId), "LSP1 support");
    assertTrue(userFVWalletProxy.supportsInterface(type(IERC725X).interfaceId), "ERC725X support");
    assertTrue(userFVWalletProxy.supportsInterface(type(IERC725Y).interfaceId), "ERC725Y support");
    assertTrue(userFVWalletProxy.supportsInterface(type(IERC1155Receiver).interfaceId), "ERC1155Receiver support");
  }

  //
  // ERC20 support
  //
  function test_EOACanSendERC20ToIdentity() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));
    FVIdentity wallet = FVIdentity(payable(userKeyManager.target()));

    MockERC20 mockERC20 = new MockERC20();
    mockERC20.mint(NON_ADMIN, 1000);

    // approve
    vm.prank(NON_ADMIN);
    mockERC20.approve(address(wallet), 1000);

    // transfer
    vm.prank(NON_ADMIN);
    mockERC20.transfer(address(wallet), 1000);

    assertEq(mockERC20.balanceOf(address(wallet)), 1000);
  }

  function test_ContractCanSendERC20ToIdentity() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(NON_ADMIN));
    FVIdentity wallet = FVIdentity(payable(userKeyManager.target()));

    MockERC20 mockERC20 = new MockERC20();
    mockERC20.mint(address(this), 1000);

    // approve
    mockERC20.approve(address(wallet), 1000);

    // send
    mockERC20.transfer(address(wallet), 1000);

    assertEq(mockERC20.balanceOf(address(wallet)), 1000);
  }

  function test_ContractCanMintERC20ToIdentity() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(NON_ADMIN));
    FVIdentity wallet = FVIdentity(payable(userKeyManager.target()));

    MockERC20 mockERC20 = new MockERC20();
    mockERC20.mint(address(wallet), 1000);

    assertEq(mockERC20.balanceOf(address(wallet)), 1000);
  }

  //
  // ERC721 support
  //
  function test_EOACanSendERC721ToIdentity() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));
    FVIdentity wallet = FVIdentity(payable(userKeyManager.target()));

    uint256 tokenId = 2;
    MockERC721 mockERC721 = new MockERC721();
    mockERC721.safeMint(NON_ADMIN, tokenId);

    // approve
    vm.prank(NON_ADMIN);
    mockERC721.approve(address(wallet), tokenId);

    // transfer
    vm.prank(NON_ADMIN);
    mockERC721.safeTransferFrom(NON_ADMIN, address(wallet), tokenId);

    assertEq(mockERC721.balanceOf(address(wallet)), 1);
    assertEq(mockERC721.ownerOf(tokenId), address(wallet));
  }

  function test_ContractCanSendERC721ToIdentity() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(NON_ADMIN));
    FVIdentity wallet = FVIdentity(payable(userKeyManager.target()));

    uint256 tokenId = 2;
    MockERC721 mockERC721 = new MockERC721();
    mockERC721.safeMint(address(this), tokenId);

    // approve
    mockERC721.approve(address(wallet), tokenId);

    // send
    mockERC721.safeTransferFrom(address(this), address(wallet), tokenId);

    assertEq(mockERC721.balanceOf(address(wallet)), 1);
    assertEq(mockERC721.ownerOf(tokenId), address(wallet));
  }

  function test_ContractCanMintERC721ToIdentity() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(NON_ADMIN));
    FVIdentity wallet = FVIdentity(payable(userKeyManager.target()));

    uint256 tokenId = 2;
    MockERC721 mockERC721 = new MockERC721();
    mockERC721.safeMint(address(wallet), tokenId);

    assertEq(mockERC721.balanceOf(address(wallet)), 1);
    assertEq(mockERC721.ownerOf(tokenId), address(wallet));
  }

  //
  // ERC1155 support
  //
  function test_EOACanSendERC1155ToIdentity() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(address(this)));
    FVIdentity wallet = FVIdentity(payable(userKeyManager.target()));

    uint256 tokenId = 2;
    uint256 tokenAmount = 2000;
    MockERC1155 mockERC1155 = new MockERC1155();
    mockERC1155.mint(NON_ADMIN, tokenId, tokenAmount);

    // approve
    vm.prank(NON_ADMIN);
    mockERC1155.isApprovedForAll(NON_ADMIN, address(wallet));

    // transfer
    vm.prank(NON_ADMIN);
    mockERC1155.safeTransferFrom(NON_ADMIN, address(wallet), tokenId, tokenAmount, "");

    assertEq(mockERC1155.balanceOf(address(wallet), tokenId), tokenAmount);
  }

  function test_ContractCanSendERC1155ToIdentity() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(NON_ADMIN));
    FVIdentity wallet = FVIdentity(payable(userKeyManager.target()));

    uint256 tokenId = 2;
    uint256 tokenAmount = 2000;
    MockERC1155 mockERC1155 = new MockERC1155();
    mockERC1155.mint(address(this), tokenId, tokenAmount);

    // approve
    mockERC1155.isApprovedForAll(address(this), address(wallet));

    // send
    mockERC1155.safeTransferFrom(address(this), address(wallet), tokenId, tokenAmount, "");

    assertEq(mockERC1155.balanceOf(address(wallet), tokenId), tokenAmount);
  }

  function test_ContractCanMintERC1155ToIdentity() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(fvIdentityRegistry.register(NON_ADMIN));
    FVIdentity wallet = FVIdentity(payable(userKeyManager.target()));

    uint256 tokenId = 2;
    uint256 tokenAmount = 2000;
    MockERC1155 mockERC1155 = new MockERC1155();
    mockERC1155.mint(address(wallet), tokenId, tokenAmount);

    assertEq(mockERC1155.balanceOf(address(wallet), tokenId), tokenAmount);
  }
}
