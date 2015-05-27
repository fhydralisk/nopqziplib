//
//  NPStreamManager.m
//  NPTcpServer
//
//  Created by 樊航宇 on 15/3/11.
//  Copyright (c) 2015年 樊航宇. All rights reserved.
//
#import "NPMacro.h"
#import "NPStreamManager.h"
#import "NPCache.h"
#include <CoreFoundation/CoreFoundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <Security/Security.h>

#define READ_BUFFSIZE 1024


@interface NSStream (QNetworkAdditions)

+ (void)qNetworkAdditions_getStreamsToHostNamed:(NSString *)hostName
                                           port:(UInt16)port
                                    inputStream:(out NSInputStream **)inputStreamPtr
                                   outputStream:(out NSOutputStream **)outputStreamPtr;

@end

@implementation NSStream (QNetworkAdditions)

+ (void)qNetworkAdditions_getStreamsToHostNamed:(NSString *)hostName
                                           port:(UInt16)port
                                    inputStream:(out NSInputStream **)inputStreamPtr
                                   outputStream:(out NSOutputStream **)outputStreamPtr
{
    CFReadStreamRef     readStream;
    CFWriteStreamRef    writeStream;
    
    assert(hostName != nil);
    assert( port > 0 );
    assert( (inputStreamPtr != NULL) || (outputStreamPtr != NULL) );
    
    readStream = NULL;
    writeStream = NULL;
    
    CFStreamCreatePairWithSocketToHost(
                                       NULL,
                                       (__bridge CFStringRef) hostName,
                                       port,
                                       ((inputStreamPtr  != NULL) ? &readStream : NULL),
                                       ((outputStreamPtr != NULL) ? &writeStream : NULL)
                                       );
    
    if (inputStreamPtr != NULL) {
        *inputStreamPtr  = CFBridgingRelease(readStream);
    }
    if (outputStreamPtr != NULL) {
        *outputStreamPtr = CFBridgingRelease(writeStream);
    }
}

@end

@implementation NPStreamManager
{
    NSThread *_threadConnect;
    //NSInputStream *_inputStream;
    //NSOutputStream *_outputStream;
    //NSInputStream *_server2ClientStream;
    //NSOutputStream *_client2ServerStream;
    //NSMutableData *_dataCached;
    
    NPCache *_cache;
    
    BOOL _connected;
    BOOL _connecting;
    NSLock *_lockSend;
}

-(void)doInitVariables
{
    _lockSend=[NSLock new];
    _cache=[NPCache new];
    _selfManageThread=nil;
    _connectTimeOut=10.0;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self doInitVariables];
    }
    return self;
}

-(instancetype)initWithInputStream:(NSInputStream *)inputStream andOutputStream:(NSOutputStream *)outputStream
{
    self=[super init];
    if (self) {
        [self doInitVariables];
        [self connectWithInputStream:inputStream andOutputStream:outputStream];
    }
    return self;
}


-(BOOL)checkConnecting
{
    return (_connecting || _connected || _inputStream!=nil || _outputStream!=nil);
}

-(BOOL) isConnectedOrConnecting
{
    return _connected || _connecting;
}

-(void)connectWithInputStream:(NSInputStream *)inputStream andOutputStream:(NSOutputStream *)outputStream
{
    assert(inputStream!=nil && outputStream!=nil);
    _inputStream=inputStream;
    _outputStream=outputStream;
    
    _connecting=YES;
    [self prepareThread];
    //_connected=YES;

    
}



-(BOOL)connectWithNativeSocket:(CFSocketNativeHandle)nativeSocket
{
    if ([self checkConnecting]) {
        return NO;
    }
    
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocket, &readStream, &writeStream);
    
    
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
    _inputStream=CFBridgingRelease(readStream);
    _outputStream=CFBridgingRelease(writeStream);
    
    _connecting=YES;
    [self prepareThread];
    
    //_connected=YES;
    return YES;

}


-(BOOL)connectTo:(NSString *)domain withPort:(UInt16)port
{
    if (port==0 || domain==nil) {
        return NO;
    }
    
    if ([self checkConnecting]) {
        return NO;
    }
    
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
    [NSStream qNetworkAdditions_getStreamsToHostNamed:domain port:port inputStream:&inputStream outputStream:&outputStream];
    
    if (inputStream==nil || outputStream==nil) {
        [inputStream close];
        [outputStream close];
        return NO;
    }
    _inputStream=inputStream;
    _outputStream=outputStream;
    
    _connecting=YES;
    [self prepareThread];
    
    //_connected=YES;

    
    return YES;
}


