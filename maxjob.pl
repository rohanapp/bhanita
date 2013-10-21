use strict;
use Getopt::Long;
use File::Spec;
use Cwd 'realpath';
use File::Basename;
use File::Path;
use Carp;
use File::Copy;
use File::Glob ':glob';

my $gStartupDir = "";

# Job ID
my $gJobName = "";

# Job definition
my $gProjPath = "";
my $gDesignName = "";
my $gSolutionSetupName = "";

# Script command purpose
my $gIsBatchSolve = 0;
my $gIsJobCleanup = 0;

# Batchsolve runtime: parallelization, etc.
my $gNewRunID = "";
my $gGraphical = 0;
my $gBatchOptions = "";
my $gNumEngines = 1;
my $gNumProcs = 1;
my $gNumProcsDist = 1;

# Job's resource request from scheduler
my $gNumSlots = 1;
my $gPeName = "mpich";

# Job's debugging/monitoring options
my $gVerbose = 0;
my $gMonitorProgress = 0;
my $gDebugMode = 0;
my $gDebugLog = "";
my $gDebugLogSeparate = 0;
my $gJobEnvVars = "";

my $gMaxPath = "/home/nappann/software/max14.0/maxwell14.0/maxwell";

sub PrintIfVerbose
{
    if ($gVerbose) {
	print "$_[0]\n";
    }
}

# input: directory. 
sub IsDirectory
{
    if (-d $_[0]) {
	return 1;
    }

    return 0;
}

# input: file or directory. 
sub IsFileOrDirWritable
{
    confess "File or Directory '$_[0]' does not exist" unless (-e $_[0]);

    if (-W $_[0]) {
	return 1;
    }
    return 0;
}

# input: file or directory
sub DoesFileOrDirExist
{
    if (-e $_[0]) {
	return 1;
    }
    return 0;
}

# Expects absolute path
# returns name, dir, extension
sub ParseFilePathComponents
{
    confess "Pass absolute path to this function instead of '$_[0]'" 
	unless File::Spec->file_name_is_absolute($_[0]);
    return fileparse($_[0], qr/\.[^.]*/);
}

# input: dir, file name, extn. 
# Expects absolute path for directory component
sub MakeFilePathFromComponents
{
    my $fdir = $_[0];
    my $fname = $_[1];
    my $extn = $_[2];
    $extn = "." . $extn unless ($extn =~ /^\./);
    confess "File directory '$fdir' should be an absolute path" unless File::Spec->file_name_is_absolute($fdir);
    $fname = $fname . $extn if ($extn ne "");

    return File::Spec->catpath("", $fdir, $fname);
}

# input: absolute path
# Simplifies path: cleans up path of .. portions, ~, etc.
sub GetSimplifiedAbsolutePath
{
    my $path = $_[0];
    die "Expecting absolute path rather than $path" unless (File::Spec->file_name_is_absolute($path));

    return realpath($path) if (-e $path);
    (my $pathName, my $pathDir, my $pathExtn) = ParseFilePathComponents($path);
    if ($pathDir ne "") {
	#print "Invoking GetSimplifiedAbsolutePath($pathDir)\n";
	$pathDir = GetSimplifiedAbsolutePath($pathDir);
    }

    return MakeFilePathFromComponents($pathDir, $pathName, $pathExtn);
}

# Pass 2 arguments: relative path, reference directory 
sub GetAbsolutePath
{
    # tilda is a shell construct and perl doesn't understand it
    my $path = $_[0];
    my $homeDir = glob("~");
    $path =~ s/^~/$homeDir/;
    confess "Relative path must be non-empty" if ($path eq "");
    if (!File::Spec->file_name_is_absolute($path)) {
	my $refDir = $_[1];
	confess "Reference directory must be non-empty" if ($refDir eq "");
	$path = File::Spec->rel2abs($path, $refDir);
    }

    my $absPath = GetSimplifiedAbsolutePath($path);
    #print "Absolute path: $absPath\n";
    return $absPath;
}

