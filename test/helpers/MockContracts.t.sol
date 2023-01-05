// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MyToken", "MTK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract DelegateAttacker {
    address private owner;
    constructor () {
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