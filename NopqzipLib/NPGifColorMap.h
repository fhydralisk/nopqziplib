//
//  NPGifColorMap.h
//  NopqzipLib
//
//  Created by 樊航宇 on 15/4/23.
//  Copyright (c) 2015年 樊航宇. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NPGifColorMap : NSObject

/**
 Returns the colormap data
 */
@property (readonly) NSData *data;

/**
 Returns the color depth of this map
 */
@property (readonly) NSUInteger depth;

@property (readonly) NSUInteger maxCodeSize;

/** 
 Evaluates and build a suitable color map for bitmap data
 */
+(instancetype)colorMapForBitmap:(NSData *)bitmapRGBData depth:(NSUInteger)depth maxCodeSize:(NSUInteger)codesize;




@end
