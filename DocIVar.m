/*
	Copyright (C) 2013 Muhammad Hussein Nasrollahpour
 
	Author:  Muhammad Hussein Nasrollahpour <iapplechocolate@me.com>
	Date:  September 2013
	License:  Modified BSD (see COPYING)
 */

#import "DocIVar.h"
#import "DocHTMLElement.h"
#import "DocIndex.h"
#import "DocDescriptionParser.h"

@implementation DocIVar

@synthesize typeEncoding;

// type name;                    => NSString *docGen;
// type<conformedProtocol> name; => id<DocWeaving> *weaver;
- (DocHTMLElement *)HTMLRepresentation
{
	H hType = [SPAN class: @"type" with: nil];
	[hType with: @"<"];
	H hConformedProtocol = [SPAN class: @"ConformedProtocol" with: hType];
	[hConformedProtocol with: @">"];
	H hivarName = [SPAN class: @"IVarName"];
	H hIvar = [SPAN class: @"iVar" with: hConformedProtocol and: hivarName];
	
	H hiVarDesc = [DIV class: @"iVarDescription" with: hIvar];
	
	// NSLog(@"%@", hiVarDesc);
	return hiVarDesc;
}

- (void)parseProgramComponent:(SCKIvar *)anIVar
{
	[self setName: [anIVar name]];
	[self setTypeEncoding: [anIVar typeEncoding]];
	[self appendToRawDescription: [[anIVar documentation] string]];
	
	DocDescriptionParser *descriptionParser = [DocDescriptionParser new];
	
	[descriptionParser parse: [self rawDescription]];
	[self addInformationFrom: descriptionParser];
}

@end
