//
//  NPTCPServerClient+Engine.m
//  NPTcpServer
//
//  Created by 樊航宇 on 15/3/3.
//  Copyright (c) 2015年 樊航宇. All rights reserved.
//
#import "NPMacro.h"
#include <CoreFoundation/CoreFoundation.h>
#include <sys/socket.h>
#include <netinet/in.h>


#import "NPTCPServerClient+Engine.h"
#import "NPTCPServerClient+Local.h"
#import "NPCache.h"

#define READ_BUFFLEN 1024

@implementation NPTCPServerClient(Engine)


#pragma mark INITIAL
+(instancetype)clientWithCFSocket:(CFSocketNativeHandle)s clientAddress:(void *)clientAddrRef andClientId:(NSInteger)clientId
{
    NPTCPServerClient *client=[[[self class]alloc]initWithCFSocket:s clientAddress:clientAddrRef andClientId:clientId];
    return client;
}

-(instancetype)initWithCFSocket:(CFSocketNativeHandle)s clientAddress:(void *)clientAddrRef andClientId:(NSInteger)clientId
{
    self=[super init];
    if (self) {
        _nativeSocket=s;
        //struct sockaddr_in *addrRef=clientAddrRef;
        _clientId=clientId;
        //_clientIp=[NSIpString stringWithContentsOfIpAddress:ntohl(addrRef->sin_addr.s_addr)];
        //_port=ntohs(addrRef->sin_port);
        //_connected=NO;
        _lockSend=[[NSLock alloc]init];
        _streamManager=[NPStreamManager new];
        //_cache=[NPCache new];
        ///_dataCached=[NSMutableData data];
        ///NSString *ipAddr=[NSString stringw]
    }
    return self;
}

#pragma mark PROPERTY

-(void)setClientId:(NSInteger)clientId
{
    _clientId=clientId;
}

-(BOOL)connectToServerEngine:(id<NPConnectorDelegate>)engineDelegate withStreamThread:(NSThread *)thread
{
    _delegate=engineDelegate;
    if ([_streamManager isConnectedOrConnecting]) {
        return NO;
    }
    _streamManager.selfManageThread=thread;
    _streamManager.delegate=self;
    
    return [_streamManager connectWithNativeSocket:_nativeSocket];
    //sleep(1);
    //return YES;
}


-(void)disconnect
{
    [_streamManager disconnect];
}


-(NSUInteger)bytesLeftToSendQuery
{
    //return [_cache cacheLength];
    return [_streamManager bytesLeftToSend];
}

// NPStreamManager delegate

-(void)streamManagerDidDisconnect:(NPStreamManager *)streamManager
{
    [_delegate clientDidDisconnect:self];
}

-(void)streamManager:(NPStreamManager *)streamManager didReceiveData:(NSData *)data
{
    [_delegate client:self didReceiveData:data];
}

-(void)streamManagerDidConnect:(NPStreamManager *)streamManager
{
    [_delegate clientDidConnect:self];
}



@end

/*-(NSData *)cachePeek
 {
 @synchronized(_dataCached)
 {
 return _dataCached;
 }
 }
 
 -(void)cachePush:(NSData *)data
 {
 @synchronized(_dataCached)
 {
 assert(_dataCached);
 [_dataCached appendData:data];
 }
 }
 
 -(NSUInteger)cacheLength
 {
 @synchronized(_dataCached)
 {
 assert(_dataCached);
 return [_dataCached length];
 }
 }
 
 -(void)cacheCut:(NSUInteger) length
 {
 @synchronized(_dataCached)
 {
 if (length==0)
 return;
 assert(length<=[_dataCached length]);
 assert(_dataCached);
 
 NSRange range={0,length};
 [_dataCached replaceBytesInRange:range withBytes:NULL length:0];
 }
 
 }
 */
/*-(BOOL)connectToServerEngine:(id <NPConnectorDelegate>) engineDegelate
 {
 if (_connected) {
 return NO;
 }
 
 if (_cfSocket==0) {
 return NO;
 }
 
 CFReadStreamRef readStream;
 CFWriteStreamRef writeStream;
 CFStreamCreatePairWithSocket(kCFAllocatorDefault, _cfSocket, &readStream, &writeStream);
 
 
 if (readStream==NULL || writeStream==NULL) {
 if (readStream) {
 CFRelease(readStream);
 }
 if (writeStream) {
 CFRelease(writeStream);
 }
 return NO;
 }
 
 CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
 _client2ServerStream=CFBridgingRelease(readStream);
 _server2ClientStream=CFBridgingRelease(writeStream);
 
 [_client2ServerStream setDelegate:self];
 [_server2ClientStream setDelegate:self];
 
 _delegate=engineDegelate;
 
 _connected=YES;
 
 return YES;
 
 
 //[NSStream ]
 }*/

/*-(void)scheduleStreamInRunloop
 {
 [_client2ServerStream open];
 [_server2ClientStream open];
 [_client2ServerStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
 [_server2ClientStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
 }*/

/*-(void)disconnect
 {
 
 if (_connected==NO) {
 return;
 }
 
 if (_server2ClientStream==nil && _client2ServerStream==nil) {
 _connected=NO;
 return;
 }
 [_client2ServerStream close];
 [_server2ClientStream close];
 
 _client2ServerStream=nil;
 _server2ClientStream=nil;
 
 
 [_cache cacheClear];
 
 //[self cacheCut:[self cacheLength]];
 if (_connected) {
 [_delegate clientDidDisconnect:self];
 }
 _connected=NO;
 
 //NPLog(@"client:%ld disconnected",(long)_clientId);
 
 
 }*/
// send management

/*-(void)sendDataSafely:(NSData *)data
 {
 if (_connected==NO)
 return;
 
 [_cache cachePush:data];
 [self continueSendData];
 }
 
 -(void)continueSendData
 {
 @synchronized (_lockSend)
 {
 if ([_cache cacheLength]==0) {
 return;
 }
 if (_connected==NO) {
 return;
 }
 NSInteger written=[_server2ClientStream write:[[_cache cachePeek] bytes] maxLength:[_cache cacheLength]];
 if (written<=0) {
 [self disconnect];
 [_cache cacheClear];
 return;
 //[self cacheCut:[self cacheLength]];
 }
 [_cache cachePullWithLength:written];
 }
 }*/


//degelate

/*-(void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
 {
 switch (eventCode) {
 case NSStreamEventErrorOccurred:
 NPLog(@"disconnect suddenly");
 [self disconnect];
 break;
 case NSStreamEventEndEncountered:
 NPLog(@"disconnect normally");
 [self disconnect];
 break;
 
 case NSStreamEventOpenCompleted:
 NPLog(@"stream opend");
 break;
 case NSStreamEventHasSpaceAvailable:
 [self continueSendData];
 break;
 case NSStreamEventHasBytesAvailable:
 //[self performSelectorOnMainThread:@selector(didReceiveData) withObject:nil waitUntilDone:NO];
 [self didReceiveData];
 break;
 default:
 break;
 }
 }*/

/*-(void)didReceiveData
 {
 NSData *data;
 uint8_t buffer[READ_BUFFLEN];
 NSUInteger len;
 
 //[_client2ServerStream getBuffer:&ptrBuffer length:&bufLen];
 
 //ptrBuffer=malloc(bufLen);
 len=[_client2ServerStream read:buffer maxLength:sizeof(buffer)];
 if (len>0)
 {
 data=[NSData dataWithBytes:buffer length:len];
 [_delegate client:self didReceiveData:data];
 } else {
 [self disconnect];
 }
 }*/
