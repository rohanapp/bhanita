use strict;
use lib "d:\\programs\\perl_scripts";
use Cwd;
use Getopt::Long;
use GlobUtils;
use Win32::Clipboard;
use File::Path qw(make_path remove_tree);
use File::Copy;

my $gVerbose = 0;
my $gInitialWorkDir;

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
=  -inputdir dirname (starting directory from which file system will be traversed)
=  -refdir dirpath ('dirname' is only valid when working directory is set to 'dirpath')
=  -select extensions
=  -modsince 1 (take action only on the files that are modified with the last given number of days)
=  -destdir dir
= Example: perl filesystemtraverse.pl -v -input lib -refdir c:\\cviews\\nappann_core5_view\\nextgen\\ansoftcore -modsince 2 -destdir d:\\dtemp\\largedsosourcecode
= Example: perl filesystemtraverse.pl -input NgAnsoftCOMApp -refdir \\sjo7na1\Views\nappann_r14_view\nextgen\ansoftcore\lib -destdir d:\dtemp\largedsofromPC\lib -action archiveall
= Example: perl filesystemtraverse.pl -input NgAnsoftCOMApp -refdir \\sjo7na1\Views\nappann_r14_view\nextgen\ansoftcore\lib -select cpp,h,c,vcproj,rc,rc2 -destdir d:\dtemp\largedsofromPC\lib -action archiveall
$sep
EOU__
exit(1);
}

my $gModifiedSinceDays = 1;
my @gFileFilterList = ();

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

my $gDerivedFileExtnMatchStr = "(ocx)|(exe)|(dll)|(obj)|(idb)|(pdb)|(user)|(htm)|(pch)|(dep)|(sbr)|(manifest)|(res)|(ncb)|(lib)|(log)|(tlb)|(suo)|(bsc)|(ilk)|(exp)|(aps)|(keep)|(contrib)|(ppt)|(doc)|(dsm)|(zip)";
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
	my $filePathAbs = GetAbsolutePath($filePath, $gInitialWorkDir);
	my ($name, $destDirAbsPath, $extn) = ParseFilePathComponents($filePathAbs);
	print "$dirName, $fileName\n" unless ($extn =~ m/$gDerivedFileExtnMatchStr/);
    }
}

my $gDestDirAbsPath;
sub CopyModsToDestinationDirAction
{
    my ($dirName, $fileName) = @_;
    my $filePath = "$dirName/$fileName";
    die "$filePath does not exist!" unless (-e $filePath);
    die "'$gDestDirAbsPath' doesn't exist" unless (-e $gDestDirAbsPath);

    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
	$atime,$mtime,$ctime,$blksize,$blocks)
           = stat($filePath);

    my $currTime = time;
    my $modifiedSinceInSecs = $gModifiedSinceDays*24*60*60;
    my $timeElapsedSinceLastModify = $currTime - $mtime;
    PrintIfVerboseMode("timeElapsedSinceLastModify = $timeElapsedSinceLastModify, target = $modifiedSinceInSecs\n");
    if ($timeElapsedSinceLastModify < $modifiedSinceInSecs) {
	my $srcFile = GetAbsolutePath($filePath, $gInitialWorkDir);
	my $destFileAbsPath = "$gDestDirAbsPath/$filePath";

	my ($name, $destDirAbsPath, $extn) = ParseFilePathComponents($destFileAbsPath);
	PrintIfVerboseMode("destDir = $destDirAbsPath\n");

	# ignore many extensions
	next if ($extn =~ m/$gDerivedFileExtnMatchStr/);

	# In scalar context, returns the number of directories created. In array context,
	# returns the list of directories created
	make_path($destDirAbsPath);

	print "copy $srcFile -> $destFileAbsPath\n";
	copy($srcFile, $destFileAbsPath) or die "Copy $srcFile -> $destFileAbsPath failed!";
    }
}

