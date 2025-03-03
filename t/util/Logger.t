#!/usr/bin/env perl
use 5.40.0;
use Test2::V0;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use File::Temp qw(tempfile tempdir);
use File::Spec;
use Iterum::Util::Logger;

# Prepare temp directory for log files
my $temp_dir = tempdir( CLEANUP => 1 );

# Test basic logger creation and methods
subtest 'Logger Creation' => sub {

    # Test instantiation
    my $logger = Iterum::Util::Logger->new(
        name  => 'Test',
        level => Iterum::Util::Logger::INFO,
    );

    ok( $logger isa Iterum::Util::Logger, 'Logger instance created' );

    # Test log level constants
    is( Iterum::Util::Logger::DEBUG, 10, 'DEBUG level is 10' );
    is( Iterum::Util::Logger::INFO,  20, 'INFO level is 20' );
    is( Iterum::Util::Logger::WARN,  30, 'WARN level is 30' );
    is( Iterum::Util::Logger::ERROR, 40, 'ERROR level is 40' );
    is( Iterum::Util::Logger::FATAL, 50, 'FATAL level is 50' );
};

# Test singleton pattern
subtest 'Singleton Pattern' => sub {

    # Clear existing singleton if any
    {
        no strict 'refs';
        undef ${ *{'Iterum::Util::Logger::instance'} };
    }

    # First instance
    my $instance1 = Iterum::Util::Logger->get_instance(
        {
            name  => 'SingletonTest',
            level => Iterum::Util::Logger::DEBUG,
        }
    );

    ok(
        $instance1 isa Iterum::Util::Logger,
        'First singleton instance created'
    );

    # Second instance should be the same object
    my $instance2 = Iterum::Util::Logger->get_instance(
        {
            name  => 'DifferentName',               # This should be ignored
            level => Iterum::Util::Logger::ERROR,   # This should be ignored too
        }
    );

    ok(
        $instance2 isa Iterum::Util::Logger,
        'Second singleton call returns an instance'
    );
    is( $instance2, $instance1, 'Both instances are the same object' );

    # Verify original parameters are maintained
    my $log_file = File::Spec->catfile( $temp_dir, 'singleton_test.log' );

    # Create a temporary file to capture console output
    my ( $console_fh, $console_file ) = tempfile(
        File::Spec->catfile( $temp_dir, "console_XXXX" ),
        SUFFIX => '.txt',
        UNLINK => 1
    );

    # Redirect STDOUT temporarily
    my $old_stdout;
    open($old_stdout, ">&STDOUT") or die "Can't dup STDOUT: $!";
    open(STDOUT, ">", $console_file) or die "Can't redirect STDOUT: $!";
    
    $instance1->enable_console();
    $instance1->info("Test message");

    # Restore STDOUT
    close(STDOUT);
    open(STDOUT, ">&", $old_stdout) or die "Can't restore STDOUT: $!";
    close($old_stdout);

    # Check that console output contains the original logger name
    open( my $check_fh, '<', $console_file )
      or die "Could not open $console_file: $!";
    my $console_content = do { local $/; <$check_fh> };
    close($check_fh);

    like(
        $console_content,
        qr/\[INFO\] \[SingletonTest\]/,
        'Console output contains original logger name'
    );
};

# Test file logging
subtest 'File Logging' => sub {
    my $log_file = File::Spec->catfile( $temp_dir, 'test.log' );

    my $logger = Iterum::Util::Logger->new(
        name  => 'FileTest',
        level => Iterum::Util::Logger::DEBUG,
        file  => $log_file,
    );

    # Log some messages
    $logger->debug("Debug message");
    $logger->info("Info message");
    $logger->warn("Warning message");
    $logger->error("Error message");
    $logger->fatal("Fatal message");

    # Check log file content
    open( my $fh, '<', $log_file ) or die "Could not open $log_file: $!";
    my @lines = <$fh>;
    close($fh);

    # We expect at least 7 lines (2 init lines + 5 log messages)
    ok( scalar(@lines) >= 7, 'Log file has expected number of lines' );

    # Check message content
    my $content = join( '', @lines );
    like(
        $content,
        qr/\[DEBUG\] \[FileTest\] Debug message/,
        'Log file contains DEBUG message'
    );
    like(
        $content,
        qr/\[INFO\] \[FileTest\] Info message/,
        'Log file contains INFO message'
    );
    like(
        $content,
        qr/\[WARN\] \[FileTest\] Warning message/,
        'Log file contains WARN message'
    );
    like(
        $content,
        qr/\[ERROR\] \[FileTest\] Error message/,
        'Log file contains ERROR message'
    );
    like(
        $content,
        qr/\[FATAL\] \[FileTest\] Fatal message/,
        'Log file contains FATAL message'
    );
};

