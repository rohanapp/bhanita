use strict;
use lib "..\\Lib";
use Cwd;
use Getopt::Long;
use File::Copy;
use Win32::Clipboard;
use GlobUtils;
use CodeGen;

# NOTE REVISIT
# Parameters to this script can only be changed by making below changes

# my $gClassName = "DJobServiceStatusBlockObject";
# my @gNamedPropNames = ("TotalChildJobs", "NumJobsRunning");
# my @gNamedPropValue = ("-1", "-1");

my $gClassName = "DJobTaskStatusBlockObject";
my @gNamedPropNames = ("TotalTasksForFullJob", "NumTasksDoneSuccess", "NumTasksDoneError", "StartTaskGlobalIndex", 
		       "EndTaskGlobalExclIndex", "ErrorStrs");
my @gNamedPropValue = ("-1", "-1", "-1", "-1", "-1", "");

# my $gClassName = "LargeDSOTaskStats";
# my @gNamedPropNames = ("Total", "Owned", "StartIdx", "EndIdx");
# my @gNamedPropValue = ("-1", "-1", "-1", "-1");

#my $gClassName = "NgAppCmdInteractionProgramParameters";
#my @gNamedPropNames = ("Program", "ProgOptions", "EngineIndex", "IsInterrupt", "IsAbort", "InputProj");
#my @gNamedPropValue = ("", "", "0", "false", "false", "");

# my $gClassName = "NgAppCommandDef";
# my @gNamedPropNames = ("OverallFirstTaskFolder", "IsOverallFirstTask", "FirstSiblingFolder", "RootWorkDir", "LocalWorkDir");
# my @gNamedPropValue = ("", "true", "", "", "");

#my $gClassName = "NgAppServiceCommandlineParameters";
#my @gNamedPropNames = ("ProgOptions", "CommandDef", "CommandParams");
#my @gNamedPropValue = ("block", "block", "block");

#my $gClassName = "NgAppProgramOptions";
#my @gNamedPropNames = ("DistribMachines", "IsNonGraphical", "WaitForLicense", "MP", "IdleCores", "PreserveDistribFiles");
#my @gNamedPropValue = ("", "true", "false", "1", "0", "false");

#my @gNamedPropNames = ("CommandName", "Monitor", "LogFile", "BatchOptions", "EnvVars", "WorkDir", "JobID", "JobFolder", "ProdName", "ProdVersion");
#my @gNamedPropValue = ("dso", "true", "", "", "", "", "", "", "", "");

#my $gClassName = "LargeDSOCommandParams";
#my @gNamedPropNames = ("DistribMachines", "IsNonGraphical", "WaitForLicense", "MP", "IdleCores", "SolveSetupName", "ProjectPath");
#my @gNamedPropValue = ("", "true", "false", "1", "0", "", "");

#my $gClassName = "NgAppCommandDef";
#my @gNamedPropNames = ("DistributedNodes", "UniqueNodes", "UniqNodeCores");
#my @gNamedPropValue = ("", "", "");
#my @gNamedPropNames = ("Name", "DistributionLevel", "SiblingRank", "SiblingCount", "TotalWorkUnits", "StartUnit", "EndUnit");
#my @gNamedPropValue = ("dso", "0", "0", "0", "0", "0", "0");



my $gClassNameFile = $gClassName;
my $gOutputFilesDir = "d:/programs/perl_scripts/codegentempls";

my $gVerbose = 1;

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

$sep
EOU__
exit(1);
}

sub PrintIfVerbose
{
    if ($gVerbose) {
	print("$_[0] $_[1]\n");
    }
}

# Inputs: file handle, abbrev-typelist
sub BlindlyWriteIncludeDirectivesToFile
{
    my ($fileHandle, @typesToInclude) = @_;
    foreach(@typesToInclude) {
	my $includeRefStr = CodeGen::GetIncludeReferencesOfAbbrevType($_);
	# print "GetIncludeReferencesOfAbbrevType '$_' returned '$includeRefStr'\n";
	$includeRefStr = CodeGen::GetIncludeReferencesOfUtility($_) unless (defined $includeRefStr);
	if (defined $includeRefStr) {
	    my $includeDirective = @{$includeRefStr}[0];
	    print $fileHandle "#include \"$includeDirective\"\n";
	}
    }
}

my @gStandardHeaderIncludes = ("ngappexports", "portab", "wintypes", "assert", "platform_specifics");
my @gStandardSrcIncludes = ("ansdebug", "msgmgr", "msg");

