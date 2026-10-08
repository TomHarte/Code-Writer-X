//
//  CWXResourceForkManager.m
//  Code Writer X
//
//  Created by Thomas Harte on 21/10/2012.
//  Copyright (c) 2012 Thomas Harte. All rights reserved.
//

#import "NSArray+ResourceForks.h"
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

@implementation NSArray (ResourceForks)

+ (nullable NSArray <CWXResource *> *)resourcesFromResourceForkOfFileAtPath:(NSString *)path {
	// Get C-style strings for the file name and the extended attribute we're interested in
	// (ie, the resource fork)
	const char *const fileSystemPath = path.fileSystemRepresentation;
	const char *const extendedAttribute = "com.apple.ResourceFork";

	// Use getxattr to query the size of the resource fork and then to load the whole
	// thing into memory.
	ssize_t bufferLength = getxattr(fileSystemPath, extendedAttribute, NULL, 0, 0, 0);
	if(bufferLength < 0) {
		return nil;
	}

	uint8_t *const rawData = (uint8_t *)malloc(bufferLength);
	bufferLength = getxattr(fileSystemPath, extendedAttribute, rawData, bufferLength, 0, 0);

	// Convert that into an NSData, handing over ownership of the malloc'd memory.
	NSData *const data = [NSData dataWithBytesNoCopy:rawData length:bufferLength];

	// Parse.
	return [self resourcesFromData:data];
}

+ (nullable NSArray <CWXResource *> *)resourcesFromDataForkOfFileAtPath:(NSString *)path {
	NSError *error = nil;
	NSData *const data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:&error];

	return error ? nil : [self resourcesFromData:data];
}

+ (nullable NSArray <CWXResource *> *)resourcesFromData:(NSData *)data {
	// Ensure accesses below are legal.
	if(data.length < 16) return nil;

	// Read resource definitions.
	const uint32_t *const dataBytes = data.bytes;
	const uint32_t offsetToResourceData	= CFSwapInt32BigToHost(dataBytes[0]);
	const uint32_t offsetToResourceMap	= CFSwapInt32BigToHost(dataBytes[1]);
	const uint32_t lengthOfResourceData	= CFSwapInt32BigToHost(dataBytes[2]);
	const uint32_t lengthOfResourceMap	= CFSwapInt32BigToHost(dataBytes[3]);

	if(
		(offsetToResourceData + lengthOfResourceData) <= data.length &&
		(offsetToResourceMap + lengthOfResourceMap) <= data.length)
	{
		return [self
			createResourcesWithData:[data subdataWithRange:NSMakeRange(offsetToResourceData, lengthOfResourceData)]
			map:[data subdataWithRange:NSMakeRange(offsetToResourceMap, lengthOfResourceMap)]
		];
	}

	return nil;
}

+ (nullable NSArray <CWXResource *> *)createResourcesWithData:(NSData *)data map:(NSData *)map {
	NSMutableArray <CWXResource *> *const resources = [[NSMutableArray alloc] init];

	// Get type and name offsets.
	const uint16_t *const map16 = map.bytes;
	const uint8_t *const data8 = data.bytes;

	const uint16_t offsetToTypeList = CFSwapInt16BigToHost(map16[12]);
	const uint16_t offsetToNameList = CFSwapInt16BigToHost(map16[13]);

	// Generate resource type strings.
	const uint8_t *const nameList = (const uint8_t *)map16 + offsetToNameList;
	const uint16_t *const typeList = (const uint16_t *)((const uint8_t *)map16 + offsetToTypeList);
	const uint16_t numberOfTypes = CFSwapInt16BigToHost(typeList[0]);

	const uint16_t *typeListPointer = typeList + 1;

	for(int type = 0; type <= numberOfTypes; type++) {
		// Read four-byte resource type.
		const uint32_t type = CFSwapInt32BigToHost(*(uint32_t *)typeListPointer);
		const uint16_t numberOfResources = CFSwapInt16BigToHost(typeListPointer[2]);
		const uint16_t offsetIntoResourceList = CFSwapInt16BigToHost(typeListPointer[3]);
		typeListPointer += 4;

		const uint8_t *resourceList = (const uint8_t *)typeList + offsetIntoResourceList;
		for(int resource = 0; resource <= numberOfResources; resource++) {
			const uint16_t resourceID = CFSwapInt16BigToHost(*(uint16_t *)resourceList);
			const uint16_t offsetToResourceName = CFSwapInt16BigToHost(*(uint16_t *)&resourceList[2]);
			const uint8_t resourceAttributes = resourceList[4];
			const uint32_t offsetToResourceData = resourceList[7] | (resourceList[6] << 8) | (resourceList[5] << 16);

			resourceList += 12;

			// Get name.
			const uint8_t lengthOfName = nameList[offsetToResourceName];
			NSString *const name =
				[[NSString alloc]
					initWithBytes:&nameList[offsetToResourceName+1]
					length:lengthOfName
					encoding:NSMacOSRomanStringEncoding
				];

			// Get data
			const uint8_t *const startOfData = &data8[offsetToResourceData];
			const uint32_t lengthOfData = CFSwapInt32BigToHost(*(uint32_t *)startOfData);
			NSData *const resourceData = [data subdataWithRange:NSMakeRange(offsetToResourceData+4, lengthOfData)];

			[resources addObject:[CWXResource
				resourceWithName:name
				type:type
				attributes:resourceAttributes
				resourceID:resourceID
				data:resourceData]
			];
		}
	}

	return [resources copy];
}

@end
