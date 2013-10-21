use strict;
use lib "..\\Lib";
use Cwd;
use Getopt::Long;
use GlobUtils;
use Win32::Clipboard;

my @gProcIDs = "";
my $gTimeIntervalSecs = 1;

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
=  -pids 23,34 (comma-separated process IDs)
=  -interval 1 (specify in seconds)

$sep
EOU__
exit(1);
}

my $gModifiedSinceDays = 1;
my $gTodayYear;
my $gTodayMonth;
my $gTodayDay;

# sub IsFileModifiedSinceGivenDays
# {
#     my ($year, $month, $day) = GetLastModifyDateForFile($ff);

#     return 0 if ($year != $gTodayYear || $month != $gTodayMonth);
#     return 1 if ( ($gTodayDay - $day) <= $gModifiedSinceDays);
#     return 0;
# }    

sub PrintAction
{
    my ($dirName, $fileName) = @_;
    print "$dirName, $fileName\n";
}

sub PrintIfModifiedSinceDaysAction
{
    my ($dirName, $fileName) = @_;
    my $filePath = "$dirName/$fileName";
    die "$filePath does not exist!" unless (-e $filePath);

    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
	$atime,$mtime,$ctime,$blksize,$blocks)
           = stat($filePath);

    my $currTime = time;
    my $modifiedSinceInSecs = $gModifiedSinceDays*24*60*60;
    my $timeElapsedSinceLastModify = $currTime - $mtime;
    PrintIfVerboseMode("timeElapsedSinceLastModify = $timeElapsedSinceLastModify, target = $modifiedSinceInSecs\n");
    if ($timeElapsedSinceLastModify < $modifiedSinceInSecs) {
	print "$dirName, $fileName\n";
    }
}

sub WalkDirectoryTreeAndApply
{
    my ($dirName, $funcPtr) = @_;

    my $dirHandle;
    opendir($dirHandle, $dirName) or die "Unable to open '$dirName'";
    
    my @dirFiles = readdir($dirHandle) or die "Unable to read directory contents '$dirName'";
    
    foreach(@dirFiles) {
	next if ($_ eq "." || $_ eq "..");
	my $dirPath = "$dirName/$_";
	if (-d $dirPath) {
	    WalkDirectoryTreeAndApply($dirPath, $funcPtr);
	    PrintIfVerboseMode("Invoking WalkDirectoryTreeAndApply using args $dirPath, $funcPtr\n");
	} else {
	    PrintIfVerboseMode("Applying action on file '$_'...\n");
	    $funcPtr->($dirName, $_);
	    PrintIfVerboseMode("Done applying action.\n");
	}
    }
}


sub PrintConnectionIfMatchProcID
{
    my $procID = $_[0];
    my $netStatLineStr = $_[1];
    foreach (@gProcIDs) {
	if ($procID eq $_) {
	    print ("$netStatLineStr\n");
	}
    }
}

sub PrintTCPPortSnapshot
{
    my $netStatOutput = `netstat -aon`;

    my @netConnectionList = split("\n", $netStatOutput);
    
    foreach (@netConnectionList) {
	if ($_ =~ /([\d]+)$/) {
	    PrintConnectionIfMatchProcID($1, $_);
	}
    }
}

sub TestTCP
{
    my $procIDsStr = "";
    my $verbose = 0;
    GetOptions("verbose" => \$verbose, "pids=s" => \$procIDsStr, 
	       "interval=f" => \$gTimeIntervalSecs) or die usage("Incorrect Usage:");

    print ("Verbose flag is: $verbose\n");

    PrintIfVerboseMode("Process ID string is:", $procIDsStr);
    PrintIfVerboseMode("Time interval (milliseconds):", $gTimeIntervalSecs);

    @gProcIDs = split(",", $procIDsStr);

    my $ii = 1;
    while(1) {
	print ("Capture number: $ii\n");
	PrintTCPPortSnapshot;
	print ("\n\n");
	$ii++;
	sleep $gTimeIntervalSecs;
    }
}

sub AddSemicolonToEndOfCodeLine
{
    my $inputFile = $_[0];
    my $hh;
    open($hh, "< $inputFile") or die "Unable to open '$inputFile' for reading";

    my $tempOut = $inputFile . "_temp";
    my $ohh;
    open($ohh, "> $tempOut") or die "Unable to open '$tempOut' for writing";
    while(<$hh>) {
	if (IsCommentOrSpace($_) || $_ =~ m/[;}{]/){
	    print $ohh $_;
	    next;
	}
	my $lineStr = $_;
	chomp($lineStr);
	$lineStr =~ s/\Q$lineStr/$lineStr;/;
	print $ohh "$lineStr\n";
    }

    close $hh;
    close $ohh;
}

