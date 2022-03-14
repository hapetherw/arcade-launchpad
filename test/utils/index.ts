import { parseUnits } from 'ethers/lib/utils'
const { BigNumber } = require('ethers')

export const BASE_TEN = 10
export const ADDRESS_ZERO = '0x0000000000000000000000000000000000000000'

// Defaults to e18 using amount * 10^18
export function getBigNumber(amount:number | string, decimals = 18) {
  return parseUnits(amount.toString(), decimals);
}

export * from './utils'
export * from './time'