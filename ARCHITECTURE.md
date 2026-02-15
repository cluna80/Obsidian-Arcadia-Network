# ���️ Architecture - Obsidian Arcadia Network

## System Overview
```
┌─────────────────────────────────────┐
│    LAYER 1: CORE ENGINE (v1.0.0)   │
│                                     │
│  • OBSIDIAN DSL Parser              │
│  • Behavioral Intelligence Engine   │
│  • Multi-Entity Coordinator         │
│  • Communication Hub                │
│  • Coordination Primitives          │
│  • Cyberpunk Dashboard              │
└─────────────────────────────────────┘
          ↓
┌─────────────────────────────────────┐
│   LAYER 2: WEB3 (v2.0.0 - Planned) │
│                                     │
│  • NFT Entities (ERC-721)           │
│  • On-Chain State Storage           │
│  • Smart Contracts                  │
│  • DAO Governance                   │
└─────────────────────────────────────┘
```

## Core Components

### 1. Parser (`parser.py`)
- Parses OBSIDIAN DSL files
- Validates syntax
- Creates Entity objects

### 2. Entity (`entity.py`)
- Core data structure
- State management
- Behavior application

### 3. Executor (`executor.py`)
- Execution engine
- Cycle management
- Tool execution

### 4. Behavioral Intelligence (`behavior.py`)
- Condition evaluation
- Rule execution
- State transitions

### 5. Entity Manager (`entity_manager.py`)
- Network management
- Parent-child relationships
- Hierarchy tracking

### 6. Communication Hub (`communication.py`)
- Broadcast messages
- Direct messaging
- Pub/sub channels

### 7. Coordination Hub (`coordination.py`)
- Synchronization
- Dependency tracking
- Result aggregation

## Data Flow
```
.obs file → Parser → Entity → Executor → Results
                                ↓
                         EntityManager
                                ↓
                    Communication/Coordination
```

## Performance

- **Execution**: 180+ cycles/second
- **Memory**: ~1KB per entity
- **Scalability**: 100+ entities tested

## Extension Points

- Add custom tools in `tools/`
- Add custom behaviors in DSL
- Extend parser for new keywords
- Add new coordination patterns

## Future Architecture (Layer 2)
```
Smart Contracts
    ↓
NFT Entities
    ↓
On-Chain State
    ↓
DAO Governance
```

For detailed technical documentation, see repository.
