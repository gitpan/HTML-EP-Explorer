# -*- perl -*-
#
#   HTML::EP::Explorer - A Perl package for browsing filesystems and
#       executing actions on files.
#
#
#   This module is
#
#           Copyright (C) 1999     Jochen Wiedmann
#                                  Am Eisteich 9
#                                  72555 Metzingen
#                                  Germany
#
#                                  Email: joe@ispsoft.de
#
#   All Rights Reserved.
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.
#
#   $Id$
#

use strict;

use Cwd ();
use File::Spec ();
use HTML::EP ();
use HTML::EP::Locale ();
use HTML::EP::Session ();


package HTML::EP::Explorer;

@HTML::EP::Explorer::ISA = qw(HTML::EP::Session HTML::EP::Locale HTML::EP);
$HTML::EP::Explorer::VERSION = '0.1003';

sub init {
    my $self = shift;
    $self->HTML::EP::Session::init(@_);
    $self->HTML::EP::Locale::init(@_);
}

sub _ep_explorer_init {
    my $self = shift; my $attr = shift;
    return '' if $self->{_ep_explorer_init_done};
    $self->print("_ep_explorer_init: attr = (", join(",", %$attr), ")\n")
	if $self->{'debug'};
    $self->{_ep_explorer_init_done} = 1;
    my $cgi = $self->{'cgi'};
    $attr->{'class'} ||= "HTML::EP::Session::Cookie";
    $attr->{'id'} ||= "explorer-session";
    $attr->{'path'} ||= "/";
    $attr->{'expires'} ||= "+10y";
    eval { $self->_ep_session($attr) };
    my $session = $self->{$attr->{'var'} || 'session'};
    if ($self->{debug}) {
	require Data::Dumper;
	$self->print("Session = ", Data::Dumper::Dumper($session), "\n");
    }
    if (!$attr->{'noprefs'} and
	($@  or  !exists($session->{'prefs'}))) {
	# First time run, open the prefs page.
	my $prefs = $attr->{'prefs_page'} || "prefs.ep";
	my $return_to = $attr->{'return_to'} || $self->{'env'}->{'PATH_INFO'};
	$self->print("_ep_explorer_init: Redirecting to $prefs, returning to $return_to\n")
	    if $self->{'debug'};
	$cgi->param('return_to', $return_to);
	$self->{'_ep_output'} .= $self->_ep_include({file => $prefs});
	$self->_ep_exit({});
    }
    '';
}

sub _ep_explorer_config {
    my $self = shift;  my $attr = shift;
    my $debug = $self->{'debug'};
    my $cgi = $self->{'cgi'};
    my $file = $attr->{'file'} || "config.pm";
    if ($cgi->param('save')) {
	$self->print("_ep_explorer_config: Saving.\n");
	foreach my $var ($cgi->param()) {
	    if ($var =~ /^explorer_config_(.*)/) {
		my $v = $1;
		$self->{'config'}->{$1} = $cgi->param($var);
	    }
	}

	my @actions;
	my @names = $cgi->param('explorer_action_name');
	my @icons = $cgi->param('explorer_action_icon');
	my @scripts = $cgi->param('explorer_action_script');
	foreach my $name (@names) {
	    push(@actions, {'name' => $name,
			    'icon' => shift(@icons),
			    'script' => shift(@scripts)}) if $name;
	}
	$self->{'config'}->{'actions'} = \@actions;

	my @filetypes;
	@names = $cgi->param('explorer_filetype_name');
	@icons = $cgi->param('explorer_filetype_icon');
	my @res = $cgi->param('explorer_filetype_re');
	foreach my $name (@names) {
	    push(@filetypes, {'name' => $name,
			      'icon' => shift(@icons),
			      're' => shift(@res)}) if $name;
	}
	$self->{'config'}->{'filetypes'} = \@filetypes;

	my @directories;
	@names = $cgi->param('explorer_directory_name');
	my @dirs = $cgi->param('explorer_directory_dir');
	my $pwd = Cwd::cwd();
	foreach my $name (@names) {
	    next unless $name;
	    my $dir = shift(@dirs);
	    chdir($dir) or die "Failed to change directory to $dir: $!";
	    $dir = Cwd::cwd();
	    push(@directories, {'name' => $name,
				'dir' => $dir});
	}
	$self->{'config'}->{'directories'} = \@directories;
	chdir $pwd;

	require Data::Dumper;
	my $fh = Symbol::gensym();
	my $dump = Data::Dumper->new([$self->{'config'}], ["config"]);
	$dump->Indent(1);
	$self->print("Saved configuration is:\n", $dump->Dump(), "\n")
	    if $debug;
	(open($fh, ">$file") and (print $fh $dump->Dump()) and close($fh))
	    or die "Failed to create $file: $!";
    } else {
	$self->{'config'} = eval { require $file } ||
	    { 'actions' => [], filetypes => [], directories => [] };
    }
    $self->{'actions'} = $self->{'config'}->{'actions'};
    $self->{'directories'} = $self->{'config'}->{'directories'};
    $self->{'filetypes'} = $self->{'config'}->{'filetypes'};
    $self->{'num_directories'} = @{$self->{'directories'}};
    '';
}

sub _ep_explorer_prefs {
    my $self = shift;  my $attr = shift;
    my $debug = $self->{'debug'};
    $self->print("_ep_explorer_prefs: attr = (", join(",", %$attr), ")\n")
	if $debug;
    $attr->{'noprefs'} = 1;
    $self->_ep_explorer_init($attr);
    my $session = $self->{$attr->{'var'} ||= 'session'};
    my $cgi = $self->{'cgi'};
    if ($cgi->param('save')  ||  $cgi->param('save_and_return')) {
	$self->print("_ep_explorer_prefs: Saving\n") if $debug;
	foreach my $var ($cgi->param()) {
	    if ($var =~ /^explorer_prefs_(.*)/) {
		my $vr = $1;
		my $val = $cgi->param($var);
		$self->print("_ep_explorer_prefs: $vr => $val\n") if $debug;
		$session->{'prefs'}->{$vr} = $val;
	    }
	}
	if ($cgi->param('save_and_return') and
	    (my $return_to = $cgi->param('return_to'))) {
	    $self->print("Returning to $return_to\n") if $debug;
	    $self->{'_ep_output'} .=
		$self->_ep_include({'file' => $return_to});
	    $self->print("Done including $return_to\n") if $debug;
	    $self->_ep_exit({});
	}
	$self->_ep_session_store($attr);
    }
    '';
}

sub _ep_explorer_basedir {
    my $self = shift; my $attr = shift;
    return if $self->{'basedir'};
    my $cgi = $self->{'cgi'};
    my $session = $self->{'session'};
    my $debug = $self->{'debug'};
    my $basedir = $cgi->param('basedir') || $session->{'basedir'}
        || $attr->{'basedir'} || $self->{'directories'}->[0]
	|| $ENV{'DOCUMENT_ROOT'};
    $basedir = HTML::EP::Explorer::Dir->new($basedir)->{'dir'};
    chdir($basedir)
	or die "Failed to change directory to $basedir: $!";
    $basedir = Cwd::cwd();
    if (!$session->{'basedir'} or $session->{'basedir'} ne $basedir) {
	$self->{'modified'} = 1;
	$session->{'basedir'} = $basedir;
    }
    foreach my $dir (@{$self->{'directories'}}) {
	$self->print("Checking whether $dir->{'dir'} is $basedir.\n")
	    if $debug;
	if ($dir->{'dir'} eq $basedir) {
	    $self->{'in_top_dir'} = 1;
	    $self->{'in_base_dir'} = $dir;
	    $self->{'display_dir'} = "/";
	    $self->print("Yes, it is.\n") if $debug;
	    last;
	}
    }
    if (!$self->{'in_top_dir'}) {
	$self->{'in_top_dir'} = ($basedir eq File::Spec->rootdir());
	foreach my $dir (@{$self->{'directories'}}) {
	    $self->print("Checking whether $basedir is below $dir->{'dir'}.\n")
		if $debug;
	    if ($basedir =~ /^\Q$dir->{'dir'}\E(\/.*)$/) {
		$self->{'in_base_dir'} = $dir;
		$self->{'display_dir'} = $1;
		$self->print("Yes, it is.\n") if $debug;
		last;
	    }
	}
	if (!$self->{'in_base_dir'}) {
	    die "Directory $basedir is outside of the permitted area."
		if $self->{'config'}->{'dirs_restricted'};
	    $self->{'display_dir'} = $basedir;
	}
    }
    $self->print("Basedir is $basedir.\n") if $debug;
    $self->{'basedir'} = $basedir;
    '';
}

sub _ep_explorer_sortby {
    my $self = shift; my $attr = shift;
    my $cgi = $self->{'cgi'};
    my $session = $self->{'session'};
    my $sortby = $cgi->param('sortby') || $session->{'sortby'} ||
	$attr->{'sortby'} || "name";
    if (!$session->{'sortby'}  ||  $session->{'sortby'} ne $sortby) {
	$self->{'modified'} = 1;
	$session->{'sortby'} = $sortby;
    }
    $self->print("Sorting by $sortby.\n") if $self->{'debug'};
    $self->{'sortby'} = $sortby;
    '';
}

sub _ep_explorer_filetype {
    my $self = shift; my $attr = shift;
    my $cgi = $self->{'cgi'};
    my $debug = $self->{'debug'};
    my $session = $self->{'session'};
    my $filetype = $cgi->param('filetype') || $session->{'filetype'}
	|| $attr->{'filetype'} || '';
    $self->print("Looking for file type $filetype\n") if $debug;
    my $found;
    foreach my $ft (@{$self->{'filetypes'}}) {
	if ($filetype eq $ft->{'name'}) {
	    $found = $ft;
	    last;
	}
    }
    if ($found) {
	$self->print("Found it.\n") if $debug;
    } elsif (@{$self->{'filetypes'}}) {
	$found = $self->{'filetypes'}->[0];
	$self->print("Choosing default file type $found->{'name'}\n")
	    if $debug;
    } else {
	$self->print("No file type found.\n");
    }

    $found->{'selected'} = 'SELECTED' if $found;
    my $name = $found ? $found->{'name'} : '';
    if (!defined($session->{'filetype'}) ||
	$session->{'filetype'} ne $name) {
	$self->{'modified'} = 1;
	$session->{'filetype'} = $name;
    }
    $self->print("Filetype is $found->{'name'}.\n")
	if $self->{'debug'} and $found;
    $self->{'filetype'} = $found;
    '';
}

sub _ep_explorer_browse {
    my $self = shift; my $attr = shift;
    my $cgi = $self->{'cgi'};
    my $debug = $self->{'debug'};
    my $session = $self->{'session'};
    $self->{'modified'} = 0;
    my $dir_template = $self->{'dir_template'}
	or die "Missing template variable: dir_template";
    my $item = $attr->{'item'} || die "Missing item name";

    $self->_ep_explorer_basedir($attr);
    $self->_ep_explorer_filetype($attr);
    $self->_ep_explorer_sortby($attr);

    my $dir = HTML::EP::Explorer::Dir->new($self->{'basedir'});
    my $list = $dir->Read($self->{'filetype'}->{'re'});
    my $sortby = $self->{'sortby'};
    my $updir;
    if ($list->[0]->IsDir()
	and  $list->[0]->{'name'} eq File::Spec->updir()) {
	$updir = shift @$list;
    }
    $self->print("Sorting by $sortby.\n") if $debug;
    if ($sortby eq 'type') {
	@$list = sort {
	    if ($a->IsDir()) {
		$b->IsDir() ? $a->{'name'} cmp $b->{'name'} : -1;
	    } elsif ($b->IsDir()) {
		return 1;
	    } else {
		my $ae = ($a =~ /\.(.*?)$/) ? $1 : '';
		my $be = ($b =~ /\.(.*?)$/) ? $1 : '';
		($ae cmp $be) || ($a->{'name'} cmp $b->{'name'});
	    }
	} @$list;
    } elsif ($sortby eq 'uid') {
	@$list = sort { (getpwuid($a->{'uid'}) || '') cmp
			(getpwuid($b->{'uid'}) || '')} @$list;
    } elsif ($sortby eq 'gid') {
	@$list = sort { (getgrgid($a->{'gid'}) || '') cmp
			(getgrgid($b->{'gid'}) || '')} @$list;
    } elsif ($sortby =~ /^(?:size|[amc]time)$/) {
	@$list = sort { $a->{$sortby} <=> $b->{$sortby} } @$list;
    } else {
	@$list = sort { $a->{$sortby} cmp $b->{$sortby} } @$list;
    }
    unshift(@$list, $updir)
	if $updir and !$self->{'in_top_dir'};
    my $output = '';
    $self->{'i'} = 0;
    foreach my $i (@$list) {
	$self->{$item} = $i;
	$output .= $i->AsHtml($self, $item);
	++$self->{'i'};
    }

    $self->_ep_session_store($attr) if $self->{'modified'};
    $output;
}