# Batchsolve options (<design>(:<Nominal|Optimetrics>(:<Setup>)))
sub GetSolveSetupOptionString
{
    my $ssetupStr = "\"" . (($gDesignName ne "" && $gSolutionSetupName ne "") ? 
	($gDesignName . ":" . $gSolutionSetupName) : 
	(($gDesignName ne "") ? $gDesignName : "")) . "\"";
    return $ssetupStr;
}

sub GetQsubArgumentForEnv
{
    my $envStr = "";
    if ($gDebugMode) {
	$envStr = "ANSOFT_DEBUG_MODE=$gDebugMode";
	$envStr = $envStr . ",ANSOFT_DEBUG_LOG=$gDebugLog" if ($gDebugLog ne "");
	$envStr = $envStr . ",ANSOFT_DEBUG_LOG_SEPARATE=$gDebugLogSeparate";
	$envStr = $envStr . ",$gJobEnvVars" if ($gJobEnvVars ne "");
    } else {
	$envStr = $gJobEnvVars if ($gJobEnvVars ne "");
    }
    return $envStr;
}

sub GetBatchOptionsString
{
    my $batchOptionsStr = "'Maxwell2D/Preferences/NumberOfProcessors'=$gNumProcs " .
	"'Maxwell2D/Preferences/NumberOfProcessorsDistributed'=$gNumProcsDist " .
	"'Maxwell3D/Preferences/NumberOfProcessors'=$gNumProcs " .
	"'Maxwell3D/Preferences/NumberOfProcessorsDistributed'=$gNumProcsDist";

    $batchOptionsStr = "\"" . ($gBatchOptions ? "$gBatchOptions " : " ") . $batchOptionsStr . " \"";

    return $batchOptionsStr;
}

# Submit a maxwell job given batchoptions: num processors, num processors distributed
sub BatchSolveMaxwellProject
{
    eval {

	my $projPathToSolve = $gProjPath;
	(my $origProjName, my $origProjDir, my $origProjExtn) = ParseFilePathComponents($projPathToSolve);
	my $defaultJobName = $origProjName;
	if ($gNewRunID ne "") {
	    my $runIDStr = $gNewRunID;
	    my @dirs;
	    if (File::Spec->file_name_is_absolute($gNewRunID)) {
		@dirs = ($gNewRunID);
		# basename returns last level even when the dir string ends with a forward slash
		$runIDStr = basename($gNewRunID);
		PrintIfVerbose("$gNewRunID represents absolute path. Using basename '$runIDStr' as job ID");
	    } else {
		@dirs = ($origProjDir, $gNewRunID);
	    }

	    my $newProjDir = File::Spec->catdir(@dirs);
	    die "Project directory '$newProjDir' already exists" if (-e $newProjDir);

	    mkpath($newProjDir) or die "Unable to create run directory '$newProjDir'";

	    $projPathToSolve = MakeFilePathFromComponents($newProjDir, $origProjName, $origProjExtn);
	    copy($gProjPath, $projPathToSolve) or die "Unable to copy project from " . 
		"'$gProjPath' to '$projPathToSolve'";
	    $defaultJobName = $origProjName . "_" . $runIDStr;
	}

	(my $projName, my $projDir, my $projExtn) = ParseFilePathComponents($projPathToSolve);

	# qsub -b y -cwd -v ANSOFT_DEBUG_MODE=1,ANSOFT_DEBUG_LOG=$HOME/ansdebuglogs/ansdebug.log
	# -pe pename numslots
	# -e projpath -o projpath
	# -N $gJobName maxwell_desktop [-ng] -batchsolve -batchoptions ... 
	# -LogFile projpath/projname_$JOB_ID_$HOSTNAME_batchsolve.log 
	# [-local -distributed] -machinelist num=# projpath
	my @qsubArgs = ("qsub", "-b", "y", "-cwd");

	my $jobEnv = GetQsubArgumentForEnv();
	if ($jobEnv ne "") {
	    push(@qsubArgs, "-v");
	    push(@qsubArgs, $jobEnv);
	}

	push(@qsubArgs, "-pe");
	push(@qsubArgs, $gPeName);
	push(@qsubArgs, $gNumSlots);

	# if directory is specfied, error file with default name (jobid.err) in the below
	# directory will be created
	push(@qsubArgs, "-e");
	push(@qsubArgs, $projDir);

	push(@qsubArgs, "-o");
	push(@qsubArgs, $projDir);

	push(@qsubArgs, "-N");
	push(@qsubArgs, ($gJobName eq "") ? $defaultJobName : $gJobName);

	push(@qsubArgs, "perl");
	push(@qsubArgs, "/home/nappann/scripts/maxjobfromtempdir.pl");
	push(@qsubArgs, $gMaxPath);

	push(@qsubArgs, "-ng") unless ($gGraphical);

	push(@qsubArgs, "-batchsolve");
	my $solveSetupStr = GetSolveSetupOptionString();
	push(@qsubArgs, $solveSetupStr) if ($solveSetupStr =~ /\w+/);

	push(@qsubArgs, "-monitor") if ($gMonitorProgress);
	push(@qsubArgs, "-batchoptions");
	my $batchOptionArgs = GetBatchOptionsString();
	push(@qsubArgs, $batchOptionArgs);

	my $projLogFile = MakeFilePathFromComponents($projDir, "$projName"."_\${JOB_ID}_\${HOSTNAME}_batchsolve", 
						     "log");
	push(@qsubArgs, "-LogFile");
	push(@qsubArgs, $projLogFile);

	push(@qsubArgs, ($gNumEngines > 1) ? "-distributed" : "-local");
	if ($gNumEngines > 1) {
	    push(@qsubArgs, "-machinelist");
	    push(@qsubArgs, "num=".$gNumEngines);
	}

	push(@qsubArgs, $projPathToSolve);

	#push(@qsubArgs, );

	print "Running system command: @qsubArgs\n";
	if (system(@qsubArgs) != 0) {
	    die "Qsub command @qsubArgs failed";
	}
    };

    print "Error occured in BatchSolveMaxwellProject: $@\n" if $@;
}

