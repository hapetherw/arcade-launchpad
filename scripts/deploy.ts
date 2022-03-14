import { ethers } from "hardhat";
import * as dotenv from "dotenv";
import { save } from "./utils"

dotenv.config();
import { getBigNumber } from '../test/utils'

async function main() {
  const TokenFactory = await ethers.getContractFactory("Token");
  const LoopTokenFactory = await ethers.getContractFactory("LoopToken")
  const tokenContract = await LoopTokenFactory.deploy();
  console.log('LoopContract address:', tokenContract.address);
  console.log('LoopContract hash:', tokenContract.deployTransaction.hash);
  await tokenContract.deployed();

  await save('loopContract', {
    address: tokenContract.address
  });

  const presaleContractFactory = await ethers.getContractFactory("Presale");
  const presaleContract = await presaleContractFactory.deploy(
    tokenContract.address,
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
    );
  console.log('presaleContract address:', presaleContract.address);
  console.log('presaleContract hash:', presaleContract.deployTransaction.hash);
  await presaleContract.deployed();

  await save('presaleContract', {
    address: presaleContract.address
  });
}
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });