// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {VmSafe} from "forge-std/Vm.sol";
import {EIP191Signer} from "@lukso/lsp-smart-contracts/contracts/Custom/EIP191Signer.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@lukso/lsp-smart-contracts/contracts/LSP6KeyManager/LSP6Constants.sol";

import "../../src/Utils.sol";

import "./MockERC20.t.sol";

contract DataHelper {
    using ECDSA for bytes32;

    // Construct call data for calling mint on the mockERC20
    function createERC20ExecuteDataForCall(MockERC20 _mockERC20)
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

    function signForRelayCall(
        bytes memory payload,
        uint256 nonce,
        uint256 msgValue,
        uint256 pk,
        VmSafe vm,
        address validator
    ) internal view returns (bytes memory) {
        bytes memory encodedMessage = abi.encodePacked(
            LSP6_VERSION,
            block.chainid,
            nonce,
            msgValue,
            payload
        );
        return sign(EIP191Signer.toDataWithIntendedValidator(validator, encodedMessage), pk, vm);
    }

    function sign(
        bytes32 data,
        uint256 pk,
        VmSafe vm
    ) internal pure returns (bytes memory) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        (v, r, s) = vm.sign(pk, data);
        return abi.encodePacked(r, s, v);
    }

    function predictProxyWalletAddress(
        address deployer,
        address fvAccountBeacon,
        address userAddr
    ) public pure returns (address) {
        bytes memory bytecodeWithConstructor = abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(fvAccountBeacon, bytes("")));

        bytes32 salt = keccak256(abi.encodePacked(userAddr));

        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecodeWithConstructor))
        );

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint(hash)));
    }

    function predictProxyWalletKeyManagerAddress(
        address deployer,
        address fvKeyManagerBeacon,
        address proxyWalletAddress,
        address userAddr
    ) public pure returns (address) {
        bytes memory bytecodeWithConstructor = abi.encodePacked(
            type(BeaconProxy).creationCode,
            abi.encode(
                fvKeyManagerBeacon,
                abi.encodeWithSignature("initialize(address)", address(proxyWalletAddress))
            )
        );

        bytes32 salt = keccak256(abi.encodePacked(userAddr));

        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecodeWithConstructor))
        );

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint(hash)));
    }
}
