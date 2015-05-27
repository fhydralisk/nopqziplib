//
//  NPTCPServer.m
//  NPTcpServer
//
//  Created by 樊航宇 on 15/3/2.
//  Copyright (c) 2015年 樊航宇. All rights reserved.
//
#import "NPMacro.h"
#import <ifaddrs.h>
#import "NPTCPServerEngine.h"
#import "NPPacket.h"
#import "NPTCPServerClient+Engine.h"

#define INITIAL_PORT 65535
@interface NPTCPServerEngine()
{
    NSThread *_listenThread;
    NSThread *_streamThread;
    unsigned int _port;
    CFSocketRef _listenCFSocket;
    NSMutableArray *_connectedClients;
    NSInteger _clientIndexing;
    NPPacket *_nextPacket;
    Class packetTypeClass;
}

-(NSInteger)clientIndexing;
-(void)appendIncomeClient:(NPTCPServerClient *)client;

@end

@interface NPTCPServerEngine (ClientDelegate) <NPConnectorDelegate>

@end

//typedef void (*CFSocketCallBack) ( CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info );
void handleIncomeConnect(CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info)
{
    
    if (callbackType==kCFSocketAcceptCallBack) {
        NPTCPServerEngine *engine=(__bridge NPTCPServerEngine*)info;
        NPTCPServerClient *incomeClient=[NPTCPServerClient clientWithCFSocket:*(CFSocketNativeHandle*)data clientAddress:(void*)CFDataGetBytePtr(address) andClientId:0];
        [engine performSelectorOnMainThread:@selector(appendIncomeClient:) withObject:incomeClient waitUntilDone:NO];
        NPLog(@"Attempt to connect");
    }
}

//CFSocketRef _listenCFSocket;


@implementation NPTCPServerEngine

@dynamic port;

// Initial methods

- (instancetype)init
{
    self = [super init];
    if (self) {
        self=[self initWithPort:INITIAL_PORT];
    }
    return self;
}

-(instancetype)initWithPort:(unsigned int)port
{
    self = [super init];
    if (self) {
        _listenCFSocket=NULL;
        _port=port;
        _clientIndexing=1;
        _connectedClients=[NSMutableArray arrayWithObjects:nil];
        _listenThread=nil;
        _streamThread=nil;
        packetTypeClass=nil;
        
    }
    return self;
    
}

+(instancetype)serverWithPort:(unsigned int)port
{
    NPTCPServerEngine* server=[[[self class]alloc]init];
    if (server) {
        [server setPort:port];
    }
    return server;
}

//properties

-(void)setPort:(unsigned int)port
{
    if (_port>65535)
        return;
    _port=port;
}

-(unsigned int)port
{
    return _port;
}

-(NSInteger)clientIndexing
{
    return _clientIndexing;
}

-(BOOL)setPacketClass:(Class)pktClass
{
    @synchronized (packetTypeClass){
        if ([pktClass isSubclassOfClass:[NPPacket class]]) {
            packetTypeClass=pktClass;
            return YES;
        }
    }
    return NO;
}
//socket initial method

-(BOOL)doInitCFSocket
{
    
    
    CFSocketContext cfsocketctx={0,(__bridge void*)self,NULL,NULL,NULL};
    _listenCFSocket=CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, handleIncomeConnect, &cfsocketctx);
    if (_listenCFSocket==NULL)
        return NO;
    
    
    struct sockaddr_in sin;
    memset(&sin, 0, sizeof(sin));
    sin.sin_addr.s_addr=INADDR_ANY;
    sin.sin_family=AF_INET;
    sin.sin_len=sizeof(sin);
    sin.sin_port=htons(_port);
    
    CFDataRef sincfd=CFDataCreate(kCFAllocatorDefault, (UInt8*)&sin, sizeof(sin));
    CFSocketError error=CFSocketSetAddress(_listenCFSocket, sincfd);
    CFRelease(sincfd);
    
    if (error!=kCFSocketSuccess) {
        CFRelease(_listenCFSocket);
        _listenCFSocket=NULL;
        return NO;
    }
    
    return YES;
}

// engine method

-(BOOL)startListen
{
    // Avoid restarting
    if (_listenCFSocket) {
        return NO;
    }
    
    // Init CfSocket
    [self doInitCFSocket];
    
    
    // Check if socket is prepared
    if (_listenCFSocket==NULL) {
        return NO;
    }
    
    
    _listenThread = [[NSThread alloc]initWithTarget:self selector:@selector(threadPerformListening) object:nil];
    [_listenThread start];
    return YES;
}


-(void)stopListen
{
    if (_listenCFSocket) {
        CFSocketInvalidate(_listenCFSocket);
        CFRelease(_listenCFSocket);
        _listenCFSocket=nil;
    }
}


-(NSArray *)connectedClients
{
    NSArray *retArray=[NSArray arrayWithArray:_connectedClients];
    return retArray;
}

-(void)disconnectClient:(NPTCPServerClient *)client
{
    if ([_connectedClients indexOfObjectIdenticalTo:client]!=NSNotFound) {
        [client disconnect];
    }
}

-(void)disconnectAll
{
    for (NPTCPServerClient* client in _connectedClients) {
        [client disconnect];
    }
}

-(void)sendPacket:(NPPacket *)packet toClient:(NPTCPServerClient *)client
{
    assert([packet isFilled]);
    [client sendData:[packet data]];
}

-(void)sendPacketToAll:(NPPacket *)packet
{
    assert([packet isFilled]);
    for (NPTCPServerClient* client in _connectedClients) {
        [client sendData:[packet data]];
    }
}

