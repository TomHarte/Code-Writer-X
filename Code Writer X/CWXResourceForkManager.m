//
//  CWXResourceForkManager.m
//  Code Writer X
//
//  Created by Thomas Harte on 21/10/2012.
//  Copyright (c) 2012 Thomas Harte. All rights reserved.
//

#import "CWXResourceForkManager.h"
#import "CWXResource.h"
#include <sys/xattr.h>

/*

	Inside Macintosh: Volume 1 provides a description of the format
	of resource forks starting from Page 128; this code attempts to
	reimplement that description.

	It seeks to use a memory mapping where possible and makes use
	of the CoreFoundation byte order utilities in order to ensure
	the resource's big endian data is interpreted correctly.

*/

@implementation CWXResourceForkManager
{
	NSMutableArray *_resources;
}

+ (id)resourceForkManagerWithResourceForkOfFileAtPath:(NSString *)path
{
	return [[[self alloc] initWithFileAtPath:path] autorelease];
}

+ (id)resourceForkManagerWithResourceForkData:(NSData *)data
{
	return [[[self alloc] initWithResourceForkData:data] autorelease];
}

+ (id)resourceForkManagerWithDataForkOfFileAtPath:(NSString *)path
{
	NSError *error = nil;
	NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:&error];

	if(error) return nil;

	return [[[self alloc] initWithResourceForkData:data] autorelease];
}

- (id)initWithResourceForkData:(NSData *)data
{
	self = [super init];

	if(self)
	{
		[self createResourcesWithData:data];
	}

	return self;
}

- (id)initWithFileAtPath:(NSString *)path
{
	self = [super init];

	if(self)
	{
		// get C-style strings for the file name and the extended attribute we're interested in
		// (ie, the resource fork)
		const char *fileSystemPath = [path fileSystemRepresentation];
		const char *extendedAttribute = "com.apple.ResourceFork";

		// use getxattr to query the size of the resource fork and then to load the whole
		// thing into memory
		ssize_t bufferLength = getxattr(fileSystemPath, extendedAttribute, NULL, 0, 0, 0);

		if(bufferLength < 0)
		{
			[self release];
			return nil;
		}

		uint8_t *rawData = (uint8_t *)malloc(bufferLength);
		bufferLength = getxattr(fileSystemPath, extendedAttribute, rawData, bufferLength, 0, 0);

		// convert that into an NSData (handing over ownership of our malloc'd memory
		// while we do it)
		NSData *data = [NSData dataWithBytesNoCopy:rawData length:bufferLength];

		// parse that into resources
		[self createResourcesWithData:data];
	}

	return self;
}

- (void)createResourcesWithData:(NSData *)data
{
	// ensure the accesses we're about to make are definitely legal
	if([data length] < 16) return;

	// the following four things are stored in the order declared,
	// in big endian format
	uint32_t offsetToResourceData;
	uint32_t offsetToResourceMap;
	uint32_t lengthOfResourceData;
	uint32_t lengthOfResourceMap;

	// we'll use the CoreFoundation byte order utilities rather than
	// effectively reimplementing them
	const uint32_t *dataBytes = [data bytes];
	offsetToResourceData = CFSwapInt32BigToHost(dataBytes[0]);
	offsetToResourceMap = CFSwapInt32BigToHost(dataBytes[1]);
	lengthOfResourceData = CFSwapInt32BigToHost(dataBytes[2]);
	lengthOfResourceMap = CFSwapInt32BigToHost(dataBytes[3]);

	if(
		(offsetToResourceData + lengthOfResourceData) <= [data length] &&
		(offsetToResourceMap + lengthOfResourceMap) <= [data length])
	{

		[self createResourcesWithData:[data subdataWithRange:NSMakeRange(offsetToResourceData, lengthOfResourceData)]
			map:[data subdataWithRange:NSMakeRange(offsetToResourceMap, lengthOfResourceMap)]];
	}
}

- (void)createResourcesWithData:(NSData *)data map:(NSData *)map
{
	[_resources release];
	_resources = [[NSMutableArray alloc] init];

	// start by getting the type and name offsets
	const uint16_t *map16 = [map bytes];
	const uint8_t *data8 = [data bytes];

	uint16_t offsetToTypeList = CFSwapInt16BigToHost(map16[12]);
	uint16_t offsetToNameList = CFSwapInt16BigToHost(map16[13]);

	// now generate the resource type strings
	const uint8_t *nameList = (const uint8_t *)((const uint8_t *)map16 + offsetToNameList);
	const uint16_t *typeList = (const uint16_t *)((const uint8_t *)map16 + offsetToTypeList);
	uint16_t numberOfTypes = CFSwapInt16BigToHost( typeList[0]);
	
	const uint16_t *typeListPointer = typeList + 1;

	for(int type = 0; type <= numberOfTypes; type++)
	{
		// read the four-byte resource type
		uint32_t type = CFSwapInt32BigToHost(*(uint32_t *)typeListPointer);
		uint16_t numberOfResources = CFSwapInt16BigToHost(typeListPointer[2]);
		uint16_t offsetIntoResourceList = CFSwapInt16BigToHost(typeListPointer[3]);
		typeListPointer += 4;

		const uint8_t *resourceList = (const uint8_t *)((const uint8_t *)typeList + offsetIntoResourceList);
		for(int resource = 0; resource <= numberOfResources; resource++)
		{
			uint16_t resourceID = CFSwapInt16BigToHost(*(uint16_t *)resourceList);
			uint16_t offsetToResourceName = CFSwapInt16BigToHost(*(uint16_t *)&resourceList[2]);
			uint8_t resourceAttributes = resourceList[4];
			uint32_t offsetToResourceData = resourceList[7] | (resourceList[6] << 8) | (resourceList[5] << 16);

			resourceList += 12;

			// get the name
			uint8_t lengthOfName = nameList[offsetToResourceName];
			NSString *name = [[NSString alloc] initWithBytes:&nameList[offsetToResourceName+1] length:lengthOfName encoding:NSMacOSRomanStringEncoding];

			// get the data
			const uint8_t *startOfData = &data8[offsetToResourceData];
			uint32_t lengthOfData = CFSwapInt32BigToHost(*(uint32_t *)startOfData);
			NSData *resourceData = [data subdataWithRange:NSMakeRange(offsetToResourceData+4, lengthOfData)];

			CWXResource *newResource = [CWXResource resourceWithName:name type:type attributes:resourceAttributes resourceID:resourceID data:resourceData];
			[_resources addObject:newResource];
			[name release];
		}
	}
}

@end
