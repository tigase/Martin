//
// SocketConnector.swift
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
import Foundation

public class SocketConnector : XMPPDelegate, NSStreamDelegate {
    
    public static let SERVER_HOST = "serverHost";
    
    
    let context:Context;
    let sessionObject:SessionObject;
    var inStream:NSInputStream?
    var outStream:NSOutputStream?
    var parserDelegate:XMLParserDelegate?
    var parser:XMLParser?
    let dnsResolver = XMPPDNSSrvResolver();
    weak var sessionLogic:XmppSessionLogic!;
    
    init(context:Context) {
        self.sessionObject = context.sessionObject;
        self.context = context;
    }
    
    public func start() {
        let userJid:BareJID = sessionObject.getProperty(SessionObject.USER_BARE_JID)!;
        let domain = userJid.domain;
        let server:String = sessionObject.getProperty(SocketConnector.SERVER_HOST) ?? domain;
        let dnsResolver = self.dnsResolver;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
            dnsResolver.resolve(server, connector:self);
        }
    }
    
    func connect(dnsRecords:Array<XMPPSrvRecord>) {
        if (dnsResolver.srvRecords.isEmpty) {
            let userJid:BareJID = sessionObject.getProperty(SessionObject.USER_BARE_JID)!;
            let domain = userJid.domain;
            dnsResolver.srvRecords.append(XMPPSrvRecord(port: 5222, weight: 0, priority: 0, target: domain));
        }
        
        let rec:XMPPSrvRecord = dnsResolver.srvRecords[0];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
            self.connect(rec.target, port: rec.port, ssl: false);
        }
    }
    
    private func connect(addr:String, port:Int, ssl:Bool) -> Void {
        autoreleasepool {
        NSStream.getStreamsToHostWithName(addr, port: port, inputStream: &inStream, outputStream: &outStream)
        }
        
        self.inStream!.delegate = self
        self.outStream!.delegate = self
        
        CFReadStreamSetProperty(self.inStream! as CFReadStreamRef, kCFStreamNetworkServiceType, kCFStreamNetworkServiceTypeBackground)
        CFWriteStreamSetProperty(self.outStream! as CFWriteStreamRef, kCFStreamNetworkServiceType, kCFStreamNetworkServiceTypeBackground)
        
        self.inStream!.scheduleInRunLoop(.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        self.outStream!.scheduleInRunLoop(.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        
        self.inStream!.open();
        self.outStream!.open();
        
        //self.wrappedInStream = NSInputStreamWrapper(input: self.inStream!);
        
        if (ssl) {
            configureTLS()
        }
        
        parserDelegate = XMPPParserDelegate();
        parserDelegate!.delegate = self
        parser = XMLParser(delegate: parserDelegate!);
    }
    
    func startTLS() {
        self.send("<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>");
    }
    
    func stop() {
        
    }
    
    func configureTLS() {
        log("configuring TLS");

        self.inStream?.delegate = self
        self.outStream?.delegate = self

        let userJid:BareJID = self.sessionObject.getProperty(SessionObject.USER_BARE_JID)!;
        
        let settings:NSDictionary = NSDictionary(objects: [NSStreamSocketSecurityLevelNegotiatedSSL, userJid.domain, kCFBooleanFalse], forKeys: [kCFStreamSSLLevel as NSString,
                kCFStreamSSLPeerName as NSString,
                kCFStreamSSLValidatesCertificateChain as NSString])
        let started = CFReadStreamSetProperty(self.inStream! as CFReadStreamRef, kCFStreamPropertySSLSettings, settings as CFTypeRef)
        if (!started) {
            self.log("could not start STARTTLS");
        }
        CFWriteStreamSetProperty(self.outStream! as CFWriteStreamRef, kCFStreamPropertySSLSettings, settings as CFTypeRef)
        self.inStream?.open()
        self.outStream?.open();
        
        self.inStream?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode);
        self.outStream?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode);
            
        self.context.sessionObject.setProperty(SessionObject.STARTTLS_ACTIVE, value: true, scope: SessionObject.Scope.stream);
    }
    
    public func restartStream() {
        self.parser = XMLParser(delegate: parserDelegate!);
        self.log("starting new parser", self.parser!);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let userJid:BareJID = self.sessionObject.getProperty(SessionObject.USER_BARE_JID)!;
            // replace with this first one to enable see-other-host feature
            //self.send("<stream:stream from='\(userJid)' to='\(userJid.domain)' version='1.0' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>")
            self.send("<stream:stream to='\(userJid.domain)' version='1.0' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>")
        }
    }
    
    override public func processElement(packet: Element) {
        super.processElement(packet);
        if packet.name == "proceed" && packet.xmlns == "urn:ietf:params:xml:ns:xmpp-tls" {
            configureTLS();
            restartStream();
        } else {
            processStanza(Stanza.fromElement(packet));
        }
    }
    
    func processStanza(stanza: Stanza) {
        sessionLogic.receivedIncomingStanza(stanza);
    }
    
    func send(stanza:Stanza) {
        sessionLogic.sendingOutgoingStanza(stanza);
        self.send(stanza.element.stringValue)
    }
    
    private func send(data:String) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
        self.log("sending stanza:", data);
        let buf = data.dataUsingEncoding(NSUTF8StringEncoding)!
        var outBuf = Array<UInt8>(count: buf.length, repeatedValue: 0)
        buf.getBytes(&outBuf, length: buf.length)
        let sent = self.outStream?.write(&outBuf, maxLength: buf.length)
        self.log("sent \(sent) from \(buf.length)")
        //self.outStream?.write(&outBuf, maxLength: 0);
        }
    }
    
    public func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch eventCode {
        case NSStreamEvent.ErrorOccurred:
            log("stream event: ErrorOccurred: \(aStream.streamError?.description)");
        case NSStreamEvent.OpenCompleted:
            if (aStream == self.inStream) {
                log("setsockopt!");
                let socketData:NSData = CFReadStreamCopyProperty(self.inStream! as CFReadStream, kCFStreamPropertySocketNativeHandle) as! NSData;
                var socket:CFSocketNativeHandle = 0;
                socketData.getBytes(&socket, length: sizeofValue(socket));
                var value:Int = 0;
                let size = UInt32(sizeofValue(value));
            
//                if setsockopt(socket, SOL_SOCKET, 0x1006, &value, size) != 0 {
//                    log("failed to set SO_TIMEOUT");
//                }
                value = 0;
                if setsockopt(socket, SOL_SOCKET, SO_KEEPALIVE, &value, size) != 0 {
                    log("failed to set SO_KEEPALIVE");
                }
                value = 1;
                if setsockopt(socket, IPPROTO_TCP, TCP_NODELAY, &value, size) != 0 {
                    log("failed to set TCP_NODELAY");
                }

                var tv = timeval();
                tv.tv_sec = 0;
                tv.tv_usec = 0;
                if setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(strideof(timeval))) != 0 {
                    log("failed to set SO_RCVTIMEO");
                }
                log("setsockopt done");
                
                // moved here?
                restartStream();
                
                log("inStream.hasBytesAvailable", inStream?.hasBytesAvailable);
            }
            log("stream event: OpenCompleted");
        case NSStreamEvent.HasBytesAvailable:
            log("stream event: HasBytesAvailable");
            if aStream == self.inStream {
                var buffer = [UInt8](count:2048, repeatedValue: 0);
                while self.inStream!.hasBytesAvailable {
                    if let read = self.inStream?.read(&buffer, maxLength: buffer.count) {
                       parser?.parse(&buffer, length: read)
                    }
                }
            }
        case NSStreamEvent.HasSpaceAvailable:
            log("stream event: HasSpaceAvailable");
        case NSStreamEvent.EndEncountered:
            log("stream event: EndEncountered");
        default:
            log("stream event:", aStream.description);            
        }
    }
}