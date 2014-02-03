/*
	Copyright (C) 2010 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  November 2010
	License:  Modified BSD (see COPYING)
 */

#import "DocIndex.h"
#import "DocElement.h"
#import "DocHeader.h"

@implementation DocIndex

@synthesize projectName, outputDirectory, externalRefs;

static DocIndex *currentIndex = nil;

+ (id) currentIndex
{
	return currentIndex;
}

+ (void) setCurrentIndex: (DocIndex *)anIndex
{
	currentIndex = anIndex;
}

- (id) createRefDictionaryWithMutability: (BOOL)mutable
{
	Class dictClass = (mutable ? [NSMutableDictionary class] : [NSDictionary class]);
	return [[dictClass alloc] initWithObjectsAndKeys: 
		[NSMutableDictionary dictionary], @"classes", 
		[NSMutableDictionary dictionary], @"protocols",
		[NSMutableDictionary dictionary], @"categories", 
		[NSMutableDictionary dictionary], @"methods", 
		[NSMutableDictionary dictionary], @"functions",
		[NSMutableDictionary dictionary], @"macros", 
		[NSMutableDictionary dictionary], @"constants", nil];
}

- (id) init
{
	SUPERINIT;
	projectName = @"Untitled";
	externalRefs = [self createRefDictionaryWithMutability: NO];
	projectRefs = [self createRefDictionaryWithMutability: YES];
	mergedRefs = [self createRefDictionaryWithMutability: YES];
	projectElements = [self createRefDictionaryWithMutability: YES];
   	return self;
}

- (void) dealloc
{
	projectName = nil;
	outputDirectory = nil;
	externalRefs = nil;
	projectRefs = nil;
	mergedRefs = nil;
}

- (void) setProjectName: (NSString *)aName
{
	if (aName == nil)
	{
        projectName = @"Untitled";
	}
	else
	{
        projectName = aName;
	}
}

- (NSString *) ouputDirectory
{
	NSAssert(outputDirectory != nil, @"A valid output directory must be set on the documentation index");
	return outputDirectory;
}

- (void) mergeRefs: (NSDictionary *)otherRefs 
            ofKind: (NSString *)aKind 
          intoRefs: (NSMutableDictionary *)refs
   reportConflicts: (BOOL)warn
withDictionaryName: (NSString *)mergedDictName
{
	NSMutableDictionary *refSubset = [refs objectForKey: aKind];
	NSDictionary *otherRefSubset = [otherRefs objectForKey: aKind];

	for (NSString *symbolName in otherRefSubset)
	{
		if (warn && [refSubset objectForKey: symbolName] != nil)
		{
			ETLog(@"WARNING: Conflict between old ref %@ and new ref %@ "
				"named %@ while merging %@ from %@", [refSubset objectForKey: symbolName],
				[otherRefSubset objectForKey: symbolName] , symbolName, aKind, mergedDictName);
		}

		[refSubset setObject: [otherRefSubset objectForKey: symbolName] 
		              forKey: symbolName];
	}
}

- (void) regenerate
{
	NSArray *refKinds = [self symbolKinds];
	NSArray *refIVarNames = A(@"externalRefs", @"projectRefs");
	
	FOREACH(refKinds, kind, NSString *)
	{
		[[mergedRefs objectForKey: kind] removeAllObjects];
	}

	FOREACH(refIVarNames, dictName, NSString *)
	{
		FOREACH(refKinds, kind, NSString *)
		{
			[self mergeRefs: [self valueForKey: dictName]
			         ofKind: kind
			       intoRefs: mergedRefs
			reportConflicts: YES
		 withDictionaryName: dictName];	
		}
	}
}

- (void) setProjectRef: (NSString *)aRef
         forSymbolName: (NSString *)aSymbol
                ofKind: (NSString *)aKind
{
	/* Don't accept external refs */
	ETAssert([aRef hasSuffix: [self refFileExtension]] == NO);

	NSString *finalRef = [aRef stringByAppendingPathExtension: [self refFileExtension]];
	[[projectRefs objectForKey: aKind] setObject: finalRef forKey: aSymbol];
}

- (NSArray *) projectSymbolNamesOfKind: (NSString *)aKind
{
	return [[projectRefs objectForKey: aKind] allKeys];
}

- (NSArray *) symbolKinds
{
	return A(@"classes", @"protocols", @"categories", @"methods", 
		@"functions", @"macros", @"constants");
}

- (NSString *) linkWithName: (NSString *)aName ref: (NSString *)aRef
{
	return aName;
}

- (NSString *) linkForSymbolName: (NSString *)aSymbol ofKind: (NSString *)aKind
{
	return [self linkWithName: aSymbol forSymbolName: aSymbol ofKind: aKind];
}

- (NSString *) linkWithName: (NSString *)aName forSymbolName: (NSString *)aSymbol ofKind: (NSString *)aKind
{
	NSString *kind = (aKind != nil ? aKind : @"classes"); // FIXME: Should be @"symbols");
	return [self linkWithName: aName
	                      ref: [[mergedRefs objectForKey: kind] objectForKey: aSymbol]
	                   anchor: aSymbol];
}

- (NSString *) linkForClassName: (NSString *)aClassName
{
	return [self linkWithName: aClassName
	                      ref: [[mergedRefs objectForKey: @"classes"] objectForKey: aClassName]
	                   anchor: aClassName];
}

