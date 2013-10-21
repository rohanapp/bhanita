use strict;
use File::Glob;
use Getopt::Long;
use DateTime;
use File::Copy;
use CodeGen;
use GlobUtils;

# LIMITATIONS: Following are the limitations. Clients should avoid limitations or fix this code

# REVISIT: following globals must be set before running the program
my $gCodeGenSpecFile = "e:/programs/perl_scripts/codegentempls/codegenspec.txt";
my $gOutputFilesDir = "e:/programs/perl_scripts/codegentempls";


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

my @gStandardHeaderIncludes = ("ngappexports", "portab", "wintypes", "assert", "platform_specifics");
my @gHeaderFileIncludeReferences;
my @gHeaderFileForwardDeclarations;
my @gClassPurpose;
my $gClassName;
my @gClassParents;
my @gClassDefinitionBodyLines;
my @gClassDefinitionBodyLinesIndentation;

my @gStandardSrcIncludes = ("ansdebug", "msgmgr", "msg");
my @gClassImplIncludeFileReferences;
my @gClassImplUtilityReferences;
my @gClassImplBodyLines;
my @gClassImplBodyLinesIndentation;

sub UniqueNonStandardTypes
{
    my @uniqNSList = ();
    my %uniqueTypesPlaceHolder;
    foreach(@_) {
	next if CodeGen::IsStandardType($_) || GlobUtils::DoesKeyExist(\%uniqueTypesPlaceHolder, $_);
	GlobUtils::RegisterKey(\%uniqueTypesPlaceHolder, $_);
	push @uniqNSList, $_;
    }
    PrintIfVerboseMode("UniqueNonStandardTypes: @uniqNSList\n");
    return @uniqNSList;
}

# The type's members are accessed in this case
# Input: type name without any modifiers
sub RegisterTypeUsedInHeader
{
    my $typeName = $_[0];
    die "Invalid input. Type name '$typeName' should not contain modifiers" unless IsStringPureWord($typeName);
    # REVISI: rename gHeaderFileIncludeReferences to gHeaderFileIncludes
    # For now: registered even the standard types. The only ones that will have include directives are the non-standard types
    push @gHeaderFileIncludeReferences, $typeName;
}

# dont include a file multiple times or forward declare multiple times
my %gIncludeDirectivesAddedToCppOrH;
my %gForwardDeclarationsAddedToH;


# Inputs: file handle, abbrev-typelist
sub WriteIncludeDirectivesToFile
{
    my ($fileHandle, @typesToInclude) = @_;
    my @uniqNonStandardTypes = UniqueNonStandardTypes(@typesToInclude);
    foreach(@uniqNonStandardTypes) {
	my $includeRefStr = CodeGen::GetIncludeReferencesOfAbbrevType($_);
	# print "GetIncludeReferencesOfAbbrevType '$_' returned '$includeRefStr'\n";
	$includeRefStr = CodeGen::GetIncludeReferencesOfUtility($_) unless (defined $includeRefStr);
	if (defined $includeRefStr) {
	    my $includeDirective = @{$includeRefStr}[0];
	    next if ($includeDirective =~ m/\s*^none\s*$/);
	    if (!exists $gIncludeDirectivesAddedToCppOrH{$includeDirective}) {
		my ($isSTL, $stlType, $elemType1, $elemType2) = CodeGen::IsSTLIncludeDirective($includeDirective);
		print $fileHandle "#include \"$includeDirective\"\n" if !$isSTL;
		print $fileHandle "#include <$stlType>\n" if $isSTL;
		WriteIncludeDirectivesToFile($fileHandle, ($elemType1, $elemType2)) if  $elemType1 ne "";
		$gIncludeDirectivesAddedToCppOrH{$includeDirective} = 1;
	    }
	}
    }
}

