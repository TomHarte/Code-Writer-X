//
//  CWXCodeReference.m
//  Code Writer X
//
//  Created by Thomas Harte on 22/10/2012.
//  Copyright (c) 2012 Thomas Harte. All rights reserved.
//

#import "CWXCodeReference.h"

@implementation CWXCodeReference

+ (id)codeReferenceWithTitle:(NSString *)title resourceID:(uint16_t)resourceID
{
	return [[self alloc] initWithTitle:title resourceID:resourceID];
}

- (id)initWithTitle:(NSString *)title resourceID:(uint16_t)resourceID
{
	self = [super init];

	if(self)
	{
		_title = title;
		_resourceID = resourceID;
	}

	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<Code reference %p> %@ (ID %d)", self, self.title, self.resourceID];
}

@end
