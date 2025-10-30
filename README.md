# 🎨 Community-Designed Drops DAO

A decentralized autonomous organization where fans and designers collaborate to co-create NFT collections, with automatic royalty distribution based on community contribution votes.

## 🚀 Features

- **🏛️ DAO Membership**: Join the community and build reputation through participation
- **🎭 Collection Creation**: Designers can create new NFT collections with custom royalty rates
- **✨ Contribution System**: Community members submit creative contributions to collections
- **🗳️ Weighted Voting**: Vote on contributions with reputation-based vote weights
- **💰 Automatic Royalties**: Transparent distribution based on contribution vote weights
- **📊 Reputation System**: Build reputation through active participation and quality contributions

## 📋 Contract Functions

### Public Functions

#### DAO Management
- `join-dao()` - Join the DAO as a member (starts with 10 reputation points)
- `get-member-reputation(member)` - Check a member's reputation score
- `is-dao-member(member)` - Verify DAO membership status

#### Collection Management  
- `create-collection(name, description, royalty-rate)` - Create a new NFT collection
- `get-collection(collection-id)` - Retrieve collection details
- `record-sale(collection-id, sale-amount)` - Record sales and distribute royalties

#### Contribution System
- `submit-contribution(collection-id, description)` - Submit creative contribution to a collection
- `vote-contribution(contribution-id)` - Vote for a contribution (increases reputation)
- `get-contribution(contribution-id)` - Get contribution details
- `get-collection-contributions(collection-id)` - List all contributions for a collection

#### Voting Periods
- `start-voting-period(collection-id)` - Start voting period for a collection (144 blocks minimum)
- `end-voting-period(collection-id)` - End voting and calculate final royalty shares
- `get-voting-period(collection-id)` - Check voting period status

### Read-Only Functions

- `get-royalty-share(collection-id, contributor)` - View contributor's royalty share
- `get-dao-treasury()` - Check total treasury balance
- `has-voted(contribution-id, voter)` - Check if member has voted on contribution

## 🎯 Usage Example

### 1. Join the DAO
```clarity
(contract-call? .community-designed-drops join-dao)
```

### 2. Create a Collection
```clarity
(contract-call? .community-designed-drops create-collection 
    "Cyber Cats" 
    "Futuristic feline NFT collection" 
    u500) ;; 5% royalty rate
```

### 3. Submit Contributions
```clarity
(contract-call? .community-designed-drops submit-contribution 
    u1 ;; collection-id
    "Neon pink cyberpunk cat with laser eyes")
```

### 4. Vote on Contributions
```clarity
(contract-call? .community-designed-drops vote-contribution u1)
```

### 5. Manage Voting
```clarity
;; Start voting period
(contract-call? .community-designed-drops start-voting-period u1)

;; End voting (after 144+ blocks)
(contract-call? .community-designed-drops end-voting-period u1)
```

### 6. Record Sales
```clarity
(contract-call? .community-designed-drops record-sale u1 u1000000) ;; 1 STX sale
```

## 🔧 Technical Details

### Constants
- `MIN-VOTING-PERIOD`: 144 blocks (minimum voting duration)
- `ROYALTY-BASIS-POINTS`: 1000 (for percentage calculations)

### Error Codes
- `u100`: Not authorized
- `u101`: Already a member
- `u102`: Not a member
- `u103`: Collection not found
- `u104`: Already voted
- `u105`: Invalid amount
- `u106`: Insufficient balance
- `u107`: Contribution not found
- `u108`: Voting period ended
- `u109`: Voting period still active

### Data Structures

#### Collections
```clarity
{
    creator: principal,
    name: (string-ascii 64),
    description: (string-ascii 256),
    total-sales: uint,
    royalty-rate: uint,
    created-at: uint,
    is-active: bool
}
```

#### Contributions
```clarity
{
    collection-id: uint,
    contributor: principal,
    description: (string-ascii 256),
    votes: uint,
    vote-weight: uint,
    created-at: uint
}
```

## 🌟 Key Benefits

1. **🤝 Collaborative Creation**: Fans and designers work together on collections
2. **⚖️ Fair Distribution**: Royalties distributed based on community votes
3. **🏆 Reputation System**: Active contributors build influence over time
4. **🔄 Transparent Process**: All votes and distributions are on-chain
5. **💎 Quality Control**: Community voting ensures high-quality contributions

## 🛠️ Development

### Prerequisites
- Clarinet CLI
- Stacks blockchain testnet access

### Testing
```bash
clarinet check
clarinet test
```

### Deployment
```bash
clarinet deploy --network testnet
```

## 📜 License

This project is open source and available under the MIT License.

---

*Built with ❤️ for the Stacks ecosystem*
