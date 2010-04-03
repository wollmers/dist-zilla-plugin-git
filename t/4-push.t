#!perl

use strict;
use warnings;

use Dist::Zilla  1.093250;
use Dist::Zilla::Tester;
use Cwd          qw{ getcwd  };
use File::Temp   qw{ tempdir };
use Git::Wrapper;
use Path::Class;
use Test::More   tests => 3;

# build fake repository
my $zilla = Dist::Zilla::Tester->from_config({
  dist_root => dir(qw(t push)),
});

chdir $zilla->tempdir->subdir('source');
system "git init";
my $git   = Git::Wrapper->new('.');

$git->config( 'user.name'  => 'dzp-git test' );
$git->config( 'user.email' => 'dzp-git@test' );
$git->add( qw{ dist.ini Changes } );
$git->commit( { message => 'initial commit' } );

# create a clone, and use it to set up origin
my $clone = tempdir( CLEANUP => 1 );
my $curr  = getcwd;
$git->clone( { quiet=>1, 'no-checkout'=>1, bare=>1 }, $curr, $clone );
$git->remote('add', 'origin', $clone);
$git->config('branch.master.remote', 'origin');
$git->config('branch.master.merge', 'refs/heads/master');

# do the release
append_to_file('Changes',  "\n");
append_to_file('dist.ini', "\n");
$zilla->release;

# check if everything was pushed
$git = Git::Wrapper->new( $clone );
my ($log) = $git->log( 'HEAD' );
is( $log->message, "v1.23\n\n- foo\n- bar\n- baz\n", 'commit pushed' );

# check if tag has been correctly created
my @tags = $git->tag;
is( scalar(@tags), 1, 'one tag pushed' );
is( $tags[0], 'v1.23', 'new tag created after new version' );

sub append_to_file {
    my ($file, @lines) = @_;
    open my $fh, '>>', $file or die "can't open $file: $!";
    print $fh @lines;
    close $fh;
}
