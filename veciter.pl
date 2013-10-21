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

sub VecIterationToClipboard
{
  
  my ($typeOfElem1, $containerName) = @_;

  my @codeLines;
  #push @codeLines, "#include <map>\n";
  if (CodeGen::IsAString($typeOfElem1)) {
      push @codeLines, "std::vector<$typeOfElem1>::iterator miter;\n";
  } else {
      push @codeLines, "std::vector<$typeOfElem1>::iterator miter;\n";
  }
  push @codeLines, "for(miter = $containerName" . ".begin(); miter != $containerName" .".end(); ++miter)\n";
  push @codeLines, "{\n";
  push @codeLines, "  const $typeOfElem1" . "& currVal = *miter;\n";
  push @codeLines, "}\n";

  return \@codeLines;
}
  
sub GenerateSTLVecIterCodeToClipboard
{
    my $numIndentSpaces = 2;
    my $indentStr = " "x$numIndentSpaces;

    my $clippedText = Win32::Clipboard::GetText();
    print "GenerateSTLVecIterCodeToClipboard -> Found text on cipboard: $clippedText\n";

    # Code lines should be generated in these
    my @codeLinesArray;

    my ($typeOfElem1, $containerName);
    my $oneElemContainerpattern = "\\s*(.+)\\s*,\\s*(.+)\\s*";
    if ($clippedText =~ m/$oneElemContainerpattern/) {

	($typeOfElem1, $containerName) = 
	    ($clippedText =~ m/$oneElemContainerpattern/);
	print "Type of element: $typeOfElem1, " .
	    "Container name: $containerName\n";

	my $codeLinesRef;
	$codeLinesRef = VecIterationToClipboard($typeOfElem1, $containerName);

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

    GenerateSTLVecIterCodeToClipboard;

    print ("Verbose flag is: $gVerbose\n");


}