# Test log level filtering
subtest 'Log Level Filtering' => sub {
    my $log_file = File::Spec->catfile( $temp_dir, 'filter_test.log' );

    my $logger = Iterum::Util::Logger->new(
        name  => 'FilterTest',
        level => Iterum::Util::Logger::WARN,    # Only WARN and above
        file  => $log_file,
    );

    # Log messages at various levels
    $logger->debug("Debug message");     # Should be filtered out
    $logger->info("Info message");       # Should be filtered out
    $logger->warn("Warning message");    # Should be included
    $logger->error("Error message");     # Should be included
    $logger->fatal("Fatal message");     # Should be included

    # Check log file content
    open( my $fh, '<', $log_file ) or die "Could not open $log_file: $!";
    my @lines = <$fh>;
    close($fh);

    # We expect 5 lines (2 init lines + 3 log messages)
    ok( scalar(@lines) >= 5, 'Log file has expected number of lines' );

    # Check message content
    my $content = join( '', @lines );
    unlike(
        $content,
        qr/\[DEBUG\] \[FilterTest\] Debug message/,
        'Log file does not contain DEBUG message'
    );
    unlike(
        $content,
        qr/\[INFO\] \[FilterTest\] Info message/,
        'Log file does not contain INFO message'
    );
    like(
        $content,
        qr/\[WARN\] \[FilterTest\] Warning message/,
        'Log file contains WARN message'
    );
    like(
        $content,
        qr/\[ERROR\] \[FilterTest\] Error message/,
        'Log file contains ERROR message'
    );
    like(
        $content,
        qr/\[FATAL\] \[FilterTest\] Fatal message/,
        'Log file contains FATAL message'
    );

    # Test changing log level
    $logger->set_level(Iterum::Util::Logger::INFO);
    $logger->info("New info message");    # Should now be included

    # Re-check log file content
    open( $fh, '<', $log_file ) or die "Could not open $log_file: $!";
    @lines = <$fh>;
    close($fh);

    $content = join( '', @lines );
    like(
        $content,
        qr/\[INFO\] \[FilterTest\] New info message/,
        'Log file contains INFO message after level change'
    );
};

# Test child loggers
subtest 'Child Loggers' => sub {
    my $log_file = File::Spec->catfile( $temp_dir, 'child_test.log' );

    my $parent = Iterum::Util::Logger->new(
        name  => 'Parent',
        level => Iterum::Util::Logger::INFO,
        file  => $log_file,
    );

    # Create child logger
    my $child = $parent->get_child('Child');
    ok( $child isa Iterum::Util::Logger, 'Child logger created' );

    # Log messages from both loggers
    $parent->info("Parent message");
    $child->info("Child message");

    # Check log file content
    open( my $fh, '<', $log_file ) or die "Could not open $log_file: $!";
    my @lines = <$fh>;
    close($fh);

    # We expect at least 4 lines (2 init lines + 2 log messages)
    ok( scalar(@lines) >= 4, 'Log file has expected number of lines' );

    # Check message content
    my $content = join( '', @lines );
    like(
        $content,
        qr/\[INFO\] \[Parent\] Parent message/,
        'Log file contains parent logger message'
    );
    like(
        $content,
        qr/\[INFO\] \[Parent\.Child\] Child message/,
        'Log file contains child logger message with correct name'
    );

    # Test that child inherits settings
    $parent->set_level(Iterum::Util::Logger::ERROR);

    # Create new child after level change
    my $child2 = $parent->get_child('Child2');

    # This should be filtered out due to parent's log level
    $child2->info("Child2 info message");
    $child2->warn("Child2 warning message");

    # This should be included
    $child2->error("Child2 error message");

    # Re-check log file
    open( $fh, '<', $log_file ) or die "Could not open $log_file: $!";
    @lines = <$fh>;
    close($fh);

    $content = join( '', @lines );
    unlike(
        $content,
        qr/\[INFO\] \[Parent\.Child2\] Child2 info message/,
        'Child inherits parent log level - INFO message filtered'
    );
    unlike(
        $content,
        qr/\[WARN\] \[Parent\.Child2\] Child2 warning message/,
        'Child inherits parent log level - WARN message filtered'
    );
    like(
        $content,
        qr/\[ERROR\] \[Parent\.Child2\] Child2 error message/,
        'Child inherits parent log level - ERROR message included'
    );
};

