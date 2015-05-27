//
//  NopqzipLibTests.m
//  NopqzipLibTests
//
//  Created by 樊航宇 on 15/4/17.
//  Copyright (c) 2015年 樊航宇. All rights reserved.
//

#import "NPMacro.h"
#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "NPGifCoder.h"
#import "NPGifFrame.h"
#import "NPTCPServerEngine.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>


@interface NopqzipLibTests : XCTestCase

@end

@implementation NopqzipLibTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    //sleep(5);
    /*NSImage *img=[NSImage imageWithSize:CGSizeMake(1024, 768) flipped:NO drawingHandler:^(NSRect rect){
        NSGradient *gra=[[NSGradient alloc]initWithColors:@[[NSColor colorWithWhite:0 alpha:1],[NSColor colorWithWhite:1 alpha:1]]];
        [gra drawInRect:rect angle:0];
        return YES;
    }];
    NSRect rect=CGRectMake(0, 0, 1880, 900);
    CGImageRef imgRef=[img CGImageForProposedRect:&rect context:NULL hints:nil];*/
    //CGImageRef imgRef=CGDisplayCreateImage(CGMainDisplayID());
    //NPGifFrame *gifFrame=[[NPGifFrame alloc]initWithCGImage:imgRef origin:CGPointMake(0, 0)];
    /*NSBitmapImageRep *imgRep=[[NSBitmapImageRep alloc]initWithCGImage:imgRef];
     NSBitmapImageRep *gifRep=[NSBitmapImageRep imageRepWithData:[imgRep representationUsingType:NSGIFFileType properties:nil]];
     NSData *data=[gifRep valueForProperty:NSImageRGBColorTable];
     data=[gifRep representationUsingType:NSGIFFileType properties:nil];
     const char *ptr=[data bytes];*/
    //ptr+=[data length]-4;
    /*NPGifCoder *coder=[NPGifCoder new];
    for (int i=1; i<=10; i++) {
        CGImageRef imgRef=CGDisplayCreateImage(CGMainDisplayID());
        coder.width=CGImageGetWidth(imgRef);
        coder.height=CGImageGetHeight(imgRef);
        [coder addCGImage:imgRef origin:CGPointMake(0, 0) duration:1];
        CGImageRelease(imgRef);
        sleep(1);
    }
    NSData *data=[coder data];
    [data writeToFile:@"/Users/Hydralisk/Desktop/test.gif" atomically:NO];
    
    
    //void *ptr=[data bytes];
    NPLog(@"hi");

    //[gifFrame colorMap];*/
    NSArray *ips=[NPTCPServerEngine serverIps];
    NPLog(@"%@",ips);
    

    XCTAssert(YES, @"Pass");
}

-(void)testGet
{
    CGImageRef imgRef=CGDisplayCreateImage(CGMainDisplayID());
    NSBitmapImageRep *imageRep=[[NSBitmapImageRep alloc]initWithCGImage:imgRef];
    CGImageRelease(imgRef);
    NSUInteger height=imageRep.size.height;
    NSUInteger width=imageRep.size.width;
    char *bitmap=malloc(height*width*3);
    bzero(bitmap, height*width*3);
    void (* getPixel)(id self,SEL _cmd,NSUInteger *pixel,NSInteger x,NSInteger y);
    getPixel=method_getImplementation(class_getInstanceMethod([NSBitmapImageRep class], @selector(getPixel:atX:y:)));
    
    for (int y=0; y<height; y++) {
        for (int x=0; x<width; x++) {
            NSUInteger pix[4];
            //[imageRep getPixel:pix atX:x y:y];
            getPixel(imageRep,@selector(getPixel:atX:y:),pix,x,y);
            //CGFloat r,g,b,a;
            //[color getRed:&r green:&g blue:&b alpha:&a];
            bitmap[(y*width+x)*3+0]=pix[0];
            bitmap[(y*width+x)*3+1]=pix[1];
            bitmap[(y*width+x)*3+2]=pix[2];
        }
    }
    NPLog(@"finished");

}
- (CGContextRef)CreateARGBBitmapContextWithImage:(CGImageRef)image {
    CGContextRef context = NULL;
    CGColorSpaceRef colorSpace;
    void * bitmapData;
    long bitmapByteCount;
    long bitmapBytesPerRow;
    
    // Get image width, height. We'll use the entire image.
    size_t pixelsWide = CGImageGetWidth(image);
    size_t pixelsHigh = CGImageGetHeight(image);
    
    bitmapBytesPerRow = (pixelsWide * 4);
    bitmapByteCount = (bitmapBytesPerRow * pixelsHigh);
    
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
    // setting up the image as an ARGB (0-255 per component)
    // 4-byte per/pixel.
    context = CGBitmapContextCreate (bitmapData,
                                     pixelsWide,
                                     pixelsHigh,
                                     8,      // bits per component
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     kCGBitmapAlphaInfoMask&kCGImageAlphaPremultipliedFirst);
    if (context == NULL) {
        free (bitmapData);
        NPLog(@"Failed to create bitmap!");
    }
    
    // draw the image on the context.
    // CGContextTranslateCTM(context, 0, CGImageGetHeight(image));
    // CGContextScaleCTM(context, 1.0, -1.0);
    CGContextClearRect(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)));
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);
    
    CGColorSpaceRelease(colorSpace);
    
    return context;	
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    //NSImage *image=[[NSImage alloc] initWithContentsOfFile:@"/Users/Hydralisk/Desktop/img/play.png"];
    [self measureBlock:^{
    }];
}

@end
