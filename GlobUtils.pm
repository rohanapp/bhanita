package GlobUtils;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
              SetVerboseMode PrintIfVerboseMode TrimWhiteSpace AddNewEntryToHashWListValues GetListValueFromHash
              IsCommentOrSpace GetValueFromHash AddNewEntryToHash ParseNameAnchoredAtEnd
              IsWhiteSpaceOrEmpty CleanSplit ArrayLength IsStringPureWord GetFirstWordStripAll
              GetIndentedString IsDirectory IsFileOrDirWritable DoesFileOrDirExist ParseFilePathComponents
              MakeFilePathFromComponents MakeDirPathFromComponentDirs GetSimplifiedAbsolutePath GetAbsolutePath
              CopyStringsToClipboard StartingWorkDir
            );


use strict;
use warnings;
use File::Spec;
use Cwd;
use Cwd 'realpath';
use File::Basename;
use File::Path;
use Carp;
use File::Copy;
use File::Glob ':glob';
use Win32::Clipboard;

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

sub IsStringPureWord { $_[0] =~ /^\w+$/; }

# input: string
# output: first word discard everything else
sub GetFirstWordStripAll { $_[0] =~ /(\w+)/; return $1; }

# Input: string
# WARNING: must pass by reference! E.g. TrimWhiteSpace(\$foo);
sub TrimWhiteSpace
{
    my $lStrRef = $_[0];
    ${$lStrRef} =~ s/^\s+//;
    ${$lStrRef} =~ s/\s+$//;
}

# Purpose: If you have non-unique items in container, but want to take actions once per unique element,
#          use below.
# Usage: create hash that is a placeholder for your unique keys
#        Pass the hash and key to below (in that order)
sub RegisterKey { $_[0]->{$_[1]} = 1; }
sub DoesKeyExist { return exists $_[0]->{$_[1]}; }

# Input: hash reference, key, value
# (assumption: hash values are scalars)
sub AddNewEntryToHash
{
    (my $refToHash, my $hKey, my $hVal) = @_;
    die "Wrong parameters passed to AddNewEntryToHash: key '$hKey' already exist in the hash"
	if exists $refToHash->{$hKey};
    $refToHash->{$hKey} = $hVal;
    #PrintIfVerboseMode("New hash entry created: $hKey => $hVal\n");
}

# Input: hash reference, key
# Lower-case 'key' will used to index hash
# Returns undef or scalar (assumption: hash values are scalars)
sub GetValueFromHash
{
    (my $refToHash, my $utName) = @_;
    return $refToHash->{$utName} if exists $refToHash->{$utName};
    return undef;
}

# Input: hash reference, key, value
# 'key' will be converted to lowercase
# (assumption: hash values are lists)
# Note: to pass hash as the first parameter of subroutine, it must be a reference!
sub AddNewEntryToHashWListValues
{
    (my $refToHash, my $hKey, my @hVal) = @_;

    die "Wrong parameters passed to AddNewEntryToHashWListValues: key '$hKey' already exists in the hash"
	if exists $refToHash->{$hKey};
    @{$refToHash->{$hKey}} = @hVal;
    #PrintIfVerboseMode("New hash-w-list-values entry created: $hKey => @hVal\n");
}

# Input: hash reference, key
# Lower-case 'key' will used to index hash
# Returns scalar! List (assumption: hash values are lists) or undef
sub GetListValueFromHash
{
    (my $refToHash, my $utName) = @_;
    return $refToHash->{$utName} if exists $refToHash->{$utName};
    return undef;
}

my $gCommentOrSpaceMatchStr = "^\\s*(\$|\\/\\/)";
my $gWhiteSpaceMatchStr = "^\\s*\$";
sub IsCommentOrSpace {$_[0] =~ m/$gCommentOrSpaceMatchStr/; }
sub IsWhiteSpaceOrEmpty {$_[0] =~ m/$gWhiteSpaceMatchStr/; }

sub ArrayLength { my $arrayRef = $_[0]; my $arraySize = @{$arrayRef}; return $arraySize; }

#Input: string, indentAmount
sub GetIndentedString
{
    if ($_[1] > 0) {
	return " "x($_[1]) . $_[0];
    }
    return $_[0];
}

# input1: string with separators embedded
# input2: separator (note: space around separator is automatically trimmed)
# output: list of strings that is whitespace-trimmed and with empty strings removed
sub CleanSplit
{
    my $strWSeps = $_[0];
    chomp($strWSeps);
    my $sep = $_[1];
    my @setEntriesList = split(/\s*$sep\s*/, $strWSeps);
    my @cleanList;
    foreach(@setEntriesList) {
	my $trimStr = $_;
	TrimWhiteSpace(\$trimStr);
	next if IsWhiteSpaceOrEmpty($trimStr);
	next if ($trimStr =~ m/\s*$sep\s*/);
	push @cleanList, $trimStr;
    }
    return @cleanList;
}

my $anchorNameLeadPartMatchStr = "\\s*(.+)\\s+(\\w+)\\s*\$";
sub ParseNameAnchoredAtEnd
{
    my $toParse = $_[0];
    die "Unable to parse name and leading part from '$toParse'" unless ($toParse =~ m/$anchorNameLeadPartMatchStr/);
    my $leadPart = $1;
    my $namePart = $2;
    TrimWhiteSpace(\$leadPart);
    TrimWhiteSpace(\$namePart);
    return ($leadPart, $namePart);
}

# File utilities
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

# input: file path (abs or relative to current work dir)
# output: File is deleted if it exists. Dies if unable to delete existing file
sub DeleteFileIfExists
{
    if (-e $_[0]) {
	print "Deleting $_[0]...\n";
	unlink($_[0]) or die "Unable to remove $_[0]";
	print "Done with deletion.\n";
    }
}

# input: dir path (abs or relative to current workdir)
# output: Directory/contents are deleted if it exists. Dies if unable to delete 
# an existing directory
sub DeleteDirAndContentsIfExists
{
    if (-e $_[0]) {
	print "Deleting folder and contents $_[0]...\n";
	rmtree($_[0]) or die "unable to delete folder '$_[0]'\n";
	print "Done with deletion.\n"
    }
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

# input: list of dirs
sub MakeDirPathFromComponentDirs
{
    return File::Spec->catdir(@_);
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

sub CopyStringsToClipboard
{
    my $strToClipBoard = join("", @_);
    print "CopyStringsToClipboard: \n$strToClipBoard\n";

    my $CLIP = Win32::Clipboard();
    $CLIP->Set($strToClipBoard);
}

1;
