"""
OAN Bridge — Connects Python execution layer to Solidity contracts
Slots directly into executor.py via four hooks with zero breaking changes
"""

from web3 import Web3
from web3.exceptions import ContractLogicError
import json
import time
import threading
from collections import deque
from typing import Optional
from enum import Enum


# ─────────────────────────────────────────────
#  TIER SYSTEM — decides what hits the chain
# ─────────────────────────────────────────────

class WriteTier(Enum):
    INSTANT = 1   # write immediately (lifecycle events)
    BATCH   = 2   # write every N cycles (frequent state)
    HASH    = 3   # store hash only (continuous behavioral data)


TIER_MAP = {
    "entity_registered":   WriteTier.INSTANT,
    "entity_spawned":      WriteTier.INSTANT,
    "entity_deceased":     WriteTier.INSTANT,
    "state_change":        WriteTier.BATCH,
    "reputation_change":   WriteTier.BATCH,
    "tool_executed":       WriteTier.HASH,
    "behavior_cycle":      WriteTier.HASH,
}


# ─────────────────────────────────────────────
#  MINIMAL ABIs — only what the bridge calls
# ─────────────────────────────────────────────

ABI_REPUTATION_ORACLE = [
    {"inputs": [{"name": "entityId", "type": "uint256"}],
     "name": "initializeReputation", "outputs": [], "type": "function"},
    {"inputs": [{"name": "entityId", "type": "uint256"},
                {"name": "score",    "type": "uint256"}],
     "name": "updateReputation", "outputs": [], "type": "function"},
]

ABI_TEMPORAL_ENTITIES = [
    {"inputs": [{"name": "entityId",    "type": "uint256"},
                {"name": "currentAge",  "type": "uint256"},
                {"name": "lifespan",    "type": "uint256"}],
     "name": "createTemporalEntity", "outputs": [], "type": "function"},
    {"inputs": [{"name": "entityId", "type": "uint256"}],
     "name": "markDeceased", "outputs": [], "type": "function"},
]

ABI_LEGACY_SYSTEM = [
    {"inputs": [{"name": "parentId",             "type": "uint256"},
                {"name": "heirId",               "type": "uint256"},
                {"name": "inheritedReputation",  "type": "uint256"},
                {"name": "inheritedWealth",      "type": "uint256"}],
     "name": "createHeir", "outputs": [{"type": "uint256"}], "type": "function"},
]

ABI_EMOTIONAL_STATE = [
    {"inputs": [{"name": "entityId", "type": "uint256"}],
     "name": "initializeEmotions", "outputs": [], "type": "function"},
]

ABI_TRUST_DYNAMICS = [
    {"inputs": [{"name": "entity1Id",        "type": "uint256"},
                {"name": "entity2Id",        "type": "uint256"},
                {"name": "interactionScore", "type": "uint256"}],
     "name": "buildTrust", "outputs": [], "type": "function"},
]


# ─────────────────────────────────────────────
#  BRIDGE CORE
# ─────────────────────────────────────────────