-(void)disconnect
{
    
    /*if (_connected==NO) {
     return;
     }*/
    if (_inputStream==nil && _outputStream==nil)
    {
        _connected=NO;
        return;
    }
    
    if (_inputStream) {
        [_inputStream close];
        _inputStream=nil;
    }
    
    if (_outputStream)
    {
        [_outputStream close];
        _outputStream=nil;
    }
    
    //[self cacheCut:[self cacheLength]];
    [_cache cacheClear];
    
    if ([_delegate respondsToSelector:@selector(streamManagerDidDisconnect:)] && (_connected || _connecting)) {
        [_delegate streamManagerDidDisconnect:self];
    }
    _connecting=NO;
    _connected=NO;
}

-(void)sendData:(NSData *)data
{
    [self sendDataSafely:data];
}

-(void)getIpAddress:(NSString *__autoreleasing *)ipAddress andPort:(UInt16 *)port
{
    //NSString *retString=nil;
    if (_connected) {
        
        CFSocketNativeHandle sock=[self getNativeSocketWithInputStream:_inputStream];
        //CFRelease(nativeSocketData);
        
        CFSocketRef lcfSocket=CFSocketCreateWithNative(kCFAllocatorDefault, sock, 0, NULL, NULL);
        
        CFDataRef lcfdSocketAddr=CFSocketCopyAddress(lcfSocket);
        
        //char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
        struct sockaddr *pSockAddr = (struct sockaddr *) CFDataGetBytePtr (lcfdSocketAddr);
        struct sockaddr_in  *pSockAddrV4 = (struct sockaddr_in *) pSockAddr;
        //struct sockaddr_in6 *pSockAddrV6 = (struct sockaddr_in6 *)pSockAddr;
        
        if (pSockAddr->sa_family==AF_INET) {
            UInt32 ip=ntohl(pSockAddrV4->sin_addr.s_addr);
            *ipAddress=[NSString stringWithFormat:@"%d.%d.%d.%d",ip>>24,(ip>>16)%0x100,(ip>>8)%0x100,ip%0x100];
            *port=ntohs(pSockAddrV4->sin_port);
        }
        
        if (pSockAddr->sa_family==AF_INET6) {
            //unsupported yet;
        }
        
        /*const void *pAddr = (pSockAddr->sa_family == AF_INET) ?
         (void *)(&(pSockAddrV4->sin_addr)) :
         (void *)(&(pSockAddrV6->sin6_addr));
         
         
         //const char *pStr = inet_ntop (pSockAddr->sa_family, pAddr, addrBuf, sizeof(addrBuf));
         if (pStr == NULL) [NSException raise: NSInternalInconsistencyException
         format: @"Cannot convert address to string."];*/
        
        
        CFRelease(lcfdSocketAddr);
        CFRelease(lcfSocket);
        //return [NSString stringWithCString:pStr encoding:NSASCIIStringEncoding];
    }
    return;
}


-(void)sendDataSafely:(NSData *)data
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
        if (_connected==NO) {
            return;
        }
        if (![_outputStream hasSpaceAvailable]) {
            return;
        }
        if ([_cache cacheLength]==0) {
            if ([_delegate respondsToSelector:@selector(streamManagerCanSendData:)]) {
                [_delegate performSelector:@selector(streamManagerCanSendData:) withObject:self];
            }
            return;
        }

        NSInteger written=[_outputStream write:[[_cache cachePeek] bytes] maxLength:[_cache cacheLength]];
        if (written<=0) {
            [self disconnect];
            return;
            //[self cacheCut:[self cacheLength]];
        }
        [_cache cachePullWithLength:written];
    }
}

-(NSUInteger)bytesLeftToSend
{
    return [_cache cacheLength];
}


-(void)didReceiveData
{
    NSData *data;
    NSInteger len;
    uint8_t buffer[READ_BUFFSIZE];
    len=[_inputStream read:buffer maxLength:sizeof(buffer)];
    if (len>0)
    {
        data=[NSData dataWithBytes:buffer length:len];
        if ([_delegate respondsToSelector:@selector(streamManager:didReceiveData:)]) {
            [_delegate streamManager:self didReceiveData:data];
        }
        //[self didReceiveData:data];
    } else {
        [self disconnect];
    }
    
}

-(void)setStreamProperty:(id)property forKey:(NSString *)key
{
    if ([self checkConnecting]==NO) {
        return;
    }
    [_inputStream setProperty:property forKey:key];
    [_outputStream setProperty:property forKey:key];
}

// Background Holding Thread

