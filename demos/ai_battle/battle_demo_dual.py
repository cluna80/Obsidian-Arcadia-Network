#!/usr/bin/env python3
"""
OAN AI Battle Royale - Dual AI Edition
Ollama vs OpenClaw - Two different AI models fight!
"""

import json
import requests
import time
from datetime import datetime
import os
import asyncio

class AIAgent:
    """Base class for AI agents"""
    
    def __init__(self, name, personality, ai_type):
        self.name = name
        self.personality = personality
        self.ai_type = ai_type
        self.health = 100
        self.energy = 100
        self.wins = 0
        self.defending = False
        
    def think(self, situation):
        """Agent decides next move - implemented by subclasses"""
        raise NotImplementedError
        
    def execute_action(self, action, opponent):
        """Execute chosen action"""
        actions = {
            1: self._attack,
            2: self._defend,
            3: self._charge,
            4: self._special
        }
        return actions[action](opponent)
    
    def _attack(self, opponent):
        if self.energy < 20:
            return f"[LOW ENERGY] {self.name} can't attack!"
        
        self.energy -= 20
        damage = 25
        if hasattr(opponent, 'defending') and opponent.defending:
            damage = damage // 2
            opponent.defending = False
        opponent.health -= damage
        return f"[ATTACK] {self.name} attacks dealing {damage} damage!"
    
    def _defend(self, opponent):
        if self.energy < 10:
            return f"[LOW ENERGY] {self.name} can't defend!"
        self.energy -= 10
        self.defending = True
        return f"[DEFEND] {self.name} defends (blocks 50% damage next turn)"
    
    def _charge(self, opponent):
        self.energy = min(100, self.energy + 30)
        return f"[CHARGE] {self.name} charges energy (+30 energy)"
    
    def _special(self, opponent):
        if self.energy < 50:
            return f"[LOW ENERGY] {self.name} can't use special!"
        
        self.energy -= 50
        damage = 50
        opponent.health -= damage
        return f"[SPECIAL] {self.name} special attack dealing {damage} damage!"


class OllamaAgent(AIAgent):
    """Ollama-powered agent"""
    
    def __init__(self, name, personality, model="gemma3:12b"):
        super().__init__(name, personality, "ollama")
        self.model = model
        
    def think(self, situation):
        """Use Ollama to decide"""
        prompt = f"""You are {self.name}, a fighter. Personality: {self.personality}

{situation}
Health: {self.health} | Energy: {self.energy}

Choose ONE action (respond with ONLY the number):
1. ATTACK - 25 damage, costs 20 energy
2. DEFEND - Block 50% damage, costs 10 energy
3. CHARGE - Restore 30 energy
4. SPECIAL - 50 damage, costs 50 energy

Your choice (1-4):"""

        try:
            response = requests.post(
                'http://localhost:11434/api/generate',
                json={
                    'model': self.model,
                    'prompt': prompt,
                    'stream': False
                },
                timeout=15
            )
            
            if response.status_code == 200:
                result = response.json()
                choice = result['response'].strip()
                
                for char in choice:
                    if char.isdigit() and 1 <= int(char) <= 4:
                        print(f"   [OLLAMA] chose: {char}")
                        return int(char)
                
                print(f"   [OLLAMA] defaulted to defend")
                return 2
            else:
                print(f"   [OLLAMA ERROR] defaulting to defend")
                return 2
                
        except Exception as e:
            print(f"   [OLLAMA ERROR] {e}")
            return 2


class OpenClawAgent(AIAgent):
    """OpenClaw-powered agent (simplified - no Telegram for now)"""
    
    def __init__(self, name, personality):
        super().__init__(name, personality, "openclaw")
        
    def think(self, situation):
        """Simple tactical AI (placeholder for OpenClaw)"""
        # For now, use tactical logic until OpenClaw is properly integrated
        if self.health < 30 and self.energy >= 10:
            print(f"   [OPENCLAW] chose: 2 (tactical defense)")
            return 2  # Defend when low health
        elif self.energy < 30:
            print(f"   [OPENCLAW] chose: 3 (tactical charge)")
            return 3  # Charge when low energy
        elif self.energy >= 50:
            print(f"   [OPENCLAW] chose: 4 (tactical special)")
            return 4  # Special when high energy
        else:
            print(f"   [OPENCLAW] chose: 1 (tactical attack)")
            return 1  # Attack otherwise