sub CleanupMaxwellProject
{
    eval {
	my $projResultsFolder = $gProjPath . "results";
	PrintIfVerbose("Removing folder if exists: $projResultsFolder");
	rmtree($projResultsFolder, $gVerbose, 0) if (-e $projResultsFolder);

	my @filesToRm = ( $gProjPath . ".lock", $gProjPath . ".auto" );
	foreach my $ff (@filesToRm) {
	    PrintIfVerbose("Deleting file if exists '$ff'");
	    unlink($ff);
	}
    };
    print "Error occured in CleanupMaxwellProject: $@\n" if $@;
}

# -----------------------------------------------------------------------------------
# Below represent parameters collected by user and are in exact form as input by user
# -----------------------------------------------------------------------------------

my $gInvalidValue = -122334;

# Job ID
my $gSpecifiedJobName = "";

# Job definition
my $gSpecifiedProjPath = "";
my $gSpecifiedDesignName = "";
my $gSpecifiedSolutionSetupName = "";

# Script command purpose
my $gSpecifiedIsBatchSolve = $gInvalidValue;
my $gSpecifiedIsJobCleanup = $gInvalidValue;

# Batchsolve runtime: parallelization, etc.
my $gSpecifiedNewRunID = "";
my $gSpecifiedGraphical = $gInvalidValue;
my $gSpecifiedBatchOptions = "";
my $gSpecifiedNumEngines = $gInvalidValue;
my $gSpecifiedNumProcs = $gInvalidValue;
my $gSpecifiedNumProcsDist = $gInvalidValue;

# Job's resource request from scheduler
my $gSpecifiedNumSlots = $gInvalidValue;
my $gSpecifiedPeName = "";

