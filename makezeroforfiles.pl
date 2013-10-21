use strict;
use lib "..\\Lib";
use Cwd;
use Getopt::Long;
use File::Basename;

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
=  -filepath     <filepath that lists files for which make zero is needed> 
=                (each file must be on separate line;
=                 path must be relative to current directory)

$sep
EOU__
exit(1);
}

sub IsElementCheckedOut($)
{
    my @describeElemCmd = ("cleartool", "describe", "-short", $_[0]);
    my $out = `@describeElemCmd`;
    if ($out =~ /CHECKEDOUT/) {
	return 1;
    }
    return 0;
}

sub MakeZeroForFile
{
    my $filePath = $_[0];

    my $fileBaseName = basename($filePath);
    # strip trailing space
    $fileBaseName =~ s/(.*)\s$/$1/; 
    my $dirName = dirname($filePath);

    my $currDir = getcwd;
    chdir $dirName or die "Unable to change directory to: $dirName";
    my $foo = getcwd;

    if (IsElementCheckedOut($fileBaseName) == 0) {
	my @checkoutCommand = ("cleartool", "co", "-unr", "-nmaster", "-nc", $fileBaseName);
	my $out = `@checkoutCommand`;
        print "@checkoutCommand\n";
	if ($? != 0) {
	    print "Failed to checkout $fileBaseName\n";
	    exit 1;
	}
    }

    chdir $currDir;

}
    
MAIN:
{
    my $makeZeroCandidatesFile;
    GetOptions("filepath=s" => \$makeZeroCandidatesFile) || usage("Unknown option");
    usage("filepath must be a valid file") unless -f $makeZeroCandidatesFile;

    open(filesToMakeZeroFileHandle, $makeZeroCandidatesFile) or die "Cannot open $makeZeroCandidatesFile: $!";
    while(<filesToMakeZeroFileHandle>)
    {
	chomp;
	my $makeZeroCandidate = $_;
	if ($makeZeroCandidate) {
	    MakeZeroForFile($makeZeroCandidate);
	    print "File to make zero: $makeZeroCandidate.\n";
	}
    }
}
