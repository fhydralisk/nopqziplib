//
//  NPCache.m
//  NPTcpServer
//
//  Created by 樊航宇 on 15/3/11.
//  Copyright (c) 2015年 樊航宇. All rights reserved.
//

#import "NPCache.h"

/*
    NPCache class:
 A class that caches data.
 */

@implementation NPCache {
    NSMutableData *_cacheData;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _cacheData=[NSMutableData data];
    }
    return self;
}

-(void)cacheClear
{
    @synchronized (_cacheData){
        _cacheData=[NSMutableData data];
    }
}

-(NSData *)cachePeek
{
    @synchronized (_cacheData){
        return _cacheData;
    }
}

-(NSData *)cachePull
{
    NSData *dataToPull=_cacheData;
    @synchronized (_cacheData){
        _cacheData=[NSMutableData data];
        return dataToPull;
    }
}

-(NSData *)cachePullWithLength:(NSUInteger)length
{
    assert(length<=[_cacheData length]);
    NSRange range={0,length};
    @synchronized (_cacheData){
        NSData *dataToPull=[_cacheData subdataWithRange:range];
        [_cacheData replaceBytesInRange:range withBytes:nil length:0];
        return dataToPull;
    }
}

-(NSData *)cachePop
{
    NSData *dataToPull=_cacheData;
    @synchronized (_cacheData){
        _cacheData=[NSMutableData data];
        return dataToPull;
    }
}

-(NSData *)cachePopWithLength:(NSUInteger)length
{
    assert(length<=[_cacheData length]);
    @synchronized (_cacheData){
        NSRange range={[_cacheData length]-length,length};
        NSData *dataToPull=[_cacheData subdataWithRange:range];
        [_cacheData replaceBytesInRange:range withBytes:nil length:0];
        return dataToPull;
    }

}

-(void)cachePush:(NSData *)data
{
    @synchronized(_cacheData)
    {
        assert(_cacheData);
        [_cacheData appendData:data];
    }
}

-(NSUInteger)cacheLength
{
    @synchronized(_cacheData)
    {
        assert(_cacheData);
        return [_cacheData length];
    }
}


@end
