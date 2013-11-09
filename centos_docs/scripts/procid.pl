#!/usr/bin/perl
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
my $gprintPPIds;
# Following data is indexed hy procid key: uid, ppid, command-line
my %gMatchedProcs = ();
my $gMatchCmdLinePattern = 0;

sub IsMatchedProcess
{
  my $isMatch = 0;
  my $cmdLine = $_[0];
  my $procName = $_[1];
  if ($gMatchCmdLinePattern) {
      if ($cmdLine =~ m/$procName/) {
        print "'$procName' pattern match is successful.\n" if ($gVerbose);
        $isMatch = 1;
    }
  } else {
      my @cmdLineArgs = split(/\s+/, $cmdLine);
      my $exeName = $cmdLineArgs[0];
      if ($exeName =~ m/\/([\w\d.]+)$/) {
          $exeName = $1;
          print "exename = $exeName\n" if ($gVerbose);;
      }

      if ($exeName eq $procName) {
        print "'$procName' exe match is successful.\n" if ($gVerbose);
        $isMatch = 1;
      }
  }

  return $isMatch;
}

sub UpdatePIDsFromName
{
  my $procName = $_[0];
  die "ProcName is empty!" unless length($procName);
  return $procName if(IsInteger($procName));

  # exclude this process as the command-line contains exe
  my $selfPID = $$;

  foreach(`ps -ef`) {
    my $procLine = $_;
    if ($procLine =~ m/\s*(\w+)\s+(\d+)\s+(\d+)\s+\d+\s+[\w:\d]+\s+[\w\/\d]+\s+\d\d:\d\d:\d\d\s+(.+)$/) {
      my $uid = $1;
      my $pid = $2;
      my $ppid = $3;
      my $cmd = $4;

      next if ($pid == $selfPID);

      print "Checking match of process: uid=$uid, pid=$pid, ppid=$ppid, cmd=$cmd\n" if ($gVerbose);
      if (IsMatchedProcess($cmd, $procName)) {
        die "Error in the hash. '$pid' exists in the hash!" if (exists $gMatchedProcs{$pid});
        my @procAssocInfo = ($uid, $ppid, $cmd);
        $gMatchedProcs{$pid} = \@procAssocInfo;
      }
    }
  }

}

MAIN:
{

    my $procNameStr;
    GetOptions("procname=s" => \$procNameStr, "ppids" => \$gprintPPIds, "pattern" => \$gMatchCmdLinePattern, 
               "verbose" => \$gVerbose) or Usage("");

    die "'procname' option must be specified on the command-line!" unless (length($procNameStr));

    UpdatePIDsFromName($procNameStr);
    my @procIDs = keys %gMatchedProcs;
    my $numProcsMatched = @procIDs;
    die "Unable to resolve '$procNameStr' to ID! Num matches = $numProcsMatched" unless ($numProcsMatched && IsInteger($procIDs[0]));

    while (my ($pid, $pidAssocValsRef) = each(%gMatchedProcs)) {
	my @pidAssocVals = @{$pidAssocValsRef};
	print "pidAssocVals = @pidAssocVals\n" if ($gVerbose);
        print $pid, $gprintPPIds ? ", $pidAssocVals[1]\n" : "\n";
    }
      
    exit(0);
}

