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

/**
 Class responsible for connecting to XMPP server, sending and receiving data.
 */
public class SocketConnector : XMPPDelegate, NSStreamDelegate {
    
    public static let SEE_OTHER_HOST_KEY = "seeOtherHost";
    public static let SERVER_HOST = "serverHost";
    
    /**
     Possible states of connection:
     - connecting: Trying to establish connection to XMPP server
     - connected: Connection to XMPP server is established
     - disconnecting: Connection to XMPP server is being closed
     - disconnected: Connection to XMPP server is closed
     */
    public enum State {
        case connecting
        case connected
        case disconnecting
        case disconnected
    }
    
    let context: Context;
    let sessionObject: SessionObject;
    var inStream: NSInputStream?
    var outStream: NSOutputStream? {
        didSet {
            if outStream != nil && oldValue == nil {
                outStreamBuffer = WriteBuffer();
            }
        }
    }
    var outStreamBuffer: WriteBuffer?;
    var parserDelegate: XMLParserDelegate?
    var parser: XMLParser?
    let dnsResolver = XMPPDNSSrvResolver();
    weak var sessionLogic: XmppSessionLogic!;
    var closeTimer: Timer?;
    var zlib: Zlib?;
    
    /// Internal processing queue
    private var queue = dispatch_queue_create("xmpp_socket_queue", nil);
    
    private var state_:State = State.disconnected;
    public var state:State {
        get {
            if state_ != State.disconnected && (inStream?.streamStatus == NSStreamStatus.Closed || outStream?.streamStatus == NSStreamStatus.Closed) {
                return State.disconnected;
            }
            return state_;
        }
        set {
            if newValue == State.disconnecting && state_ == State.disconnected {
                return;
            }
            let oldState = state_;
            state_ = newValue
            if oldState != State.disconnected && newValue == State.disconnected {
                context.eventBus.fire(DisconnectedEvent(sessionObject: self.sessionObject, clean: State.disconnecting == oldState));
            }
            if oldState == State.connecting && newValue == State.connected {
                context.eventBus.fire(ConnectedEvent(sessionObject: self.sessionObject));
            }
        }
    }
    
    init(context:Context) {
        self.sessionObject = context.sessionObject;
        self.context = context;
    }
    
