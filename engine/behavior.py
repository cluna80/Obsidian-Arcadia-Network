"""
OAN Behavior System
Defines behavioral rules and actions for entities

Fix: Three-phase evaluation resolves competing rules cancelling each other.

  Phase 1 — evaluate non-STATE conditions (ENERGY, REPUTATION checks)
             execute their STATE/ENERGY/REPUTATION actions immediately
             in declaration order.

  Phase 2 — after all non-STATE-condition rules have fired and state
             has settled, evaluate STATE-condition rules (IF STATE == X).
             This guarantees ENERGY/REPUTATION side effects see the
             correct post-transition state.

  Phase 3 — execute any remaining ENERGY/REPUTATION actions from
             STATE-condition rules that fired in phase 2.

Result: IF ENERGY < 50 THEN STATE Recovery fires, then
        IF STATE == Recovery THEN ENERGY + 10 correctly sees Recovery.
"""


class Condition:
    """Represents a conditional expression (e.g., ENERGY < 30)"""
    
    VALID_OPERATORS = ['<', '>', '==', '!=', '<=', '>=']
    VALID_FIELDS = ['ENERGY', 'REPUTATION', 'STATE']
    
    def __init__(self, field, operator, value):
        self.field = field.upper()
        self.operator = operator
        self.value = value
        
        if self.field not in self.VALID_FIELDS:
            raise ValueError(f"Invalid field: {field}. Valid fields: {self.VALID_FIELDS}")
        if self.operator not in self.VALID_OPERATORS:
            raise ValueError(f"Invalid operator: {operator}. Valid operators: {self.VALID_OPERATORS}")
    
    @property
    def is_state_check(self):
        """True if this condition checks STATE field"""
        return self.field == 'STATE'
    
    def evaluate(self, entity):
        """Evaluate condition against an entity"""
        if self.field == 'ENERGY':
            field_value = entity.energy
        elif self.field == 'REPUTATION':
            field_value = entity.reputation
        elif self.field == 'STATE':
            field_value = entity.state
        else:
            return False
        
        if self.field == 'STATE':
            compare_value = str(self.value)
            field_value = str(field_value)
        else:
            try:
                compare_value = int(self.value)
            except (ValueError, TypeError):
                return False
        
        if self.operator == '<':
            return field_value < compare_value
        elif self.operator == '>':
            return field_value > compare_value
        elif self.operator == '==':
            return field_value == compare_value
        elif self.operator == '!=':
            return field_value != compare_value
        elif self.operator == '<=':
            return field_value <= compare_value
        elif self.operator == '>=':
            return field_value >= compare_value
        
        return False
    
    def __repr__(self):
        return f"Condition({self.field} {self.operator} {self.value})"


class Action:
    """Represents an action to take when a condition is met"""
    
    VALID_ACTION_TYPES = ['STATE', 'ENERGY', 'REPUTATION']
    VALID_OPERATIONS = ['+', '-', '=']
    
    def __init__(self, action_type, operation, value):
        self.action_type = action_type.upper()
        self.operation = operation
        self.value = value
        
        if self.action_type not in self.VALID_ACTION_TYPES:
            raise ValueError(f"Invalid action type: {action_type}")
        
        if self.action_type == 'STATE':
            self.operation = '='
        elif self.operation not in self.VALID_OPERATIONS:
            raise ValueError(f"Invalid operation: {operation}")
    
    def execute(self, entity):
        """Execute action on an entity"""
        old_value = None
        
        if self.action_type == 'STATE':
            old_value = entity.state
            entity.state = self.value
            print(f"[BEHAVIOR] State transition: {old_value} → {entity.state}")
            
        elif self.action_type == 'ENERGY':
            old_value = entity.energy
            
            if self.operation == '=':
                entity.energy = int(self.value)
            elif self.operation == '+':
                entity.energy += int(self.value)
            elif self.operation == '-':
                entity.energy -= int(self.value)
            
            entity.energy = max(0, min(1000, entity.energy))
            print(f"[BEHAVIOR] Energy change: {old_value} → {entity.energy}")
            
        elif self.action_type == 'REPUTATION':
            old_value = entity.reputation
            
            if self.operation == '=':
                entity.reputation = int(self.value)
            elif self.operation == '+':
                entity.reputation += int(self.value)
            elif self.operation == '-':
                entity.reputation -= int(self.value)
            
            entity.reputation = max(-100, min(1000, entity.reputation))
            print(f"[BEHAVIOR] Reputation change: {old_value} → {entity.reputation}")
    
    def __repr__(self):
        return f"Action({self.action_type} {self.operation} {self.value})"


class BehaviorRule:
    """Represents a complete behavior rule: IF condition THEN action"""
    
    def __init__(self, condition, action):
        self.condition = condition
        self.action = action
    
    def evaluate_and_execute(self, entity):
        """Evaluate condition and execute action if true. Legacy single-pass method."""
        if self.condition.evaluate(entity):
            print(f"[BEHAVIOR] Rule triggered: {self.condition}")
            self.action.execute(entity)
            return True
        return False
    
    def __repr__(self):
        return f"BehaviorRule(IF {self.condition} THEN {self.action})"


class ExecuteRule:
    """Represents a conditional tool execution rule"""
    
    def __init__(self, condition, tool_name):
        self.condition = condition
        self.tool_name = tool_name
    
    def should_execute(self, entity):
        """Check if tool should be executed based on condition"""
        return self.condition.evaluate(entity)
    
    def __repr__(self):
        return f"ExecuteRule(IF {self.condition} THEN {self.tool_name})"


def apply_behaviors(entity, rules):
    """
    Three-phase behavior evaluation — fixes competing rule cancellation.

    Phase 1: Run all rules whose conditions check ENERGY or REPUTATION.
             These set STATE transitions based on numeric thresholds.
             Rules fire in declaration order (last writer wins for STATE,
             matching how OBSIDIAN authors expect rule priority to work).

    Phase 2: Re-evaluate rules whose conditions check STATE.
             By now STATE has settled from Phase 1, so these correctly
             see the final state. E.g. IF STATE == Recovery THEN ENERGY + 10
             will fire if Phase 1 landed the entity in Recovery.

    Phase 3: Any ENERGY/REPUTATION rules whose conditions check STATE
             fire here (already handled inline in Phase 2).

    Returns number of rules that triggered.
    """
    print(f"[BEHAVIOR ENGINE] Evaluating {len(rules)} behavior rule(s) for {entity.name}...")

    triggered_count = 0

    # ── Phase 1: non-STATE condition rules (ENERGY/REPUTATION checks) ──
    for rule in rules:
        if not rule.condition.is_state_check:
            if rule.condition.evaluate(entity):
                print(f"[BEHAVIOR] Rule triggered: {rule.condition}")
                rule.action.execute(entity)
                triggered_count += 1

    # ── Phase 2: STATE condition rules — evaluated after state settles ──
    for rule in rules:
        if rule.condition.is_state_check:
            if rule.condition.evaluate(entity):
                print(f"[BEHAVIOR] Rule triggered: {rule.condition}")
                rule.action.execute(entity)
                triggered_count += 1

    if triggered_count == 0:
        print(f"[BEHAVIOR ENGINE] No rules triggered")
    else:
        print(f"[BEHAVIOR ENGINE] {triggered_count} rule(s) triggered")

    return triggered_count