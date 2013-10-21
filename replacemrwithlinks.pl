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
=  -user         <user-name>      (user's first name for which to generate this report)
=  -verbose      <on/off>         (whether to run in silent mode or print to stdout)

$sep
EOU__
exit(1);
}

my $gVerbose = 1;

sub PrintIfVerboseMode($)
{
    if ($gVerbose) {
        print "$_[0]\n";
    }
}

sub ReplaceMRNumsWithLinks($)
{
    my $lineStr = $_[0];
    my $numMatches = ($lineStr =~ s/(\s)(mr|ansft000|)(\d\d\d\d\d)/$1%ANSOFT_MR{$3}%/gi);
    if ($numMatches) {
        PrintIfVerboseMode("Symbolic link is added to $numMatches MRs in below line:\n$_[0]");
    }

    $numMatches = ($lineStr =~ s/(^mr|^ansft000)(\d\d\d\d\d)/%ANSOFT_MR{$2}%/gi);
    if ($numMatches) {
	PrintIfVerboseMode("Symbolic link is added to $numMatches MRs in below line:\n$_[0]");
    }

    return $lineStr;
}

sub ReplaceMRNumsWithLinksInFile($)
{  
    my $fileWithMRs = $_[0];

    open(fileHandle, "< $fileWithMRs") or 
        die "Can't open file '$fileWithMRs' for reading: $!\n";
    PrintIfVerboseMode("Opened file '$fileWithMRs' for reading\n");

    my @fileContents = <fileHandle>;
    my $numLines = @fileContents;
    PrintIfVerboseMode("Num lines in the file = $numLines \n");

    my @updateStrs = "\n";
    my $currLine = 0;
    for (; $currLine < $numLines; $currLine++) {
        my $currLineStr = @fileContents[$currLine];
        $currLineStr = ReplaceMRNumsWithLinks($currLineStr);
        @updateStrs = (@updateStrs, $currLineStr);
        @updateStrs = (@updateStrs, "\n");
    }

    close(fileHandle);

    return @updateStrs;
}

sub DeleteFile($)
{
    my $fileName = $_[0];
    my $numFilesDeleted = unlink $fileName;

    PrintIfVerboseMode(sprintf("Deleted file: %s\n", $fileName)) unless $numFilesDeleted == 0;
}

MAIN:
{
    GetOptions("verbose" => \$gVerbose) || usage("Unknown option");

    my $mrListFileStr = "mrlist.txt";
    my @replacedMRLinksFile = ReplaceMRNumsWithLinksInFile($mrListFileStr);

    DeleteFile($mrListFileStr);

    open(fileHandle, ">> $mrListFileStr") or 
        die "Can't open file '$mrListFileStr' for appending: $!\n";
    print fileHandle @replacedMRLinksFile;
    close fileHandle;

}
