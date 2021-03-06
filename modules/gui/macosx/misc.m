/*****************************************************************************
 * misc.m: code not specific to vlc
 *****************************************************************************
 * Copyright (C) 2003-2015 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Jon Lech Johansen <jon-vl@nanocrew.net>
 *          Felix Paul Kühne <fkuehne at videolan dot org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#import "CompatibilityFixes.h"
#import "misc.h"
#import "VLCMain.h"                                          /* VLCApplication */
#import "VLCMainWindow.h"
#import "VLCMainMenu.h"
#import "VLCControlsBarCommon.h"
#import "VLCCoreInteraction.h"
#import <vlc_keys.h>

/*****************************************************************************
 * VLCDragDropView
 *****************************************************************************/

@implementation VLCDropDisabledImageView

- (void)awakeFromNib
{
    [self unregisterDraggedTypes];
}

@end

/*****************************************************************************
 * VLCDragDropView
 *****************************************************************************/

@interface VLCDragDropView()
{
    bool b_activeDragAndDrop;
}
@end

@implementation VLCDragDropView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // default value
        [self setDrawBorder:YES];
    }

    return self;
}

- (void)enablePlaylistItems
{
    [self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, @"VLCPlaylistItemPboardType", nil]];
}

- (BOOL)mouseDownCanMoveWindow
{
    return YES;
}

- (void)dealloc
{
    [self unregisterDraggedTypes];
}