sub _format_ACTIONS {
    my $self = shift; my $item = shift;

    my $str = '';
    foreach my $action (@{$self->{'actions'}}) {
	$self->{'action'} = $action;
	$self->{'icon'} = $action->{'icon'} ?
	    qq{<img src="$action->{'icon'}" alt="$action->{'name'}">} :
	    $action->{'name'};
	$str .= $self->ParseVars($self->{'action_template'});
    }

    $str;
}

sub _ep_explorer_action {
    my $self = shift;  my $attr = shift;
    my $cgi = $self->{'cgi'};
    my $debug = $self->{'debug'};
    my $name = $attr->{'action'} || die "Missing action name";
    $self->print("_ep_explorer_action: $name\n") if $debug;
    my $action;
    foreach my $a (@{$self->{'actions'}}) {
	if ($a->{'name'} eq $name) {
	    $action = $a;
	    last;
	}
    }
    die "Unknown action: $name" unless $action;
    $self->print("Selected action is $action\n") if $debug;

    my @files;
    if ($attr->{'files'}) {
	@files = split(" ", $attr->{'files'});
    } elsif ($attr->{'file'}) {
	@files = $attr->{'file'};
    } else {
	die "Missing file name";
    }
    my $command = $action->{'script'};
    if ($command =~ /\$files/) {
	# Can handle multiple files
	my $files = join(" ",
			 map { HTML::EP::Explorer::File->new($_)->{'file'} }
			 @files);
	$command =~ s/\$files/$files/sg;
	$command .= " 2>&1" if $attr->{'execute'};
    } else {
	my @commands;
	foreach my $file (@files) {
	    my $c = $command;
	    my $f = HTML::EP::Explorer::File->new($file)->{'file'};
	    $c =~ s/\$file/$f/sg;
	    push(@commands, $attr->{'execute'} ? "$c 2>&1" : $c);
	}
	$command = join(";", @commands);
    }
    $self->print("Selected command is $command\n") if $debug;
    if ($attr->{'execute'}) {
	return `$command`;
    } else {
	return $command;
    }
}

sub _format_MODE {
    my $self = shift; my $mode = shift;
    (($mode & 0400) ? "r" : "-") .
    (($mode & 0200) ? "w" : "-") .
    (($mode & 04000) ? "s" : (($mode & 0100) ? "x" : "-")) .
    (($mode & 040)  ? "r" : "-") .
    (($mode & 020)  ? "w" : "-") .
    (($mode & 02000) ? "s" : (($mode & 010) ? "x" : "-")) .
    (($mode & 04)   ? "r" : "-") .
    (($mode & 02)   ? "w" : "-") .
    (($mode & 01)   ? "x" : "-");
}

sub _format_UID {
    my $self = shift; my $uid = shift;
    my $u = getpwuid($uid);
    defined $u ? $u : $uid;
}

sub _format_GID {
    my $self = shift; my $gid = shift;
    my $g = getgrgid($gid);
    defined $g ? $g : $gid;
}

sub _format_DATE {
    my $self = shift; my $time = shift;
    return '' unless $time;
    return $self->_format_TIME(scalar(localtime($time)));
}

sub _format_SELECTED {
    my $self = shift; shift() ? "SELECTED" : "";
}

package HTML::EP::Explorer::File;

sub new {
    my $proto = shift;  my $file = shift;
    $file =~ s/^file://;
    my $self = { 'file' => $file, @_ };
    $self->{'name'} ||= File::Basename::basename($file);
    $self->{'url'} ||= "file:$file";
    bless($self, (ref($proto) || $proto));
}

sub IsDir { 0 }

sub AsHtml {
    my $self = shift;  my $ep = shift;
    foreach my $ft (@{$ep->{'filetypes'}}) {
	if ($ft->{'icon'}  &&  $self->{'name'} =~ /$ft->{'re'}/) {
	    $self->{'icon'} = $ft->{'icon'};
	    last;
	}
    }
    $self->{'icon'} = "unknown.gif" unless $self->{'icon'};
    $ep->ParseVars($ep->{'file_template'}
		   or die "Missing template variable: file_template");
}


