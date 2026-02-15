# í³– Examples - Obsidian Arcadia Network

## Simple Entity
```obsidian
ENTITY SimpleBot
STATE Active
ENERGY 100
REPUTATION 0
BIND DataCollector
INTENT "Collect data"
```

## Self-Regulating Entity
```obsidian
ENTITY AdaptiveBot
STATE Active
ENERGY 100
REPUTATION 0

BEHAVIOR
  IF ENERGY < 30 THEN STATE Recovery
  IF REPUTATION > 10 THEN STATE Elite
  IF STATE == Recovery THEN ENERGY + 15
END

EXECUTE
  IF STATE == Active THEN StandardTool
  IF STATE == Elite THEN AdvancedTool
  IF STATE == Recovery THEN Monitor
END

INTENT "Adapt and optimize"
```

## Trading Bot
```obsidian
ENTITY TradingBot
TYPE Trader
STATE Conservative
ENERGY 100
REPUTATION 0

BEHAVIOR
  IF REPUTATION > 50 THEN STATE Aggressive
  IF REPUTATION < -10 THEN STATE VeryConservative
  IF ENERGY < 20 THEN STATE Paused
  IF STATE == Paused THEN ENERGY + 25
END

EXECUTE
  IF STATE == Conservative THEN MarketAnalyzer
  IF STATE == Aggressive THEN HighFrequencyTrader
  IF STATE == VeryConservative THEN RiskAnalyzer
  IF STATE == Paused THEN Monitor
END

INTENT "Execute profitable trades"
MODE Production
TOKENIZED True
```

## Research Agent
```obsidian
ENTITY ResearchAgent
TYPE Researcher
STATE Active
ENERGY 100
REPUTATION 0

BEHAVIOR
  IF REPUTATION > 10 THEN STATE Experienced
  IF REPUTATION > 30 THEN STATE Expert
  IF ENERGY < 20 THEN STATE Resting
  IF STATE == Resting THEN ENERGY + 15
END

EXECUTE
  IF STATE == Active THEN WebScraper
  IF STATE == Active THEN DataExtractor
  IF STATE == Experienced THEN DeepAnalyzer
  IF STATE == Expert THEN AIResearcher
  IF STATE == Resting THEN LiteratureReader
END

INTENT "Conduct research"
MODE Production
```

## Multi-Entity Network

**coordinator.obs:**
```obsidian
ENTITY Coordinator
TYPE Coordinator
STATE Active
ENERGY 100
REPUTATION 0

EXECUTE
  IF STATE == Active THEN TaskDistributor
END

INTENT "Coordinate workers"
```

**worker.obs:**
```obsidian
ENTITY Worker
TYPE Worker
STATE Active
ENERGY 100
REPUTATION 0

BEHAVIOR
  IF ENERGY < 30 THEN STATE Recovery
  IF STATE == Recovery THEN ENERGY + 15
END

EXECUTE
  IF STATE == Active THEN TaskExecutor
  IF STATE == Recovery THEN StatusReporter
END

INTENT "Execute tasks"
```

**Usage:**
```python
import oan

entities = oan.execute_multi_entity([
    "coordinator.obs",
    "worker.obs",
    "worker.obs"
], cycles=10)
```

## More Examples

See complete examples with communication and coordination at:
https://github.com/cluna80/Obsidian-Arcadia-Network/tree/master/examples
