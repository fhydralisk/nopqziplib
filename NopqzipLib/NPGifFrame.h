//
//  NPGifFrame.h
//  NopqzipLib
//
//  Created by 樊航宇 on 15/4/23.
//  Copyright (c) 2015年 樊航宇. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NPGifFrame : NSObject

@property BOOL hasExtention;
@property NSRect rect;

@property unsigned short delayInCentiseconds;

-(instancetype)initWithCGImage:(CGImageRef)image origin:(NSPoint)origin;
-(NSData *)gifData;

//-(NSData *)colorMap;

@end
