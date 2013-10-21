use strict;
use Getopt::Long;
use File::Spec;
use Cwd 'realpath';
use File::Basename;
use File::Path;
use Carp;
use File::Copy;
use File::Glob ':glob';

my $gStartupDir = "";
my $gVerbose = 0;

sub PrintIfVerbose
{
    if ($gVerbose) {
	print "$_[0]\n";
    }
}

# input: directory. 
sub IsDirectory
{
    if (-d $_[0]) {
	return 1;
    }

    return 0;
}

# input: file or directory. 
sub IsFileOrDirWritable
{
    confess "File or Directory '$_[0]' does not exist" unless (-e $_[0]);

    if (-W $_[0]) {
	return 1;
    }
    return 0;
}

# input: file or directory
sub DoesFileOrDirExist
{
    if (-e $_[0]) {
	return 1;
    }
    return 0;
}

# Expects absolute path
# returns name, dir, extension
sub ParseFilePathComponents
{
    confess "Pass absolute path to this function instead of '$_[0]'" 
	unless File::Spec->file_name_is_absolute($_[0]);
    return fileparse($_[0], qr/\.[^.]*/);
}

# input: dir, file name, extn. 
# Expects absolute path for directory component
sub MakeFilePathFromComponents
{
    my $fdir = $_[0];
    my $fname = $_[1];
    my $extn = $_[2];
    $extn = "." . $extn unless ($extn =~ /^\./);
    confess "File directory '$fdir' should be an absolute path" unless File::Spec->file_name_is_absolute($fdir);
    $fname = $fname . $extn if ($extn ne "");

    return File::Spec->catpath("", $fdir, $fname);
}

# input: absolute path
# Simplifies path: cleans up path of .. portions, ~, etc.
sub GetSimplifiedAbsolutePath
{
    my $path = $_[0];
    die "Expecting absolute path rather than $path" unless (File::Spec->file_name_is_absolute($path));

    return realpath($path) if (-e $path);
    (my $pathName, my $pathDir, my $pathExtn) = ParseFilePathComponents($path);
    if ($pathDir ne "") {
	#print "Invoking GetSimplifiedAbsolutePath($pathDir)\n";
	$pathDir = GetSimplifiedAbsolutePath($pathDir);
    }

    return MakeFilePathFromComponents($pathDir, $pathName, $pathExtn);
}

# Pass 2 arguments: relative path, reference directory 
sub GetAbsolutePath
{
    # tilda is a shell construct and perl doesn't understand it
    my $path = $_[0];
    my $homeDir = glob("~");
    $path =~ s/^~/$homeDir/;
    confess "Relative path must be non-empty" if ($path eq "");
    if (!File::Spec->file_name_is_absolute($path)) {
	my $refDir = $_[1];
	confess "Reference directory must be non-empty" if ($refDir eq "");
	$path = File::Spec->rel2abs($path, $refDir);
    }

    my $absPath = GetSimplifiedAbsolutePath($path);
    #print "Absolute path: $absPath\n";
    return $absPath;
}

sub GetUniquePathName
{
    (my $pdir, my $pname, my $pextn) = @_;
    my $projPathInTempDir = MakeFilePathFromComponents($pdir, $pname, $pextn) or die "Unable to MakeFilePathFromComponents\n";

    if (-e $projPathInTempDir) {
	for (my $ii = 0; $ii < 5; $ii++) {
	    my $randomNumber = int(rand(100000));
	    print "Random number obtained: $randomNumber\n";
	    my $newPname = $pname . $randomNumber;
	    print "Newpname is $newPname\n";
	    $projPathInTempDir = MakeFilePathFromComponents($pdir, $newPname, $pextn);
	    last unless (-e $projPathInTempDir);
	}
    }
	    
    die "Project path $projPathInTempDir exists" if -e $projPathInTempDir;
    return $projPathInTempDir;
}

my $gTmpDir = "/tmp";

MAIN:
{
    my $numArgs = $#ARGV + 1;
    my $projPathOnNFS = $ARGV[$numArgs - 1];
    (my $projName, my $projDir, my $projExtn) = ParseFilePathComponents($projPathOnNFS);

    print "Original project path is $projPathOnNFS. Components: $projName, $projDir, $projExtn\n";

    my $projPathInTempDir = GetUniquePathName($gTmpDir, $projName, $projExtn) or die "Unable to GetUniquePathName\n";
    print "Copying original project to tmp location: $projPathInTempDir\n";
    die "Project path $projPathInTempDir exists" if -e $projPathInTempDir;

    copy($projPathOnNFS, $projPathInTempDir) or die "Unable to copy $projPathOnNFS to $projPathInTempDir";

    my @maxJobCommandLine;
    for (my $ii = 0; $ii < $numArgs - 1; $ii++) {
	push @maxJobCommandLine, $ARGV[$ii];
    }
    push @maxJobCommandLine, $projPathInTempDir;

    print "Running system command: @maxJobCommandLine\n";
    if (system(@maxJobCommandLine) != 0) {
	die "Maxwell command @maxJobCommandLine failed";
    }

}
