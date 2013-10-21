use strict;
use File::Glob;
use Getopt::Long;
use DateTime;

#----------------------------------------------------------
sub Usage
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
=  -batchlog     <path-to-project-analysis-batchlog>

$sep
EOU__
exit(1);
}

my $gVerbose = 0;
my $gAnsoftProjBatchLogFilePath = "";
my %gJobTimeInfoPerMachine;
my $gFirstMachineOfJob = "";
# REVISIT: below value is not computed correctly and so not in use. Before use, fix the computation
my $gNumCoresPerMachine = -1;

sub PrintIfVerboseMode
{
    if ($gVerbose) {
        print "$_[0]\n";
    }
}

sub TrimWhiteSpace
{
    my $lStr = $_[0];
    $lStr =~ s/^\s+//;
    $lStr =~ s/\s+$//;
    return $lStr;
}

# REVISIT: all hardcoded data below
# Must change for each batchlog
my $gNumIdleCoresOnFirstMachine = 1; #unused at this time
# Use reference time so the first variation time corresponds to the time to solve
# one variation
my $gRefYear = 2011;
my $gRefMonth = 8;
my $gRefDayOfMonth = 21;
my $gRefHourIn24Form = 12;
my $gRefMins = 23;
my $gRefSecs = 9;
my $gTimeZone = 'America/Los_Angeles';

sub ParseMachineListString
{
    my $machineListStr = lc($_[0]);
    $machineListStr =~ s/\.$//;
    my @parsedMlist = split(' ', $machineListStr);
    PrintIfVerboseMode("Input machine list: @parsedMlist\n");
    my @nonUniqMlist;
    foreach(@parsedMlist) {
	chomp;
	my $mStr = $_;
	PrintIfVerboseMode("Parsed machine: $mStr\n");
	push @nonUniqMlist, $mStr;
    }
	
    my $gFirstMachineOfJob = $nonUniqMlist[0];
    PrintIfVerboseMode("First machine of job is: $gFirstMachineOfJob");
    @gJobTimeInfoPerMachine{@nonUniqMlist} = ();
    my $numMachines = keys %gJobTimeInfoPerMachine;
    $gNumCoresPerMachine = @nonUniqMlist/$numMachines;
    PrintIfVerboseMode("Number of machines: $numMachines. Num cores per machine: $gNumCoresPerMachine\n");
}

sub CollectVariationRequestedTimeForMachine
{
    my $variationRequestedStrPattern = "has been requested on machine (.+)\\s+\\((.+)\\)";
    if ($_[0] =~ m/$variationRequestedStrPattern/) {
	my $machineName = lc(TrimWhiteSpace($1));
	# PrintIfVerboseMode("$machineName => $2");
	push @{$gJobTimeInfoPerMachine{$machineName}}, $2;
    }
}

my %gMonth2Num = 
    (
    "Jan" => 1,
    "Feb" => 2,
    "Mar" => 3,
    "Apr" => 4,
    "May" => 5,
    "Jun" => 6,
    "Jul" => 7,
    "Aug" => 8,
    "Sep" => 9,
    "Oct" => 10,
    "Nov" => 11,
    "Dec" => 12
    );

sub ParseTimeStringFromBatchLog
{
    my ($hrs, $mins, $secs, $aMPM, $month, $dayOfMonth, $year) = 
	($_[0] =~ m/(\d+):(\d+):(\d+)\s+(AM|PM)\s+(\w+)\s+(\d+),\s+(\d+)/);

    # REVISIT: month is hardcoded
    die "Month '$month' string needs to be parsed" unless exists $gMonth2Num{$month};
    my $monthNum = $gMonth2Num{$month};
    PrintIfVerboseMode("Parsed month is '$month', '$monthNum'\n");

    $hrs = 0 if $hrs == 12;
    my $hourIn24Form = ($aMPM eq "AM") ? $hrs : $hrs + 12;

    return ($hourIn24Form, $mins, $secs, $aMPM, $monthNum, $dayOfMonth, $year);
}


sub GetEpochValueForTimeString
{
    my ($hourIn24Form, $mins, $secs, $aMPM, $monthNum, $dayOfMonth, $year) = 
	ParseTimeStringFromBatchLog($_[0]);
    
    my $dt1 = DateTime->new(
	year => $year,
	month => $monthNum,
	day => $dayOfMonth,
	hour => $hourIn24Form,
	minute => $mins,
	second => $secs,
	time_zone => $gTimeZone
	);
    my $dt1_epoch = $dt1->epoch();
    return $dt1_epoch;
}

sub TimeInSecondsOffsetfromReferenceTime
{
    my $dt1_epoch = GetEpochValueForTimeString($_[0]);
    my $dt2_epoch = $_[1];

    my $timeElapsedInSecs = $dt1_epoch - $dt2_epoch;

    return $timeElapsedInSecs;
}


my %gElapsedTimeBetweenVariationsPerMachine;

sub ComputeElapsedTimeBetweenVariations
{
    foreach(keys %gJobTimeInfoPerMachine) {
	my @varRequestTimeStrs = @{$gJobTimeInfoPerMachine{$_}};
	my $reqTimeForFirstVarn = $varRequestTimeStrs[0];
	print("First variation for machine '$_' is reqested at time '$reqTimeForFirstVarn'\n");
	print("Variation requested times, offset from first request:\n");
	my $firstVar_epoch = GetEpochValueForTimeString($reqTimeForFirstVarn);
	foreach(@varRequestTimeStrs) {
	    my $elapsedTimeForVarn = TimeInSecondsOffsetfromReferenceTime($_, $firstVar_epoch);
	    print "$elapsedTimeForVarn\n";
	}
    }
	    
}

MAIN:
{
    GetOptions("verbose" => \$gVerbose, "batchlog=s" => \$gAnsoftProjBatchLogFilePath) or Usage("Incorrect command-line");
    Usage ("Path to batchlog must be specified") unless -f $gAnsoftProjBatchLogFilePath;

    my $filehandle;
    open($filehandle, "<$gAnsoftProjBatchLogFilePath") or die "Unable to open file for reading: $gAnsoftProjBatchLogFilePath";

    my $machinelistPatternStr = "Using machine list:(.+)";
    my $machineListStr = "";

    while (<$filehandle>) {
	my $currLineStrCache = $_;
	if ($_ =~ m/$machinelistPatternStr/) {
	    $machineListStr = $1;
	    PrintIfVerboseMode("Found machine-list as: $machineListStr");
	    ParseMachineListString($machineListStr);

	    foreach(keys %gJobTimeInfoPerMachine) {
		PrintIfVerboseMode("Collecting data for machine: $_\n");
	    }
	}
	if ($machineListStr ne "") {
	    CollectVariationRequestedTimeForMachine($currLineStrCache);
	}
    }

    foreach(keys %gJobTimeInfoPerMachine) {
	my $numSolvedVars = $#{$gJobTimeInfoPerMachine{$_}} + 1;
	PrintIfVerboseMode("The number of solves requested on machine $_ is: $numSolvedVars");
    }

    ComputeElapsedTimeBetweenVariations;

}