- (NSString *) linkForProtocolName: (NSString *)aProtocolName
{
	return [self linkWithName: aProtocolName
	                      ref: [[mergedRefs objectForKey: @"protocols"] objectForKey: aProtocolName]
	                   anchor: aProtocolName];
}

- (NSString *) linkForGSDocRef: (NSString *)aRef
{
	return nil;
}

- (id) elementForOwnerSymbolName: (NSString *)anOwnerSymbol
{
	DocElement *element = [self elementForSymbolName: anOwnerSymbol
	                                          ofKind: @"classes"];

	if (element != nil)
		return element;

	element = [self elementForSymbolName: anOwnerSymbol
	                              ofKind: @"protocols"];

	if (element != nil)
		return element;

	element = [self elementForSymbolName: anOwnerSymbol
	                              ofKind: @"categories"];

	return element;
}

- (NSString *) linkForLocalAdoptedProtocolMethodRef: (NSString *)aRef
                                      inMethodOwner: (DocHeader *)methodOwner
{
	NSParameterAssert([methodOwner isKindOfClass: [DocHeader class]]);

	for (NSString *protocolName in [methodOwner adoptedProtocolNames])
	{
		DocHeader *protocol = [self elementForSymbolName: protocolName
		                                          ofKind: @"protocols"];

		NSString *symbol = [NSString stringWithFormat: @"%@[%@ %@]",
			[aRef substringToIndex: 1], [protocol ownerSymbolName], [aRef substringFromIndex: 1]];
		NSString *link = [self linkWithName: aRef
		                      forSymbolName: symbol
		                             ofKind: @"methods"];

		if ([link isEqualToString: aRef] == NO)
			return link;
	}

	return aRef;
}

/** For a DocHeader representing a protocol as methodOwner, returns immediately. */
- (NSString *) linkForLocalSuperclassMethodRef: (NSString *)aRef
                                 inMethodOwner: (DocHeader *)methodOwner
{
	NSParameterAssert([methodOwner isKindOfClass: [DocHeader class]]);
	BOOL isClass = ([methodOwner className] == nil);

	if (isClass == NO)
		return aRef;

	NSString *superclassName = [methodOwner superclassName];

	while (superclassName != nil)
	{
		DocHeader *class = [self elementForSymbolName: superclassName
		                                       ofKind: @"classes"];

		NSString *symbol = [NSString stringWithFormat: @"%@[%@ %@]",
			[aRef substringToIndex: 1], [class ownerSymbolName], [aRef substringFromIndex: 1]];
		NSString *link = [self linkWithName: aRef
		                      forSymbolName: symbol
		                             ofKind: @"methods"];

		if ([link isEqualToString: aRef] == NO)
			return link;
			
		superclassName = [class superclassName];
	}

	return aRef;
}

// NOTE: Could be better to pass -ownerSymbolName result to relativeTo:, but 
// we would lost the context to report a warning.
- (NSString *) linkForLocalMethodRef: (NSString *)aRef relativeTo: (DocElement *)anElement
{
	if ([anElement ownerSymbolName] == nil)
	{
		ETLog(@"WARNING: %@ cannot be resolved in %@ (ownerSymbolName is nil)", aRef, anElement);
		return aRef;
	}

	/* For a protocol, ownerSymbolName == '(ProtocolName)'. 
	   For a category, ownerSymbolName == 'ClassName(CategoryName)'. */
	NSString *symbol = [NSString stringWithFormat: @"%@[%@ %@]", 
		[aRef substringToIndex: 1], [anElement ownerSymbolName], [aRef substringFromIndex: 1]];
	NSString *link = [self linkWithName: aRef
	                      forSymbolName: symbol
	                             ofKind: @"methods"];

	if ([link isEqualToString: aRef] == NO)
		return link;

	DocHeader *methodOwner =
		[self elementForOwnerSymbolName: [anElement ownerSymbolName]];

	link = [self linkForLocalAdoptedProtocolMethodRef: aRef
	                                    inMethodOwner: methodOwner];
	
	if ([link isEqualToString: aRef] == NO)
		return link;
		
	return [self linkForLocalSuperclassMethodRef: aRef
	                               inMethodOwner: methodOwner];
}

- (NSString *) linkWithName: (NSString *)aName ref: (NSString *)aRef anchor: (NSString *)anAnchor
{
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (NSString *) refFileExtension
{
	return nil;
}

- (id) elementForSymbolName: (NSString *)aSymbol
                     ofKind: (NSString *)aKind
{
	return [[projectElements objectForKey: aKind] objectForKey: aSymbol];
}

- (void) setElement: (DocElement *)anElement
      forSymbolName: (NSString *)aSymbol
             ofKind: (NSString *)aKind
{
	[[projectElements objectForKey: aKind] setObject: anElement forKey: aSymbol];
}

@end


@implementation DocHTMLIndex

- (NSString *) linkWithName: (NSString *)aName ref: (NSString *)aRef anchor: (NSString *)anAnchor
{
	if (aRef == nil)
		return aName;

	if (anAnchor != nil && [anAnchor isEqualToString: @""] == NO)
	{
		return [NSString stringWithFormat: @"<a href=\"%@#%@\">%@</a>", aRef, 
			[anAnchor stringByReplacingOccurrencesOfString: @" " withString: @"_"], aName];
	}
	else
	{
		return [NSString stringWithFormat: @"<a href=\"%@\">%@</a>", aRef, aName];	
	}
}

- (NSString *) refFileExtension
{
	return @"html";
}


@end

