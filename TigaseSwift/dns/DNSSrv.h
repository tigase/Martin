//
// dns.h
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

#ifndef dnssrv_h
#define dnssrv_h

#include <stdio.h>
struct DNSSrvRecord {
    char *target;
    uint16_t priority;
    uint16_t weight;
    uint16_t port;
};

//struct DNSSrvResult {
//    struct DNSSrvRecord* data;
//    int count;
//    void (*callback)(struct DNSSrvResult *records);
//    int hasResult;
//};

int32_t DNSQuerySRVRecord(const char* fullname, void *srvRecords, void (*callbackOnSrvRecord)(struct DNSSrvRecord*, void * resolver), void (*callbackonFinieshed)(int err, void * resolver));

//struct DNSSrvRecord* DNSSrvResultGetRecord(struct DNSSrvResult*, int pos);

#endif /* dnssrv_h */