sub WriteForwardDeclarationsToFile
{
    my ($fileHandle, @typesToInclude) = @_;
    my @uniqNonStandardTypes = UniqueNonStandardTypes(@typesToInclude);
    foreach(@uniqNonStandardTypes) {
	my $fullQualType = CodeGen::GetFullyQualifiedTypeOfAbbrevType($_);
	if (defined $fullQualType) {
	    if (!exists $gForwardDeclarationsAddedToH{$fullQualType}) {
		print $fileHandle "class $fullQualType;\n";
		$gForwardDeclarationsAddedToH{$fullQualType} = 1;
	    }
	}
    }
}

# The type is not used but just referenced
# Input: type name without any modifiers
sub RegisterTypesReferencedInHeader
{
    my $typeName = $_[0];
    die "Invalid input. Type name should not contain modifiers" unless IsStringPureWord($typeName);
    # For now: registered even the standard types. The only ones that will have forward decls are the non-standard types
    push @gHeaderFileForwardDeclarations, $typeName;
    # This same type is likely used in cpp and so ensure approp header is included
    push @gClassImplIncludeFileReferences, $typeName;
}

sub WriteStandardIncludesToHeaderFile
{
    WriteIncludeDirectivesToFile($_[0], @gStandardHeaderIncludes);
}

sub WriteIncludesToHeaderForSelfContainment
{
    WriteIncludeDirectivesToFile($_[0], @gHeaderFileIncludeReferences);
}

sub WriteIncludesToCppFile
{
    my $fileHandle = $_[0];
    print $fileHandle "#include \"headers" . ".h\"\n";
    print $fileHandle "#include \"$gClassName" . ".h\"\n";
    WriteIncludeDirectivesToFile($_[0], @gStandardSrcIncludes);
    WriteIncludeDirectivesToFile($_[0], @gClassImplIncludeFileReferences);
    # REVISIT: is below the way to go
    WriteIncludeDirectivesToFile($_[0], @gClassImplUtilityReferences);
}

sub WriteForwardDeclarationsToHeaderFile
{
    WriteForwardDeclarationsToFile($_[0], @gHeaderFileForwardDeclarations);
}

sub WritePurposeCommentsToFile
{
    my $fileHandle = $_[0];
    foreach(@gClassPurpose) {
	chomp($_);
	print $fileHandle "$_\n";
    }
}


sub RegisterTypeGivenVariableType
{
    #my @checkDecl = ("  char** & ", "msgmgr* ", "const A& const", "void ", " MessageSeverity"
    my $typeFullName = $_[0];
    my $isTypePtrRef = CodeGen::IsTypeAPointerOrReference($typeFullName);
    my $typeBareName = CodeGen::GetTypeNameExclModifiers($typeFullName);
    PrintIfVerboseMode("RegisterTypeGivenVariableType: '$typeBareName' is registered as a ");
    my $isSTLType = CodeGen::DoesAbbrevTypeRepresentSTL($typeBareName);
    PrintIfVerboseMode "DoesAbbrevTypeRepresentSTL: $typeBareName\n" if $isSTLType;
    if ($isTypePtrRef && !$isSTLType) {
	PrintIfVerboseMode("forward declaration in header file.\n");
	RegisterTypesReferencedInHeader($typeBareName);
    } else {
	PrintIfVerboseMode("include in header file.\n");
	RegisterTypeUsedInHeader($typeBareName);
    }
    
    my $fullQualType = CodeGen::GetFullyQualifiedTypeOfAbbrevType($typeBareName);
    $typeFullName =~ s/\Q$typeBareName/$fullQualType/ unless $fullQualType eq $typeBareName;
    return $typeFullName;
}

sub RegisterTypeGivenVariableDeclaration
{
    #my @checkDecl = ("  char** & argv ", "msgmgr* f", "const A& const varName", "void v", " MessageSeverity severity ",
    #" const AnsoftCommandContext* context", "int i1", " const lfn remainingMsg");
    my $varDecl = $_[0];
    my ($typeFullName, $varName) = CodeGen::SplitVariableDeclarationIntoTypeWModAndName($varDecl);
    my $translatedTypeFullName = RegisterTypeGivenVariableType($typeFullName);
    $varDecl =~ s/\Q$typeFullName/$translatedTypeFullName/ unless $typeFullName eq $translatedTypeFullName;
    return $varDecl;
}

