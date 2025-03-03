use 5.40.0;
use experimental 'class';

class Iterum::Util::Logger {
    use Time::HiRes qw(time);
    use File::Spec;
    use Carp qw(croak);
    
    # Log levels
    use constant {
        DEBUG => 10,
        INFO  => 20,
        WARN  => 30,
        ERROR => 40,
        FATAL => 50,
    };
    
    # Map level numbers to names for display
    my %LEVEL_NAMES = (
        10 => 'DEBUG',
        20 => 'INFO',
        30 => 'WARN',
        40 => 'ERROR',
        50 => 'FATAL',
    );
    
    # Singleton instance
    my $instance;
    
    # File handles storage (shared between parent/child loggers)
    my %file_handles;
    
    # Fields
    field $name :param;         # Logger name/component
    field $level :param = 30;   # Default level (WARN)
    field $console :param = 0;  # Output to console?
    field $file :param = undef; # Optional log file path
    field $file_id;             # ID to use when looking up file handle
    
    # Constructor (internal use)
    ADJUST {
        # Open log file if specified
        if (defined $file) {
            # Create a unique ID for this file
            $file_id = "$file";
            
            # Open file if not already open
            unless (exists $file_handles{$file_id}) {
                open(my $fh, '>', $file) or croak "Cannot open log file $file: $!";
                # Enable autoflush
                select((select($fh), $|=1)[0]);
                $file_handles{$file_id} = $fh;
            }
            
            $self->_write_to_file("Logger initialized: $name");
            $self->_write_to_file("Log level: $LEVEL_NAMES{$level}");
        }
    }
    
    # Get singleton instance or create new one - this is a CLASS method
    our sub get_instance($class, $params = {}) {
        # Create instance if it doesn't exist
        unless ($instance) {
            # Set default log file path if not provided and debug is enabled
            my $debug_enabled = $ENV{ITERUM_DEBUG} // 0;
            if ($debug_enabled && !exists $params->{file}) {
                $params->{file} = File::Spec->catfile(
                    File::Spec->tmpdir(),
                    "iterum_" . time() . ".log"
                );
                
                # Set default level based on environment
                $params->{level} //= DEBUG;
            }
            
            # Set default name if not provided
            $params->{name} //= 'Iterum';
            
            # Create instance
            $instance = Iterum::Util::Logger->new(%$params);
        }
        
        return $instance;
    }
    
    # Get a child logger with the same settings but different name
    method get_child($child_name) {
        my $full_name = "$name.$child_name";
        
        # Create new logger with same settings but different name
        # Since we're using the class-level %file_handles, the child will
        # automatically use the same file handle as the parent
        my $child = Iterum::Util::Logger->new(
            name => $full_name,
            level => $level,
            console => $console,
            file => $file,
        );
        
        return $child;
    }
    
    # Internal method to write to log file
    method _write_to_file($message) {
        return unless defined $file_id && exists $file_handles{$file_id};
        
        my $fh = $file_handles{$file_id};
        my $timestamp = scalar(localtime());
        print $fh "[$timestamp] $message\n";
    }
    
    # Internal method to write to console
    method _write_to_console($level_name, $message) {
        return unless $console;
        
        # Write to STDERR for ERROR and FATAL levels, STDOUT for others
        my $handle = ($level_name eq 'ERROR' || $level_name eq 'FATAL') ? \*STDERR : \*STDOUT;
        print $handle "[$level_name] [$name] $message\n";
    }
    
    # Log a message at specified level
    method log($level_num, $message) {
        # Skip if below threshold
        return if $level_num < $level;
        
        my $level_name = $LEVEL_NAMES{$level_num} // 'UNKNOWN';
        
        # Format message
        my $formatted = "[$level_name] [$name] $message";
        
        # Write to file
        $self->_write_to_file($formatted);
        
        # Write to console if enabled
        $self->_write_to_console($level_name, $message);
        
        return 1;
    }
    
    # Convenience method for DEBUG level
    method debug($message) {
        return $self->log(DEBUG, $message);
    }
    
    # Convenience method for INFO level
    method info($message) {
        return $self->log(INFO, $message);
    }
    
    # Convenience method for WARN level
    method warn($message) {
        return $self->log(WARN, $message);
    }
    
    # Convenience method for ERROR level
    method error($message) {
        return $self->log(ERROR, $message);
    }
    
    # Convenience method for FATAL level
    method fatal($message) {
        return $self->log(FATAL, $message);
    }
    
    # Set log level
    method set_level($new_level) {
        $level = $new_level;
        $self->_write_to_file("Log level changed to: $LEVEL_NAMES{$level}");
        return $self;
    }
    
    # Enable console output
    method enable_console() {
        $console = 1;
        $self->_write_to_file("Console output enabled");
        return $self;
    }
    
    # Disable console output
    method disable_console() {
        $console = 0;
        $self->_write_to_file("Console output disabled");
        return $self;
    }
    
    # Clean up
    method DESTROY() {
        if (defined $file_id && exists $file_handles{$file_id}) {
            $self->_write_to_file("Logger shutting down: $name");
            # Only close the file handle if this is the last logger using it
            # We'd need reference counting to do this properly
            # For now, we'll just leave it open to avoid premature closing
        }
    }
}

1;