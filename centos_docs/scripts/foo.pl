use strict;
use Getopt::Long;
use File::Spec;
use Cwd 'realpath';
use Carp;
use Config;

# Program Parameters

# my $isDesktopJobAnalysis = 0;
#my $projpath = "/home/nareshapp/Ansoft/ibm_dso_deck_02/20110601_s13dpc_ddr3_rdq.adsn_vars22_tsby100.adsn";

my $isDesktopJobAnalysis = 1;
my $projpath = "/home/nareshapp/Ansoft/ibm_dso_deck_02/20110601_s13dpc_ddr3_rdq.adsn_vars22_tsby100_fordjob.adsn";
# !NOTE! desktopjob run is done so the models (aka external referened files) are NOT 
# copied to temp folder. Instead, this script sets IBM_MODELS environment variable to below parameter
my $modelsDir = "/home/nareshapp/Ansoft/ibm_dso_deck_02/models";

my $design = "mic_v79b_dt_rd_da_1_cf_29_lineimp_40_all";
my $parsetup = "Optimetrics:corners";
my $desktoppath = "/home/nareshapp/programs/designer8.0/Linux/designer";
my $desktopjobpath = "/home/nareshapp/programs/designer8.0/Linux/desktopjob";
my $numProcs = 4;

MAIN:
{
      print "Keeping around core files. Begin deletion of models folder...\n";
      my $deleteModelsFolderCmd = "find /tmp -name models -type d -prune -print -exec rm -rf {} \\;";
      if (system($deleteModelsFolderCmd) != 0) {
        print "Failed in running command '$deleteModelsFolderCmd'!\n";
      }
      print "Done deletion of models folder.\n";
}
