// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../src/Utils.sol";

import "./MockERC20.t.sol";

contract DataHelper {
    // Construct call data for calling mint on the mockERC20
    function createTestERC20ExecuteData(MockERC20 _mockERC20)
        internal
        view
        returns (bytes memory)
    {
        // abi encoded call to mint 100 tokens to address(this)
        bytes memory mintCall = abi.encodeWithSelector(
            _mockERC20.mint.selector,
            address(this),
            100
        );
        // abi encoded call to execute mint call
        bytes memory executeCall = abi.encodeWithSignature(
            "execute(uint256,address,uint256,bytes)", // operationType, target, value, data
            0,
            address(_mockERC20),
            0,
            mintCall
        );

        return executeCall;
    }

    /**
     * Create permission data for whitelisting all calls to given address.
     * @param addrs The addresses to whitelist.
     * @return permissionData The data to set to allow access to all addresses.
     * @notice This method whitelists all interfaces and methods.
     * @dev Include user's existing permissions when constructing this list so they are not overridden.
     */
    function createCallContractWhitelistData(address[] memory addrs)
        public
        pure
        returns (bytes memory)
    {
        string memory s = "";
        // Create compact bytes array for permission data
        for (uint256 i = 0; i < addrs.length; i++) {
            // https://github.com/lukso-network/lsp-smart-contracts/blob/6540c98f174c2d6b8340502725bcd338da7c0cca/contracts/LSP6KeyManager/LSP6KeyManagerCore.sol#L872
            s = string.concat(
                s,
                "1cffffffff", // 1c (length) + allow all interfaces
                Utils.toHexStringNoPrefix(addrs[i]), // addr allowed to access
                "ffffffff" // allow all methods
            );
        }
        return Utils.toBytes(s);
    }
}