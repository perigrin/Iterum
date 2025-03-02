requires 'perl', '5.40.0';
requires 'DBI';
requires 'DBD::SQLite';
requires 'JSON::MaybeXS';
requires 'Term::ReadKey';  # For CLI interface
requires 'Time::HiRes';
requires 'File::ShareDir::Tiny';
requires 'Path::Tiny';

on 'test' => sub {
    requires 'Test2::V0';
    requires 'Test2::Suite';
};
