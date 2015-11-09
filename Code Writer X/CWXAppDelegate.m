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

#define kCodeWriterXMaxLeftColumnWidth	250.0f

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
	NSArray *_codeReferences;
	NSArray *_filteredCodeReferences;
	NSArray *_allDocuments;
}

#pragma mark -
#pragma mark Application delegeate methods

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// compile the list of all enclosed documents; we'll do this by just
	// looking for everything ending in .rsrc in our resource folder
	// and then stripping off the extension
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	NSError *error = nil;
	_allDocuments =
		[[[defaultManager contentsOfDirectoryAtPath:[[NSBundle mainBundle] resourcePath] error:&error]
			filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension = \"rsrc\""]] valueForKey:@"stringByDeletingPathExtension"];

	// open the first document by default
	[self openDocument:[_allDocuments objectAtIndex:0]];

	// horrid though it is, this is the only way I've found of imposing a less-than-half
	// default width on the split view; we'll check whether the view in the left half is
	// too large and, if so, resize the split.
	//
	// Assumption at work then: the table view is always the same width as the left side
	// of the split view.
	if(self.tableView.frame.size.width > kCodeWriterXMaxLeftColumnWidth)
	{
		[self.splitView setPosition:kCodeWriterXMaxLeftColumnWidth ofDividerAtIndex:0];
	}
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	// this is a small utility program; we'll stay open only as long as the window is open
	return YES;
}

#pragma mark -
#pragma mark Document and reference opening

- (void)openDocument:(NSString *)documentName
{
	// kill our current fork manager and open a new one with the data fork
	// of the nominated document, parsing it as though it were a resource fork
	_resources = [NSArray resourcesFromDataForkOfFileAtPath:[[NSBundle mainBundle] pathForResource:documentName ofType:@"rsrc"]];

	// Cliff's files contain two special resources:
	//
	//	LIST, which is a list of enclosed article names separated by carriage returns, and...
	//
	//	INDX, which is a list of the respective resource numbers containing the text for each article,
	//			in the same order as they were listed in LIST.
	//
	// So we'll grab those two resources here
	CWXResource *list = [[_resources filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"stringType = %@", @"LIST"]] objectAtIndex:0];
	CWXResource *index = [[_resources filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"stringType = %@", @"INDX"]] objectAtIndex:0];

	// from those resources, compile an array of code references, each of which is just
	// the title of a code snippet and a record of the resource number
	NSString *allTitlesString = [[NSString alloc] initWithData:list.data encoding:NSMacOSRomanStringEncoding];
	NSArray *allTitles = [allTitlesString componentsSeparatedByString:@"\r"];

	const uint16_t *indicesPointer = index.data.bytes;
	const uint16_t *maxIndicesPointer = indicesPointer + (index.data.length/2);

	_codeReferences = [NSMutableArray arrayWithCapacity:[allTitles count]];

	for(NSString *title in allTitles)
	{
		// the final string has a terminating \r so NSArray's componentsSeparatedByString: will give us a final
		// empty string, which we don't care about
		if(![title length]) break;

		// the files all contain an article named 'About…' which mostly just explains that the desk accessory
		// version of Cliff's program is no longer supported. We'll filter those out but keep all the others
		if(![title isEqualToString:@"About…"])
			[(NSMutableArray *)_codeReferences addObject:[CWXCodeReference codeReferenceWithTitle:title resourceID:CFSwapInt16BigToHost(*indicesPointer)]];

		// we'll increment the indices pointer and make sure we don't overrun, repeating the final
		// index pointer indefinitely if that happens (since it generally indicates that there are
		// no indices and the list is the content in and of itself)
		indicesPointer++;
		if(indicesPointer == maxIndicesPointer) indicesPointer--;
	}

	// as the user has yet to perform any searching, we'll store the [user] filtered list as
	// identical to the full list for now
	_filteredCodeReferences = _codeReferences;

	// inform our table view that the data backing it has changed
	[self.tableView reloadData];

	// if a row is currently selected then ensure we have that code reference open
	// (eg, this happens when changing document)
	NSInteger selectedRow = [self.tableView selectedRow];
	if(selectedRow < [_filteredCodeReferences count])
		[self openReference:selectedRow];
	else
		[self.textView setString:@""];

	// ensure the current document name is in the combo box (eg, it won't be if
	// this program has just started running)
	[self.comboBox setObjectValue:documentName];
}

