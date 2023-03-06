import { ethers } from "hardhat";
import dotenv from "dotenv";

dotenv.config();

async function main() {
  // deploy FuturePass contract
  const futurePassFactory = await ethers.getContractFactory("FuturePass");
  const futurePass = await futurePassFactory.deploy();
  await futurePass.deployed();
  console.log("[contract] FuturePass deployed to:", futurePass.address);

  // deploy FuturePassKeyManager contract
  const keyManagerFactory = await ethers.getContractFactory("FuturePassKeyManager");
  const keyManager = await keyManagerFactory.deploy();
  await keyManager.deployed();
  console.log("[contract] FuturePassKeyManager deployed to:", keyManager.address);

  // deploy Utils library
  const utilsLibFactory = await ethers.getContractFactory("Utils");
  const utilsLib = await utilsLibFactory.deploy();
  await utilsLib.deployed();
  console.log("[library] Utils deployed to:", utilsLib.address);

  // deploy FuturePassIdentityRegistry contract - with linked Utils library
  const registryFactory = await ethers.getContractFactory("FuturePassIdentityRegistry", {
    libraries: { Utils: utilsLib.address, },
  });
  const identityRegistry = await registryFactory.deploy();
  await identityRegistry.deployed();
  console.log("[contract] FuturePassIdentityRegistry deployed to:", identityRegistry.address);

  // deploy TransparentUpgradeableProxy contract with PUBLIC_ADDRESS as admin
  // initialize FuturePassIdentityRegistry contract
  const transparentUpgradeableProxyFactory = await ethers.getContractFactory("TransparentUpgradeableProxy");
  const transparentUpgradeableProxy = await transparentUpgradeableProxyFactory.deploy(
    identityRegistry.address,
    process.env.PUBLIC_ADDRESS!,
    // abi.encodeWithSignature("initialize(address,address)", futurePassImpl, keyManagerImpl)
    (new ethers.utils.Interface(["function initialize(address,address)"]))
      .encodeFunctionData("initialize", [futurePass.address, keyManager.address])
  );
  await transparentUpgradeableProxy.deployed();
  console.log("[contract] TransparentUpgradeableProxy deployed to:", transparentUpgradeableProxy.address);
  
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
