//
//  CWXAppDelegate.m
//  Code Writer X
//
//  Created by Thomas Harte on 21/10/2012.
//  Copyright (c) 2012 Thomas Harte. All rights reserved.
//

#import "CWXAppDelegate.h"
#import "NSArray+ResourceForks.h"
#import "CWXResource.h"
#include <sys/xattr.h>
#import "CWXCodeReference.h"

static const CGFloat kCodeWriterXMaxLeftColumnWidth = 250.0;
static const CGFloat kCodeWriterXMinLeftColumnWidth = 100.0;
static const char *const kResourceFileExtension = "resource";

@interface CWXAppDelegate ()

@property (nonatomic, weak) IBOutlet NSTableView *tableView;
@property (nonatomic, unsafe_unretained) IBOutlet NSTextView *textView;
@property (nonatomic, weak) IBOutlet NSComboBox *comboBox;
@property (nonatomic, weak) IBOutlet NSSearchField *searchField;
@property (nonatomic, weak) IBOutlet NSSplitView *splitView;

@end

@implementation CWXAppDelegate
{
	NSArray <CWXResource *> *_resources;
	NSArray <CWXCodeReference *> *_codeReferences;
	NSArray <CWXCodeReference *> *_filteredCodeReferences;
	NSArray <NSString *> *_allDocuments;
}

#pragma mark -
#pragma mark Application delegeate methods

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Compile list of enclosed documents by searching the bundle.
	NSFileManager *const defaultManager = [NSFileManager defaultManager];
	NSError *error = nil;
	_allDocuments =
		[[[defaultManager contentsOfDirectoryAtPath:[NSBundle mainBundle].resourcePath error:&error]
			filteredArrayUsingPredicate:
				[NSPredicate
					predicateWithFormat:[NSString stringWithFormat:@"pathExtension = \"%s\"", kResourceFileExtension]]
			] valueForKey:@"stringByDeletingPathExtension"];

	// Open the first document by default.
	[self openDocument:_allDocuments[0]];

	// The only means I've found of imposing a less-than-half default width on the split view:
	// check whether the view in the left half is too large and, if so, resize the split.
	//
	// Assumption: the table view is always the same width as the left side of the split view.
	if(self.tableView.frame.size.width > kCodeWriterXMaxLeftColumnWidth) {
		[self.splitView setPosition:kCodeWriterXMaxLeftColumnWidth ofDividerAtIndex:0];
	}

	// Enforce font.
	self.textView.font = [NSFont monospacedSystemFontOfSize:NSFont.systemFontSize weight:NSFontWeightRegular];

	// Set tabs to be eight spaces.
	const CGFloat tabInterval = [@" " sizeWithAttributes:@{ NSFontAttributeName: self.textView.font }].width * 8.0;
	NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	paragraphStyle.tabStops = @[];
	paragraphStyle.defaultTabInterval = tabInterval;
	self.textView.defaultParagraphStyle = paragraphStyle;

}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
	return YES;
}

#pragma mark -
#pragma mark Document and reference opening

- (void)openDocument:(NSString *)documentName {
	_resources = [NSArray
		resourcesFromDataForkOfFileAtPath:[[NSBundle mainBundle]
		pathForResource:documentName
		ofType:@(kResourceFileExtension)]
	];

	// Cliff's files contain two special resources:
	//
	//	LIST, which is a list of enclosed article names separated by carriage returns; and
	//
	//	INDX, which is a list of the respective resource numbers containing the text for each article,
	//			in the same order as they were listed in LIST.
	//
	CWXResource *const list =
		[_resources filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"stringType = %@", @"LIST"]][0];
	CWXResource *const index =
		[_resources filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"stringType = %@", @"INDX"]][0];

	// Hence compile an array of code references, capturing title and resource number.
	NSString *const allTitlesString = [[NSString alloc] initWithData:list.data encoding:NSMacOSRomanStringEncoding];
	NSArray <NSString *> *const allTitles = [allTitlesString componentsSeparatedByString:@"\r"];

	const uint16_t *indicesPointer = index.data.bytes;
	const uint16_t *maxIndicesPointer = indicesPointer + (index.data.length / sizeof(uint16_t));

	NSMutableArray <CWXCodeReference *> *codeReferences = [NSMutableArray arrayWithCapacity:allTitles.count];
	for(NSString *title in allTitles) {
		// The final string has a terminating \r so NSArray's componentsSeparatedByString: produces a redundant final
		// empty string.
		if(!title.length) break;

		// Files all contain an article named 'About…' which mostly just explains that the desk accessory
		// version of Cliff's program is no longer supported. Filter that out.
		if(![title isEqualToString:@"About…"]) {
			[codeReferences addObject:^{
				if(indicesPointer) {
					return [CWXCodeReference
						codeReferenceWithTitle:title
						resourceID:CFSwapInt16BigToHost(*indicesPointer)
					];
				} else {
					return [CWXCodeReference codeReferenceWithTitle:title];
				}
			}()];

		}

		// Increment the indices pointer but don't overrun; sometimes there are no indices and the list is the content.
		if(indicesPointer) {
			++indicesPointer;

			if(indicesPointer == maxIndicesPointer) {
				indicesPointer = NULL;
			}
		}
	}
	_codeReferences = [codeReferences copy];

	// User has yet to perform any searching so store the [user] filtered list as identical to the full list.
	_filteredCodeReferences = _codeReferences;
	[self.tableView reloadData];

	// If a row is currently selected then open that code reference.
	const NSInteger selectedRow = self.tableView.selectedRow;
	if(selectedRow < _filteredCodeReferences.count) {
		[self openReference:selectedRow];
	} else {
		self.textView.string = @"";
	}

	// ensure the current document name is in the combo box (eg, it won't be if
	// this program has just started running)
	self.comboBox.objectValue = documentName;
}

