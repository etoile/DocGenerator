/*
	Copyright (C) 2013 Muhammad Hussein Nasrollahpour

	Author:  Muhammad Hussein Nasrollahpour <iapplechocolate@me.com>
	Date:  April 2013
	License:  Modified BSD (see COPYING)
 */

#import "DocSourceCodeParser.h"
#import "DocHeader.h"
#import "DocMethod.h"
#import "DocMacro.h"
#import "DocCDataType.h"
#import "DocIVar.h"
#import "DocProperty.h"

@implementation DocSourceCodeParser

- (id) init
{
	return [self initWithSourceFile: nil additionalParserFiles: [NSArray array]];
}

- (id) initWithSourceFile: (NSString *)aSourceCodePath additionalParserFiles: (NSArray *)additionalFiles
{
	NILARG_EXCEPTION_TEST(aSourceCodePath);

	SUPERINIT;
	sourceCollection = [SCKSourceCollection new];
	sourceFile = (SCKClangSourceFile *)[sourceCollection sourceFileForPath: aSourceCodePath];
	return self;
}

- (void) dealloc
{
	sourceCollection = nil;
	sourceFile = nil;
}

- (void) parseAndWeave
{
	[self parseClassesAndCategories];
	[self parseProtocols];
	[self parseMacros];
	[self parseEnumerations];
	[self parseFunctions];
	[self parseVariables];
}

- (void) parseClassesAndCategories
{
	DocHeader *header = nil;
	
	for (SCKClass *class in [[sourceCollection classes] objectEnumerator])
	{		
		header = [DocHeader new];

		[header setClassName: [class name]];
		[pageWeaver weaveHeader: header];

		[pageWeaver weaveClassNamed: [class name]
		             superclassName: [[class superclass] name]];
		
		for (SCKIvar *ivar in [class ivars])
		{
			DocIVar *docIVar = [DocIVar new];
			[docIVar parseProgramComponent: ivar];
			[pageWeaver weaveIVar: docIVar];
		}
		
		for (SCKProperty *property in [class properties])
		{
			DocProperty *docProperty = [DocProperty new];
			[docProperty parseProgramComponent: property];
			[pageWeaver weaveProperty: docProperty];
		}
		
		for (SCKMethod *method in [class methods])
		{
			DocMethod *docMethod = [DocMethod new];
			[docMethod parseProgramComponent: method];
			[pageWeaver weaveMethod: docMethod];
		}
		
		for (SCKCategory *category in [class categories])
		{
			[pageWeaver weaveCategoryNamed: [category name]
					className: [class name] isInformalProtocol: YES];
			
			// TODO: Enable once supported by SCK
			/*for (SCKProperty *property in [category properties])
			{
				DocProperty *docProperty = [DocProperty new];
				[docProperty parseProgramComponent: property];
				[pageWeaver weaveProperty: docProperty];
			}
			
			for (SCKMethod *method in [category methods])
			{
				DocMethod *docMethod = [DocMethod new];
				[docMethod parseProgramComponent: method];
				[pageWeaver weaveMethod: docMethod];
			}*/
		}
	}
}

- (void) parseProtocols
{
	DocHeader *header = nil;

	for (SCKProtocol *protocol in [[sourceCollection protocols] objectEnumerator])
	{
		[pageWeaver weaveHeader: [DocHeader new]];
		[pageWeaver weaveProtocolNamed: [protocol name]];
		
		for (SCKMethod *method in [protocol requiredMethods])
		{
			DocMethod *docMethod = [DocMethod new];
			[docMethod parseProgramComponent: method];
			[pageWeaver weaveMethod: docMethod];
		}
		
		for (SCKMethod *method in [protocol optionalMethods])
		{
			DocMethod *docMethod = [DocMethod new];
			[docMethod parseProgramComponent: method];
			[pageWeaver weaveMethod: docMethod];
		}
		
		// TODO: Add support for -requiredProperties and -optionalProperties once supported by SCK
	}
}

- (void) parseMacros
{
	for (SCKMacro *macro in [[sourceFile macros] objectEnumerator])
	{
		DocMacro *docMacro = [DocMacro new];
		[docMacro parseProgramComponent: macro];
		[pageWeaver weaveMacro: docMacro];
	}
}

- (void) parseEnumerations
{	
	for (SCKEnumeration *enumeration in [sourceFile enumerations])
	{
		DocConstant *docEnumeration = [DocConstant new];
		[docEnumeration parseProgramComponent: enumeration];
		[pageWeaver weaveConstant: docEnumeration];
	}
	
	for (SCKEnumerationValue *enumValue in [[sourceFile enumerationValues] objectEnumerator])
	{
		DocConstant *docEnumValue = [DocConstant new];
		[docEnumValue parseProgramComponent: enumValue];
		[pageWeaver weaveConstant: docEnumValue];
	}
}

- (void) parseFunctions
{
	/* Static Functions */

	for (SCKFunction *function in [sourceFile functions])
	{		
		DocFunction *docFunction = [DocFunction new];
		[docFunction parseProgramComponent: function];
		[pageWeaver weaveFunction: docFunction];
	}

	/* Global Functions */

	for (SCKFunction *function in [[sourceCollection functions] objectEnumerator])
	{		
		DocFunction *docFunction = [DocFunction new];
		[docFunction parseProgramComponent: function];
		[pageWeaver weaveFunction: docFunction];
	}
}

- (void) parseVariables
{
	/* Global Variables */
	
	for (SCKGlobal *global in [[sourceCollection globals] objectEnumerator])
	{
		DocVariable *docGlobal = [DocVariable new];
		[docGlobal parseProgramComponent: global];
		[pageWeaver weaveOtherDataType: docGlobal];
	}

	// TODO: Parse static variables once supported by SCK
}

- (id <DocWeaving>)weaver
{
	return pageWeaver;
}

- (void)setWeaver: (id <DocWeaving>)aDocWeaver
{
	pageWeaver = aDocWeaver;
}

@end
