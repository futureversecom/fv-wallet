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

  //
  // Interfaces
  //
  function testIdentityInterfaces() public {
    address userKeyManager = futurePassIdentityRegistry.register(address(0));
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
  function test_EOACanSendERC20ToFuturePass() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(futurePassIdentityRegistry.register(address(this)));
    FuturePass wallet = FuturePass(payable(userKeyManager.target()));

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

  function test_ContractCanSendERC20ToFuturePass() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(futurePassIdentityRegistry.register(NON_ADMIN));
    FuturePass wallet = FuturePass(payable(userKeyManager.target()));

    MockERC20 mockERC20 = new MockERC20();
    mockERC20.mint(address(this), 1000);

    // approve
    mockERC20.approve(address(wallet), 1000);

    // send
    mockERC20.transfer(address(wallet), 1000);

    assertEq(mockERC20.balanceOf(address(wallet)), 1000);
  }

  function test_ContractCanMintERC20ToFuturePass() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(futurePassIdentityRegistry.register(NON_ADMIN));
    FuturePass wallet = FuturePass(payable(userKeyManager.target()));

    MockERC20 mockERC20 = new MockERC20();
    mockERC20.mint(address(wallet), 1000);

    assertEq(mockERC20.balanceOf(address(wallet)), 1000);
  }

  //
  // ERC721 support
  //
  function test_EOACanSendERC721ToFuturePass() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(futurePassIdentityRegistry.register(address(this)));
    FuturePass wallet = FuturePass(payable(userKeyManager.target()));

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

  function test_ContractCanSendERC721ToFuturePass() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(futurePassIdentityRegistry.register(NON_ADMIN));
    FuturePass wallet = FuturePass(payable(userKeyManager.target()));

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

  function test_ContractCanMintERC721ToFuturePass() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(futurePassIdentityRegistry.register(NON_ADMIN));
    FuturePass wallet = FuturePass(payable(userKeyManager.target()));

    uint256 tokenId = 2;
    MockERC721 mockERC721 = new MockERC721();
    mockERC721.safeMint(address(wallet), tokenId);

    assertEq(mockERC721.balanceOf(address(wallet)), 1);
    assertEq(mockERC721.ownerOf(tokenId), address(wallet));
  }

  //
  // ERC1155 support
  //
  function test_EOACanSendERC1155ToFuturePass() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(futurePassIdentityRegistry.register(address(this)));
    FuturePass wallet = FuturePass(payable(userKeyManager.target()));

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

  function test_ContractCanSendERC1155ToFuturePass() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(futurePassIdentityRegistry.register(NON_ADMIN));
    FuturePass wallet = FuturePass(payable(userKeyManager.target()));

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

  function test_ContractCanMintERC1155ToFuturePass() public {
    ILSP6KeyManager userKeyManager = ILSP6KeyManager(futurePassIdentityRegistry.register(NON_ADMIN));
    FuturePass wallet = FuturePass(payable(userKeyManager.target()));

    uint256 tokenId = 2;
    uint256 tokenAmount = 2000;
    MockERC1155 mockERC1155 = new MockERC1155();
    mockERC1155.mint(address(wallet), tokenId, tokenAmount);

    assertEq(mockERC1155.balanceOf(address(wallet), tokenId), tokenAmount);
  }
}
