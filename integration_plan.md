# LangGraph Integration Plan

## Backend Integration (FastAPI)

### New Endpoint: `/cognitive/decision`
```python
@app.post("/cognitive/decision")
async def cognitive_decision(data: CognitiveRequest):
    """
    Use LangGraph cognitive engine for entity decisions
    
    Input: entity state + market state
    Output: reasoned decision with explanation
    """
    from oan_ai.cognitive_engine import run_cognitive_cycle
    result = run_cognitive_cycle(json.dumps(data.dict()))
    return json.loads(result)
```

### Enhanced Trading Agent Node
- Add "Use AI Brain" toggle
- When enabled, calls `/cognitive/decision` endpoint
- Shows AI reasoning in tooltip
- Displays emotion state indicator

### New Demo: "Cognitive Trading"
- Template with AI-powered trading agents
- Real-time emotion visualization
- Energy bars on nodes
- Strategy mutation controls

## Files to Modify

1. **backend/api.py**
   - Import oan_ai modules
   - Add cognitive decision endpoint
   - Add emotion update endpoint
   - Add strategy evolution endpoint

2. **src/components/nodes/TradingAgentNode.tsx**
   - Add "AI Brain" toggle
   - Show emotion indicator
   - Display energy bar
   - Show reasoning tooltip

3. **src/templates/cognitiveDemo.ts**
   - New template with AI agents
   - Pre-configured with emotions
   - Energy visualization

4. **src/services/cognitiveApi.ts**
   - API client for cognitive endpoints
   - Emotion management
   - Strategy evolution calls

## Demo Flow

1. Load "Cognitive Trading" template
2. Entities start with different emotions
3. Click "Run Sim" → AI reasoning happens
4. Watch emotions change based on P/L
5. See energy bars deplete/regenerate
6. Strategies evolve over time
7. Chat with agents about their decisions
