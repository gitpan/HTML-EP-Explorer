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
$HTML::EP::Explorer::VERSION = '0.1002';

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
	while (@names) {
	    my $name = shift @names;
	    my $icon = shift @icons;
	    my $script = shift @scripts;
	    push(@actions, {'name' => $name,
			    'icon' => $icon,
			    'script' => $script}) if $name;
	}
	$self->{'config'}->{'actions'} = $self->{'actions'} = \@actions;
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
	    { 'actions' => [] };
	$self->{'actions'} = $self->{'config'}->{'actions'};
    }
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

sub _ep_explorer_browse {
    my $self = shift; my $attr = shift;
    my $cgi = $self->{'cgi'};
    my $debug = $self->{'debug'};
    my $session = $self->{'session'};
    my $modified;
    my $dir_template = $self->{'dir_template'}
	or die "Missing template variable: dir_template";
    my $item = $attr->{'item'} || die "Missing item name";

    my $basedir = $cgi->param('basedir') || $session->{'basedir'}
	|| $attr->{'basedir'} || die "Missing basedir";
    if (!$session->{'basedir'} or $session->{'basedir'} ne $basedir) {
	$modified = 1;
	$session->{'basedir'} = $basedir;
	$self->print("Setting base directory to $basedir\n") if $debug;
    }

    my $dir = HTML::EP::Explorer::Dir->new($basedir);
    my $list = $dir->Read();
    my $output = '';
    $self->{'i'} = 0;
    foreach my $i (@$list) {
	$self->{$item} = $i;
	$output .= $i->AsHtml($self, $item);
	++$self->{'i'};
    }

    $self->_ep_session_store($attr) if $modified;
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
    my $debug = $self->{'debug'};
    my $name = $self->{'cgi'}->param('action') || die "Missing action name";
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
    my $file = $self->{'cgi'}->param('file') || die "Missing file name";
    my $command = $action->{'script'};
    my $f = HTML::EP::Explorer::File->new($file);
    $command =~ s/\$file/$f->{'file'}/g;
    $self->print("Selected command is $command\n") if $debug;
    if ($attr->{'execute'}) {
	return `$command 2>&1`;
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


package HTML::EP::Explorer::File;

sub new {
    my $proto = shift;  my $file = shift;
    $file =~ s/^file://;
    my $self = { 'file' => $file, @_ };
    $self->{'name'} ||= File::Basename::basename($file);
    $self->{'url'} ||= "file:$file";
    bless($self, (ref($proto) || $proto));
}

sub AsHtml {
    my $self = shift;  my $ep = shift;
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

sub AsHtml {
    my $self = shift;  my $ep = shift;
    $ep->ParseVars($ep->{'dir_template'}
		   or die "Missing template variable: dir_template");
}

sub Read {
    my $self = shift;
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


=cut
