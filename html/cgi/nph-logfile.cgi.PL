# -*- perl -*-

use Config ();

my $script;
$script =~ s/\~\~(\w+)\~\~/$Config::Config{$1}/g;
my $file = "html/cgi/nph-logfile.cgi";
(open(FILE, ">$file")  and
 (print FILE $script)  and  close(FILE)  and chmod(0755, $file))
    or die "Failed to create $file: $!";


BEGIN { $script = <<'END_OF_SCRIPT' };
~~startperl~~ -w

use strict;
use File::Spec ();
use Safe ();
use CGI ();
my $cgi;

BEGIN {
     $cgi = CGI->new();
     $SIG{'__DIE__'} = sub {
	 my $msg = shift;
	 my $language = $cgi->param("language");
	 print $cgi->header('-nph' => 0, '-type' => 'text/html');
	 if ($language && $language eq "de") {
	     print <<"END_OF_HTML";
<html><head>Interner Fehler</head></html>
<body bgcolor=#ffffff>
<h1>Interner Fehler</h1>
<p>Ihre Anfrage konnte wegen eines Systemfehlers nicht durchgeführt
  werden:</p>
<pre>
  $msg
</pre>
</body></html>
END_OF_HTML
         } else {
	     print <<"END_OF_HTML";
<html><head>Interner Fehler</head></html>
<body bgcolor=#ffffff>
<h1>Internal Error</h1>
<p>We could not process your request, due to the following error:</p>
<pre>
  $msg
</pre>
</body></html>
END_OF_HTML
	 }
	 exit 0;
     };
};


use HTML::EP::Explorer::Config ();
my $cfg = $HTML::EP::Explorer::Config::config;

my $config_file = File::Spec->catfile($cfg->{'html_base_dir'}, "admin",
				      "config.pm");
my $config = Safe->new()->rdo($config_file);
if ($@) {
    die $@;
}

my $name = $cgi->param('faction')
    or die "Missing action name";

foreach my $a (@{$config->{'actions'}}) {
    if ($a->{'name'} eq $name) {
	my $logfile = $a->{'logfile'};
	print $cgi->header('-nph' => 0, '-type' => 'text/html');
	exec "tail", "-f", "$logfile";
    }
}
die "Unknown action: $name";
END_OF_SCRIPT
