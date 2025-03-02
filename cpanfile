requires 'perl', '5.40.0';
requires 'DBI';
requires 'DBD::SQLite';
requires 'JSON::MaybeXS';
requires 'Time::HiRes';
requires 'File::ShareDir::Tiny';
requires 'Path::Tiny';
requires 'Term::Screen';
requires 'Term::ANSIColor';
requires 'Feature::Compat::Try';
requires 'Feature::Compat::Class';

on 'test' => sub {
    requires 'Test2::V0';
    requires 'Test2::Suite';
};
