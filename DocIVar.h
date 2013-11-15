/**
    Copyright (C) 2013 Muhammad Hussein Nasrollahpour
 
    Author:  Muhammad Hussein Nasrollahpour <iapplechocolate@me.com>
    Date:  September 2013
    License:  Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <SourceCodeKit/SourceCodeKit.h>
#import "DocElement.h"

@interface DocIVar : DocElement
{
	@private
	NSString *typeEncoding;
}

@property NSString *typeEncoding;

- (void)parseProgramComponent: (SCKIvar *)anIVar;

@end
