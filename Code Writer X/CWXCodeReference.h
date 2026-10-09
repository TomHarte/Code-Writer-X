//
//  CWXCodeReference.h
//  Code Writer X
//
//  Created by Thomas Harte on 22/10/2012.
//  Copyright (c) 2012 Thomas Harte. All rights reserved.
//

#import <Foundation/Foundation.h>

/*

	A code reference contains a reference to one of Cliff's
	code fragments. His files contain an index and a list of
	resources, the list containing fragment names and the
	index containing resource numbers for loading the appropriate
	text when requested.

	In this program those two things are parsed when the document
	is loaded, and stored into an array of code references.

*/

static const uint16_t kNoResourceID = ~0;

@interface CWXCodeReference : NSObject

+ (nonnull instancetype)codeReferenceWithTitle:(nonnull NSString *)title resourceID:(uint16_t)resourceID;
+ (nonnull instancetype)codeReferenceWithTitle:(nonnull NSString *)title;

@property (nonatomic, readonly, nonnull) NSString *title;
@property (nonatomic, readonly) uint16_t resourceID;

@end
