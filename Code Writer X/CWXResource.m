//
//  CWXResource.m
//  Code Writer X
//
//  Created by Thomas Harte on 21/10/2012.
//  Copyright (c) 2012 Thomas Harte. All rights reserved.
//

#import "CWXResource.h"

@implementation CWXResource

+ (instancetype)resourceWithName:(NSString *)name type:(uint32_t)type attributes:(uint8_t)attributes resourceID:(uint16_t)resourceID data:(NSData *)data
{
	return [[self alloc] initWithName:name type:type attributes:attributes resourceID:resourceID data:data];
}

- (instancetype)initWithName:(NSString *)name type:(uint32_t)type attributes:(uint8_t)attributes resourceID:(uint16_t)resourceID data:(NSData *)data
{
	self = [super init];

	if(self)
	{
		_name = name;
		_type = type;
		_data = data;
		_attributes = attributes;
		_resourceID = resourceID;
	}

	return self;
}

- (NSString *)stringType;
{
	return [NSString stringWithFormat:@"%c%c%c%c", _type >> 24, (_type >> 16)&0xff, (_type >> 8)&0xff, _type&0xff];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<Resource %p>: %@, type %@, id %d, length %ld", self, self.name, self.stringType, self.resourceID, self.data.length];
}

@end
