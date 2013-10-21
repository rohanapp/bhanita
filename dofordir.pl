use strict;
use Cwd;
use Getopt::Long;

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
=  -pids 23,34 (comma-separated process IDs)
=  -interval 1 (specify in seconds)

$sep
EOU__
exit(1);
}

my $gVerbose = 0;

my $gSystemCommand = "";

sub PrintIfVerbose
{
    if ($gVerbose) {
	print("$_[0] $_[1]\n");
    }
}

sub RunSystemCommandInCurrDir
{
    die "System command must be specified" if $gSystemCommand eq "";

    my $runStatus = system($gSystemCommand);
    if ($runStatus != 0) {
	print "Error occurred in running the command. Status is '$runStatus'\n";
    }
}

sub WalkOneDirectoryInCurrDirAndApply
{
    my $dirHandle;
    opendir($dirHandle, ".") or die "Unable to open current directory";
    
    my @dirFiles = readdir($dirHandle) or die "Unable to read directory contents of current directory";
    
    foreach(@dirFiles) {
	next if ($_ eq "." || $_ eq "..");
	my $dirPath = "./$_";
	if (-d $dirPath) {
	    #print "Running '$gSystemCommand' in directory '$dirPath'...\n";
	    my $currDir = getcwd;
	    next unless chdir($dirPath); # or die "Unable to change working directory to '$dirPath'";
	    RunSystemCommandInCurrDir();
	    chdir($currDir) or die "Unable to switch back the working directory to '$currDir'";
	}
    }
}

sub SetVerboseMode { $gVerbose = $_[0]; }

MAIN:
{
    GetOptions("verbose" => \$gVerbose, "cmd=s" => \$gSystemCommand) or 
	die usage("Incorrect Usage:");

    SetVerboseMode($gVerbose);

    my $initialWorkDir = getcwd;
    WalkOneDirectoryInCurrDirAndApply;
    chdir($initialWorkDir);

}
