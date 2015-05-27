//
//  NPTCPPacket.m
//  NPTcpServer
//
//  Created by 樊航宇 on 15/3/3.
//  Copyright (c) 2015年 樊航宇. All rights reserved.
//

/*
 
 Packet Construction Flow
 
 Assemble Flow:
 
 Packet alloc & init
 Packet setHeader
 Packet endHeader, return=YES
 Packet fillContent
 Packet endPacket, return=YES
 
 Disassemble Flow:
 
 Packet alloc & init
 Packet tryFillPacket with data until return 0
    tryFillPacket return value:
    >=0 Fill Completed,     bytes unused.
    NP_FILLRESULT_NEEDMORE  need more data
    NP_FILLRESULT_FAIL,     failed to fill, data invalid.
 */


#import "NPPacket.h"
#import "NPCache.h"

static const NSNull* emptyObj;

@implementation NPPacket

+(void)initialize
{
    emptyObj=[NSNull new];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _contentData=[NSMutableData data];
        _cache=[NPCache new];
        //_tailData=[NSMutableData data];
        _fillFailed=NO;
        NSArray *headersList=[[self class]headerFieldsDescription];
        if (headersList!=nil) {
            NSArray *headersLength=[[self class]headerFieldsLength];
            
            _headers=[NSMutableArray array];
            
            if ([[self class] isFlexible]) {
                // Flexible type.
                assert(headersLength==nil);   // Flexible type shuod not override +headerFieldsLength.
                for (NSUInteger hIndex=0; hIndex<[headersList count]; hIndex++) {
                    [_headers addObject:[[self class] emptyObject]];
                }
            } else {
                // Fixed type.
                assert([headersList count]==[headersLength count]);

                for (NSUInteger hIndex=0; hIndex<[headersList count]; hIndex++) {
                    [_headers addObject:[[self class] emptyObject]];
                }
            }
            
            _headerFilled=NO;
        }
        else
        {
            _headers=nil;
            if ([[self class]headerLength]==-1)     // Flexible Headers Packet with flexiable description
            {
                //assert([[self class] canAddHeaderDescription]);   // If Flexible Headers packet cannot add a header, Use Fixed packet with no header
                _headerFilled=NO;
                _headers=[NSMutableArray array];
            }
            else                                    // None Headers Packet
                _headerFilled=YES;
        }
        
    }
    return self;
}

-(BOOL)isFilled
{
    return _filled;
}

-(BOOL)isFillFailed
{
    return _fillFailed;
}


-(NSUInteger)length
{
    if (_filled==NO) {
        return 0;
    }
    NSUInteger pktLength=0;
    if (_contentData)
        pktLength=[_contentData length];
    
    
    if ([[self class ]tailData])
        pktLength+=[[[self class ]tailData] length];

    
    if (_headers) {
        for (NSUInteger hIndex=0; hIndex<[_headers count]; hIndex++) {
            pktLength+=[[_headers objectAtIndex:hIndex] length];
        }
    }
    
    return pktLength;
}

-(NSData *)data
{
    if (_filled==NO) {
        return nil;
    }
    
    NSMutableData *pktData=[NSMutableData data];
    
    if (_headers) {
        for (NSUInteger hIndex=0; hIndex<[_headers count]; hIndex++) {
            assert([[_headers objectAtIndex:hIndex] isKindOfClass:[NSData class]]);
            [pktData appendData:[_headers objectAtIndex:hIndex]];
        }
    }
    
    [pktData appendData:_contentData];
  
    
    if ([[self class]tailData])
        [pktData appendData:[[self class]tailData]];
    
    return pktData;
}



+(BOOL)isFlexible
{
    /* virtual */
    return NO;
}

+(id)emptyObject
{
    return emptyObj;
}


+(BOOL)convertData:(NSData *)data ToNumber:(NSNumber *__autoreleasing *)number
{
    UInt8 charData;
    UInt16 shortData;
    UInt32 longData;
    UInt64 longlongData;
    switch ([data length]) {
        case 1:
            [data getBytes:&charData length:1];
            *number=[NSNumber numberWithUnsignedChar:charData];
            break;
        case 2:
            [data getBytes:&shortData length:2];
            *number=[NSNumber numberWithUnsignedShort:shortData];
            
            break;
        case 4:
            [data getBytes:&longData length:4];
            *number=[NSNumber numberWithUnsignedInt:longData];
            
            break;
        case 8:
            [data getBytes:&longlongData length:8];
            *number=[NSNumber numberWithUnsignedLongLong:longlongData];
            
            break;
        default:
            return NO;
    }
    
    return YES;
}

