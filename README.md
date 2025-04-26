# SalePhasedToken

A smart contract for managing a phased token sale with multiple price tiers and time-based phases.

## Features

- **Phased Token Sale**: Multiple sale phases with different token prices
- **Time-Based Phases**: Each phase has configurable start and end times
- **Purchase Limits**: Minimum and maximum purchase amounts per user
- **Automatic Refunds**: Excess USDT is automatically refunded
- **Emergency Controls**: Pausable functionality and emergency withdraw
- **Upgradeable**: UUPS upgradeable contract pattern
- **Security Features**: 
  - Purchase amount limits
  - Phase timing controls
  - Emergency pause functionality
  - Owner-only administrative functions

## Contract Details

### Phases
The sale consists of 6 phases with the following token limits and prices:
1. 35M tokens at $0.35
2. 42.5M tokens at $0.40
3. 21.25M tokens at $0.45
4. 21.25M tokens at $0.50
5. 60M tokens at $0.55
6. 60M tokens at $0.60

### Technical Specifications
- Total Supply: 240M tokens
- Decimals: 18
- Token Standard: ERC20
- Payment Token: USDT (6 decimals)

## Prerequisites

- Node.js (v16 or later)
- npm or yarn
- Hardhat
- USDT token address on the target network

## Installation

1. Clone the repository
```bash
git clone <repository-url>
cd <repository-name>
```

2. Install dependencies
```bash
npm install
```

3. Create a `.env` file with the following variables:
```env
USDT_ADDRESS=0x...  # USDT token address
TREASURY_ADDRESS=0x...  # Treasury address for receiving USDT
```

## Deployment

1. Compile the contracts
```bash
npx hardhat compile
```

2. Deploy the contract
```bash
npx hardhat run scripts/deploySalePhasedToken.ts --network <network-name>
```

## Usage

### Buying Tokens
Users can buy tokens by calling the `buy` function with their desired USDT amount:
```solidity
function buy(uint256 usdtAmount) external
```

### Administrative Functions
Owner-only functions:
```solidity
function setPhaseTime(uint256 phaseIndex, uint256 startTime, uint256 endTime) external
function mintTo(address recipient, uint256 amount) external
function emergencyWithdraw(address token, uint256 amount) external
function pause() external
function unpause() external
```

### View Functions
```solidity
function getTokensSoldInPhase(uint256 phaseIndex) public view returns (uint256)
function getPhaseEnd(uint256 phaseIndex) public view returns (uint256)
```

## Security Considerations

1. **Access Control**: 
   - Administrative functions are restricted to the owner
   - Emergency functions are available for crisis situations

2. **Purchase Limits**:
   - Minimum purchase amount prevents dust attacks
   - Maximum purchase amount prevents whale dominance

3. **Phase Controls**:
   - Time-based phase transitions
   - Token limit per phase
   - Automatic phase advancement

4. **Emergency Features**:
   - Contract can be paused
   - Funds can be emergency withdrawn
   - Upgradeable for future improvements

## Testing

Run the test suite:
```bash
npx hardhat test
```

## License

MIT License
# presale
