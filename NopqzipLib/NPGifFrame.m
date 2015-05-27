//
//  NPGifFrame.m
//  NopqzipLib
//
//  Created by 樊航宇 on 15/4/23.
//  Copyright (c) 2015年 樊航宇. All rights reserved.
//
#import "NPMacro.h"
#import "NPGifFrame.h"

#pragma pack(1)
typedef struct _GraphicsControlExtensionStruct
{
    unsigned char extIntro;
    unsigned char extLabel;
    unsigned char blockSize;
    struct GCESFlag {
        unsigned char transparentColorFlag:1;
        unsigned char userInputFlag:1;
        unsigned char displayMethod:3;
        unsigned char reserved:3;
    } flag;
    unsigned short delay;
    unsigned char transparentColorIndex;
    unsigned char blockTrailer;
} GraphicsControlExt;


typedef struct _ImageDescriptor
{
    unsigned char header;
    unsigned short xOffset;
    unsigned short yOffset;
    unsigned short width;
    unsigned short height;
    struct IDFlag {
        unsigned char pixel:3;
        unsigned char reserved:2;
        unsigned char sortFlag:1;
        unsigned char interlaneFlag:1;
        unsigned char localColorTableFlag:1;

    } flag;
} ImageDescriptor;
#pragma pack()


@implementation NPGifFrame
{
    //NSBitmapImageRep *imageRep;
    NSData *gifRepData;
    NSData *imageData;
    NSData *colorMap;
}

-(instancetype)initWithCGImage:(CGImageRef)image origin:(NSPoint)origin
{
    self=[self init];
    if (self) {
        _rect.origin=origin;
        _rect.size=CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
        NSBitmapImageRep *imageRep=[[NSBitmapImageRep alloc]initWithCGImage:image];
        gifRepData=[imageRep representationUsingType:NSGIFFileType properties:nil];
        imageRep=nil;
        //[self createRGBBitmapContextWithImage:image];
    }
    return self;
}

-(NSData *)graphicsControlExtension
{
    GraphicsControlExt gce;
    bzero(&gce, sizeof(gce));
    gce.extIntro='!';
    gce.extLabel=0xF9;
    gce.blockSize=4;
    gce.flag.displayMethod=1;
    gce.flag.transparentColorFlag=1;
    gce.delay=_delayInCentiseconds;
    return [NSData dataWithBytes:&gce length:sizeof(gce)];
}

-(NSData *)imageDescriptor
{
    ImageDescriptor ides;
    bzero(&ides, sizeof(ides));
    ides.header=',';
    ides.xOffset=(unsigned short)_rect.origin.x;
    ides.yOffset=(unsigned short)_rect.origin.y;
    ides.width = (unsigned short)_rect.size.width;
    ides.height =(unsigned short)_rect.size.height;
    ides.flag.interlaneFlag=NO;
    ides.flag.localColorTableFlag=YES;
    ides.flag.sortFlag=0;
    ides.flag.pixel=7;
    return [NSData dataWithBytes:&ides length:sizeof(ides)];
}

-(NSData *)colorMap
{
    if (colorMap) {
        return colorMap;
    }
    NSData *data=gifRepData;
    NSRange range={13,256*3};
    colorMap=[data subdataWithRange:range];
    return colorMap;
}

-(NSData *)imageData
{
    if (imageData) {
        return imageData;
    }
    NSData *data=gifRepData;
    unsigned char start[]={',',0,0,0,0,(unsigned long)self.rect.size.width&0xFF,((unsigned long)self.rect.size.width>>8)&0xFF,
                                   (unsigned long)self.rect.size.height&0xFF,((unsigned long)self.rect.size.height>>8)&0xFF};
    NSRange range={0,[data length]};
    NSRange rangeStart=[data rangeOfData:[NSData dataWithBytes:&start length:sizeof(start)] options:0 range:range];
    rangeStart.location+=10;
    rangeStart.length=[data length]-rangeStart.location-1;
    imageData=[data subdataWithRange:rangeStart];
        
    return imageData;
}

-(NSData *)gifData
{
    NSMutableData *gifDataM=[NSMutableData data];
    if (_hasExtention) {
        [gifDataM appendData:[self graphicsControlExtension]];
    }
    [gifDataM appendData:[self imageDescriptor]];
    [gifDataM appendData:[self colorMap]];
    [gifDataM appendData:[self imageData]];
    
    return gifDataM;
}

/*-(CGContextRef)createRGBBitmapContextWithImage:(CGImageRef)image {
    CGContextRef context = NULL;
    CGColorSpaceRef colorSpace;
    void * bitmapData;
    long bitmapByteCount;
    long bitmapBytesPerRow;
    
    // Get image width, height. We'll use the entire image.
    //size_t pixelsWide = CGImageGetWidth(image);
    //size_t pixelsHigh = CGImageGetHeight(image);
    
    bitmapBytesPerRow = (_rect.size.width * 4);
    bitmapByteCount = (bitmapBytesPerRow * _rect.size.height);
    
    // Use the generic RGB color space.
    colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == NULL) {
        fprintf(stderr, "Error allocating color space\n");
        return NULL;
    }
    
    // allocate

    bitmapData = malloc(bitmapByteCount);
    if (bitmapData == NULL) {
        NPLog(@"Malloc failed which is too bad.  I was hoping to use this memory.");
        CGColorSpaceRelease(colorSpace);
        // even though CGContextRef technically is not a pointer,
        // it's typedef probably is and it is a scalar anyway.
        return NULL;
    }
    
    // Create the bitmap context. We are
    // setting up the image as an RGB (0-255 per component)
    // 3-byte per/pixel.
    const int width=_rect.size.width;
    const int height=_rect.size.height;
    
    context = CGBitmapContextCreate (bitmapData,
                                     width,
                                     height,
                                     8,      // bits per component
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     kCGBitmapAlphaInfoMask&kCGImageAlphaPremultipliedLast);
    if (context == NULL) {
        free (bitmapData);
        NPLog(@"Failed to create bitmap!");
    }
    
    // draw the image on the context.
    // CGContextTranslateCTM(context, 0, CGImageGetHeight(image));
    // CGContextScaleCTM(context, 1.0, -1.0);
    CGContextClearRect(context, CGRectMake(0, 0, _rect.size.width, _rect.size.height));
    CGContextDrawImage(context, CGRectMake(0, 0, _rect.size.width, _rect.size.height), image);
    CGColorSpaceRelease(colorSpace);
    bitmapNSData=[NSData dataWithBytesNoCopy:bitmapData length:bitmapByteCount freeWhenDone:YES];
    
    return context;
}*/

-(void)dealloc
{

}

@end
