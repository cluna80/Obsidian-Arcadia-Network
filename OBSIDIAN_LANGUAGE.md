# í¼‘ OBSIDIAN Language Reference

**Obsidian Behavioral Scripting Language - The Language of Autonomous Intelligence**

Version: 1.0.0 | File Extension: `.obs` or `.ent`

## Quick Reference

### Basic Structure
```obsidian
ENTITY <name>
TYPE <type>
STATE <state>
ENERGY <number>
REPUTATION <number>

BEHAVIOR
  IF <condition> THEN <action>
END

EXECUTE
  IF <condition> THEN <tool>
END

INTENT "<description>"
MODE <mode>
```

## Core Keywords

- `ENTITY` - Entity name (required)
- `STATE` - Initial state (required)
- `ENERGY` - Energy level 0-1000 (required)
- `REPUTATION` - Score -100 to 1000 (required)
- `TYPE` - Entity classification (optional)
- `BEHAVIOR/END` - Behavioral rules block
- `EXECUTE/END` - Tool execution block
- `IF/THEN` - Conditional logic
- `INTENT` - Purpose description
- `MODE` - Execution mode
- `BIND` - Attach tools

## Operators

- `==` Equal | `!=` Not equal
- `>` Greater | `<` Less
- `>=` Greater/equal | `<=` Less/equal
- `AND` Logical AND | `OR` Logical OR

## Example
```obsidian
ENTITY TradingBot
TYPE Trader
STATE Active
ENERGY 100
REPUTATION 0

BEHAVIOR
  IF ENERGY < 30 THEN STATE Recovery
  IF REPUTATION > 50 THEN STATE Elite
  IF STATE == Recovery THEN ENERGY + 15
END

EXECUTE
  IF STATE == Active THEN MarketAnalyzer
  IF STATE == Elite THEN AdvancedTrader
  IF STATE == Recovery THEN Monitor
END

INTENT "Execute profitable trades"
MODE Production
```

## States

Common states: `Active`, `Recovery`, `Elite`, `Emergency`, `Idle`, `Overclocked`

## Best Practices

1. Always restore energy: `IF STATE == Recovery THEN ENERGY + 15`
2. Progressive unlocking: Use reputation thresholds
3. Avoid oscillation: Add hysteresis to conditions
4. Clear naming: Use descriptive entity and tool names

For complete reference with 13 examples, visit:
https://github.com/cluna80/Obsidian-Arcadia-Network
