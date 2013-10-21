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

sub IncludeDirectivesToList
{
    my @typesToInclude = @_;
    my @includeList;
    foreach(@typesToInclude) {
	my $includeRefStr = CodeGen::GetIncludeReferencesOfAbbrevType($_);
	print "GetIncludeReferencesOfAbbrevType '$_' returned '$includeRefStr'\n";
	$includeRefStr = CodeGen::GetIncludeReferencesOfUtility($_) unless (defined $includeRefStr);
	if (defined $includeRefStr) {
	    foreach(@{$includeRefStr}) {
		my $includeDirective = $_;
		my ($isSTL, $stlType, $elemType1, $elemType2) = CodeGen::IsSTLIncludeDirective($includeDirective);
		push (@includeList, "#include \"$includeDirective\"\n") if !$isSTL;
		push (@includeList, "#include <$stlType>\n") if $isSTL;
		(map {push @includeList, $_} IncludeDirectivesToList($elemType1, $elemType2)) if  $elemType1 ne "";
	    }
	}
    }
    return @includeList;
}

sub GenerateIncludeDirectivesToClipboard
{
    my $clippedText = Win32::Clipboard::GetText();
    print "GenerateSTLVecIterCodeToClipboard -> Found text on cipboard: $clippedText\n";

    my @abbrevTypes = CleanSplit($clippedText, ",");

    # Code lines should be generated in these
    my @codeLinesArray = IncludeDirectivesToList(@abbrevTypes);

    CopyStringsToClipboard(@codeLinesArray);
}

MAIN:
{
    GetOptions("verbose" => \$gVerbose) or 
	die usage("Incorrect Usage");

    CodeGen::InitializeCodeGenDatabases;

    GenerateIncludeDirectivesToClipboard;


    print ("Verbose flag is: $gVerbose\n");


}
