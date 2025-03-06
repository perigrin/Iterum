# Iterum UI Regions Guide

This document explains the UI regions used in Iterum's layout system.

## Overview

Iterum uses a region-based layout system where each UI element is rendered within a specific region. This ensures consistency, prevents overlap, and makes the interface more adaptable to different terminal sizes.

## Region Structure

UI regions are defined in the `define_ui_regions` method in `CLI.pm`. Each region has:

- `row`: The top row coordinate (0-based)
- `col`: The leftmost column coordinate (0-based)
- `width`: The width in characters
- `height`: The height in lines

## Core Regions

| Region | Description | Used By | Dimensions |
|--------|-------------|---------|------------|
| `header` | Top bar of the screen | `display_header` | Full width, 2 lines high |
| `title` | Area for centered titles | `display_title` | Full width, 1 line high |
| `player` | Player status area | `display_player_status` | Left half of screen, 4 lines high |
| `enemy` | Enemy status area | `display_enemy_status` | Right half of screen, 4 lines high |
| `messages` | Message history box | `display_message_history` | Full width, 8 lines high |

## Info Display Regions

| Region | Description | Used By | Dimensions |
|--------|-------------|---------|------------|
| `result` | Combat result display | `display_result` | Full width, 5 lines high |
| `ev_feedback` | AI coach feedback | `display_ev_feedback` | Full width, 5 lines high |
| `score_summary` | EV score summary | `display_score_summary` | Full width, 5 lines high |

## Input/Output Regions

| Region | Description | Used By | Dimensions |
|--------|-------------|---------|------------|
| `combat_options` | Available combat actions | `display_combat_options` | Full width, 6 lines high |
| `input` | User input area | `get_input`, `get_combat_action` | Full width, 3 lines high |

## Full Screen Regions

| Region | Description | Used By | Dimensions |
|--------|-------------|---------|------------|
| `decision_history` | Display of decision history | `display_decision_history` | Full screen (minus bottom line) |

## How to Use Regions

To render content within a region:

```perl
$self->render_in_region(
    'region_name',
    sub {
        my $region = shift;
        
        # Use region coordinates for positioning
        $buffer->put_string(
            $region->{row}, 
            $region->{col},
            "Content within region"
        );
        
        # Use $region->{width} and $region->{height} for boundary checks
    }
);
```

## Region Visualization

During gameplay, press the backtick key (`` ` ``) to toggle region visualization. This will draw boxes around each region with labels, which is extremely helpful for debugging layout issues.

## Adding New Regions

To add a new region:

1. Update `define_ui_regions` method in `CLI.pm`
2. Ensure the new region doesn't overlap with existing regions
3. Use `render_in_region` to draw within the region

## Best Practices

1. Always use `render_in_region` instead of direct positioning
2. Check region boundaries before rendering to prevent overflow
3. For full-screen displays, use the appropriate full-screen region
4. Be mindful of terminal size variations
5. Use region visualization when developing new UI components

## Region Layout Diagram

```
+----------------------------------------------------------+
|                        header                             |
+----------------------------------------------------------+
|                        title                              |
+----------------------+-----------------------------------+
|                      |                                   |
|       player         |             enemy                 |
|                      |                                   |
+----------------------+-----------------------------------+
|                                                          |
|                       messages                           |
|                                                          |
|                                                          |
+----------------------------------------------------------+
|                                                          |
|              result / ev_feedback / score_summary        |
|                                                          |
+----------------------------------------------------------+
|                                                          |
|                     combat_options                       |
|                                                          |
+----------------------------------------------------------+
|                        input                             |
+----------------------------------------------------------+
```
