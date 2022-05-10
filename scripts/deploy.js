const hre = require("hardhat");

async function main() {
  const BearNFTS = await hre.ethers.getContractFactory(
    "BearNFTS"
  );
  const deployedBearNFTS = await BearNFTS.deploy(
  );

  await deployedBearNFTS.deployed();

  console.log(
    "Deployed BearNFTS Address:",
    deployedBearNFTS.address
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });