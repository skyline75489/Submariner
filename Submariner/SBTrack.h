#import <Cocoa/Cocoa.h>
#import "_SBTrack.h"

@interface SBTrack : _SBTrack {
    NSString *durationString;
    NSString *artistString;
    NSString *albumString;
    NSImage *playingImage;
    NSImage *coverImage;
    NSImage *onlineImage;
    NSDictionary *movieAttributes;
}

@property (readonly) NSString *durationString;
@property (readonly) NSString *artistString;
@property (readonly) NSString *albumString;
@property (readonly) NSImage *playingImage;
@property (readonly) NSImage *coverImage;
@property (readonly) NSImage *onlineImage;
@property (readonly) NSDictionary *movieAttributes;

- (NSURL *)streamURL;
- (NSURL *)downloadURL;

- (BOOL)isVideo;

@end
