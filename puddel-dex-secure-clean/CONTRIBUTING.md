# 🤝 Contributing to PuddelSwap

We welcome contributions from the community! This guide will help you understand our development process and how to contribute effectively.

## 🌟 Ways to Contribute

- **🐛 Bug Reports**: Found an issue? Let us know!
- **💡 Feature Requests**: Have ideas for improvements?
- **🔧 Code Contributions**: Submit pull requests
- **📚 Documentation**: Improve our docs
- **🛡️ Security**: Report vulnerabilities responsibly
- **🧪 Testing**: Help expand our test coverage

## 🚀 Getting Started

### Prerequisites
- Node.js 18+ and npm
- Git familiarity
- Basic understanding of Solidity and TypeScript
- Avalanche development knowledge helpful

### Development Setup
```bash
# Fork and clone the repository
git clone https://github.com/YOUR_USERNAME/puddel-dex-secure-clean.git
cd puddel-dex-secure-clean

# Install dependencies
npm install

# Run tests to ensure setup works
npm test

# Start local development network
npx hardhat node

# In another terminal, deploy contracts locally
npx hardhat run scripts/deploy-production-secure.js --network localhost
```

## 📋 Development Guidelines

### Code Standards

#### Solidity
- Follow [OpenZeppelin style guide](https://docs.openzeppelin.com/contracts/4.x/style-guide)
- Use latest stable compiler version (0.8.19+)
- Include comprehensive NatSpec documentation
- Implement proper access controls
- Add reentrancy protection where needed

```solidity
// ✅ Good: Proper function documentation
/**
 * @notice Swaps tokens through optimal routing
 * @param amountIn Amount of input tokens
 * @param path Array of token addresses for swap route
 * @return amounts Array of output amounts for each step
 */
function swapExactTokensForTokens(
    uint256 amountIn,
    address[] calldata path
) external returns (uint256[] memory amounts);
```

#### TypeScript/JavaScript
- Use strict TypeScript configuration
- Follow [Airbnb style guide](https://github.com/airbnb/javascript)
- Write comprehensive JSDoc comments
- Implement proper error handling
- Use meaningful variable names

```typescript
// ✅ Good: Type-safe contract interaction
interface SwapParams {
  tokenIn: string;
  tokenOut: string;
  amountIn: BigNumber;
  slippage: number;
}

async function executeSwap(params: SwapParams): Promise<TransactionResponse> {
  // Implementation with proper error handling
}
```

### Testing Requirements

#### Smart Contract Tests
- Minimum 95% code coverage required
- Test all edge cases and error conditions
- Include integration tests
- Test security assumptions

```javascript
// ✅ Good: Comprehensive test structure
describe("PuddelRouter", () => {
  describe("swapExactTokensForTokens", () => {
    it("should swap tokens successfully", async () => {
      // Happy path test
    });
    
    it("should revert with insufficient input", async () => {
      // Error condition test
    });
    
    it("should handle maximum slippage", async () => {
      // Edge case test
    });
  });
});
```

#### Frontend Tests
- Unit tests for all components
- Integration tests for user flows
- E2E tests for critical paths
- Accessibility testing

### Security Standards

#### Pre-submission Checklist
- [ ] Run `npm run slither` (static analysis)
- [ ] Run `npm run test:security` (security tests)
- [ ] Check for reentrancy vulnerabilities
- [ ] Verify access control mechanisms
- [ ] Test input validation thoroughly
- [ ] Review for arithmetic overflows/underflows

#### Security Review Process
1. **Self-review**: Check your code thoroughly
2. **Automated tools**: Run all security scanners
3. **Peer review**: Get feedback from other developers
4. **Security team**: Major changes reviewed by security experts

## 🔄 Pull Request Process

### Before Submitting
1. **Create an issue** describing the problem/feature
2. **Fork the repository** and create a feature branch
3. **Make your changes** following our guidelines
4. **Add/update tests** for your changes
5. **Run all checks** locally

```bash
# Run the full test suite
npm run test:all

# Run security analysis
npm run audit

# Check code formatting
npm run lint

# Build the project
npm run build
```

### PR Requirements
- **Clear title**: Describe what the PR does
- **Detailed description**: Explain the changes and why
- **Link issues**: Reference related issues
- **Test evidence**: Show tests pass and coverage maintained
- **Breaking changes**: Clearly document any breaking changes

### PR Template
```markdown
## Description
Brief description of changes and their purpose.

## Type of Change
- [ ] Bug fix (non-breaking change)
- [ ] New feature (non-breaking change)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work)
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Security tests pass
- [ ] Manual testing completed

## Security Review
- [ ] No new security vulnerabilities introduced
- [ ] Access controls properly implemented
- [ ] Input validation added where needed
- [ ] Reentrancy protection considered

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Tests added for new functionality
- [ ] Documentation updated
- [ ] No merge conflicts
```

## 🐛 Reporting Bugs

### Bug Report Template
```markdown
## Bug Description
Clear description of what the bug is.

## To Reproduce
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

## Expected Behavior
What you expected to happen.

## Screenshots
If applicable, add screenshots.

## Environment
- Browser: [e.g., Chrome, Firefox]
- Wallet: [e.g., MetaMask, WalletConnect]
- Network: [e.g., Fuji, Mainnet]
- Device: [e.g., Desktop, Mobile]
```

## 💡 Feature Requests

### Feature Request Template
```markdown
## Feature Description
Clear description of the feature you'd like to see.

## Use Case
Explain why this feature would be valuable.

## Proposed Solution
Your ideas for how this could be implemented.

## Alternatives Considered
Other approaches you've thought about.

## Additional Context
Any other context, mockups, or examples.
```

## 🛡️ Security Vulnerabilities

### Responsible Disclosure
If you discover a security vulnerability:

1. **DO NOT** open a public issue
2. **Email us privately**: security@puddelswap.com
3. **Include details**: Steps to reproduce, impact assessment
4. **Wait for response**: We'll respond within 48 hours
5. **Coordinate disclosure**: We'll work together on timing

### Security Bounty Program
We're planning a bug bounty program with rewards for:
- **Critical**: $1,000 - $5,000
- **High**: $500 - $1,000  
- **Medium**: $100 - $500
- **Low**: $50 - $100

## 👥 Community

### Communication Channels
- **GitHub Discussions**: Design discussions and feature requests
- **GitHub Issues**: Bug reports and technical support
- **Email**: Direct communication for sensitive matters

### Code of Conduct
We follow the [Contributor Covenant](https://www.contributor-covenant.org/):
- **Be respectful**: Treat everyone with respect
- **Be inclusive**: Welcome diverse perspectives
- **Be constructive**: Focus on improving the project
- **Be patient**: Understand that review takes time

## 📚 Resources

### Learning Resources
- [Solidity Documentation](https://docs.soliditylang.org/)
- [Hardhat Tutorial](https://hardhat.org/tutorial/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Uniswap V2 Core](https://docs.uniswap.org/protocol/V2/introduction)

### Development Tools
- **Hardhat**: Smart contract development environment
- **Slither**: Static analysis for security
- **Mythril**: Symbolic execution analysis
- **OpenZeppelin**: Security-focused contract library

## 🎉 Recognition

### Contributors
We recognize all contributors in our documentation and acknowledge significant contributions in our release notes.

### Maintainer Pathway
Outstanding contributors may be invited to become maintainers with additional responsibilities and privileges.

---

## ❓ Questions?

If you have questions about contributing:
- Check existing [GitHub Discussions](../../discussions)
- Open a new discussion for general questions
- Email us at dev@puddelswap.com for specific inquiries

Thank you for helping make PuddelSwap better! 🚀