@end


@implementation NPPacket (Headers)

-(NSData *)headerContent
{
    if (_headerFilled && _headers) {
        NSMutableData *headerData=[NSMutableData data];
        for (NSUInteger hIndex=0;hIndex<[_headers count];hIndex++)
        {
            id obj=[_headers objectAtIndex:hIndex];
            assert(obj);
            assert([obj isKindOfClass:[NSData class]]);
            [headerData appendData:obj];
        }
        return headerData;
    }
    return nil;
}

-(NSUInteger)headerLength
{
    assert(_headers);
    if (_headerFilled) {
        NSUInteger headerLength=0;
        for (id obj in _headers)
        {
            //assert(obj);
            headerLength+=[obj length];
        }
        return headerLength;
    }
    return 0;
}

-(NSUInteger)headerLengthFilled
{
    assert(_headers);
    NSUInteger headerLength=0;
    for (id obj in _headers)
    {
        //assert(obj);
        if (obj!=[[self class]emptyObject]) {
            headerLength+=[obj length];
        }
    }
    return headerLength;
    //return 0;
    
}

-(NSArray *)headers
{
    return _headers;
}

-(NSArray*)headerFieldsDescription
{
    assert([[self class] headerFieldsDescription] || ![[self class] isFlexible]);  //Packets with its header fields' sequence flexible must override this method.
    return [[self class] headerFieldsDescription];
}

/*-(NSArray*)headerFieldsLength
{
    assert([[self class] headerFieldsLength] || ![[self class] isFlexible]);
    return nil;
}*/


+(NSArray*)headerFieldsDescription
{
    /* virtual */
    return nil;
}
+(NSArray*)headerFieldsLength
{
    /* virtual */
    return nil;
}

+(NSNumber *)getFieldLength:(NSString *)headerKey
{
    if ([self isFlexible]) {
        return nil;
    }
    assert([self headerFieldsDescription]);
    NSUInteger hIndex = [[self headerFieldsDescription]indexOfObject:headerKey];
    if (hIndex==NSNotFound) {
        return nil;
    }
    
    id objLength=[[self headerFieldsLength] objectAtIndex:hIndex];
    assert(objLength);
    assert([objLength isKindOfClass:[NSNumber class]] || objLength==[[self class]emptyObject] );

    
    return objLength;
    
}

-(NSNumber *)getFieldLength:(NSString *)headerKey
{
    if ([[self class]isFlexible]) {
        NSUInteger hIndex = [self seekForHeaderKey:headerKey];
        if (hIndex==NSNotFound) {
            return nil;
        }
        return [NSNumber numberWithUnsignedInteger:[[_headers objectAtIndex:hIndex] length]];
    } else {
        return [[self class] getFieldLength:headerKey];
    }
}

// header(s) Length predict. >0 has headers; =0 no header; NP_HEADER_FLEXIBLE flexible headers.
+(NSInteger)headerLength
{
    if ([self isFlexible]) {
        return NP_HEADERLENGTH_FLEXIBLE;
    }
    
    NSArray *headersLength=[self headerFieldsLength];
    if (headersLength==nil) {
        return 0;
    }
    
    
    NSUInteger length=0;
    
    if ([headersLength indexOfObjectIdenticalTo:[self emptyObject]]!=NSNotFound) {
        return NP_HEADERLENGTH_FLEXIBLE;
    }
    
    for (id obj in headersLength)
    {
        assert(obj);
        assert([obj isKindOfClass:[NSNumber class]]);
        length+=[obj unsignedIntegerValue];
    }
    return length;
}

-(NSUInteger)seekForHeaderKey:(NSString *)headerKey
{
    NSArray *headersList=[self headerFieldsDescription];
    assert(headersList);
    
    return [headersList indexOfObject:headerKey];    //return headerIndex;
}


//#pragma mark Some logical problems here..
// Subclasses can ignore checking fields that could freely fill.
-(NSData*) canSetData:(NSData *)headerData toField:(NSString *)headerKey
{
    /* virtual */
    return headerData;
}

