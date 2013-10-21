use strict;
use lib "..\\Lib";
use Cwd;
use Getopt::Long;
use GlobUtils;
use File::Copy::Reliable;

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
=  -<source view dir path>
=  -<destination view dir path>
= Example: copydjobfromarchive.pl -src \\\\sjo7na1\\Views\\nappann_core5_view2 -dest C:\\cviews\\nappann_core5_view

$sep
EOU__
exit(1);
}

my $gVerbose = 0;
my $gsrcViewPath = "";
my $gDestinationViewPath = "";

sub RenameDirectory
{
    my ($srcDir, $destDir) = @_;
    print "RenameDirectory: Src = $srcDir, Dest = $destDir\n";

    die "Directory $srcDir does not exist!" if !(-e $srcDir);
    die "Directory $destDir already exists! Remove this directory before continuing" if (-e $destDir);

    eval {
	move_reliable($srcDir, $destDir);
    };
    die "RenameDirectory $srcDir -> $destDir failed! Both dirs might have partial data. Restore $srcDir carefully!" if ($@);
    return 0;
}

sub CopyDirectory
{
    my ($srcDir, $destDir) = @_;
    print "CopyDirectory: Src = $srcDir, Dest = $destDir\n";

    die "Directory $srcDir does not exist!" if !(-e $srcDir);
    die "Directory $destDir already exists! Remove this directory before continuing" if (-e $destDir);

    eval {
	copy_reliable($srcDir, $destDir);
    };
    die "CopyDirectory $srcDir -> $destDir failed! Both dirs might have partial data. Restore $srcDir carefully!" if ($@);
    return 0;
}

sub BackupDeleteDirectoriesInDestView
{
    my @dirList = @_;
    foreach(@dirList) {
	my $destDir = File::Spec->catdir($gDestinationViewPath, "nextgen/ansoftcore", $_);
	print "Concatenated dest dir is $destDir\n";
	if (!(-e $destDir)) {
	    print "$destDir doesn't exist. It is not backedup";
	    next;
	}
	my $destDirBackup = $destDir . ".backup";
	warn "Backup already exists! $destDirBackup is being overridden" if (-e $destDirBackup);
	DeleteDirAndContentsIfExists($destDirBackup);
	MoveDirectory($destDir, $destDirBackup);
    }
}

sub CopyDirectoriesFromSrcViewToDestView
{
    my @dirList = @_;
    foreach(@dirList) {
	my $srcDir = File::Spec->catdir($gsrcViewPath, "nextgen/ansoftcore", $_);
	print "Concatenated src dir is $srcDir\n";
	die "" unless (-e $srcDir);

	my $destDir = File::Spec->catdir($gDestinationViewPath, "nextgen/ansoftcore", $_);
	print "Concatenated dest dir is $srcDir\n";
	CopyDirectory($srcDir, $destDir);
    }
}

MAIN:
{

    GetOptions("verbose" => \$gVerbose, "srcview=s" => \$gsrcViewPath, "destview=s" => \$gDestinationViewPath) or
	die usage("Incorrect Usage:");

    SetVerboseMode($gVerbose);

    die "View $gsrcViewPath does not exist!" unless (-e $gsrcViewPath);
    die "View $gDestinationViewPath does not exist!" unless (-e $gDestinationViewPath);

    $gsrcViewPath = File::spec->rel2abs($gsrcViewPath);
    $gDestinationViewPath = File::spec->rel2abs($gDestinationViewPath);

    my $initialWorkDir = getcwd;

    my @djobDirs = ("lib/NgAnsoftCOMApp", "lib/mxwlresextractor", "lib/wbintegutils", "products/desktopjob", "products/djobextractor");

    eval {
	BackupDeleteDirectoriesInDestView(@djobDirs);
	CopyDirectoriesFromSrcViewToDestView(@djobDirs);
    };
    print "Error occured during the script run!\n" if ($@);

    chdir($initialWorkDir);

}
