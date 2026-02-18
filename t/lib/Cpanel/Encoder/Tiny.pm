package Cpanel::Encoder::Tiny;

# Stub of Cpanel::Encoder::Tiny for use during testsuite execution

use cPstrict;

my %HTML_ENCODE_MAP = ( '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;', "'" => '&#39;' );

sub safe_html_encode_str {
    return $_[0] if !defined $_[0] || ( !defined $_[1] && $_[0] !~ tr/&<>"'// );
    my $data = defined $_[1] ? join( '', @_ ) : $_[0];
    return $data if $data !~ tr/&<>"'//;
    $data =~ s/([&<>"'])/$HTML_ENCODE_MAP{$1}/sg;
    return $data;
}

1;