class OANBridge:
    """
    Connects Python entity execution to Solidity contracts.

    Usage in executor.py:
        from web3.scripts.oan_bridge import bridge
        # then call hooks at the four insertion points
    """

    def __init__(self):
        self.w3:           Optional[Web3] = None
        self.account:      Optional[object] = None
        self.contracts:    dict = {}
        self.connected:    bool = False

        # Batch queue — Tier 2 writes accumulate here
        self._batch_queue: deque = deque()
        self._batch_size:  int = 10          # flush every N events
        self._batch_lock:  threading.Lock = threading.Lock()

        # Python uuid → on-chain uint256 mapping
        self._id_map:      dict = {}
        self._id_counter:  int = 0

        # Dry-run mode — log what WOULD be written without hitting chain
        self.dry_run:      bool = True

    # ── Setup ──────────────────────────────────

    def connect(self, provider_url: str, private_key: str, addresses: dict) -> bool:
        """
        Connect bridge to a running chain.

        addresses = {
            "ReputationOracle": "0x...",
            "TemporalEntities": "0x...",
            "LegacySystem":     "0x...",
            "EmotionalState":   "0x...",
            "TrustDynamics":    "0x...",
        }
        """
        try:
            self.w3 = Web3(Web3.HTTPProvider(provider_url))
            if not self.w3.is_connected():
                print("[BRIDGE] ✗ Cannot connect to provider")
                return False

            self.account = self.w3.eth.account.from_key(private_key)

            abi_map = {
                "ReputationOracle": ABI_REPUTATION_ORACLE,
                "TemporalEntities": ABI_TEMPORAL_ENTITIES,
                "LegacySystem":     ABI_LEGACY_SYSTEM,
                "EmotionalState":   ABI_EMOTIONAL_STATE,
                "TrustDynamics":    ABI_TRUST_DYNAMICS,
            }

            for name, abi in abi_map.items():
                if name in addresses:
                    self.contracts[name] = self.w3.eth.contract(
                        address=addresses[name], abi=abi
                    )

            self.connected = True
            self.dry_run   = False
            print(f"[BRIDGE] ✓ Connected — chain {self.w3.eth.chain_id}")
            print(f"[BRIDGE] ✓ Wallet: {self.account.address[:10]}...")
            print(f"[BRIDGE] ✓ Contracts loaded: {list(self.contracts.keys())}")
            return True

        except Exception as e:
            print(f"[BRIDGE] ✗ Connection failed: {e}")
            return False

    # ── ID management ──────────────────────────

    def _get_chain_id(self, python_uuid: str) -> int:
        """Map Python uuid string → stable on-chain uint256"""
        if python_uuid not in self._id_map:
            self._id_counter += 1
            self._id_map[python_uuid] = self._id_counter
        return self._id_map[python_uuid]

    # ── Transaction helper ─────────────────────

    def _send_tx(self, fn) -> Optional[str]:
        """Build, sign, send a contract call. Returns tx hash or None."""
        if self.dry_run:
            print(f"[BRIDGE][DRY] Would call: {fn.fn_name}({fn.args})")
            return "dry-run"
        try:
            tx = fn.build_transaction({
                "from":  self.account.address,
                "nonce": self.w3.eth.get_transaction_count(self.account.address),
                "gas":   300_000,
            })
            signed = self.account.sign_transaction(tx)
            tx_hash = self.w3.eth.send_raw_transaction(signed.raw_transaction)
            print(f"[BRIDGE] ✓ tx: {tx_hash.hex()[:16]}...")
            return tx_hash.hex()
        except ContractLogicError as e:
            print(f"[BRIDGE] ✗ Contract reverted: {e}")
            return None
        except Exception as e:
            print(f"[BRIDGE] ✗ TX failed: {e}")
            return None

    # ─────────────────────────────────────────────
    #  THE FOUR HOOKS — drop these into executor.py
    # ─────────────────────────────────────────────

    def on_entity_registered(self, python_uuid: str, entity) -> int:
        """
        HOOK 1 — call after entity_manager.register_entity()

        In execute_entity() and execute_multi_entity():
            entity_id = entity_manager.register_entity(entity)
            chain_id  = bridge.on_entity_registered(entity_id, entity)
        """
        # Guard: skip if already registered (prevents duplicate from spawn flow)
        if python_uuid in self._id_map:
            return self._id_map[python_uuid]

        chain_id = self._get_chain_id(python_uuid)
        print(f"[BRIDGE] HOOK 1 — entity_registered: {entity.name} → chain_id {chain_id}")

        # Tier 1: write immediately
        if "TemporalEntities" in self.contracts:
            self._send_tx(
                self.contracts["TemporalEntities"].functions.createTemporalEntity(
                    chain_id, 0, 80 * 365 * 24 * 3600  # age=0, lifespan=80yrs
                )
            )

        if "ReputationOracle" in self.contracts:
            self._send_tx(
                self.contracts["ReputationOracle"].functions.initializeReputation(chain_id)
            )

        if "EmotionalState" in self.contracts:
            self._send_tx(
                self.contracts["EmotionalState"].functions.initializeEmotions(chain_id)
            )

        return chain_id

    def on_state_change(self, python_uuid: str, old_state: str, new_state: str):
        """
        HOOK 2 — call after log_state_transition()

        In execute_entity() and execute_multi_entity():
            log_state_transition(entity.name, old_state, entity.state)
            bridge.on_state_change(entity_id, old_state, entity.state)
        """
        chain_id = self._get_chain_id(python_uuid)
        print(f"[BRIDGE] HOOK 2 — state_change: chain_id {chain_id} | {old_state} → {new_state}")

        # Tier 2: batch — add to queue, flush when full
        event = {
            "type":     "state_change",
            "chain_id": chain_id,
            "old":      old_state,
            "new":      new_state,
            "ts":       int(time.time()),
        }
        self._enqueue(event)

        # Special case: Deceased state → Tier 1 instant write
        if new_state in ("Deceased", "Dead", "Inactive"):
            self.on_entity_deceased(python_uuid)

    def on_reputation_change(self, python_uuid: str, new_reputation: int):
        """
        HOOK 3 — call after entity.update_reputation()

        In execute_entity() and execute_multi_entity():
            entity.update_reputation(1)
            bridge.on_reputation_change(entity_id, entity.reputation)
        """
        chain_id = self._get_chain_id(python_uuid)
        print(f"[BRIDGE] HOOK 3 — reputation_change: chain_id {chain_id} → rep {new_reputation}")

        # Tier 2: batch
        event = {
            "type":       "reputation_change",
            "chain_id":   chain_id,
            "reputation": new_reputation,
            "ts":         int(time.time()),
        }
        self._enqueue(event)

    def on_entity_spawned(self, parent_uuid: str, child_uuid: str, child_entity, parent_entity):
        """
        HOOK 4 — call after entity_manager.spawn_entity() returns

        In entity_manager.spawn_entity():
            child_id = self.register_entity(child, parent_id=parent_id)
            bridge.on_entity_spawned(parent_id, child_id, child, parent)
        """
        parent_chain_id = self._get_chain_id(parent_uuid)
        child_chain_id  = self._get_chain_id(child_uuid)
        print(f"[BRIDGE] HOOK 4 — entity_spawned: parent {parent_chain_id} → child {child_chain_id}")

        # Register child on chain (guard prevents duplicate if already registered)
        self.on_entity_registered(child_uuid, child_entity)

        # Tier 1: write lineage immediately
        if "LegacySystem" in self.contracts:
            self._send_tx(
                self.contracts["LegacySystem"].functions.createHeir(
                    parent_chain_id,
                    child_chain_id,
                    getattr(child_entity, "reputation", 0),
                    getattr(child_entity, "energy", 0),
                )
            )

        # Build trust between parent and child
        if "TrustDynamics" in self.contracts:
            self._send_tx(
                self.contracts["TrustDynamics"].functions.buildTrust(
                    parent_chain_id, child_chain_id, 80
                )
            )

    def on_entity_deceased(self, python_uuid: str):
        """Called automatically when state → Deceased. Also callable directly."""
        chain_id = self._get_chain_id(python_uuid)
        print(f"[BRIDGE] LIFECYCLE — entity_deceased: chain_id {chain_id}")

        if "TemporalEntities" in self.contracts:
            self._send_tx(
                self.contracts["TemporalEntities"].functions.markDeceased(chain_id)
            )

    # ── Batch system ───────────────────────────

    def _enqueue(self, event: dict):
        """Add event to batch queue, flush if full."""
        with self._batch_lock:
            self._batch_queue.append(event)
            if len(self._batch_queue) >= self._batch_size:
                self._flush_batch()

    def _flush_batch(self):
        """
        Process all queued Tier 2 events.
        Collapses multiple reputation updates for same entity into one tx.
        Called automatically when queue is full, or manually via flush().
        """
        if not self._batch_queue:
            return

        # Collapse: keep only latest reputation per entity
        rep_latest: dict = {}
        other_events = []

        while self._batch_queue:
            event = self._batch_queue.popleft()
            if event["type"] == "reputation_change":
                rep_latest[event["chain_id"]] = event["reputation"]
            else:
                other_events.append(event)

        print(f"[BRIDGE] Flushing batch — {len(rep_latest)} rep updates, {len(other_events)} other")

        # Write collapsed reputation updates
        for chain_id, reputation in rep_latest.items():
            if "ReputationOracle" in self.contracts:
                self._send_tx(
                    self.contracts["ReputationOracle"].functions.updateReputation(
                        chain_id, reputation
                    )
                )

        # State changes — logged now, extend to on-chain as needed
        for event in other_events:
            if event["type"] == "state_change":
                print(f"[BRIDGE] State change logged: {event['chain_id']} {event['old']}→{event['new']}")

    def flush(self):
        """Force flush the batch queue. Call at end of execution."""
        with self._batch_lock:
            self._flush_batch()
        print("[BRIDGE] ✓ Batch flushed")

    def status(self):
        """Print bridge status."""
        print("\n" + "="*50)
        print("OAN BRIDGE STATUS")
        print("="*50)
        print(f"  Mode:       {'LIVE' if not self.dry_run else 'DRY RUN'}")
        print(f"  Connected:  {self.connected}")
        print(f"  Contracts:  {list(self.contracts.keys())}")
        print(f"  Entities:   {len(self._id_map)} registered")
        print(f"  ID map:     {self._id_map}")
        print(f"  Queue:      {len(self._batch_queue)} pending")
        print("="*50 + "\n")