-(BOOL) setData:(NSData *)headerData toField:(NSString *)headerKey
{
    if (headerData==nil) {
        return NO;
    }
    if (_headerFilled) {
        return NO;
    }
    
    /*if ([[self class] headerLength]==0) {                               //Without Headers
        return NO;
    } else*/
    
    if (![[self class] isFlexible]) {                         //Fixed
        if ([[self class] headerLength]==0) {
            return NO;
        }
        assert(_headers);
        /*headersList=[[self class] headerFieldsDescription];
        assert(headersList);*/
        NSUInteger headerIndex=[self seekForHeaderKey:headerKey];
        if (headerIndex!=NSNotFound) {
            id objLength=[self getFieldLength:headerKey];
            assert(objLength);
            assert([objLength isKindOfClass:[NSNumber class]] || objLength==[[self class]emptyObject] );
            
            if (objLength==[[self class]emptyObject] || [headerData length]==[objLength unsignedIntegerValue]) {
                assert([_headers count]>headerIndex);
                NSData* actualData=[self canSetData:headerData toField:headerKey];
                if (actualData) {
                    //query header data is Vaild;
                    [_headers setObject:actualData atIndexedSubscript:headerIndex];
                    return YES;
                } else {
                    return NO;
                }

            } else {
                return NO;
            }
        }
    } else {                                                            //Flexible
        assert(_headers);
        NSMutableArray *headersList=(NSMutableArray *)[self headerFieldsDescription];
        assert(headersList);
        /*NSMutableArray *headerLengthList=(NSMutableArray *)[self headerFieldsLength];
        assert(headerLengthList);
        assert([headerLengthList count]==[headersList count]);*/  // Count Must equal.
        
        NSData* actualData=[self canSetData:headerData toField:headerKey];
        if (actualData) {
            
            NSUInteger headerIndex=[self seekForHeaderKey:headerKey];
            if (headerIndex!=NSNotFound) {
                //Description found, modify it
                
                /*NSNumber *objLength=[headerLengthList objectAtIndex:headerIndex];
                assert(objLength);
                assert([objLength isKindOfClass:[NSNumber class]]);*/
                
                [_headers setObject:actualData atIndexedSubscript:headerIndex];
                /*if ([actualData length]!=[objLength unsignedIntegerValue]) {
                    assert([headerLengthList isKindOfClass:[NSMutableArray class]]);
                    [headerLengthList setObject:[NSNumber numberWithUnsignedInteger:[actualData length]] atIndexedSubscript:headerIndex];
                }*/
                
                return YES;
            } else {
                //Description not found, add it
                //assert([headerLengthList isKindOfClass:[NSMutableArray class]]);
                assert([headersList isKindOfClass:[NSMutableArray class]]);
                [headersList addObject:headerKey];
                //[headerLengthList addObject:[NSNumber numberWithUnsignedInteger:[actualData length]]];
                [_headers addObject:actualData];
                return YES;
            }

        }
        else
        {
            // header data with key denied
            return NO;
        }
        
     }
    return NO;
}

-(BOOL)setChar:(UInt8)charData toField:(NSString *)headerKey
{
    NSData *data=[NSData dataWithBytes:&charData length:sizeof(charData)];
    return [self setData:data toField:headerKey];
}

-(BOOL)setShort:(UInt16)shortData toField:(NSString *)headerKey
{
    NSData *data=[NSData dataWithBytes:&shortData length:sizeof(shortData)];
    return [self setData:data toField:headerKey];
}

-(BOOL)setLong:(UInt32)longData toField:(NSString *)headerKey
{
    NSData *data=[NSData dataWithBytes:&longData length:sizeof(longData)];
    return [self setData:data toField:headerKey];
}

-(BOOL)setLongLong:(UInt64)longLongData toField:(NSString *)headerKey
{
    NSData *data=[NSData dataWithBytes:&longLongData length:sizeof(longLongData)];
    return [self setData:data toField:headerKey];
}

-(BOOL)setShort:(UInt16)shortData toField:(NSString *)headerKey byNetOrder:(BOOL)isNetOrder
{
    return [self setShort:isNetOrder?htons(shortData):shortData toField:headerKey];
}

