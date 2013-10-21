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

# Note: ValidateUserName expects names to be in lower case
my @gUserNameArray = ('anand', 'abhijeet', 'emily', 'jim', 'nick', 'srinivas',
                      'vamsi', 'vikram', 'zhigang');
my $gVerbose = 1;
my $gWeeklyUpdateFileNamesStr = "WeeklyUpdateNotes*2007.txt";
my $gWeeklyUpdateFileNamePrefix = "WeeklyUpdateNotes";

sub PrintIfVerboseMode($)
{
    if ($gVerbose) {
        print "$_[0]\n";
    }
}

sub ValidateUserName($)
{
    my $uname = lc $_[0];
    my $i = 0;
    for ($i = 0; $i < @gUserNameArray; $i++) {
        if ($uname eq @gUserNameArray[$i]) {
            PrintIfVerboseMode("Specified user name is valid\n");
            return 1;
        }
    }
    PrintIfVerboseMode("Specified user name is not valid!\n");
    return 0;
}

sub GetPerUserWeeklyUpdatesFileName($)
{
    my $uname = lc $_[0];
    my $userfile = sprintf("%sWeeklyUpdateNotes.txt", $uname);
    return $userfile;
}

sub DeletePerUserWeeklyUpdatesFile($)
{
    my $uname = lc $_[0];
    my $userfile = GetPerUserWeeklyUpdatesFileName($uname);
    my $numFilesDeleted = unlink $userfile;

    PrintIfVerboseMode(sprintf("Deleted file: %s\n", $userfile)) unless $numFilesDeleted == 0;
}

sub IsErroneousSectionFormat($)
{
    my $lineStr = $_[0];
    return 0;
}

sub IsNewSection($)
{
    my $lineStr = $_[0];
    die unless !IsErroneousSectionFormat($lineStr);

    if (split(/\s+/, $lineStr) >= 1) {

        my $sectionKwd = "---+++";
        if (@_[0] eq $sectionKwd) {
            return 1;
        }
    }

    return 0;
}

sub GetLCUserNameFromSectionStr($)
{
    my $lineStr = $_[0];

    die "User name expected in the section name\n" unless split(/\s+/, $lineStr) == 2;

    return lc @_[1];
}

sub GetWeekNameFromWeeklyUpdatesFile($)
{
    my $weeklyUpdatesFile = $_[0];
    my @weekNameStrWithExtn = split(/$gWeeklyUpdateFileNamePrefix/, $weeklyUpdatesFile);
    my @weekNameStrSplit = split(/\./, @weekNameStrWithExtn[1]);
    return @weekNameStrSplit[0];
}
    
sub GetMonthNameFromWeeklyUpdatesFile($)
{
    my $weeklyUpdatesFile = $_[0];
    my $weekName = GetWeekNameFromWeeklyUpdatesFile($weeklyUpdatesFile);
    my @monthNameSplitResult = split(/\d+/, $weekName);
    return @monthNameSplitResult[1];
}
    
