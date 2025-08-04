require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
/** @type import('hardhat/config').HardhatUserConfig */


const { ALCHEMY_API_URL, CROSSFI_PRIVATE_KEY } = process.env;
module.exports = {
  defaultNetwork: "crossFi",
  networks: {
   crossFi:{
    url:"https://rpc.testnet.ms",
      accounts:[`0x${CROSSFI_PRIVATE_KEY}`]
    // url:`https://crossfi-testnet.g.alchemy.com/2/${ALCHEMY_API_URL}`,
  },
  },
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 40000
  }
}


