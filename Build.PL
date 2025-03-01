use 5.40.0;
use Module::Build::Tiny 0.039;

# Configure Module::Build::Tiny
%Module::Build::Tiny::SharedData = (
    dist_name => 'Iterum',
    dist_version => '0.01',  # Matches version in Iterum::ECS
);

Build_PL();
