// DSOTestHelper.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"
#include <iostream>
#include <string>
#include <assert.h>
#include <stdlib.h>
#include <memory.h>
#include <vector>

#pragma warning(push)
#pragma warning(disable:4224)
#pragma warning(disable:4244)
#include <boost/filesystem.hpp>
#include <boost/program_options.hpp>
//#include <boost/python.hpp>
#pragma warning(pop)

namespace po = boost::program_options;
namespace fs = boost::filesystem;

// Purpose: 
//    - A tool to write data to disk with options to vary stress levels
//    - Future: Introduce some randomness in behavior
// Inputs: 
//    - Amount of data to write in MB
//    - Number of files to split above data into 
//      (note: due to latency, writing small files typically takes more real-time than writing same data as
//       one large file)
//    - Folder to use (note: this folder is in the current directory)
// Behavior:
//    - For ever,
//        - For each unit of data to IO,
//          - Create new file in given folder
//          - Write (Amount-of-data/NumberofFiles)
//          - Flush file
//          - Close file
//        - Delete all files

static int gOutputInMBPerSecond = 0;
static std::string gTargetFolder;
static int gNumOutputUnits = 0;

#if defined WIN32
  #include <direct.h>
	#define ANSOFT_GETCWD _getcwd
	#define ANSOFT_PUTENV _putenv
	#define ANSOFT_READ _read
	#define ANSOFT_CLOSE _close
	#define ANSOFT_CHDIR _chdir
	#define ANSOFT_SLEEP(x) _sleep(x)
	#define ANSOFT_MKDIR(name) _mkdir(name)
#else
	#include <unistd.h>
	#include <sys/types.h>
	#include <sys/stat.h>
	#define ANSOFT_GETCWD getcwd
	#define ANSOFT_PUTENV putenv
	#define ANSOFT_READ read
	#define ANSOFT_CLOSE close
	#define ANSOFT_CHDIR chdir
	#define ANSOFT_MKDIR(name) mkdir(name, 00755)
	#define _lfind lfind
	#define ANSOFT_SLEEP(x) usleep(x*1000)
#endif

static int WriteIntDataToFiles(const fs::path& outputFolderPath, const std::vector<std::string>& filesToWriteVec, size_t numBytesToWrite, int charToWrite) {
  assert(charToWrite >0 && charToWrite < 256);

  // Create output folder
  if (!fs::exists(outputFolderPath) && fs::create_directory(outputFolderPath) == false) {
    std::cerr << "Unable to create output folder '" << outputFolderPath.c_str() << "'!\n";
    return 2;
  }

  std::vector<std::string>::const_iterator iter;
  for (iter = filesToWriteVec.begin(); iter != filesToWriteVec.end(); ++iter)
  {
    const std::string& filePath = *iter;
    FILE* fp = ::fopen(filePath.c_str(), "w");
    static char* dataToWrite = 0;
    if (!dataToWrite) {
      std::cout << "Allocated buffer: " << numBytesToWrite << " bytes\n";
      dataToWrite = new char [numBytesToWrite];
      ::memset(dataToWrite, 1, numBytesToWrite);
    }
    size_t bytesWritten = ::fwrite(dataToWrite, sizeof(char), numBytesToWrite, fp);
    assert(bytesWritten == numBytesToWrite);
    ::fflush(fp);
    ::fclose(fp);
  }

  // Remove output folder
  if (fs::remove_all(outputFolderPath) <= 0) {
    std::cerr << "Unable to remove output folder '" << outputFolderPath.c_str() << "'!\n";
    return 3;
  }

	return 0;
}

int _tmain(int argc, _TCHAR* argv[])
{
  const int bufSize = 1024; // REVISIT hard coding
  char currWDBuf[bufSize]; 
  const char* chRet = ANSOFT_GETCWD(currWDBuf, bufSize);
  assert(chRet);

  std::string currWDStr = currWDBuf;

  po::options_description optionsDesc("Allowed Options");
  optionsDesc.add_options()
      ("help", "Print help messages") 
      ("outpersec", po::value<int>(&gOutputInMBPerSecond)->default_value(0), 
        "Specify the amount of data, in MB, to be written to disk every one second") 
      ("numfiles", po::value<int>(&gNumOutputUnits), "Specify the number of files to use")
      ("outfolder", po::value<std::string>(&gTargetFolder), "Specify the target folder to use, to create files"); 

  po::variables_map vm;

  po::store(po::wcommand_line_parser(argc, argv).options(optionsDesc).run(), vm);
  po::notify(vm);

  if (vm.count("help")) {
    std::cout << optionsDesc;
    return 0;
  }

  assert(gOutputInMBPerSecond > 0);
  assert(gTargetFolder.empty() == false);
  assert(gNumOutputUnits > 0);

  if (gOutputInMBPerSecond <= 0 || gTargetFolder.empty() == true || gNumOutputUnits <= 0) {
    std::cerr << "All three parameters must be specified on command-line!\n";
    return 255;
  }


  size_t numBytesToWrite = gOutputInMBPerSecond*1024*1024/gNumOutputUnits;

  std::string targetFolderFullPath = currWDStr + "/" + gTargetFolder + "/";
  fs::path outputFolderPath(targetFolderFullPath);

  // Make a list of file paths first
  // Directory is not needed for exclusive usage and can contain other user files. So give some random names
  std::vector<std::string> filesToWriteVec;
  const char* fileNamePrefix = "randomnamefortempio"; // give some randomname to avoid conflict with files created by user
  const char* fileNameExt = ".randext"; // give some randomname to avoid conflict with files created by user
  for (int ii = 0; ii < gNumOutputUnits; ++ii) {
    std::string intStr = std::to_string((size_t)ii);
    std::string filePath = targetFolderFullPath + fileNamePrefix + intStr + fileNameExt;
    filesToWriteVec.push_back(filePath);
  }

  while(1) {

    int retVal = WriteIntDataToFiles(outputFolderPath, filesToWriteVec, numBytesToWrite, 1);

    if (retVal) 
      return retVal;

    ANSOFT_SLEEP(1000); // sleep for 1 second
  }

  return 0;

}