- (void)openReference:(NSInteger)selectedRow
{
	// we'll grab the code reference from the filtered list then search for a
	// suitable resource...
	CWXCodeReference *reference = [_filteredCodeReferences objectAtIndex:selectedRow];

	NSArray *candidates =
		[_resources
			filteredArrayUsingPredicate:
				[NSPredicate predicateWithFormat:@"stringType = %@ and resourceID = %@", @"TEXT", @(reference.resourceID)]];

	// if no resource was found, leave the text view empty
	if(![candidates count])
	{
		[self.textView setString:@""];
		return;
	}

	// if at least one matching resource was found (which should also mean
	// exactly one) then parse its contents as per the Mac OS Roman string
	// encoding and put them in the text view
	CWXResource *resource = [candidates objectAtIndex:0];

	NSString *string = [[NSString alloc] initWithData:resource.data encoding:NSMacOSRomanStringEncoding];

	[self.textView setString:string];
}

#pragma mark -
#pragma mark Table view datasource methods

/*
	easy stuff: connect the table view directly to our list of filtered code references
*/
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [_filteredCodeReferences count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return [[_filteredCodeReferences objectAtIndex:rowIndex] title];
}

#pragma mark -
#pragma mark Table view delegate method

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	// selecting anything in the table view results in an appropriate
	// call to openReference:...
	NSTableView *tableView = [aNotification object];
	NSInteger selectedRow = [tableView selectedRow];

	if(selectedRow < 0) return;
	
	[self openReference:selectedRow];
}

#pragma mark -
#pragma mark UIControl delegate method; applicable to the search field and the combo box

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	if(aNotification.object == self.searchField)
	{
		// if the text in the search field has changed then use it to
		// filter down the full list of code references into a new filtered
		// list and inform the table view of the change
		NSString *newText = [self.searchField stringValue];

		if(![newText length])
		{
			_filteredCodeReferences = _codeReferences;
		}
		else
		{
			_filteredCodeReferences = [_codeReferences filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"title contains[cd] %@", newText]];
		}

		[self.tableView reloadData];
	}
	
	if(aNotification.object == self.comboBox)
	{
		// if the text in the combo box has changed and now matches one
		// of our known documents then open it immediately
		NSInteger indexOfSelection = [_allDocuments indexOfObject:[self.comboBox stringValue]];
		if(indexOfSelection != NSNotFound)
		{
			[self openDocument:[self.comboBox stringValue]];
		}
	}
}

#pragma mark -
#pragma mark Combo box datasource methods

/*

	more uncontroversial stuff here; _allDocuments is an array of strings and
	we'll use that to populate the combo box and to respond to autocompletes

*/
- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
	return [_allDocuments count];
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index
{
	return [_allDocuments objectAtIndex:index];
}

- (NSString *)comboBox:(NSComboBox *)aComboBox completedString:(NSString *)uncompletedString
{
	NSArray *candidates = [_allDocuments filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self beginswith[cd] %@", uncompletedString]];
	
	if([candidates count])
		return [candidates objectAtIndex:0];

	return nil;
}

- (NSUInteger)comboBox:(NSComboBox *)aComboBox indexOfItemWithStringValue:(NSString *)aString
{
	return [_allDocuments indexOfObject:aString];
}

#pragma mark -
#pragma mark Combo box delegate methods

- (void)comboBoxSelectionDidChange:(NSNotification *)notification
{
	// selecting a document in the combo box results in that document being loaded
	NSComboBox *comboBox = notification.object;
	[self openDocument:[_allDocuments objectAtIndex:[comboBox indexOfSelectedItem]]];
}

#pragma mark -
#pragma mark Split view delegate methods

- (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)dividerIndex
{
	// we'll constrain the size of the leftmost column
	if(proposedPosition < kCodeWriterXMaxLeftColumnWidth)
		return proposedPosition;

	return kCodeWriterXMaxLeftColumnWidth;
}

@end
