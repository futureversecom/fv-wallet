import { ethers } from "hardhat";
import dotenv from "dotenv";

dotenv.config();

async function main() {
  // deploy LSP0ERC725AccountLateInit contract
  const fvAccountFactory = await ethers.getContractFactory("LSP0ERC725AccountLateInit");
  const fvAccount = await fvAccountFactory.deploy();
  await fvAccount.deployed();
  console.log("LSP0ERC725AccountLateInit deployed to:", fvAccount.address);

  // deploy LSP6KeyManagerInit contract
  const lsp6KeyManagerInitFactory = await ethers.getContractFactory("LSP6KeyManagerInit");
  const lsp6KeyManagerInit = await lsp6KeyManagerInitFactory.deploy();
  await lsp6KeyManagerInit.deployed();
  console.log("LSP6KeyManagerInit deployed to:", lsp6KeyManagerInit.address);

  // deploy Utils library
  const utilsLibFactory = await ethers.getContractFactory("Utils");
  const utilsLib = await utilsLibFactory.deploy();
  await utilsLib.deployed();
  console.log("[library] Utils deployed to:", utilsLib.address);

  // deploy FVAccountRegistry contract - with linked Utils library
  const fvAccountRegistryFactory = await ethers.getContractFactory("FVAccountRegistry", {
    libraries: { Utils: utilsLib.address, },
  });
  const fvAccountRegistry = await fvAccountRegistryFactory.deploy();
  await fvAccountRegistry.deployed();
  console.log("FVAccountRegistry deployed to:", fvAccountRegistry.address);

  // deploy TransparentUpgradeableProxy contract with PUBLIC_ADDRESS as admin
  // initialize FVAccountRegistry contract
  const transparentUpgradeableProxyFactory = await ethers.getContractFactory("TransparentUpgradeableProxy");
  const transparentUpgradeableProxy = await transparentUpgradeableProxyFactory.deploy(
    fvAccountRegistry.address,
    process.env.PUBLIC_ADDRESS!,
    // abi.encodeWithSignature("initialize(address,address)", fvAccountImpl, keyManagerImpl)
    (new ethers.utils.Interface(["function initialize(address,address)"]))
      .encodeFunctionData("initialize", [fvAccount.address, lsp6KeyManagerInit.address])
  );
  await transparentUpgradeableProxy.deployed();
  console.log("TransparentUpgradeableProxy deployed to:", transparentUpgradeableProxy.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
