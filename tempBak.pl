use strict;
use File::Glob;
use Getopt::Long;
use DateTime;
use GlobUtils;
use CodeGen;

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

sub TestParsingOfDeclarations
{
    my @checkDecl = ("  char** & argv ", "msgmgr* f", "const A& const varName", "void v", " MessageSeverity severity ",
		     " const AnsoftCommandContext* context", "int i1", " const int remainingMsg");
    
    foreach(@checkDecl) {
	print "\nDeclaration: $_\n";
	my ($tFullName, $varName) = CodeGen::SplitVariableDeclarationIntoTypeWModAndName($_);
	my $tBareName = CodeGen::GetTypeNameExclModifiers($tFullName);
	print "Type name = $tFullName, Typename without modifiers = $tBareName, Var name = $varName\n";
    }
}

sub TestIsTypeAPointerOrReference
{
    my @checkDecl = ("  char** & argv ", "msgmgr* f", "const A& const varName", "void v", " MessageSeverity severity ",
		     " const AnsoftCommandContext* context", "lfn ", "lfn &*boo", " const int remainingMsg");

    foreach(@checkDecl) {
	print "\nDeclaration: $_\n";
	print "TestIsTypeAPointerOrReference: ";
	CodeGen::IsTypeAPointerOrReference($_) ? print "true" : print "false";
	print "\n";
    }
}

# TestUniqueNonStandardTypes(qw(int char A B lfn A AB CD AB lfn))
sub TestUniqueNonStandardTypes
{
    my @lst = UniqueNonStandardTypes(@_);
    print "TestUniqueNonStandardTypes: @lst\n";
}

sub TestRegisterTypesReferencedInHeader
{
    my @lst = qw(int char A msgmgr B lfn A AB CD msgmgr AB lfn);
    # push @lst, "int*";
    foreach(@lst) {
	RegisterTypesReferencedInHeader($_);
    }
    print "TestRegisterTypesReferencedInHeader: @gHeaderFileForwardDeclarations\n";
}

sub TestRegisterTypeUsedInHeader
{
    my @lst = qw(int char A msgmgr B lfn A AB CD msgmgr AB lfn);
    # push @lst, "int*";
    foreach(@lst) {
	RegisterTypeUsedInHeader($_);
    }
    print "TestRegisterTypeUsedInHeader: @gHeaderFileIncludeReferences\n";
}

sub TestWriteIncludeDirectivesToFile
{
    TestRegisterTypeUsedInHeader;
    my $fileHandle = \*STDOUT;
    WriteIncludeDirectivesToFile($fileHandle, @gHeaderFileIncludeReferences);

    print "Testing types referenced in header that should be included in cpp...\n";
    TestRegisterTypesReferencedInHeader;
    WriteIncludeDirectivesToFile($fileHandle, @gClassImplIncludeFileReferences);
    
}

sub TestWriteForwardDeclarationsToFile
{
    TestRegisterTypesReferencedInHeader;
    my $fileHandle = \*STDOUT;
    WriteForwardDeclarationsToFile($fileHandle, @gHeaderFileForwardDeclarations);
}

#    my @fArgs = ("const lfn& ff", "int a1", "const void* ptr");
sub TestCompositionOfMethodDeclFromParts
{
    my $gClassName = "CAnsoftCOMNgApplication";
    my ($methodReturnPart, $methodName, $methodArgsRef, $methodModifiersPart, $methodBodyPart) = @_;
    my $methodArgsStr = join(", ", @{$methodArgsRef});
    my $headerLine = join(" ", ($methodReturnPart, $methodName . "(" . $methodArgsStr . ")", 
				$methodModifiersPart . ";"));
    # "= 0" must be stripped from pure virtual method line
    my $modifiersNoPV = GetFirstWordStripAll($methodModifiersPart);
    my $srcLine = join(" ", ($methodReturnPart, $gClassName . "::" . $methodName . "(" . $methodArgsStr . ")", 
			     $modifiersNoPV));
    print "TestCompositionOfMethodDeclFromParts:\n";
    print "$headerLine\n";
    print "$srcLine\n";

    my @utilitiesNeeded = CleanSplit($methodBodyPart, ",");
    my @srcUtilityLines;
    foreach(@utilitiesNeeded) {
	my $utilSrcCode = CodeGen::GetSourceCodeForUtility($_);
	next unless (defined $utilSrcCode);
	map push (@srcUtilityLines, $_), @{$utilSrcCode};
    }
    print "Src utility lines:\n";
    print @srcUtilityLines;

}

sub TestRegisterBodyLineAndIndentation
{
    my @array1;
    my @array2;
    RegisterBodyLineAndIndentation(\@array1, \@array2, "line1", 0);
    RegisterBodyLineAndIndentation(\@array1, \@array2, "line1_indent1", 2);
    RegisterBodyLineAndIndentation(\@array1, \@array2, "line1_indent2", 4);
    RegisterBodyLineAndIndentation(\@array1, \@array2, "line2", 0);
    RegisterBodyLineAndIndentation(\@array1, \@array2, "line2_indent2", 2);

    print "\n\n";
    print "@array1\n";
    print "@array2\n";
}

MAIN:
{
    # Sample: "const msgmgr* InitializeApplication(const lfn& ff) const {fileexists}"
    # Sample: "const msgmgr& CustomInitializeApplication() const = 0 {}"
    my $verbose = 0;
    GetOptions("verbose" => \$verbose) or Usage("Incorrect command-line");
    SetVerboseMode($verbose);

    CodeGen::InitializeCodeGenDatabases;

    TestRegisterTypeGivenVariableDeclaration;

    my $sampStr = "const msgmgr* InitializeApplication() const {fileexists}";
    #my $sampStr = "const msgmgr& CustomInitializeApplication() const = 0 {}";

    my $currIndent = 2;

    my @gClassParents = ( "foo" );
    if (ArrayLength(\@gClassParents)) {
	my $parentsStr = join(", ", map { "public " . $_; } @gClassParents);
    }
}
