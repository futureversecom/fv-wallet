// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title OwnableSilent
 * @dev modified version of OpenZeppelin implementation, without emits
 */
abstract contract OwnableSilent is Ownable {
  address private _owner;

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
   * Internal function without access restriction.
   * @dev Doesn't emit.
   */
  function _transferOwnership(address newOwner) internal override {
    _owner = newOwner;
  }

  /**
   * @dev Returns the address of the current owner.
   */
  function owner() public view override returns (address) {
    return _owner;
  }

  /**
   * @dev Throws if the sender is not the owner.
   */
  function _checkOwner() internal view override {
    require(owner() == _msgSender(), "Ownable: caller is not the owner");
  }
}
