from rich.console import Console
from rich.panel import Panel
from rich.text import Text
from rich import box
import random

console = Console()

def neon_glitch(text):
    glitches = ["░", "▒", "▓"]
    return "".join(random.choice([c, random.choice(glitches)]) for c in text)

def log_entity(entity):
    title = Text(neon_glitch(" OAN ENTITY LINKED "), style="bold bright_magenta")

    body = f"""
[bright_cyan]ENTITY:[/bright_cyan] {entity.name}
[cyan]INTENT:[/cyan] {entity.intent}
[green]TOOLS:[/green] {", ".join(entity.binds)}
[yellow]MODE:[/yellow] {entity.mode}
[magenta]WORLD:[/magenta] {entity.world}
[white]TOKENIZED:[/white] {entity.tokenized}

[bright_black]Neural threads stabilizing...[/bright_black]
"""

    panel = Panel(body, border_style="bright_magenta", box=box.DOUBLE)
    console.print(panel)

def log_tool(tool_name, intent):
    console.print(
        f"[bright_cyan]⚡ TOOL EXECUTION →[/bright_cyan] "
        f"[magenta]{tool_name}[/magenta] :: "
        f"[cyan]{intent}[/cyan]"
    )

def log_system(message):
    console.print(f"[bright_black]{message}[/bright_black]")
