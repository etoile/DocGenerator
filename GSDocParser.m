/*
	Copyright (C) 2008 Nicolas Roard

	Author:  Nicolas Roard
	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  June 2008
	License:  Modified BSD (see COPYING)
 */

#import "GSDocParser.h"
#import "DocCDataType.h"
#import "DocHeader.h"
#import "DocMacro.h"
#import "DocMethod.h"
#import "DocFunction.h"
#import "DocHTMLElement.h"
#import "DocDescriptionParser.h"

@interface NullParserDelegate : NSObject <GSDocParserDelegate>
@end


@implementation GSDocParser

- (id) init
{
	return [self initWithSourceFile: nil additionalParserFiles: [NSArray array]];
}

- (id) initWithSourceFile: (NSString *)aSourceFile additionalParserFiles: (NSArray *)additionalFiles
{
	NILARG_EXCEPTION_TEST(aSourceFile);
	INVALIDARG_EXCEPTION_TEST(additionalFiles,
		[[additionalFiles pathsMatchingExtensions: [NSArray arrayWithObject: @"igsdoc"]] count] == 1);

	SUPERINIT;

	xmlParser = [[NSXMLParser alloc] initWithContentsOfURL: [NSURL fileURLWithPath: aSourceFile]];
	[xmlParser setDelegate: self];
	parserDelegateStack = [[NSMutableArray alloc] initWithObjects: [NSValue valueWithNonretainedObject: self], nil];
	indentSpaces = @"";
	indentSpaceUnit = @"  ";
	elementClasses = [[NSMutableDictionary alloc] initWithObjectsAndKeys: 
		[DocHeader class], @"head", 
		[NullParserDelegate class], @"ivariable",
		[DocMethod class], @"method",
		[DocFunction class], @"function",
		[DocMacro class], @"macro",
		[DocCDataType class], @"type",
		[DocConstant class], @"constant",
		[DocVariable class], @"variable", nil];
	symbolElements = [[NSSet alloc] initWithObjects: @"head", @"class", @"protocol", @"category", 
		@"ivariable", @"method", @"function", @"constant", @"macro", nil];
	// NOTE: ref elements are pruned. DocIndex is used instead.
	// desc -> dd substitution is not added to the dictionary until we enter a 
	// deflist, otherwise this would intercept <desc> inside <method>, <class> etc.
	substitutionElements = [[NSMutableDictionary alloc] initWithObjectsAndKeys: @"ul", @"list", 
		@"li", @"item", @"ol", @"enum", @"dl", @"deflist", @"dt", @"term", @"", @"ref", @"", @"uref", nil];
	// NOTE: var corresponds to GSDoc var and not HTML var
	etdocElements = [[NSSet alloc] initWithObjects: @"p", @"code", @"example", @"br", @"em", @"strong", @"var", @"ivar", nil]; 
	escapedCharacters = [[NSMutableDictionary alloc] initWithObjectsAndKeys: @"&lt;", @"<", @"&gt;", @">", nil];
	content = [NSMutableString new];
	indexContent = [[NSDictionary alloc] initWithContentsOfFile:
		[[additionalFiles pathsMatchingExtensions: [NSArray arrayWithObject: @"igsdoc"]] lastObject]];
	
	return self;
}


- (void) setWeaver: (id <DocWeaving>)aDocWeaver
{
	/* The weaver retains the parser */
	weaver = aDocWeaver;
}

- (id <DocWeaving>) weaver
{
	return weaver;
}

- (void) parseAndWeave
{
	[xmlParser parse];
}

- (void) newContent
{
	content = [NSMutableString new];
}

- (Class) elementClassForName: (NSString *)anElementName
{
	return [elementClasses objectForKey: anElementName];
}

- (id <GSDocParserDelegate>) parserDelegate
{
	id parserDelegate = [parserDelegateStack lastObject];
	BOOL isWeakRef = [parserDelegate isKindOfClass: [NSValue class]];
	return (isWeakRef ? [parserDelegate nonretainedObjectValue] : parserDelegate);
}

- (void) increaseIndentSpaces
{
	indentSpaces = [indentSpaces stringByAppendingString: indentSpaceUnit];
}

- (void) decreaseIndentSpaces
{
	NSUInteger i = [indentSpaces length] - [indentSpaceUnit length];
	ETAssert(i >= 0);
	indentSpaces = [indentSpaces substringFromIndex: i];
}

- (void) pushParserDelegate: (id <GSDocParserDelegate>)aDelegate
{
	if ([parserDelegateStack lastObject] != aDelegate)
	{
		[self increaseIndentSpaces];
	}
	[parserDelegateStack addObject: aDelegate];
}

