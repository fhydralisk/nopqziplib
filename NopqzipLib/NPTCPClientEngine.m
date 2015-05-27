//
//  NPTCPClient.m
//  NPTcpServer
//
//  Created by 樊航宇 on 15/3/2.
//  Copyright (c) 2015年 樊航宇. All rights reserved.
//

#import "NPTCPClientEngine.h"
#import "NPPacket.h"
#import "NPCache.h"
#import "NPStreamManager.h"

#include <CoreFoundation/CoreFoundation.h>
#include <sys/socket.h>
#include <netinet/in.h>


#define READ_BUFFSIZE 1024


@implementation NPTCPClientEngine
{
    NSThread *_threadConnect;
    NPStreamManager *_streamManager;
    //NSMutableData *_dataCached;
    
    //BOOL _connected;
    Class packetTypeClass;
    NSLock *_lockSend;
    NPPacket *_nextPacket;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self=[self initWithPort:0 andDomain:nil];
    }
    return self;
}

-(instancetype)initWithPort:(UInt16)port andDomain:(NSString *)domain
{
    self = [super init];
    if (self) {
        _serverPort=port;
        _serverDomain = domain;
        _threadConnect=nil;
        _streamManager=nil;
        //_dataCached=[NSMutableData data];
        _nextPacket=nil;
        _lockSend=[NSLock new];
    }
    return self;

}

-(BOOL)isConnected
{
    return [_streamManager isConnectedOrConnecting];
}

-(BOOL)setPacketType:(Class)packetClass
{
    if (![packetClass isSubclassOfClass:[NPPacket class]]) {
        return NO;
    }
    packetTypeClass=packetClass;
    return YES;
}

-(BOOL)connect
{
    if (_serverPort==0 || _serverDomain==nil) {
        return NO;
    }
    
    if (_streamManager!=nil && [_streamManager isConnectedOrConnecting]) {
        return NO;
    }
    
    _streamManager=[NPStreamManager new];
    [_streamManager setDelegate:self];
    /*if (_serverTLS) {
        _streamManager.tls=YES;
    }*/
    
    
    return [_streamManager connectTo:_serverDomain withPort:_serverPort];
}




-(void)sendPacket:(NPPacket *)packet
{
    [self sendData:[packet data]];
}

-(void)sendData:(NSData *)data
{
    [_streamManager sendData:data];
}


-(void)disconnect
{
    [_streamManager disconnect];
}



-(NSUInteger)bytesLeftToSend
{
    return [_streamManager bytesLeftToSend];
}

-(NSString *)getServerIp
{
    NSString *ipAddress=nil;
    UInt16 port;
    [_streamManager getIpAddress:&ipAddress andPort:&port];
    return ipAddress;

}



// NPStreamManagerDelegate

-(void)streamManagerDidConnect:(NPStreamManager *)streamManager
{
    /*if (_streamType) {
        [_streamManager setStreamProperty:_streamType forKey:NSStreamNetworkServiceType];
    }*/
    if ([_delegate respondsToSelector:@selector(clientEngineDidConnectToServer:)]) {
        [_delegate clientEngineDidConnectToServer:self];
    }
}

-(void)streamManagerDidDisconnect:(NPStreamManager *)streamManager
{
    if ([_delegate respondsToSelector:@selector(clientEngineDidDisconnect:)]) {
        [_delegate clientEngineDidDisconnect:self];
    }
}



-(void)streamManager:(NPStreamManager *)streamManager didReceiveData:(NSData *)data
{
    if (packetTypeClass==nil) {
        if ([_delegate respondsToSelector:@selector(clientEngine:didReceiveData:)]) {
            [_delegate clientEngine:self didReceiveData:data];
        }

        return;
    }
    @synchronized (packetTypeClass) {
        if (!_nextPacket)
        {
            _nextPacket=[[packetTypeClass alloc]init];
        }
    }
    assert(![_nextPacket isFilled]);
    assert(![_nextPacket isFillFailed]);
    
    
    while (YES) {
        NSInteger ret=[_nextPacket tryFillPacketWithData:data];
        if (ret==NP_FILLRESULT_FAIL) {
            // Fill failed.
            if ([_delegate respondsToSelector:@selector(clientEngine:didReceiveErrorPacket:)]) {
                if([_delegate clientEngine:self didReceiveErrorPacket:_nextPacket])  //query the delegate if disconnect
                {
                    [self disconnect];
                }
            } else {
                [self disconnect];
            }
            _nextPacket=nil;
            break;
        }
        
        if (ret==NP_FILLRESULT_NEEDMORE) {
            if ([_delegate respondsToSelector:@selector(clientEngine:isReceivingPacket:)]) {
                [_delegate clientEngine:self isReceivingPacket:_nextPacket];
            }
            break;
        }
        
        if (ret>=0) {
            
            if ([_delegate respondsToSelector:@selector(clientEngine:isReceivingPacket:)]) {
                [_delegate clientEngine:self isReceivingPacket:_nextPacket];
            }
            
            if ([_delegate respondsToSelector:@selector(clientEngine:didReceivePacket:)]) {
                [_delegate clientEngine:self didReceivePacket:_nextPacket];
            }
            if (ret==0) {
                _nextPacket=nil;
                break;
            } else {
                @synchronized(packetTypeClass){
                    _nextPacket=[[packetTypeClass alloc]init];
                }
                NSRange range={[data length]-ret,ret};
                data=[NSData dataWithData:[data subdataWithRange:range]];
            }
        }
    }
    
}