# Test console logging
subtest 'Console Logging' => sub {
    my $logger = Iterum::Util::Logger->new(
        name    => 'ConsoleTest',
        level   => Iterum::Util::Logger::INFO,
        console => 1,                            # Enable console logging
    );

    # Create temporary files to capture console output
    my ( $stdout_fh, $stdout_file ) = tempfile(
        File::Spec->catfile( $temp_dir, "stdout_XXXX" ),
        SUFFIX => '.txt',
        UNLINK => 1
    );

    my ( $stderr_fh, $stderr_file ) = tempfile(
        File::Spec->catfile( $temp_dir, "stderr_XXXX" ),
        SUFFIX => '.txt',
        UNLINK => 1
    );

    # Redirect STDOUT
    my $old_stdout;
    open($old_stdout, ">&STDOUT") or die "Can't dup STDOUT: $!";
    open(STDOUT, ">", $stdout_file) or die "Can't redirect STDOUT: $!";
    
    # Redirect STDERR
    my $old_stderr;
    open($old_stderr, ">&STDERR") or die "Can't dup STDERR: $!";
    open(STDERR, ">", $stderr_file) or die "Can't redirect STDERR: $!";

    # Log messages
    $logger->info("Info to stdout");
    $logger->error("Error to stderr");

    # Restore STDOUT
    close(STDOUT);
    open(STDOUT, ">&", $old_stdout) or die "Can't restore STDOUT: $!";
    close($old_stdout);
    
    # Restore STDERR
    close(STDERR);
    open(STDERR, ">&", $old_stderr) or die "Can't restore STDERR: $!";
    close($old_stderr);

    # Check that output went to the right places
    open( my $check_stdout, '<', $stdout_file )
      or die "Could not open $stdout_file: $!";
    my $stdout_content = do { local $/; <$check_stdout> };
    close($check_stdout);

    open( my $check_stderr, '<', $stderr_file )
      or die "Could not open $stderr_file: $!";
    my $stderr_content = do { local $/; <$check_stderr> };
    close($check_stderr);

    like(
        $stdout_content,
        qr/\[INFO\] \[ConsoleTest\] Info to stdout/,
        'INFO message sent to stdout'
    );
    like(
        $stderr_content,
        qr/\[ERROR\] \[ConsoleTest\] Error to stderr/,
        'ERROR message sent to stderr'
    );

    # Test disabling console output
    ( $stdout_fh, $stdout_file ) = tempfile(
        File::Spec->catfile( $temp_dir, "stdout2_XXXX" ),
        SUFFIX => '.txt',
        UNLINK => 1
    );

    # Redirect STDOUT
    open($old_stdout, ">&STDOUT") or die "Can't dup STDOUT: $!";
    open(STDOUT, ">", $stdout_file) or die "Can't redirect STDOUT: $!";

    $logger->disable_console();
    $logger->info("This should not appear");

    # Restore STDOUT
    close(STDOUT);
    open(STDOUT, ">&", $old_stdout) or die "Can't restore STDOUT: $!";
    close($old_stdout);

    # Check that no output was generated
    open( $check_stdout, '<', $stdout_file )
      or die "Could not open $stdout_file: $!";
    $stdout_content = do { local $/; <$check_stdout> };
    close($check_stdout);

    is( $stdout_content, '', 'No output after disabling console logging' );
};

# Test null/undefined file behavior
subtest 'Null File Behavior' => sub {

    # Test with explicit undef file
    my $logger = Iterum::Util::Logger->new(
        name => 'NullFileTest',
        file => undef,
    );

    # These should not fail even though no file is set
    ok(
        defined eval { $logger->debug("Test message"); 1 },
        'Debug with null file does not fail'
    );
    ok(
        defined eval { $logger->info("Test message"); 1 },
        'Info with null file does not fail'
    );
    ok(
        defined eval { $logger->warn("Test message"); 1 },
        'Warn with null file does not fail'
    );
    ok(
        defined eval { $logger->error("Test message"); 1 },
        'Error with null file does not fail'
    );
    ok(
        defined eval { $logger->fatal("Test message"); 1 },
        'Fatal with null file does not fail'
    );
};

# Test environment variable interaction
subtest 'Environment Variable' => sub {

    # Backup existing value
    my $old_debug = $ENV{ITERUM_DEBUG};

    # Test with debug enabled
    $ENV{ITERUM_DEBUG} = 1;

    # Clear existing singleton if any
    {
        no strict 'refs';
        undef ${ *{'Iterum::Util::Logger::instance'} };
    }

    my $logger = Iterum::Util::Logger->get_instance();
    ok(
        $logger isa Iterum::Util::Logger,
        'Logger created with debug environment'
    );

    # Test with debug disabled
    $ENV{ITERUM_DEBUG} = 0;

    # Clear existing singleton if any
    {
        no strict 'refs';
        undef ${ *{'Iterum::Util::Logger::instance'} };
    }

    $logger = Iterum::Util::Logger->get_instance();
    ok( $logger isa Iterum::Util::Logger,
        'Logger created without debug environment' );

    # Restore previous value
    if ( defined $old_debug ) {
        $ENV{ITERUM_DEBUG} = $old_debug;
    }
    else {
        delete $ENV{ITERUM_DEBUG};
    }
};

done_testing();
