# 🔒 Escrow Smart Contract

A secure escrow system built on the Stacks blockchain using Clarity smart contracts. This MVP enables safe transactions between buyers and sellers with built-in dispute resolution mechanisms.

## 🚀 Features

- **💰 Secure Fund Holding**: Buyer deposits funds into the contract
- **📦 Delivery Confirmation**: Seller can mark items as delivered
- **✅ Fund Release**: Buyer can release funds to seller upon satisfaction
- **⚖️ Dispute Resolution**: Third-party arbitrator can resolve conflicts
- **⏰ Automatic Expiration**: Funds automatically refund to buyer after expiration
- **🔄 Cancellation Support**: Both parties can cancel pending escrows
- **📊 Transaction History**: Track all escrow transactions and states
- **💼 Dynamic Fee Collection**: Platform automatically collects configurable fees from completed transactions

## 🏗️ Contract Architecture

### States
- `pending` - Initial state after escrow creation
- `delivered` - Seller has confirmed delivery
- `completed` - Funds released to seller
- `disputed` - Buyer has raised a dispute
- `refunded` - Funds returned to buyer via dispute resolution
- `cancelled` - Escrow cancelled by mutual agreement
- `expired-refunded` - Automatic refund due to expiration

### Key Functions

#### 🛒 For Buyers
- `create-escrow` - Create new escrow with funds
- `release-funds` - Release funds to seller
- `dispute-escrow` - Raise a dispute
- `cancel-escrow` - Cancel pending escrow

#### 📤 For Sellers
- `confirm-delivery` - Mark item as delivered
- `cancel-escrow` - Cancel pending escrow

#### ⚖️ For Arbitrators
- `resolve-dispute` - Resolve disputes in favor of buyer or seller

#### 💼 For Platform Owner
- `update-platform-fee` - Adjust fee rate (max 10%)
- `withdraw-collected-fees` - Withdraw accumulated platform fees

#### 🔍 Read-Only Functions
- `get-escrow-details` - Get complete escrow information
- `get-escrow-state` - Get current escrow state
- `get-escrows-by-buyer` - List buyer's escrows
- `get-escrows-by-seller` - List seller's escrows
- `get-platform-fee-rate` - Check current fee percentage
- `get-collected-fees` - View total accumulated fees
- `preview-fee` - Calculate fees before creating escrow

## 🛠️ Setup and Usage

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone this repository:
```bash
git clone <your-repo-url>
cd Escrow-Smart-Contract
```

2. Initialize Clarinet (if not already done):
```bash
clarinet new .
```

3. Check contract syntax:
```bash
clarinet check
```

4. Run tests:
```bash
clarinet test
```

### 📝 Usage Examples

#### Creating an Escrow
```clarity
(contract-call? .escrow-smart-contract create-escrow
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; seller
  'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE  ;; arbitrator
  u1000000                                        ;; amount (1 STX)
  u144                                           ;; duration (144 blocks)
  "Digital Art NFT"                              ;; title
  "Custom digital artwork commission"            ;; description
)
```

#### Confirming Delivery (Seller)
```clarity
(contract-call? .escrow-smart-contract confirm-delivery u1)
```

#### Releasing Funds (Buyer)
```clarity
(contract-call? .escrow-smart-contract release-funds u1)
```

#### Disputing Transaction (Buyer)
```clarity
(contract-call? .escrow-smart-contract dispute-escrow u1)
```

#### Resolving Dispute (Arbitrator)
```clarity
(contract-call? .escrow-smart-contract resolve-dispute u1 true) ;; true = release to seller
```

#### Managing Platform Fees (Owner)
```clarity
;; Update fee rate to 3% (300 basis points)
(contract-call? .escrow-smart-contract update-platform-fee u300)

;; Withdraw collected fees
(contract-call? .escrow-smart-contract withdraw-collected-fees)

;; Preview fees before creating escrow
(contract-call? .escrow-smart-contract preview-fee u1000000) ;; Check fees for 1 STX
```

## 🧪 Testing

Run the test suite to verify contract functionality:

```bash
clarinet test
```

The tests cover:
- ✅ Escrow creation and fund locking
- ✅ Delivery confirmation workflow
- ✅ Fund release mechanisms
- ✅ Dispute resolution process
- ✅ Expiration and refund logic
- ✅ Authorization checks
- ✅ Edge cases and error handling

## 🔐 Security Features

- **Authorization Checks**: Only authorized parties can perform actions
- **State Validation**: Prevents invalid state transitions
- **Fund Safety**: Funds are securely locked in the contract
- **Expiration Protection**: Automatic refunds prevent stuck funds
- **Dispute Resolution**: Third-party arbitration for conflict resolution

## 📋 Error Codes

- `u100` - Not authorized
- `u101` - Escrow not found
- `u102` - Invalid state transition
- `u103` - Insufficient funds
- `u104` - Escrow expired
- `u105` - Escrow not yet expired
- `u106` - Funds already released
- `u107` - Funds already refunded
- `u108` - Invalid fee rate (exceeds 10%)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run `clarinet check` and `clarinet test`
6. Submit a pull request

## 📜 License

This project is open source and available under the MIT License.

## 🙋‍♂️ Support

For questions or issues, please open a GitHub issue or contact the development team.

---

*Built with ❤️ on Stacks blockchain using Clarity smart contracts*
