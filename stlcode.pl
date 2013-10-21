use strict;
use lib "..\\Lib";
use Cwd;
use Getopt::Long;
use GlobUtils;
use Win32::Clipboard;

my $gVerbose = 1;
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

sub PrintIfVerbose
{
    if ($gVerbose) {
	print("$_[0] $_[1]\n");
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
    GetOptions("verbose" => \$gVerbose, "pids=s" => \$procIDsStr, 
	       "interval=f" => \$gTimeIntervalSecs) or die usage("Incorrect Usage:");

    print ("Verbose flag is: $gVerbose\n");

    PrintIfVerbose("Process ID string is:", $procIDsStr);
    PrintIfVerbose("Time interval (milliseconds):", $gTimeIntervalSecs);
    if ($gVerbose) {
	print ("\n");
    }

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
    GetOptions("verbose" => \$gVerbose, "stype=s" => \$srcType, "dtype=s" => \$destType, "input=s" => \$inputFile, "out=s" => \$destFile) or 
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

sub FixGeneratedCode
{
    my $inputFile;
    my $srcType;
    my $destType;
    my $destFile;
    GetOptions("verbose" => \$gVerbose, "stype=s" => \$srcType, "dtype=s" => \$destType, "input=s" => \$inputFile, "out=s" => \$destFile) or 
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

sub MapIterationToClipboard
{
  
  my ($typeOfElem1, $typeOfElem2, $containerName) = @_;

  my @codeLines;
  push @codeLines, "#include <map>\n";
  push @codeLines, "std::map<$typeOfElem1, $typeOfElem2>::iterator miter;\n";
  push @codeLines, "for(miter = $containerName" . ".begin(); miter != $containerName" .".end(); ++miter)\n";
  push @codeLines, "{\n";
  push @codeLines, "  const $typeOfElem1" . "& currKey = miter->first;\n";
  push @codeLines, "  const $typeOfElem2" . "& currVal = miter->second;\n";
  push @codeLines, "}\n";

  return \@codeLines;
}
  
sub MapFindToClipboard
{
  
  my ($typeOfElem1, $typeOfElem2, $containerName) = @_;

  my @codeLines;
  push @codeLines, "#include <map>\n";
  push @codeLines, "std::map<$typeOfElem1, $typeOfElem2>::iterator miter = $containerName.find(elem);\n";
  push @codeLines, "SS_ASSERT(miter != $containerName.end());\n";
  push @codeLines, "v = miter->second;\n";

  return \@codeLines;
}

# Inputs: typeofalgo, type of element, container name OR
#         typeofalgo, type of element1,type of second element2, container name
sub GenerateSTLCodeToClipboard
{
    my $numIndentSpaces = 2;
    my $indentStr = " "x$numIndentSpaces;

    my $clippedText = Win32::Clipboard::GetText();
    print "Found text on cipboard: $clippedText\n";

    # Code lines should be generated in these
    my @codeLinesArray;

    my ($typeOfAlgo, $typeOfElem1, $typeOfElem2, $containerName);
    my $pairContainerpattern = "(\\w+)\\s+(\\w+)\\s+(\\w+)\\s+(\\w+)";
    my $singleElemContainer = "(\\w+)\\s+(\\w+)\\s+(\\w+)";
    if ($clippedText =~ m/$pairContainerpattern/) {

	($typeOfAlgo, $typeOfElem1, $typeOfElem2, $containerName) = 
	    ($clippedText =~ m/$pairContainerpattern/);
	print "Requested algo: $typeOfAlgo, Type of element1: $typeOfElem1, Type of element2: $typeOfElem2, " .
	    "Container name: $containerName\n";

	my $codeLinesRef;
	if ($typeOfAlgo eq "mapiter") {
	    die "Type of second element of container must be specified" if $typeOfElem2 eq "";
	    $codeLinesRef = MapIterationToClipboard($typeOfElem1, $typeOfElem2, $containerName);
	} elsif ($typeOfAlgo eq "mapfind") {
	    $codeLinesRef = MapFindToClipboard($typeOfElem1, $typeOfElem2, $containerName);
	} else {
	    die "Unknown type of algorithm '$typeOfAlgo'";
	}

	@codeLinesArray = map "$_" . $indentStr, @{$codeLinesRef};

    } elsif ($clippedText =~ m/$singleElemContainer/) {

	print "Requested algo: $typeOfAlgo, Type of element: $typeOfElem1, Container name: $containerName\n";
	($typeOfAlgo, $typeOfElem1, $containerName) = 
	    ($clippedText =~ m/$singleElemContainer/);

	my $codeLinesRef;

	@codeLinesArray = map "$_" . $indentStr, @{$codeLinesRef};

	die "Code generation is not yet supported";

    } else {

	die "Unable to interpret and generate code for text '$clippedText'";
	die "Type of algo must be specified" if $typeOfAlgo eq "";
	die "Type of first element of container must be specified" if $typeOfElem1 eq "";
	$containerName = "container" if (!defined $containerName);

    }

    CopyStringsToClipboard(@codeLinesArray);
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
    GetOptions("verbose" => \$gVerbose) or 
	die usage("Incorrect Usage");

    GenerateSTLCodeToClipboard;

    print ("Verbose flag is: $gVerbose\n");


}
