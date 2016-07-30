//
// dns.c
//
// TigaseSwift
// Copyright (C) 2016 "Tigase, Inc." <office@tigase.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License,
// or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. Look for COPYING file in the top folder.
// If not, see http://www.gnu.org/licenses/.
//

#include "DNSSrv.h"

#ifdef __APPLE__

#include <string.h>
#include <stdlib.h>
#include <dns_util.h>
#include <dns_sd.h>

struct DNSQueryContext {
    void *resolver;
    void (*callback)(struct DNSSrvRecord *record, void *resolver);
};

void DNSQuerySRVRecordProcessReply(DNSServiceRef       sdRef,
                                   DNSServiceFlags     flags,
                                   uint32_t            interfaceIndex,
                                   DNSServiceErrorType errorCode,
                                   const char*         fullname,
                                   uint16_t            rrtype,
                                   uint16_t            rrclass,
                                   uint16_t            rdlen,
                                   const void*         rdata,
                                   uint32_t            ttl,
                                   void*               context) {
    
    if (errorCode != kDNSServiceErr_NoError) {
        // TODO: error during processing request - need to handle this
        return;
    }
    
    if ((flags & kDNSServiceFlagsMoreComing) == 0) {
        // TODO: no record received - handle this properly
    }
    
    uint32_t rrDataLen = 1+2+2+4+2+rdlen;
    char *rrData = malloc(rrDataLen);
    uint8_t u8;
    uint16_t u16;
    uint32_t u32;
    u8 = 0;
    memcpy(rrData, &u8, sizeof(u8));
    u16 = htons(kDNSServiceType_SRV);
    memcpy(rrData + 1, &u16, sizeof(u16));
    u16 = htons(kDNSServiceClass_IN);
    memcpy(rrData + 3, &u16, sizeof(u16));
    u32 = htonl(666);
    memcpy(rrData + 5, &u32, sizeof(u32));
    u16 = htons(rdlen);
    memcpy(rrData + 9, &u16, sizeof(u16));
    memcpy(rrData + 11, rdata, rdlen);
    
    dns_resource_record_t *rr = dns_parse_resource_record(rrData, rrDataLen);
    
    free(rrData);
    
    struct DNSSrvRecord data;
    if (rr != NULL) {
        data.priority = rr->data.SRV->priority;
        data.weight = rr->data.SRV->weight;
        data.port = rr->data.SRV->port;
        data.target = malloc(strlen(rr->data.SRV->target) + 1);
        memcpy(data.target, rr->data.SRV->target, strlen(rr->data.SRV->target) + 1);
        dns_free_resource_record(rr);
    }
    
    struct DNSQueryContext *dnsContext = (struct DNSQueryContext *) context;
    ((void (*)(struct DNSSrvRecord*, void *))dnsContext->callback)(&data, dnsContext->resolver);
    
    free(data.target);
}

int32_t DNSQuerySRVRecord(const char* fullname, void *resolver, void (*callbackOnSrvRecord)(struct DNSSrvRecord*, void *resolver), void (*callbackOnFinished)(int error, void *resolver)) {
    DNSServiceRef sdRef;
    DNSServiceErrorType err;
    struct DNSQueryContext context;
    context.callback = callbackOnSrvRecord;
    context.resolver = resolver;
    
    err = DNSServiceQueryRecord(&sdRef, kDNSServiceFlagsReturnIntermediates, kDNSServiceInterfaceIndexAny, fullname, kDNSServiceType_SRV, kDNSServiceClass_IN, DNSQuerySRVRecordProcessReply, &context);
    if (err != kDNSServiceErr_NoError) {
        return err;
    }
    
    int sdFd = DNSServiceRefSockFD(sdRef);
    if (sdFd < 0)
        return -1;
    
    fd_set readfds;
    int result;
    
    uint32_t timeout = 30;
    uint32_t remainingTime = timeout;
    time_t start = time(NULL);
    
    while (remainingTime > 0) {
        FD_ZERO(&readfds);
        FD_SET(sdFd, &readfds);
        
        struct timeval tv;
        tv.tv_sec = (time_t) remainingTime;
        tv.tv_usec = (__darwin_suseconds_t) ((remainingTime - tv.tv_sec) * 1000000);
        
        result = select(sdFd+1, &readfds, (fd_set*) NULL, (fd_set*) NULL, &tv);
        if (result == 1) {
            if (FD_ISSET(sdFd, &readfds)) {
                err = DNSServiceProcessResult(sdRef);
                break;
            }
        } else if (result == 0) {
            break;
        } else {
            err = -2;
            break;
        }
        
        remainingTime = timeout - (uint32_t)(time(NULL) - start);
    }
    
    DNSServiceRefDeallocate(sdRef);
    callbackOnFinished(err, resolver);
    return err;
}

#endif