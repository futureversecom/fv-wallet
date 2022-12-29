// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@lukso/lsp-smart-contracts/contracts/LSP0ERC725Account/LSP0ERC725AccountInitAbstract.sol";

/**
 * @title Deployable Proxy Implementation of ERC725Account with late initialisation.
 * @dev Call initialize with the new owner as soon as it is available.
 */
contract LSP0ERC725AccountLateInit is LSP0ERC725AccountInitAbstract {
    constructor() {}

    /**
     * @notice Sets the owner of the contract and set initial data
     * @param newOwner the owner of the contract
     * @param dataKey data key to set
     * @param dataKey data value to set
     */
    function initializeWithData(address newOwner, bytes32 dataKey, bytes memory dataValue) external payable initializer {
        LSP0ERC725AccountInitAbstract._initialize(newOwner);
        _setData(dataKey, dataValue);
    }

    function disableInitializers() external {
        _disableInitializers();
    }
}
