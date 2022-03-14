const { ethers } = require("hardhat")

const { BigNumber } = ethers

export async function advanceBlock() {
  return ethers.provider.send("evm_mine", [])
}

export async function advanceBlockTo(blockNumber:any) {
  for (let i = await ethers.provider.getBlockNumber(); i < blockNumber; i++) {
    await advanceBlock()
  }
}

export async function increase(value:any) {
  await ethers.provider.send("evm_increaseTime", [value.toNumber()])
  await advanceBlock()
}

export async function getLatestBlock() {
  const block = await ethers.provider.getBlock("latest")
  return block;
}

export async function advanceTimeAndBlock(time:any) {
  await advanceTime(time)
  await advanceBlock()
}

export async function advanceTime(time:number) {
  await ethers.provider.send("evm_increaseTime", [time])
}

export async function advanceBlockTimeStamp(time:number) {
  await ethers.provider.send("evm_setNextBlockTimestamp", [time])
}

export async function getSnapShot() {
  const snapshot = await ethers.provider.send("evm_snapshot")
  return snapshot;
}

export async function revertTime(snapshot:number) {
  const revertResult = await ethers.provider.send("evm_revert", snapshot)
  return revertResult;
}