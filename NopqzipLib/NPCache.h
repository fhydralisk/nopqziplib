//
//  NPCache.h
//  NPTcpServer
//
//  Created by 樊航宇 on 15/3/11.
//  Copyright (c) 2015年 樊航宇. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NPCache : NSObject


-(NSData *)cachePull;
-(NSData *)cachePullWithLength:(NSUInteger) length;

-(NSData *)cachePop;
-(NSData *)cachePopWithLength:(NSUInteger) length;

-(NSData *)cachePeek;

-(NSUInteger)cacheLength;

-(void)cachePush:(NSData *)data;
-(void)cacheClear;



@end