# Job's debugging/monitoring options
my $gSpecifiedMonitorProgress = $gInvalidValue;
my $gSpecifiedDebugMode = $gInvalidValue;
my $gSpecifiedDebugLog = "";
my $gSpecifiedDebugLogSeparate = $gInvalidValue;
my $gSpecifiedJobEnvVars = "";

my $gSpecifiedMaxPath = "";

sub CopyIfSpecified
{
    if (!($_[0] == $gInvalidValue || $_[0] eq "")) {
	$_[1] = $_[0];
    }
    #print "Copied value is $_[1]\n";
}

sub PrintCommandParameters
{
    if ($gVerbose) {
	print "\nStart printing command parameters...\n";
	print "JobName = $gJobName.\n";
	print "ProjPath = $gProjPath.\n";
	print "DesignName = $gDesignName.\n";
	print "SolutionSetupName = $gSolutionSetupName.\n";
	print "IsBatchSolve = $gIsBatchSolve.\n";
	print "IsJobCleanup = $gIsJobCleanup.\n";
	print "NewRunID = $gNewRunID.\n";
	print "Graphical = $gGraphical.\n";
	print "BatchOptions = $gBatchOptions.\n";
	print "NumEngines = $gNumEngines.\n";
	print "NumProcs = $gNumProcs.\n";
	print "NumProcsDist = $gNumProcsDist.\n";
	print "NumSlots = $gNumSlots.\n";
	print "PeName = $gPeName.\n";
	print "MonitorProgress = $gMonitorProgress.\n";
	print "DebugMode = $gDebugMode.\n";
	print "DebugLog = $gDebugLog.\n";
	print "DebugLogSeparate = $gDebugLogSeparate.\n";
	print "JobEnvVars = $gJobEnvVars.\n";
	print "MaxPath = $gMaxPath.\n";
	print "End printing command parameters\n";
	print "\n";
    }
}

my $gMaxParallelEngines = 1000;
my $gMaxMP = 1000;

# input: value, minval, maxval
sub EnforceSpecifiedValueMinMax
{
    if ($_[0] != $gInvalidValue) {
	die "$_[0] must exist between $_[1] and $_[2]" unless ($_[0] >= $_[1] && $_[0] <= $_[2]);
    }
}

sub InitializeParallelizationParameters
{
    # Num slots must be specified
    die "Num slots must be specified" if ($gSpecifiedNumSlots == $gInvalidValue);
    # Waterloo cluster specifics: PE name must be specified and of form mpi-# when requesting MP
    die "PE name must be specified when requesting multi-processing" 
	if ($gSpecifiedPeName eq "" && ($gSpecifiedNumProcs != $gInvalidValue ||
					$gSpecifiedNumProcsDist != $gInvalidValue));
    die "Serial MP must be specified when distributed MP is specified" 
	if ($gSpecifiedNumProcs == $gInvalidValue &&
	    $gSpecifiedNumProcsDist != $gInvalidValue);
    
    EnforceSpecifiedValueMinMax($gSpecifiedNumSlots, 1, $gMaxParallelEngines);
    EnforceSpecifiedValueMinMax($gSpecifiedNumEngines, 1, $gMaxParallelEngines);
    EnforceSpecifiedValueMinMax($gSpecifiedNumProcs, 1, $gMaxMP);
    EnforceSpecifiedValueMinMax($gSpecifiedNumProcsDist, 1, $gMaxMP);

    CopyIfSpecified($gSpecifiedNumSlots, $gNumSlots);
    CopyIfSpecified($gSpecifiedPeName, $gPeName);

    # if num engines is 1 or unspecified, it's a serial run
    $gNumEngines = 1;
    CopyIfSpecified($gSpecifiedNumEngines, $gNumEngines);

    # if both num procs are not specified, serial/dist MP is not used
    $gNumProcs = 1;
    $gNumProcsDist = 1;
    CopyIfSpecified($gSpecifiedNumProcs, $gNumProcs);
    CopyIfSpecified($gSpecifiedNumProcsDist, $gNumProcsDist);
    # dist MP is same as serial MP, unless specified
    if ($gSpecifiedNumProcs != $gInvalidValue &&
	$gSpecifiedNumProcsDist == $gInvalidValue) {
	$gNumProcsDist = $gSpecifiedNumProcs;
    }

    #PrintIfVerbose("Num engines = $gNumEngines, Serial MP = $gNumProcs, Dist MP = $gNumProcsDist");

    # REVISIT: Below is specific to waterloo cluster
    my $coresPerNode = 1;
    $gPeName =~ /.+(\d+).*/;
    if ($1 ne "") {
	$coresPerNode = $1;
    }
    #PrintIfVerbose("Cores per node assigned to job: $coresPerNode");

    die "Num slots must be greater than num-engines*dist MP" unless ($gNumSlots >= $gNumEngines*$gNumProcsDist);
    die "PE '$gPeName' is not suitable for serial MP '$gNumProcs'" 
	unless ($coresPerNode >= $gNumProcs);
    die "PE '$gPeName' is not suitable for distributed MP '$gNumProcsDist'" 
	unless ($coresPerNode >= $gNumProcsDist);

}

