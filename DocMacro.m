/*
	Copyright (C) 2010 Quentin Mathe

	Authors:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  December 2010
	License:  Modified BSD (see COPYING)
 */

#import "DocMacro.h"
#import "DocDescriptionParser.h"

@implementation DocMacro

- (NSString *) GSDocElementName
{
	return @"macro";
}

- (SEL) weaveSelector
{
	return @selector(weaveMacro:);
}

- (void) parseProgramComponent: (SCKMacro *)aMacro
{	
	[self setName: [aMacro name]];
	[self appendToRawDescription: [[aMacro documentation] string]];
	
	DocDescriptionParser *descriptionParser = [DocDescriptionParser new];
	
	[descriptionParser parse: [self rawDescription]];
	[self addInformationFrom: descriptionParser];
}

@end
