// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

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
}
