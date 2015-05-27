//
//  NPTCPServerClient+Engine.h
//  NPTcpServer
//
//  Created by 樊航宇 on 15/3/3.
//  Copyright (c) 2015年 樊航宇. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NPTCPServerClient.h"
#include "NPStreamManager.h"

@protocol NPConnectorDelegate <NSObject>


-(void)clientDidConnect:(NPTCPServerClient *)client;
-(void)clientDidDisconnect:(NPTCPServerClient *)client;
-(void)client:(NPTCPServerClient *)client didReceiveData:(NSData *)data;


@end

@interface NPTCPServerClient (Engine) <NPStreamManagerDelegate>



-(instancetype)initWithCFSocket:(CFSocketNativeHandle)s clientAddress:(void*)clientAddrRef andClientId:(NSInteger)clientId;

+(instancetype)clientWithCFSocket:(CFSocketNativeHandle)s clientAddress:(void*)clientAddrRef andClientId:(NSInteger)clientId;

-(void) setClientId:(NSInteger)clientId;

-(BOOL) connectToServerEngine:(id <NPConnectorDelegate> )engineDelegate withStreamThread:(NSThread *)thread;

-(void) disconnect;

-(NSUInteger)bytesLeftToSendQuery;

//-(BOOL) connectToServerEngine:(id <NPConnectorDelegate> )engineDelegate;
//-(void) scheduleStreamInRunloop;
//-(void) sendDataSafely:(NSData *)data;

/*-(NSData *) cachePeek;
-(void) cachePush:(NSData *)data;
-(NSUInteger) cacheLength;*/

//-(instancetype)init;



@end
