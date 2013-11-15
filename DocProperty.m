/*
    Copyright (C) 2013 Muhammad Hussein Nasrollahpour
 
    Author:  Muhammad Hussein Nasrollahpour <iapplechocolate@me.com>
    Date:  September 2013
    License:  Modified BSD (see COPYING)
 */

#import "DocProperty.h"
#import "DocDescriptionParser.h"

@implementation DocProperty

@synthesize attributes;

- (void)parseProgramComponent:(SCKProperty *)aProperty
{
	[self setName: [aProperty name]];
	[self setAttributes: [aProperty attributes]];
	[self appendToRawDescription: [[aProperty documentation] string]];
	
	DocDescriptionParser *descriptionParser = [DocDescriptionParser new];
	
	[descriptionParser parse: [self rawDescription]];
	[self addInformationFrom: descriptionParser];
}

@end
