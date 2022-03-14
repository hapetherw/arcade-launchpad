import hre from "hardhat";
import { load, save } from "./utils"
import * as dotenv from "dotenv";
dotenv.config();
import { getBigNumber } from '../test/utils'

async function main() {
    const loopContractAddress = (await load('loopContract')).address
    await hre.run("verify:verify", {
        address: loopContractAddress,
        constructorArguments: [
            'LOOP',
            'LOOP',
            18
        ],
    });

    const presaleContractAddress = (await load('presaleContract')).address
    await hre.run("verify:verify", {
        address: presaleContractAddress,
        constructorArguments: [
            loopContractAddress,
            process.env.SALE_START,
            process.env.SALE_END,
            process.env.FCFS_MINUTES,
            getBigNumber(process.env.TOKEN_PRICE+''),
            getBigNumber(process.env.ALLOWEDTOKEN_AMOUNT+''),
            [
                '0x985458e523db3d53125813ed68c274899e9dfab4',
                '0xe176ebe47d621b984a73036b9da5d834411ef734',
                '0x3c2b8be99c50593081eaa2a724f0b8285f5aba8f'
            ],
            getBigNumber(process.env.PRESALETOKEN_AMOUNT+''),
        ],
    });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});