- (void)awakeFromNib
{
    [self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    if ((NSDragOperationGeneric & [sender draggingSourceOperationMask]) == NSDragOperationGeneric) {
        b_activeDragAndDrop = YES;
        [self setNeedsDisplay:YES];

        return NSDragOperationCopy;
    }

    return NSDragOperationNone;
}

- (void)draggingEnded:(id < NSDraggingInfo >)sender
{
    b_activeDragAndDrop = NO;
    [self setNeedsDisplay:YES];
}

- (void)draggingExited:(id < NSDraggingInfo >)sender
{
    b_activeDragAndDrop = NO;
    [self setNeedsDisplay:YES];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    BOOL b_returned;

    if (_dropHandler && [_dropHandler respondsToSelector:@selector(performDragOperation:)])
        b_returned = [_dropHandler performDragOperation:sender];
    else // default
        b_returned = [[VLCCoreInteraction sharedInstance] performDragOperation:sender];

    [self setNeedsDisplay:YES];
    return b_returned;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    if ([self drawBorder] && b_activeDragAndDrop) {
        NSRect frameRect = [self bounds];

        [[NSColor selectedControlColor] set];
        NSFrameRectWithWidthUsingOperation(frameRect, 2., NSCompositeSourceOver);
    }

    [super drawRect:dirtyRect];
}

@end


/*****************************************************************************
 * VLCVolumeSliderCommon
 *****************************************************************************/

@implementation VLCVolumeSliderCommon : NSSlider

- (void)scrollWheel:(NSEvent *)o_event
{
    BOOL b_up = NO;
    CGFloat f_deltaY = [o_event deltaY];
    CGFloat f_deltaX = [o_event deltaX];

    if ([o_event isDirectionInvertedFromDevice])
        f_deltaX = -f_deltaX; // optimisation, actually double invertion of f_deltaY here
    else
        f_deltaY = -f_deltaY;

    // positive for left / down, negative otherwise
    CGFloat f_delta = f_deltaX + f_deltaY;
    CGFloat f_abs;

    if (f_delta > 0.0f)
        f_abs = f_delta;
    else {
        b_up = YES;
        f_abs = -f_delta;
    }

    for (NSUInteger i = 0; i < (int)(f_abs/4.+1.) && f_abs > 0.05 ; i++) {
        if (b_up)
            [[VLCCoreInteraction sharedInstance] volumeUp];
        else
            [[VLCCoreInteraction sharedInstance] volumeDown];
    }
}

- (void)drawFullVolumeMarker
{
    CGFloat maxAudioVol = self.maxValue / AOUT_VOLUME_DEFAULT;
    if (maxAudioVol < 1.)
        return;

    NSColor *drawingColor;
    // for bright artwork, a black color is used and vice versa
    if (_usesBrightArtwork)
        drawingColor = [[NSColor blackColor] colorWithAlphaComponent:.4];
    else
        drawingColor = [[NSColor whiteColor] colorWithAlphaComponent:.4];

    NSBezierPath* bezierPath = [NSBezierPath bezierPath];
    [self drawFullVolBezierPath:bezierPath];
    [bezierPath closePath];

    bezierPath.lineWidth = 1.;
    [drawingColor setStroke];
    [bezierPath stroke];
}

- (CGFloat)fullVolumePos
{
    CGFloat maxAudioVol = self.maxValue / AOUT_VOLUME_DEFAULT;
    CGFloat sliderRange = [self frame].size.width - [self knobThickness];
    CGFloat sliderOrigin = [self knobThickness] / 2.;

    return 1. / maxAudioVol * sliderRange + sliderOrigin;
}

- (void)drawFullVolBezierPath:(NSBezierPath*)bezierPath
{
    CGFloat fullVolPos = [self fullVolumePos];
    [bezierPath moveToPoint:NSMakePoint(fullVolPos, [self frame].size.height - 3.)];
    [bezierPath lineToPoint:NSMakePoint(fullVolPos, 2.)];
}

@end

@implementation VolumeSliderCell

- (BOOL)continueTracking:(NSPoint)lastPoint at:(NSPoint)currentPoint inView:(NSView *)controlView
{
    VLCVolumeSliderCommon *o_slider = (VLCVolumeSliderCommon *)controlView;
    CGFloat fullVolumePos = [o_slider fullVolumePos] + 2.;

    CGPoint snapToPoint = currentPoint;
    if (ABS(fullVolumePos - currentPoint.x) <= 4.)
        snapToPoint.x = fullVolumePos;

    return [super continueTracking:lastPoint at:snapToPoint inView:controlView];
}

@end

/*****************************************************************************
 * ITSlider
 *****************************************************************************/

@interface ITSlider()
{
    NSImage *img;
    NSRect image_rect;
}
@end

@implementation ITSlider

- (void)awakeFromNib
{
    BOOL b_dark = config_GetInt( getIntf(), "macosx-interfacestyle" );
    if (b_dark)
        img = imageFromRes(@"volume-slider-knob_dark");
    else
        img = imageFromRes(@"volume-slider-knob");

    image_rect.size = [img size];
    image_rect.origin.x = 0;

    if (b_dark)
        image_rect.origin.y = -1;
    else
        image_rect.origin.y = 0;
}

- (void)drawKnobInRect:(NSRect)knobRect
{
    knobRect.origin.x += (knobRect.size.width - image_rect.size.width) / 2;
    knobRect.size.width = image_rect.size.width;
    knobRect.size.height = image_rect.size.height;
    [img drawInRect:knobRect fromRect:image_rect operation:NSCompositeSourceOver fraction:1];
}

- (void)drawRect:(NSRect)rect
{
    /* Draw default to make sure the slider behaves correctly */
    [[NSGraphicsContext currentContext] saveGraphicsState];
    NSRectClip(NSZeroRect);
    [super drawRect:rect];
    [[NSGraphicsContext currentContext] restoreGraphicsState];

    [self drawFullVolumeMarker];

    NSRect knobRect = [[self cell] knobRectFlipped:NO];
    knobRect.origin.y+=2;
    [self drawKnobInRect: knobRect];
}

@end

/*****************************************************************************
 * VLCMainWindowSplitView implementation
 *****************************************************************************/
@implementation VLCMainWindowSplitView : NSSplitView

// Custom color for the dividers
- (NSColor *)dividerColor
{
    return [NSColor colorWithCalibratedRed:.60 green:.60 blue:.60 alpha:1.];
}

// Custom thickness for the divider
- (CGFloat)dividerThickness
{
    return 1.0;
}

@end

/*****************************************************************************
 * VLCThreePartImageView interface
 *****************************************************************************/

@interface VLCThreePartImageView()
{
    NSImage *_left_img;
    NSImage *_middle_img;
    NSImage *_right_img;
}
@end

@implementation VLCThreePartImageView

- (void)setImagesLeft:(NSImage *)left middle: (NSImage *)middle right:(NSImage *)right
{
    _left_img = left;
    _middle_img = middle;
    _right_img = right;
}

- (void)drawRect:(NSRect)rect
{
    NSRect bnds = [self bounds];
    NSDrawThreePartImage( bnds, _left_img, _middle_img, _right_img, NO, NSCompositeSourceOver, 1, NO );
}

@end

@interface PositionFormatter()
{
    NSCharacterSet *o_forbidden_characters;
}
@end

@implementation PositionFormatter

- (id)init
{
    self = [super init];
    NSMutableCharacterSet *nonNumbers = [[[NSCharacterSet decimalDigitCharacterSet] invertedSet] mutableCopy];
    [nonNumbers removeCharactersInString:@"-:"];
    o_forbidden_characters = [nonNumbers copy];

    return self;
}

- (NSString*)stringForObjectValue:(id)obj
{
    if([obj isKindOfClass:[NSString class]])
        return obj;
    if([obj isKindOfClass:[NSNumber class]])
        return [obj stringValue];

    return nil;
}

- (BOOL)getObjectValue:(id*)obj forString:(NSString*)string errorDescription:(NSString**)error
{
    *obj = [string copy];
    return YES;
}

- (BOOL)isPartialStringValid:(NSString*)partialString newEditingString:(NSString**)newString errorDescription:(NSString**)error
{
    if ([partialString rangeOfCharacterFromSet:o_forbidden_characters options:NSLiteralSearch].location != NSNotFound) {
        return NO;
    } else {
        return YES;
    }
}

@end

@implementation NSView (EnableSubviews)

- (void)enableSubviews:(BOOL)b_enable
{
    for (NSView *o_view in [self subviews]) {
        [o_view enableSubviews:b_enable];

        // enable NSControl
        if ([o_view respondsToSelector:@selector(setEnabled:)]) {
            [(NSControl *)o_view setEnabled:b_enable];
        }
        // also "enable / disable" text views
        if ([o_view respondsToSelector:@selector(setTextColor:)]) {
            if (b_enable == NO) {
                [(NSTextField *)o_view setTextColor:[NSColor disabledControlTextColor]];
            } else {
                [(NSTextField *)o_view setTextColor:[NSColor controlTextColor]];
            }
        }

    }
}

@end

/*****************************************************************************
 * VLCByteCountFormatter addition
 *****************************************************************************/

@implementation VLCByteCountFormatter

+ (NSString *)stringFromByteCount:(long long)byteCount countStyle:(NSByteCountFormatterCountStyle)countStyle
{
    // Use native implementation on >= mountain lion
    Class byteFormatterClass = NSClassFromString(@"NSByteCountFormatter");
    if (byteFormatterClass && [byteFormatterClass respondsToSelector:@selector(stringFromByteCount:countStyle:)]) {
        return [byteFormatterClass stringFromByteCount:byteCount countStyle:NSByteCountFormatterCountStyleFile];
    }

    float devider = 0.;
    float returnValue = 0.;
    NSString *suffix;

    NSNumberFormatter *theFormatter = [[NSNumberFormatter alloc] init];
    [theFormatter setLocale:[NSLocale currentLocale]];
    [theFormatter setAllowsFloats:YES];

    NSString *returnString = @"";

    if (countStyle != NSByteCountFormatterCountStyleDecimal)
        devider = 1024.;
    else
        devider = 1000.;

    if (byteCount < 1000) {
        returnValue = byteCount;
        suffix = _NS("B");
        [theFormatter setMaximumFractionDigits:0];
        goto end;
    }

    if (byteCount < 1000000) {
        returnValue = byteCount / devider;
        suffix = _NS("KB");
        [theFormatter setMaximumFractionDigits:0];
        goto end;
    }

    if (byteCount < 1000000000) {
        returnValue = byteCount / devider / devider;
        suffix = _NS("MB");
        [theFormatter setMaximumFractionDigits:1];
        goto end;
    }

    [theFormatter setMaximumFractionDigits:2];
    if (byteCount < 1000000000000) {
        returnValue = byteCount / devider / devider / devider;
        suffix = _NS("GB");
        goto end;
    }

    returnValue = byteCount / devider / devider / devider / devider;
    suffix = _NS("TB");

end:
    returnString = [NSString stringWithFormat:@"%@ %@", [theFormatter stringFromNumber:[NSNumber numberWithFloat:returnValue]], suffix];

    return returnString;
}

@end
