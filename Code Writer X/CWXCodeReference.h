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

	In this program we parse those two things when the document
	is loaded and store the results in an array of code references.

*/

@interface CWXCodeReference : NSObject

+ (id)codeReferenceWithTitle:(NSString *)title resourceID:(uint16_t)resourceID;

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) uint16_t resourceID;

@end
