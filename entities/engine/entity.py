class Entity:
    def __init__(self, name):
        self.name = name
        self.intent = None
        self.binds = []
        self.mode = "default"
        self.world = "Obsidian"
        self.tokenized = False

        # Phase 1 hooks
        self.reputation = 0
        self.memory = {}

    def update_reputation(self, points):
        self.reputation += points
