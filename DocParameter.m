/*
	Copyright (C) 2008 Nicolas Roard

	Author:  Nicolas Roard
	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  June 2008
	License:  Modified BSD (see COPYING)
 */

#import "DocParameter.h"
#import "DocIndex.h"
#import "DocHTMLElement.h"


@implementation DocParameter

@synthesize name, type, description, typePrefix, className, protocolName, typeSuffix;

- (id) initWithName: (NSString *) aName type: (NSString *) aType
{
	SUPERINIT;
	[self setName: aName];
	[self setType: aType];
	return self;
}

- (void) dealloc
{
	name = nil;
	type = nil;
	description = nil;
	typePrefix = nil;
	className = nil;
	protocolName = nil;
	typeSuffix = nil;
}

+ (id) parameterWithName: (NSString *) aName type: (NSString *) aType
{
	return [[DocParameter alloc] initWithName: aName type: aType];
}

- (void) setName: (NSString *) aName
{
	name = aName;
}

static inline BOOL isDelimiter(char c)
{
	return (c == ' ' || c == '*' || c == '<' || c == '>');
}

static inline unsigned int parseTypePrefix(char *rawType, unsigned int length, NSString __strong **typePrefix)
{
	char *symbol = calloc(sizeof(char), length);;
	int i;
	BOOL foundProtocolOrClassName = NO;

	for (i = 0; i < length; i++)
	{
		if (rawType[i] == '*')
			break;
		
		if (rawType[i] == '<' || isupper(rawType[i]))
		{
			foundProtocolOrClassName = YES;
			break;
		}
		symbol[i] = rawType[i];
	}

	if (foundProtocolOrClassName)
	{
		*typePrefix = [[NSString alloc] initWithBytes: (const void *)symbol length: i encoding: NSUTF8StringEncoding];
		free(symbol);
		return i;
	}

	free(symbol);

	return 0;
}

static inline unsigned int parseClassOrProtocolName(char *rawType, unsigned int length, __strong NSString **classOrProtocolName)
{
	char *symbol = calloc(sizeof(char), length);
	int i;

	for (i = 0; i < length; i++)
	{
		if (isDelimiter(rawType[i]))
			break;

		symbol[i] = rawType[i];
	}

	*classOrProtocolName = [[NSString alloc] initWithBytes: (const void *)symbol length: i encoding: NSUTF8StringEncoding];
	free(symbol);
	return i;
}

static inline unsigned int parseTypeSuffix(char *rawType, unsigned int length, NSString __strong **typeSuffix)
{
	char *suffix = calloc(sizeof(char), length);
	int i;

	for (i = 0; i < length; i++)
	{
		suffix[i] = rawType[i];
	}

	*typeSuffix = [[NSString alloc] initWithBytes: (const void *)suffix length: i encoding: NSUTF8StringEncoding];
	free(suffix);

	return i;
}


/** We support parsing protocol and classe type such as:

<list>
<item>id&lt;ProtocolName&gt;</item>
<item>id&lt;ProtocolName&gt;*</item>
<item>ClassName*</item>
<item>ClassName**</item>
<item>ClassName&lt;ProtocolName&gt;*</item>
<item>ClassName&lt;ProtocolName&gt;**</item>
</list>

These declarations can be wrapped with a prefix and suffix too, but this isn't 
well tested yet. e.g. const.

We won't parse a protocol name that doesn't begin with a uppercase letter 
(parsing code limitation). Doesn't matter so much given we have no way to 
recognize a class name without a uppercase letter (unless we use the doc index 
to check its existence, but that would make the parsing slower without 
observable benefit since ObjC tradition requires class and protocol names to use 
camel case). */
- (void) parseType: (NSString *)aType
{
	if (aType == nil)
		return;

	const char *rawType = [aType UTF8String];
	unsigned int i = 0;
	BOOL isParsingProtocolName = NO;

	while (rawType[i] != '\0')
	{
		char character = rawType[i];
		char *unparsedText = (char *)&(rawType[i]);

		if (character == '<' || character == '>')
		{
			/* We skip < and >. typePrefix, classOrProtocolName or typeSuffix 
			   will never contain them.

			   For '<' let isupper() branch parses the protocol name on next iteration.
			   For '>' let else branch parses the suffix on next iteration. */
			i++;
			isParsingProtocolName = YES;
			continue;
		}
		else if (isupper(character))
		{
			NSString __strong **classOrProtocolName = (isParsingProtocolName ? &protocolName : &className);
			i += parseClassOrProtocolName(unparsedText, strlen(unparsedText), classOrProtocolName);
			isParsingProtocolName = NO;
		}
		else if (i == 0)
		{
			int advancement = parseTypePrefix(unparsedText, strlen(unparsedText), &typePrefix);
			if (advancement == 0)
				return;

			i += advancement;
		}
		else
		{
			i += parseTypeSuffix(unparsedText, strlen(unparsedText), &typeSuffix);
		}
	}
	//NSLog(@"Parsed type as prefix %@ class %@ protocol %@ suffix %@", typePrefix, className, protocolName, typeSuffix);
}

- (void) setType: (NSString *) aType
{
	type = aType;
	[self parseType: aType];
}

- (DocHTMLElement *) HTMLRepresentation
{
	ETAssertUnreachable();
	return nil;
}

- (DocHTMLElement *) HTMLRepresentationWithParentheses: (BOOL)usesParentheses
{
	DocIndex *docIndex = [DocIndex currentIndex];
	BOOL isReturnParameter = ([self name] == nil);
	H hParam = (isReturnParameter ? [SPAN class: @"returnType"] : [SPAN class: @"type"]);
	BOOL hasContent = NO;

	if (usesParentheses)
	{
		[hParam with: @"("];
	}

	if (typePrefix != nil)
	{
		[hParam with: typePrefix];
		hasContent = YES;
	}
	if (className != nil)
	{
		if (hasContent)
		{
			[hParam addText: @" "];
		}
		[hParam with: [docIndex linkForClassName: className]];
		hasContent = YES;
	}
	if (protocolName != nil)
	{
		if (hasContent)
		{
			[hParam addText: @" "];
		}
		[hParam with: @"<" and: [docIndex linkForProtocolName: protocolName] and: @">"];
		hasContent = YES;
	}
	if (typeSuffix != nil)
	{
		if (hasContent)
		{
			[hParam addText: @" "];
		}
		[hParam addText: typeSuffix];
	}

	/* No protocol or class in the type, we insert the raw type */
	if (hasContent == NO)
	{
		[hParam addText: type];
	}

	if (usesParentheses)
	{
		[hParam with: @")"];
	}
	else
	{
		[hParam with: @" "];
	}

	if (isReturnParameter)
		return hParam;

	return [SPAN class: @"parameter" with: hParam
	               and: [SPAN class: @"arg" with: [self name]]];
}

@end