sub WriteStandardIncludesToHeaderFile
{
    BlindlyWriteIncludeDirectivesToFile($_[0], @gStandardHeaderIncludes);
}

sub WriteStandardIncludesToCppFile
{
    my $fileHandle = $_[0];
    print $fileHandle "#include \"headers" . ".h\"\n";
    print $fileHandle "#include \"$gClassName" . ".h\"\n";
    BlindlyWriteIncludeDirectivesToFile($_[0], @gStandardSrcIncludes);
}

my @gStringConstantDefines;
my @gnamedValInitStrs;
my @gAccessorDefs;
my @gAccessorImpls;

sub WriteAccessorsToHeader
{
    my $filehh = $_[0];
    foreach(@gAccessorDefs) {
	print $filehh "  $_\n";
    }
}

sub WriteAccessorsToCpp
{
    my $filehh = $_[0];
    foreach(@gAccessorImpls) {
	print $filehh "$_\n";
    }
}

sub is_num {
    my($cand) = shift;

    my $not_num;
    local $^W = 1;
    local $SIG{__WARN__} = sub {
        $not_num = $_[0] =~ /^Argument ".*?" isn't numeric/;
    };

    () = $cand + 0;
    return !$not_num;
}

sub PrintMyList
{
    my @ll = @_;
    foreach(@ll) {
	print "$_\n";
    }
}

sub GetNamedValueTypeDetails
{
    my $val = $_[0];
    my $isNum = 0;
    my $isBool = 0;
    my $retType = "AString";
    if (is_num($val)) {
	$retType = "int";
	$isNum = 1;
    } elsif ($val =~ m/(^false$)|(^true$)/) {
	$retType = "bool";
	$isBool = 1;
    }
    return ($isNum, $isBool, $retType);
}

sub GetStringConstantForPropName { "k" . $_[0] . "Str"; }

sub GenerateNameValueConstructorArguments
{
    my $ii = 0;
    foreach(@gNamedPropNames) {
	my $nam = $_;
	my $val = $gNamedPropValue[$ii];

	my ($isNum, $isBool, $retType) = GetNamedValueTypeDetails($val);

	my $valStr = "ACHAR(\"$val\")";
	if ($isNum || $isBool) {
	    $valStr = "Value($val)";
	}
	my $stringConstantVar = GetStringConstantForPropName($nam);
	push @gStringConstantDefines, "static const AChar* " . $stringConstantVar . " = ACHAR(\"$nam\");";
	push @gnamedValInitStrs, $stringConstantVar . ", $valStr";
	$ii++;
    }
}

sub GenerateAccessorsForProps
{
    my $ii = 0;
    foreach(@gNamedPropNames) {
	my $nam = $_;
	my $val = $gNamedPropValue[$ii];

	my ($isNum, $isBool, $retType) = GetNamedValueTypeDetails($val);
	push @gAccessorDefs, "$retType " . "Get" . $nam . "Prop() const;";
	push @gAccessorImpls, "$retType " . "$gClassName" . "::" . "Get" . $nam . "Prop() const";
	push @gAccessorImpls, "{";
	push @gAccessorImpls, "  const ValueBase* vb = m_namedProps.GetPropertyValue(" . GetStringConstantForPropName($nam) . ");";
	push @gAccessorImpls, "  SS_ASSERT(vb);";
	push @gAccessorImpls, "  if (!vb)";
	push @gAccessorImpls, ($isNum ? "    return -1;" 
			       : "    return ACHAR(\"\");");
	push @gAccessorImpls, ($isBool ? "  return vb->GetIntValue() ? true : false;" :
			       ($isNum ? "  return vb->GetIntValue();"
				: "  return ValueUtil::GetStringInsideQuotes(vb->GetStringValue());"));
	push @gAccessorImpls, "}";
	push @gAccessorImpls, "";
	
	$ii++;
    }

}