# Input: reference-to-body-line-array, ref-to-body-line-indentation-array, line-string, indentationAmount
sub RegisterBodyLineAndIndentation
{
    my ($bodyLineArrayRef, $indentArrayRef, $lineStr, $amtIndentation) = @_;
    push @{$bodyLineArrayRef}, $lineStr;
    push @{$indentArrayRef}, $amtIndentation;
    PrintIfVerboseMode("Line string added to body line data: " . GetIndentedString($lineStr, $amtIndentation) . "\n");
}

# REVISIT: it is nice if we can keep class body lines as a datastructure, where each line has
# associated with various parts such as: return type, name, etc. Since this is more work,
# postpone. For now, the body-lines will contain resolved abbrev-types and resolved utility funcs
# Input (all as scalars): Method return(referencing full-qual-types), method name, 
#                         arg list as scalar reference(referencing full-qualified-types), modifier, 
#                         methodbody (referencing utilities that should be expanded)
# Output: Body (header as well as cpp file) global structures are populated
sub RegisterMethodForHeaderCppBodyLines
{
    # Sample: "const bool InitializeApplication(int argc, char** argv) const {debuglogcontext,addmessage}"
    # Sample: "const msgmgr* InitializeApplication(const lfn& ff) const {fileexists}"
    # Sample: "const msgmgr& CustomInitializeApplication() const = 0 {}"
    # ZZZ
    my ($methodReturnPart, $methodName, $methodArgsRef, $methodModifiersPart, $methodBodyPart) = @{$_[0]};
    # ZZZ
    my $methodArgsStr = (defined $methodArgsRef) ? join(", ", @{$methodArgsRef}) : "";
    my @argNameList;
    foreach(@{$methodArgsRef}) {
	my ($tmp, $argName) = ParseNameAnchoredAtEnd($_);
	push @argNameList, $argName;
    }

    # ZZZ
    my $headerLine = "";
    $headerLine .= "$methodReturnPart " if (defined $methodReturnPart);
    $headerLine .= ($methodName . "(" . $methodArgsStr . ")");
    $headerLine .= " $methodModifiersPart" if (defined $methodModifiersPart);
    $headerLine .= ";";
    # print "headerLine = $headerLine\n";

    # "= 0" must be stripped from pure virtual method line
    # REVISIT my $modifiersNoPV = GetFirstWordStripAll($methodModifiersPart);
    my $srcLine = "";
    $srcLine .= "$methodReturnPart " if (defined $methodReturnPart);
    $srcLine .= ($gClassName . "::" . $methodName . "(" . $methodArgsStr . ")");
    $srcLine .= " $methodModifiersPart" if (defined $methodModifiersPart);
    #$srcLine .= GetFirstWordStripAll($methodModifiersPart) if (defined $methodModifiersPart && $methodModifiersPart ne "");

    my @utilitiesNeeded = (defined $methodBodyPart) ? CleanSplit($methodBodyPart, ",") : ();
    my @srcUtilityLines;
    foreach(@utilitiesNeeded) {
	my $utName = $_;
	#print "Utils needed: $utName\n";
	my $utilSrcCode = CodeGen::GetSourceCodeForUtility($_, $gClassName, $methodName, \@argNameList, "");
	if (!defined $utilSrcCode) {
	    print "ERROR! Utility '$utName' is unknown. Could it be a typo or denote type abbrev?\n";
	    next;
	}
	map push (@srcUtilityLines, $_), @{$utilSrcCode};
	# Ensure headers needed by a utility are included into cpp file
	push @gClassImplUtilityReferences, $utName;
    }
    
    # REVISIT: start from here. Now we have all the header, cpp lines. Need to add to global vecs
    # And also add indentation lines ZZZZ
    # Header body lines
    RegisterBodyLineAndIndentation(\@gClassDefinitionBodyLines, \@gClassDefinitionBodyLinesIndentation, $headerLine, 2);
    # Src body lines
    RegisterBodyLineAndIndentation(\@gClassImplBodyLines, \@gClassImplBodyLinesIndentation, "\n", 0);
    RegisterBodyLineAndIndentation(\@gClassImplBodyLines, \@gClassImplBodyLinesIndentation, $srcLine, 0);
    RegisterBodyLineAndIndentation(\@gClassImplBodyLines, \@gClassImplBodyLinesIndentation, "{", 0);
    foreach(@srcUtilityLines) {
	RegisterBodyLineAndIndentation(\@gClassImplBodyLines, \@gClassImplBodyLinesIndentation, $_, 2);
    }
    RegisterBodyLineAndIndentation(\@gClassImplBodyLines, \@gClassImplBodyLinesIndentation, "}", 0);
}

