//
//  SBViewController.m
//  Submariner
//
//  Created by Rafaël Warnault on 06/06/11.
//
//  Copyright (c) 2011-2014, Rafaël Warnault
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  * Neither the name of the Read-Write.fr nor the names of its
//  contributors may be used to endorse or promote products derived from
//  this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "SBViewController.h"

#import "SBDatabaseController.h"
#import "SBTrack.h"
#import "SBSubsonicDownloadOperation.h"
#import "NSOperationQueue+Shared.h"

@implementation SBViewController

@synthesize managedObjectContext;


#pragma mark -
#pragma mark Class Methods

+ (NSString *)nibName {
    return nil;
}



#pragma mark -
#pragma mark Lifecycle

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context
{
    self = [super initWithNibName:[[self class] nibName] bundle:nil];
    if (self) {
        managedObjectContext = context;
    }
    return self;
}


#pragma mark -
#pragma mark Library View Helper Functions

-(void)showTracksInFinder:(NSArray*)trackList selectedIndices:(NSIndexSet*)indexSet
{
    NSMutableArray *tracks = [NSMutableArray array];
    
    __block NSInteger remoteOnly = 0;
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        SBTrack *track = [trackList objectAtIndex:idx];
        // handle remote but cached tracks
        if (track.localTrack != nil) {
            track = track.localTrack;
        } else if (track.isLocalValue == NO) {
            remoteOnly++;
            return;
        }
        NSURL *trackURL = [NSURL fileURLWithPath: track.path];
        [tracks addObject: trackURL];
    }];
    
    if ([tracks count] > 0) {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: tracks];
    }
    if (remoteOnly > 0) {
        NSAlert *oops = [[NSAlert alloc] init];
        oops.messageText = @"Some tracks couldn't be shown in Finder";
        oops.informativeText = @"If the remote track isn't cached, it only exists on the server, and not the filesystem.";
        oops.alertStyle = NSAlertStyleInformational;
        [oops addButtonWithTitle: @"OK"];
        [oops beginSheetModalForWindow: self.view.window completionHandler: ^(NSModalResponse response) {}];
    }
}

-(void)downloadTracks:(NSArray*)trackList selectedIndices:(NSIndexSet*)indexSet databaseController:(SBDatabaseController*)databaseController
{
    __block NSInteger downloaded = 0;
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        SBTrack *track = [trackList objectAtIndex:idx];
        // Check if we've already downloaded this track.
        if (track.localTrack != nil || track.isLocalValue == YES) {
            return;
        }
        
        SBSubsonicDownloadOperation *op = [[SBSubsonicDownloadOperation alloc] initWithManagedObjectContext:self.managedObjectContext];
        [op setTrackID:[track objectID]];
        
        [[NSOperationQueue sharedDownloadQueue] addOperation:op];
        downloaded++;
    }];
    if (databaseController != nil && downloaded > 0) {
        [databaseController showDownloadView];
    }
}


@end
