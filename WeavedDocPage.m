/*
	Copyright (C) 2008 Nicolas Roard

	Authors:  Nicolas Roard, 
	          Quentin Mathe <quentin.mathe@gmail.com>
	Date:  June 2008
	License:  Modified BSD (see COPYING)
 */

#import "WeavedDocPage.h"
#import "DocHeader.h"
#import "DocCDataType.h"
#import "DocFunction.h"
#import "DocIndex.h"
#import "DocMacro.h"
#import "DocMethod.h"
#import "GSDocParser.h"
#import "HtmlElement.h"


@implementation WeavedDocPage

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

	subheaders = [NSMutableDictionary new];
	classMethods = [NSMutableDictionary new];
	instanceMethods = [NSMutableDictionary new];
	functions = [NSMutableDictionary new];
	constants = [NSMutableDictionary new];
	macros = [NSMutableDictionary new];
	otherDataTypes = [NSMutableDictionary new];

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
	[classMethods release];
	[instanceMethods release];
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
	[self insert: [[self mainContentHTMLRepresentations] componentsJoinedByString: @""]
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
	NSArray *symbolNames = [[docIndex projectSymbolNamesOfKind: aKind]
		sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
	H list = UL;

	FOREACH(symbolNames, name, NSString *)
	{
		[list and: [LI with: [docIndex linkForSymbolName: name ofKind: aKind]]];
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

- (void) addElement: (DocElement *)anElement toDictionaryNamed: (NSString *)anIvarName forKey: (NSString *)aKey
{
	NSMutableDictionary *elements = [self valueForKey: anIvarName];
	NSMutableArray *array = [elements objectForKey: aKey];

	if (array == nil)
	{
		array = [NSMutableArray array];
		[elements setObject: array forKey: aKey];
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

- (void) addClassMethod: (DocMethod *)aMethod
{
	[self addElement: aMethod toDictionaryNamed: @"classMethods"];
}

- (void) addInstanceMethod: (DocMethod *)aMethod
{
	[self addElement: aMethod toDictionaryNamed: @"instanceMethods"];
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

- (NSDictionary *) methods
{
	NSMutableDictionary *methods = [NSMutableDictionary dictionaryWithDictionary: instanceMethods];
	[methods addEntriesFromDictionary: classMethods];
	return methods;
}

- (HtmlElement *) HTMLRepresentationWithTitle: (NSString *)aTitle 
                                  subroutines: (NSDictionary *)subroutinesByTask
{
	return [self HTMLRepresentationWithTitle: aTitle 
	                             subroutines: subroutinesByTask 
	              HTMLRepresentationSelector: @selector(HTMLRepresentation)];
}

- (NSArray *) mainContentHTMLRepresentations
{
	return [NSArray arrayWithObjects: 
		[self HTMLRepresentationWithTitle: nil subroutines: [self methods]],
		[self HTMLRepresentationWithTitle: @"Functions" subroutines: functions],
 		[self HTMLRepresentationWithTitle: @"Macros" subroutines: macros], 
		[self HTMLRepresentationWithTitle: @"Constants" subroutines: constants], 
		[self HTMLRepresentationWithTitle: @"Other Data Types" subroutines: otherDataTypes], nil];
}

- (HtmlElement *) HTMLRepresentationForHeader: (DocHeader *)aHeader
{
	return [aHeader HTMLRepresentation];
}

- (HtmlElement *) HTMLRepresentationWithTitle: (NSString *)aTitle 
                                  subroutines: (NSDictionary *)subroutinesByTask
                   HTMLRepresentationSelector: (SEL)repSelector
{
	if ([subroutinesByTask isEmpty])
		return [HtmlElement blankElement];

	NSArray *unsortedTasks = [subroutinesByTask allKeys];
	NSArray *tasks = [unsortedTasks sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];
	NSString *titleWithoutSpaces = [[aTitle componentsSeparatedByCharactersInSet: 
		[NSCharacterSet whitespaceCharacterSet]] componentsJoinedByString: @"-"];
	HtmlElement *html = [DIV class: [titleWithoutSpaces lowercaseString]];
	BOOL hasH3 = NO;

	if (aTitle != nil)
	{
		[html add: [H3 with: aTitle]];
		hasH3 = YES;
	}
	
	for (NSString *task in tasks)
	{
		HtmlElement *hTask = (hasH3 ? [H4 with: task] : [H3 with: task]);

		[html add: hTask];
		NSLog(@"HTML Task: %@", hTask);
		NSArray *subroutinesInTask = [subroutinesByTask objectForKey: task];
			//sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)];

		for (DocSubroutine *subroutine in subroutinesInTask)
		{
			[html add: [subroutine performSelector: repSelector]];
		}
	}

	return html;
}

@end
