class Entity:
    def __init__(self, name, type, state, energy, modules, intent=None, binds=None, mode=None, world=None, tokenized=False, reputation=0):
        self.name = name
        self.type = type
        self.state = state
        self.energy = energy
        self.modules = modules
        self.intent = intent
        self.binds = binds if binds is not None else []
        self.mode = mode
        self.world = world
        self.tokenized = tokenized
        self.reputation = reputation
        
        # NEW: Behavior system
        self.behavior_rules = []  # List of BehaviorRule objects
        self.execute_rules = []   # List of ExecuteRule objects
    
    def add_behavior_rule(self, rule):
        """Add a behavior rule to this entity"""
        self.behavior_rules.append(rule)
    
    def add_execute_rule(self, rule):
        """Add an execute rule to this entity"""
        self.execute_rules.append(rule)
    
    def apply_behaviors(self):
        """Evaluate and apply all behavior rules"""
        if not self.behavior_rules:
            return
        
        print(f"\n[BEHAVIOR ENGINE] Evaluating {len(self.behavior_rules)} behavior rule(s) for {self.name}...")
        
        rules_triggered = 0
        for rule in self.behavior_rules:
            if rule.evaluate_and_execute(self):
                rules_triggered += 1
        
        if rules_triggered > 0:
            print(f"[BEHAVIOR ENGINE] {rules_triggered} rule(s) triggered")
        else:
            print(f"[BEHAVIOR ENGINE] No rules triggered")
    
    def get_conditional_tools(self):
        """Get list of tools to execute based on current state"""
        if not self.execute_rules:
            # No conditional execution, return all binds
            return self.binds
        
        tools_to_execute = []
        
        print(f"\n[EXECUTE ENGINE] Evaluating {len(self.execute_rules)} execute rule(s)...")
        
        for rule in self.execute_rules:
            if rule.should_execute(self):
                tools_to_execute.append(rule.tool_name)
                print(f"[EXECUTE ENGINE] ✓ {rule.tool_name} (condition met)")
            else:
                print(f"[EXECUTE ENGINE] ✗ {rule.tool_name} (condition not met)")
        
        return tools_to_execute
    
    def update_reputation(self, amount):
        """
        Updates the entity's reputation by the given amount
        """
        self.reputation += amount
        
        # Clamp reputation to valid range
        self.reputation = max(-100, min(1000, self.reputation))
        
        print(f"[OAN SYSTEM] {self.name}'s reputation updated: {amount:+d} (Total: {self.reputation})")

    def __repr__(self):
        behavior_info = f"\nBehavior Rules: {len(self.behavior_rules)}" if self.behavior_rules else ""
        execute_info = f"\nExecute Rules: {len(self.execute_rules)}" if self.execute_rules else ""
        
        return (
            f"\n[ENTITY STATUS]"
            f"\nName: {self.name}"
            f"\nType: {self.type}"
            f"\nState: {self.state}"
            f"\nEnergy: {self.energy}"
            f"\nModules: {', '.join(self.modules)}"
            f"\nIntent: {self.intent}"
            f"\nBinds: {', '.join(self.binds)}"
            f"\nMode: {self.mode}"
            f"\nWorld: {self.world}"
            f"\nTokenized: {self.tokenized}"
            f"\nReputation: {self.reputation}"
            f"{behavior_info}"
            f"{execute_info}\n"
        )