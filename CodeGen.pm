package CodeGen;

use strict;
use warnings;
use GlobUtils;

# REVISIT: below database file names are hard-coded
my $gTypeTranslationFile = "D:/programs/perl_scripts/typetranslationhelper.txt";
my $gUtilityTranslationFile = "D:/programs/perl_scripts/utilitytranslationhelper.txt";

# "typetranslation.txt" and "utilitytranslation.txt" databases are used to map abbreviated types and abbreviated utilities
# Abbreviated-type-name is mapped to: list of include references, list of fully qualified type names
# Abbreviated-utility-name is mapped to: list of include references, list of cpp source code that represents utility algorithm

# LIMITATIONS:
# - In the utility definition file, it is possible to use 'abbrev types' but only to define objects. Nothing else

my %gUtilityCodeIncludeReferences;
my %gUtilityCodeImplBlock;
my %gAbbrevTypeIncludeReferences;
my %gAbbrevTypeToFullyQualifiedType;

my $gDebugLogContextKwd = "debuglogcontext";
my $gDebugLogAbbrevContextKwd = "dlcntxt";

sub IsAString { $_[0] =~ m/^\s*AString\s*$/; }

# Returns scalar! A reference to list or undef
sub GetIncludeReferencesOfUtility
{
    # Some utilities need to be hardcoded for now
    my @includeRefList;
    if ($_[0] eq $gDebugLogContextKwd) {
	push @includeRefList, "wbintegutils/LoggingHelper.h";
	return \@includeRefList;
    }
    return GetListValueFromHash(\%gUtilityCodeIncludeReferences, $_[0]);
}

# Returns scalar! A reference to list or undef
sub GetIncludeReferencesOfAbbrevType
{
    my $foundEntry = GetListValueFromHash(\%gAbbrevTypeIncludeReferences, $_[0]);
    # REVISIT: performing a quick hack!
    if (!defined $foundEntry) {
	my $lcStr = lc($_[0]);
	$foundEntry = GetListValueFromHash(\%gAbbrevTypeIncludeReferences, $lcStr);
    }
    return $foundEntry;
}

# Returns fully-qualified type if translation exists. Otherwise
# returns the same type as passed in
sub GetFullyQualifiedTypeOfAbbrevType
{
    my $translatedType = GetValueFromHash(\%gAbbrevTypeToFullyQualifiedType, $_[0]);
    if (defined $translatedType) {
	return $translatedType;
    }
    return $_[0];
    #my $ff = GetValueFromHash(\%gAbbrevTypeToFullyQualifiedType, $_[0]);
    #print "GetFullyQualifiedTypeOfAbbrevType: $ff\n";
    #return $ff;
}

sub GetDebugLoggingHelperCode
{
    my ($className, $methodName, $methodArgsNameListRef, $methodReturnName) = @_;

    my @loggingHelperLines;
    push @loggingHelperLines, "CLoggingHelper logHelp(ACHAR(\"" . "$className" . "::" . "$methodName\"));";

    foreach(@{$methodArgsNameListRef}) {
	push @loggingHelperLines, "logHelp.LogParam(ACHAR(\"$_\"), $_);";
    }
    push @loggingHelperLines, "logHelp.LogParam(ACHAR(\"$_\"), $_, true);" if $methodReturnName ne "";

    return \@loggingHelperLines;
}

# Returns scalar! A reference to list or undef
# Input: utilityname, classname, methodname, methodArgVarNameListRef, methodReturnValName
sub GetSourceCodeForUtility
{
    my ($utilName, $className, $methodName, $methodArgsNameListRef, $methodReturnName) = @_;

    # Some utilities need to be hardcoded for now
    if ($utilName eq $gDebugLogContextKwd || $utilName eq $gDebugLogAbbrevContextKwd ) {
	return GetDebugLoggingHelperCode($className, $methodName, $methodArgsNameListRef, $methodReturnName);
    }
    my $foundEntry = GetListValueFromHash(\%gUtilityCodeImplBlock, $utilName);
    # REVISIT: performing a quick hack!
    if (!defined $foundEntry) {
	my $lcStr = lc($utilName);
	$foundEntry = GetListValueFromHash(\%gUtilityCodeImplBlock, $lcStr);
    }
    return $foundEntry;
}

# REVISIT hack
sub DoesAbbrevTypeRepresentSTL
{
    return $_[0] =~ m/^(stlq)|(stlv)|(stlm)|(strmap)|(strvalmap)|(strvec)$/;
}
sub IsSTLIncludeDirective
{
    my ($isSTL, $stlType, $elemType1, $elemType2) = (0, "", "", "");

    my $incl = $_[0];
    TrimWhiteSpace(\$incl);
    my $stlTypeMatchStr = "vector|map|deque|set";
    if ($incl =~ m/^($stlTypeMatchStr)/) {
	$isSTL = 1;
	$stlType = $1;
    }
    return ($isSTL, $stlType, $elemType1, $elemType2) unless $isSTL;

    if ($incl =~ m/^($stlTypeMatchStr)_(\w+)/) {
	$elemType1 = $2;
    }
    if ($incl =~ m/^($stlTypeMatchStr)_(\w+)_(\w+)/) {
	$elemType2 = $3;
    }
    #print "IsSTLIncludeDirective: $isSTL, $stlType, $elemType1, $elemType2\n";
    return ($isSTL, $stlType, $elemType1, $elemType2);
}

