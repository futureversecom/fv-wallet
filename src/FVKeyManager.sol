// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {_PERMISSION_CHANGEOWNER} from "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6Constants.sol";
import {
  InvalidERC725Function, NoPermissionsSet
} from "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6Errors.sol";
import {LSP6Utils} from "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6Utils.sol";
import {ILSP14Ownable2Step} from "@lukso/lsp-smart-contracts/contracts/LSP14Ownable2Step/ILSP14Ownable2Step.sol";
import {
  EXECUTE_SELECTOR, SETDATA_SELECTOR, SETDATA_ARRAY_SELECTOR
} from "@erc725/smart-contracts/contracts/constants.sol";
import {ERC725Y} from "@erc725/smart-contracts/contracts/ERC725Y.sol";

import "./custom/LSP6KeyManagerInitVirtual.sol";
import "./custom/OwnableSilent.sol";

/**
 * @title Proxy implementation of a contract acting as a controller of an ERC725 Account, using permissions stored in the ERC725Y storage
 * @notice This implementation includes an owner which is the only account able to manage permissions and ownership.
 */
contract FVKeyManager is LSP6KeyManagerInitVirtual, OwnableSilent {
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice Initiate the account with the address of the ERC725Account contract and sets LSP6KeyManager InterfaceId
   * @param target_ The address of the ER725Account to control
   * @param owner_ The owner address of the the Key Manager
   */
  function initialize(address target_, address owner_) external initializer {
    LSP6KeyManagerInitVirtual._initialize(target_);
    OwnableSilent._setOwner(owner_);
  }

  /**
   * @dev verify if the `from` address is allowed to execute the `payload` on the `target`.
   * @param from either the caller of `execute(...)` or the signer of `executeRelayCall(...)`.
   * @param payload the payload to execute on the `target`.
   */
  function _verifyPermissions(address from, bytes calldata payload) internal view override {
    bytes4 erc725Function = bytes4(payload);

    if (
      erc725Function == SETDATA_SELECTOR // ERC725Y.setData(bytes32,bytes)
        || erc725Function == SETDATA_ARRAY_SELECTOR // ERC725Y.setData(bytes32[],bytes[])
        || erc725Function == ILSP14Ownable2Step.transferOwnership.selector
    ) {
      // Only the owner can use these selectors
      _checkOwner();
    } else if (erc725Function == EXECUTE_SELECTOR) {
      bytes32 permissions = LSP6Utils.getPermissionsFor(ERC725Y(_target), from);
      if (permissions == bytes32(0)) {
        revert NoPermissionsSet(from);
      }
      _verifyCanExecute(from, permissions, payload);
    } else {
      revert InvalidERC725Function(erc725Function);
    }
  }
}