-(void)streamManagerCanSendData:(NPStreamManager *)streamManager
{
    
}

-(void)dealloc
{
    [self disconnect];
}

@end




/*
-(NSString *)getServerIp
{
    NSString *retString=nil;
    if (_connected) {
        
        CFReadStreamRef lcfReadStream=(__bridge CFReadStreamRef)(_server2ClientStream);
        CFDataRef nativeSocketData = CFReadStreamCopyProperty(lcfReadStream, kCFStreamPropertySocketNativeHandle);
        CFSocketNativeHandle sock=*(int *)CFDataGetBytePtr(nativeSocketData);
        CFRelease(nativeSocketData);
        
        CFSocketRef lcfSocket=CFSocketCreateWithNative(kCFAllocatorDefault, sock, 0, NULL, NULL);
        
        CFDataRef lcfdSocketAddr=CFSocketCopyAddress(lcfSocket);
        
        //char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
        struct sockaddr *pSockAddr = (struct sockaddr *) CFDataGetBytePtr (lcfdSocketAddr);
        struct sockaddr_in  *pSockAddrV4 = (struct sockaddr_in *) pSockAddr;
        //struct sockaddr_in6 *pSockAddrV6 = (struct sockaddr_in6 *)pSockAddr;
        
        if (pSockAddr->sa_family==AF_INET) {
            UInt32 ipAddress=ntohl(pSockAddrV4->sin_addr.s_addr);
            retString=[NSString stringWithFormat:@"%d.%d.%d.%d",ipAddress>>24,(ipAddress>>16)%0x100,(ipAddress>>8)%0x100,ipAddress%0x100];
        }
        
        if (pSockAddr->sa_family==AF_INET6) {
            //unsupported yet;
        }*/
        
        /*const void *pAddr = (pSockAddr->sa_family == AF_INET) ?
         (void *)(&(pSockAddrV4->sin_addr)) :
         (void *)(&(pSockAddrV6->sin6_addr));
         
         
         //const char *pStr = inet_ntop (pSockAddr->sa_family, pAddr, addrBuf, sizeof(addrBuf));
         if (pStr == NULL) [NSException raise: NSInternalInconsistencyException
         format: @"Cannot convert address to string."];*/
        
        
        /*CFRelease(lcfdSocketAddr);
        CFRelease(lcfSocket);
        //return [NSString stringWithCString:pStr encoding:NSASCIIStringEncoding];
    }
    return  retString;*/

//}

/*-(void)disconnect
 {
 
 
 
 if (_server2ClientStream==nil && _client2ServerStream==nil)
 {
 _connected=NO;
 return;
 }
 
 if (_server2ClientStream) {
 [_server2ClientStream close];
 _server2ClientStream=nil;
 }
 
 if (_client2ServerStream)
 {
 [_client2ServerStream close];
 _client2ServerStream=nil;
 }
 
 //[self cacheCut:[self cacheLength]];
 [_cache cacheClear];
 
 if ([_delegate respondsToSelector:@selector(didDisconnect)] && _connected) {
 [_delegate didDisconnect];
 }
 _connected=NO;
 
 }*/


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
        NSInteger written=[_client2ServerStream write:[[_cache cachePeek] bytes] maxLength:[_cache cacheLength]];
        if (written<=0) {
            [self disconnect];
            return;
            //[self cacheCut:[self cacheLength]];
        }
        [_cache cachePullWithLength:written];
    }
}*/




/*-(void)didReceiveData
{
    NSData *data;
    NSInteger len;
    uint8_t buffer[READ_BUFFSIZE];
    len=[_server2ClientStream read:buffer maxLength:sizeof(buffer)];
    if (len>0)
    {
        data=[NSData dataWithBytes:buffer length:len];
        [self didReceiveData:data];
    } else {
        [self disconnect];
    }

}
-(void)threadConnection
{
    NSRunLoop *runloop=[NSRunLoop currentRunLoop];
    
    [_server2ClientStream open];
    [_client2ServerStream open];
    [_server2ClientStream setDelegate:self];
    [_client2ServerStream setDelegate:self];
    [_server2ClientStream scheduleInRunLoop:runloop forMode:NSRunLoopCommonModes];
    [_client2ServerStream scheduleInRunLoop:runloop forMode:NSRunLoopCommonModes];
    
    while (_connected) {
        [runloop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
}

-(void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventEndEncountered:
            [self disconnect];
            break;
            
        case NSStreamEventHasBytesAvailable:
            [self didReceiveData];
            break;
        case NSStreamEventHasSpaceAvailable:
            [self continueSendData];
            break;
        case NSStreamEventErrorOccurred:
            [self disconnect];
            break;
        case NSStreamEventOpenCompleted:
            if (aStream==_server2ClientStream) {
                [_delegate didConnectToServer];
            }
            break;
        default:
            break;
    }
}*/


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
 
 }*/


/*NSInputStream *inputStream;
 NSOutputStream *outputStream;
 [NSStream qNetworkAdditions_getStreamsToHostNamed:_serverDomain port:_serverPort inputStream:&inputStream outputStream:&outputStream];
 
 if (inputStream==nil || outputStream==nil) {
 [inputStream close];
 [outputStream close];
 return NO;
 }
 _server2ClientStream=inputStream;
 _client2ServerStream=outputStream;
 _threadConnect=[[NSThread alloc]initWithTarget:self selector:@selector(threadConnection) object:nil];
 _connected=YES;
 [_threadConnect start];*/


