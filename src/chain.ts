import { createPublicClient, createWalletClient, custom, http, isAddress, parseAbi, BaseError, ContractFunctionRevertedError, type Address, type ContractFunctionName, type ContractFunctionArgs, type EIP1193Provider } from 'viem'
import { sepolia } from 'viem/chains'

export const abi = parseAbi([
  'struct Batch { string productName; uint64 harvestedAt; string origin; string certification; address farmer; address custodian; address pendingRecipient; uint8 stage; bool recalled; string recallReason; }',
  'struct HistoryEntry { uint8 action; uint64 timestamp; address actor; address counterparty; uint8 stage; string note; }',
  'function administrator() view returns (address)',
  'function roles(address account) view returns (uint8)',
  'function getBatch(string batchId) view returns (Batch)',
  'function getHistoryCount(string batchId) view returns (uint256)',
  'function getHistoryEntry(string batchId, uint256 index) view returns (HistoryEntry)',
  'function setStakeholder(address account, uint8 role)',
  'function registerBatch(string batchId, string productName, uint64 harvestedAt, string origin, string certification)',
  'function offerHandover(string batchId, address recipient)',
  'function acceptHandover(string batchId)',
  'function cancelHandover(string batchId)',
  'function updateStage(string batchId, uint8 newStage, string note)',
  'function recordInspection(string batchId, bool passed, string note)',
  'function reportIssue(string batchId, string reason)',
  'function recallBatch(string batchId, string reason)',
  'function resolveRecall(string batchId, string resolution)',
])

const configuredAddress = import.meta.env.VITE_CONTRACT_ADDRESS?.trim() ?? ''
const apiKey = import.meta.env.VITE_INFURA_API_KEY?.trim() ?? ''
export const live = isAddress(configuredAddress) && Boolean(apiKey)
const client = createPublicClient({
  chain: sepolia,
  transport: http(`https://sepolia.infura.io/v3/${apiKey}`),
})
const contract = { abi, address: configuredAddress as Address }
export const explorer = sepolia.blockExplorers.default.url

type BrowserWallet = EIP1193Provider & {
  removeListener: EIP1193Provider['removeListener']
}

export function provider() {
  return (window as Window & { ethereum?: BrowserWallet }).ethereum
}

export const readBatch = (id: string) => client.readContract({ ...contract, functionName: 'getBatch', args: [id] })
export const readCount = (id: string) => client.readContract({ ...contract, functionName: 'getHistoryCount', args: [id] })
export const readHistory = (id: string, index: bigint) => client.readContract({ ...contract, functionName: 'getHistoryEntry', args: [id, index] })
export const readRole = (account: Address) => client.readContract({ ...contract, functionName: 'roles', args: [account] })
export const readAdmin = () => client.readContract({ ...contract, functionName: 'administrator' })

export type Batch = Awaited<ReturnType<typeof readBatch>>
export type Entry = Awaited<ReturnType<typeof readHistory>>
type WriteName = ContractFunctionName<typeof abi, 'nonpayable'>
export type ActionCall = {
  [Name in WriteName]: {
    functionName: Name
    args: ContractFunctionArgs<typeof abi, 'nonpayable', Name>
  }
}[WriteName]

export async function send(account: Address, call: ActionCall, onSubmitted: (hash: string) => void) {
  const injected = provider()
  if (!live || !injected) throw new Error('กรุณาตั้งค่า Sepolia และเชื่อม MetaMask')
  const wallet = createWalletClient({ chain: sepolia, transport: custom(injected) })
  const chainId = await wallet.getChainId()
  if (chainId !== sepolia.id) {
    try {
      await wallet.switchChain({ id: sepolia.id })
    } catch (error) {
      if (!(error instanceof BaseError) || !error.walk(cause => typeof cause === 'object' && cause !== null && 'code' in cause && cause.code === 4902)) throw error
      // Only prompt for an unknown chain, and use the chain's public RPC here.
      await wallet.addChain({ chain: sepolia })
      await wallet.switchChain({ id: sepolia.id })
    }
  }
  const parameters = { ...contract, ...call, account }
  await client.simulateContract<typeof abi, WriteName, ActionCall['args'], undefined, Address>(parameters)
  const hash = await wallet.writeContract<typeof abi, WriteName, ActionCall['args']>(parameters)
  onSubmitted(hash)
  const receipt = await client.waitForTransactionReceipt({ hash })
  if (receipt.status !== 'success') throw new Error('ธุรกรรมถูกย้อนกลับบนบล็อกเชน')
}

export function errorMessage(error: unknown) {
  if (error instanceof BaseError) {
    const revert = error.walk(cause => cause instanceof ContractFunctionRevertedError)
    if (revert instanceof ContractFunctionRevertedError && revert.reason === 'Batch not found') return 'ไม่พบ Batch ID นี้บนบล็อกเชน'
    return revert instanceof ContractFunctionRevertedError && revert.reason ? revert.reason : error.shortMessage
  }
  return error instanceof Error ? error.message : 'เกิดข้อผิดพลาด กรุณาลองอีกครั้ง'
}