sub GenerateSettersForProps
{
    my $ii = 0;
    push @gAccessorDefs, "";
    foreach(@gNamedPropNames) {
	my $nam = $_;
	my $val = $gNamedPropValue[$ii];

	my ($isNum, $isBool, $fooIgnore) = GetNamedValueTypeDetails($val);
	my $retType = "bool";
	
	my $valArg = "const AString& val";
	if ($isNum) {
	    $valArg = "int val";
	}
	if ($isBool) {
	    $valArg = "bool val";
	}
	push @gAccessorDefs, "$retType " . "Set" . $nam . "PropVal($valArg);";
	push @gAccessorImpls, "$retType " . "$gClassName" . "::" . "Set" . $nam . "PropVal($valArg)";
	push @gAccessorImpls, "{";
	if ($isNum || $isBool) {
	    push @gAccessorImpls, "  bool retVal = m_namedProps.SetPropertyValue(" . GetStringConstantForPropName($nam) . ", Value(val));";
	} else {
	    push @gAccessorImpls, "  bool retVal = m_namedProps.SetPropertyValue(" . GetStringConstantForPropName($nam) . ", val);";
	}
	push @gAccessorImpls, "  SS_ASSERT(retVal);";
	push @gAccessorImpls, "  return retVal;";
	push @gAccessorImpls, "}";
	push @gAccessorImpls, "";
	
	$ii++;
    }
    push @gAccessorDefs, "";

}

sub WriteNamedPropHeaderCppFiles
{
    GenerateNameValueConstructorArguments;
    GenerateAccessorsForProps;
    GenerateSettersForProps;

    PrintMyList @gnamedValInitStrs;
    PrintMyList @gAccessorDefs;
    PrintMyList @gAccessorImpls;

    # header file
    my $classHeaderFileName = MakeFilePathFromComponents($gOutputFilesDir, $gClassNameFile, ".h");
    my $classHeaderHandle;
    open($classHeaderHandle, ">$classHeaderFileName") or die "Unable to open file '$classHeaderFileName' for writing";

    CodeGen::PrintCopyRightCommentToHeaderFile($classHeaderHandle);
    print $classHeaderHandle "#ifndef _" . uc($gClassName) . "_H\n";
    print $classHeaderHandle "#define _" . uc($gClassName) . "_H\n";
    print $classHeaderHandle "\n";

    WriteStandardIncludesToHeaderFile($classHeaderHandle);
    print $classHeaderHandle "#include \"ngcore/streamio/streamio_object.h\"\n";
    print $classHeaderHandle "#include \"ngcore/streamio/errorConstants.h\"\n";
    print $classHeaderHandle "#include \"ngcore/stringutils/astring.h\"\n";
    print $classHeaderHandle "#include \"NgAnsoftCOMApp/GenericNamedPropertiesObject.h\"\n";

    print $classHeaderHandle "\n";

    print $classHeaderHandle "class io::CBlock;\n";


    print $classHeaderHandle "\n";

    # Class definition line
    print $classHeaderHandle "class NGANSOFTCOMAPP_API $gClassName";
    print $classHeaderHandle " : ";
    print $classHeaderHandle "public io::CStreamio_block_object\n";
    print $classHeaderHandle "{\n";

    print $classHeaderHandle "\n";
   
    print $classHeaderHandle "public:\n";
    print $classHeaderHandle "\n";

    my $indentStr = " "x2;
  
    print $classHeaderHandle $indentStr . "$gClassName();\n";
    print $classHeaderHandle $indentStr . "~$gClassName();\n";
    print $classHeaderHandle "\n";

    WriteAccessorsToHeader($classHeaderHandle);

    print $classHeaderHandle $indentStr . "virtual io::ReadError DoDataExchange(io::CBlock& block, bool do_read);\n";
    print $classHeaderHandle $indentStr . "virtual AString GetItemName() const;\n";
    print $classHeaderHandle "\n";
  
    print $classHeaderHandle "private:\n";
    print $classHeaderHandle "\n";
  
    print $classHeaderHandle $indentStr . "void InitiliazeObjectPropertySpec();\n";
    print $classHeaderHandle "\n";

    print $classHeaderHandle $indentStr . "GenericNamedPropertiesObject m_namedProps;\n";
    print $classHeaderHandle "\n";
  
    print $classHeaderHandle "};\n";
    print $classHeaderHandle "\n";
    print $classHeaderHandle "#endif\n";

    # cpp file
    my $classSrcFileName = MakeFilePathFromComponents($gOutputFilesDir, $gClassNameFile, ".cpp");
    my $classSrcHandle;
    open($classSrcHandle, ">$classSrcFileName") or die "Unable to open file '$classSrcFileName' for writing";
    WriteStandardIncludesToCppFile($classSrcHandle);

    print $classSrcHandle "#include \"ngcore/ngutils/ans_debug.h\"\n";
    print $classSrcHandle "#include \"CoreInterfaces/IMessageManager.h\"\n";
    print $classSrcHandle "#include \"ngcore/messagelibni/AnsoftMessage.h\"\n";
    print $classSrcHandle "#include \"ngcore/streamio/block.h\"\n";
    print $classSrcHandle "#include \"ngcore/value/ValueUtil.h\"\n";
    print $classSrcHandle "\n";

    foreach(@gStringConstantDefines) {
	print $classSrcHandle "$_\n";
    }
    print $classSrcHandle "\n";

    print $classSrcHandle "$gClassName" . "::" . "$gClassName()\n";
    print $classSrcHandle ": m_namedProps(ACHAR(\"$gClassName\"))\n";
    print $classSrcHandle "{\n";
    print $classSrcHandle "  InitiliazeObjectPropertySpec();\n";
    print $classSrcHandle "}\n";
    print $classSrcHandle "\n";

    print $classSrcHandle "$gClassName" . "::" . "~$gClassName()\n";
    print $classSrcHandle "{\n";
    print $classSrcHandle "}\n";
    print $classSrcHandle "\n";

    WriteAccessorsToCpp($classSrcHandle);
    print $classSrcHandle "\n";

    print $classSrcHandle "io::ReadError " . "$gClassName" . "::" . "DoDataExchange(io::CBlock& block, bool do_read) \n";
    print $classSrcHandle "{\n";
    print $classSrcHandle "  return m_namedProps.DoDataExchange(block, do_read);\n";
    print $classSrcHandle "}\n";
    print $classSrcHandle "\n";

    print $classSrcHandle "AString " . "$gClassName" . "::" . "GetItemName() const\n";
    print $classSrcHandle "{\n";
    print $classSrcHandle "  return m_namedProps.GetItemName();\n";
    print $classSrcHandle "}\n";
    print $classSrcHandle "\n";

    print $classSrcHandle "void $gClassName" . "::" . "InitiliazeObjectPropertySpec()\n";
    print $classSrcHandle "{\n";
    foreach(@gnamedValInitStrs) {
	print $classSrcHandle "  m_namedProps.InitializePropertySpec($_);\n";
    }
    print $classSrcHandle "}\n";
    print $classSrcHandle "\n";

    # Flush the generated files
    close($classHeaderHandle);
    close($classSrcHandle);

    # copy header, cpp files to another file with a constant name
    copy($classHeaderFileName, "NamedProps.h") or die "Unable to copy $classHeaderFileName to header.h";
    copy($classSrcFileName, "NamedProps.cpp") or die "Unable to copy $classHeaderFileName to header.h";
}

