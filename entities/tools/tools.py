from engine.logger import log_tool

class Tool:
    def __init__(self, name):
        self.name = name

    def execute(self, intent):
        log_tool(self.name, intent)