sub GetYearNameFromWeeklyUpdatesFile($)
{
    my $weeklyUpdatesFile = $_[0];
    my $weekName = GetWeekNameFromWeeklyUpdatesFile($weeklyUpdatesFile);
    my @weekNameSplitResult = split(/\D+/, $weekName);
    return @weekNameSplitResult[1];
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
  
sub EnsureSJCDevWebTopicIsLinked($)
{
    my $lineStr = $_[0];
    my $numMatches = ($lineStr =~ s/([^\[])(sjcdev\.)(\w+)/$1\[\[$2$3\]\]/gi);
    if ($numMatches) {
        PrintIfVerboseMode("Webtopic is now linked in below line:\n$_[0]");
    } else {
        $numMatches = ($lineStr =~ s/(^sjcdev\.)(\w+)/\[\[$1$2\]\]/gi);
        if ($numMatches) {
            PrintIfVerboseMode("Webtopic is now linked in below line:\n$_[0]");
        }
    }
    return $lineStr;
}
  
sub GetWeeklyUpdatesForUser
{
    my $uname = lc $_[0];
    my $weeklyUpdatesFile = $_[1];

    open(fileHandle, "< $weeklyUpdatesFile") or 
        die "Can't open file '$weeklyUpdatesFile' for reading: $!\n";
    PrintIfVerboseMode("Opened file '$weeklyUpdatesFile' for reading\n");

    my @fileContents = <fileHandle>;
    my $numLines = @fileContents;
    PrintIfVerboseMode("Num lines in the file = $numLines \n");

    my $atNewSection = 0;
    my $currLine = 0;
    for (; $currLine < $numLines && !$atNewSection; $currLine++) {
        my $currLineStr = @fileContents[$currLine];
        if (IsNewSection($currLineStr) && GetLCUserNameFromSectionStr($currLineStr) eq $uname) {
            $atNewSection = 1;
        }
    }

    my $weekName = GetWeekNameFromWeeklyUpdatesFile($weeklyUpdatesFile);
    my $monthName = GetMonthNameFromWeeklyUpdatesFile($weeklyUpdatesFile);
    my $yearName = GetYearNameFromWeeklyUpdatesFile($weeklyUpdatesFile);
    PrintIfVerboseMode("Year, Month, Week name obtained from file name: $yearName, $monthName, $weekName\n");
    my $weekSectionLine = sprintf("---+++ %s\n", $weekName);
    my @updateStrs = ($weekSectionLine);
    for (; $currLine < $numLines; $currLine++) {
        my $currLineStr = @fileContents[$currLine];
        last unless (!IsNewSection($currLineStr) && !($currLineStr =~ /noautolink/));
        my $currLineStr = @fileContents[$currLine];
        $currLineStr = ReplaceMRNumsWithLinks($currLineStr);
        $currLineStr = EnsureSJCDevWebTopicIsLinked($currLineStr);
        @updateStrs = (@updateStrs, $currLineStr);
    }

    close(fileHandle);

    return @updateStrs;
}

sub AppendWeeklyUpdatesForUserToGivenFile
{
    my $uname = lc $_[0];
    my $weeklyUpdatesFile = $_[1];
    my $destinationFile = $_[2];

    my @updateStrs = GetWeeklyUpdatesForUser($uname, $weeklyUpdatesFile);

    open(fileHandle, ">> $destinationFile") or 
        die "Can't open file '$$destinationFile' for appending: $!\n";
    print fileHandle @updateStrs;
    close fileHandle;

    PrintIfVerboseMode(sprintf("Appended %s's weekly updates to file '%s'\n\n", 
                               $uname, $destinationFile));
}

sub GetMonthIndex($)
{
    my $monthName = lc $_[0];
    if ($monthName eq "jan") {
        return 1;
    } elsif ($monthName eq "feb") {
        return 2;
    } elsif ($monthName eq "mar") {
        return 3;
    } elsif ($monthName eq "apr") {
        return 4;
    } elsif ($monthName eq "may") {
        return 5;
    } elsif ($monthName eq "jun") {
        return 6;
    } elsif ($monthName eq "july") {
        return 7;
    } elsif ($monthName eq "aug") {
        return 8;
    } elsif ($monthName eq "sep") {
        return 9;
    } elsif ($monthName eq "oct") {
        return 10;
    } elsif ($monthName eq "nov") {
        return 11;
    } elsif ($monthName eq "dec") {
        return 12;
    } else {
        die "Unknown month: $monthName\n";
    }
    return -1;
}

sub SortWeeklyUpdateFiles 
{
    my $monthA = GetMonthIndex(GetMonthNameFromWeeklyUpdatesFile($a));
    my $monthB = GetMonthIndex(GetMonthNameFromWeeklyUpdatesFile($b));
    if ($monthA != $monthB) {
        $monthA <=> $monthB;
    } else {
        $a cmp $b;
    }
}

MAIN:
{
    my $userName;
    GetOptions("user=s" => \$userName,
               "verbose" => \$gVerbose) || usage("Unknown option");

    usage("User name must be specified on the command-line") unless 
        length($userName) != 0;
    usage("Specified user name is not valid") unless ValidateUserName($userName);

    DeletePerUserWeeklyUpdatesFile($userName);

    my @weeklyUpdateFileListUnsorted = glob($gWeeklyUpdateFileNamesStr);
    my @weeklyUpdateFileList = sort SortWeeklyUpdateFiles @weeklyUpdateFileListUnsorted;

    my $weeklyUpdatesFilePerUser = GetPerUserWeeklyUpdatesFileName($userName);

    # write header
    open(fileHandle, ">> $weeklyUpdatesFilePerUser") or 
        die "Can't open file '$weeklyUpdatesFilePerUser' for appending: $!\n";
    print fileHandle ("<noautolink>\n", "%TOC%\n");
    close fileHandle;

    foreach my $currFile (@weeklyUpdateFileList) {
        AppendWeeklyUpdatesForUserToGivenFile($userName, $currFile, $weeklyUpdatesFilePerUser);
    }

    # write footer complementary to header
    open(fileHandle, ">> $weeklyUpdatesFilePerUser") or 
        die "Can't open file '$weeklyUpdatesFilePerUser' for appending: $!\n";
    print fileHandle ("</noautolink>\n");
    close fileHandle;

}
