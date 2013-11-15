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

@interface DocProperty : DocElement
{
	@private
	NSString *attributes;
}

@property NSString *attributes;

- (void)parseProgramComponent: (SCKProperty *)aProperty;

@end