sub IntializeAllData
{
    # Use defaults. Override with options
    InitializeParallelizationParameters()  unless ($gSpecifiedIsBatchSolve == $gInvalidValue);
    CopyIfSpecified($gSpecifiedJobName, $gJobName);
    CopyIfSpecified(GetAbsolutePath($gSpecifiedProjPath, $gStartupDir), $gProjPath);
    CopyIfSpecified($gSpecifiedDesignName, $gDesignName);
    CopyIfSpecified($gSpecifiedSolutionSetupName, $gSolutionSetupName);
    CopyIfSpecified($gSpecifiedIsBatchSolve, $gIsBatchSolve);
    CopyIfSpecified($gSpecifiedIsJobCleanup, $gIsJobCleanup);
    CopyIfSpecified($gSpecifiedNewRunID, $gNewRunID);
    CopyIfSpecified($gSpecifiedGraphical, $gGraphical);
    CopyIfSpecified($gSpecifiedBatchOptions, $gBatchOptions);
    CopyIfSpecified($gSpecifiedMonitorProgress, $gMonitorProgress);
    CopyIfSpecified($gSpecifiedDebugMode, $gDebugMode);
    my $debugLogAbsPath = ($gSpecifiedDebugLog ne "") ? GetAbsolutePath($gSpecifiedDebugLog, $gStartupDir) : "";
    CopyIfSpecified($debugLogAbsPath, $gDebugLog);
    CopyIfSpecified($gSpecifiedDebugLogSeparate, $gDebugLogSeparate);
    CopyIfSpecified($gSpecifiedJobEnvVars, $gJobEnvVars);
    CopyIfSpecified($gSpecifiedMaxPath, $gMaxPath);
}

sub Usage
{
    print "$_[0]\n" if ($_[0] ne "");
    print "USAGE:\n";
    print "       Cleanup project results, lock file, semaphores, etc.\n";
    print "       [--v(erbose)] --cl(eanup) -- projpath\n";

    print "       Submit a batch job given Maxwell project path with options to cleanup prior to job submission\n";
    print "       [--v(erbose)] [--j(obID)=name] [--mod(el)=designname] [--so(lution)=name] [--r(unID)]\n";
    print "       [--g(raphical)] [--b(atchoptions)=val] [--eng(ines)=num] [--MP=num] [--di(stMP)=num]\n";
    print "       [--mon(itorprogress)] [--de(bugMode)=num] [--l(ogFileForDebug)=val] [--se(parateDebugLog)]\n";
    print "       [--p(arallelEnv)] [--n(umslots)=val] [--ma(xwellpath)=val] \n";
    print "       [--a(nalysis)] [--cl(eanup)] [--env=var1=v,var2=v] -- projpath\n";
    print "\n";
    print "       Solution option's value is either Nominal:<setup name> or Optimetrics:<setup name>\n";
    print "       Specify runID to create a copy of project in a new directory with this name and solve copy\n";
    print "\n";
    print "\n";

    exit(1);
}

