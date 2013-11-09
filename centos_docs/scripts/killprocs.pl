#! /usr/bin/perl
use strict;
use Getopt::Long;
use File::Spec;
use Cwd 'realpath';
use Carp;
use Config;

my $gExcludeProcID;

sub IsInteger
{
  return 1 if ($_[0] =~ m/^\d+$/);
  return 0;
}

sub UpdatePIDFromName
{
  my $procName = $_[0];
  die "ProcName is empty!" unless length($procName);
  return $procName if(IsInteger($procName));

  my $procID;
  foreach(`ps`) {
    my $procLine = $_;
    #print "$procLine\n";
    if ($procLine =~ m/\s*(\d+)\s+.+\s+(\w+)$/) {
      #print "Matched process line: '$1', '$2'\n";
      if ($procName eq $2) {
        $procID = $1;
        print "'$procName' corresponds to process ID of '$procID'.\n";
        last;
      }
    }
  }

  chomp($procID);
  return $procID;
}

  
MAIN:
{

    my $exclProcStr;
    GetOptions("exclude=s" => \$exclProcStr) or Usage("");

    if (length($exclProcStr)) {
      $gExcludeProcID = UpdatePIDFromName($exclProcStr);
      die "Unable to resolve '$exclProcStr' to ID!" unless (IsInteger($gExcludeProcID));
    }

    my @procList = `ps -o pid=`;
    my $selfPID = $$;
    foreach(@procList) {
      my $currProc = $_;
      my $printOut = "'$currProc' : ";
      if ($currProc == $gExcludeProcID || $currProc == $selfPID) {
        $printOut = $printOut . "NOT killed";
      } else {
        my $killCmd = "kill -9 $currProc";
        print "Error running '$killCmd'!\n" if system($killCmd);
        $printOut = $printOut . "$killCmd";
      }
      print("$printOut.\n");
    }
    exit(0);
}