- (void) popParserDelegate
{
	id objectBeforeLast = [parserDelegateStack objectAtIndex: [parserDelegateStack count] - 2];

	if ([parserDelegateStack lastObject] != objectBeforeLast)
	{
		[self decreaseIndentSpaces];
	}
	[parserDelegateStack removeObjectAtIndex: [parserDelegateStack count] - 1];
}

- (NSString *) indentSpaces
{
	return indentSpaces;
}

- (void) parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName
   namespaceURI:(NSString *)namespaceURI
  qualifiedName:(NSString *)qName
     attributes:(NSDictionary *)attributeDict
{
	//NSLog (@"%@  parse <%@>", indentSpaces, elementName);

	NSString *substituedElement = [substitutionElements objectForKey: elementName]; 
	BOOL removeMarkup = [substituedElement isEqualToString: @""];
	BOOL substituteMarkup = (substituedElement != nil && removeMarkup == NO);
	BOOL keepMarkup = [etdocElements containsObject: elementName];

	/* (1) For GSDoc tags which have equivalent ETDoc tags, we insert their content 
	   enclosed in equivalent ETDoc tags into our content accumulator. 
	   The next handled element can retrieve the accumulated content. For example:
	   <desc><i>A boat</i> on <j>the</j> river.</desc>
	   if i and j are GSDoc elements equivalent to x and y in ETDoc, the 
	   accumulated content will be:
	   <desc><x>A boat</x> on <y>the</y> river.</desc>

	   (2) For ETDoc tags, we insert them along with their content in our content accumulator. 
	   The next handled element can retrieve the accumulated content. For example:
	   <desc><i>A boat<i> on <j>the</j> river.</desc>
	   if i and j are ETDoc elements, the accumulated content will be:
	   <i>A boat</i>on <j>the</j> river. */
	if (removeMarkup)
	{
		return;
	}
	else if (substituteMarkup)
	{
		[content appendString: [NSString stringWithFormat: @"<%@>", substituedElement]];

		/* Replace <desc> with <dd> inside <deflist> but not elsewhere */
		if ([elementName isEqualToString: @"deflist"])
		{
			[substitutionElements setObject: @"dd" forKey: @"desc"];
		}
		return;
	}
	else if (keepMarkup)
	{
		[content appendString: [NSString stringWithFormat: @"<%@>", elementName]];
		return;
	}

	currentAttributes = attributeDict;

	id parserDelegate = [self parserDelegate];

	/* When we have a parser delegate registered for the new element name, 
	   we switch this delegate, otherwise we continue with the current one. */
	if ([self elementClassForName: elementName] != nil)
	{
		parserDelegate = [[self elementClassForName: elementName] new];

	}
	[self pushParserDelegate: parserDelegate];

	/* Discard previously parsed but unused content that belongs to a topmost element.

	   For example, we want to discard <p></p> below otherwise it gets inserted 
	   at the end of the first arg content.
	    <chapter>
	      <heading>ETGetOptionsDictionary functions</heading>
	      <p></p>
	      <function type="NSDictionary*" name="ETGetOptionsDictionary">
	        <arg type="char*">optString</arg> */
	if ([symbolElements containsObject: elementName])
	{
		[content setString: @""];
	}

	//NSLog(@"%@  Begin <%@>, parser %@", indentSpaces, elementName, [(id)[self parserDelegate] primitiveDescription]);
	[[self parserDelegate] parser: self startElement: elementName withAttributes: attributeDict];
}

/* On Mac OS X, this method is called with '<' and '>' as foundCharacters when 
the parser encounters &lt; or &gt;.

NSXMLParser automatically unescape common sequences such as &lt; and &gt;, and 
no way exists to disable it. */
- (void) parser: (NSXMLParser *)parser foundCharacters:(NSString *)string 
{
	NSString *escapedCharacter = [escapedCharacters objectForKey: string];

#if 0
	NSString *escapedString = [string stringByReplacingOccurrencesOfString: @"<" withString: @"&lt;"];
	escapedString = [escpaedString stringByReplacingOccurrencesOfString: @">" withString: @"&gt;"];
	if ([escapedString isEqual: string] == NO || [string rangeOfString: @"<"].location != NSNotFound)
	{
		NSLog(@"bla");
	}
#endif

	[content appendString: (escapedCharacter != nil ? escapedCharacter : string)];
}

