import os
from engine.entity import Entity
from engine.behavior import Condition, Action, BehaviorRule, ExecuteRule


class DSLParseError(Exception):
    def __init__(self, message, line_number=None, line_content=None):
        self.line_number = line_number
        self.line_content = line_content
        error_msg = f"[OAN DSL ERROR] {message}"
        if line_number is not None:
            error_msg += f"\n  → Line {line_number}"
        if line_content is not None:
            error_msg += f"\n  → Content: {line_content}"
        super().__init__(error_msg)


class DSLValidator:
    VALID_KEYWORDS = {
        'ENTITY', 'TYPE', 'STATE', 'ENERGY', 'MODULES', 
        'INTENT', 'BIND', 'MODE', 'WORLD', 'TOKENIZED', 'REPUTATION',
        'BEHAVIOR', 'EXECUTE', 'END', 'IF', 'THEN'
    }
    
    REQUIRED_FIELDS = {'ENTITY'}
    RECOMMENDED_FIELDS = {'INTENT', 'MODE'}
    
    VALID_MODES = {'Production', 'Testing', 'Development', 'ColdLogic', 'Experimental', 'Debug'}
    VALID_STATES = {'Idle', 'Active', 'Suspended', 'Terminated', 'Learning', 'Executing', 
                    'Recovery', 'Overclocked', 'Degraded', 'Dormant'}
    VALID_TYPES = {'AIAgent', 'Researcher', 'Analyzer', 'Generator', 'Monitor', 'Coordinator', 'Undefined'}
    
    ENERGY_MIN = 0
    ENERGY_MAX = 1000
    REPUTATION_MIN = -100
    REPUTATION_MAX = 1000
    INTENT_MIN_LENGTH = 10
    INTENT_MAX_LENGTH = 500
    ENTITY_NAME_MIN_LENGTH = 3
    ENTITY_NAME_MAX_LENGTH = 50
    MAX_BINDS = 20
    
    @staticmethod
    def validate_keyword(keyword, line_number, line_content):
        if keyword not in DSLValidator.VALID_KEYWORDS:
            raise DSLParseError(
                f"Unknown keyword '{keyword}'. Valid keywords: {', '.join(sorted(DSLValidator.VALID_KEYWORDS))}",
                line_number, line_content
            )
    
    @staticmethod
    def validate_required_fields(fields_set, filepath):
        missing_fields = DSLValidator.REQUIRED_FIELDS - fields_set
        if missing_fields:
            raise DSLParseError(f"Missing required field(s): {', '.join(missing_fields)}\n  → File: {filepath}")
    
    @staticmethod
    def validate_entity_name(name, line_number, line_content):
        if not name or len(name) < 3:
            raise DSLParseError("Entity name too short", line_number, line_content)
        import re
        if not re.match(r'^[a-zA-Z0-9_-]+$', name):
            raise DSLParseError("Entity name invalid characters", line_number, line_content)
        return name
    
    @staticmethod
    def validate_energy_value(value, line_number, line_content):
        try:
            energy = int(value)
            if energy < 0 or energy > 1000:
                raise DSLParseError(f"ENERGY out of range (0-1000)", line_number, line_content)
            return energy
        except ValueError:
            raise DSLParseError(f"Invalid ENERGY value", line_number, line_content)
    
    @staticmethod
    def validate_intent(intent, line_number, line_content):
        if not intent or len(intent) < 10:
            raise DSLParseError("INTENT too short", line_number, line_content)
        return intent


class BehaviorParser:
    @staticmethod
    def parse_condition(condition_str, line_number, line_content):
        condition_str = condition_str.strip()
        operator = None
        for op in ['<=', '>=', '==', '!=', '<', '>']:
            if op in condition_str:
                operator = op
                break
        if not operator:
            raise DSLParseError(f"Invalid condition: no operator", line_number, line_content)
        parts = condition_str.split(operator, 1)
        if len(parts) != 2:
            raise DSLParseError(f"Invalid condition format", line_number, line_content)
        field = parts[0].strip().upper()
        value = parts[1].strip()
        return Condition(field, operator, value)
    
    @staticmethod
    def parse_action(action_str, line_number, line_content):
        action_str = action_str.strip()
        parts = action_str.split(None, 1)
        if len(parts) < 2:
            raise DSLParseError(f"Invalid action", line_number, line_content)
        action_type = parts[0].strip().upper()
        rest = parts[1].strip()
        if action_type == 'STATE':
            return Action(action_type, '=', rest)
        operation = None
        for op in ['+', '-', '=']:
            if op in rest:
                operation = op
                break
        if operation:
            value_parts = rest.split(operation, 1)
            value = value_parts[1].strip() if len(value_parts) == 2 else rest
        else:
            value = rest
            operation = '='
        return Action(action_type, operation, value)
    
    @staticmethod
    def parse_behavior_rule(rule_str, line_number, line_content):
        rule_str = rule_str.strip()
        if not rule_str.upper().startswith('IF'):
            raise DSLParseError("Behavior rule must start with IF", line_number, line_content)
        if 'THEN' not in rule_str.upper():
            raise DSLParseError("Behavior rule must contain THEN", line_number, line_content)
        then_pos = rule_str.upper().find('THEN')
        condition_str = rule_str[2:then_pos].strip()
        action_str = rule_str[then_pos + 4:].strip()
        condition = BehaviorParser.parse_condition(condition_str, line_number, line_content)
        action = BehaviorParser.parse_action(action_str, line_number, line_content)
        return BehaviorRule(condition, action)
    
    @staticmethod
    def parse_execute_rule(rule_str, line_number, line_content):
        rule_str = rule_str.strip()
        if not rule_str.upper().startswith('IF'):
            raise DSLParseError("Execute rule must start with IF", line_number, line_content)
        if 'THEN' not in rule_str.upper():
            raise DSLParseError("Execute rule must contain THEN", line_number, line_content)
        then_pos = rule_str.upper().find('THEN')
        condition_str = rule_str[2:then_pos].strip()
        tool_name = rule_str[then_pos + 4:].strip()
        condition = BehaviorParser.parse_condition(condition_str, line_number, line_content)
        return ExecuteRule(condition, tool_name)