package HTML::EP::Explorer::Dir;

sub new {
    my $proto = shift;  my $dir = shift;
    $dir =~ s/^file://;
    my $self = { 'dir' => $dir, @_ };
    $self->{'name'} ||= File::Basename::basename($dir);
    $self->{'url'} ||= "file:$dir";
    bless($self, (ref($proto) || $proto));
}

sub IsDir { 1 }

sub AsHtml {
    my $self = shift;  my $ep = shift;
    $ep->ParseVars($ep->{'dir_template'}
		   or die "Missing template variable: dir_template");
}

sub Read {
    my $self = shift;  my $re = shift;
    my $fh = Symbol::gensym();
    my $pwd = Cwd::cwd();
    my $curdir = File::Spec->curdir();
    my $dir = $self->{'dir'};
    my @list;
    chdir $dir or die "Failed to change directory to $dir: $!";
    opendir($fh, $curdir) or die "Failed to open directory $dir: $!";
    while (defined(my $f = readdir($fh))) {
	next if $f eq $curdir;
	my($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
	   $atime, $mtime, $ctime, $blksize) = stat $f;
	if (-f _) {
	    push(@list,
		 HTML::EP::Explorer::File->new(File::Spec->catfile($dir, $f),
					       'name' => $f,
					       'mode' => $mode,
					       'uid' => $uid,
					       'gid' => $gid,
					       'size' => $size,
					       'mtime' => $mtime,
					       'ctime' => $ctime,
					       'atime' => $atime))
		if !$re || $f =~ /$re/;
	} elsif (-d _) {
	    push(@list,
		 HTML::EP::Explorer::Dir->new(File::Spec->catdir($dir, $f),
					      'name' => $f,
					      'mode' => $mode,
					      'uid' => $uid,
					      'gid' => $gid,
					      'size' => $size,
					      'mtime' => $mtime,
					      'ctime' => $ctime,
					      'atime' => $atime))
	}
    }
    closedir $fh;
    chdir $pwd;
    \@list;
}


1;

__END__

=pod

=head1 NAME

  HTML::EP::Explorer - Web driven browsing of a filesystem


=head1 SYNOPSIS

  <ep-explorer-browse>


=head1 DESCRIPTION

This application was developed for DHW, a german company that wanted to
give its users access to files stored on a file server via certain
applications defined by an administrator. (See

  http://www.dhw.de/

if you are interested in the sponsor.) The rough idea is as follows:

The users are presented a view similar to that of the Windows Explorer
or an FTP servers directory listing. On the top they have a list of
so-called actions. The users may select one or more files and then
execute an action on them.


=head1 INSTALLATION

The system is based on my embedded HTML system HTML::EP. It should be
available at the same place where you found this file, or at any CPAN
mirror, in particular

  ftp://ftp.funet.fi/pub/languages/perl/CPAN/authors/id/JWIED/

The installation of HTML::EP is described in detail in the README, I
won't explain it here. However, in short it is just as installing
HTML::EP::Explorer: Assumed you have a file

  HTML-EP-Explorer-0.1003.tar.gz

then you have to execute the following steps:

  gzip -cd HTML-EP-Explorer-0.1003.tar.gz | tar xf -
  perl Makefile.PL
  make		# You will be prompted some questions here
  make test
  make install

Installation will in particular create a file

  lib/HTML/EP/Explorer/Config.pm

which will contain your answers to the following questions:

=over 8

=item *

  Install HTML files?

If you say I<y> here (the default), the installation script will
install some HTML files at a location choosed by you. Usually you
will say yes, because the system is pretty useless without it's
associated HTML files. However, if you already did install the
system and modified the HTML files you probably want to avoid
overriding them. In that case say I<n>.

=item *

  Directory for installing HTML files?

If you requested installing the HTML files, you have to choose a
location. By default the program suggests

  F</home/httpd/html/explorer>

which is fine on a Red Hat Linux box. Users of other systems will modify
this to some path below your your web servers root directory.

=item *

  UID the httpd is running as?

The explorer scripts need write access to some files, in particular the
configuration created by the site administrator. To enable write access,
these files are owned by the Unix user you enter here, by default the
user I<nobody>.

In most cases this will be the same user that your httpd is running as,
but it might be different, for example if your Apache is using the
suexec feature. Contact your webmaster for details.

=back



=cut
