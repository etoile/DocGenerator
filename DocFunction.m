//
//  Function.m
//  ETDocGenerator
//
//  Created by Nicolas Roard (Home) on 6/8/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "DocFunction.h"
#import "HtmlElement.h"
#import "DescriptionParser.h"
#import "DocIndex.h"
#import "Parameter.h"

@implementation DocFunction

- (void) dealloc
{
	[returnDescription release];
	[super dealloc];
}

- (void) setReturnDescription: (NSString *)aDescription
{
	ASSIGN(returnDescription, aDescription);
}

- (void) setDescription: (NSString *)aDescription forParameter: (NSString *)aName
{
	FOREACH(parameters, p, Parameter *)
	{
		if ([[p name] isEqualToString: aName])
		{
			[p setDescription: aDescription];
			return;
		}
	}
}

- (H) richDescription
{
	H param_list = [DIV class: @"paramsList"];
	H ul = UL;

	if ([parameters count] > 0)
	{
		[param_list and: [H3 with: @"Parameters"]];
	}

	FOREACH(parameters, p, Parameter *)
	{
		H h_param = [LI with: [I with: [p name]]];
		[h_param and: [p description]];
		[ul and: h_param];
	}
	[param_list and: ul];
	
	if ([returnDescription length])
	{
		[param_list and: [H3 with: @"Return"]];
		[param_list and: returnDescription];
	}
	
	[param_list and: [H3 with: @"Description"]];
	[param_list and: filteredDescription];

	return param_list;
}

- (HtmlElement *) HTMLRepresentation
{
	H h_signature = [SPAN class: @"methodSignature"];
	H h_returnType = [SPAN class: @"returnType" 
	                       with: [SPAN class: @"type" with: [[self returnParameter] HTMLRepresentationWithParentheses: NO]]];
	
	[h_signature and: h_returnType];
	[h_signature and: [SPAN class: @"selector" with: @" " and: name]];
	[h_signature with: @"("];

	BOOL isFirst = YES;
	FOREACH(parameters, p, Parameter *)
	{
		H h_parameter = [p HTMLRepresentationWithParentheses: NO];

		if (NO == isFirst)
		{
			[h_signature and: @", "];
		}
		[h_signature and: h_parameter];

		isFirst = NO;
	}
	[h_signature with: @")"];
	
	H methodFull = [DIV class: @"method" 
	                     with: [DL with: [DT with: h_signature]
                                    and: [DD with: [DIV class: @"methodDescription" 
	                                                     with: [self HTMLDescriptionWithDocIndex: [DocIndex currentIndex]]]]]];

	return methodFull;
}

- (NSString *) GSDocElementName
{
	return @"function";
}

- (SEL) weaveSelector
{
	return @selector(weaveFunction:);
}

- (void) parser: (GSDocParser *)parser 
   startElement: (NSString *)elementName
 withAttributes: (NSDictionary *)attributeDict
{
	if ([elementName isEqualToString: [self GSDocElementName]]) /* Opening tag */
	{
		BEGINLOG();
		[self setReturnType: [attributeDict objectForKey: @"type"]];
		[self setName: [attributeDict objectForKey: @"name"]];
	}
}

- (void) parser: (GSDocParser *)parser
     endElement: (NSString *)elementName
    withContent: (NSString *)trimmed
{
	if ([elementName isEqualToString: @"arg"]) 
	{
		[self addParameter: trimmed
		            ofType: [parser argTypeFromArgsAttributes: [parser currentAttributes]]];	
	}
	else if ([elementName isEqualToString: @"desc"]) 
	{
		[self appendToRawDescription: trimmed];
		CONTENTLOG();
	}
	else if ([elementName isEqualToString: [self GSDocElementName]]) /* Closing tag */
	{
		DescriptionParser* descParser = [DescriptionParser new];
		
		[descParser parse: [self rawDescription]];
		
		//NSLog(@"Function raw description <%@>", [self rawDescription]);
		
		[self addInformationFrom: descParser];
		[descParser release];
		
		[(id)[parser weaver] performSelector: [self weaveSelector] withObject: self];
		
		ENDLOG2(name, [self task]);
	}
}



@end
