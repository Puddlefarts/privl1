# Fuji Testnet Deployment Guide

## Pre-Deployment Checklist ✅

### 1. Environment Setup
- [ ] Node.js v18+ installed
- [ ] Hardhat configured
- [ ] MetaMask or wallet configured for Fuji testnet

### 2. Wallet Requirements
- [ ] Deployer wallet has at least 0.5 AVAX on Fuji testnet
- [ ] Private key securely stored in `.env` file
- [ ] Get testnet AVAX from: https://faucet.avax.network/

### 3. Environment Variables
Create a `.env` file with:
```env
PRIVATE_KEY=your_private_key_here
FUJI_RPC_URL=https://api.avax-test.network/ext/bc/C/rpc
SNOWTRACE_API_KEY=your_snowtrace_api_key
```

## Deployment Steps 🚀

### Step 1: Install Dependencies
```bash
npm install
```

### Step 2: Compile Contracts
```bash
npx hardhat compile
```

### Step 3: Run Tests
```bash
npx hardhat test
```

### Step 4: Deploy to Fuji
```bash
npx hardhat run scripts/deploy-fuji-testnet.js --network fuji
```

### Step 5: Verify Contracts (Optional)
```bash
npx hardhat verify --network fuji <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

## Post-Deployment Tasks 📝

### 1. Verify Deployment
- [ ] Check all contracts on Fuji Snowtrace
- [ ] Verify contract addresses in `deployment-fuji.json`
- [ ] Test basic contract interactions

### 2. Frontend Integration
- [ ] Contract addresses updated in `src/contracts/addresses.ts`
- [ ] Test wallet connections
- [ ] Test swap functionality
- [ ] Test liquidity provision

### 3. Initialize Liquidity
- [ ] Create initial PeL/AVAX pool
- [ ] Add initial liquidity
- [ ] Test swap functionality

## Contract Addresses (Will be populated after deployment)

| Contract | Address | Snowtrace |
|----------|---------|-----------|
| PuddelFactory | - | - |
| PuddelRouter | - | - |
| PUDDeL Token | - | - |
| VeNFT | - | - |
| Governance | - | - |
| Config | - | - |

## Testing on Fuji

### 1. Get Test Tokens
- Use Fuji faucet: https://faucet.avax.network/
- Request test AVAX

### 2. Test Core Functions
- [ ] Swap AVAX for PeL
- [ ] Add liquidity to pools
- [ ] Remove liquidity
- [ ] Create veNFT
- [ ] Vote on proposals

### 3. Monitor Transactions
- View on Snowtrace: https://testnet.snowtrace.io/

## Troubleshooting 🔧

### Common Issues

1. **Insufficient Gas**
   - Ensure you have at least 0.5 AVAX for deployment
   - Adjust gas settings in `hardhat.config.js`

2. **Transaction Timeout**
   - Increase timeout in network config
   - Check Fuji network status

3. **Contract Verification Failed**
   - Ensure correct Snowtrace API key
   - Check constructor arguments match

## Security Notes 🔒

- NEVER commit private keys to git
- Use hardware wallets for mainnet deployment
- Test thoroughly on Fuji before mainnet
- Get contracts audited before mainnet launch

## Next Steps

1. Complete testing on Fuji
2. Gather user feedback
3. Fix any issues found
4. Prepare for mainnet deployment
5. Get security audit
6. Launch on Avalanche mainnet

## Support

For issues or questions:
- GitHub Issues: [Create an issue](https://github.com/your-repo/issues)
- Discord: [Join our community](https://discord.gg/your-invite)