sub CopyCodeSrcFileToDestinationDirAction
{
    my ($dirName, $fileName) = @_;
    my $filePath = "$dirName/$fileName";
    die "$filePath does not exist!" unless (-e $filePath);
    die "'$gDestDirAbsPath' doesn't exist" unless (-e $gDestDirAbsPath);

    my $srcFile = GetAbsolutePath($filePath, $gInitialWorkDir);
    my $destFileAbsPath = "$gDestDirAbsPath/$filePath";

    my ($name, $destDirAbsPath, $extn) = ParseFilePathComponents($destFileAbsPath);
    PrintIfVerboseMode("destDir = $destDirAbsPath\n");

    # ignore many extensions
    if (!($extn =~ m/$gDerivedFileExtnMatchStr/)) {

	# In scalar context, returns the number of directories created. In array context,
	# returns the list of directories created
	make_path($destDirAbsPath);

	print "copy $srcFile -> $destFileAbsPath\n";
	copy($srcFile, $destFileAbsPath) or die "Copy $srcFile -> $destFileAbsPath failed!";
    }
}

# Returns ($hrs, $mins, $secs, $aMPM, $month, $dayOfMonth, $year)
sub ParseTimeStringFromBatchLog
{
    my ($hrs, $mins, $secs, $aMPM, $month, $dayOfMonth, $year) = 
	($_[0] =~ m/(\d+):(\d+):(\d+)\s+(AM|PM)\s+(\w+)\s+(\d+),\s+(\d+)/);

    $hrs = 0 if $hrs == 12;
    my $hourIn24Form = ($aMPM eq "AM") ? $hrs : $hrs + 12;

    return ($hourIn24Form, $mins, $secs, $aMPM, $month, $dayOfMonth, $year);
}

my %jobSolveDoneTimeStrings;

sub PrintBatchAnalysisDoneTime
{
    my ($dirName, $fileName) = @_;
    my $filePath = "$dirName/$fileName";

    my $srcFile = GetAbsolutePath($filePath, $gInitialWorkDir);
    my ($name, $destDirAbsPath, $extn) = ParseFilePathComponents($srcFile);

    # check only batch.log file
    next if ($extn ne ".log" || $name ne "batch");
    #print("Processing $srcFile...\n");

    my $tailCmdStr = "tail --lines=1 $srcFile";
    my $tailOut = (`$tailCmdStr`);

    my @batchLogLines = split("\n", $tailOut);
    my $numLines = ArrayLength(\@batchLogLines);

    my $lastLineStr = $batchLogLines[$numLines-1];
    my ($hrs, $mins, $secs, $aMPM, $month, $dayOfMonth, $year) = 
	ParseTimeStringFromBatchLog($lastLineStr);

    my $doneTimeStr = "$hrs:$mins:$secs";
    AddNewEntryToHash(\%jobSolveDoneTimeStrings, $filePath, $doneTimeStr);

}

sub WalkDirectoryTreeAndApply
{
    my ($dirName, $funcPtr) = @_;

    my $dirHandle;
    opendir($dirHandle, $dirName) or die "Unable to open '$dirName'";
    
    my @dirFiles = readdir($dirHandle) or die "Unable to read directory contents '$dirName'";

    my $fileFilterExists = ArrayLength(\@gFileFilterList) ? 1 : 0;
    
    PrintIfVerboseMode("WalkDirectoryTreeAndApply invoked using args $dirName, $funcPtr. Filefilter = $fileFilterExists\n");
    foreach(@dirFiles) {
	next if ($_ eq "." || $_ eq "..");
	my $currFName = $_;
	my $dirPath = "$dirName/$currFName";
	if (-d $dirPath) {
	    WalkDirectoryTreeAndApply($dirPath, $funcPtr);
	} else {
	    my $filePathAbs = GetAbsolutePath($dirPath, $gInitialWorkDir);
	    if ($fileFilterExists) {
		my ($nn, $dd, $extn) = ParseFilePathComponents($filePathAbs);
		goto processfile if ($extn eq "");
		my $fileMatches = 0;
		foreach(@gFileFilterList) {
		    my $selectedExtn = "." . $_;
		    if ($extn eq $selectedExtn) {
			$fileMatches = 1;
			last;
		    }
		}
		next if ($fileMatches == 0);
	    }
processfile:
	    PrintIfVerboseMode("Applying action on file '$currFName'...\n");
	    $funcPtr->($dirName, $currFName);
	    PrintIfVerboseMode("Done applying action.\n");
	}
    }
}