sub FixGeneratedCode
{
    my $inputFile;
    my $srcType;
    my $destType;
    my $destFile;
    my $verbose = 0;
    GetOptions("verbose" => \$verbose, "stype=s" => \$srcType, "dtype=s" => \$destType, "input=s" => \$inputFile, "out=s" => \$destFile) or 
	die usage("Incorrect Usage:");
    die "Src type must be specified" if !defined $srcType || $srcType eq "";
    die "Dest type must be specified" if !defined $destType || $destType eq "";
    die "File must be specified" if !defined $inputFile || $inputFile eq "";

    my ($inputFile, $srcType, $destType, $destFile) = @_;

    my $hh;
    open($hh, "< $inputFile") or die "Unable to open '$inputFile' for reading";

    my $tempOut = $inputFile . "_temp";
    if (defined $destFile && $destFile ne "") {
	$tempOut = $destFile;
    }

    # Don't truncate output file until parsing is done. Output file can be same as input file
    my @outPutFileStrs;

    while(<$hh>) {
	if (IsCommentOrSpace($_)) {
	    push @outPutFileStrs, $_;
	    next;
	}
	my $lineStr = $_;
	chomp($lineStr);
	$lineStr =~ s/\Q$srcType/$destType/;
	push @outPutFileStrs, "$lineStr\n";
    }
    close $hh;

    my $ohh;
    open($ohh, "> $tempOut") or die "Unable to open '$tempOut' for writing";
    map {print $ohh $_} @outPutFileStrs;
    close $ohh;

    print "Output is generated in file: $tempOut\n";
}

sub CopyStringsToClipboard
{
    my $strToClipBoard = join("", @_);

    my $CLIP = Win32::Clipboard();
    $CLIP->Set($strToClipBoard);
}

#static str kMonitorOptionName {na}
#static str kLogFileOptionName {na}
sub ReplaceLiteralsWithConstantVars
{
#    ("monitor", po::value<string>()->zero_tokens(), "Monitor the job using it's standard output. You can pipe the standard output and standard"
#     " error streams to files located on a network drive.")
#    ("logfile", po::value<string>(), "Specify the file to log the analysis progress and status")
    my @outStrs;
    while(<STDIN>) {
	($_ =~ s/\Q"monitor"/CharPtr(kMonitorOptionName)/ ||
	 $_ =~ s/\Q"batchoptions"/CharPtr(kOptionName)/ ||
	 $_ =~ s/\Q"env"/CharPtr(kEnvOptionName)/ ||
	 $_ =~ s/\Q"productname"/CharPtr(kProductNameOptionName)/ ||
	 $_ =~ s/\Q"productversion"/CharPtr(kProductVersionOptionName)/ ||
	 $_ =~ s/\Q"distributed"/CharPtr(kDistributedOptionName)/ ||
	 $_ =~ s/\Q"ng"/CharPtr(kNgOptionName)/ ||
	 $_ =~ s/\Q"WaitForLicense"/CharPtr(kWaitForLicenseOptionName)/ ||
	 $_ =~ s/\Q"mp"/CharPtr(kMPOptionName)/ ||
	 $_ =~ s/\Q"jobcores"/CharPtr(kJobCoresOptionName)/ ||
	 $_ =~ s/\Q"batchsolve"/CharPtr(kBatchSolveOptionName)/ ||
	 $_ =~ s/\Q"abort"/CharPtr(kAbortOptionName)/ ||
	 $_ =~ s/\Q"project"/CharPtr(kProjectOptionName)/ ||
	 $_ =~ s/\Q"logfile"/CharPtr(kLogFileOptionName)/);
	last if $_ =~ m/^done\s*$/;
	push @outStrs, $_;
    }

    map {print $_} @outStrs;
    CopyStringsToClipboard(@outStrs);
}

MAIN:
{
    my $inputDirName;
    my $referenceDir;
    my $verbose = 0;

    GetOptions("verbose" => \$verbose, "inputdir=s" => \$inputDirName, "refdir=s" => \$referenceDir,
	       "modsince=s" => \$gModifiedSinceDays) or 
	die usage("Incorrect Usage:");

    SetVerboseMode($verbose);

    my $initialWorkDir = getcwd;
    chdir($referenceDir) or die "Unable to change working directory to '$referenceDir'";
    WalkDirectoryTreeAndApply($inputDirName, \&PrintIfModifiedSinceDaysAction);
    chdir($initialWorkDir);

}
