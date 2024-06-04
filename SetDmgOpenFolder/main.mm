//  main.mm
//  
//
//  Created by James Walker on 6/3/24.
//  
//

/*
	Copyright (c) 2024 James W. Walker

	This software is provided ‘as-is’, without any express or implied
	warranty. In no event will the authors be held liable for any damages
	arising from the use of this software.

	Permission is granted to anyone to use this software for any purpose,
	including commercial applications, and to alter it and redistribute it
	freely, subject to the following restrictions:

	1. The origin of this software must not be misrepresented; you must not
	claim that you wrote the original software. If you use this software
	in a product, an acknowledgment in the product documentation would be
	appreciated but is not required.

	2. Altered source versions must be plainly marked as such, and must not be
	misrepresented as being the original software.

	3. This notice may not be removed or altered from any source
	distribution.
 */

#include <iostream>
#include <iomanip>

#include <sys/attr.h>
#include <stdint.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <string>
#include <optional>
#include <utility>

#include <Foundation/Foundation.h>

typedef std::pair< std::string, bool > PathAndVerboseFlag;

struct InfoBuf
{
	uint32_t	length;
	uint8_t		finderInfo[32];
} __attribute__((aligned(4), packed));


static void Stream4BytesAsHex( std::ostream& stream, const uint8_t* bytes )
{
	stream << std::hex << std::setfill( '0' ) << std::uppercase <<
		std::setw(2) << (unsigned int) bytes[0] <<
		std::setw(2) << (unsigned int) bytes[1] <<
		std::setw(2) << (unsigned int) bytes[2] <<
		std::setw(2) << (unsigned int) bytes[3] << ' ';
}

static std::ostream& operator<<( std::ostream& stream, const InfoBuf& info )
{
	for (int i = 0; i < 8; ++i)
	{
		Stream4BytesAsHex( stream, &info.finderInfo[ 4 * i ] );
	}
	
	return stream;
}

static std::optional< PathAndVerboseFlag >
GetArgs( int argc, const char * argv[] )
{
	std::optional< PathAndVerboseFlag > result;
	
	PathAndVerboseFlag pathAndFlag;
	if (argc == 2)
	{
		pathAndFlag.second = false;
		pathAndFlag.first = argv[1];
		if (pathAndFlag.first != "--verbose")
		{
			result = pathAndFlag;
		}
	}
	else if (argc == 3)
	{
		if (std::string(argv[1]) == "--verbose")
		{
			pathAndFlag.second = true;
			pathAndFlag.first = argv[2];
			result = pathAndFlag;
		}
	}
	
	return result;
}


int main( int argc, const char * argv[] )
{
	std::optional< PathAndVerboseFlag > theArgs( GetArgs( argc, argv ) );
	
	if ( ! theArgs.has_value() )
	{
		std::cerr << "Wrong number of arguments.\nUsage:\n\n" <<
			"SetOpenFolder [--verbose] path-to-folder\n\n" <<
			"Make a folder on a read-write disk image automatically\n" <<
			"open as a Finder window when the image mounts.\n";
		return 1;
	}
	
	std::string path( theArgs->first );
	bool beVerbose = theArgs->second;
	
	// Find the path to the root directory of the volume
	NSURL* givenURL = [NSURL fileURLWithPath: @(path.c_str())];
	NSURL* rootURL = nil;
	[givenURL getResourceValue: &rootURL forKey: NSURLVolumeURLKey error: nil];
	const char* rootPath = rootURL.filePathURL.path.UTF8String;
	
	// Get iNode number of the folder, and verify that it is a folder.
	struct stat statInfo;
	int result = stat( path.c_str(), &statInfo );
	if (result != 0)
	{
		std::cerr << "Error " << errno << " getting information about " <<
			path << ".\n";
		return 2;
	}
	if ( (statInfo.st_mode & S_IFDIR) == 0 )
	{
		std::cerr << "The path " << path << " is not a directory.\n";
		return 3;
	}
	if (beVerbose)
	{
		std::cout << "iNode number of directory is " << statInfo.st_ino << '\n';
	}
	
	// Get current Finder info of the volume.
	attrlist whichAttrs;
	memset( &whichAttrs, 0, sizeof(whichAttrs) );
	whichAttrs.bitmapcount = ATTR_BIT_MAP_COUNT;
	whichAttrs.commonattr = ATTR_CMN_FNDRINFO;
	// Using ATTR_VOL_INFO means that we will access the Finder info of the
	// volume itself, not its root directory.
	whichAttrs.volattr = ATTR_VOL_INFO;
	InfoBuf info;
	result = getattrlist( rootPath, &whichAttrs, &info, sizeof(info), 0 );
	if (result != 0)
	{
		std::cerr << "Error " << errno << " getting Finder info.\n";
		return 4;
	}
	if (info.length != sizeof(InfoBuf))
	{
		std::cerr << "Unexpected length " << (info.length - 4) << " of Finder info.\n";
		return 5;
	}
	if (beVerbose)
	{
		std::cout << "Old Finder info: " << info << '\n';
	}
		
	// Stick the inode into the Finder info, as a bigendian 16-bit number.
	// NOTE: this uses undocumented information about the Finder info that
	// was deduced by experimentation.
	uint16_t inodeBE = NSSwapHostShortToBig( (uint16_t) statInfo.st_ino );
	memcpy( &info.finderInfo[10], &inodeBE, 2 );
	if (beVerbose)
	{
		std::cout << "New Finder info: " << info << '\n';
	}
	
	// Try to update the volume info.
	// Note that setattrlist differs from getattrlist in not wanting the
	// length value at the beginning of the buffer.
	result = setattrlist( rootPath, &whichAttrs, &info.finderInfo,
		sizeof(info.finderInfo), 0 );
	if (result != 0)
	{
		std::cerr << "Error " << errno << " setting Finder info.\n";
		return 6;
	}
	
	std::cout << "Done.\n";

	return 0;
}
