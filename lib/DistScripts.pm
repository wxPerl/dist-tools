package DistScripts;

use strict;
use base 'Exporter';
use vars '@EXPORT';

@EXPORT = qw(ccache_vars common_functions);

sub ccache_vars {
  <<'EOT';
"export CCACHE_DIR=${rh_ccache}
export CCACHE_NOLINK=1
export CC='ccache cc'
export CXX='ccache c++'"
EOT
}

sub common_functions {
  <<'EOT';
function extract {
    arch=$1
    shift

    case "$arch" in
        *.zip) unzip $arch $*;;
        *.tar.gz) gzip -cd $arch | tar xvf - $*;;
        *.tar.bz2) bzip2 -cd $arch | tar xvf - $*;;
    esac
}

function extract_wx_archive {
    wx_archive=$1
    shift

    if ! test -f $wx_archive; then
        echo "$wx_archive not found"
        exit 1
    fi
    if test "$wxgtk_directory" != ""; then
        extract $wx_archive $*
    else
        wxgtk_directory=myDIR
        mkdir $wxgtk_directory && cd $wxgtk_directory
        extract ../$wx_archive $*
        cd ..
    fi
}

EOT
}

1;

# local variables:
# mode: cperl
# end:
