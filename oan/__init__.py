"""
Obsidian Arcadia Network (OAN)
Autonomous AI agent network with behavioral intelligence
"""

__version__ = "1.0.0"
__author__ = "OAN Development Team"
__license__ = "MIT"

from oan.engine.parser import parse_dsl
from oan.engine.executor import execute_entity, execute_multi_entity
from oan.engine.entity import Entity
from oan.engine.entity_manager import entity_manager, EntityManager
from oan.engine.communication import comm_hub, CommunicationHub
from oan.engine.coordination import coord_hub, CoordinationHub
from oan.engine.logger_cyber import console, log_system, print_ascii_header

__all__ = [
    "parse_dsl",
    "execute_entity",
    "execute_multi_entity",
    "Entity",
    "EntityManager",
    "CommunicationHub",
    "CoordinationHub",
    "entity_manager",
    "comm_hub",
    "coord_hub",
    "console",
    "log_system",
    "print_ascii_header",
    "__version__",
]

def print_banner():
    print_ascii_header()
    print(f"Version: {__version__}")
