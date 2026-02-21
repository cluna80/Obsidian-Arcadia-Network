"""
OAN Entity
Core agent data structure with integrated four-phase behavior evaluation
"""

from engine.behavior import BehaviorRule, ExecuteRule


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
        
        self.behavior_rules = []  # List of BehaviorRule objects
        self.execute_rules = []   # List of ExecuteRule objects
    
    def add_behavior_rule(self, rule):
        """Add a behavior rule to this entity"""
        self.behavior_rules.append(rule)
    
    def add_execute_rule(self, rule):
        """Add an execute rule to this entity"""
        self.execute_rules.append(rule)
    
    def apply_behaviors(self):
        """
        Four-phase behavior evaluation.

        Fixes two bugs in the original single-pass system:

        Bug 1 — STATE-dependent side effects saw wrong state:
          IF ENERGY < 50 → Recovery, IF STATE == Recovery → ENERGY + 10
          In single-pass, ENERGY + 10 evaluated before state settled.
          Fix: Phase 2 runs STATE-condition rules after Phase 1 sets state.

        Bug 2 — Post-Phase-2 numeric changes didn't trigger state transitions:
          IF STATE == Recovery → ENERGY + 15, IF ENERGY > 80 → STATE Active
          After ENERGY + 15 fires in Phase 2, energy may cross 80 threshold
          but Phase 1 already ran and won't see the new value.
          Fix: Phase 3 re-runs ENERGY/REPUTATION condition rules with
               updated values so transitions like ENERGY > 80 → Active fire.

        Execution order per cycle:
          Phase 1 — ENERGY/REPUTATION conditions → execute actions (sets state)
          Phase 2 — STATE conditions → execute actions (side effects on energy/rep)
          Phase 3 — ENERGY/REPUTATION conditions again → catch post-Phase-2 changes
        """
        if not self.behavior_rules:
            return

        print(f"\n[BEHAVIOR ENGINE] Evaluating {len(self.behavior_rules)} behavior rule(s) for {self.name}...")

        triggered_count = 0

        # ── Phase 1: ENERGY/REPUTATION condition rules ──────────────────
        # Evaluate numeric thresholds and set state transitions
        for rule in self.behavior_rules:
            if not rule.condition.is_state_check:
                if rule.condition.evaluate(self):
                    print(f"[BEHAVIOR] Rule triggered: {rule.condition}")
                    rule.action.execute(self)
                    triggered_count += 1

        # ── Phase 2: STATE condition rules ──────────────────────────────
        # Evaluate state-based rules now that state has settled from Phase 1
        # These typically apply ENERGY/REPUTATION side effects
        for rule in self.behavior_rules:
            if rule.condition.is_state_check:
                if rule.condition.evaluate(self):
                    print(f"[BEHAVIOR] Rule triggered: {rule.condition}")
                    rule.action.execute(self)
                    triggered_count += 1

        # ── Phase 3: ENERGY/REPUTATION conditions again ─────────────────
        # Phase 2 may have changed energy/reputation values (e.g. ENERGY + 15)
        # which could now satisfy new thresholds (e.g. ENERGY > 80 → Active)
        # Re-run numeric rules once more to catch these post-side-effect transitions
        for rule in self.behavior_rules:
            if not rule.condition.is_state_check:
                if rule.condition.evaluate(self):
                    # Only fire if this produces a different outcome than Phase 1
                    # to avoid double-counting non-state actions
                    if rule.action.action_type == 'STATE':
                        print(f"[BEHAVIOR] Rule triggered: {rule.condition}")
                        rule.action.execute(self)
                        triggered_count += 1

        if triggered_count == 0:
            print(f"[BEHAVIOR ENGINE] No rules triggered")
        else:
            print(f"[BEHAVIOR ENGINE] {triggered_count} rule(s) triggered")

    def get_conditional_tools(self):
        """Get list of tools to execute based on current state"""
        if not self.execute_rules:
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
        """Update the entity's reputation by the given amount"""
        self.reputation += amount
        self.reputation = max(-100, min(1000, self.reputation))
        print(f"[OAN SYSTEM] {self.name}'s reputation updated: {amount:+d} (Total: {self.reputation})")

    def __repr__(self):
        behavior_info = f"\nBehavior Rules: {len(self.behavior_rules)}" if self.behavior_rules else ""
        execute_info  = f"\nExecute Rules: {len(self.execute_rules)}"   if self.execute_rules  else ""
        
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