- (void)openReference:(NSInteger)selectedRow {
	// Grab the code reference from the filtered list and search for a suitable resource...
	CWXCodeReference *const reference = _filteredCodeReferences[selectedRow];

	NSArray <CWXResource *> *const candidates =
		[_resources
			filteredArrayUsingPredicate:[NSPredicate
				predicateWithFormat:@"stringType = %@ and resourceID = %@", @"TEXT", @(reference.resourceID)]];

	// If no resource was found, leave the text view empty; otherwise populate the text view.
	self.textView.string =
		candidates.count ?
			[[NSString alloc] initWithData:candidates[0].data encoding:NSMacOSRomanStringEncoding] :
			@"No description provided.";
}

#pragma mark -
#pragma mark Table view datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
	return _filteredCodeReferences.count;
}

- (id)
	tableView:(NSTableView *)aTableView
	objectValueForTableColumn:(NSTableColumn *)aTableColumn
	row:(NSInteger)rowIndex {
	return _filteredCodeReferences[rowIndex].title;
}

#pragma mark -
#pragma mark Table view delegate method

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	NSTableView *const tableView = aNotification.object;
	const NSInteger selectedRow = tableView.selectedRow;

	if(selectedRow >= 0) {
		[self openReference:selectedRow];
	}
}

#pragma mark -
#pragma mark UIControl delegate method; applicable to the search field and the combo box

- (void)controlTextDidChange:(NSNotification *)aNotification {
	if(aNotification.object == self.searchField) {
		// If the search field has changed then filter the full list of code references into a new filtered list.
		NSString *const newText = self.searchField.stringValue;

		if(!newText.length) {
			_filteredCodeReferences = _codeReferences;
		} else {
			_filteredCodeReferences =
				[_codeReferences filteredArrayUsingPredicate:
					[NSPredicate predicateWithFormat:@"title contains[cd] %@", newText]];
		}

		[self.tableView reloadData];
	}
	
	if(aNotification.object == self.comboBox) {
		// If the combo box has changed and now matches one of our known documents then open it immediately
		const NSInteger indexOfSelection = [_allDocuments indexOfObject:self.comboBox.stringValue];
		if(indexOfSelection != NSNotFound) {
			[self openDocument:self.comboBox.stringValue];
		}
	}
}

#pragma mark -
#pragma mark Combo box datasource methods

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox {
	return _allDocuments.count;
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index {
	return _allDocuments[index];
}

- (NSString *)comboBox:(NSComboBox *)aComboBox completedString:(NSString *)uncompletedString {
	NSArray <NSString *> *const candidates =
		[_allDocuments filteredArrayUsingPredicate:
			[NSPredicate predicateWithFormat:@"self beginswith[cd] %@", uncompletedString]];
	return candidates.count ? candidates[0] : nil;
}

- (NSUInteger)comboBox:(NSComboBox *)aComboBox indexOfItemWithStringValue:(NSString *)aString {
	return [_allDocuments indexOfObject:aString];
}

#pragma mark -
#pragma mark Combo box delegate methods

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
	NSComboBox *const comboBox = notification.object;
	[self openDocument:_allDocuments[comboBox.indexOfSelectedItem]];
}

#pragma mark -
#pragma mark Split view delegate methods

- (CGFloat)
	splitView:(NSSplitView *)splitView
	constrainSplitPosition:(CGFloat)proposedPosition
	ofSubviewAt:(NSInteger)dividerIndex {

	// Constrain the leftmost column.
	return MAX(MIN(proposedPosition, kCodeWriterXMaxLeftColumnWidth), kCodeWriterXMinLeftColumnWidth);
}

@end
