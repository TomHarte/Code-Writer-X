//
//  CWXResource.h
//  Code Writer X
//
//  Created by Thomas Harte on 21/10/2012.
//  Copyright (c) 2012 Thomas Harte. All rights reserved.
//

#import <Foundation/Foundation.h>

/*

	A CWXResource is little more than a shell for holding the properties of
	a single thing found in a resource fork.

*/

@interface CWXResource : NSObject

+ (id)resourceWithName:(NSString *)name type:(uint32_t)type attributes:(uint8_t)attributes resourceID:(uint16_t)resourceID data:(NSData *)data;

@property (nonatomic, readonly) uint32_t type;
@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) uint8_t attributes;
@property (nonatomic, readonly) uint16_t resourceID;
@property (nonatomic, readonly) NSString *name;

@property (nonatomic, readonly) NSString *stringType;

@end