def parse_dsl(file_path):
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    full_path = os.path.join(base_dir, file_path)
    
    if not os.path.exists(full_path):
        raise FileNotFoundError(f"[OAN ERROR] DSL file not found → {full_path}")
    
    with open(full_path, "r", encoding='utf-8') as f:
        lines = f.readlines()
    
    entity_data = {
        "name": "Unknown", "type": "Undefined", "state": "Idle", "energy": 0,
        "modules": [], "intent": None, "binds": [], "mode": None,
        "world": None, "tokenized": False, "reputation": 0
    }
    
    fields_set = set()
    behavior_rules = []
    execute_rules = []
    in_behavior_block = False
    in_execute_block = False
    
    for line_number, line in enumerate(lines, start=1):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        
        # Handle blocks
        if line.upper() == 'BEHAVIOR':
            in_behavior_block = True
            continue
        if line.upper() == 'EXECUTE':
            in_execute_block = True
            continue
        if line.upper() == 'END':
            in_behavior_block = False
            in_execute_block = False
            continue
        
        if in_behavior_block:
            rule = BehaviorParser.parse_behavior_rule(line, line_number, line)
            behavior_rules.append(rule)
            continue
        
        if in_execute_block:
            rule = BehaviorParser.parse_execute_rule(line, line_number, line)
            execute_rules.append(rule)
            continue
        
        # Parse regular fields
        parts = line.split(None, 1)
        if len(parts) < 2:
            continue
        
        keyword, value = parts
        keyword = keyword.upper()
        
        if keyword == "ENTITY":
            entity_data["name"] = DSLValidator.validate_entity_name(value, line_number, line)
            fields_set.add("ENTITY")
        elif keyword == "TYPE":
            entity_data["type"] = value
            fields_set.add("TYPE")
        elif keyword == "STATE":
            entity_data["state"] = value
            fields_set.add("STATE")
        elif keyword == "ENERGY":
            entity_data["energy"] = DSLValidator.validate_energy_value(value, line_number, line)
            fields_set.add("ENERGY")
        elif keyword == "INTENT":
            entity_data["intent"] = DSLValidator.validate_intent(value.strip('"'), line_number, line)
            fields_set.add("INTENT")
        elif keyword == "BIND":
            entity_data["binds"].append(value)
            fields_set.add("BIND")
        elif keyword == "MODE":
            entity_data["mode"] = value
            fields_set.add("MODE")
        elif keyword == "WORLD":
            entity_data["world"] = value
            fields_set.add("WORLD")
        elif keyword == "TOKENIZED":
            entity_data["tokenized"] = value.lower() == 'true'
            fields_set.add("TOKENIZED")
        elif keyword == "REPUTATION":
            entity_data["reputation"] = int(value)
            fields_set.add("REPUTATION")
    
    DSLValidator.validate_required_fields(fields_set, full_path)
    
    print(f"[OAN SYSTEM] DSL Loaded → {full_path}")
    print(f"[OAN SYSTEM] Entity Parsed → {entity_data['name']}")
    
    entity = Entity(
        name=entity_data["name"],
        type=entity_data["type"],
        state=entity_data["state"],
        energy=entity_data["energy"],
        modules=entity_data["modules"],
        intent=entity_data["intent"],
        binds=entity_data["binds"],
        mode=entity_data["mode"],
        world=entity_data["world"],
        tokenized=entity_data["tokenized"],
        reputation=entity_data["reputation"]
    )
    
    for rule in behavior_rules:
        entity.add_behavior_rule(rule)
    
    for rule in execute_rules:
        entity.add_execute_rule(rule)
    
    return entity
