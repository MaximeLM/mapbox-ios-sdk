//
//  RMMapOverlayView.m
//  MapView
//
// Copyright (c) 2008-2013, Route-Me Contributors
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice, this
//   list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#import "RMMapOverlayView.h"
#import "RMMarker.h"
#import "RMAnnotation.h"
#import "RMPixel.h"
#import "RMMapView.h"
#import "RMUserLocation.h"

@implementation RMMapOverlayView

+ (Class)layerClass
{
    return [CAScrollLayer class];
}

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame]))
        return nil;

    self.layer.masksToBounds = NO;

    return self;
}

- (NSUInteger)sublayersCount
{
    return [self.layer.sublayers count];
}

- (void)addSublayer:(CALayer *)aLayer
{
    [self.layer addSublayer:aLayer];
}

- (void)insertSublayer:(CALayer *)aLayer atIndex:(unsigned)index
{
    [self.layer insertSublayer:aLayer atIndex:index];
}

- (void)insertSublayer:(CALayer *)aLayer below:(CALayer *)sublayer
{
    [self.layer insertSublayer:aLayer below:sublayer];
}

- (void)insertSublayer:(CALayer *)aLayer above:(CALayer *)sublayer
{
    [self.layer insertSublayer:aLayer above:sublayer];
}

- (void)moveLayersBy:(CGPoint)delta
{
    [self.layer scrollPoint:CGPointMake(-delta.x, -delta.y)];
}

- (CALayer *)overlayHitTest:(CGPoint)point
{
    RMMapView *mapView = ((RMMapView *)self.superview);

    // Here we be sure to hide disabled but visible annotations' layers to
    // avoid touch events, then re-enable them after scoring the hit. We
    // also show the user location if enabled and we're in tracking mode,
    // since its layer is hidden and we want a possible hit. 
    //
    NSPredicate *annotationPredicate = [NSPredicate predicateWithFormat:@"SELF.enabled = NO AND SELF.layer != %@ AND SELF.layer.isHidden = NO", [NSNull null]];

    NSArray *disabledVisibleAnnotations = [mapView.annotations filteredArrayUsingPredicate:annotationPredicate];

    for (RMAnnotation *annotation in disabledVisibleAnnotations)
        annotation.layer.hidden = YES;

    BOOL userLocationHidden = mapView.userLocation.layer.hidden;
    
    if (mapView.userLocation.enabled && mapView.userTrackingMode == RMUserTrackingModeFollowWithHeading && userLocationHidden)
        mapView.userLocation.layer.hidden = NO;

    CALayer *hit = [self.layer hitTest:point];

    if (mapView.userLocation.enabled && mapView.userTrackingMode == RMUserTrackingModeFollowWithHeading && userLocationHidden)
        mapView.userLocation.layer.hidden = YES;

    for (RMAnnotation *annotation in disabledVisibleAnnotations)
        annotation.layer.hidden = NO;

    return hit;
}

- (NSArray *)overlayHitTestForMultipleAnnotations:(CGPoint)point
{
    RMMapView *mapView = ((RMMapView *)self.superview);
    
    NSMutableArray *result = [NSMutableArray array];
    
    for (RMAnnotation *annotation in mapView.annotations) {
        
        if (!annotation.isUserLocationAnnotation) {
            CGRect hitZone, remainder;
            CGRectDivide(annotation.layer.frame, &hitZone, &remainder, annotation.layer.frame.size.height / 2.0, CGRectMinYEdge);
            
            CGPoint hitPoint = point;
            if (mapView.userTrackingMode == RMUserTrackingModeFollowWithHeading) {
                // Point rotation
                CGAffineTransform translationTransform = CGAffineTransformMakeTranslation(mapView.center.x, mapView.center.y);
                CGAffineTransform rotationTransform = CATransform3DGetAffineTransform(annotation.layer.transform);
                CGAffineTransform customRotation = CGAffineTransformConcat(CGAffineTransformConcat( CGAffineTransformInvert(translationTransform), rotationTransform), translationTransform);
                hitPoint = CGPointApplyAffineTransform(hitPoint, customRotation);
                
                translationTransform = CGAffineTransformMakeTranslation(hitZone.origin.x + hitZone.size.width / 2.0, hitZone.origin.y + hitZone.size.height);
                customRotation = CGAffineTransformConcat(CGAffineTransformConcat( CGAffineTransformInvert(translationTransform), rotationTransform), translationTransform);
                hitZone = CGRectApplyAffineTransform(hitZone, customRotation);
            }
            
            // Hit zone must be at least 44pt
            CGFloat delta = 44.0 - hitZone.size.width;
            if (delta > 0.0) {
                hitZone.origin.x = hitZone.origin.x - delta / 2.0;
                hitZone.size.width = hitZone.size.width + delta;
            }
            delta = 44.0 - hitZone.size.height;
            if (delta > 0.0) {
                hitZone.origin.y = hitZone.origin.y - delta / 2.0;
                hitZone.size.height = hitZone.size.height + delta;
            }
            
            if (CGRectContainsPoint(hitZone, hitPoint)) {
                [result addObject:annotation];
            }
        }
        
    }
    
    return result;
}

@end
