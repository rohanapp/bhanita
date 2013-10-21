use strict;
use Getopt::Long;

sub Usage
{
    print "$_[0]\n";
    print "Options: --f(orce kill) --v(erbose) -process <match pattern string>\n";
}

my $gForceKill = 0;
my $gVerbose = 0;
my $gPreviewOnly = 0;
my $gProcessMatchPatternStr;

sub PrintIfVerbose
{
    if ($gVerbose) {
	print "$_[0]";
	print "\n" if (!($_[0] =~ /.*\n$/));
    }
}

MAIN:
{
    GetOptions("force" => \$gForceKill, "verbose" => \$gVerbose, "process=s" => \$gProcessMatchPatternStr,
	"preview" => \$gPreviewOnly) or Usage "Unknown option";
    die "Specify pattern to match process!" unless ($gProcessMatchPatternStr);

    my $userName = getlogin();
    PrintIfVerbose("Iterating over running processes...\n");

    my $killCmd = "TASKKILL /T";
    $killCmd = ($killCmd . " /F") if $gForceKill;
    $killCmd = ($killCmd . " /PID");


    my $procIDMatchStr = "^\\s*(\\d+).+";
    my $procIDTitleMatchStr = "^\\s*(PID).+";

    my @procList = `ps -el --windows`;
    PrintIfVerbose("Using pattern '$procIDTitleMatchStr', checking for PID keyword in the title '$procList[0]'...\n");
    die "Programmer error: Unable to match PID from process output!" unless ($procList[0] =~ /$procIDTitleMatchStr/);
    foreach my $eachProc (@procList) {
	PrintIfVerbose("Checking if process line '$eachProc' matches pattern '$gProcessMatchPatternStr'...");
	if ($eachProc =~ /$procIDMatchStr/) {
	    my $pid = $1;
	    if ($eachProc =~ /$gProcessMatchPatternStr/i) {
		my $currKillCmd = $killCmd . " $pid";
		print "$eachProc\n" if ($gPreviewOnly);
		print "$currKillCmd\n";
		system($currKillCmd) unless $gPreviewOnly;
	    }
	}
    }
}