-(void)prepareThread
{
    [_inputStream setDelegate:self];
    [_outputStream setDelegate:self];
    
    if ([_delegate respondsToSelector:@selector(streamManagerShouldOpen:)]) {
        if ([_delegate streamManagerShouldOpen:self]==NO) {
            [self disconnect];
            return;
        };
    }
    
    // start connect timeout timer on main thread
    [self performSelectorOnMainThread:@selector(mainThreadCheckConnection) withObject:nil waitUntilDone:NO];
//#pragma mark NEED MODIFY HERE
    /*if (_tls) {
        [self setStreamProperty:NSStreamSocketSecurityLevelTLSv1 forKey:NSStreamSocketSecurityLevelKey];
        
        NSData *data=[NSData dataWithContentsOfFile:@"/Users/Hydralisk/Documents/code/APNs/aps_development.cer"];
        SecCertificateRef cert=SecCertificateCreateWithData(NULL, (__bridge CFDataRef)(data));
        //SecKeychainRef keychain;
        //SecKeychainOpen(NULL, &keychain);
        //SecKeychainCopyDefault(&keychain);
        SecIdentityRef identity=0;
        SecIdentityCreateWithCertificate(NULL, cert, &identity);
        
        CFRelease(cert);
        //CFRelease(keychain);
        
        
        //SecIdentityRef identity;
        //SecIdentityCopySystemIdentity((__bridge CFStringRef)@"com.Nopqzip.iosHello", &identity, NULL);
        
        NSDictionary *sslSettings=[NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObjects:(__bridge id)(identity), nil], kCFStreamSSLCertificates, nil];
        
        //NSInputStream *inputStream=_inputStream;
        
     
        
        CFReadStreamSetProperty((__bridge CFReadStreamRef)_inputStream, kCFStreamPropertySSLSettings, (__bridge CFTypeRef)(sslSettings));
        CFWriteStreamSetProperty((__bridge CFWriteStreamRef)_outputStream, kCFStreamPropertySSLSettings, (__bridge CFTypeRef)(sslSettings));
        CFRelease(identity);
        
        
    }*/
    
    //_delegate=engineDegelate;
    if (_selfManageThread==nil) {
        _threadConnect=[[NSThread alloc]initWithTarget:self selector:@selector(threadConnection) object:nil];
        [_threadConnect start];
    } else {
        [self performSelector:@selector(scheduleStreamInRunloop) onThread:_selfManageThread withObject:nil waitUntilDone:NO];
    }

}

-(void)connected
{
    _connected=YES;
    _connecting=NO;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkConnectTimeOut) object:nil];
    if ([_delegate respondsToSelector:@selector(streamManagerDidConnect:)]) {
        [_delegate streamManagerDidConnect:self];
    }
    
}
-(void)mainThreadCheckConnection
{
    [self performSelector:@selector(checkConnectTimeOut) withObject:nil afterDelay:_connectTimeOut];
}

-(void)checkConnectTimeOut
{
    if (_connecting) {
        //_connecting=NO;
        //_connected=NO;
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(connected) object:nil];
        [self disconnect];
    }
}



-(void)scheduleStreamInRunloop
{
    [_inputStream open];
    [_outputStream open];
    [_inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

-(void)threadConnection
{
    assert(_selfManageThread==NO);
    NSRunLoop *runloop=[NSRunLoop currentRunLoop];
    
    [self scheduleStreamInRunloop];
    
    while (_connected || _connecting) {
        [runloop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
}

// Stream delegate

-(void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventEndEncountered:
            [self performSelectorOnMainThread:@selector(disconnect) withObject:nil waitUntilDone:NO];
            break;
            
        case NSStreamEventHasBytesAvailable:
            //[self didReceiveData];
            [self performSelectorOnMainThread:@selector(didReceiveData) withObject:nil waitUntilDone:NO];
            break;
        case NSStreamEventHasSpaceAvailable:
            //NPLog(@"byte alvi");
            [self performSelectorOnMainThread:@selector(continueSendData) withObject:nil waitUntilDone:NO];
            break;
        case NSStreamEventErrorOccurred:
            //[self disconnect];
            [self performSelectorOnMainThread:@selector(disconnect) withObject:nil waitUntilDone:NO];
            break;
        case NSStreamEventOpenCompleted:
            if (aStream==_outputStream) {
                
                [self performSelectorOnMainThread:@selector(connected) withObject:nil waitUntilDone:NO];
             }
            break;
        default:
            break;
    }
}


// socket methods

-(CFSocketNativeHandle)getNativeSocketWithInputStream:(NSInputStream *)stream
{
    CFReadStreamRef lcfReadStream=(__bridge CFReadStreamRef)(stream);
    CFDataRef nativeSocketData = CFReadStreamCopyProperty(lcfReadStream, kCFStreamPropertySocketNativeHandle);
    CFSocketNativeHandle sock=*(int *)CFDataGetBytePtr(nativeSocketData);
    CFRelease(nativeSocketData);
    return sock;
}
@end
