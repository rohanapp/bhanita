use strict;
use Getopt::Long;
use File::Spec;
use Cwd 'realpath';
use Carp;
use Config;

sub IsInteger
{
  return 1 if ($_[0] =~ m/^\d+$/);
  return 0;
}

my $gVerbose = 0;

sub Usage
{
  my $sep = "="x60 . "\n";

  print "\n\nERROR OCCURRED: $_[0]\n" if (length($_[0]));
  print <<__USAGE;

$sep

USAGE: 
  Run "$0 -procid <nexxim.exe procid>" to obtain thread-id
  corresponding to AltraSecurityTimerProc

Options:
--procid <id>
  Specify process ID of a running nexxim.exe process
--verbose
  Turn ON verbose output

$sep


__USAGE

  exit(0);
  
}

MAIN:
{

    my $isHelp = 0;
    my $procID = -1;
    my $doEndlessLoop = 0;
    GetOptions("procid=i" => \$procID, "verbose" => \$gVerbose,
               "help" => \$isHelp) or Usage();
  
    Usage() if ($isHelp);

    Usage("'procid' option must be specified on the command-line!") if ($procID == -1);
    
    my $procFolder = "/proc/$procID";
    die "'$procFolder' does not exist!" unless (-e $procFolder);
    my $procTasksFolder = "$procFolder/task";
    die "'$procTasksFolder' does not exist!" unless (-e $procTasksFolder);

    my @processStackTraceLines = `gstack $procID`;
    my $currThreadID = -1;
    my $foundMatch = 0;
    foreach(@processStackTraceLines) {
      if ($_ =~ m/^Thread\s+\d+.+\(LWP\s+(\d+)\)/i) {
        $currThreadID = $1;
        print "Checking threadid '$currThreadID'...\n" if ($gVerbose);
        next;
      } elsif ($_ =~ m/.+AltraSecurityTimerProc.+/) {
        $foundMatch = 1;
        last;
      } else {
        $foundMatch = 0;
      }
    }

    die "Unable to find thread with stack trace containing to 'AltraSecurityTimerProc'!" if (!$foundMatch);
    if ($gVerbose) {
      print "Thread id corresponding to security timer proc is '$currThreadID'\n";
    } else {
      print "$currThreadID";
    }

    exit(0);
}

