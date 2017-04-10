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
open class SocketConnector : XMPPDelegate, StreamDelegate {
    
    /**
     Key in `SessionObject` to store custom validator for SSL certificates 
     provided by servers
     */
    open static let SSL_CERTIFICATE_VALIDATOR = "sslCertificateValidator";
    /**
     Key in `SessionObject` to store host to which we should reconnect
     after receiving see-other-host error.
     */
    open static let SEE_OTHER_HOST_KEY = "seeOtherHost";
    /**
     Key in `SessionObject` to store host to which XMPP client should
     try to connect to.
     */
    open static let SERVER_HOST = "serverHost";
    /**
     Key in `SessionObject` to store server port to which XMPP client
     should try to connect to.
     */
    open static let SERVER_PORT = "serverPort";
    
    fileprivate static var QUEUE_TAG = "xmpp_socket_queue";
    
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
    var inStream: InputStream?
    var outStream: OutputStream? {
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
    /**
     Stores information about SSL certificate validation and can
     have following values:
     - false - when validation failed or SSL layer was not established
     - true - when certificate passed validation
     - nil - awaiting for SSL certificate validation
     */
    var sslCertificateValidated: Bool? = false;
    
    /// Internal processing queue
    fileprivate let queue: DispatchQueue;
    fileprivate var queueTag: DispatchSpecificKey<DispatchQueue?>;
    
    fileprivate var state_:State = State.disconnected;
    open var state:State {
        get {
            return self.dispatch_sync_with_result_local_queue() {
                if self.state_ != State.disconnected && (self.inStream?.streamStatus == Stream.Status.closed || self.outStream?.streamStatus == Stream.Status.closed) {
                    return State.disconnected;
                }
                return self.state_;
            }
        }
        set {
            dispatch_sync_local_queue() {
                if newValue == State.disconnecting && self.state_ == State.disconnected {
                    return;
                }
                let oldState = self.state_;
                self.state_ = newValue
                if oldState != State.disconnected && newValue == State.disconnected {
                    self.context.eventBus.fire(DisconnectedEvent(sessionObject: self.sessionObject, clean: State.disconnecting == oldState));
                }
                if oldState == State.connecting && newValue == State.connected {
                    self.context.eventBus.fire(ConnectedEvent(sessionObject: self.sessionObject));
                }
            }
        }
    }
    
    fileprivate func dispatch_sync_local_queue(_ block: ()->()) {
        if (DispatchQueue.getSpecific(key: queueTag) != nil) {
            block();
        } else {
            queue.sync(execute: block);
        }
    }
    
    fileprivate func dispatch_sync_with_result_local_queue<T>(_ block: ()-> T) -> T {
        if (DispatchQueue.getSpecific(key: queueTag) != nil) {
            return block();
        } else {
            var result: T!;
            queue.sync {
                result = block();
            }
            return result;
        }
    }
    
    init(context:Context) {
        self.queue = DispatchQueue(label: "xmpp_socket_queue", attributes: []);
        self.queueTag = DispatchSpecificKey<DispatchQueue?>();
        queue.setSpecific(key: queueTag, value: queue);
        self.sessionObject = context.sessionObject;
        self.context = context;
    }
    
    deinit {
        queue.setSpecific(key: queueTag, value: nil);
    }
    
    /**
     Method used by `XMPPClient` to start process of establishing connection to XMPP server.
     
     - parameter serverToConnect: used internally to force connection to particular XMPP server (ie. one of many in cluster)
     */
    open func start(serverToConnect:String? = nil) {
        guard state == .disconnected else {
            log("start() - stopping connetion as state is not connecting", state);
            return;
        }
        queue.async {
            self.state = .connecting;
            let server:String = serverToConnect ?? self.sessionLogic.serverToConnect();
        
            if let port: Int = self.context.sessionObject.getProperty(SocketConnector.SERVER_PORT) {
                self.log("connecting to server:", server, "on port:", port);
                self.connect(addr: server, port: port, ssl: false);
            } else {
                self.log("connecting to server:", server);
                let dnsResolver = self.dnsResolver;
                dnsResolver.resolve(domain: server, connector:self);
            }
        }
    }
    
    func connect(dnsName:String, dnsRecords:Array<XMPPSrvRecord>) {
        guard state == .connecting else {
            log("connect(dns) - stopping connetion as state is not connecting", state);
            return;
        }
        log("got dns records:", dnsResolver.srvRecords);
        queue.async {
            if (self.dnsResolver.srvRecords.isEmpty) {
                self.dnsResolver.srvRecords.append(XMPPSrvRecord(port: 5222, weight: 0, priority: 0, target: dnsName));
            }
        
            let rec:XMPPSrvRecord = self.dnsResolver.srvRecords[0];
            self.connect(addr: rec.target, port: rec.port, ssl: false);
        }
    }
    
    fileprivate func connect(addr:String, port:Int, ssl:Bool) -> Void {
        log("connecting to:", addr, port);
        guard state == .connecting else {
            log("connect(addr) - stopping connetion as state is not connecting", state);
            return;
        }
        autoreleasepool {
        Stream.getStreamsToHost(withName: addr, port: port, inputStream: &inStream, outputStream: &outStream)
        }
        
        self.inStream!.delegate = self
        self.outStream!.delegate = self
        
//        let r1 = CFReadStreamSetProperty(self.inStream! as CFReadStream, CFStreamPropertyKey(rawValue: kCFStreamNetworkServiceType), kCFStreamNetworkServiceTypeVoIP)
//        let r2 = CFWriteStreamSetProperty(self.outStream! as CFWriteStream, CFStreamPropertyKey(rawValue: kCFStreamNetworkServiceType), kCFStreamNetworkServiceTypeVoIP)
//
//        if !r1 || !r2 {
//            log("failed to enabled background connection feature", r1, r2);
//        }
        
        self.inStream!.schedule(in: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
        self.outStream!.schedule(in: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
        
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
        self.send(data: "<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>");
    }
    
    func startZlib() {
        let e = Element(name: "compress", xmlns: "http://jabber.org/protocol/compress");
        e.addChild(Element(name: "method", cdata: "zlib"));
        self.send(data: e.stringValue);
    }
    
    func stop() {
        queue.async {
        switch self.state {
        case .disconnected, .disconnecting:
            self.log("not connected or already disconnecting");
            return;
        case .connected:
            self.state = State.disconnecting;
            self.log("closing XMPP stream");
            self.send(data: "</stream:stream>");
            self.closeTimer = Timer(delayInSeconds: 3, repeats: false) {
                self.closeSocket(newState: State.disconnected);
            }
        case .connecting:
            self.state = State.disconnecting;
            self.log("closing TCP connection");
            self.closeSocket(newState: State.disconnected);
        }
        }
    }
    
    func forceStop() {
        closeSocket(newState: State.disconnected);
    }
    
    func configureTLS() {
        log("configuring TLS");

        self.inStream?.delegate = self
        self.outStream?.delegate = self

        let domain = self.sessionObject.domainName!;
        
        sslCertificateValidated = nil;
        let settings:NSDictionary = NSDictionary(objects: [StreamSocketSecurityLevel.negotiatedSSL, domain, kCFBooleanFalse], forKeys: [kCFStreamSSLLevel as NSString,
                kCFStreamSSLPeerName as NSString,
                kCFStreamSSLValidatesCertificateChain as NSString])
        let started = CFReadStreamSetProperty(self.inStream! as CFReadStream, CFStreamPropertyKey(rawValue: kCFStreamPropertySSLSettings), settings as CFTypeRef)
        if (!started) {
            self.log("could not start STARTTLS");
        }
        CFWriteStreamSetProperty(self.outStream! as CFWriteStream, CFStreamPropertyKey(rawValue: kCFStreamPropertySSLSettings), settings as CFTypeRef);
        self.inStream?.open();
        self.outStream?.open();
        
        self.inStream?.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode);
        self.outStream?.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode);
            
        self.context.sessionObject.setProperty(SessionObject.STARTTLS_ACTIVE, value: true, scope: SessionObject.Scope.stream);
    }
    
    open func restartStream() {
        queue.async {
            self.parser = XMLParser(delegate: self.parserDelegate!);
            self.log("starting new parser", self.parser!);
            let userJid:BareJID? = self.sessionObject.getProperty(SessionObject.USER_BARE_JID);
            // replace with this first one to enable see-other-host feature
            //self.send("<stream:stream from='\(userJid)' to='\(userJid.domain)' version='1.0' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>")
            let domain = self.sessionObject.domainName!;
            let seeOtherHost = (self.sessionObject.getProperty(SocketConnector.SEE_OTHER_HOST_KEY, defValue: true) && userJid != nil) ? " from='\(userJid!)'" : ""
            self.send(data: "<stream:stream to='\(domain)'\(seeOtherHost) version='1.0' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>")
        }
    }
    
    func proceedTLS() {
        configureTLS();
        restartStream();
    }
    
    func proceedZlib() {
        zlib = Zlib(compressionLevel: .default, flush: .sync);
        self.context.sessionObject.setProperty(SessionObject.COMPRESSION_ACTIVE, value: true, scope: SessionObject.Scope.stream);
        restartStream();
    }
    
    override open func process(element packet: Element) {
        super.process(element: packet);
        if packet.name == "error" && packet.xmlns == "http://etherx.jabber.org/streams" {
            sessionLogic.onStreamError(packet);
        } else if packet.name == "proceed" && packet.xmlns == "urn:ietf:params:xml:ns:xmpp-tls" {
            proceedTLS();
        } else if packet.name == "compressed" && packet.xmlns == "http://jabber.org/protocol/compress" {
            proceedZlib();
        } else {
            process(stanza: Stanza.from(element: packet));
        }
    }
    
    override open func onError(msg: String?) {
        closeSocket(newState: State.disconnected);
    }
    
    override open func onStreamTerminate() {
        log("onStreamTerminate called... state:", state);
        switch state {
        case .disconnecting:
            closeSocket(newState: State.disconnected);
        // connecting is also set in case of see other host
        case .connected, .connecting:
            //-- probably from other socket, ie due to restart!
            let inStreamState = inStream?.streamStatus;
            if inStreamState == nil || inStreamState == .error || inStreamState == .closed {
                closeSocket(newState: State.disconnected)
            } else {
                state = State.disconnecting;
                sendSync("</stream:stream>");
                closeSocket(newState: State.disconnected);
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
    open func reconnect(newHost:String) {
        dispatch_sync_local_queue() {
            self.log("closing socket before reconnecting using see-other-host!")
            self.state_ = .disconnecting;
            self.closeSocket(newState: nil);
            self.state_ = .disconnected;
        }
        queue.async {
            self.log("reconnecting to new host:", newHost);
            self.start(serverToConnect: newHost);
        }
    }
    
    /**
     This method will process any stanza received from XMPP server.
     */
    func process(stanza: Stanza) {
        sessionLogic.receivedIncomingStanza(stanza);
    }
    
    /**
     This method will process any stanza before it will be sent to XMPP server.
     */
    func send(stanza:Stanza) {
        sessionLogic?.sendingOutgoingStanza(stanza);
        self.send(data: stanza.element.stringValue)
    }
    
    open func keepAlive() {
        self.send(data: " ");
    }
    
    /**
     Methods prepares data to be sent using `dispatch_async()` to send data using other thread.
     */
    fileprivate func send(data:String) {
        queue.async {
            self.sendSync(data);
        }
    }
    
    /**
     Method responsible for actual process of sending data.
     */
    fileprivate func sendSync(_ data:String) {
        self.log("sending stanza:", data);
        let buf = data.data(using: String.Encoding.utf8)!;
        if zlib != nil {
            let outBuf = zlib!.compress(data: buf);
            outStreamBuffer?.append(data: outBuf);
            outStreamBuffer?.writeData(to: self.outStream);
        } else {
            outStreamBuffer?.append(data: buf);
            outStreamBuffer?.writeData(to: self.outStream);
        }
    }
    
    open func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.errorOccurred:
            // may happen if cannot connect to server or if connection was broken
            log("stream event: ErrorOccurred: \(aStream.streamError)");
            if (aStream == self.inStream) {
                // this is intentional - we need to execute onStreamTerminate()
                // on main queue, but after all task are executed by our serial queueła
                queue.async {
                    self.onStreamTerminate();
                }
            }
        case Stream.Event.openCompleted:
            if (aStream == self.inStream) {
                state = State.connected;
                log("setsockopt!");
                let socketData:Data = CFReadStreamCopyProperty(self.inStream! as CFReadStream, CFStreamPropertyKey.socketNativeHandle) as! Data;
                var socket:CFSocketNativeHandle = 0;
                (socketData as NSData).getBytes(&socket, length: MemoryLayout.size(ofValue: socket));
                var value:Int = 0;
                let size = UInt32(MemoryLayout.size(ofValue: value));
            
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
                if setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.stride)) != 0 {
                    log("failed to set SO_RCVTIMEO");
                }
                log("setsockopt done");
                
                // moved here?
                restartStream();
                
                log("inStream.hasBytesAvailable", inStream?.hasBytesAvailable);
            }
            log("stream event: OpenCompleted");
        case Stream.Event.hasBytesAvailable:
            log("stream event: HasBytesAvailable");
            if aStream == self.inStream {
                queue.async {
                    guard let inStream = self.inStream else {
                        return;
                    }
                    
                    var buffer = [UInt8](repeating: 0, count: 2048);
                    while inStream.hasBytesAvailable {
                        let read = inStream.read(&buffer, maxLength: buffer.count)
                        guard read > 0 else {
                            return;
                        }
                        
                        let data = Data(bytes: &buffer, count: read);
                        if self.zlib != nil {
                            let decompressedData = self.zlib!.decompress(data: data);
                            self.parser?.parse(data: decompressedData);
                        } else {
                            self.parser?.parse(data: data);
                        }
                    }
                }
            }
        case Stream.Event.hasSpaceAvailable:
            log("stream event: HasSpaceAvailable");
            if sslCertificateValidated == nil {
                let trustVal = self.inStream?.property(forKey: Stream.PropertyKey(rawValue: kCFStreamPropertySSLPeerTrust as String));
                guard trustVal != nil else {
                    self.closeSocket(newState: .disconnected);
                    return;
                }
                
                let trust: SecTrust = trustVal as! SecTrust;
                
                let sslCertificateValidator: ((SessionObject,SecTrust)->Bool)? = context.sessionObject.getProperty(SocketConnector.SSL_CERTIFICATE_VALIDATOR);
                if sslCertificateValidator != nil {
                    sslCertificateValidated = sslCertificateValidator!(sessionObject, trust);
                } else {
                    let policy = SecPolicyCreateSSL(false, sessionObject.userBareJid?.domain as CFString?);
                    var secTrustResultType = SecTrustResultType.invalid;
                    SecTrustSetPolicies(trust, policy);
                    SecTrustEvaluate(trust, &secTrustResultType);
                                        
                    sslCertificateValidated = (secTrustResultType == SecTrustResultType.proceed || secTrustResultType == SecTrustResultType.unspecified);
                }
                if !sslCertificateValidated! {
                    log("SSL certificate validation failed");
                    self.context.eventBus.fire(CertificateErrorEvent(sessionObject: context.sessionObject, trust: trust));
                    self.closeSocket(newState: .disconnected);
                    return;
                }
            }
            if aStream == self.outStream {
                queue.async {
                    self.outStreamBuffer?.writeData(to: self.outStream);
                }
            }
        case Stream.Event.endEncountered:
            log("stream event: EndEncountered");
            queue.async {
                self.closeSocket(newState: State.disconnected);
            }
        default:
            log("stream event:", aStream.description);            
        }
    }
    
