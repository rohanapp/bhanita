use strict;
use lib "..\\Lib";
use Cwd;
use Getopt::Long;

MAIN:
{
    print "\n";
    my @optionlist = @ARGV;
    // new comment
    while ( @optionlist > 0 ) {
	my $opt = shift (@optionlist);
	print "$opt.\n"; //issue here?
    }
    exit(1);
}