sub RegisterMemberForHeaderCppBodyLines
{
    my ($memberResolvedTypeName, $memberVarName, $memberMethods) = @_;
    my $headerLine = join(" ", ($memberResolvedTypeName, $memberVarName . ";"));
    # REVISIT: cpp line needs to include taking care of standard methods such as constructor/destructor/operations/etc.

    # Header body lines
    RegisterBodyLineAndIndentation(\@gClassDefinitionBodyLines, \@gClassDefinitionBodyLinesIndentation, $headerLine, 2);
}

sub RegisterClassMethod
{
    my ($methodReturnPart, $methodName, $methodArgsRef, $methodModifiersPart, $methodBodyPart) = @{$_[0]};
    my @fullQualArgs;
    # Register types referenced in the method's arguments
    foreach(@{$methodArgsRef}) {
	push @fullQualArgs, RegisterTypeGivenVariableDeclaration($_);
    }
    # Register types referenced in the method's return
    # for constructors, destructors there is no return type
    my $fullQualReturnPart = "";
    if (defined $methodReturnPart && $methodReturnPart ne "") {
	$fullQualReturnPart = $methodReturnPart;
	$fullQualReturnPart = RegisterTypeGivenVariableType($methodReturnPart);
    }

    # Register method so body-line of header and cpp are populated
    # Below methods don't translate abbrev-types and so send only qualified types
    my @argList = ($fullQualReturnPart, $methodName, \@fullQualArgs, $methodModifiersPart, $methodBodyPart);
    RegisterMethodForHeaderCppBodyLines(\@argList);
}
sub RegisterClassMember
{
    my ($memberTypeName, $memberVarName, $memberMethods) = @_;

    my $memberTypeResolvedName = RegisterTypeGivenVariableType($memberTypeName);

    # Register member so body-line of header and cpp (constructor/destructor) are populated
    # REVISIT: take care of constructor/destructor for members
    RegisterMemberForHeaderCppBodyLines($memberTypeResolvedName, $memberVarName, $memberMethods);
}

#Input: scalar string representing line from method block
sub ParseAndRegisterClassMethod
{
    my $memFuncLine = $_[0];

    # Sample: "const bool InitializeApplication(int argc, char** argv) const {debuglogcontext,addmessage}"
    # Sample: "const msgmgr* InitializeApplication(const lfn& ff) const {fileexists}"
    # Sample: "const msgmgr& CustomInitializeApplication() const = 0 {}"
    my $methodPartsMatchStr = "(.+)\\((.*)\\)(.*){(.*)}";

    die "Unable to parse member function '$memFuncLine' format" unless ($memFuncLine =~ m/$methodPartsMatchStr/);
    my $methodReturnAndNamePart = $1;
    my $methodArgsPart = $2 ? $2 : "";
    my $methodModifiersPart = $3 ? $3 : "";
    my $methodBodyPart = $4 ? $4 : "";
    TrimWhiteSpace(\$methodReturnAndNamePart);    TrimWhiteSpace(\$methodArgsPart);    
    TrimWhiteSpace(\$methodModifiersPart);        TrimWhiteSpace(\$methodBodyPart);
    # print "Parsed so far: $methodReturnAndNamePart, $methodArgsPart, $methodModifiersPart, $methodBodyPart\n";

    # ZZZ
    # special constructor/destructor
    my $isConstructorDestructor = 0;
    my $methodName = $gClassName;
    if (($memFuncLine =~ m/^constructor/i) || ($memFuncLine =~ m/^destructor/i)) {
	# print "$memFuncLine\n";
	# REVISIT: this special-case might not be necessary at all
	$isConstructorDestructor = 1;
	if ($memFuncLine =~ m/constructor/i) {
	    $methodName = $gClassName;
	} else {
	    $methodName = qw(~) . "$gClassName";
	}
    }

    # REVISIT: let below function return a list by reference rather than copy
    my @methodArgs = ();
    @methodArgs = CleanSplit($methodArgsPart, ",") if (defined $methodArgsPart && $methodArgsPart ne "");

    my $methodReturnPart = "";
    ($methodReturnPart, $methodName) = ParseNameAnchoredAtEnd($methodReturnAndNamePart) unless ($isConstructorDestructor);

    PrintIfVerboseMode("Parsed method information:$methodReturnPart;$methodName;@methodArgs;$methodModifiersPart;$methodBodyPart;\n");

    #ZZZ
    my @argList = ($methodReturnPart, $methodName, \@methodArgs, $methodModifiersPart, $methodBodyPart);
    RegisterClassMethod(\@argList);
}

