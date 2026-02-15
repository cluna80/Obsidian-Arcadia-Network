from rich.table import Table
from rich.console import Console

console = Console()

def show_dashboard(entities):
    table = Table(title="🌑 Obsidian Arcadia Network — Active Entities")

    table.add_column("Entity", style="magenta")
    table.add_column("Intent", style="cyan")
    table.add_column("Mode", style="yellow")
    table.add_column("World", style="green")
    table.add_column("Reputation", style="white")

    for e in entities:
        table.add_row(
            e.name,
            e.intent,
            e.mode,
            e.world,
            str(e.reputation)
        )

    console.print(table)
