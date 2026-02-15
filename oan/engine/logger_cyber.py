"""
OAN Cyberpunk Logger
Dark, glitchy, rogue AI lab aesthetic
"""

from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.text import Text
from rich.style import Style
from rich.theme import Theme
from rich import box
from datetime import datetime


# Initialize console with custom theme
custom_theme = Theme({
    "info": "cyan",
    "warning": "yellow",
    "error": "bold red",
    "success": "bold green",
    "cyber": "bold magenta",
    "neon": "bold bright_cyan",
    "danger": "bold red"
})

console = Console(theme=custom_theme)


# State color mapping
STATE_COLORS = {
    'Active': 'bold green',
    'Overclocked': 'bold magenta',
    'Recovery': 'bold yellow',
    'Elite': 'bold cyan',
    'Degraded': 'bold red',
    'Emergency': 'bold red',
    'Idle': 'dim white',
    'Suspended': 'dim yellow',
    'Terminated': 'dim red',
}


def print_ascii_header():
    """Print cyberpunk ASCII art header"""
    header = """
[bold magenta]
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║     ██████╗ ██████╗ ███████╗██╗██████╗ ██╗ █████╗ ███╗   ██╗    ║
║    ██╔═══██╗██╔══██╗██╔════╝██║██╔══██╗██║██╔══██╗████╗  ██║    ║
║    ██║   ██║██████╔╝███████╗██║██║  ██║██║███████║██╔██╗ ██║    ║
║    ██║   ██║██╔══██╗╚════██║██║██║  ██║██║██╔══██║██║╚██╗██║    ║
║    ╚██████╔╝██████╔╝███████║██║██████╔╝██║██║  ██║██║ ╚████║    ║
║     ╚═════╝ ╚═════╝ ╚══════╝╚═╝╚═════╝ ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝    ║
║                                                                   ║
║      █████╗ ██████╗  ██████╗ █████╗ ██████╗ ██╗ █████╗          ║
║     ██╔══██╗██╔══██╗██╔════╝██╔══██╗██╔══██╗██║██╔══██╗         ║
║     ███████║██████╔╝██║     ███████║██║  ██║██║███████║         ║
║     ██╔══██║██╔══██╗██║     ██╔══██║██║  ██║██║██╔══██║         ║
║     ██║  ██║██║  ██║╚██████╗██║  ██║██████╔╝██║██║  ██║         ║
║     ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═════╝ ╚═╝╚═╝  ╚═╝         ║
║                                                                   ║
║                 ███╗   ██╗███████╗████████╗                      ║
║                 ████╗  ██║██╔════╝╚══██╔══╝                      ║
║                 ██╔██╗ ██║█████╗     ██║                         ║
║                 ██║╚██╗██║██╔══╝     ██║                         ║
║                 ██║ ╚████║███████╗   ██║                         ║
║                 ╚═╝  ╚═══╝╚══════╝   ╚═╝                         ║
║                                                                   ║
║               [bold cyan]R O G U E   A I   L A B[/bold cyan]                      ║
║           [dim]>> Autonomous Entity Network v1.0 <<[/dim]           ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
[/bold magenta]
"""
    console.print(header)


def log_system(message: str, style: str = "info"):
    """Log system message with cyberpunk styling"""
    timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
    
    # Style mapping
    styles = {
        "info": "cyan",
        "success": "bold green",
        "warning": "bold yellow",
        "error": "bold red",
        "cyber": "bold magenta",
    }
    
    color = styles.get(style, "cyan")
    console.print(f"[dim]{timestamp}[/dim] [{color}][SYSTEM][/{color}] {message}")


def log_entity_cyber(entity):
    """Display entity info with cyberpunk aesthetic"""
    
    # Build entity panel
    entity_info = Table(show_header=False, box=box.HEAVY, border_style="cyan")
    entity_info.add_column("Key", style="bold cyan")
    entity_info.add_column("Value", style="bright_white")
    
    # Add rows
    entity_info.add_row("ENTITY_ID", f"[bold magenta]{entity.name}[/bold magenta]")
    entity_info.add_row("TYPE", f"[cyan]{entity.type}[/cyan]")
    
    # State with color
    state_color = STATE_COLORS.get(entity.state, 'white')
    entity_info.add_row("STATE", f"[{state_color}]► {entity.state}[/{state_color}]")
    
    # Energy bar
    energy = getattr(entity, 'energy', 0)
    energy_bar = create_energy_bar(energy)
    entity_info.add_row("ENERGY", energy_bar)
    
    # Reputation
    reputation = getattr(entity, 'reputation', 0)
    rep_color = "green" if reputation > 50 else "yellow" if reputation > 0 else "red"
    entity_info.add_row("REPUTATION", f"[{rep_color}]{reputation}[/{rep_color}]")
    
    # Tools
    if entity.binds:
        tools_str = ", ".join([f"[magenta]{t}[/magenta]" for t in entity.binds[:3]])
        if len(entity.binds) > 3:
            tools_str += f" [dim]+{len(entity.binds)-3} more[/dim]"
        entity_info.add_row("TOOLS", tools_str)
    
    # Create panel
    panel = Panel(
        entity_info,
        title="[bold cyan]◢ ENTITY MANIFEST ◣[/bold cyan]",
        subtitle="[dim]Neural threads stabilizing...[/dim]",
        border_style="cyan",
        box=box.DOUBLE_EDGE
    )
    
    console.print(panel)


def create_energy_bar(energy: int, max_energy: int = 100) -> str:
    """Create visual energy bar"""
    percentage = (energy / max_energy) * 100
    filled = int(percentage / 5)
    empty = 20 - filled
    
    if percentage > 70:
        color = "green"
    elif percentage > 30:
        color = "yellow"
    else:
        color = "red"
    
    bar = f"[{color}]{'█' * filled}[/{color}][dim]{'░' * empty}[/dim]"
    return f"{bar} [{color}]{energy}/{max_energy}[/{color}]"


