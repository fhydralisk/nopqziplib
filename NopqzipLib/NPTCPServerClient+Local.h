//
//  NPTcpServerClient+Local.h
//  NPTcpServer
//
//  Created by 樊航宇 on 15/3/3.
//  Copyright (c) 2015年 樊航宇. All rights reserved.
//

#ifndef NPTcpServer_NPTcpServerClient_Local_h
#define NPTcpServer_NPTcpServerClient_Local_h
#import "NPTCPServerClient.h"
#import "NPStreamManager.h"

@protocol NPConnectorDelegate;
//@class NPCache;


@interface NPTCPServerClient()
{
    CFSocketNativeHandle _nativeSocket;
    NSInteger _clientId;
    //NSInteger _port;
    //NSString * _clientIp;
    //NSInputStream *_client2ServerStream;
    //NSOutputStream *_server2ClientStream;
    //BOOL _connected;
    __weak id <NPConnectorDelegate> _delegate;
    //NSMutableData *_dataCached;
    //NPCache *_cache;
    NSLock *_lockSend;
    NPStreamManager *_streamManager;
    
}


@end

#endif
