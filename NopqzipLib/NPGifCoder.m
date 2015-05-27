//
//  NPGifCoder.m
//  NopqzipLib
//
//  Created by 樊航宇 on 15/4/23.
//  Copyright (c) 2015年 樊航宇. All rights reserved.
//

#import "NPGifCoder.h"
#import "NPGifFrame.h"


#pragma pack (1)
typedef struct _LogicalScreenDescriptor{
    unsigned short width;
    unsigned short height;
    struct LSDFlag {
        unsigned char pixel:3;
        unsigned char s:1;
        unsigned char cr:3;
        unsigned char m:1;
     } flag;
    unsigned char backgroudColorIndex;
    unsigned char aspectRatio;
} LogicalScreenDescriptor;
#pragma pack ()

@implementation NPGifCoder
{
    NSMutableArray *arrayFrames;
}
@dynamic data;

-(instancetype)init
{
    self=[super init];
    if (self) {
        arrayFrames=[NSMutableArray array];
    }
    return self;
}
-(NSData *)gifHeader
{
    static const char header[]="GIF89a";
    return [NSData dataWithBytes:header  length:sizeof(header)-1];
}

-(NSData *)logicalScreenDescriptor
{
    LogicalScreenDescriptor lsd;
    memset(&lsd, 0, sizeof(lsd));
    lsd.width=_width;
    lsd.height=_height;
    lsd.flag.cr=7;
    return [NSData dataWithBytes:&lsd length:sizeof(lsd)];
}

-(NSData *)gifTrailer
{
    static const char c=';';
    return [NSData dataWithBytes:&c length:1];
}

-(void)addCGImage:(CGImageRef)image origin:(CGPoint)origin duration:(NSTimeInterval)duration
{
    NPGifFrame *gifFrame=[[NPGifFrame alloc]initWithCGImage:image origin:origin];
    if (duration>0) {
        gifFrame.hasExtention=YES;
        gifFrame.delayInCentiseconds=duration*100;
    }
    [arrayFrames addObject:gifFrame];
}

-(NSData *)data
{
    NSMutableData *data=[NSMutableData data];
    [data appendData:[self gifHeader]];
    [data appendData:[self logicalScreenDescriptor]];
    for (NPGifFrame *frame in arrayFrames) {
        [data appendData:[frame gifData]];
    }
    [data appendData:[self gifTrailer]];
    return data;
}



@end
