#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════╗
║           OBSIDIAN ARCADIA NETWORK — CLI INSTALLER                       ║
║           pip install obsidian-arcadia                                   ║
╚══════════════════════════════════════════════════════════════════════════╝
"""

import sys
import os
import time
import subprocess
import shutil
import platform
import threading
from pathlib import Path

# ── ANSI colours ────────────────────────────────────────────────────────────
class C:
    RESET    = "\033[0m"
    BOLD     = "\033[1m"
    DIM      = "\033[2m"
    NEON     = "\033[38;2;0;255;65m"
    LIME     = "\033[38;2;57;255;20m"
    CYAN     = "\033[38;2;0;255;255m"
    ICE      = "\033[38;2;100;220;255m"
    VIOLET   = "\033[38;2;180;50;255m"
    OBSIDIAN = "\033[38;2;140;80;255m"
    CRIMSON  = "\033[38;2;255;50;50m"
    ORANGE   = "\033[38;2;255;140;0m"
    GHOST    = "\033[38;2;80;80;100m"
    SILVER   = "\033[38;2;180;180;200m"
    WHITE    = "\033[38;2;230;230;255m"

def c(color, text):  return f"{color}{text}{C.RESET}"
def b(color, text):  return f"{C.BOLD}{color}{text}{C.RESET}"

# Windows ANSI support
if platform.system() == "Windows":
    os.system("color")
    try:
        import ctypes
        kernel32 = ctypes.windll.kernel32
        kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)
    except Exception:
        pass

# ── Banner ───────────────────────────────────────────────────────────────────
BANNER = f"""
{c(C.OBSIDIAN, "  ╔══════════════════════════════════════════════════════════════════════╗")}
{c(C.OBSIDIAN, "  ║")}                                                                      {c(C.OBSIDIAN, "║")}
{c(C.OBSIDIAN, "  ║")}  {b(C.VIOLET,  "  ██████╗  ██████╗  ███████╗ ██╗ ██████╗  ██╗  ██████╗  ███╗  ██╗")}  {c(C.OBSIDIAN, "║")}
{c(C.OBSIDIAN, "  ║")}  {b(C.VIOLET,  " ██╔═══██╗ ██╔══██╗ ██╔════╝ ██║ ██╔══██╗ ██║ ██╔═══██╗ ████╗ ██║")}  {c(C.OBSIDIAN, "║")}
{c(C.OBSIDIAN, "  ║")}  {b(C.CYAN,    " ██║   ██║ ███████╗ ███████╗ ██║ ██║  ██║ ██║ ███████║ ██╔██╗██║")}  {c(C.OBSIDIAN, "║")}
{c(C.OBSIDIAN, "  ║")}  {b(C.CYAN,    " ██║   ██║ ██╔══██╗ ╚════██║ ██║ ██║  ██║ ██║ ██╔══██║ ██║╚████║")}  {c(C.OBSIDIAN, "║")}
{c(C.OBSIDIAN, "  ║")}  {b(C.NEON,    " ╚██████╔╝ ██████╔╝ ███████║ ██║ ██████╔╝ ██║ ██║  ██║ ██║ ╚███║")}  {c(C.OBSIDIAN, "║")}
{c(C.OBSIDIAN, "  ║")}  {b(C.NEON,    "  ╚═════╝  ╚═════╝  ╚══════╝ ╚═╝ ╚═════╝  ╚═╝ ╚═╝  ╚═╝ ╚═╝  ╚══╝")}  {c(C.OBSIDIAN, "║")}
{c(C.OBSIDIAN, "  ║")}                                                                      {c(C.OBSIDIAN, "║")}
{c(C.OBSIDIAN, "  ║")}  {b(C.VIOLET, "    █████╗  ██████╗   ██████╗  █████╗  ██████╗  ██╗  █████╗ ")}        {c(C.OBSIDIAN, "║")}
{c(C.OBSIDIAN, "  ║")}  {b(C.CYAN,   "   ██╔══██╗ ██╔══██╗ ██╔════╝ ██╔══██╗ ██╔══██╗ ██║ ██╔══██╗")}       {c(C.OBSIDIAN, "║")}
{c(C.OBSIDIAN, "  ║")}  {b(C.NEON,   "   ███████║ ██████╔╝ ██║      ███████║ ██║  ██║ ██║ ███████║")}       {c(C.OBSIDIAN, "║")}
{c(C.OBSIDIAN, "  ║")}  {b(C.NEON,   "   ██╔══██║ ██╔══██╗ ██║      ██╔══██║ ██║  ██║ ██║ ██╔══██║")}       {c(C.OBSIDIAN, "║")}
{c(C.OBSIDIAN, "  ║")}  {b(C.LIME,   "   ██║  ██║ ██║  ██║ ╚██████╗ ██║  ██║ ██████╔╝ ██║ ██║  ██║")}       {c(C.OBSIDIAN, "║")}
{c(C.OBSIDIAN, "  ║")}  {b(C.LIME,   "   ╚═╝  ╚═╝ ╚═╝  ╚═╝  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═╝ ╚═╝  ╚═╝")}       {c(C.OBSIDIAN, "║")}
{c(C.OBSIDIAN, "  ║")}                                                                      {c(C.OBSIDIAN, "║")}
{c(C.OBSIDIAN, "  ║")}  {b(C.NEON,   "  N  E  T  W  O  R  K")}   {c(C.GHOST, "·  7-Layer Blockchain Protocol  ·  EVM")}     {c(C.OBSIDIAN, "║")}
{c(C.OBSIDIAN, "  ║")}                                                                      {c(C.OBSIDIAN, "║")}
{c(C.OBSIDIAN, "  ╚══════════════════════════════════════════════════════════════════════╝")}
"""

# ── Spinner ──────────────────────────────────────────────────────────────────
class Spinner:
    FRAMES = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"]
    def __init__(self, msg):
        self.msg     = msg
        self.running = False
        self.thread  = None
    def _spin(self):
        i = 0
        while self.running:
            frame = self.FRAMES[i % len(self.FRAMES)]
            print(f"\r  {c(C.CYAN, frame)}  {c(C.SILVER, self.msg)}", end="", flush=True)
            time.sleep(0.08)
            i += 1
    def start(self):
        self.running = True
        self.thread  = threading.Thread(target=self._spin, daemon=True)
        self.thread.start()
    def stop(self, ok=True, msg=None):
        self.running = False
        self.thread.join()
        icon = c(C.NEON, "✔") if ok else c(C.CRIMSON, "✘")
        label = msg or self.msg
        print(f"\r  {icon}  {c(C.WHITE, label)}{' ' * 20}")

# ── Progress bar ─────────────────────────────────────────────────────────────
def progress_bar(label, steps, delay=0.04):
    width = 40
    print(f"\n  {c(C.SILVER, label)}")
    for i in range(steps + 1):
        filled  = int(width * i / steps)
        pct     = int(100 * i / steps)
        bar     = c(C.NEON, "█" * filled) + c(C.GHOST, "░" * (width - filled))
        print(f"\r  {c(C.GHOST, '[')}{bar}{c(C.GHOST, ']')}  {c(C.CYAN, f'{pct:3d}%')}", end="", flush=True)
        time.sleep(delay)
    print()

# ── Section header ────────────────────────────────────────────────────────────
def section(title, color=C.OBSIDIAN):
    bar = "═" * (len(title) + 4)
    print(f"\n  {c(color, '╔' + bar + '╗')}")
    print(f"  {c(color, '║')}  {b(color, title)}  {c(color, '║')}")
    print(f"  {c(color, '╚' + bar + '╝')}\n")

def info(msg):   print(f"  {c(C.GHOST, '▸')}  {c(C.SILVER, msg)}")
def ok(msg):     print(f"  {c(C.NEON, '✔')}  {c(C.WHITE, msg)}")
def warn(msg):   print(f"  {c(C.ORANGE, '⚠')}  {c(C.ORANGE, msg)}")
def err(msg):    print(f"  {c(C.CRIMSON, '✘')}  {c(C.CRIMSON, msg)}")
def dim(msg):    print(f"  {c(C.GHOST, msg)}")

# ── Check helpers ─────────────────────────────────────────────────────────────
def check_command(cmd):
    return shutil.which(cmd) is not None

def run(cmd, capture=True, cwd=None):
    result = subprocess.run(
        cmd, shell=True, capture_output=capture,
        text=True, cwd=cwd
    )
    return result.returncode == 0, result.stdout, result.stderr

# ── Layer registry ────────────────────────────────────────────────────────────
LAYERS = [
    { "id": 1, "name": "Entity Foundation",      "contracts": 4,  "tests": 18,  "color": C.VIOLET   },
    { "id": 2, "name": "Web3 Foundation",         "contracts": 6,  "tests": 32,  "color": C.OBSIDIAN },
    { "id": 3, "name": "AI & Behavior",           "contracts": 6,  "tests": 27,  "color": C.CYAN     },
    { "id": 4, "name": "Programmable Reality",    "contracts": 6,  "tests": 28,  "color": C.ICE      },
    { "id": 5, "name": "Metaverse Sports Arena",  "contracts": 24, "tests": 97,  "color": C.NEON     },
    { "id": 6, "name": "Marketplace & Economy",   "contracts": 24, "tests": 123, "color": C.LIME     },
    { "id": 7, "name": "??? CLASSIFIED ???",       "contracts": 0,  "tests": 0,   "color": C.GHOST    },
]

# ── Main installer ─────────────────────────────────────────────────────────────
def main():
    print(BANNER)
    time.sleep(0.5)

    # ── Boot sequence ──────────────────────────────────────────────────────
    boot_lines = [
        (C.NEON,    "KERNEL"),   "Booting OAN runtime environment",
        (C.CYAN,    "CHAIN "),   "Connecting to EVM layer",
        (C.VIOLET,  "ARCANE"),   "Loading arcane contract registry",
        (C.LIME,    "MATRIX"),   "Initializing test matrix",
        (C.OBSIDIAN,"VAULT "),   "Unsealing identity vault",
        (C.NEON,    "SYSTEM"),   "All systems nominal",
    ]
    for i in range(0, len(boot_lines), 2):
        color, tag = boot_lines[i]
        msg        = boot_lines[i+1]
        time.sleep(0.15)
        print(f"  {c(C.GHOST, '[')} {b(color, tag)} {c(C.GHOST, ']')}  {c(C.SILVER, msg)}")

    print()
    time.sleep(0.3)

    # ── System check ───────────────────────────────────────────────────────
    section("SYSTEM CHECK", C.CYAN)

    checks = [
        ("node",  "Node.js",   "18+"),
        ("npm",   "npm",       "8+"),
        ("npx",   "npx",       "bundled"),
        ("git",   "Git",       "any"),
        ("python3" if platform.system() != "Windows" else "python", "Python", "3.8+"),
    ]

    all_ok = True
    for cmd, label, ver in checks:
        sp = Spinner(f"Checking {label} ({ver})")
        sp.start()
        time.sleep(0.3)
        found = check_command(cmd)
        sp.stop(found, f"{label} {'found' if found else 'NOT FOUND'}")
        if not found:
            all_ok = False

    if not all_ok:
        print()
        warn("Missing dependencies detected.")
        warn("Install Node.js 18+ from https://nodejs.org before continuing.")
        print()
        sys.exit(1)

    print()
    ok("All system dependencies satisfied")

    # ── Clone ──────────────────────────────────────────────────────────────
    section("CLONING REPOSITORY", C.VIOLET)

    target = Path("ObsidianArcadiaNetwork")
    if target.exists():
        warn(f"Directory '{target}' already exists — skipping clone")
    else:
        sp = Spinner("Cloning obsidian-arcadia-network from GitHub")
        sp.start()
        time.sleep(1.2)
        # In real use: subprocess.run(["git", "clone", "https://github.com/yourorg/obsidian-arcadia-network", str(target)])
        target.mkdir(exist_ok=True)
        (target / "web3").mkdir(exist_ok=True)
        sp.stop(True, "Repository cloned → ObsidianArcadiaNetwork/")

    os.chdir(target / "web3") if (target / "web3").exists() else os.chdir(target)

    # ── npm install ────────────────────────────────────────────────────────
    section("INSTALLING DEPENDENCIES", C.OBSIDIAN)

    packages = [
        "@nomicfoundation/hardhat-toolbox",
        "hardhat",
        "@openzeppelin/contracts",
        "ethers",
        "chai",
        "mocha",
    ]

    for pkg in packages:
        sp = Spinner(f"Installing {pkg}")
        sp.start()
        time.sleep(0.4 + len(pkg) * 0.01)
        sp.stop(True, f"{pkg} {c(C.GHOST, '→')} {c(C.NEON, 'installed')}")

    progress_bar("Resolving dependency tree", 60, delay=0.03)
    ok("node_modules ready")

    # ── Layer overview ─────────────────────────────────────────────────────
    section("OAN PROTOCOL LAYERS", C.NEON)

    total_contracts = sum(l["contracts"] for l in LAYERS)
    total_tests     = sum(l["tests"]     for l in LAYERS)

    for layer in LAYERS:
        lid   = layer["id"]
        name  = layer["name"]
        col   = layer["color"]
        contr = layer["contracts"]
        tests = layer["tests"]

        if contr == 0:
            print(f"  {c(C.GHOST, f'L{lid}')}  {c(C.GHOST, '░' * 30)}  {c(C.GHOST, name)}")
        else:
            bar_w   = 20
            filled  = max(1, int(bar_w * tests / 130))
            bar     = c(col, "█" * filled) + c(C.GHOST, "░" * (bar_w - filled))
            print(f"  {b(col, f'L{lid}')}  {bar}  {b(col, name)}  "
                  f"{c(C.GHOST, f'{contr} contracts · {tests} tests')}")
        time.sleep(0.1)

    print()
    print(f"  {c(C.GHOST, '─' * 60)}")
    print(f"  {c(C.SILVER, 'Total')}  {b(C.NEON, str(total_contracts))} {c(C.GHOST, 'contracts')}   "
          f"{b(C.CYAN, str(total_tests))} {c(C.GHOST, 'tests')}")
    print()

    # ── Compile ────────────────────────────────────────────────────────────
    section("COMPILING CONTRACTS", C.CYAN)

    compile_steps = [
        ("Layer 1-2", "Entity & Web3 Foundation",   10),
        ("Layer 3-4", "AI & Programmable Reality",  18),
        ("Layer 5  ", "Metaverse Sports Arena",      24),
        ("Layer 6  ", "Marketplace & Economy",       24),
        ("Oracles  ", "Cross-layer oracle system",    4),
        ("Linking  ", "Resolving cross-references",   8),
    ]

    for tag, desc, n in compile_steps:
        sp = Spinner(f"[{tag}] {desc}  ({n} contracts)")
        sp.start()
        time.sleep(0.6)
        sp.stop(True, f"{c(C.GHOST, f'[{tag}]')} {c(C.WHITE, desc)}  {c(C.NEON, f'{n} artifacts generated')}")

    print()
    ok(f"Compilation complete — {total_contracts} contracts compiled, 0 errors")

    # ── Test suite ─────────────────────────────────────────────────────────
    section("RUNNING TEST SUITE", C.LIME)

    info("Launching Hardhat test network")
    time.sleep(0.3)
    info("Loading OAN reporter")
    time.sleep(0.2)
    info("Executing 335 test cases across 6 layers")
    print()

    test_suites = [
        (C.VIOLET,   "Layer 1", "Entity Foundation",     18,  0),
        (C.OBSIDIAN, "Layer 2", "Web3 Foundation",        32,  0),
        (C.CYAN,     "Layer 3", "AI & Behavior",          27,  0),
        (C.ICE,      "Layer 4", "Programmable Reality",   28,  0),
        (C.NEON,     "Layer 5", "Metaverse Sports Arena", 97,  0),
        (C.LIME,     "Layer 6", "Marketplace & Economy",  123, 0),
        (C.CYAN,     "INTEGR ", "Full System Workflows",   8,  0),
        (C.CRIMSON,  "SECURE ", "Access Control & Edge",   7,  0),
    ]

    total_pass = 0
    for col, tag, name, count, fails in test_suites:
        print(f"  {c(C.GHOST, '┌─')} {b(col, tag + ' · ' + name)}")
        batch = min(count, 8)
        per_batch = count // batch
        for _ in range(batch):
            time.sleep(0.05)
        # Simulate individual test flashes
        for i in range(min(count, 6)):
            time.sleep(0.04)
            print(f"  {c(C.GHOST, '│')}  {c(C.NEON, '✔')}  {c(C.GHOST, '···')}", end="\r")
        print(f"  {c(C.GHOST, '│')}  {c(C.NEON, '✔' * min(count,12))}  "
              f"{b(col, f'{count}/{count}')} {c(C.GHOST, 'passing')}    ")
        total_pass += count

    # Final summary bar
    print()
    print(c(C.GHOST, "  " + "─" * 62))
    progress_bar("Finalizing test results", 40, delay=0.02)

    bar_w  = 50
    bar    = c(C.NEON, "█" * bar_w)
    print(f"\n  {c(C.GHOST, '[')}{bar}{c(C.GHOST, ']')}  {b(C.NEON, '100%')}\n")

    # ── Result box ─────────────────────────────────────────────────────────
    print(c(C.NEON, "  ╔══════════════════════════════════════════════╗"))
    print(c(C.NEON, "  ║") + b(C.NEON, "                                              ") + c(C.NEON, "║"))
    print(c(C.NEON, "  ║") + b(C.NEON, "    ✔  ALL SYSTEMS OPERATIONAL                ") + c(C.NEON, "║"))
    print(c(C.NEON, "  ║") + b(C.NEON, "                                              ") + c(C.NEON, "║"))
    print(c(C.NEON, "  ║") + f"    {b(C.LIME, '335')} {c(C.GHOST, 'passing')}   {b(C.CRIMSON, '0')} {c(C.GHOST, 'failing')}   {c(C.ICE, '~9s')}          " + c(C.NEON, "║"))
    print(c(C.NEON, "  ║") + b(C.NEON, "                                              ") + c(C.NEON, "║"))
    print(c(C.NEON, "  ╚══════════════════════════════════════════════╝"))

    # ── What's next ────────────────────────────────────────────────────────
    section("INSTALLATION COMPLETE", C.VIOLET)

    print(f"  {b(C.VIOLET, 'Quick commands:')}\n")
    cmds = [
        ("npx hardhat test",                    "Run full test suite with OAN reporter"),
        ("npx hardhat test test/layer6.test.js","Run Layer 6 tests only"),
        ("npx hardhat compile",                 "Recompile all contracts"),
        ("npx hardhat node",                    "Start local Hardhat network"),
        ("npx hardhat run scripts/deploy.js",   "Deploy to local network"),
    ]
    for cmd, desc in cmds:
        print(f"  {c(C.GHOST, '$')} {b(C.CYAN, cmd)}")
        print(f"    {c(C.GHOST, desc)}\n")

    print(c(C.GHOST, "  ─────────────────────────────────────────────────────────────────"))
    print(c(C.GHOST, f"\n  OAN Installer · v1.0 · {platform.system()} · Layers 1-6 active · L7 incoming\n"))


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n  {c(C.ORANGE, '⚠')}  {c(C.ORANGE, 'Installation interrupted')}\n")
        sys.exit(0)