sub IsStandardType
{
    return 1 if ($_[0] =~ m/(int|char|double|float|long|void|bool)(|\s*\*+)/);
    # print "IsStandardType returns false for '$_[0]'\n";
    return 0;
}

# REVISIT: below has number of limitations. Wont support function pointers
# Input should not include variable names
sub IsTypeModifier { ($_[0] =~ m/^const|^mutable|^volatile|^virtual|^static/) ? 1 : 0; }
sub GetTypeNameExclModifiers
{
    while ($_[0] =~ m/(\w+)/g) {
	# print "Checking if $1 is a type or modifier...\n";
	return $1 if !IsTypeModifier($1);
    }
}

# REVISIT: below is very basic. Will likely be incorrect for certain types
# Input: variable type with optionally modifiers, name
# Output: 1 or 0
# Returns 1 for A*, A&. Return 0 for A, const A
sub IsTypeAPointerOrReference { return ($_[0] =~ m/\*|&/) ? 1 : 0; }

# Input: Variable declaration. Must include type AND name. Valid example strings below.
# Returns list: type with all modifiers, varname
# Example inputs:
# "char** & argv ", "msgmgr* f", "const A& const varName", "void v", " MessageSeverity severity "
# "const AnsoftCommandContext* context", "int i1", " const int remainingMsg"
sub SplitVariableDeclarationIntoTypeWModAndName
{
    my $varDecl = $_[0];
    my ($typeStr, $varName) = ParseNameAnchoredAtEnd($varDecl);
    # If variable name is a type modifier or standard type, then the variable name is likely unspecified
    # Illegal inputs: const int& const, int
    die "Error in SplitVariableDeclarationIntoTypeAndName: Invalid variable-name '$varName' - name cannot be a standard type or modifier"
	if (IsTypeModifier($varName) || IsStandardType($varName));
    TrimWhiteSpace(\$typeStr);
    TrimWhiteSpace(\$varName);
    #PrintIfVerboseMode("SplitVariableDeclarationIntoTypeAndName:$typeStr;$varName;\n");
    return ($typeStr, $varName);
}

sub ParseTypeTranslationFile
{
    PrintIfVerboseMode "Parsing type translation file...\n";
    my $fileHandle = $_[0];
    while(<$fileHandle>) {
	next if IsCommentOrSpace($_);
	# Sample: msg: AnsoftMessage, ngcore/messagelibni/AnsoftMessage.h
	my $abbrevTypeLineMatchStr = "(\\w+):\\s*(.+),\\s*(.+)";
	die "Unable to parse '$_' line from type translation file" unless $_ =~ m/$abbrevTypeLineMatchStr/;
	TrimWhiteSpace(\$1);
	TrimWhiteSpace(\$2);
	TrimWhiteSpace(\$3);

	# Update 2 maps: abbrev-type => fully-qualified-type, include-reference
        AddNewEntryToHash(\%gAbbrevTypeToFullyQualifiedType, $1, $2) or die "'$1' type abbrev cannot be reused for diff types";
	my @tmpList = ($3);
        AddNewEntryToHashWListValues(\%gAbbrevTypeIncludeReferences, $1, @tmpList);
	PrintIfVerboseMode("Incorporated following type-translation line into database:$1=>$2,$3;\n");
    }	
    PrintIfVerboseMode "Done.\n";
    return 1;
}

