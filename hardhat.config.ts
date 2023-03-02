import { HardhatUserConfig } from "hardhat/config";
import "hardhat-preprocessor";
import "@nomicfoundation/hardhat-toolbox";

import fs from "fs";
import dotenv from "dotenv";

dotenv.config();

function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean) // remove empty lines
    .map((line: string) => line.trim().split("="));
}

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  // https://book.getfoundry.sh/config/hardhat
  preprocess: {
    eachLine: (hre) => ({
      transform: (line: string) => {
        if (line.match(/".*.sol";$/)) { // match all lines with `"<any-import-path>.sol";`
          for (const [from, to] of getRemappings()) {
            if (line.includes(from)) {
              line = line.replace(from, to);
              break;
            }
          }
        }
        return line;
      },
    }),
  },
  paths: {
    sources: "./src",
    cache: "./cache_hardhat",
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      accounts: [process.env.PRIVATE_KEY!],
    },
    seed: {
      url: "http://127.0.0.1:9933",
      accounts: [ process.env.PRIVATE_KEY! ],
    },
    porcini: {
      url: "https://porcini.au.rootnet.app/",
      accounts: [ process.env.PRIVATE_KEY! ],
    },
    root: {
      url: "https://root.rootnet.live",
      accounts: [ process.env.PRIVATE_KEY! ],
    },
  },
};

export default config;