# ─────────────────────────────────────────────
#  SINGLETON — import this everywhere
# ─────────────────────────────────────────────

bridge = OANBridge()


# ─────────────────────────────────────────────
#  EXECUTOR PATCH — copy these into executor.py
# ─────────────────────────────────────────────

EXECUTOR_PATCH = '''
# ── At top of executor.py ────────────────────────────────
from web3.scripts.oan_bridge import bridge

# ── In execute_entity(), after register_entity ───────────
entity_id = entity_manager.register_entity(entity)
chain_id  = bridge.on_entity_registered(entity_id, entity)      # HOOK 1

# ── After each state transition ──────────────────────────
if old_state and entity.state != old_state:
    log_state_transition(entity.name, old_state, entity.state)
    bridge.on_state_change(entity_id, old_state, entity.state)   # HOOK 2

# ── After each reputation update ─────────────────────────
entity.update_reputation(1)
bridge.on_reputation_change(entity_id, entity.reputation)        # HOOK 3

# ── At end of execute_entity(), before return ────────────
bridge.flush()
return entity

# ── In entity_manager.spawn_entity(), after register ─────
child_id = self.register_entity(child, parent_id=parent_id)
bridge.on_entity_spawned(parent_id, child_id, child, parent)     # HOOK 4
'''