sub ParseAndRegisterClassMember
{
    my $memberLine = $_[0];

    # Sample: "AppStartPrms m_appStartupParams {get,set}"
    # Sample: "AppStartPrms* m_appStartupParams {get,set}"
    # This wont work with pointer members. my $membersLineMatchStr = "^\\s*(\\w+)\\s*[\\*\\&]*\\s+(\\w+)\\s+{(.+)}\\s*";
    # my $membersLineMatchStr = "^\\s*(.+)\\s+(\\w+)\\s+{(.+)}\\s*";
    my $membersLineMatchStr = "^\\s*(.+)\\s+(\\w+)\\s*(|;|{.*})";

    die "Unable to parse member format '$memberLine'" unless ($memberLine =~ m/$membersLineMatchStr/);
    my $memberTypeName = $1;
    my $memberName = $2;
    my $memberMethods = $3;
    TrimWhiteSpace(\$memberTypeName);
    TrimWhiteSpace(\$memberName);    
    TrimWhiteSpace(\$memberMethods);
    # print "Parsed so far: $methodReturnAndNamePart, $methodArgsPart, $methodModifiersPart, $methodBodyPart\n";

    PrintIfVerboseMode("Parsed member information:$memberTypeName;$memberName;$memberMethods;\n");

    RegisterClassMember($memberTypeName, $memberName, $memberMethods);
}