def log_tool(tool_name: str, intent: str = ""):
    """Log tool execution (for tools.py compatibility)"""
    console.print(f"[bold magenta]⚡[/bold magenta] [bold cyan]TOOL[/bold cyan] → [bold white]{tool_name}[/bold white]")
    if intent:
        console.print(f"   [dim]{intent[:50]}...[/dim]" if len(intent) > 50 else f"   [dim]{intent}[/dim]")


def log_tool_execution(tool_name: str, intent: str):
    """Log tool execution"""
    console.print(f"[bold magenta]⚡[/bold magenta] [bold cyan]EXECUTE[/bold cyan] → [bold white]{tool_name}[/bold white]")


def log_reputation_update(entity_name: str, delta: int, total: int):
    """Log reputation changes"""
    sign = "+" if delta > 0 else ""
    color = "green" if delta > 0 else "red"
    console.print(f"[{color}]★ REPUTATION[/{color}] {entity_name}: {sign}{delta} → [bold]{total}[/bold]")


def log_state_transition(entity_name: str, old_state: str, new_state: str):
    """Log state transitions"""
    old_color = STATE_COLORS.get(old_state, 'white')
    new_color = STATE_COLORS.get(new_state, 'white')
    console.print(f"[bold magenta]◆ STATE[/bold magenta] {entity_name}: [{old_color}]{old_state}[/{old_color}] → [{new_color}]{new_state}[/{new_color}]")


def display_cycle_header(cycle: int, total_cycles: int):
    """Display cycle header"""
    console.print(f"\n[bold cyan]═══ CYCLE {cycle}/{total_cycles} ═══[/bold cyan]")


def display_network_hierarchy(entity_manager):
    """Display network hierarchy"""
    console.print("\n")
    
    hierarchy = Table(
        show_header=True,
        header_style="bold cyan",
        border_style="magenta",
        box=box.HEAVY_HEAD,
        title="[bold magenta]◢ NETWORK TOPOLOGY ◣[/bold magenta]"
    )
    
    hierarchy.add_column("NODE", style="cyan")
    hierarchy.add_column("STATE", style="bold")
    hierarchy.add_column("ENERGY", style="green")
    hierarchy.add_column("REP", style="yellow")
    
    for entity_id in entity_manager.entities:
        entity = entity_manager.entities[entity_id]
        is_active = entity_id in entity_manager.active_entities
        
        status = "●" if is_active else "○"
        state_color = STATE_COLORS.get(entity.state, 'white')
        state_str = f"[{state_color}]{entity.state}[/{state_color}]"
        
        energy = getattr(entity, 'energy', 0)
        energy_color = "green" if energy > 70 else "yellow" if energy > 30 else "red"
        energy_str = f"[{energy_color}]{energy}[/{energy_color}]"
        
        rep = getattr(entity, 'reputation', 0)
        rep_color = "green" if rep > 50 else "yellow" if rep > 0 else "red"
        rep_str = f"[{rep_color}]{rep}[/{rep_color}]"
        
        hierarchy.add_row(
            f"{status} {entity.name}",
            state_str,
            energy_str,
            rep_str
        )
    
    stats = entity_manager.get_network_stats()
    footer = f"[dim]Total: {stats['total_entities']} | Active: {stats['active_entities']}[/dim]"
    
    console.print(hierarchy)
    console.print(footer)
    console.print()


def display_final_report(entity, execution_time: float = None):
    """Display final execution report"""
    
    report = Table(
        show_header=False,
        box=box.DOUBLE_EDGE,
        border_style="cyan"
    )
    report.add_column("Metric", style="bold cyan")
    report.add_column("Value", style="bold white")
    
    report.add_row("ENTITY", f"[magenta]{entity.name}[/magenta]")
    report.add_row("FINAL STATE", f"[{STATE_COLORS.get(entity.state, 'white')}]{entity.state}[/{STATE_COLORS.get(entity.state, 'white')}]")
    
    if hasattr(entity, 'energy'):
        energy_bar = create_energy_bar(entity.energy)
        report.add_row("ENERGY", energy_bar)
    
    report.add_row("REPUTATION", f"[yellow]{entity.reputation}[/yellow]")
    
    if execution_time:
        report.add_row("TIME", f"[dim]{execution_time:.2f}s[/dim]")
    
    panel = Panel(
        report,
        title="[bold green]◢ EXECUTION COMPLETE ◣[/bold green]",
        border_style="green",
        box=box.DOUBLE_EDGE
    )
    
    console.print("\n")
    console.print(panel)


def display_glitch_banner():
    """Display glitch effect banner"""
    console.print("[bold magenta]▓▒░ NEURAL NETWORK ACTIVE ░▒▓[/bold magenta]", justify="center")
    console.print()


def log_behavior_engine(message: str, triggered: bool = False):
    """Log behavior engine activity"""
    if triggered:
        console.print(f"[bold magenta]⚡ BEHAVIOR[/bold magenta] {message}")
    else:
        console.print(f"[dim cyan]⚙ BEHAVIOR[/dim cyan] [dim]{message}[/dim]")


def log_execute_engine(tool_name: str, condition_met: bool):
    """Log execute engine decisions"""
    if condition_met:
        console.print(f"[bold green]✓[/bold green] [cyan]EXEC[/cyan] → [bold magenta]{tool_name}[/bold magenta]")
    else:
        console.print(f"[dim]✗ EXEC → {tool_name}[/dim]")
