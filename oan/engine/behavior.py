"""
OAN Behavior System
Defines behavioral rules and actions for entities
"""


class Condition:
    """Represents a conditional expression (e.g., ENERGY < 30)"""
    
    VALID_OPERATORS = ['<', '>', '==', '!=', '<=', '>=']
    VALID_FIELDS = ['ENERGY', 'REPUTATION', 'STATE']
    
    def __init__(self, field, operator, value):
        self.field = field.upper()
        self.operator = operator
        self.value = value
        
        # Validate
        if self.field not in self.VALID_FIELDS:
            raise ValueError(f"Invalid field: {field}. Valid fields: {self.VALID_FIELDS}")
        if self.operator not in self.VALID_OPERATORS:
            raise ValueError(f"Invalid operator: {operator}. Valid operators: {self.VALID_OPERATORS}")
    
    def evaluate(self, entity):
        """Evaluate condition against an entity"""
        # Get the field value from entity
        if self.field == 'ENERGY':
            field_value = entity.energy
        elif self.field == 'REPUTATION':
            field_value = entity.reputation
        elif self.field == 'STATE':
            field_value = entity.state
        else:
            return False
        
        # Convert value to appropriate type
        if self.field == 'STATE':
            # State is string comparison
            compare_value = str(self.value)
            field_value = str(field_value)
        else:
            # Energy and reputation are numeric
            try:
                compare_value = int(self.value)
            except (ValueError, TypeError):
                return False
        
        # Evaluate operator
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
        
        # Validate
        if self.action_type not in self.VALID_ACTION_TYPES:
            raise ValueError(f"Invalid action type: {action_type}")
        
        # STATE uses assignment (=), ENERGY/REPUTATION can use +, -, =
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
            
            # Clamp energy to valid range (0-1000)
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
            
            # Clamp reputation to valid range (-100 to 1000)
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
        """Evaluate condition and execute action if true"""
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