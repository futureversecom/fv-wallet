// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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
