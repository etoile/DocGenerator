/**
	<abstract>Functions in the doc element tree.</abstract>

	Copyright (C) 2008 Nicolas Roard

	Author:  Nicolas Roard
	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  June 2008
	License:  Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <SourceCodeKit/SourceCodeKit.h>
#import "GSDocParser.h"
#import "DocElement.h"

@class DocHTMLElement;

/** @group Doc Element Tree

A DocFunction object represents a function in the documentation element tree. */
@interface DocFunction : DocSubroutine <GSDocParserDelegate>
{

}

/** @taskunit GSDoc Parsing */

/** <override-dummy />
Returns <em>function</em>.

See -[DocElement GSDocElementName]. */
- (NSString *) GSDocElementName;
/** <override-dummy />
Returns -weaveFunction:.

See -[DocElement weaveSelector]. */
- (SEL) weaveSelector;

- (void) parseProgramComponent: (SCKFunction *)aFunction;

@end
