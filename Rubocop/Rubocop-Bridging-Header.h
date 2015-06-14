//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import <Cocoa/Cocoa.h>

#define opaque int8_t

bool runRubocopEnabled (void* document, NSString* scopeAttributes);

@interface OakTextView : NSView

@property(readonly) void* rubocop_document;

- (NSString*) scopeAttributes;
- (BOOL) hasDocument;
- (void) clearAllMarks;
- (void) appendMark:(NSString*)data line:(NSUInteger)aLine;
- (BOOL) isOnDisk;
- (NSString*) dirName;
- (void) writeContent:(const char*)path;

@end