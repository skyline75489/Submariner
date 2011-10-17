/*
 
 File:		ImageBrowserView.m
 
 Abstract:	IKImageBrowserView is a view that can display and browse a 
 large amount of images and movies. This sample code demonstrates 
 how to use the view in a Cocoa Application.
 
 Version:	1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the
 following terms, and your use, installation, modification or
 redistribution of this Apple software constitutes acceptance of these
 terms.  If you do not agree with these terms, please do not use,
 install, modify or redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software. 
 Neither the name, trademarks, service marks or logos of Apple Inc.
 may be used to endorse or promote products derived from the Apple
 Software without specific prior written permission from Apple.  Except
 as expressly stated in this notice, no other rights or licenses, express
 or implied, are granted by Apple herein, including but not limited to
 any patent rights that may be infringed by your derivative works or by
 other works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright © 2009 Apple Inc. All Rights Reserved
 
 */

#import "SBImageBrowserView.h"
#import "SBImageBrowserCell.h"
#import "SBImageBrowserBackgroundLayer.h"

@implementation SBImageBrowserView


- (void)awakeFromNib {
    // album browser
    SBImageBrowserBackgroundLayer *backgroundLayer = [[[SBImageBrowserBackgroundLayer alloc] init] autorelease];
	[self setBackgroundLayer:backgroundLayer];
	backgroundLayer.owner = self;
    
    // shadow
    NSShadow *unselectedShadow = [[[NSShadow alloc] init] autorelease];
    [unselectedShadow setShadowColor:[NSColor lightGrayColor]];
    [unselectedShadow setShadowBlurRadius:0.0f];
    [unselectedShadow setShadowOffset:NSMakeSize(0.f, -1.f)];
    
    NSShadow *selectedShadow = [[[NSShadow alloc] init] autorelease];
    [selectedShadow setShadowColor:[NSColor darkGrayColor]];
    [selectedShadow setShadowBlurRadius:0.0f];
    [selectedShadow setShadowOffset:NSMakeSize(0.f, -1.f)];
    
    // create a centered paragraph style
	NSMutableParagraphStyle *paraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
	[paraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
	[paraphStyle setAlignment:NSCenterTextAlignment];
	
	NSMutableDictionary *attributes = [[[NSMutableDictionary alloc] init] autorelease];	
	[attributes setObject:[NSFont systemFontOfSize:11] forKey:NSFontAttributeName]; 
	[attributes setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
    [attributes setObject:unselectedShadow forKey:NSShadowAttributeName];
	[self setValue:attributes forKey:IKImageBrowserCellsTitleAttributesKey];
	    
	attributes = [[[NSMutableDictionary alloc] init] autorelease];	
	[attributes setObject:[NSFont boldSystemFontOfSize:11] forKey:NSFontAttributeName]; 
	[attributes setObject:selectedShadow forKey:NSShadowAttributeName];
	[attributes setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	
	[self setValue:attributes forKey:IKImageBrowserCellsHighlightedTitleAttributesKey];	
    
    //change intercell spacing
	[self setIntercellSpacing:NSMakeSize(20, 20)];
    
	//set initial zoom value
	[self setZoomValue:0.99999];
}

//---------------------------------------------------------------------------------
// newCellForRepresentedItem:
//
// Allocate and return our own cell class for the specified item. The returned cell must not be autoreleased 
//---------------------------------------------------------------------------------
- (IKImageBrowserCell *) newCellForRepresentedItem:(id) cell
{
	return [[SBImageBrowserCell alloc] init];
}

//---------------------------------------------------------------------------------
// drawRect:
//
// override draw rect and force the background layer to redraw if the view did resize or did scroll 
//---------------------------------------------------------------------------------
- (void) drawRect:(NSRect) rect
{
	//retrieve the visible area
	NSRect visibleRect = [self visibleRect];
	
	//compare with the visible rect at the previous frame
	if(!NSEqualRects(visibleRect, lastVisibleRect)){
		//we did scroll or resize, redraw the background
		[[self backgroundLayer] setNeedsDisplay];
		
		//update last visible rect
		lastVisibleRect = visibleRect;
	}
    
	[super drawRect:rect];
}

@end
