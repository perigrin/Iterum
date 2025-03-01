# Iterum - EV-Based Roguelike

Iterum is a decision-driven roguelike where Expected Value (EV) analysis determines decision quality rather than outcomes. The game evaluates combat, exploration, and resource management using an Entity Component System (ECS) architecture, built in Perl with a command-line interface (CLI).

## Project Structure

The project follows a standard Perl project structure compatible with Module::Build::Tiny:

```
/iterum/
  ├── script/                  # Executable scripts (per Module::Build::Tiny convention)
  │   └── iterum               # Main game script
  ├── lib/                     # Libraries
  │   └── Iterum/              # Main namespace
  │       ├── ECS.pm           # ECS implementation
  │       ├── Entities/        # Entity classes
  │       ├── Components/      # Component classes
  │       ├── Systems/         # System classes
  │       └── UI/              # User Interface
  ├── data/                    # Game data
  │   └── ev_lookup.json
  ├── t/                       # Tests
  │   ├── ecs.t                # ECS tests
  │   ├── components/          # Component tests
  │   ├── entities/            # Entity tests
  │   └── systems/             # System tests
  ├── Build.PL                 # Module::Build::Tiny build script
  ├── LICENSE                  # Artistic License 2.0
  ├── MANIFEST                 # List of included files
  ├── META.yml                 # Module metadata
  └── cpanfile                 # Dependencies
```

## Prerequisites

- Perl 5.40.0 or higher
- SQLite
- Required CPAN modules (listed in cpanfile)

## Setup

1. Clone the repository
2. Install dependencies:
   ```
   cpanm --installdeps .
   ```
3. Build the module:
   ```
   perl Build.PL
   ./Build
   ```

## Running Tests

```
./Build test
```

Or alternatively:

```
prove -lvr t/
```

## Running the Game

```
./script/iterum
```

## Installation

To install the game:

```
./Build install
```

## Development

The project follows a test-driven development approach. For each component:

1. Write tests first in the appropriate test file under the `t/` directory
2. Implement the component in the appropriate module file
3. Run tests to verify functionality
4. Integrate with other components

## Game Mechanics

Iterum uses an EV-based decision system where:
- Each action has an expected value (EV) score based on risk/reward calculations
- Player decisions are evaluated dynamically, considering both immediate and multi-turn impact
- AI Coach provides feedback based on patterns rather than isolated mistakes

The ECS architecture breaks entities into components & systems for flexibility and scalability:
- Entities: Objects in the game (Player, Enemy, Trap, AI Coach)
- Components: Store entity data (Health, EV Score, AI State)
- Systems: Process entity behavior (CombatSystem, EVScoringSystem, AISystem)
