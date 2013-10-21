use strict;
use lib "..\\Lib";
use lib "\\programs\\perl_scripts";
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
my ($gClassName, $methodName, @argNameList) = ("dummy", "dummy", "dummy");
sub UtilityCodeToList
{
    my @utilitiesNeeded = @_;

    my @srcUtilityLines;
    foreach(@utilitiesNeeded) {
	my $utName = $_;
	#print "Utils needed: $utName\n";
	my $utilSrcCode = CodeGen::GetSourceCodeForUtility($_, $gClassName, $methodName, \@argNameList, "");
	if (!defined $utilSrcCode) {
	    print "ERROR! Utility '$utName' is unknown. Could it be a typo or denote type abbrev?\n";
	    next;
	}
	map push (@srcUtilityLines, "$_\n"), @{$utilSrcCode};
    }
    return @srcUtilityLines;
}

sub GenerateUtilityCodeToClipboard
{
    my $clippedText = Win32::Clipboard::GetText();
    print "GenerateUtilityCodeToClipboard -> Found text on cipboard: $clippedText\n";

    my @utilTypes = CleanSplit($clippedText, ",");

    # Code lines should be generated in these
    my @codeLinesArray = UtilityCodeToList(@utilTypes);

    CopyStringsToClipboard(@codeLinesArray);
}

MAIN:
{
    GetOptions("verbose" => \$gVerbose) or 
	die usage("Incorrect Usage");

    CodeGen::InitializeCodeGenDatabases;

    GenerateUtilityCodeToClipboard;


    print ("Verbose flag is: $gVerbose\n");


}
