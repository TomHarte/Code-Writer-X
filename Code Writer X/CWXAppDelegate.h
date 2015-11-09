//
//  CWXAppDelegate.h
//  Code Writer X
//
//  Created by Thomas Harte on 21/10/2012.
//  Copyright (c) 2012 Thomas Harte. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CWXAppDelegate : NSObject
	<
		NSApplicationDelegate,

		NSTableViewDataSource,
		NSTableViewDelegate,

		NSTextFieldDelegate,

		NSComboBoxDataSource,
		NSComboBoxDelegate>

@property (weak) IBOutlet NSWindow *window;

@end