#input: comma separated include references such as "abbrev1, foo.h, abbrev2"
sub GetIncludeRefsResolveAbbrevs
{
    my @includeRefList = CleanSplit($_[0], ",");
    my @resolvedRefList = ();
    foreach(@includeRefList) {
	my $includeRef = $_;
	my $scalRefForList = GetIncludeReferencesOfAbbrevType($includeRef);
	if (defined $scalRefForList) {
	    my @refList = @$scalRefForList;
	    die "Multiple include references for a single type are not yet supported" if ($#refList > 0);
	    my $ref = $refList[0];
	    push @resolvedRefList, $ref;
	} else {
	    push @resolvedRefList, $includeRef;
	}
    }
    return \@resolvedRefList;
}

my @resolvedIncludeReferences;
# Sample line to match: "fileexists: ngcore/ngutils/LongFilenameOperations.h {"
my $gCodeUtilityLineMatchStr = "([\\w,]+):\\s*(|.+)\\s*{"; 
sub ParseOneUtilityCodeBlock
{
    (my $blockDefinitionStr, my @blockCodeStrs) = @_;
    die "Unable to parse '$blockDefinitionStr' line from utility translation file" 
	unless $blockDefinitionStr =~ m/$gCodeUtilityLineMatchStr/;
    #print "ParseOneUtilityCodeBlock: ;$1;$2;\n";
    my @utilList = CleanSplit($1, ",");

    my @utilSpecifiedInclList = CleanSplit($2, ",");
    my @resolvedIncludeReferences;
    foreach(@utilSpecifiedInclList) {
	push @resolvedIncludeReferences, @{GetIncludeRefsResolveAbbrevs($_)};
	#print "@{GetIncludeRefsResolveAbbrevs($_)} \n";
    }

    my @srcCodeLines;
    foreach(@blockCodeStrs) {
	my $srcLine = $_;
	# Match statements. Allow objects to be defined as 'abbrev types'
	# Sample1 where lfn is matched: lfn lfn(f1);
        # Sample2: bool exists = (LFN_Exists(lfn) && LFN_IsExistingDirectory(lfn));
	my $implStatementMatchStr = "^(\\w+)\\s+";
	my $fullQualType;
	if (($srcLine =~ m/$implStatementMatchStr/) && ($fullQualType = GetFullyQualifiedTypeOfAbbrevType($1)) && $fullQualType ne $1) {
	    # Ensure type's header is included in the source code
	    my @typeIncludeFile = @{GetIncludeRefsResolveAbbrevs($1)};
	    die "Only one include is supported per type" unless ($#typeIncludeFile <= 0);
	    push @resolvedIncludeReferences, $typeIncludeFile[0];
	    # Replace abbrev type with fully qualified type
	    $srcLine =~ s/$implStatementMatchStr/$fullQualType /;
	}
	TrimWhiteSpace(\$srcLine);
	push @srcCodeLines, $srcLine;
    }

    # Update 2 maps: utility => include-reference, implementation code
    foreach(@utilList) {
	my $utilityName = $_;
	AddNewEntryToHashWListValues(\%gUtilityCodeIncludeReferences, $utilityName, @resolvedIncludeReferences);
	AddNewEntryToHashWListValues(\%gUtilityCodeImplBlock, $utilityName, @srcCodeLines);
	PrintIfVerboseMode("Incorporated following utility-translation line into database:$utilityName;\n");
	PrintIfVerboseMode("Utility needs includes:@resolvedIncludeReferences;\n");
	PrintIfVerboseMode("Utility implementation:\n@srcCodeLines;\n");
    }

    PrintIfVerboseMode "Done.\n";
    return 1;
}

sub ParseUtilityTranslationFile
{
    PrintIfVerboseMode "Parsing utility translation file...\n";
    my $fileHandle = $_[0];
    my @oneUtilityBlockStr;
    while(<$fileHandle>) {
	next if IsCommentOrSpace($_);
	die "Unable to parse '$_' line from utility translation file" unless $_ =~ m/$gCodeUtilityLineMatchStr/;
	# Start a new block
	$#oneUtilityBlockStr = -1;
	my $blockDefinitionStr = $_;
	while(<$fileHandle>) {
	    #print "ParseUtilityTranslationFile: $_\n";
	    my $utilityBlockEndMatchStr = "^\\s*}\\s*\$"; 
	    last if ($_ =~ m/$utilityBlockEndMatchStr/);
	    push @oneUtilityBlockStr, $_;
	}
	ParseOneUtilityCodeBlock($blockDefinitionStr, @oneUtilityBlockStr);
    }
    PrintIfVerboseMode "Done.\n";
    return 1;
}

# Input parameter: verbose flag
sub InitializeCodeGenDatabases
{
    PrintIfVerboseMode "Initializing codegen databases...\n";
    
    my $typeTranslationFileHandle;
    open($typeTranslationFileHandle, "< $gTypeTranslationFile") or die "Unable to open type translation file '$gTypeTranslationFile'";
    ParseTypeTranslationFile($typeTranslationFileHandle) or die "Unable to parse type translation file '$gTypeTranslationFile'";
    close($typeTranslationFileHandle);

    my $utilityTranslationFileHandle;
    open($utilityTranslationFileHandle, "< $gUtilityTranslationFile") or die "Unable to open utility translation file '$gUtilityTranslationFile'";
    ParseUtilityTranslationFile($utilityTranslationFileHandle) or die "Unable to parse type translation file '$gUtilityTranslationFile'";
    close($utilityTranslationFileHandle);
    PrintIfVerboseMode "Done initializing codegen databases.\n";
}

my $gCopyRightStr = << "COPYRIGHT__";
// -----------------------------------------------------------------
// Original Author: Naresh Appannagaari
// Contents: 
//     
// Copyright 2011 ANSYS Inc, All Rights Reserved
// No part of this file may be reproduced, stored in a 
// retrieval system, or transmitted in any form or by any means -
// electronic, mechanical, photocopying, recording, or otherwise - 
// without prior written permission of ANSYS Inc.
// -----------------------------------------------------------------
COPYRIGHT__

sub PrintCopyRightCommentToHeaderFile
{
    my $fileHandle = $_[0];
    print $fileHandle "$gCopyRightStr";
}


1;
