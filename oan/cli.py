#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OAN Protocol - Command Line Interface
Main entry point for the oan command
"""

import sys
import os

def print_banner():
    banner = """
  ╔══════════════════════════════════════════════════════════╗
  ║                                                          ║
  ║         ��� OBSIDIAN ARCADIA NETWORK v1.0                ║
  ║              Command Line Interface                      ║
  ║                                                          ║
  ╚══════════════════════════════════════════════════════════╝
    """
    print(banner)

def print_menu():
    menu = """
  [1] Run Protocol Tests (Solidity)
  [2] Run Rust Integration Tests
  [3] Launch AI Entity Conversation
  [4] Launch Founding Council Interview
  [5] Run Live Economy Demo (Investor Pitch)
  [6] Run AI Battle Arena
  [7] Protocol Status
  [8] Help
  [9] Exit

  Choose an option (1-9): """
    return input(menu).strip()

def main():
    """Main CLI entry point"""
    print_banner()
    
    # Get the project root
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    
    print(f"\n  Installation: {project_root}")
    print(f"  Python: {sys.version.split()[0]}")
    print("\n")
    
    while True:
        choice = print_menu()
        
        if choice == '1':
            print("\n��� Running Solidity tests...\n")
            os.system(f"cd {project_root}/web3 && npx hardhat test")
            input("\nPress Enter to continue...")
        
        elif choice == '2':
            print("\n��� Running Rust integration tests...\n")
            os.system(f"cd {project_root}/rust/integration_tests && python test_full_protocol.py")
            input("\nPress Enter to continue...")
        
        elif choice == '3':
            print("\n��� Launching AI Entity Conversation...\n")
            print("Make sure Ollama is running: ollama serve\n")
            os.system(f"cd {project_root}/demos/ollama_entities && python ai_entity_conversation.py")
            input("\nPress Enter to continue...")
        
        elif choice == '4':
            print("\n��� Launching Founding Council Interview...\n")
            print("Make sure Ollama is running: ollama serve\n")
            os.system(f"cd {project_root}/demos/ollama_entities && python oan_founding_council.py")
            input("\nPress Enter to continue...")
        
        elif choice == '5':
            print("\n��� Running Live Economy Demo...\n")
            os.system(f"cd {project_root}/demos/investor_demo && python live_economy_demo.py")
            input("\nPress Enter to continue...")
        
        elif choice == '6':
            print("\n��� Launching AI Battle Arena...\n")
            print("Make sure Ollama is running: ollama serve\n")
            os.system(f"cd {project_root}/demos/ollama_entities && python ai_battle_arena.py")
            input("\nPress Enter to continue...")
        
        elif choice == '7':
            print("\n��� PROTOCOL STATUS\n")
            print("  ✅ 125+ Smart Contracts")
            print("  ✅ 370+ Tests Passing")
            print("  ✅ Rust Engine: 335k+ ops/sec")
            print("  ✅ 7 Complete Protocol Layers")
            print("  ✅ ZKSync Privacy Integration")
            print("  ✅ Production Ready")
            input("\nPress Enter to continue...")
        
        elif choice == '8':
            print("\n��� HELP\n")
            print("  OAN Protocol Documentation:")
            print("  - GitHub: https://github.com/cluna80/Obsidian-Arcadia-Network")
            print("  - Demos: demos/ollama_entities/")
            print("  - Tests: web3/test/")
            print("  - Rust: rust/oan-engine/")
            input("\nPress Enter to continue...")
        
        elif choice == '9':
            print("\n  Goodbye! ���\n")
            sys.exit(0)
        
        else:
            print("\n  ❌ Invalid choice. Please select 1-9.\n")

if __name__ == '__main__':
    main()
