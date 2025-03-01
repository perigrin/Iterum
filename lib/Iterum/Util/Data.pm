use 5.40.0;

package Iterum::Util::Data;

use File::ShareDir qw(dist_dir);
use File::Spec;
use JSON::MaybeXS qw(decode_json);
use Carp qw(croak);
use Exporter 'import';

our @EXPORT_OK = qw(load_json_data);

# Helper method to get share directory path
sub _share_file_path {
    my $file = shift;
    
    # During development, first try to find the file in the local share directory
    my $dev_share = File::Spec->catfile('share', $file);
    return $dev_share if -f $dev_share;
    
    # If installed as a distribution, use File::ShareDir
    eval {
        my $dist_dir = dist_dir('Iterum');
        my $dist_path = File::Spec->catfile($dist_dir, $file);
        return $dist_path if -f $dist_path;
    };
    
    # If file not found in either location
    croak "Could not find data file: $file";
}

# Load JSON data from share directory
sub load_json_data {
    my ($file) = @_;
    
    my $file_path = _share_file_path($file);
    
    open my $fh, '<', $file_path or croak "Could not open data file $file_path: $!";
    local $/;
    my $json_text = <$fh>;
    close $fh;
    
    return decode_json($json_text);
}

1;