sub ValidateBatchSolveOptions
{
    Usage "Path to maxwell '$gSpecifiedMaxPath' doesn't exist" 
	if ($gSpecifiedMaxPath ne "" && !DoesFileOrDirExist($gSpecifiedMaxPath));

    Usage "Debug mode must be a positive number and less than 10" 
	if ($gSpecifiedDebugMode != $gInvalidValue && ($gSpecifiedDebugMode >= 10 || $gSpecifiedDebugMode < 0));
    Usage "Debug log separate value must be 1 or 0" 
	if ($gSpecifiedDebugLogSeparate != $gInvalidValue && 
	    ($gSpecifiedDebugLogSeparate != 0 && $gSpecifiedDebugLogSeparate != 1));

    if ($gSpecifiedDebugLog ne "") {
	my $debugLogDir = (ParseFilePathComponents(GetAbsolutePath($gSpecifiedDebugLog, $gStartupDir)))[1];
	Usage "Debug log directory doesn't exist" if (!IsDirectory($debugLogDir));
	Usage "Debug log directory isn't writable" if (!IsFileOrDirWritable($debugLogDir));
	Usage "Debug log '$gSpecifiedDebugLog' should be writable" if (DoesFileOrDirExist($gSpecifiedDebugLog) && 
								       !IsFileOrDirWritable($gSpecifiedDebugLog));
    }

    print "Warning: Serial MP and Distributed MP value is typically same!\n" 
	if ($gSpecifiedNumProcs != $gSpecifiedNumProcsDist);
}

sub ValidateOptionsAndArguments
{
    Usage "At least one of the actions must be specified: cleanup, analysis"
	if ($gSpecifiedIsBatchSolve == $gInvalidValue && $gSpecifiedIsJobCleanup == $gInvalidValue);

    Usage "Project path must be specified" if ($gSpecifiedProjPath eq "");

    Usage "Project '$gSpecifiedProjPath' doesn't exist" 
	if (!DoesFileOrDirExist(GetAbsolutePath($gSpecifiedProjPath, $gStartupDir)));

    my $projDir = (ParseFilePathComponents(GetAbsolutePath($gSpecifiedProjPath, $gStartupDir)))[1];
    Usage "Project '$gSpecifiedProjPath' and it's container directory must be writable"
	if (!IsFileOrDirWritable($gSpecifiedProjPath) || !IsFileOrDirWritable($projDir));

    ValidateBatchSolveOptions() unless ($gSpecifiedIsBatchSolve == $gInvalidValue);

    print "\n";
}

# Pass begin-str, end-string such as new-line, value, override for default str (optional), 
# override for value (optional)
sub PrintSpecifiedValueOrDefault
{
    print "$_[0]";
    if (($_[2] == $gInvalidValue || $_[2] eq "")) {
	if ($_[3] eq "") {
	    print "default";
	} else {
	    print $_[3];
	}
    } else {
	if ($_[4] eq "") {
	    print $_[2];
	} else {
	    print $_[4];
	}
    }
    print "$_[1]";
}

