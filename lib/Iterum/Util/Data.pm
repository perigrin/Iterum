use 5.40.0;

package Iterum::Util::Data;

use File::ShareDir::Tiny qw(dist_dir);
use Path::Tiny;
use JSON::MaybeXS qw(decode_json);
use Exporter 'import';

our @EXPORT_OK = qw(load_json_data);

sub load_json_data ($file) {
    try { $$file = dist_file($file) }
    catch ($e) {

        # Try to find the file relative to the module
        $file = "share/$file";
    }
    die "Could not find EV lookup file ($file)" unless -e $file;
    return decode_json path($file)->slurp;
}

1;
