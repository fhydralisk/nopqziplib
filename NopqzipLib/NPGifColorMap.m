//
//  NPGifColorMap.m
//  NopqzipLib
//
//  Created by 樊航宇 on 15/4/23.
//  Copyright (c) 2015年 樊航宇. All rights reserved.
//

typedef struct _ColorMapCell{
    unsigned char red;
    unsigned char green;
    unsigned char blue;
    unsigned char alpha;
} ColorMapCell, *ColorMapCellPtr;

#import "NPMacro.h"
#import "NPGifColorMap.h"
#define PERSAMPLE_DEPTH 64
// count/pixels*width
// width=sum(count/pixels)
#define PERSAMPLE_THRESHOLD_NORMALIZED 0.05

static void printToFileLong(const unsigned long nums[],unsigned long count)
{
    NSMutableString *strM=[NSMutableString string];
    for (int i=0; i<count; i++) {
        [strM appendFormat:@"%lu ",nums[i]];
    }
    NSData *dataStr=[strM dataUsingEncoding:NSUTF8StringEncoding];
    [dataStr writeToFile:@"/Users/Hydralisk/Desktop/img/test/test/pixelscount.txt" atomically:NO];
}

static void printToFileFloat(const float nums[],unsigned long count)
{
    NSMutableString *strM=[NSMutableString string];
    for (int i=0; i<count; i++) {
        [strM appendFormat:@"%f ",nums[i]];
    }
    NSData *dataStr=[strM dataUsingEncoding:NSUTF8StringEncoding];
    [dataStr writeToFile:@"/Users/Hydralisk/Desktop/img/test/test/pixelsstep.txt" atomically:NO];
}


static void calcFloatStep(unsigned long pixels,
                          const unsigned long cPixels[],
                          unsigned short persampleDepth,
                          float fStep[],
                          unsigned long stepCount)
{
    unsigned long pixelsPerStep=pixels/stepCount;
    NPLog(@"pixels per step=%lu",pixelsPerStep);
    bzero(fStep, stepCount*sizeof(float));
    
    unsigned long currentStepPixels=0;
    unsigned short currentStep=0;
    for (ushort i=0; i<persampleDepth; i++) {
        if (currentStepPixels+cPixels[i]<=pixelsPerStep) {
            currentStepPixels+=cPixels[i];
            fStep[currentStep]+=1.0;
        } else {
            if (cPixels[i]>=pixelsPerStep) {
                currentStep++;
                fStep[currentStep]=1.0;
                currentStep++;
                currentStepPixels=0;
            } else {
                float remainfStep=((float)(pixelsPerStep-currentStepPixels))/cPixels[i];
                fStep[currentStep]+=remainfStep;
                currentStep++;
                fStep[currentStep]=1.0-remainfStep;
                currentStepPixels=cPixels[i]-pixelsPerStep+currentStepPixels;
            }
            
        }
        
        if (currentStep==stepCount-1) {
            break;
        }
    }
    
    fStep[stepCount-1]=persampleDepth;
    for (unsigned long step=0; step<stepCount-1; step++) {
        fStep[stepCount-1]-=fStep[step];
    }
    
    printToFileLong(cPixels, persampleDepth);
    printToFileFloat(fStep, stepCount);


}



@implementation NPGifColorMap

+(instancetype)colorMapForBitmap:(NSData *)bitmapRGBData depth:(NSUInteger)depth maxCodeSize:(NSUInteger)codesize
{
    NPGifColorMap  *instance;
    if (depth!=4 && depth!=8) {
        return nil;
    }
    instance=[[self class]new];
    instance->_depth=depth;
    instance->_maxCodeSize=codesize;
    
    // Per-sample color existance
    unsigned long cRed[PERSAMPLE_DEPTH],cGreen[PERSAMPLE_DEPTH],cBlue[PERSAMPLE_DEPTH];
    bzero(cRed, sizeof(cRed));
    bzero(cGreen, sizeof(cGreen));
    bzero(cBlue, sizeof(cBlue));
    
    unsigned char div=256/PERSAMPLE_DEPTH;
    ColorMapCellPtr pColor=(ColorMapCellPtr)[bitmapRGBData bytes];
    NSUInteger pixels=[bitmapRGBData length]/sizeof(ColorMapCell);
    for (unsigned long i=0; i<pixels; i++) {
        cRed[pColor[i].red/div]++;
        cGreen[pColor[i].green/div]++;
        cBlue[pColor[i].blue/div]++;
    }
    // evaluate color width
    // normalized width=pixels^2/depth/sum(cColor^2)
    double wRed=0,wGreen=0,wBlue=0;
    double dPixels=(double)pixels;
    double dLength=PERSAMPLE_DEPTH;
    double wNorm=dPixels/dLength*dPixels;
    for (int i=0; i<PERSAMPLE_DEPTH; i++) {
        wRed+=cRed[i]*cRed[i];
        wGreen+=cGreen[i]*cGreen[i];
        wBlue+=cBlue[i]*cBlue[i];
    }
    wRed=wNorm/wRed;
    wGreen=wNorm/wGreen;
    wBlue=wNorm/wBlue;
    
    NPLog(@"width red:%f, green:%f, blue:%f",wRed,wGreen,wBlue);
    int numColorIndex;
    switch (depth) {
        case 4:
            numColorIndex=16;
            break;
        case 8:
            numColorIndex=256;
            break;
            
        default:
            return nil;
            break;
    }
    // evaluate step count
    
    double proportionRed,proportionGreen,proportionBlue;
    proportionRed=wRed/(wRed+wGreen+wBlue);
    proportionGreen=wGreen/(wRed+wGreen+wBlue);
    proportionBlue=wBlue/(wRed+wGreen+wBlue);
    
    unsigned long nStepRed,nStepGreen,nStepBlue;
    nStepRed=lround(depth*proportionRed);
    nStepGreen=lround(depth*proportionGreen);
    nStepBlue=lround(depth-nStepGreen-nStepRed);
    
    nStepRed=pow(2,nStepRed);
    nStepGreen=pow(2,nStepGreen);
    nStepBlue=pow(2,nStepBlue);
    
    NPLog(@"steps red=%lu,green=%lu,blue=%lu",nStepRed,nStepGreen,nStepBlue);
    
    //evaluate step length
    
    float           fStepLenR[nStepRed],fStepLenG[nStepGreen],fStepLenB[nStepBlue];
    unsigned long   iStepLenR[nStepRed],iStepLenG[nStepGreen],iStepLenB[nStepBlue];
    calcFloatStep(pixels, cRed, PERSAMPLE_DEPTH, fStepLenR, nStepRed);
    calcFloatStep(pixels, cGreen, PERSAMPLE_DEPTH, fStepLenG, nStepGreen);
    calcFloatStep(pixels, cBlue, PERSAMPLE_DEPTH, fStepLenB, nStepBlue);
    
    
    
    return instance;
}


@end


/*#ifdef DEBUG
    NSMutableString *strM=[NSMutableString string];
    for (int i=0; i<PERSAMPLE_DEPTH; i++) {
        [strM appendFormat:@"%lu ",cRed[i]];
    }
    NSData *dataStr=[strM dataUsingEncoding:NSUTF8StringEncoding];
    [dataStr writeToFile:@"/Users/Hydralisk/Desktop/test.txt" atomically:NO];
#endif*/