sub PrintOptions
{
    if ($gVerbose) {
	print "\nStart printing job options...\n";

	PrintSpecifiedValueOrDefault("Is cleanup action: ", "\n", $gSpecifiedIsJobCleanup, "no", "yes");
	PrintSpecifiedValueOrDefault("Is batch solve action: ", "\n", $gSpecifiedIsBatchSolve, "no", "yes");
	PrintSpecifiedValueOrDefault("Job name is: ", "\n", $gSpecifiedJobName);
	PrintSpecifiedValueOrDefault("Project path: ", "\n", $gSpecifiedProjPath);
	PrintSpecifiedValueOrDefault("Design name: ", "\n", $gSpecifiedDesignName);
	PrintSpecifiedValueOrDefault("Solution setup: ", "\n", $gSpecifiedSolutionSetupName);
	PrintSpecifiedValueOrDefault("New directory for this run: ", "\n", $gSpecifiedNewRunID, "no");
	PrintSpecifiedValueOrDefault("Graphical solve: ", "\n", $gSpecifiedGraphical, "no", "yes");
	PrintSpecifiedValueOrDefault("Specified batch options: ", "\n", $gSpecifiedBatchOptions, "none");
	PrintSpecifiedValueOrDefault("Number of distributed engines: ", "\n", $gSpecifiedNumEngines, $gNumEngines);
	PrintSpecifiedValueOrDefault("Serial MP: ", "\n", $gSpecifiedNumProcs, $gNumProcs);
	PrintSpecifiedValueOrDefault("Distributed MP: ", "\n", $gSpecifiedNumProcsDist, $gNumProcsDist);
	PrintSpecifiedValueOrDefault("Num slots requested from scheduler: ", "\n", 
				     $gSpecifiedNumSlots, $gNumSlots);
	PrintSpecifiedValueOrDefault("Parallel enviroment requested: ", "\n", $gSpecifiedPeName, $gPeName);
	PrintSpecifiedValueOrDefault("Ansoft debug mode: ", "\n", $gSpecifiedDebugMode, "OFF", "ON");
	PrintSpecifiedValueOrDefault("Ansoft debug mode level: ", "\n", $gSpecifiedDebugMode, "N/A");
	PrintSpecifiedValueOrDefault("Ansoft debug log path: ", "\n", $gSpecifiedDebugLog, "stdout");
	PrintSpecifiedValueOrDefault("Debug logs are separate: ", "\n", $gSpecifiedDebugLogSeparate, "no", "yes");
	PrintSpecifiedValueOrDefault("Maxwell path: ", "\n", $gSpecifiedMaxPath, $gMaxPath);
	PrintSpecifiedValueOrDefault("Specified job enviroment variables: ", "\n", $gSpecifiedJobEnvVars, "none");
	#PrintSpecifiedValueOrDefault("", "\n", $);

	print "Done printing job options.\n\n";

	# print ": $\n";
    }

}

MAIN:
{
    $gStartupDir = File::Spec->rel2abs(File::Spec->curdir());
    PrintIfVerbose("Startup directory is: $gStartupDir");

    GetOptions("verbose" => \$gVerbose, "cleanup" => \$gSpecifiedIsJobCleanup, 
	       "analysis" => \$gSpecifiedIsBatchSolve, "jobID=s" => \$gSpecifiedJobName, 
	       "model=s" => \$gSpecifiedDesignName, "solution=s" => \$gSpecifiedSolutionSetupName, 
	       "runID=s" => \$gSpecifiedNewRunID, 
	       "graphical" => \$gSpecifiedGraphical, "batchoptions=s" => \$gSpecifiedBatchOptions, 
	       "engines=i" => \$gSpecifiedNumEngines, 
	       "MP=i" => \$gSpecifiedNumProcs, "distMP=i" => \$gSpecifiedNumProcsDist, 
	       "monitorprogress" => \$gSpecifiedMonitorProgress, 
	       "debugMode=i" => \$gSpecifiedDebugMode, "logFileForDebug=s" => \$gSpecifiedDebugLog, 
	       "separateDebugLog" => \$gSpecifiedDebugLogSeparate, "parallelEnv=s" => \$gSpecifiedPeName, 
	       "numslots=i" => \$gSpecifiedNumSlots, "maxwellpath=s" => \$gSpecifiedMaxPath, 
	       "env=s" => \$gSpecifiedJobEnvVars) or Usage("");


    my $numArgs = @ARGV;
    Usage("This script accepts a single project_path argument and a number of options. See usage.") 
	if ($numArgs != 1);
    $gSpecifiedProjPath = @ARGV[0];

    PrintOptions();

    eval {
	ValidateOptionsAndArguments();
	IntializeAllData();
	PrintCommandParameters();
	CleanupMaxwellProject() if ($gIsJobCleanup);
	BatchSolveMaxwellProject() if ($gIsBatchSolve);
    };
    
    print "Error occured during script execution: $@\n" if ($@);

}