sub CreateNamedObjectHeaderToClipboard
{
  
    my $numIndentSpaces = 2;
    my $indentStr = " "x$numIndentSpaces;

    my $clippedText = Win32::Clipboard::GetText();

    my @numLines = split("\n", $clippedText);
    my $ii=0;
    foreach(@numLines) {
	$_ =~ m/(\w+)=(\w+)/;
	print "Name = $1, Value = $1\n";
    }

    WriteNamedPropHeaderCppFiles
    #return \@codeLines;
    #CopyStringsToClipboard(@codeLinesArray);
}
  
sub GenerateSTLMapIterCodeToClipboard
{
    my $numIndentSpaces = 2;
    my $indentStr = " "x$numIndentSpaces;

    my $clippedText = Win32::Clipboard::GetText();
    print "Found text on cipboard: $clippedText\n";

    # Code lines should be generated in these
    my @codeLinesArray;

    my ($typeOfElem1, $typeOfElem2, $containerName);
    my $pairContainerpattern = "\\s*(.+)\\s*,\\s*(.+)\\s*,\\s*(.+)";
    if ($clippedText =~ m/$pairContainerpattern/) {

	($typeOfElem1, $typeOfElem2, $containerName) = 
	    ($clippedText =~ m/$pairContainerpattern/);
	print "Type of element1: $typeOfElem1, Type of element2: $typeOfElem2, " .
	    "Container name: $containerName\n";

	my $codeLinesRef;
	$codeLinesRef = MapIterationToClipboard($typeOfElem1, $typeOfElem2, $containerName);

	@codeLinesArray = map "$_" . $indentStr, @{$codeLinesRef};

	CopyStringsToClipboard(@codeLinesArray);
	return;
    }

    die "Unable to interpret and generate code for text '$clippedText'";
}

MAIN:
{
    GetOptions("verbose" => \$gVerbose) or 
	die usage("Incorrect Usage");

    CodeGen::InitializeCodeGenDatabases;
    CreateNamedObjectHeaderToClipboard;


    print ("Verbose flag is: $gVerbose\n");


}