# ─────────────────────────────────────────────
#  QUICK START — run this to test dry-run mode
# ─────────────────────────────────────────────

if __name__ == "__main__":
    print("OAN Bridge — Dry Run Test\n")

    class MockEntity:
        def __init__(self, name):
            self.name       = name
            self.energy     = 100
            self.reputation = 0
            self.state      = "Active"

    parent = MockEntity("ParentBot")
    child  = MockEntity("ChildBot")

    # Hook 1 — register both entities
    pid = bridge.on_entity_registered("uuid-parent-001", parent)
    cid = bridge.on_entity_registered("uuid-child-001",  child)

    # Hook 3 — reputation changes (collapses to 1 tx per entity on flush)
    bridge.on_reputation_change("uuid-parent-001", 10)
    bridge.on_reputation_change("uuid-parent-001", 25)  # replaces above
    bridge.on_reputation_change("uuid-child-001",   5)

    # Hook 2 — state change (batched)
    bridge.on_state_change("uuid-parent-001", "Active", "Elite")

    # Hook 4 — spawn (guard prevents double-registration of child)
    bridge.on_entity_spawned("uuid-parent-001", "uuid-child-001", child, parent)

    # Deceased state auto-triggers instant markDeceased()
    bridge.on_state_change("uuid-parent-001", "Elite", "Deceased")

    # Force flush remaining
    bridge.flush()

    # Show final status
    bridge.status()