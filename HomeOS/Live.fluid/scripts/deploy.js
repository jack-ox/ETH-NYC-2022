//Rinkeby addresses - change if using a different network
//Addresses are available on Superfluid doc https://docs.superfluid.finance/superfluid/developers/networks
const host = '0xeD5B5b32110c3Ded02a07c8b8e97513FAfb883B6';
const fUSDCx = '0x0F1D7C55A2B133E000eA10EeC03c774e0d6796e8';

//Jack's address
const landlord = "0xDbc3d803b241d3E9a31E5bB365A139bB043Fe0b7";

//Alex's address
const underwriter = "0x303CBE6DfD9DC761ecE44829f1EBD6Ed6B4B01bA";

//to deploy, run yarn hardhat deploy --network rinkeby

async function main() {
  const provider = new hre.ethers.providers.JsonRpcProvider(process.env.RINKEBY_RPC_URL);

  const sf = await Framework.create({
    chainId: (await provider.getNetwork()).chainId,
    provider,
    customSubgraphQueriesEndpoint: "",
    dataMode: "WEB3_ONLY"
  });

  // We get the contract to deploy
  const RentRouter = await hre.ethers.getContractFactory("MoneyRouter");
  //deploy the money router account using the proper host address and the address of the first signer
  const rentRouter = await RentRouter.deploy(host, fUSDCx, landlord, underwriter, 0.3);

  await rentRouter.deployed();

  console.log("RentRouter deployed to:", rentRouter.address);
}

module.exports.tags = ["RentRouter"];

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