# Create header and cpp files using the following information:
# Header file: multiple include protection, copyright, standard includes, includes specific to this class, 
#              forward declarations, class purpose, class definition line using class name/parents, 
#              class body lines, closing header statements (class closing brace, include protection)
# Source file: cpp includes, cpp body lines
# Todo: ensure includes are not done multiple times
#       body lines should contain code that can be spit out as-is. Abbrev types to be replaced with fully qualified
sub GenerateCodeForClass
{
    PrintIfVerboseMode("Generating header and cpp file for class: $gClassName, @gClassPurpose\n");
    die "Only named and empty classes supported" unless ($gClassName ne "");

    # header file
    my $classHeaderFileName = MakeFilePathFromComponents($gOutputFilesDir, $gClassName, ".h");
    my $classHeaderHandle;
    open($classHeaderHandle, ">$classHeaderFileName") or die "Unable to open file '$classHeaderFileName' for writing";

    CodeGen::PrintCopyRightCommentToHeaderFile($classHeaderHandle);
    print $classHeaderHandle "#ifndef _" . uc($gClassName) . "_H\n";
    print $classHeaderHandle "#define _" . uc($gClassName) . "_H\n";
    print $classHeaderHandle "\n";

    WriteStandardIncludesToHeaderFile($classHeaderHandle);
    print $classHeaderHandle "\n";

    WriteIncludesToHeaderForSelfContainment($classHeaderHandle);
    print $classHeaderHandle "\n";

    WriteForwardDeclarationsToHeaderFile($classHeaderHandle);
    print $classHeaderHandle "\n";

    # Add 'purpose' comments
    WritePurposeCommentsToFile($classHeaderHandle);

    # Class definition line
    # ZZZ
    print $classHeaderHandle "class NGANSOFTCOMAPP_API $gClassName";
    if (ArrayLength(\@gClassParents)) {
	print $classHeaderHandle " : ";
	my $parentsStr = join(", ", map { "public " . $_; } @gClassParents);
	print $classHeaderHandle "$parentsStr";
    }

    print $classHeaderHandle "\n{\n";

    # Class body lines to header
    my $numClassDefBodyLines = ArrayLength(\@gClassDefinitionBodyLines);
    my $otherNumBodyLines = ArrayLength(\@gClassDefinitionBodyLinesIndentation);
    die "Array length for indentation '$otherNumBodyLines' and for class-def-body-lines '$numClassDefBodyLines' must match" 
	unless $numClassDefBodyLines == $otherNumBodyLines;
    for (my $ii = 0; $ii < $numClassDefBodyLines; $ii++) {
	my $currIndent = $gClassDefinitionBodyLinesIndentation[$ii];
	print $classHeaderHandle GetIndentedString($gClassDefinitionBodyLines[$ii], $currIndent) . "\n";
    }

    print $classHeaderHandle "\n";
    print $classHeaderHandle "};\n";
    print $classHeaderHandle "\n";
    print $classHeaderHandle "#endif\n";

    # cpp file
    my $classSrcFileName = MakeFilePathFromComponents($gOutputFilesDir, $gClassName, ".cpp");
    my $classSrcHandle;
    open($classSrcHandle, ">$classSrcFileName") or die "Unable to open file '$classSrcFileName' for writing";
    WriteIncludesToCppFile($classSrcHandle);

    # Class implementation body lines to cpp file
    my $numClassImplBodyLines = ArrayLength(\@gClassImplBodyLines);
    my $otherLines = ArrayLength(\@gClassImplBodyLinesIndentation);
    die "Array length for indentation '$otherLines' and for class-impl-body-lines '$numClassImplBodyLines' must match" 
	unless $numClassImplBodyLines == $otherLines;
    for (my $jj = 0; $jj < $numClassImplBodyLines; $jj++) {
	my $currIndent = $gClassImplBodyLinesIndentation[$jj];
	my $cppLineStr = $gClassImplBodyLines[$jj];
	$cppLineStr =~ s/^virtual\s+//;
	print $classSrcHandle GetIndentedString($cppLineStr, $currIndent) . "\n";
    }

    # Flush the generated files
    close($classHeaderHandle);
    close($classSrcHandle);

    # copy header, cpp files to another file with a constant name
    copy($classHeaderFileName, "header_code.h") or die "Unable to copy $classHeaderFileName to header.h";
    copy($classSrcFileName, "src_code.cpp") or die "Unable to copy $classHeaderFileName to header.h";
}