-(BOOL)setLong:(UInt32)longData toField:(NSString *)headerKey byNetOrder:(BOOL)isNetOrder
{
    
    return [self setLong:isNetOrder?htonl(longData):longData toField:headerKey];
}

-(BOOL)setLongLong:(UInt64)longLongData toField:(NSString *)headerKey byNetOrder:(BOOL)isNetOrder
{
    return [self setLongLong:isNetOrder?htonll(longLongData):longLongData toField:headerKey];
}

-(BOOL)setNumber:(UInt64)number toFiled:(NSString *)headerKey byNetOrder:(BOOL)isNetOrder
{
    switch ([[[self class] getFieldLength:headerKey] unsignedIntegerValue]) {
        case 1:
            assert(number<=UCHAR_MAX);
            return [self setChar:number toField:headerKey];
            break;
            
        case 2:
            assert(number<=USHRT_MAX);
            return [self setShort:number toField:headerKey byNetOrder:isNetOrder];
            break;
            
        case 4:
            assert(number<=UINT_MAX);
            return [self setLong:(UInt32)number toField:headerKey byNetOrder:isNetOrder];
            break;
            
        case 8:
            //assert(number<ULONG_LONG_MAX);
            return [self setLongLong:number toField:headerKey byNetOrder:isNetOrder];
            break;
            
        default:
            return NO;
            break;
    }
    
    return NO;
}

