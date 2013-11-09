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
# Following data is indexed hy procid key: uid, ppid, command-line
my %gMatchedProcs = ();
my $gNiceValue = 15; # range -19 to 20
my $gLoopIterIntervalInSecs = 120; # every 2 minutes
# Allow specifying renice values for a second group identified by a matching function in thread's call stack
my $gInvalidNiceValue = -999;
my $gNiceValue2ndGroup = $gInvalidNiceValue;
my $gFunctionsInGroup2; # simple name or a pattern


sub Usage
{
  my $sep = "="x60 . "\n";

  print "\n\nERROR OCCURRED: $_[0]\n" if (length($_[0]));
  print <<__USAGE;

$sep

USAGE: 
  Run "$0 <Options>" to renice threads belonging to
  processes with given name.
  Specify option to renice once or loop every few seconds.

Options:
--procname <procname>
  Specify process name including extension, excluding path
--niceval (=$gNiceValue)
  Specify nice value within range [-19, 19]. Higher values are nicer
--loop
  Renice in an endless loop. Use when processes start/stop dynamically
--interval (=$gLoopIterIntervalInSecs) 
  Specify time between renice iterations. Applies only when renice is 
  done in an endless loop
--secondniceval
  Specify nice value within range [-19, 19]. Higher values are nicer
  Note: Must specify this option along with 'functionin2ndgroup'
--functionin2ndgroup
  Specify name/pattern of function(s) that belongs to the stack trace of second group of 
  threads. Any non-matching thread belongs to first group
  Note: Must specify this option along with 'secondniceval'
--verbose
  Turn ON verbose output

$sep


__USAGE

  exit(0);
  
}
sub UpdatePIDsFromName
{
  # First clear the hash
  %gMatchedProcs = ();
  die "Programmer error: hash is supposed to be cleared!" if (scalar(keys %gMatchedProcs));
  my $procName = $_[0];
  die "ProcName is empty!" unless length($procName);
  return $procName if(IsInteger($procName));

  my @procNameList = split(',', $procName);
  foreach(`ps -ef`) {
    my $procLine = $_;
    if ($procLine =~ m/\s*(\w+)\s+(\d+)\s+(\d+)\s+\d+\s+[\w:\d]+\s+[\w\/\d]+\s+\d\d:\d\d:\d\d\s+(.+)$/) {
      my $uid = $1;
      my $pid = $2;
      my $ppid = $3;
      my $cmd = $4;

      my @cmdLineArgs = split(/\s+/, $cmd);
      my $exeName = $cmdLineArgs[0];
      if ($exeName =~ m/\/([\w\d.]+)$/) {
          $exeName = $1;
          print "exename = $exeName\n" if ($gVerbose);;
      }

      print "Matched process line: uid=$uid, pid=$pid, ppid=$ppid, exeName=$exeName\n" if ($gVerbose);

      foreach(@procNameList) {
        if ($exeName eq $_) {
          print "'$procName' corresponds to process ID of '$pid'.\n" if ($gVerbose);
          die "Error in the hash. '$pid' exists in the hash!" if (exists $gMatchedProcs{$pid});
          my @procAssocInfo = ($uid, $ppid, $cmd);
          $gMatchedProcs{$pid} = \@procAssocInfo;
        }
      }
    }
  }

}

