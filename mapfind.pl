use strict;
use lib "..\\Lib";
use Cwd;
use Getopt::Long;
use GlobUtils;
use CodeGen;
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

sub MapIterationToClipboard
{
  
  my ($typeOfElem1, $typeOfElem2, $containerName) = @_;

  my @codeLines;
  push @codeLines, "#include <map>\n";
  if (CodeGen::IsAString($typeOfElem1)) {
      push @codeLines, "std::map<$typeOfElem1, $typeOfElem2, AString::NoCaseLess>::iterator miter;\n";
  } else {
      push @codeLines, "std::map<$typeOfElem1, $typeOfElem2>::iterator miter;\n";
  }
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
  #push @codeLines, "#include <map>\n";
  if (CodeGen::IsAString($typeOfElem1)) {
      push @codeLines, "std::map<$typeOfElem1, $typeOfElem2, AString::NoCaseLess>::iterator miter = $containerName" . ".find(elem);\n";
  } else {
      push @codeLines, "std::map<$typeOfElem1, $typeOfElem2>::iterator miter = $containerName" . ".find(elem);\n";
  }
  push @codeLines, "if(miter == $containerName" . ".end())\n";
  push @codeLines, "{\n";
  push @codeLines, "}\n";
  push @codeLines, "$typeOfElem2& v = miter->second;\n";

  return \@codeLines;
}

sub GenerateSTLMapFindCodeToClipboard
{
    my $numIndentSpaces = 2;
    my $indentStr = " "x$numIndentSpaces;

    my $clippedText = Win32::Clipboard::GetText();
    print "Found text on cipboard: $clippedText\n";

    # Code lines should be generated in these
    my @codeLinesArray;

    my ($typeOfElem1, $typeOfElem2, $containerName);
    my $pairContainerpattern = "\\s*(.+)\\s*,\\s*(.+)\\s*,\\s*(.+)";
    if ($clippedText =~ m/$pairContainerpattern/) {

	($typeOfElem1, $typeOfElem2, $containerName) = 
	    ($clippedText =~ m/$pairContainerpattern/);
	print "Type of element1: $typeOfElem1, Type of element2: $typeOfElem2, " .
	    "Container name: $containerName\n";

	my $codeLinesRef;
	$codeLinesRef = MapFindToClipboard($typeOfElem1, $typeOfElem2, $containerName);

	@codeLinesArray = map "$_" . $indentStr, @{$codeLinesRef};

	CopyStringsToClipboard(@codeLinesArray);
	return;
    }

    die "Unable to interpret and generate code for text '$clippedText'";
}

MAIN:
{
    GetOptions("verbose" => \$gVerbose) or 
	die usage("Incorrect Usage");

    GenerateSTLMapFindCodeToClipboard;

    print ("Verbose flag is: $gVerbose\n");


}