MAIN:
{
    my $verbose = 0;
    GetOptions("verbose" => \$verbose) or Usage("Incorrect command-line");
    SetVerboseMode($verbose);

    CodeGen::InitializeCodeGenDatabases;

    my $codeGenSpecFileHandle;
    open($codeGenSpecFileHandle, "< $gCodeGenSpecFile") or die "Unable to open file '$gCodeGenSpecFile' for reading";

    my $codeTypeLinePattern = "CodeType:\\s*(\\w+)";
    my $parseContext = "";

    # Ensure that the code generation is needed for 'class' (nothing else supported at this time)
    while(<$codeGenSpecFileHandle>) {
	# Remove new line at the end
	chomp($_);
	PrintIfVerboseMode("Parsing new line=$_");
	if ($parseContext eq "") {
	    # Ignore if empty
	    next if ($_ eq "" || $_ =~ m/^\s*$/);
	    # print "$_\n";
	    die "Codetype must be specified" unless ($_ =~ m/$codeTypeLinePattern/);
	    PrintIfVerboseMode("Parsed codetype as '$1'\n");
	    $parseContext = lc($1);
	    last;
	}
    }
    die "Only classes supported" unless (lc($parseContext) eq "class");

    # Check if there is a need for registering include file references.
    # Continue parsing the file until class-definition-line
    # Read up all empty-lines/comments as 'class purpose'. It is an error 
    # if anything other than class-defn-line/comments/empty-line is encountered.
    # After below block of code: class name and parents are read. Class body parsing
    # to start next.
    # Sample: class AnsoftCOMNgApplication: AnsoftCOMApplication, IMessageHandler {
    my $classDefLineMatchStr = "^class\\s+(.+)\\s*:\\s*(.+)\\s*{";
    my $extraIncludeInHeadersLinePattern = "ExtraIncludeInHeaders\\s*:(.+)";
    my $extraIncludeInCppLinePattern = "ExtraIncludeInCpp\\s*:(.+)";
    while(<$codeGenSpecFileHandle>) {
        if (IsCommentOrSpace($_)) {
	    push @gClassPurpose, $_;
	} elsif ($_ =~ m/$extraIncludeInHeadersLinePattern/) {
	    my $extraIncludes = $1;
	    my @abbrevRefs = CleanSplit($extraIncludes, ",");
	    foreach(@abbrevRefs) {
		PrintIfVerboseMode("Register Extra TypeUsedInHeader $_\n");
		RegisterTypeUsedInHeader $_;
	    }
	} elsif ($_ =~ m/$extraIncludeInCppLinePattern/) {
	    my $extraIncludes = $1;
	    my @abbrevRefs = CleanSplit($extraIncludes, ",");
	    foreach(@abbrevRefs) {
		PrintIfVerboseMode("Register Extra TypeReferencedInHeader $_\n");
		RegisterTypesReferencedInHeader $_;
	    }
	} elsif ($_ =~ m/$classDefLineMatchStr/) {
	    $gClassName = $1;
	    TrimWhiteSpace(\$gClassName);
	    my @classParents = split(/\s*,\s*/, $2);
	    # ignore 'none'
	    @gClassParents = grep(!/^\s*none\s*$/, @classParents);
	    PrintIfVerboseMode("Parsed class name: $gClassName. Parsed class parents: ");
	    PrintIfVerboseMode("@gClassParents\n");
	    if (ArrayLength(\@gClassParents)) {
		my @resolvedParList = map RegisterTypeGivenVariableType($_), @gClassParents;
		@gClassParents = @resolvedParList;
	    }
	    last;
	}
    }

    # Register each line (including comments/space) until classmethods block is encountered
    my $classMethodsBlockStartMatchStr = "^ClassMethods {\\s*\$";
    my $classMembersBlockStartMatchStr = "^ClassMembers {\\s*\$";
    my $blockEndMatchStr = "^\\s*}\\s*\$";
    while(<$codeGenSpecFileHandle>) {
	chomp($_);
	my $lineStr = $_;
	if ($lineStr =~ m/($classMethodsBlockStartMatchStr)|($classMembersBlockStartMatchStr)/) {
	    my $isMethodsBlock = ($lineStr =~ m/$classMethodsBlockStartMatchStr/) ? 1 : 0;
	    # Parse each line of classmethods or classmembers block
	    while(<$codeGenSpecFileHandle>) {
		chomp($_);
		my $blockLineStr = $_;
		if (IsCommentOrSpace($blockLineStr)) {
		    # Add as is
		    RegisterBodyLineAndIndentation(\@gClassDefinitionBodyLines, \@gClassDefinitionBodyLinesIndentation, $blockLineStr, 2);
		} elsif ($blockLineStr =~ m/$blockEndMatchStr/) {
		    last;
		} else {
		    $isMethodsBlock ? ParseAndRegisterClassMethod($blockLineStr) : ParseAndRegisterClassMember($blockLineStr);
		}
	    }
	} elsif ($lineStr =~ m/$blockEndMatchStr/) {
	    last;
	} else {
	    RegisterBodyLineAndIndentation(\@gClassDefinitionBodyLines, \@gClassDefinitionBodyLinesIndentation, $lineStr, 2);
	}
    }

    GenerateCodeForClass;

}
