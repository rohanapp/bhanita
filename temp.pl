use strict;
use File::Glob;
use Getopt::Long;
use DateTime;
use GlobUtils;
use CodeGen;

#----------------------------------------------------------
sub Usage
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
=  -batchlog     <path-to-project-analysis-batchlog>

$sep
EOU__
exit(1);
}

sub PrintLinearSolveTimesForDSO
{
    my $varSolveTime = $_[0]; #seconds
    my $numParallelEngines = $_[1];
    my $numVariationsPerEng = $_[2];
    my $cumulativeVarSolveTime = $varSolveTime;
    for (my $ii = 0; $ii < $numVariationsPerEng; $ii++) {
	for (my $jj = 0; $jj < $numParallelEngines; $jj++) {
	    print "$cumulativeVarSolveTime\n";
	}
	$cumulativeVarSolveTime += $varSolveTime;
    }
}

sub PrintSerialSolveTimesForDSO
{
    my $varSolveTime = $_[0]; #seconds
    my $cumulativeVarSolveTime = $varSolveTime;
    for (my $ii = 0; $ii < $_[1]; $ii++) {
	print "$cumulativeVarSolveTime\n";
	$cumulativeVarSolveTime += $varSolveTime;
    }
}

MAIN:
{
    my $verbose = 0;
    GetOptions("verbose" => \$verbose) or Usage("Incorrect command-line");

    GlobUtils::OnApplicationStartup($verbose);

    my $startWorkDir = StartingWorkDir;
    print "Starting workdir is '$startWorkDir'\n";

    #CodeGen::InitializeCodeGenDatabases;

    #PrintSerialSolveTimesForDSO(480, 700);
    PrintLinearSolveTimesForDSO(480, 12, 60);

    GlobUtils::OnApplicationExit;
}
