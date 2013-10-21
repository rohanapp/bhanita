use strict;
use Getopt::Long;

sub Usage
{
    print "$_[0]\n";
    print "Options: --f(orce kill) --v(erbose)\n";
}

my $gForceKill = 0;
my $gVerbose = 0;

sub PrintIfVerbose
{
    if ($gVerbose) {
	print "$_[0]";
	print "\n" if (!($_[0] =~ /.*\n$/));
    }
}

MAIN:
{
    GetOptions("force" => \$gForceKill, "verbose" => \$gVerbose) or Usage "Unknown option";
    my $userName = getlogin();
    PrintIfVerbose("Checking processes for user '$userName'\n");
    my @procList = `ps -ef --windows | grep -i $userName`;
    foreach my $eachProc (@procList) {
	PrintIfVerbose("Check if mainwin process: $eachProc");
	if ($eachProc =~ /.*nappann\s+(\d+).+(regss|mwrpcss|watchdog)\s.+/) {
	    my $mwProcID = $1;
	    my $killCmd = "kill $mwProcID";
	    if ($gForceKill) {
		$killCmd = "kill -9 $mwProcID";
	    }
	    print "$killCmd\n";
	    #system($killCmd);
	}
    }
}
