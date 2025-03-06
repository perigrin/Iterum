# Iterum Debug Features

This document explains the debugging features available in the Iterum UI system.

## Enabling Debug Mode

There are two ways to enable debugging:

1. **Environment Variable**: Setting `ITERUM_DEBUG=1` before running Iterum will enable debug logging automatically:
   ```
   ITERUM_DEBUG=1 perl bin/iterum
   ```

2. **Debug Keys**: During gameplay, press the tilde key (`~`) to toggle debug logging.

## Debug Features

### 1. UI Region Visualization

Press the backtick key (`` ` ``) during gameplay to toggle region visualization. This will draw boxes around each UI region with labels, helping you understand how the UI is organized.

Regions include:
- `header`: The title bar at the top
- `player`: The player status area
- `enemy`: The enemy status area
- `messages`: The message history box
- `combat_options`: The area showing available combat actions
- `input`: The area for user input

### 2. Debug Logging

When enabled, debug logging tracks all UI operations and state changes. The log includes:

- **Operations**: Method calls like `display_status`, `display_combat_options`, etc.
- **Snapshots**: Captures of the UI state including cursor position, screen dimensions, and region definitions
- **User Input**: Records of key presses and input handling

Debug logs are automatically written to a file named `iterum_debug_log_<timestamp>.txt` when debug mode is disabled or the game exits.

### 3. Debug Snapshots

The system can capture the current UI state at key points. Each snapshot includes:
- Cursor position
- Screen dimensions
- UI region definitions
- Timestamp

### 4. Viewing Debug Logs

Debug logs are saved with a timestamp in the filename. Each log entry includes:
- Entry type (operation, snapshot, etc.)
- Timestamp
- Method name and arguments for operations
- Detailed state information for snapshots

## For Developers

### Adding Debug Logging to New Methods

To add debug logging to a method:

```perl
method your_method($arg1, $arg2) {
    # Log the operation
    $self->_log_operation('your_method', $arg1, $arg2);
    
    # Take a snapshot if needed
    $self->debug_snapshot("your_method called");
    
    # Method implementation...
}
```

### Creating Custom Debug Views

You can create custom debug visualizations by:

1. Creating a new method in `CLI.pm`
2. Using the existing debug regions or creating custom ones with `debug_set_region`
3. Rendering content in those regions with `render_in_region`

### Running Debug Tests

Run the debug feature tests with:

```
perl -Ilib t/ui/debug_features.t
```
