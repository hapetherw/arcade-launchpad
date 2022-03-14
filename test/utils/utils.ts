import { Provider } from '@ethersproject/abstract-provider'
import { BigNumberish } from 'ethers'
import { formatUnits, parseUnits } from 'ethers/lib/utils'

export enum TOKEN_DECIMAL {
  USDC = 6,
  BUSD = 18,
  USDT = 6,
  LOOP = 18,
  DEFAULT = ''
}

export enum TOKEN_NAME {
  USDC = 'USDC',
  BUSD = 'BUSD',
  USDT = 'USDT',
  DEFAULT = ''
}

export const parseCurrency = (
  tokenName: TOKEN_NAME,
  tokenDecimal: TOKEN_DECIMAL,
  amountInEther: string
) => {
  let convertedValue

  switch (tokenName) {
    case TOKEN_NAME.USDC:
      convertedValue = parseUnits(amountInEther, TOKEN_DECIMAL.USDC)
      break
    case TOKEN_NAME.BUSD:
      convertedValue = parseUnits(amountInEther, TOKEN_DECIMAL.BUSD)
      break
    case TOKEN_NAME.USDT:
      convertedValue = parseUnits(amountInEther, TOKEN_DECIMAL.USDT)
      break
    default:
      convertedValue = parseUnits(amountInEther) // 18 decimals
      break
  }

  return convertedValue
}

export const formatCurrency = (
  tokenName: TOKEN_NAME,
  tokenDecimal: TOKEN_DECIMAL,
  amountInEther: BigNumberish
) => {
  let convertedValue

  switch (tokenName) {
    case TOKEN_NAME.USDC:
      convertedValue = formatUnits(amountInEther, TOKEN_DECIMAL.USDC)
      break
    case TOKEN_NAME.BUSD:
      convertedValue = formatUnits(amountInEther, TOKEN_DECIMAL.BUSD)
      break
    case TOKEN_NAME.USDT:
      convertedValue = formatUnits(amountInEther, TOKEN_DECIMAL.USDT)
      break
    default:
      convertedValue = formatUnits(amountInEther) // 18 decimals
      break
  }

  return convertedValue
}

export const getLatestBlockTime = async (
  provider: Provider
): Promise<number> => {
  const blockNumber = await provider.getBlockNumber()
  const block = await provider.getBlock(blockNumber)

  if (block) {
    return block.timestamp
  }

  return new Date().getTime()
}

export const getFutureTime = async (provider: Provider): Promise<number> => {
  const t = await getLatestBlockTime(provider)
  return t + 60
}
