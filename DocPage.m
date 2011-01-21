/*
	Copyright (C) 2008 Nicolas Roard

	Author:  Nicolas Roard
	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  June 2008
	License:  Modified BSD (see COPYING)
 */

#import "DocPage.h"
#import "DocHeader.h"
#import "DocCDataType.h"
#import "DocFunction.h"
#import "DocIndex.h"
#import "DocMacro.h"
#import "DocMethod.h"
#import "GSDocParser.h"
#import "DocHTMLElement.h"


@implementation DocPage

- (NSString *) sourcePath
{
	return [documentPath stringByDeletingLastPathComponent];
}

- (NSString *) defaultMenuFile
{
	NSFileManager* fm = [NSFileManager defaultManager];
	return [[[fm currentDirectoryPath] 
		stringByAppendingPathComponent: [self sourcePath]]
		stringByAppendingPathComponent: @"menu.html"];
}

- (NSSet *) validDocumentTypes
{
	return S(@"gsdoc", @"html");
}

- (id) initWithDocumentFile: (NSString *)aDocumentPath
               templateFile: (NSString *)aTemplatePath 
                   menuFile: (NSString *)aMenuPath
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *finalMenuPath = aMenuPath;

	if (nil == aMenuPath)
	{
		finalMenuPath = [self defaultMenuFile];
	}

	INVALIDARG_EXCEPTION_TEST(aTemplatePath, [fileManager fileExistsAtPath: aTemplatePath]);
	INVALIDARG_EXCEPTION_TEST(finalMenuPath, [fileManager fileExistsAtPath: finalMenuPath]);
	if (documentPath != nil && NO == [[self validDocumentTypes] containsObject: [aDocumentPath pathExtension]])
	{
		[NSException raise: NSInvalidArgumentException
		            format: @"The input document type must be .html or .gsdoc"];
	}

	SUPERINIT;

	ASSIGN(documentPath, aDocumentPath);
	ASSIGN(documentType, [aDocumentPath pathExtension]);
	if (documentPath != nil)
	{
		ASSIGN(documentContent, [NSString stringWithContentsOfFile: aDocumentPath encoding: NSUTF8StringEncoding error: NULL]);
	}
	ASSIGN(templateContent, [NSString stringWithContentsOfFile: aTemplatePath encoding: NSUTF8StringEncoding error: NULL]);
	ASSIGN(menuContent, [NSString stringWithContentsOfFile: finalMenuPath encoding: NSUTF8StringEncoding error: NULL]);

	subheaders = [NSMutableArray new];
	methods = [NSMutableArray new];
	functions = [NSMutableArray new];
	constants = [NSMutableArray new];
	macros = [NSMutableArray new];
	otherDataTypes = [NSMutableArray new];

	return self;
}

- (id) init
{
	return nil;
}

- (void) dealloc
{
	[documentPath release];
	[documentType release];
	[documentContent release];
	[templateContent release];
	[menuContent release];
	[weavedContent release];
	[header release];
	[subheaders release];
	[methods release];
	[functions release];
	[constants release];
	[macros release];
	[otherDataTypes release];
	[super dealloc];
}

- (NSString *) name
{
	if ([header name] != nil)
		return [header name];

	NSString *pageName = [[documentPath lastPathComponent] stringByDeletingPathExtension];
	ETLog(@"WARNING: Found no header page, will use %@ as page name", pageName);
	return pageName;
}

- (void) insert: (NSString *)content forTag: (NSString *)aTag
{
	NSParameterAssert(nil != content);
	NSParameterAssert(nil != weavedContent);

	ASSIGN(weavedContent, [weavedContent stringByReplacingOccurrencesOfString: aTag 
	                                                               withString: content]);
}

- (void) insertHTMLDocument
{
	if ([documentType isEqual: @"html"] == NO)
		return;

	[self insert: documentContent forTag: @"<!-- etoile-document -->"];
}

