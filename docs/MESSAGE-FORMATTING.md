# Iterum Message Formatting

This document explains the message formatting system in Iterum's UI.

## Overview

Iterum uses a sophisticated message system that provides clear visual feedback to the player during gameplay. The message system includes:

- A message history box that displays recent messages
- Distinct formatting for different message types (combat, EV, system, error)
- Message coalescing to avoid redundancy
- Proper text wrapping and indentation
- Timestamps to indicate when messages occurred

## Message Types

### System Messages

System messages provide general information about the game state.

```
ℹ [2s] Game started
```

System messages use the `add_system_message()` method and are displayed with an info icon (ℹ).

### Combat Messages

Combat messages provide information about combat actions and results.

```
⚔ [5s] Action: attack - ✓ Success! Damage dealt: 15
```

Combat messages use the `add_combat_message()` method and are displayed with crossed swords (⚔).

### EV Messages

EV messages provide feedback about the expected value of player decisions.

```
★ [10s] EV Score: 0.85 (Excellent)
```

EV messages use the `add_ev_message()` method and are displayed with a star (★).

### Error Messages

Error messages provide information about errors or warnings.

```
⚠ [3s] Invalid action. Please try again.
```

Error messages use the `add_error_message()` method and are displayed with a warning icon (⚠).

## Message Coalescing

When multiple identical messages occur within a short timeframe, they are coalesced into a single message with a count indicator:

```
ℹ [12s] Enemy approaching [×3]
```

The coalescing time window can be configured using the `configure_message_display()` method.

## Message Display Components

### Message History Box

The message history box displays recent messages with a double-line border for emphasis:

```
╔════════════ Messages (5) ═════════════╗
║                                       ║
║ ⚔ [2s] Action: attack                 ║
║ ★ [2s] EV Score: 0.75 (Good)          ║
║ ℹ [5s] Enemy approaching              ║
║ ⚠ [8s] Health critical!               ║
║                                 [MORE ▼]║
╚═══════════════════════════════════════╝
```

The box includes a count of total messages and a scrolling indicator.

### Result Box

Combat results are displayed in a box with a single-line border:

```
┌──────────── ACTION RESULT ────────────┐
│                                       │
│ Action: attack                        │
│ ✓ Success! Damage dealt: 15           │
│ EV Score: 0.85 (Excellent)            │
│                                       │
└───────────────────────────────────────┘
```

### EV Feedback Box

AI coach feedback is displayed in a box with a slanted border:

```
┏━━━━━━━━━━ AI COACH FEEDBACK ━━━━━━━━━━┓
┃                                       ┃
┃ ◆ Good choice attacking when enemy    ┃
┃   was weak                            ┃
┃ ◆ Consider defending when your health ┃
┃   is low                              ┃
┃                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

### Score Summary Box

EV score summaries are displayed in a box with rounded corners:

```
╭────────── EV SCORE SUMMARY ───────────╮
│                                       │
│ Total Score: 75 (Good)                │
│ [===============================     ]│
│ ✔ Best Decision: attack when weak     │
│ ✖ Worst Decision: defend at full HP   │
│                                       │
╰───────────────────────────────────────╯
```

Includes a graphical score indicator bar.

## Configuration

The message display can be configured using the `configure_message_display()` method:

```perl
$cli->configure_message_display({
    max_messages => 20,           # Maximum number of messages to keep
    coalesce_time => 2,           # Time window for coalescing (seconds)
    timestamp_display => 1        # Whether to show timestamps
});
```

## Message Display Methods

- `add_message(message, type, color)`: Add a message with a specified type and color
- `add_system_message(message, color)`: Add a system message (shortcut)
- `add_combat_message(message, color)`: Add a combat message (shortcut)
- `add_ev_message(message, color)`: Add an EV message (shortcut)
- `add_error_message(message)`: Add an error message (shortcut)
- `display_message_history()`: Force refresh of the message history display
- `clear_messages()`: Clear all messages from history
- `get_message_stats()`: Get statistics about current messages

## For Developers

### Adding New Message Types

To add a new message type:

1. Choose a distinctive icon for the message type
2. In `display_message_history()`, add a new condition for the message type
3. Add a convenience method for adding the new message type

### Customizing Message Appearance

The message style for each message type can be customized by modifying:

- The prefix icon
- The default color
- Whether the message is displayed in bold

These settings are defined in the `display_message_history()` method.

### Testing Message Formatting

Tests for message formatting are available in `t/ui/message_formatting.t`.
