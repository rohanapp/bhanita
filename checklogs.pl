use strict;
use File::Glob;
use Getopt::Long;
use DateTime;
use GlobUtils;
use CodeGen;
use Cwd;
use File::stat;

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
=  --verbose 
=  --view <view-root-dir> Root directory of the view for which log summary is printed
=  --details Print errors/warnings summary per project
=  --filter <log-file-name>  Print errors/warnings summary for just this log file
=  --ignorelogs <number-of-hours-since-last-build> Ignore logs that are older than the specified hours
=
= Run the perl script from the directory of containing perl script
= Examples:
=   <cmd-prompt> perl checklogs.pl --view c:\\cviews\\nappann_core5_view
=   <cmd-prompt> perl checklogs.pl --view c:\\cviews\\nappann_core5_view --filter Core
=   <cmd-prompt> perl checklogs.pl --view c:\\cviews\\nappann_core5_view --filter debug/Core
=   <cmd-prompt> perl checklogs.pl --view c:\\cviews\\nappann_core5_view --ignorelogs 1
$sep
EOU__
exit(1);
}

my $gPrintDetails = 0;
my $gViewRootDir = "";
my $gIgnoreLogsOlderByHours = -1;
sub CheckGivenLogFile
{
    my $logFile = $_[0];
    
    my $logFileHandle;
    open($logFileHandle, "< $logFile") or die "Unable to open '$logFile' for reading";

    my $fileStats = stat($logFile);
    my $fileEpochTime = $fileStats->mtime;
    my $currTime = time;
    my $elapsedTimeTargetInSecs = $gIgnoreLogsOlderByHours*60*60;
    my $timeElapsedSinceLastBuild = $currTime - $fileEpochTime;
    PrintIfVerboseMode("timeElapsedSinceLastBuild = $timeElapsedSinceLastBuild, target = $elapsedTimeTargetInSecs\n");
    return if ($gIgnoreLogsOlderByHours > 0) && ($timeElapsedSinceLastBuild > $elapsedTimeTargetInSecs);

    my $fileLastModifyTime = localtime($fileEpochTime);

    my @logFileLines = <$logFileHandle>;
    my @logLinesWError = grep(/(error)|(warning)/, @logFileLines);
    my $buildSummaryStringMatch = "Build.+(\\d+).+succeeded.+(\\d+).+failed";
    my @buildSummaryList = grep(/$buildSummaryStringMatch/, @logFileLines);
    my $buildSummaryLine = "";
    $buildSummaryLine = $buildSummaryList[0] if (ArrayLength(\@buildSummaryList) > 0);

    #my $logFileBegin = "*"x15 . "$logFile" . "*"x15;
    my $logFileBegin = "$logFile ($fileLastModifyTime)";
    print "\n\n$logFileBegin\n\n";
    print "\t$buildSummaryList[0]\n";
    if ($gPrintDetails != 0) {
	map { print "\t$_" } @logLinesWError;
    }
}


my $gLogFileFilter = "";

MAIN:
{
    my $verbose = 0;
    
    GetOptions("verbose" => \$verbose, "view=s" => \$gViewRootDir, "details" => \$gPrintDetails, 
	       "filter=s" => \$gLogFileFilter, "ignorelogs=i" => \$gIgnoreLogsOlderByHours) or Usage("Incorrect command-line");

    Usage("View root dir must be specified!") if ($gViewRootDir eq "");
    Usage("'$gViewRootDir' does not exist - a valid view root dir must be specified!") unless (-e $gViewRootDir);

    GlobUtils::OnApplicationStartup($verbose);
    my $startingDir = StartingWorkDir();

    my @logFileDirs = ("nextgen/ansoftcore", "nextgen/ansoftcore/products/reportsetup/reportsetuptest", 
		       "nextgen/ansoftcore/products/desktopjob", "nextgen");

    my @buildConfigSubDirs = ("64Debug", "64Release", "debug", "release");
    # Once for debug and once for release
    foreach (@buildConfigSubDirs) {

	my $buildConfigSubDir = $_;

	foreach(@logFileDirs) {
	    
	    my $logFileTopDir = "$_/$buildConfigSubDir";

	    my $currWD = getcwd;
	    my $logDir = MakeDirPathFromComponentDirs($gViewRootDir, $logFileTopDir);
	    if (chdir($logDir)) {
		my @logFilesInThisDir = glob('*.log');
		foreach(@logFilesInThisDir) {
		    my $logFileAbsPath = GetAbsolutePath($_, $logDir);
		    next if ($gLogFileFilter ne "") && (!($logFileAbsPath =~ /$gLogFileFilter/));
		    CheckGivenLogFile($logFileAbsPath);
		}
	    } else {
		PrintIfVerboseMode("Unable to change directory to '$logDir'. This log will be skipped.\n");
	    }
	    chdir($currWD);
	}
    }

    #CodeGen::InitializeCodeGenDatabases;

    GlobUtils::OnApplicationExit;
}
