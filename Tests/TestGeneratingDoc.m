/*
    Copyright (C) 2013 Muhammad Hussein Nasrollahpour
 
    Author:  Muhammad Hussein Nasrollahpour <iapplechocolate@me.com>
    Date:  June 2013
    License:  Modified BSD (see COPYING)
 */

#import "TestCommon.h"
#import "DocSourceCodeParser.h"

@interface TestGeneratingDoc : TestCommon

@end

@implementation TestGeneratingDoc

- (id)init
{
	SUPERINIT;
	
	DocSourceCodeParser *sourceCodeParser = [[DocSourceCodeParser alloc] initWithSourceFile: [[self retrieveTestFiles] firstObject] additionalParserFiles: nil];
	
	[sourceCodeParser parseAndWeave];
	
	return self;
}

@end