class BattleArena:
    """Manages the battle"""
    
    def __init__(self, agent1, agent2):
        self.agent1 = agent1
        self.agent2 = agent2
        self.round = 0
        self.history = []
        
    def fight(self):
        """Run the battle"""
        print("\n" + "="*70)
        print("OAN AI BATTLE ROYALE - DUAL AI EDITION")
        print("="*70)
        print(f"\n[MATCH] {self.agent1.name} ({self.agent1.ai_type.upper()}) VS {self.agent2.name} ({self.agent2.ai_type.upper()})")
        print(f"  {self.agent1.name}: {self.agent1.personality}")
        print(f"  {self.agent2.name}: {self.agent2.personality}")
        print("="*70)
        
        input("\nPress ENTER to start the battle...")
        
        while self.agent1.health > 0 and self.agent2.health > 0:
            self.round += 1
            print(f"\n{'='*70}")
            print(f"ROUND {self.round}")
            print(f"{'='*70}")
            
            print(f"{self.agent1.name}: ❤️ {self.agent1.health} | ⚡ {self.agent1.energy}")
            print(f"{self.agent2.name}: ❤️ {self.agent2.health} | ⚡ {self.agent2.energy}")
            
            self.agent1.defending = False
            self.agent2.defending = False
            
            print(f"[THINK] {self.agent1.name} ({self.agent1.ai_type}) is thinking...")
            action1 = self.agent1.think(f"Round {self.round}")
            
            print(f"[THINK] {self.agent2.name} ({self.agent2.ai_type}) is thinking...")
            action2 = self.agent2.think(f"Round {self.round}")
            
            result1 = self.agent1.execute_action(action1, self.agent2)
            result2 = self.agent2.execute_action(action2, self.agent1)
            
            print(f"\n{result1}")
            print(f"{result2}")
            
            self.history.append({
                'round': self.round,
                'agent1_action': action1,
                'agent2_action': action2,
                'agent1_health': self.agent1.health,
                'agent2_health': self.agent2.health
            })
            
            time.sleep(1.5)
            
            if self.agent1.health <= 0:
                return self._declare_winner(self.agent2, self.agent1)
            elif self.agent2.health <= 0:
                return self._declare_winner(self.agent1, self.agent2)
            
            if self.round >= 20:
                print("\n[TIMEOUT] Time limit reached!")
                if self.agent1.health > self.agent2.health:
                    return self._declare_winner(self.agent1, self.agent2)
                else:
                    return self._declare_winner(self.agent2, self.agent1)
    
    def _declare_winner(self, winner, loser):
        """Announce winner"""
        print("\n" + "="*70)
        print("[VICTORY] BATTLE COMPLETE!")
        print("="*70)
        print(f"\n[WINNER] {winner.name} ({winner.ai_type.upper()})")
        print(f"  Final HP: {winner.health}")
        print(f"  Final Energy: {winner.energy}")
        print(f"\n[DEFEATED] {loser.name} ({loser.ai_type.upper()})")
        print(f"  Final HP: {loser.health}")
        print(f"\n[STATS] Battle lasted {self.round} rounds")
        
        winner.wins += 1
        return winner


def check_ai_availability():
    """Check which AIs are available"""
    available = {}
    
    try:
        response = requests.get('http://localhost:11434/api/tags', timeout=3)
        if response.status_code == 200:
            available['ollama'] = True
            print("[OK] Ollama detected")
        else:
            available['ollama'] = False
            print("[WARN] Ollama not responding")
    except:
        available['ollama'] = False
        print("[ERROR] Ollama not available (run: ollama serve)")
    
    # For now, always say OpenClaw is available (tactical AI)
    available['openclaw'] = True
    print("[OK] OpenClaw tactical AI ready")
    
    return available


def main():
    """Run the demo"""
    print("\n" + "="*70)
    print("OBSIDIAN ARCADIA NETWORK - DUAL AI BATTLE DEMO")
    print("="*70)
    print("\nChecking AI availability...\n")
    
    available = check_ai_availability()
    
    if not available['ollama']:
        print("\n[ERROR] Ollama required! Please start: ollama serve")
        return
    
    print(f"\n[READY] Starting Ollama vs OpenClaw (Tactical AI) battle!")
    
    agent1 = OllamaAgent(
        name="Thunderfist",
        personality="Aggressive brawler who loves close combat",
        model="gemma3:12b"
    )
    
    agent2 = OpenClawAgent(
        name="ShadowStrike",
        personality="Tactical genius who calculates every move"
    )
    
    arena = BattleArena(agent1, agent2)
    winner = arena.fight()
    
    print("\n" + "="*70)
    print("[MINTING] Champion as NFT Entity")
    print("="*70)
    
    entity_code = f"""
ENTITY champion_{winner.name}_{int(time.time())} {{
    METADATA {{
        name: "{winner.name} - Battle Champion"
        ai_type: "{winner.ai_type}"
        wins: {winner.wins}
        final_health: {winner.health}
        minted_at: "{datetime.now().isoformat()}"
    }}
    
    STATE {{
        champion_tier: "Legendary"
        ai_powered_by: "{winner.ai_type}"
        combat_rating: {winner.health + winner.energy}
    }}
}}
"""
    
    os.makedirs("entities", exist_ok=True)
    filename = f"entities/champion_{winner.name}_{int(time.time())}.ent"
    with open(filename, 'w') as f:
        f.write(entity_code)
    
    print(f"\n[SUCCESS] Champion minted: {filename}")
    print(f"[SUCCESS] Powered by: {winner.ai_type.upper()}")
    print(f"\n[COMPLETE] OAN Protocol - Where AI meets Web3\n")


if __name__ == "__main__":
    main()
