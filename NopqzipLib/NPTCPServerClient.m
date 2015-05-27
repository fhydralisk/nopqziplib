//
//  NPTCPServerClient.m
//  NPTcpServer
//
//  Created by 樊航宇 on 15/3/2.
//  Copyright (c) 2015年 樊航宇. All rights reserved.
//
#import "NPMacro.h"
#import "NPTCPServerClient.h"
#import "NPTCPServerClient+Local.h"
#import "NPTCPServerClient+Engine.h"
#include <sys/socket.h>
#include <netinet/in.h>

@implementation NPTCPServerClient

@dynamic clientIp,clientId,port;

-(NSInteger)clientId
{
    return _clientId;
}

-(NSString *)clientIp
{
    NSString *retString;
    UInt16 port;
    [_streamManager getIpAddress:&retString andPort:&port];
    return retString;
}


-(NSInteger)port
{
    NSString *retString;
    UInt16 port;
    [_streamManager getIpAddress:&retString andPort:&port];
    return port;
}

-(void)dealloc
{
    NPLog(@"client%ld dealloced",(long)_clientId);
}

-(void)sendData:(NSData *)data
{
    //void *dataBuf;
    //[data getBytes:; length:]
    /*if (!_connected) {
        return;
    }
    if ([data length]>0) {
        [self sendDataSafely:data];
        //[_server2ClientStream write:[data bytes] maxLength:[data length]];
    }*/
    [_streamManager sendData:data];
}

-(NSUInteger)bytesLeftToSend
{
    return [self bytesLeftToSendQuery];
}

@end
