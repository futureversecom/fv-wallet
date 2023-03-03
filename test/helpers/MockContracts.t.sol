// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {FVIdentity} from "../../src/FVIdentity.sol";
import {FVKeyManager} from "../../src/FVKeyManager.sol";

contract MockERC20 is ERC20 {
  constructor() ERC20("MyToken", "MTK") {}

  function mint(address to, uint256 amount) public {
    _mint(to, amount);
  }

  function mintCaller(uint256 amount) public {
    _mint(msg.sender, amount);
  }
}

contract MockERC721 is ERC721 {
  constructor() ERC721("MyToken", "MTK") {}

  function safeMint(address to, uint256 tokenId) public {
    _safeMint(to, tokenId);
  }
}

contract MockERC1155 is ERC1155 {
  constructor() ERC1155("") {}

  function setURI(string memory newuri) public {
    _setURI(newuri);
  }

  function mint(address account, uint256 id, uint256 amount) public {
    _mint(account, id, amount, "");
  }

  function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) public {
    _mintBatch(to, ids, amounts, "");
  }
}

contract DelegateAttacker {
  address private owner;

  constructor() {
    owner = msg.sender;
  }

  function balance() public view returns (uint256) {
    return address(this).balance;
  }

  function attack() public {
    selfdestruct(payable(owner));
  }
}

contract UpgradedMock is Initializable {
  constructor() {
    _disableInitializers();
  }

  /// @dev contracts with `initializer` modifier set proxy `initialized` state to `1`
  /// hence we need to set it to `2` to reenable to call `initialize` for future contracts
  function initialize() external virtual reinitializer(2) {}
}

/// @dev Key Manager with additional storage and functions
contract MockKeyManagerUpgraded is FVKeyManager {
  uint256 public val;

  function incrementVal() external {
    ++val;
  }
}

/// @dev Key Manager with additional storage and functions
contract MockIdentityUpgraded is FVIdentity {
  uint256 public setDataCounter;

  function setData(bytes32 dataKey, bytes memory dataValue) public override onlyOwner {
    ++setDataCounter;
    super.setData(dataKey, dataValue);
  }
}
