use strict;
use Getopt::Long;
use File::Spec;
use Cwd 'realpath';
use Carp;
use Config;

# Program Parameters

#my $isDesktopJobAnalysis = 0;
#my $projpath = "./20110601_s13dpc_ddr3_rdq_vars22_tsby100.adsn";

#For desktopjob run, put projects/models in a folder
my $isDesktopJobAnalysis = 1;
my $projpath = "./20110601_s13dpc_ddr3_rdq_vars42_tsby100_fordjob.adsn";

my $design = "mic_v79b_dt_rd_da_1_cf_29_lineimp_40_all";
my $parsetup = "Optimetrics:corners";
my $desktoppath = "/home/nareshapp/programs/AnsysEM/designer8.0/Linux/designer";
my $desktopjobpath = "/home/nareshapp/programs/AnsysEM/designer8.0/Linux/desktopjob";
my $numProcs = 8; 
my $preserveCoreFiles = 1;

#debugging parameters
# Turn ON hooking into standard C library functions
# REVISIT todo

# Private variables
my $gStartupDir;
my $gVerbose = 0;
my $gPreviewOnly = 0;

sub Usage
{
    print "$_[0]\n" if ($_[0] ne "");
    print "USAGE:\n";
    print "       Run one parametric analysis per core in manner similar to how LSDSO\n";
    print "       [--v(erbose)]\n";

    exit(1);
}

sub PrintIfVerbose
{
    if ($gVerbose) {
        print "$_[0]\n";
    }
}

sub LaunchParametricAnalysisOnEachProc
{
    my $mainCmdLine = ($Config{osname} =~ m/linux/i) ? "perl ./designerjob.pl" : "perl .\\designerjob.pl";
    $mainCmdLine = $mainCmdLine . " -verbose" if ($gVerbose);
    $mainCmdLine = $mainCmdLine . " -preview" if ($gPreviewOnly); 
    my $ii = 1;
    for ($ii = 1; $ii <= $numProcs; $ii++) {
        my $doCmdLine = $mainCmdLine . " -cleanup -runID $ii $projpath";
        PrintIfVerbose("Running command '$doCmdLine'");
        if (system($doCmdLine) != 0) {
            print "Batch solve command $doCmdLine failed!\n";
        }
    }

    for ($ii = 1; $ii <= $numProcs; $ii++) {
        # Run in background by adding '&' to command-line
        my $doCmdLine = $mainCmdLine . " -analysis -monitor -sleep $ii -runID $ii -model $design -solsetup $parsetup" .
            " -desktoppath $desktoppath $projpath &";
        PrintIfVerbose("Running command in the background '$doCmdLine'");
        if (system($doCmdLine) != 0) {
            print "Background batch solve command $doCmdLine failed!\n";
        }
    }

    # Wait ufor begin of analysis: wait until all lock files to be created
    for ($ii = 1; $ii <= $numProcs; $ii++) {
        my $doCmdLine = $mainCmdLine . " -waitforlock -runID $ii $projpath";
        PrintIfVerbose("Running command '$doCmdLine'");
        if (system("$doCmdLine") != 0) {
            print "Batch solve command $doCmdLine failed!\n";
        }
    }

    # Now wait for end of analysis: wait until all lock files are gone
    for ($ii = 1; $ii <= $numProcs; $ii++) {
        my $doCmdLine = $mainCmdLine . " -waitforunlock -runID $ii $projpath";
        PrintIfVerbose("Running command '$doCmdLine'");
        if (system("$doCmdLine") != 0) {
            print "Batch solve command $doCmdLine failed!\n";
        }
    }

}

sub LaunchDesktopJobAnalysisOnEachProc
{
    my $mainCmdLine = ($Config{osname} =~ m/linux/i) ? "perl ./designerjob.pl" : "perl .\\designerjob.pl";
    $mainCmdLine = $mainCmdLine . " -verbose" if ($gVerbose);
    $mainCmdLine = $mainCmdLine . " -preview" if ($gPreviewOnly); 
    my $ii = 1;
    {
        my $doCmdLine = $mainCmdLine . " -cleanup -runID $ii $projpath";
        PrintIfVerbose("Running command '$doCmdLine'");
        if (system($doCmdLine) != 0) {
            print "Cleanup command '$doCmdLine' failed!\n";
        }
    }

    {
        $ENV{ANSOFT_PRESERVE_CORE_FILES} = '1' if ($preserveCoreFiles);
        my $doCmdLine = ($preserveCoreFiles ? $mainCmdLine . " -preserve" : $mainCmdLine);
        $doCmdLine = $doCmdLine . 
            " -analysis -monitor -engines $numProcs -runID $ii -model $design -solsetup $parsetup" .
            " -desktopjobpath $desktopjobpath $projpath &";
        PrintIfVerbose("Running background command '$doCmdLine'");
        if (system($doCmdLine) != 0) {
            print "Background batch solve command '$doCmdLine' failed!\n";
        }
        delete $ENV{ANSOFT_PRESERVE_CORE_FILES} if ($preserveCoreFiles);
    }

    # Wait ufor begin of analysis: wait until all lock files to be created
    {
        my $doCmdLine = $mainCmdLine . " -waitforlock -runID $ii $projpath";
        PrintIfVerbose("Running command '$doCmdLine'");
        if (system($doCmdLine) != 0) {
            print "Wait-for-lock command '$doCmdLine' failed!\n";
        }
    }

    # Now wait for end of analysis: wait until all lock files are gone
    {
        my $doCmdLine = $mainCmdLine . " -waitforunlock -runID $ii $projpath";
        PrintIfVerbose("Running command '$doCmdLine'");
        if (system($doCmdLine) != 0) {
            print "Wait-for=unlock command '$doCmdLine' failed!\n";
        }
    }

    # Preserve core files deleting rest. (REVISIT: for now just cleanup models directory)
    if ($preserveCoreFiles) {
      print "Keeping around core files. Begin deletion of models folder...\n";
      my $deleteModelsFolderCmd = "find /tmp -name models -type d -prune -print -exec rm -rf {} \\;";
      if (system($deleteModelsFolderCmd) != 0) {
        print "Failed in running command '$deleteModelsFolderCmd'!\n";
      }
      print "Done deletion of models folder.\n";
    }
}

MAIN:
{
    $gStartupDir = File::Spec->rel2abs(File::Spec->curdir());
    PrintIfVerbose("Startup directory is: $gStartupDir");

    GetOptions("verbose" => \$gVerbose, "preview" => \$gPreviewOnly) or Usage("");

    PrintIfVerbose "OS name is: $Config{osname}\n";

    if ($gPreviewOnly) {
        print "\n\n\n";
        print "*"x15 . "PREVEW MODE OUTPUT START" . "*"x15 . "\n";
        print "\n\n\n";
    }
    
    # Run $numIterations parametric-analysis-sets, one after another
    my $numIteratios = 500;
    print "."x5 . "Following steps are run '$numIteratios' times" . "."x5 . "\n\n\n" if ($gPreviewOnly);
    for (my $ii = 0; $ii < $numIteratios; $ii++) {
        print("Run number (0-based) is '$ii'.\n");
        if ($isDesktopJobAnalysis) {
            LaunchDesktopJobAnalysisOnEachProc();
        } else {
            LaunchParametricAnalysisOnEachProc();
        }
        last if ($gPreviewOnly);
    }

    if ($gPreviewOnly) {
        print "\n\n\n";
        print "*"x15 . "PREVEW MODE OUTPUT END" . "*"x15 . "\n";
        print "\n\n\n";
    }
    
}
