//
//  CWXResourceForkManager.h
//  Code Writer X
//
//  Created by Thomas Harte on 21/10/2012.
//  Copyright (c) 2012 Thomas Harte. All rights reserved.
//

#import <Foundation/Foundation.h>

/*

	The resource fork manager encompasses the knowledge for parsing
	Classic OS-style resource forks into individual resources. It
	can load the actual resource fork of a file, the data fork of
	a file as though it were the resource fork or be given the
	NSData of the resource fork directly.

	In all cases it then exposes an array of resources, in the
	order they were stored on disk. Each thing in the array is
	an instance of CWXResource.

*/

@interface CWXResourceForkManager : NSObject

+ (id)resourceForkManagerWithResourceForkOfFileAtPath:(NSString *)path;
+ (id)resourceForkManagerWithDataForkOfFileAtPath:(NSString *)path;
+ (id)resourceForkManagerWithResourceForkData:(NSData *)data;

@property (nonatomic, readonly) NSArray *resources;

@end