- (void) insertHeader
{
	if (header == nil)
		return;

	[self insert: [[self HTMLRepresentationForHeader: header] content] 
	      forTag:  @"<!-- etoile-header -->"];
}

- (void) insertSymbolDocumentation
{
	// FIXME: HOM broken on NSString *mainContentStrings = [[[self mainContentHTMLRepresentation] mappedCollection] content];
	// [[mainContentStrings rightFold] stringByAppendingString: @""];
	NSString *content = [[self mainContentHTMLRepresentations] componentsJoinedByString: @""];
	
	if ([content isEqual: @""])
	{
		content = [[P with: [I with: @"No public API available"]] content];
	}
	[self insert: content
	      forTag: @"<!-- etoile-methods -->"];
}

- (void) insertMenu
{
	[self insert: menuContent forTag: @"<!-- etoile-menu -->"];
}

- (void) insertProjectName
{
	[self insert: [[DocIndex currentIndex] projectName] forTag: @"<!-- etoile-project-name -->"];
}

- (void) insertProjectSymbolListOfKind: (NSString *)aKind
{
	DocIndex *docIndex = [DocIndex currentIndex];
	NSArray *symbols = [[docIndex projectSymbolNamesOfKind: aKind]
		sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
	BOOL isCategoryKind = [aKind isEqual: @"categories"];
	NSMutableSet *categoryClassNames = [NSMutableSet set];
	H list = UL;

	FOREACH(symbols, symbol, NSString *)
	{
		NSString *linkName = symbol;

		/* We skip categories which extend the same class than a previous 
		   category added to the list.

		   For NSString(A) and NSString(B), on NSString(A) a link named 
		   'NSString' to 'NSString_Categories.html' or similar will be inserted, 
		   on NSString(B), no link is inserted since NSString(B) belongs to the
		   same 'NSString_Categories.html' page. */
		if (isCategoryKind)
		{
			linkName = [symbol substringToIndex: [symbol rangeOfString: @"("].location];
			if ([categoryClassNames containsObject: linkName])
				continue;
			
			[categoryClassNames addObject: linkName];
		}

		[list and: [LI with: [docIndex linkWithName: linkName forSymbolName: symbol ofKind: aKind]]];
	}

	NSString *blockId = [NSString stringWithFormat: @"project-%@-list", aKind];
 	NSString *templateTag  = [NSString stringWithFormat: @"<!-- etoile-list-%@ -->", aKind];

	[self insert: [[DIV id: blockId with: list] content] 
	      forTag: templateTag];
}

- (void) weave
{
	ASSIGN(weavedContent, templateContent);

	[self insertHeader];
	[self insertHTMLDocument]; /* Additional HTML content */
	[self insertSymbolDocumentation]; /* Classes, methods etc. */

	[self insertMenu];
	[self insertProjectName];
	for (NSString *kind in [NSArray arrayWithObjects: @"classes", @"protocols", @"categories", nil]) //[docIndex symbolKinds])
	{
		[self insertProjectSymbolListOfKind: kind];
	}
}

- (void) writeToURL: (NSURL *)outputURL
{
	[[self HTMLString] writeToURL: outputURL atomically: YES encoding: NSUTF8StringEncoding error: NULL];
}

- (void) setHeader: (DocHeader *)aHeader
{
	ASSIGN(header, aHeader);
}

- (DocHeader *) header
{
	return header;
}

- (ETKeyValuePair *) firstPairWithKey: (NSString *)aKey inArray: (NSArray *)anArray
{
	return [anArray firstObjectMatchingValue: aKey forKey: @"key"];
}

- (void) addElement: (DocElement *)anElement toDictionaryNamed: (NSString *)anIvarName forKey: (NSString *)aKey
{
	NSMutableArray *elements = [self valueForKey: anIvarName];
	NSMutableArray *array = [[self firstPairWithKey: aKey inArray: elements] value];

	if (array == nil)
	{
		array = [NSMutableArray array];
		[elements addObject: [ETKeyValuePair pairWithKey: aKey value: array]];
	}
	[array addObject: anElement];
}

- (void) addElement: (DocElement *)anElement toDictionaryNamed: (NSString *)anIvarName
{
	[self addElement: anElement toDictionaryNamed: anIvarName forKey: [anElement task]];
}

- (void) addSubheader: (DocHeader *)aHeader
{
	[self addElement: aHeader toDictionaryNamed: @"subheaders" forKey: [aHeader group]];
}

- (void) addMethod: (DocMethod *)aMethod
{
	[self addElement: aMethod toDictionaryNamed: @"methods"];
}

- (void) addFunction: (DocFunction *)aFunction
{
	[self addElement: aFunction toDictionaryNamed: @"functions"];
}

- (void) addMacro: (DocMacro *)aMacro
{
	[self addElement: aMacro toDictionaryNamed: @"macros"];
}

- (void) addConstant: (DocConstant *)aConstant
{
	[self addElement: aConstant toDictionaryNamed: @"constants"];
}

- (void) addOtherDataType: (DocCDataType *)anotherDataType
{
	[self addElement: anotherDataType toDictionaryNamed: @"otherDataTypes"];
}

- (NSString *) HTMLString
{
	[self weave];
	return weavedContent;
}

- (DocHTMLElement *) HTMLRepresentationWithTitle: (NSString *)aTitle 
                                     elements: (NSArray *)elementsByGroup
{
	return [self HTMLRepresentationWithTitle: aTitle 
	                                elements: elementsByGroup 
	              HTMLRepresentationSelector: @selector(HTMLRepresentation)
				              groupSeparator: [DocHTMLElement blankElement]];
}

- (NSArray *) mainContentHTMLRepresentations
{
	return [NSArray arrayWithObjects: 
		[self HTMLRepresentationWithTitle: nil elements: methods],
		[self HTMLRepresentationWithTitle: @"Functions" elements: functions],
 		[self HTMLRepresentationWithTitle: @"Macros" elements: macros], 
		[self HTMLRepresentationWithTitle: @"Constants" elements: constants], 
		[self HTMLRepresentationWithTitle: @"Other Data Types" elements: otherDataTypes], nil];
}

- (DocHTMLElement *) HTMLRepresentationForHeader: (DocHeader *)aHeader
{
	return [aHeader HTMLRepresentation];
}

- (DocHTMLElement *) HTMLRepresentationWithTitle: (NSString *)aTitle 
                                     elements: (NSArray *)elementsByGroup
                   HTMLRepresentationSelector: (SEL)repSelector
                               groupSeparator: (DocHTMLElement *)aSeparator
{
	if ([elementsByGroup isEmpty])
		return [DocHTMLElement blankElement];

	NSString *titleWithoutSpaces = [[aTitle componentsSeparatedByCharactersInSet: 
		[NSCharacterSet whitespaceCharacterSet]] componentsJoinedByString: @"-"];
	DocHTMLElement *html = [DIV class: [titleWithoutSpaces lowercaseString]];
	BOOL hasH3 = NO;

	if (aTitle != nil)
	{
		[html add: [H3 with: aTitle]];
		hasH3 = YES;
	}
	
	for (int i = 0; i < [elementsByGroup count]; i++)
	{
		NSString *group = [[elementsByGroup objectAtIndex: i] key];
		NSArray *elementsInGroup = [(ETKeyValuePair *)[elementsByGroup objectAtIndex: i] value];
		DocHTMLElement *hGroup = (hasH3 ? [H4 with: group] : [H3 with: group]);
		BOOL isFirst = (i == 0);

		if (isFirst == NO)
		{
			[html add: aSeparator];
		}
		[html add: hGroup];
		//NSLog(@"HTML Task or Group: %@", hGroup);

		for (DocElement *element in elementsInGroup)
		{
			[html add: [element performSelector: repSelector]];
		}
	}

	return html;
}

@end
