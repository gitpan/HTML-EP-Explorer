# -*- perl -*-

use strict;

use ExtUtils::MakeMaker ();

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
my %opts = (
    'NAME'	=> 'HTML-EP-Explorer',
    'dist'      => { SUFFIX   => '.gz', DIST_DEFAULT => 'all tardist',
                     COMPRESS => 'gzip -9vf' },
    'VERSION_FROM' => 'lib/HTML/EP/Explorer.pm', # finds $VERSION
);

if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
    $opts{'AUTHOR'} = 'Jochen Wiedmann (joe@ispsoft.de)';
    $opts{'PREREQ_PM'} = { 'HTML::EP' => 0.1128 };
    $opts{'ABSTRACT_FROM'} = 'lib/HTML/EP/Explorer.pm';
}

ExtUtils::MakeMaker::WriteMakefile(%opts);

package MY;

sub libscan { my($self, $path) = @_; ($path =~ /\~$/) ? undef : $path }

sub postamble {
    <<"END_OF_POSTAMBLE";

pm_to_blib: README

README: lib/HTML/EP/Explorer.pm
\tperldoc -t lib/HTML/EP/Explorer.pm >README

END_OF_POSTAMBLE
}
