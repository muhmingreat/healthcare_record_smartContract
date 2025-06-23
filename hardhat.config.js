require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
/** @type import('hardhat/config').HardhatUserConfig */
// const INFURA_API_KEY = process.env.INFURA_API_KEY;
// const PRIVATE_KEY = process.env.PRIVATE_KEY;
const { INFURA_API_KEY, PRIVATE_KEY } = process.env;
module.exports = {
  defaultNetwork: "celoAlfajores",
  networks: {
    hardhat: {
    },
    celoAlfajores: {
      url:  'https://alfajores-forno.celo-testnet.org',
      // `https://celo-alfajores.infura.io/v3/${INFURA_API_KEY}` ,
      // "https://alfajores-forno.celo-testnet.org",
      accounts: [`0x${PRIVATE_KEY}`]
    }
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


