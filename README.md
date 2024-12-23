# SkillForge: Decentralized Talent Marketplace

## Overview

SkillForge is a decentralized talent marketplace built on the Stacks blockchain, enabling secure and transparent collaboration between talent providers and requesters. The platform facilitates milestone-based project management, secure payments, and dispute resolution through smart contracts.

## Key Features

### 🔒 Secure Collateral System
- Providers must lock STX tokens as collateral
- Minimum collateral requirements vary by domain
- Time-locked withdrawal mechanism

### 💫 Advanced Task Management
- Phased project completion
- Up to 10 phases per task
- Detailed scope and timeline tracking
- Domain-specific categorization

### 💰 Financial Features
- Platform fee: 2.5%
- Automated payment distribution
- Phase-based reward release
- Protected escrow system

### ⚖️ Dispute Resolution
- Dedicated mediation system
- Proof submission mechanism
- Transparent arbitration process

## Technical Specifications

### Constants
```clarity
LOCK-PERIOD: 1440 blocks (~10 days)
MAX-PHASES: 10
MAX-TIMELINE: 14400 blocks (~100 days)
MIN-COLLATERAL: 1,000,000 micro-STX
PLATFORM-RATE: 2.5%
```

### Data Structures
- Tasks: Main project container
- Phases: Milestone tracking
- ExpertiseScores: Provider reputation
- Domains: Service categories
- ProviderCollateral: Stake management
- MediationProof: Dispute evidence

## Core Functions

### For Providers
```clarity
(lock-collateral (amount uint))
(release-collateral)
```

### For Requesters
```clarity
(forge-task (provider principal) (total-reward uint) ...)
(add-phase (task-id uint) (scope string-ascii) ...)
(complete-phase (task-id uint) (phase-id uint))
```

### For Domain Management
```clarity
(create-domain (title string-ascii) ...)
```

### For Dispute Resolution
```clarity
(submit-mediation-proof (task-id uint) (proof-hash buff))
```

## Read Operations
```clarity
(view-task (task-id uint))
(view-phase (task-id uint) (phase-id uint))
(view-expertise (expert principal))
(view-provider-stats (provider principal))
(view-domain (domain-id uint))
```

## Error Codes
- ERR-UNAUTHORIZED (u1)
- ERR-INVALID-TASK (u2)
- ERR-LOW-BALANCE (u3)
[See contract for complete list]

## Getting Started

1. Deploy contract to Stacks blockchain
2. Initialize service domains
3. Providers lock required collateral
4. Requesters can begin creating tasks

## Security Notes

- Funds are secured through smart contract escrow
- Time-locked collateral system
- Multiple validation checks
- Phase-based fund release
- Mediation system for disputes

## Best Practices

### For Providers
- Maintain adequate collateral
- Complete phases within timeline
- Document work progress
- Retain proof of delivery

### For Requesters
- Clear scope definition
- Reasonable phase distribution
- Timely phase completion
- Regular communication

## Contributing

Contributions are welcome! Please follow these steps:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request
