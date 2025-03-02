use 5.40.0;

package Iterum::Util::Data;

use File::ShareDir::Tiny qw(dist_dir);
use Path::Tiny;
use JSON::MaybeXS qw(decode_json);
use Exporter 'import';

our @EXPORT_OK = qw(load_file load_json_data);

sub load_file ($file) {
    try { $$file = dist_file($file) }
    catch ($e) {

        # Try to find the file relative to the module
        $file = "share/$file";
    }
    die "Could not find EV lookup file ($file)" unless -e $file;
    return path($file)->slurp;
}

sub load_json_data ($file) {
    return decode_json load_file($file);
}

1;