# Sample commandlines
#
# Copy desktopjob sources from PC to laptop
# LIBS:
# -input NgAnsoftCOMApp -refdir \\sjo7na1\Views\nappann_r14_view\nextgen\ansoftcore\lib -modsince 1 -destdir d:\dtemp\largedsofromPC\lib -action archiveall
# -input mxwlresextractor -refdir \\sjo7na1\Views\nappann_r14_view\nextgen\ansoftcore\lib -modsince 1 -destdir d:\dtemp\largedsofromPC\lib -action archiveall
# -input wbintegutils -refdir \\sjo7na1\Views\nappann_r14_view\nextgen\ansoftcore\lib -modsince 1 -destdir d:\dtemp\largedsofromPC\lib -action archiveall
# -input Desktop -refdir \\sjo7na1\Views\nappann_r14_view\nextgen\ansoftcore\lib -modsince 1 -destdir d:\dtemp\largedsofromPC\lib -action archiveall
# PRODS:
# -input desktopjob -refdir \\sjo7na1\Views\nappann_r14_view\nextgen\ansoftcore\products -modsince 1 -destdir d:\dtemp\largedsofromPC\products -action archiveall
# -input djobextractor -refdir \\sjo7na1\Views\nappann_r14_view\nextgen\ansoftcore\products -modsince 1 -destdir d:\dtemp\largedsofromPC\products -action archiveall
# -input optimetrics/ui -refdir \\sjo7na1\Views\nappann_r14_view\nextgen\ansoftcore\products -modsince 1 -destdir d:\dtemp\largedsofromPC\products -action archiveall


MAIN:
{
    my $inputDirName;
    my $referenceDir;

    # possible actions: archivemodfiles, solveendtimes, archiveall
    my $actionKwd = "archivemodfiles";

    my $fileFilterStr = "";

    GetOptions("verbose" => \$gVerbose, "inputdir=s" => \$inputDirName, "refdir=s" => \$referenceDir,
	       "modsince=s" => \$gModifiedSinceDays, "destdir=s" => \$gDestDirAbsPath, "action=s" => \$actionKwd, "select=s" => \$fileFilterStr) or 
	die usage("Incorrect Usage:");

    SetVerboseMode($gVerbose);

    $gInitialWorkDir = getcwd;
    my $startWorkDir = getcwd;

    if ($fileFilterStr ne "") {
	@gFileFilterList = CleanSplit($fileFilterStr, ",");
	PrintIfVerboseMode("File filter = @gFileFilterList\n");
    }

    if ($actionKwd eq "solveendtimes") {
	WalkDirectoryTreeAndApply($inputDirName, \&PrintBatchAnalysisDoneTime);
        foreach(keys %jobSolveDoneTimeStrings) {
	    my $dirName = $_;
	    print "$dirName, $jobSolveDoneTimeStrings{$dirName}\n";
	}
    } elsif ($actionKwd eq "archivemodfiles") {

	chdir($referenceDir) or die "Unable to change working directory to '$referenceDir'";
	$gInitialWorkDir = getcwd;

	$gDestDirAbsPath = GetAbsolutePath($gDestDirAbsPath, $startWorkDir);
	PrintIfVerboseMode("Aboslute path of destination directory: $gDestDirAbsPath\n");

	WalkDirectoryTreeAndApply($inputDirName, \&CopyModsToDestinationDirAction);
	# WalkDirectoryTreeAndApply($inputDirName, \&PrintIfModifiedSinceDaysAction);
    } elsif ($actionKwd eq "archiveall") {

	chdir($referenceDir) or die "Unable to change working directory to '$referenceDir'";
	$gInitialWorkDir = getcwd;

	$gDestDirAbsPath = GetAbsolutePath($gDestDirAbsPath, $startWorkDir);
	PrintIfVerboseMode("Aboslute path of destination directory: $gDestDirAbsPath\n");

	WalkDirectoryTreeAndApply($inputDirName, \&CopyCodeSrcFileToDestinationDirAction);
	# WalkDirectoryTreeAndApply($inputDirName, \&PrintIfModifiedSinceDaysAction);
    } else {
	die "Valid action argument must be specified.";
    }

    chdir($startWorkDir);

}