- (void) parser: (NSXMLParser *)parser
  didEndElement: (NSString *)elementName
   namespaceURI: (NSString *)namespaceURI
  qualifiedName: (NSString *)qName
{
	NSString* trimmed = [content stringByTrimmingCharactersInSet: 
		[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSString *substituedElement = [substitutionElements objectForKey: elementName];
	BOOL removeMarkup = [substituedElement isEqualToString: @""];
	BOOL substituteMarkup = (substituedElement != nil && removeMarkup == NO);
	BOOL keepMarkup = [etdocElements containsObject: elementName];

	/* See comment in -parser:didStartElement:namespaceURI:qualifiedName: */
	if (removeMarkup)
	{
		return;
	}
	else if (substituteMarkup)
	{
		[content appendString: [NSString stringWithFormat: @"</%@>", substituedElement]];

		if ([elementName isEqualToString: @"deflist"])
		{
			[substitutionElements removeObjectForKey: @"desc"];
		}
		return;
	}
	else if (keepMarkup)
	{
		[content appendString: [NSString stringWithFormat: @"</%@>", elementName]];
		return;
	}

	[[self parserDelegate] parser: self endElement: elementName withContent: trimmed];
	//NSLog(@"%@  End <%@> --> %@", indentSpaces, elementName, trimmed);

	[self popParserDelegate];
	/* Discard the content accumulated to handle the element which ends. */
	[self newContent];
	currentAttributes = nil;
}


- (void) parserDidEndDocument: (NSXMLParser *)parser
{
	[weaver finishWeaving];
}

- (void) parser: (GSDocParser *)parser 
   startElement: (NSString *)elementName
  withAttributes: (NSDictionary *)attributeDict
{
	/* The main parser is responsible to parse the class, category and protocol attributes */
	if ([elementName isEqualToString: @"class"]) 
	{
		[weaver weaveClassNamed: [attributeDict objectForKey: @"name"]
		         superclassName: [attributeDict objectForKey: @"super"]];
	}
	else if ([elementName isEqualToString: @"category"]) 
	{
		BOOL isInformalProtocol =
			[self isInformalProtocolSymbolName: [attributeDict objectForKey: @"name"]];

		[weaver weaveCategoryNamed: [attributeDict objectForKey: @"name"]
		                 className: [attributeDict objectForKey: @"class"]
		        isInformalProtocol: isInformalProtocol];
	}
	if ([elementName isEqualToString: @"protocol"]) 
	{
		[weaver weaveProtocolNamed: [attributeDict objectForKey: @"name"]];
	}
}

- (void) parser: (GSDocParser *)parser
     endElement: (NSString *)elementName
    withContent: (NSString *)trimmedContent
{
	/* When we parse a class, we parse the declared child element too */
	if ([elementName isEqualToString: @"declared"])
	{
		ETAssert(nil != [weaver currentHeader]);
		[[weaver currentHeader] setDeclaredIn: trimmedContent];
	}
	else if ([elementName isEqualToString: @"conform"])
	{
		ETAssert(nil != [weaver currentHeader]);
		[[weaver currentHeader] addAdoptedProtocolName: trimmedContent];
	}
	else if ([elementName isEqualToString: @"desc"])
	{
		DocHeader *currentHeader = [weaver currentHeader];
		ETAssert(nil != currentHeader);
		DocMethodGroupDescriptionParser *descParser = [DocMethodGroupDescriptionParser new];
		
		[descParser parse: trimmedContent];
		[currentHeader setGroup: [descParser group]];
		if (IS_NIL_OR_EMPTY_STR([descParser abstract]) == NO)
		{
			[currentHeader setAbstract: [descParser abstract]];
		}
		[currentHeader setOverview: [descParser description]];
	}
}

- (NSDictionary *) currentAttributes
{
	NSParameterAssert(nil != currentAttributes);
	return currentAttributes;
}

- (NSString *) argTypeFromArgsAttributes: (NSDictionary *)attributeDict
{
	NSString *argType = [attributeDict objectForKey: @"type"];

	if (argType == nil)
		return @"";

	return [argType stringByTrimmingCharactersInSet: 
		[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (BOOL) isInformalProtocolSymbolName: (NSString *)aSymbolName
{
	ETAssert(indexContent != nil);
	return ([[indexContent objectForKey: @"protocol"] objectForKey: aSymbolName] != nil);
}

@end


@implementation NullParserDelegate 

- (void) parser: (GSDocParser *)parser 
   startElement: (NSString *)elementName
  withAttributes: (NSDictionary *)attributeDict
{

}

- (void) parser: (GSDocParser *)parser
     endElement: (NSString *)elementName
    withContent: (NSString *)trimmed
{

}

@end
