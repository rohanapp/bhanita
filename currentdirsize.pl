use strict;
use Cwd;
use File::Spec;
use Carp;
#use Getopt::Long;
use File::Basename; # for fileparse

sub CurrentDirSize
{
    my $size = 0;

    my $dirHandle;
    opendir($dirHandle, ".") or die "Unable to open current directory";
    
    my @dirFiles = readdir($dirHandle) or die "Unable to read directory contents of current directory";
    
    foreach(@dirFiles) {
	next if ($_ eq "." || $_ eq "..");
	my $dirPath = "./$_";
	if (-d $dirPath) {
	    my $currDir = getcwd;
	    chdir($dirPath) or die "Unable to change working directory to '$dirPath'";
	    $size += CurrentDirSize(); 
	    chdir($currDir) or die "Unable to switch back the working directory to '$currDir'";
	} else {
	    my $filePath = $dirPath;
	    $size += -s _; #(stat($filePath))[7]
	}
    }
    return $size;
}

# Expects absolute path
# returns name, dir, extension
sub ParseFilePathComponents
{
    confess "Pass absolute path to this function instead of '$_[0]'" 
	unless File::Spec->file_name_is_absolute($_[0]);
    return fileparse($_[0], qr/\.[^.]*/);
}

MAIN:
{
    my $gStartupDir = File::Spec->rel2abs(File::Spec->curdir());
    my ($dirname, $dirdir, $dirext) = ParseFilePathComponents($gStartupDir);

    my $sizeInMB = CurrentDirSize()/1000/1000; # literally 'mega' (1e6) bytes 
    print "$dirname:\t\t$sizeInMB (mega bytes)\n";
}

