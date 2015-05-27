//
//  NPGernalPacket.m
//  NPTcpServer
//
//  Created by 樊航宇 on 15/3/4.
//  Copyright (c) 2015年 樊航宇. All rights reserved.
//

#import "NPGeneralPacket.h"



/*
 
 Genral Packet Format:
 | Foward code 0x1010 (2bytes) | Type (1 byte) | Content Length (4bytes Network) | HeaderChecksum (1 byte) | Content |
 
 
 */
#define GP_FORWARD 0x1010

static NSArray *headersDescriptionGeneral, *headersLengthGeneral;

@implementation NPGeneralPacket

-(BOOL)endPacket
{
    
    
    if ([self contentLengthFilled]!=[[self getHeaderField:GPH_CONTENTLENGTH] unsignedIntValue]) {
        return NO;
    }
    return [super endPacket];
}


@end

@implementation NPGeneralPacket(Headers)

+(void)initialize
{
    //[super initialize];
    headersDescriptionGeneral=  @[GPH_FORWARD,  GPH_TYPE,   GPH_CONTENTLENGTH,  GPH_HEADERCHECKSUM];
    headersLengthGeneral=       @[    @2,          @1,              @4,                 @1        ];
}

-(BOOL)calcChecksum:(UInt8 *)refChecksum
{
    UInt8 checksum=0, check;
    NSArray *headers=[self headers];
    NSUInteger count=[headers count];
    for (int hIndex=0; hIndex<count; hIndex++) {
        if (![[[self headerFieldsDescription]objectAtIndex:hIndex] isEqualToString:GPH_FORWARD] &&
            ![[[self headerFieldsDescription]objectAtIndex:hIndex] isEqualToString:GPH_HEADERCHECKSUM]) {
            NSData *data=[headers objectAtIndex:hIndex];
            if (data==[[self class]emptyObject]) {
                return NO;
            }
            
            for (int i=0; i<[data length]; i++) {
                NSRange range={i,sizeof(check)};
                [data getBytes:&check range:range];
                checksum+=check;
            }
        }
    }
    *refChecksum=checksum;
    return YES;

}

+(NSArray*)headerFieldsDescription
{
    return headersDescriptionGeneral;
}
+(NSArray*)headerFieldsLength
{
    return headersLengthGeneral;
}

-(BOOL)endHeaders
{
    NSData *data;
    NSNumber *number;
    //UInt32 longData;
    
    /*if ([self isAllHeaderFieldFilled]==NO)
        return NO;*/
    data=[self getHeaderFieldData:GPH_FORWARD];
    if (![NPPacket convertData:data ToNumber:&number]) {
        return NO;
    }
    if ([number unsignedShortValue]!=GP_FORWARD)
        return NO;
    
    data=[self getHeaderFieldData:GPH_HEADERCHECKSUM];
    if (![NPPacket convertData:data ToNumber:&number]) {
        return NO;
    }
    UInt8 checksum;
    if ([self calcChecksum:&checksum]==NO) {
        return NO;
    }
    
    if ([number unsignedCharValue]!=checksum) {
        return NO;
    }
    
    data=[self getHeaderFieldData:GPH_TYPE];
    if (![NPPacket convertData:data ToNumber:&number]) {
        return NO;
    }
    
    if ([number unsignedLongValue]==0) {
        return NO;
    }
    
    return [super endHeaders];
}

-(BOOL)autoEndHeaders
{
    //set forward
    if ([self setShort:GP_FORWARD toField:GPH_FORWARD byNetOrder:NO]==NO)
        return NO;
    
    //set content length if needed
    if ([self getHeaderField:GPH_CONTENTLENGTH]==nil) {
        if ([self content]) {
            if ([self setLong:(UInt32)[[self content] length] toField:GPH_CONTENTLENGTH byNetOrder:YES]==NO) {
                return NO;
            }
        } else {
            return NO;
        }
    }
    
    // set check sum.
    UInt8 checksum;
    if ([self calcChecksum:&checksum]==NO) {
        return NO;
    }
    if ([self setData:[NSData dataWithBytes:&checksum length:sizeof(checksum)] toField:GPH_HEADERCHECKSUM]==NO) {
        return NO;
    }
    
    
    return [super autoEndHeaders];
}

-(NSData *)canSetData:(NSData *)headerData toField:(NSString *)headerKey
{
    NSNumber *number;
    if ([headerKey isEqualToString:GPH_FORWARD]) {
        if (![NPPacket convertData:headerData ToNumber:&number]) {
            return nil;
        }
        if ([number unsignedShortValue]!=GP_FORWARD) {
            return nil;
        }
    }
    
    if ([headerKey isEqualToString:GPH_HEADERCHECKSUM])
    {
        UInt8 checksum;
        if ([self calcChecksum:&checksum]==NO) {
            return nil;
        }
        if (![NPPacket convertData:headerData ToNumber:&number]) {
            return nil;
        }
        
        if ([number unsignedCharValue]!=checksum) {
            return nil;
        }
    }
    
    
    if ([headerKey isEqualToString:GPH_TYPE])
    {
        if (![NPPacket convertData:headerData ToNumber:&number]) {
            return nil;
        }
        
        if ([number unsignedLongValue]==0) {
            return nil;
        }
    }
    return [super canSetData:headerData toField:headerKey];
}

-(id)getHeaderField:(NSString *)headerKey
{
    NSNumber *number=nil;
    NSData *data=[self getHeaderFieldData:headerKey];
    if (data==nil)
        return nil;
    
    if ([headerKey isEqualToString:GPH_FORWARD]         ||
        [headerKey isEqualToString:GPH_TYPE]            ||
        [headerKey isEqualToString:GPH_CONTENTLENGTH]   ||
        [headerKey isEqualToString:GPH_HEADERCHECKSUM]) {
        
        if ([NPPacket convertData:data ToNumber:&number]) {
            if ([headerKey isEqualToString:GPH_CONTENTLENGTH]) {
                number=[NSNumber numberWithUnsignedLong:ntohl([number unsignedLongValue])];
            }
            return number;
        }
        
    }

    return [super getHeaderField:headerKey];
}



@end

@implementation NPGeneralPacket(Tail)

+(NSData *)tailData
{
    return nil;
}

@end

@implementation NPGeneralPacket(Parser)

-(NSInteger)contentLengthToFill
{
    /*NSData *data=[self getHeaderFieldData:GPH_CONTENTLENGTH];
    if (data==[[self class]emptyObject]) {
        return NP_FILLRESULT_NEEDMORE;
    }
    UInt32 contentLength;
    [data getBytes:&contentLength length:4];
    
    return ntohl(contentLength);*/
    NSNumber *contentLen=[self getHeaderField:GPH_CONTENTLENGTH];
    if (contentLen) {
        return [contentLen unsignedLongValue];
    }
    return NP_FILLRESULT_NEEDMORE;
}

-(NSInteger)bytesLeftToFill
{
    return NP_FILLRESULT_UNUSED;
}

-(BOOL)tryEndPacket
{
    return [super tryEndPacket];
}


@end