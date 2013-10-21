use strict;
use File::Glob;
use Getopt::Long;
use Cwd;
use File::Basename;
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove pathrm);
use File::chmod;
use File::Path qw(remove_tree);

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
=  -sln <Path to sln. This is not optional>

$sep
EOU__
exit(1);
}

my $gModVerbose = 0;
my $gInitialWorkDir = "";

sub SetVerboseMode { $gModVerbose = $_[0]; }

# input: verbose-mode-flag
sub OnApplicationStartup
{
    SetVerboseMode($_[0]);
    $gInitialWorkDir = getcwd;
}

sub OnApplicationExit
{
    chdir($gInitialWorkDir);
}

sub StartingWorkDir {return $gInitialWorkDir;}

sub PrintIfVerboseMode($)
{
    if ($gModVerbose) {
        print "$_[0]";
    }
}

sub RemoveDerivedFolders
{
    my $baseFolder = $_[0];
    die "$baseFolder does not exist!" unless (-e $baseFolder);
    PrintIfVerboseMode ("RemoveDerivedFolders $baseFolder...\n");

    my $dh;
    opendir($dh, $baseFolder) or die "Unable to open directory $baseFolder!";

    my @dirFiles = readdir($dh) or die "Unable to read directory $baseFolder!";

    foreach(@dirFiles) {
	my $baseFolderName = $_;
	next if ($_ eq "." || $_ eq "..");
	
	my $currDir = $baseFolder . "\\" . $_;
	next if (-f $currDir);
	if ($baseFolderName eq "obj" || $baseFolderName eq "bin") {
	    chmod 0777, $currDir;
	    print "Removing derived directory $currDir...\n";
	    remove_tree($currDir) or die $!;
	} else {
	    RemoveDerivedFolders($currDir);
	}
    }

    closedir($dh) or die "Unable to close directory $baseFolder!";
}

MAIN:
{

    my $verbose = 0;
    my $inputSlnPath = "";
    my $destFolder = "";
    GetOptions("verbose" => \$verbose, "sln=s" => \$inputSlnPath, "dest=s" => \$destFolder) or Usage("Incorrect command-line");
    
    Usage("Sln path must be specified!") if ($inputSlnPath eq "");
    Usage("Destination folder must be specified!") if ($destFolder eq "");
    Usage("Specified sln file does not exist!") unless (-e $inputSlnPath);
    Usage("Specified destination folder does not exist!") unless (-e $destFolder);

    my ($fileName, $inputSlnDir) = fileparse($inputSlnPath);
    
    OnApplicationStartup($verbose);

    my $fh;
    open($fh, "< $inputSlnPath") or die "$inputSlnPath is not readable";
    while (<$fh>) {
	chomp;
	# Now parse the folder path from the string
	if ($_ =~ /Project\(\"\{.+\}\"\).*=.*\".+\",.*\"(.+)\\.+\.csproj\",.*\".+\"/) {
	    my $projFolder = $inputSlnDir . $1;
	    die "$projFolder does not exist!" unless (-e $projFolder);

	    # Find the folder path relative starting from lib or product
	    die "Unable to parse $projFolder string as relative to lib or product!" 
		unless ($projFolder =~ /.+(\\lib\\.+|\\products\\.+)$/);
	    my $folderNameFromLibProduct = $1;
	    my $destCurrFolder = $destFolder . $folderNameFromLibProduct;
	    print "Archiving $projFolder to $destCurrFolder...\n";
	    my ($numFilesDirs, $numDirs, $depthTraversed) = dircopy($projFolder, $destCurrFolder);
	    print "Summary: Numfilesdirs copied = $numFilesDirs, NumDirs copied = $numDirs\n";
	}
    }
    close($fh) or die "Unable to close file $inputSlnPath!";

    # Now copy sln
    print "Copying sln...\n";
    fcopy($inputSlnPath, $destFolder) or die "Unable to copy $inputSlnPath to $destFolder!";

    # Remove bin abd obj directories
    print "Removing derived folders...\n";
    RemoveDerivedFolders($destFolder);


    OnApplicationExit;
}
