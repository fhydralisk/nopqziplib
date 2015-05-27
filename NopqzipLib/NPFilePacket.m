//
//  NPFilePacket.m
//  NPTcpServer
//
//  Created by 樊航宇 on 15/3/9.
//  Copyright (c) 2015年 樊航宇. All rights reserved.
//

#import "NPFilePacket.h"


static NSArray *headersDescriptionFile;
static NSArray *headersLengthFile;

@implementation NPFilePacket


-(BOOL)endPacket
{
    if ([self contentLengthFilled]!=[[self getHeaderField:FPH_CONTENTLENGTH] unsignedLongValue]) {
        return NO;
    }
    return [super endPacket]; 
}

@end

@implementation NPFilePacket (Headers)

+(void)initialize
{
    headersDescriptionFile= @[FPH_FILENAMELENGTH, FPH_FILENAME, FPH_CONTENTLENGTH];
    headersLengthFile=      @[      @2,         [self emptyObject],     @4];
}

+(NSArray *)headerFieldsDescription
{
    return headersDescriptionFile;
}

+(NSArray *)headerFieldsLength
{
    return headersLengthFile;
}

-(id)getHeaderField:(NSString *)headerKey
{
    NSData* data=[self getHeaderFieldData:headerKey];
    if (data==nil)
        return nil;
    if ([headerKey isEqualToString:FPH_FILENAME]) {
        return [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    }
    
    if ([headerKey isEqualToString:FPH_CONTENTLENGTH] ||
        [headerKey isEqualToString:FPH_FILENAMELENGTH]) {
        NSNumber *number;
        if ([NPPacket convertData:data ToNumber:&number]==NO) {
            return nil;
        } else {
            return number;
        }
    }
    
    return [super getHeaderField:headerKey];
}

-(NSData *)canSetData:(NSData *)headerData toField:(NSString *)headerKey
{
    return [super canSetData:headerData toField:headerKey];
}

-(BOOL)endHeaders
{
    if (![self isAllHeaderFieldFilled]) {
        return NO;
    }
    if ([[self getHeaderField:FPH_FILENAMELENGTH] unsignedShortValue]!=[[self getHeaderField:FPH_FILENAME]length]) {
        return NO;
    }
    return [super endHeaders];
}

-(BOOL)autoEndHeaders
{
    if ([self getHeaderField:FPH_FILENAME]==nil ||
        [self getHeaderField:FPH_CONTENTLENGTH]==nil) {
        return NO;
    }
    
    UInt16 fnlen=[[self getHeaderField:FPH_FILENAME] length];
    if ([self setData:[NSData dataWithBytes:&fnlen length:2] toField:FPH_FILENAMELENGTH]==NO)
        return NO;
    
    return [self endHeaders];
}

@end


@implementation NPFilePacket (Parser)

-(void)nextHeaderIs:(NSString *__autoreleasing *)refHeaderKey andLengthIs:(NSNumber *__autoreleasing *)refHeaderLength
{
    [super nextHeaderIs:refHeaderKey andLengthIs:refHeaderLength];
    if ([*refHeaderKey isEqualToString:FPH_FILENAME]) {
        *refHeaderLength=[self getHeaderField:FPH_FILENAMELENGTH];
    }
}

-(NSInteger)contentLengthToFill
{
    NSNumber *contentLen=[self getHeaderField:FPH_CONTENTLENGTH];
    if (contentLen) {
        return [contentLen unsignedLongValue];
    }
    return NP_FILLRESULT_NEEDMORE;
}

-(BOOL)tryEndPacket
{
    return [super tryEndPacket];
}

@end