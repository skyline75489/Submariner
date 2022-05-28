//
//  SBRepeatModeTransformer.m
//  Submariner
//
//  Created by Calvin Buckley on 2022-05-23.
//  Copyright © 2022 Calvin Buckley. All rights reserved.
//

#import "SBRepeatModeTransformer.h"

@implementation SBRepeatModeTransformer {
    SBPlayerRepeatMode mode;
}

- (id) initWithMode: (SBPlayerRepeatMode) newMode {
    [super init];
    mode = newMode;
    return self;
}

+ (Class)transformedValueClass {
    return [NSNumber class];
}

// Makes menu item happy
+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)value {
    SBPlayerRepeatMode passedMode = (SBPlayerRepeatMode)[(__bridge NSNumber*)value integerValue];
    return @(mode == passedMode);
}

- (id)reverseTransformedValue:(id)value {
    BOOL enabled = [(__bridge NSNumber*)value boolValue];
    NSLog(@"Enabled? %d; Transformer Mode? %d", enabled, mode);
    return enabled ? @(mode) : @(SBPlayerRepeatNo);
}

@end