/*-(void)appendIncomeClient:(NPTCPServerClient *)client
{
    
    
    if ([client connectToServerEngine:self]==NO) {
        return;
    }
    
    
    [client setClientId:_clientIndexing++];
    @synchronized  (_connectedClients)
    {
        [_connectedClients addObject:client];
    }
    
    if (_streamThread==nil)
    {
        _streamThread=[[NSThread alloc]initWithTarget:self selector:@selector(threadManageStreams:) object:client];
        [_streamThread start];
    }
    else
    {
        [self performSelector:@selector(threadSchduleClient:) onThread:_listenThread withObject:client waitUntilDone:NO];
    }
    if ([_degelate respondsToSelector:@selector(clientDidConnect:)]) {
        [_degelate clientDidConnect:client];
    }
    
    //NPLog(@"client added. addr=%@, port=%ld, id=%ld",client.clientIp,(long)client.port,(long)client.clientId);
}*/

-(void)appendIncomeClient:(NPTCPServerClient *)client
{
    BOOL firstClient=NO;
    
    if (_streamThread==nil) {
        firstClient=YES;
        _streamThread=[[NSThread alloc]initWithTarget:self selector:@selector(threadManageStreams) object:nil];
    }
    
    [client setClientId:_clientIndexing++];
    @synchronized  (_connectedClients)
    {
        [_connectedClients addObject:client];
    }
    
    if (firstClient) {
        [_streamThread start];
    }


    if ([client connectToServerEngine:self withStreamThread:_streamThread]==NO) {
        if (firstClient) {
            @synchronized (_connectedClients)
            {
                [_connectedClients removeObjectIdenticalTo:client];
            }
            _streamThread=nil;
        }
        return;
    }
    
    
    
    
}

// threads

-(void)threadPerformListening
{
    CFRunLoopRef currentRunLoop=CFRunLoopGetCurrent();
    
    CFRunLoopSourceRef socketsource=CFSocketCreateRunLoopSource(kCFAllocatorDefault, _listenCFSocket, 0);
    CFRunLoopAddSource(currentRunLoop, socketsource, kCFRunLoopDefaultMode);
    CFRelease(socketsource);
    
    CFRunLoopRun();
    NPLog(@"Listening Thread exiting");
}

-(void)threadManageStreams
{
    //[self threadSchduleClient:firstClient];
    while (YES) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        @synchronized (_connectedClients)
        {
            if ([_connectedClients count]==0) {
                _streamThread=nil;
                NPLog(@"_streamThread exiting");
                return;
            }
        }
    }
}

/*-(void)threadSchduleClient:(NPTCPServerClient *)client
{
    [client scheduleStreamInRunloop];
}*/


//dealloc


-(void)dealloc
{
    [self disconnectAll];
    [self stopListen];
    if (_listenCFSocket) {
        CFSocketInvalidate(_listenCFSocket);
        CFRelease(_listenCFSocket);
        _listenCFSocket=NULL;
    }
    //NPLog(@"NSTcpServerEngine dealloced");
}

//other
+(NSArray *)serverIps
{
    NSMutableArray *array=[NSMutableArray array];
    struct ifaddrs *addrs_list,*addrs;
    BOOL success;
    
    success=getifaddrs(&addrs_list)==0;
    if (success) {
        addrs=addrs_list;
        while (addrs) {
            if (addrs->ifa_addr->sa_family==AF_INET) {
                unsigned int addr=NTOHL(((struct sockaddr_in *)(addrs->ifa_addr))->sin_addr.s_addr);
                if (addr!=0) {
                    NSString *strAddr=[NSString stringWithFormat:@"%d.%d.%d.%d",addr>>24,addr>>16&0xFF,addr>>8&0xFF,addr&0xFF];
                    [array addObject:strAddr];
                }
            }
            if (addrs->ifa_addr->sa_family==AF_INET6) {
                //unspported yet
            }
            addrs=addrs->ifa_next;
        }
        freeifaddrs(addrs);
    }
    
    
    return array;
}


@end


@implementation NPTCPServerEngine (ClientDelegate)


//client degelate

-(void)clientDidConnect:(NPTCPServerClient *)client
{
    if ([_delegate respondsToSelector:@selector(serverEngine:clientDidConnect:)]) {
        [_delegate serverEngine:self clientDidConnect:client];
    }
    
}

-(void)client:(NPTCPServerClient *)client didReceiveData:(NSData *)data
{
    if (packetTypeClass==nil) {
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
            if ([_delegate respondsToSelector:@selector(serverEngine:client:shouldDisconnectWithErrorPacket:)]) {
                if([_delegate serverEngine:self client:client shouldDisconnectWithErrorPacket:_nextPacket])
                {
                    [client disconnect];
                }
            }
            _nextPacket=nil;
            break;
        }
        
        if (ret==NP_FILLRESULT_NEEDMORE) {
            if ([_delegate respondsToSelector:@selector(serverEngine:client:isReceivingPacket:)]) {
                [_delegate serverEngine:self client:client isReceivingPacket:_nextPacket];
            }
            break;
        }
        
        if (ret>=0) {
            
            if ([_delegate respondsToSelector:@selector(serverEngine:client:isReceivingPacket:)]) {
                [_delegate serverEngine:self client:client isReceivingPacket:_nextPacket];
            }
            
            if ([_delegate respondsToSelector:@selector(serverEngine:client:didReceivePacket:)]) {
                [_delegate serverEngine:self client:client didReceivePacket:_nextPacket];
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

-(void)clientDidDisconnect:(NPTCPServerClient *)client
{
    @synchronized (_connectedClients)
    {
        [_connectedClients removeObject:client];
    }
    if (_delegate) {
        if ([_delegate respondsToSelector:@selector(serverEngine:clientDidDisconnect:)]) {
            [_delegate serverEngine:self clientDidDisconnect:client];
        }
    }
}


@end