sub GetAllThreadsOfProc
{
  (my $procID, my $threadArrayRef, my $secondThreadArrayRef) = @_;

  my $procFolder = "/proc/$procID";
  print "Process '$procID' does not exist! May have just exited\n" unless (-e $procFolder);
  return unless (-e $procFolder);

  # clear arrays
  @{$threadArrayRef} = ();
  @{$secondThreadArrayRef} = ();

  # Add procid to the first group
  push(@{$threadArrayRef}, $procID);

  my @processStackTraceLines = `gstack $procID`;
  my $invalidThreadID = -999;
  my $currThreadID = $invalidThreadID;
  my $twoReniceGroupsExist = (($gNiceValue2ndGroup != $gInvalidNiceValue) ? 1 : 0);
  my $isIn2ndGroup = 0;
  my $secondGroupFunctionMatchStr = ".+" . $gFunctionsInGroup2 . ".+";
  foreach(@processStackTraceLines) {
    if ($_ =~ m/^Thread\s+\d+.+\(LWP\s+(\d+)\)/i) {
        my $firstMatch = $1;
        # Add previous threadid to the first group if it isn't already added to 2nd group
        push(@{$threadArrayRef}, $currThreadID) if ($currThreadID != $invalidThreadID && !$isIn2ndGroup);
        $isIn2ndGroup = 0;
        $currThreadID = $firstMatch;
        print "Inside stack for threadid '$currThreadID'...\n" if ($gVerbose);
        next;
      } elsif ($twoReniceGroupsExist && ($_ =~ m/$secondGroupFunctionMatchStr/)) {
        print "Matched stack-trace line to 2nd group: '$_'\n" if ($gVerbose);
        push(@{$secondThreadArrayRef}, $currThreadID) if ($currThreadID != $invalidThreadID);
        $isIn2ndGroup = 1;
        print "Programmer error: invalid threadID '$currThreadID' found!\n" if ($currThreadID == $invalidThreadID);
      } else {
        print "Skipping stack trace line '$_'...\n" if ($gVerbose);
      }
  }

  print "Unable to find thread with stack trace matching pattern '$secondGroupFunctionMatchStr' and function '$gFunctionsInGroup2'!\n" 
        if (!scalar(@{$secondThreadArrayRef}) && $twoReniceGroupsExist);

  print "Group1 threadids = '@{$threadArrayRef}', Group2 threadids = '@{$secondThreadArrayRef}'\n" if ($gVerbose);

  # my @topCommandLine = "top -H -p $procID -n 1 -b";
  # my @topOutputLines = `@topCommandLine`;
  # print "@topOutputLines\n" if ($gVerbose);
  # foreach(@topOutputLines) {
  #   my @lineTokens = split(" ", $_);
  #   next if (scalar(@topCommandLine) <= 0);
  #   push(@threadArray, $lineTokens[0]) if ($lineTokens[0] =~ m/\d+/);
  # }
  # print "Returning thread ids = '@threadArray'\n" if ($gVerbose);
  # return @threadArray;
}

MAIN:
{

    my $isHelp = 0;
    my $procNameStr;
    my $doEndlessLoop = 0;
    GetOptions("procname=s" => \$procNameStr, "verbose" => \$gVerbose,
               "niceval=i" => \$gNiceValue, "secondniceval=i" => \$gNiceValue2ndGroup,
               "functionin2ndgroup=s" => \$gFunctionsInGroup2, "loop" => \$doEndlessLoop, 
               "interval=i" => \$gLoopIterIntervalInSecs, "help" => \$isHelp) or Usage();
  
    Usage() if ($isHelp);

    Usage("'procname' option must be specified on the command-line!") unless (length($procNameStr));
    if (length($gFunctionsInGroup2) || $gNiceValue2ndGroup != $gInvalidNiceValue) {
      Usage("'Options 'functionin2ndgroup' and 'secondniceval' must be specified together!") 
        unless (length($gFunctionsInGroup2) && $gNiceValue2ndGroup != $gInvalidNiceValue);
    }

    my $currTime = localtime;
    print "$currTime\n";

    UpdatePIDsFromName($procNameStr);
    my @procIDs = keys %gMatchedProcs;
    my $numProcsMatched = @procIDs;
    die "Unable to resolve '$procNameStr' to ID! Num matches = $numProcsMatched" unless ($numProcsMatched && IsInteger($procIDs[0]));

    while (1) {
      while (my ($pid, $pidAssocValsRef) = each(%gMatchedProcs)) {
        my @procThreads, my @procThreads2ndGroup;
        GetAllThreadsOfProc($pid, \@procThreads, \@procThreads2ndGroup);
        foreach(@procThreads) {
          my $currThread = $_;
          my @reniceCmd = split(" ", "renice $gNiceValue -p $currThread");
          print "Running renice command '@reniceCmd'...\n" if ($gVerbose);
          # Run renice command for this process
          print "Error occurred in running command '@reniceCmd'\n" if (system(@reniceCmd) != 0);
        }
        # REVISIT: below loop is identical copy of above code
        foreach(@procThreads2ndGroup) {
          my $currThread = $_;
          my @reniceCmd = split(" ", "renice $gNiceValue2ndGroup -p $currThread");
          print "Running renice command on second group: '@reniceCmd'...\n" if ($gVerbose);
          print "Error occurred in running command '@reniceCmd'\n" if (system(@reniceCmd) != 0);
        }
      }
      last if ($doEndlessLoop == 0);
      sleep $gLoopIterIntervalInSecs;

      $currTime = localtime;
      print "$currTime\n";
      UpdatePIDsFromName($procNameStr);
      @procIDs = keys %gMatchedProcs;
      $numProcsMatched = @procIDs;
      print "Unable to resolve '$procNameStr' to ID! Num matches = $numProcsMatched\n" unless ($numProcsMatched && IsInteger($procIDs[0]));

    }

    exit(0);
}