    /**
     Method used by `XMPPClient` to start process of establishing connection to XMPP server.
     
     - parameter serverToConnect: used internally to force connection to particular XMPP server (ie. one of many in cluster)
     */
    public func start(serverToConnect:String? = nil) {
        guard state == .disconnected else {
            log("start() - stopping connetion as state is not connecting", state);
            return;
        }
        state = .connecting;
        let server:String = serverToConnect ?? sessionLogic.serverToConnect();
        log("connecting to server:", server);
        let dnsResolver = self.dnsResolver;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
            dnsResolver.resolve(server, connector:self);
        }
    }
    
    func connect(dnsName:String, dnsRecords:Array<XMPPSrvRecord>) {
        guard state == .connecting else {
            log("connect(dns) - stopping connetion as state is not connecting", state);
            return;
        }
        log("got dns records:", dnsResolver.srvRecords);
        if (dnsResolver.srvRecords.isEmpty) {
            dnsResolver.srvRecords.append(XMPPSrvRecord(port: 5222, weight: 0, priority: 0, target: dnsName));
        }
        
        let rec:XMPPSrvRecord = dnsResolver.srvRecords[0];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
            self.connect(rec.target, port: rec.port, ssl: false);
        }
    }
    
    private func connect(addr:String, port:Int, ssl:Bool) -> Void {
        log("connecting to:", addr, port);
        guard state == .connecting else {
            log("connect(addr) - stopping connetion as state is not connecting", state);
            return;
        }
        autoreleasepool {
        NSStream.getStreamsToHostWithName(addr, port: port, inputStream: &inStream, outputStream: &outStream)
        }
        
        self.inStream!.delegate = self
        self.outStream!.delegate = self
        
        let r1 = CFReadStreamSetProperty(self.inStream! as CFReadStreamRef, kCFStreamNetworkServiceType, kCFStreamNetworkServiceTypeVoIP)
        let r2 = CFWriteStreamSetProperty(self.outStream! as CFWriteStreamRef, kCFStreamNetworkServiceType, kCFStreamNetworkServiceTypeVoIP)
        
        if !r1 || !r2 {
            log("failed to enabled background connection feature", r1, r2);
        }
        
        self.inStream!.scheduleInRunLoop(.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        self.outStream!.scheduleInRunLoop(.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        
        self.inStream!.open();
        self.outStream!.open();
        
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
    
    func startZlib() {
        let e = Element(name: "compress", xmlns: "http://jabber.org/protocol/compress");
        e.addChild(Element(name: "method", cdata: "zlib"));
        self.send(e.stringValue);
    }
    
    func stop() {
        switch state {
        case .disconnected, .disconnecting:
            log("not connected or already disconnecting");
            return;
        case .connected:
            state = State.disconnecting;
            log("closing XMPP stream");
            self.send("</stream:stream>");
            closeTimer = Timer(delayInSeconds: 3, repeats: false) {
                self.closeSocket(State.disconnected);
            }
        case .connecting:
            state = State.disconnecting;
            log("closing TCP connection");
            self.closeSocket(State.disconnected);
        }
    }
    
    func forceStop() {
        closeSocket(State.disconnected);
    }
    
    func configureTLS() {
        log("configuring TLS");

        self.inStream?.delegate = self
        self.outStream?.delegate = self

        let domain = self.sessionObject.domainName!;
        
        let settings:NSDictionary = NSDictionary(objects: [NSStreamSocketSecurityLevelNegotiatedSSL, domain, kCFBooleanFalse], forKeys: [kCFStreamSSLLevel as NSString,
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
            let userJid:BareJID? = self.sessionObject.getProperty(SessionObject.USER_BARE_JID);
            // replace with this first one to enable see-other-host feature
            //self.send("<stream:stream from='\(userJid)' to='\(userJid.domain)' version='1.0' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>")
            let domain = self.sessionObject.domainName!;
            let seeOtherHost = (self.sessionObject.getProperty(SocketConnector.SEE_OTHER_HOST_KEY, defValue: true) && userJid != nil) ? " from='\(userJid!)'" : ""
            self.send("<stream:stream to='\(domain)'\(seeOtherHost) version='1.0' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>")
        }
    }
    
    func proceedTLS() {
        configureTLS();
        restartStream();
    }
    
    func proceedZlib() {
        zlib = Zlib(compressionLevel: .Default, flush: .Sync);
        self.context.sessionObject.setProperty(SessionObject.COMPRESSION_ACTIVE, value: true, scope: SessionObject.Scope.stream);
        restartStream();
    }
    
    override public func processElement(packet: Element) {
        super.processElement(packet);
        if packet.name == "error" && packet.xmlns == "http://etherx.jabber.org/streams" {
            sessionLogic.onStreamError(packet);
        } else if packet.name == "proceed" && packet.xmlns == "urn:ietf:params:xml:ns:xmpp-tls" {
            proceedTLS();
        } else if packet.name == "compressed" && packet.xmlns == "http://jabber.org/protocol/compress" {
            proceedZlib();
        } else {
            processStanza(Stanza.fromElement(packet));
        }
    }
    
    override public func onError(msg: String?) {
        closeSocket(State.disconnected);
    }
    
    override public func onStreamTerminate() {
        switch state {
        case .disconnecting:
            closeSocket(State.disconnected);
        // connecting is also set in case of see other host
        case .connected, .connecting:
            //-- probably from other socket, ie due to restart!
            let inStreamState = inStream?.streamStatus;
            if inStreamState == nil || inStreamState == .Error || inStreamState == .Closed {
                closeSocket(State.disconnected)
            } else {
                state = State.disconnecting;
                sendSync("</stream:stream>");
                closeSocket(State.disconnected);
            }
        default:
            break;
        }
    }
    
    /**
     Method used to close existing connection and reconnect to specific host.
     Used mainly to support [see-other-host] feature.
     
     [see-other-host]: http://xmpp.org/rfcs/rfc6120.html#streams-error-conditions-see-other-host
     */
    public func reconnect(newHost:String) {
        state_ = .disconnecting;
        closeSocket(nil);
        state_ = .disconnected;
        dispatch_async(dispatch_get_main_queue()) {
            self.start(newHost);
        }
    }
    
    /**
     This method will process any stanza received from XMPP server.
     */
    func processStanza(stanza: Stanza) {
        sessionLogic.receivedIncomingStanza(stanza);
    }
    
    /**
     This method will process any stanza before it will be sent to XMPP server.
     */
    func send(stanza:Stanza) {
        sessionLogic.sendingOutgoingStanza(stanza);
        self.send(stanza.element.stringValue)
    }
    
    public func keepAlive() {
        self.send(" ");
    }
    
    /**
     Methods prepares data to be sent using `dispatch_async()` to send data using other thread.
     */
    private func send(data:String) {
        dispatch_async(queue) {
            self.sendSync(data);
        }
    }
    
    /**
     Method responsible for actual process of sending data.
     */
    private func sendSync(data:String) {
        self.log("sending stanza:", data);
        let buf = data.dataUsingEncoding(NSUTF8StringEncoding)!;
        if zlib != nil {
            var outBuf = zlib!.compress(UnsafePointer<UInt8>(buf.bytes), length: buf.length);
            outStreamBuffer?.appendData(outBuf);
            outStreamBuffer?.writeData(self.outStream);
        } else {
            var outBuf = [UInt8](count: buf.length, repeatedValue: 0);
            buf.getBytes(&outBuf, length: buf.length);
            outStreamBuffer?.appendData(outBuf);
            outStreamBuffer?.writeData(self.outStream);
        }
    }
    
    public func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch eventCode {
        case NSStreamEvent.ErrorOccurred:
            // may happen if cannot connect to server or if connection was broken
            log("stream event: ErrorOccurred: \(aStream.streamError?.description)");
            if (aStream == self.inStream) {
                // this is intentional - we need to execute onStreamTerminate()
                // on main queue, but after all task are executed by our serial queueła
                dispatch_async(queue) {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.onStreamTerminate();
                    }
                }
            }
        case NSStreamEvent.OpenCompleted:
            if (aStream == self.inStream) {
                state = State.connected;
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
                dispatch_async(queue) {
                    guard self.inStream != nil else {
                        return;
                    }
                    let inStream = self.inStream!;
                    while inStream.hasBytesAvailable {
                        var buffer = [UInt8](count:2048, repeatedValue: 0);
                        if let read = self.inStream?.read(&buffer, maxLength: buffer.count) {
                        if self.zlib != nil {
                            var data = self.zlib!.decompress(buffer, length: read);
                            self.parser?.parse(&data, length: data.count);
                        } else {
                                self.parser?.parse(&buffer, length: read);
                            }
                        }
                    }
                }
            }
        case NSStreamEvent.HasSpaceAvailable:
            log("stream event: HasSpaceAvailable");
            if aStream == self.outStream {
                dispatch_async(queue) {
                    self.outStreamBuffer?.writeData(self.outStream);
                }
            }
        case NSStreamEvent.EndEncountered:
            log("stream event: EndEncountered");
            closeSocket(State.disconnected);
        default:
            log("stream event:", aStream.description);            
        }
    }
    
    /**
     Internal method used to properly close TCP connection and set state if needed
     */
    private func closeSocket(newState: State?) {
        closeStreams();
        zlib = nil;
        if newState != nil {
            state = newState!;
        }
        closeTimer?.cancel()
        closeTimer = nil;
    }

    private func closeStreams() {
        let inStream = self.inStream;
        let outStream = self.outStream;
        self.inStream = nil;
        self.outStream = nil;
        self.outStreamBuffer = nil;
        inStream?.close();
        outStream?.close();
        inStream?.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode);
        outStream?.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode);
    }
    
    /// Event fired when client establishes TCP connection to XMPP server.
    public class ConnectedEvent: Event {
        
        /// identified of event which should be used during registration of `EventHandler`
        public static let TYPE = ConnectedEvent();
        
        public let type = "connectorConnected";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        
        init() {
            sessionObject = nil;
        }
        
        public init(sessionObject: SessionObject) {
            self.sessionObject = sessionObject;
        }
        
    }
    
    /// Event fired when TCP connection to XMPP server is closed or is broken.
    public class DisconnectedEvent: Event {
        
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = DisconnectedEvent();
        
        public let type = "connectorDisconnected";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// If is `true` then XMPP client was properly closed, in other case it may be broken
        public let clean:Bool;
        
        init() {
            sessionObject = nil;
            clean = false;
        }
        
        public init(sessionObject: SessionObject, clean: Bool) {
            self.sessionObject = sessionObject;
            self.clean = clean;
        }
        
    }
    
    class WriteBuffer: Logger {
        
        var queue = Queue<[UInt8]>();
        var position = 0;
        
        func appendData(data: [UInt8]) {
            queue.offer(data);
        }
        
        func writeData(outputStream: NSOutputStream?) {
            guard outputStream != nil && outputStream!.hasSpaceAvailable else {
                return;
            }
            var data = queue.peek();
            guard data != nil else {
                return;
            }
            var remainingLength = data!.count - position;
            let sent = outputStream!.write(&data! + position, maxLength: remainingLength);
            if sent < 0 {
                return;
            }
            position += sent;
            log("sent ", sent, "bytes", position, "of", data!.count);
            if position == data!.count {
                position = 0;
                queue.poll();
            }
        }
        
    }
}