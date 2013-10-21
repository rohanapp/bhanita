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
=  -mergefrom    <branch-name>      (branch name from which to merge changes)
=  -filepath     <filepath that lists files to merge> 
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

sub MergeFile
{
    my $filePath = $_[0];
    my $fromBranch = $_[1];
    my $drawDummyMergeArrow = $_[2];

    my $fileBaseName = basename($filePath);
    # strip trailing space
    $fileBaseName =~ s/(.*)\s$/$1/; 
    my $dirName = dirname($filePath);

    my $currDir = getcwd;
    chdir $dirName or die "Unable to change directory to: $dirName";
    my $foo = getcwd;

    if ($drawDummyMergeArrow == 0 && IsElementCheckedOut($fileBaseName) == 0) {
	my @checkoutCommand = ("cleartool", "co", "-unr", "-nmaster", "-nc", $fileBaseName);
	my $out = `@checkoutCommand`;
        #print "@checkoutCommand\n";
	if ($? != 0) {
	    print "Failed to checkout $fileBaseName\n";
	    exit 1;
	}
    }

    my $mergeFromFile = sprintf("/main/%s/LATEST", $fromBranch);
    my @mergeCommand = ("cleartool", "merge", "-to", 
			$fileBaseName, "-version", $mergeFromFile);
    if ($drawDummyMergeArrow) {
        my $mergeToFile = sprintf("%s@@/main/LATEST", $fileBaseName);
	@mergeCommand = ("cleartool", "merge", "-ndata", "-to", 
			 $mergeToFile, "-version", $mergeFromFile);
    }

    my $mergeOut = `@mergeCommand`;
    #print "@mergeCommand\n";

    if ($? != 0) {
	print "$fileBaseName requires manual merge\n";
    }

    chdir $currDir;

}
    
MAIN:
{
    my $fromBranch;
    my $filesToMerge;
    GetOptions("mergefrom=s" => \$fromBranch, 
	       "filepath=s" => \$filesToMerge) || usage("Unknown option");
    usage("filepath must be a valid file") unless -f $filesToMerge;

    open(filesToMergeFileHandle, $filesToMerge) or die "Cannot open $filesToMerge: $!";
    while(<filesToMergeFileHandle>)
    {
	chomp;
	my $drawDummyMergeArrow = 0;
	my $mergeCandidate = $_;
	if ($mergeCandidate =~ /\(dummy\)$/) {
	    my $ignore;
	    ($mergeCandidate, $ignore) = split /\(dummy\)/, $mergeCandidate;
	    $drawDummyMergeArrow = 1;
	}
	if ($mergeCandidate) {
	    MergeFile($mergeCandidate, $fromBranch, $drawDummyMergeArrow);
	    #print "File to merge: $mergeCandidate, DummyMerge: $drawDummyMergeArrow.\n";
	}
    }
}