    /**
     Internal method used to properly close TCP connection and set state if needed
     */
    fileprivate func closeSocket(newState: State?) {
        closeStreams();
        zlib = nil;
        if newState != nil {
            state = newState!;
        }
        closeTimer?.cancel()
        closeTimer = nil;
    }

    fileprivate func closeStreams() {
        let inStream = self.inStream;
        let outStream = self.outStream;
        self.inStream = nil;
        self.outStream = nil;
        self.outStreamBuffer = nil;
        inStream?.close();
        outStream?.close();
        inStream?.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode);
        outStream?.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode);
        sslCertificateValidated = false;
    }
    
    /// Event fired when client establishes TCP connection to XMPP server.
    open class ConnectedEvent: Event {
        
        /// identified of event which should be used during registration of `EventHandler`
        open static let TYPE = ConnectedEvent();
        
        open let type = "connectorConnected";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject:SessionObject!;
        
        init() {
            sessionObject = nil;
        }
        
        public init(sessionObject: SessionObject) {
            self.sessionObject = sessionObject;
        }
        
    }
    
    /// Event fired when TCP connection to XMPP server is closed or is broken.
    open class DisconnectedEvent: Event {
        
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = DisconnectedEvent();
        
        open let type = "connectorDisconnected";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject:SessionObject!;
        /// If is `true` then XMPP client was properly closed, in other case it may be broken
        open let clean:Bool;
        
        init() {
            sessionObject = nil;
            clean = false;
        }
        
        public init(sessionObject: SessionObject, clean: Bool) {
            self.sessionObject = sessionObject;
            self.clean = clean;
        }
        
    }
    
    /// Event fired if SSL certificate validation fails
    open class CertificateErrorEvent: Event {
        
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = CertificateErrorEvent();
        
        open let type = "certificateError";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject:SessionObject!;
        /// Instance of SecTrust - contains data related to certificate
        open let trust: SecTrust!;
        
        init() {
            sessionObject = nil;
            trust = nil;
        }
        
        init(sessionObject: SessionObject, trust: SecTrust) {
            self.sessionObject = sessionObject;
            self.trust = trust;
        }
    }
    
    class WriteBuffer: Logger {
        
        var queue = Queue<Data>();
        var position = 0;
        
        func append(data: Data) {
            queue.offer(data);
        }
        
        func writeData(to outputStream: OutputStream?) {
            guard outputStream != nil && outputStream!.hasSpaceAvailable else {
                return;
            }
            var data = queue.peek();
            guard data != nil else {
                return;
            }
            let remainingLength = data!.count - position;
            
            let sent = data!.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> Int in
                return outputStream!.write(ptr + position, maxLength: remainingLength);
            }
            
            if sent < 0 {
                return;
            }
            position += sent;
            log("sent ", sent, "bytes", position, "of", data!.count);
            if position == data!.count {
                position = 0;
                _ = queue.poll();
            }
        }
        
    }
}
