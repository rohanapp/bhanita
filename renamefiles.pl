use File::Glob;

sub SubstituteKeywordsInFile
{
    my $fileName = $_[0];
    my $fromKwd = $_[1];
    my $toKwd = $_[2];
    #print "SubstituteKeywordsInFile $fromKwd -> $toKwd. File: $fileName\n";

    # Ignore all files other than headers/sources
    if (!($fileName =~ m/(\.h$)|(\.hpp$)|(\.cpp$)|(\.c$)|(\.cs$)|(\.xml$)|(\.vcproj$)|(\.csproj$)|(\.sln$)|(\.rc$)/)) {
	return;
    }

    #print "SubstituteKeywordsInFile: replacing contents inside file $fileName\n";
    my $inputFileHandle;
    open $inputFileHandle, "<$fileName" or die "Unable to open file '$fileName' for reading";

    my $outputFileHandle;
    my $outName = $fileName . "_updated.tmp";
    open $outputFileHandle, ">$outName" or die "Unable to open file '$outName' for writing";
    while(<$inputFileHandle>) {
	$_ =~ s/$fromKwd/$toKwd/g;
        print $outputFileHandle $_;
    }

    close $inputFileHandle;
    close $outputFileHandle;

    my $renameOrigTo = $fileName . ".orig";
    rename($fileName, $renameOrigTo) or die "Unable to rename $fileName -> $renameOrigTo";
    rename($outName, $fileName) or die "Unable to rename $outName to $fileName";

    print ("\nUpdated contents of file $fileName\n");
    print ("File with original contents renamed to $renameOrigTo\n");
}

sub RenameKwdInFileName
{
    my $origName = $_[0];
    my $fromKwd = $_[1];
    my $toKwd = $_[2];
    my $newName = $origName;

    if ($newName =~ s/$fromKwd/$toKwd/g) {
	rename($origName, $newName) or die "Unable to rename $origName to $newName";
	print "Renamed $origName -> $newName\n\n";
	return 1;
    }
    return 0;
}

# Copy source directory to a new folder
# Remove all unneeded files from new folder
# Make sure that all file in the new folder are 'writable'
# Run below in all the sub-folders of new folder, including res
MAIN:
{
    my @fileList = glob('*.*');

    foreach(@fileList) {
        my $origName = $_;
	# File content changes
	# Replace djobextractor with ngtestapp
	# Replace DJOBEXTRACTOR with NGTESTAPP
	# Replace DJobExtractor with NgTestApp
	SubstituteKeywordsInFile($origName, mbd, maxwell);
	SubstituteKeywordsInFile($origName, MBD, Maxwell);
	SubstituteKeywordsInFile($origName, Mbd, Maxwell);

	# File name changes
	RenameKwdInFileName($origName, MBD, Maxwell);
	RenameKwdInFileName($origName, Mbd, Maxwell);
    }
}
