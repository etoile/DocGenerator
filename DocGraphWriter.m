#include <stdio.h>
#include <unistd.h>
#include "DocGraphWriter.h"

/*
 * For writing code that supports both libgraph and libcgraph, see 
 * http://www.graphviz.org/dot.demo/example.c 
 */
@implementation DocGraphWriter

- (id) init
{
	self = [super init];

	mNodes = [NSMutableDictionary new];
	mEdges = [NSMutableArray new];

	// NOTE: No need to call aginit() just for libgraph, since we use a context 
	// to support the graph layout, see gvLayout() in -layout.
	mGraphContext = gvContext();
#ifdef WITH_CGRAPH
	mGraph = agopen("g", Agdirected, NULL);
#else
	mGraph = agopen("g", AGDIGRAPH);
#endif
	ETAssert(mGraphContext != NULL);
	ETAssert(mGraph != NULL);

	[self setGraphAttribute: @"rankdir" with: @"BT"];
	[self setGraphAttribute: @"size" with: @"2."];
	[self setGraphAttribute: @"dpi" with: @"72"];

	return self;
}

- (void) dealloc
{
	[self cleanupGraph];
}

- (void) cleanupGraph
{
	gvFreeLayout(mGraphContext, mGraph);
	agclose(mGraph);
	gvFreeContext(mGraphContext);
}

- (void) layout
{
	gvLayout(mGraphContext, mGraph, "dot");
}

- (void) generateFile: (NSString*) path withFormat: (NSString*) format
{
	gvRenderFilename(mGraphContext, mGraph,
		(char*) [format UTF8String], (char*) [path UTF8String]);
}

- (NSString*) generateWithFormat: (NSString*) format
{
	NSFileHandle* handle = [[NSFileManager defaultManager] tempFile];

	FILE* file = fdopen([handle fileDescriptor], "w+");
	gvRender(mGraphContext, mGraph,
		(char*) [format UTF8String], file);

	[handle seekToFileOffset: 0];
	NSData* data = [handle readDataToEndOfFile];
	NSString* str = [[NSString alloc] initWithData: data
				encoding: NSUTF8StringEncoding];

	return str;
}

- (NSValue*) addNode: (NSString*) node
{
	NILARG_EXCEPTION_TEST(node);
	ETAssert(mGraph != NULL);

	NSValue* pointer = [mNodes objectForKey: node];
	if (pointer)
		return pointer;

	//NSLog(@"Add node %@", node);

#ifdef WITH_CGRAPH
	Agnode_t *n = agnode(mGraph, (char*)[node UTF8String], 1);
#else
	Agnode_t *n = agnode(mGraph, (char*)[node UTF8String]);
#endif
	NSValue* value = [NSValue valueWithPointer: n];
	[mNodes setObject: value forKey: node];
	return value;
}

- (void) addEdge: (NSString*) nodeA to: (NSString*) nodeB
{
	NILARG_EXCEPTION_TEST(nodeA);
	NILARG_EXCEPTION_TEST(nodeB);
	ETAssert(mGraph != NULL);

	//NSLog(@"Add edge from %@ to %@", nodeA, nodeB);

	NSValue* A = [self addNode: nodeA];
	NSValue* B = [self addNode: nodeB];
#ifdef WITH_CGRAPH
	agedge(mGraph, [A pointerValue], [B pointerValue], "", 1);
#else
	agedge(mGraph, [A pointerValue], [B pointerValue]);
#endif
}

- (void) setAttribute: (NSString*) attribute
		 with: (NSString*) value
		   on: (NSString*) node
{
	NILARG_EXCEPTION_TEST(attribute);
	NILARG_EXCEPTION_TEST(value);
	NILARG_EXCEPTION_TEST(node);

	NSValue* n = [self addNode: node];
	agsafeset([n pointerValue],
		 (char*) [attribute UTF8String],
		 (char*) [value UTF8String], "");
}

- (void) setGraphAttribute: (NSString*) attribute
	              with: (NSString*) value
{
	NILARG_EXCEPTION_TEST(attribute);
	NILARG_EXCEPTION_TEST(value);
	ETAssert(mGraph != NULL);

	agsafeset(mGraph,
		 (char*) [attribute UTF8String],
		 (char*) [value UTF8String], "");
}

@end
