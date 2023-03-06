// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {LSP0ERC725AccountCore} from "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725AccountCore.sol";
import {LSP0ERC725AccountInitAbstract} from
  "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725AccountInitAbstract.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder, ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title Deployable Proxy Implementation of ERC725Account with late initialisation.
 * @dev Call initialize as soon as it is available.
 */
contract FuturePass is LSP0ERC725AccountInitAbstract, ERC721Holder, ERC1155Holder {
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice Sets the owner of the contract and set initial data
   * @param newOwner the owner of the contract
   * @param dataKey data key to set
   * @param dataKey data value to set
   */
  function initialize(address newOwner, bytes32 dataKey, bytes memory dataValue) external payable initializer {
    LSP0ERC725AccountInitAbstract._initialize(newOwner);
    _setData(dataKey, dataValue);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override (ERC1155Receiver, LSP0ERC725AccountCore)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}
