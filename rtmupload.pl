use strict;
use lib "..\\Lib";
use Cwd;
use Getopt::Long;
use GlobUtils;
use Win32::Clipboard;

# Capture network activity for a given set of process IDs
# Capture the information every second or given amount of time.
# dump activity to stdout

#----------------------------------------------------------
sub usage
{
   my $err = shift;
   my $sep = "="x60 . "\n";

   print $sep;
   if ($err) 
   {
      print "= Error: $err\n";
      print $sep;
   }

   print << "EOU__";
= $0 
= Options:
=  -verbose
=  -index <list-index>
=  -name <list-name>
= Note: list index and name can be obtained by running "perl rtm.pl --show list"
$sep
EOU__
exit(1);
}

MAIN:
{
    my $invalidListIndex = -2323;
    my $listIndex = $invalidListIndex;
    my $listName;

    my $verbose = 0;
    GetOptions("verbose" => \$verbose, "indexOfList=i" => \$listIndex, "nameOfList=s" => \$listName) or 
	die usage("Incorrect Usage:");

    my $initialWorkDir = getcwd;

    SetVerboseMode($verbose);
    die "List index and name must be specified" unless ($listIndex != $invalidListIndex && defined $listName && $listName ne "");

    my $tasksFile = "C:/Users/nappann/rtm/" . $listName . ".txt";
    die "File '$tasksFile' does not exist! Tasks of list must be present in this file" unless (-e $tasksFile);

    my $perlScriptsDir = "d:/programs/perl_scripts";
    chdir($perlScriptsDir) or die "Unable to change working directory to $perlScriptsDir";
    PrintIfVerboseMode("Switched directory to: $perlScriptsDir\n");

    my $tasksFileHandle;
    open($tasksFileHandle, "< $tasksFile") or die "Unable to open $tasksFile for reading";

    my @taskList = <$tasksFileHandle>;
    foreach(@taskList) {
	my $taskStr = $_;
	chomp($taskStr);
	my $addTaskCmdStr = "perl rtm.pl --add \"$taskStr\" --list $listIndex";
	PrintIfVerboseMode("Running command: $addTaskCmdStr\n");
	if (system($addTaskCmdStr) != 0) {
	    warn "Error occurred in running '$addTaskCmdStr'";
	}
    }

    chdir($initialWorkDir);
}
