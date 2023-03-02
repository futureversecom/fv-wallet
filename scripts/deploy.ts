import { ethers } from "hardhat";
import dotenv from "dotenv";

dotenv.config();

async function main() {
  // deploy FVIdentity contract
  const fvAccountFactory = await ethers.getContractFactory("E2EWallet");
  const fvAccount = await fvAccountFactory.deploy();
  await fvAccount.deployed();
  console.log("[contract] E2EWallet deployed to:", fvAccount.address);

  // deploy FVKeyManager contract
  const keyManagerFactory = await ethers.getContractFactory("E2EWalletKeyManager");
  const fvKeyManager = await keyManagerFactory.deploy();
  await fvKeyManager.deployed();
  console.log("[contract] E2EWalletKeyManager deployed to:", fvKeyManager.address);

  // deploy Utils library
  const utilsLibFactory = await ethers.getContractFactory("Utils");
  const utilsLib = await utilsLibFactory.deploy();
  await utilsLib.deployed();
  console.log("[library] Utils deployed to:", utilsLib.address);

  // deploy E2EWalletRegistry contract - with linked Utils library
  const fvIdentityRegistryFactory = await ethers.getContractFactory("E2EWalletRegistry", {
    libraries: { Utils: utilsLib.address, },
  });
  const fvIdentityRegistry = await fvIdentityRegistryFactory.deploy();
  await fvIdentityRegistry.deployed();
  console.log("[contract] E2EWalletRegistry deployed to:", fvIdentityRegistry.address);

  // deploy TransparentUpgradeableProxy contract with PUBLIC_ADDRESS as admin
  // initialize E2EWalletRegistry contract
  const transparentUpgradeableProxyFactory = await ethers.getContractFactory("TransparentUpgradeableProxy");
  const transparentUpgradeableProxy = await transparentUpgradeableProxyFactory.deploy(
    fvIdentityRegistry.address,
    process.env.PUBLIC_ADDRESS!,
    // abi.encodeWithSignature("initialize(address,address)", fvAccountImpl, keyManagerImpl)
    (new ethers.utils.Interface(["function initialize(address,address)"]))
      .encodeFunctionData("initialize", [fvAccount.address, fvKeyManager.address])
  );
  await transparentUpgradeableProxy.deployed();
  console.log("[contract] TransparentUpgradeableProxy deployed to:", transparentUpgradeableProxy.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
