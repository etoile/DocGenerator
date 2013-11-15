/*
    Copyright (C) 2013 Muhammad Hussein Nasrollahpour
 
    Author:  Muhammad Hussein Nasrollahpour <iapplechocolate@me.com>
    Date:  June 2013
    License:  Modified BSD (see COPYING)
*/

#import "TestCommon.h"

@implementation TestCommon

- (NSArray *)retrieveTestFiles
{
	NSBundle *bundle = [NSBundle bundleForClass: [self class]];
	NSArray *testFiles = [bundle pathsForResourcesOfType: @"h"
											 inDirectory: nil];
	[testFiles arrayByAddingObjectsFromArray: [bundle pathsForResourcesOfType: @"m" inDirectory: nil]];
	
	return testFiles;
}

@end