-(BOOL)setString:(NSString *)stringData toField:(NSString *)headerKey
{
    NSData *data=[NSData dataWithBytes:[stringData UTF8String] length:[stringData lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
    return [self setData:data toField:headerKey];
}

-(NSData *)getHeaderFieldData:(NSString *)headerKey
{
    NSUInteger hIndex=[self seekForHeaderKey:headerKey];
    if (hIndex==NSNotFound || [_headers objectAtIndex:hIndex]==[[self class]emptyObject]) {
        return nil;
    }
    
    
    return [_headers objectAtIndex:hIndex];
}

-(id)getHeaderField:(NSString *)headerKey
{
    
    /* virtual */
    
    return [self getHeaderFieldData:headerKey];
}

-(BOOL)removeHeader:(NSString *)headerKey
{
//#pragma mark need fill data
    
    NSUInteger hIndex=[self seekForHeaderKey:headerKey];
    if (hIndex==NSNotFound)
        return NO;
    
    if (![[self class]isFlexible]) {
        [_headers setObject:[[self class]emptyObject] atIndexedSubscript:hIndex];
    } else {
        NSMutableArray *headersList=(NSMutableArray *)[self headerFieldsDescription];
        assert(headersList);
        assert([headersList isKindOfClass:[NSMutableArray class]]);
        assert([headerKey isEqualToString:[headersList objectAtIndex:hIndex]]);
        [_headers removeObjectAtIndex:hIndex];
        [headersList removeObjectAtIndex:hIndex];
    }
    
    return NO;
}


-(BOOL)endHeaders
{
    if ([self isAllHeaderFieldFilled]==NO) {
        return NO;
    }
    if (_headerFilled==NO) {
        _headerFilled=YES;
        return YES;
    }
    return NO;
}

-(BOOL)autoEndHeaders
{
    /*if (_headerFilled==NO) {
        _headerFilled=YES;
        return YES;
    }
    return NO;*/
    return [self endHeaders];
    
}

-(BOOL) isAllHeaderFieldFilled
{
    for (id Obj in _headers)
    {
        if (Obj==[[self class]emptyObject])
            return NO;
    }
    return YES;
}


@end


@implementation NPPacket (Content)

-(void)fillContent:(NSData*)data
{
    /* virtual */
    //return [self fillPacketWithData:data];
    [_contentData appendData:data];
    
    //return NP_FILLRESULT_NEEDMORE;
}


-(BOOL)endPacket
{
    if  (_filled)
    {
        return NO;
    }
    _filled=YES;
    return YES;
}


-(NSInteger)contentBytesLeftToFill
{
    /* virtual */
    if (_filled) {
        return 0;
    }
    return NP_FILLRESULT_NEEDMORE;
}




-(NSData*)content
{
    return _contentData;
}

-(NSUInteger)contentLength
{
    if (_filled)
        return [_contentData length];
    return 0;
}

-(NSUInteger)contentLengthFilled
{
    return [_contentData length];
}


@end


@implementation NPPacket(Tail)

+(NSData *)tailData
{
    return nil;
}

@end


@implementation NPPacket (Parser)


-(NSData *)peekCachedData
{
    return [_cache cachePeek];
}

-(NSInteger)tryFillPacketWithData:(NSData *)data
{
    if (_fillFailed) {
        return NP_FILLRESULT_FAIL;
    }
    
    if (_filled) {
        return [data length];
    }

    [_cache cachePush:data];
    
    NSString *nextHeader;
    NSNumber *nextHeaderLen;
    NSData *fillData;
    
    
    // Try fill data into header fields....
    if (!_headerFilled) {
        
        [self nextHeaderIs:&nextHeader andLengthIs:&nextHeaderLen];
        while (nextHeader) {
            if (nextHeaderLen==nil) {
//#pragma mark Logical issue.
                fillData=[NSData data];
            } else if ([nextHeaderLen unsignedIntegerValue]>[_cache cacheLength]) {
                return NP_FILLRESULT_NEEDMORE;
            } else {
                fillData=[_cache cachePullWithLength:[nextHeaderLen unsignedIntegerValue]];
            }
            
            if ([self setData:fillData toField:nextHeader]==NO)
            {
//#pragma mark HOW TO close this pakcet? or just reflush it?
                // _filled=YES; ?
                _fillFailed=YES;
                return NP_FILLRESULT_FAIL;
            }
            [self nextHeaderIs:&nextHeader andLengthIs:&nextHeaderLen];
        }
        
        if ([self endHeaders]==NO) {
            _fillFailed=YES;
            return NP_FILLRESULT_FAIL;
        }
    }
    
    // if segment of the top had exited, header fields should been filled.
    assert(_headerFilled);
    
    fillData=nil;
    
    // Try fill data into contents...
    if (!_filled)
    {
        NSInteger bytesLeft=[self bytesLeftToFill];
        NSInteger contentLen=[self contentLengthToFill];
        
        BOOL endFlag=NO;
        
        if (bytesLeft>=0 && contentLen>=0) {  // check if logically match.
            if (bytesLeft+[self contentLengthFilled]==contentLen) {
                contentLen=NP_FILLRESULT_UNUSED;  // if matched, set one of the return value to unused.
            } else {
                assert(false);   // do not logically match, assertion failed.
            }
        }
        
        if (bytesLeft==NP_FILLRESULT_NEEDMORE && contentLen==NP_FILLRESULT_NEEDMORE) {  // all need more.
            /*fillData=[self cacheDataPull];
            endFlag=NO;*/
            contentLen=NP_FILLRESULT_UNUSED;
        }
        
        if (bytesLeft==NP_FILLRESULT_UNUSED && contentLen==NP_FILLRESULT_UNUSED) {   // all unused.
            fillData=[_cache cachePull];
            endFlag=YES;
        } else {                                                                    // not all unused. And with checks upside, at least one should be unused.
            assert(bytesLeft==NP_FILLRESULT_UNUSED || contentLen==NP_FILLRESULT_UNUSED);
            
            NSInteger lengthToPull=NP_FILLRESULT_NEEDMORE;
            if (bytesLeft==NP_FILLRESULT_UNUSED && contentLen!=NP_FILLRESULT_UNUSED) {  // only content length is used
                if (contentLen!=NP_FILLRESULT_NEEDMORE) {
                    lengthToPull=contentLen-[self contentLengthFilled];
                }
            }
            
            if (bytesLeft!=NP_FILLRESULT_UNUSED && contentLen==NP_FILLRESULT_UNUSED) {
                if (bytesLeft!=NP_FILLRESULT_NEEDMORE) {
                    lengthToPull=bytesLeft;
                }
               
            }
            
            if (lengthToPull>[_cache cacheLength] || lengthToPull==NP_FILLRESULT_NEEDMORE) {
                fillData=[_cache cachePull];
                endFlag=NO;
            } else {
                fillData=[_cache cachePullWithLength:lengthToPull];
                endFlag=YES;
            }
            
        }
        
        
        // execute fill content.
        //assert(fillData);
        if (fillData) {
            [self fillContent:fillData];
        }
        
        if (endFlag) {
            if ([self tryEndPacket]) {
                return [_cache cacheLength];
            } else {
                _fillFailed=YES;
                return NP_FILLRESULT_FAIL;
            }
        } else {
            return NP_FILLRESULT_NEEDMORE;
        }
    }
    
    // Here should not arrive..
    
    /*assert(_headerFilled);
    assert(_filled);*/
    assert(false);
    
    
    
    //return [self cacheBuffLength];
}

-(void)nextHeaderIs:(NSString *__autoreleasing *)refHeaderKey andLengthIs:(NSNumber *__autoreleasing *)refHeaderLength
{
    assert([[self class]isFlexible]==NO); // Flexible type should not call this method.
    
    NSUInteger hIndex=[_headers indexOfObjectIdenticalTo:[[self class]emptyObject]];
    if (hIndex==NSNotFound) {
        *refHeaderKey=nil;
        *refHeaderLength=nil;
    } else {
        *refHeaderKey=[[self headerFieldsDescription] objectAtIndex:hIndex];
        
        if ([[[self class]headerFieldsLength] objectAtIndex:hIndex]==[[self class]emptyObject]) {
            *refHeaderLength=nil;
        } else {
            assert([[[[self class]headerFieldsLength] objectAtIndex:hIndex] isKindOfClass:[NSNumber class]]);
            *refHeaderLength=[[[self class]headerFieldsLength] objectAtIndex:hIndex];
        }
    }
}

-(BOOL)tryEndPacket
{
    /* virtual */
    if ([[self class]tailData]) {
        NSUInteger tailLen=[[[self class ]tailData] length];
        if (tailLen>0) {
            if ([_contentData length]<tailLen) {
                return NO;
            }
            NSRange rangeTail={[_contentData length]-tailLen,tailLen};
            NSRange rangeRet=[_contentData rangeOfData:[[self class]tailData] options:0 range:rangeTail];
            if (rangeRet.location==NSNotFound) {
                return NO;
            } else {
                [_contentData replaceBytesInRange:rangeTail withBytes:NULL length:0];
            }
            //NSData *contentTail=[NSData dataWithData:[_contentData ]]
        }        
    }
    
    
    _filled=YES;
    return YES;
}

-(NSInteger)contentLengthToFill
{
    /* virtual */
    return NP_FILLRESULT_UNUSED;
}

-(NSInteger)bytesLeftToFill
{
    /* virtual */
    return NP_FILLRESULT_UNUSED;
}


@end


/*-(NSInteger)fillPacketWithData:(NSData *)data
 {
 if (_packetData==nil) {
 _packetData=[[NSMutableData alloc] initWithData:data];
 } else {
 [_packetData appendData:data];
 }
 return [data length];
 }
 
 -(NSInteger)fillPacketWithData:(NSData *)data andLength:(NSUInteger)length
 {
 if (_packetData==nil) {
 _packetData=[[NSMutableData alloc] init];
 }
 NSUInteger actualLength=(length>[data length]?[data length]:length);
 [_packetData appendBytes:[data bytes] length:actualLength];
 return actualLength;
 
 }*/


/*-(void)cacheDataPush:(NSData *)data
 {
 if (_cacheQueue==nil) {
 _cacheQueue=[NSMutableData dataWithData:data];
 } else {
 [_cacheQueue appendData:data];
 }
 }
 
 -(NSData *)cacheDataPull:(NSUInteger)length
 {
 assert(length<=[_cacheQueue length]);
 if (length==[_cacheQueue length]) {
 return [self cacheDataPull];
 } else if (length==0) {
 return nil;
 } else {
 NSData *data=[NSData dataWithBytes:[_cacheQueue bytes] length:length];
 NSRange range={0, length};
 [_cacheQueue replaceBytesInRange:range withBytes:NULL length:0];
 return data;
 }
 }
 
 -(NSData *)cacheDataPull
 {
 NSData *data=_cacheQueue;
 _cacheQueue=nil;
 return data;
 }
 
 -(NSData *)peekCachedData
 {
 return _cacheQueue;
 }
 
 -(NSUInteger)cacheBuffLength
 {
 if (_cacheQueue) {
 return [_cacheQueue length];
 }
 return 0;
 }*/
