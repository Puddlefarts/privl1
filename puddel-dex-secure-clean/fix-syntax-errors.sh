#!/bin/bash

echo "Fixing syntax errors in TypeScript files..."

# Fix useLiquidity.ts
sed -i '350,356d' src/hooks/useLiquidity.ts
sed -i '349a\
              // Add liquidity AVAX parameters\
              const addLiquidityParams = {\
                routerAddress: getContractAddress(chainId, "PuddelRouter"),\
                tokenAddress: tokenAddress,\
                tokenAmount: tokenAmount.toString(),\
                tokenMin: tokenMin.toString(),\
                avaxMin: avaxMin.toString(),\
                to: address,\
                deadline: deadline\
              }' src/hooks/useLiquidity.ts

echo "Syntax errors fixed. Running build..."