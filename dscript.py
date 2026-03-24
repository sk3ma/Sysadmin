#!/usr/bin/env python3

#########################################
# DeathScript - Dramatic CLI Playground #
#########################################

from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from time import sleep
import os
import sys
import readline

console = Console()

VERSION = "1.0"
MODE = "safe"

def welcome_banner() -> None:
    console.print("""
[red]
 ██████╗ ███████╗ █████╗ ████████╗██╗  ██╗███████╗ ██████╗██████╗ ██╗██████╗ ████████╗
 ██╔══██╗██╔════╝██╔══██╗╚══██╔══╝██║  ██║██╔════╝██╔════╝██╔══██╗██║██╔══██╗╚══██╔══╝
 ██║  ██║█████╗  ███████║   ██║   ███████║███████╗██║     ██████╔╝██║██████╔╝   ██║   
 ██║  ██║██╔══╝  ██╔══██║   ██║   ██╔══██║╚════██║██║     ██╔══██╗██║██╔═══╝    ██║   
 ██████╔╝███████╗██║  ██║   ██║   ██║  ██║███████║╚██████╗██║  ██║██║██║        ██║   
 ╚═════╝ ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═╝        ╚═╝   
[/]
""")
    console.print(
        Panel.fit(
            "Type [green]help[/] to see commands.\n",
            style="blue"
        )
    )

def show_help():
    table = Table(title="Available Commands")

    table.add_column("Command", style="cyan")
    table.add_column("Description", style="white")

    table.add_row("help", "Show this help menu")
    table.add_row("about", "What is DeathScript?")
    table.add_row("clear", "Clear the screen")
    table.add_row("exit", "Terminate DeathScript")
    table.add_row("version", "Show version info")
    table.add_row("mode <safe|chaos>", "Switch operating mode")

    console.print(table)

def show_about():
    console.print(Panel("""
DeathScript is a dramatic CLI sandbox.

It detects cursed commands and blocks destructive behaviour.
Mostly it exists for chaos and vibes.

Type wisely.
""", title="About DeathScript", style="magenta"))

def set_mode(new_mode):
    global MODE
    if new_mode not in ["safe", "chaos"]:
        console.print("[red]Invalid mode. Use 'safe' or 'chaos'.[/]")
        return

    MODE = new_mode
    console.print(f"[bold red]Mode switched to {MODE}.[/]")

def handle_input(user_input: str) -> None:
    cursed_inputs = {
        ":(){ :|:& };:": "Fork bomb detected",
        "mv / /dev/null": "Filesystem annihilation attempt detected",
        "rm -rf /": "Root-level self-destruction attempt detected",
    }

    cmd = user_input.strip()
    if not cmd:
        return

    parts = cmd.split()
    command = parts[0]
    args = parts[1:]

    if command == "help":
        show_help()
        return

    if command == "about":
        show_about()
        return

    if command == "clear":
        os.system("clear")
        return

    if command == "exit":
        console.print("[dim]DeathScript terminated safely.[/]")
        sys.exit(0)

    if command == "version":
        console.print(f"[green]DeathScript v{VERSION}[/]")
        return

    if command == "mode":
        if not args:
            console.print("[red]Usage: mode <safe|chaos>[/]")
        else:
            set_mode(args[0])
        return

    if cmd in cursed_inputs and MODE == "safe":
        console.print(f"[bold red]{cursed_inputs[cmd]}[/]")
        sleep(1)
        console.print("[blue]Absolutely not. Step away from the keyboard.[/]")
        sleep(1)
        console.print("[dim]Incident logged (emotionally, not on disk).[/]")
        return

    if MODE == "chaos":
        console.print(f"[bold red]Executing:[/] {cmd}")
        sleep(0.5)
        console.print("[green]Operation complete. Probably.[/]")
        return

    console.print(f"[red]Unknown command:[/] {cmd}")
    console.print("[dim]Type 'help' to see available commands.[/]")

if __name__ == "__main__":
    welcome_banner()
    try:
        while True:
            console.print(f"[bold yellow]DeathScript[/] ({MODE}) >", end=" ")
            user_input = input()
            handle_input(user_input)
    except KeyboardInterrupt:
        console.print("\n[dim]DeathScript terminated safely.[/]")
