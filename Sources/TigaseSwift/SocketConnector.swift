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
import TigaseLogging

/**
 Class responsible for connecting to XMPP server, sending and receiving data.
 */
open class SocketConnector : XMPPDelegate, StreamDelegate {
        
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
    
    private weak var context: Context!;
    private let sessionObject: SessionObject;
    private var inStream: InputStream?
    private var outStream: OutputStream? {
        didSet {
            if outStream != nil && oldValue == nil {
                outStreamBuffer = WriteBuffer();
            }
        }
    }
    var outStreamBuffer: WriteBuffer?;
    var parserDelegate: XMLParserDelegate?
    var parser: XMLParser?
    private let dnsResolver: DNSSrvResolver;
    weak var sessionLogic: XmppSessionLogic?;
    private var zlib: Zlib?;
    public private(set) var isTLSActive: Bool = false;
    public var isCompressionActive: Bool {
        return zlib != nil;
    }
    /**
     Stores information about SSL certificate validation and can
     have following values:
     - false - when validation failed or SSL layer was not established
     - true - when certificate passed validation
     - nil - awaiting for SSL certificate validation
     */
    var sslCertificateValidated: Bool? = false;
    
    /// Internal processing queue
    private let queue: QueueDispatcher;
    
    fileprivate var server: String?;
    private(set) var currentConnectionDetails: XMPPSrvRecord? {
        didSet {
            context.currentConnectionDetails = self.currentConnectionDetails;
        }
    }
    
    private var connectionTimer: Foundation.Timer?;
    
    @Published
    open private(set) var state: State = .disconnected;
    
    private let logger = Logger(subsystem: "TigaseSwift", category: "SocketConnector")
    private var stateSubscription: Cancellable?;
    
    init(context:Context) {
        self.queue = QueueDispatcher(label: "xmpp_socket_queue");
        self.dnsResolver = context.connectionConfiguration.dnsResolver ?? XMPPDNSSrvResolver();
        self.sessionObject = context.sessionObject;
        self.context = context;
        
        super.init();
        
        var oldState: State = .disconnected;
        self.stateSubscription = $state.sink(receiveValue: { [weak self] newState in
            guard let that = self else {
                return;
            }
            that.queue.sync {
            switch newState {
            case .disconnected:
                if oldState != .disconnected {
                    DispatchQueue.main.async {
                        that.connectionTimer?.invalidate();
                        that.connectionTimer = nil;
                    }
                    that.context.eventBus.fire(DisconnectedEvent(sessionObject: that.sessionObject, connectionDetails: that.currentConnectionDetails, clean: State.disconnecting == oldState));
                }
            case .connected:
                if oldState == .connecting {
                    DispatchQueue.main.async {
                        that.connectionTimer?.invalidate();
                        that.connectionTimer = nil;
                    }
                    that.context.eventBus.fire(ConnectedEvent(sessionObject: that.sessionObject));
                }
            case .connecting:
                if let timeout: Double = context.connectionConfiguration.conntectionTimeout {
                    that.logger.debug("\(that.context) - scheduling timer for: \(timeout)");
                    DispatchQueue.main.async {
                        that.connectionTimer = Foundation.Timer.scheduledTimer(timeInterval: timeout, target: that, selector: #selector(that.connectionTimedOut), userInfo: nil, repeats: false)
                    }
                }
            default:
                break;
            }
            oldState = newState;
            }
        })
    }
    
    deinit {
        stateSubscription?.cancel();
    }
    
    /**
     Method used by `XMPPClient` to start process of establishing connection to XMPP server.
     
     - parameter serverToConnect: used internally to force connection to particular XMPP server (ie. one of many in cluster)
     */
    open func start() {
        guard state == .disconnected else {
            logger.log("start() - stopping connetion as state is not connecting \(self.state)");
            return;
        }
        queue.async {
            let start = Date();
            let timeout: Double? = self.context.connectionConfiguration.conntectionTimeout;
            self.state = .connecting;
            if let srvRecord = self.sessionLogic?.serverToConnectDetails() {
                self.connect(dnsName: srvRecord.target, srvRecord: srvRecord);
                return;
            } else {
                if let details = self.context.connectionConfiguration.serverConnectionDetails {
                    self.connect(addr: details.host, port: details.port, ssl: details.useSSL);
                }

                let server = self.context.userBareJid.domain;
                self.logger.debug("\(self.context) - connecting to server: \(server)");
                self.dnsResolver.resolve(domain: server, for: self.context.userBareJid) { result in
                    if timeout != nil {
                        // if timeout was set, do not try to connect after timeout was fired!
                        // another event will take care of that
                        guard Date().timeIntervalSince(start) < timeout! else {
                            return;
                        }
                    }
                    switch result {
                    case .success(let dnsResult):
                        if let record = dnsResult.record() ?? self.currentConnectionDetails {
                            self.connect(dnsName: server, srvRecord: record);
                        } else {
                            self.connect(dnsName: server, srvRecord: XMPPSrvRecord(port: 5222, weight: 0, priority: 0, target: server, directTls: false));
                        }
                    case .failure(_):
                        self.connect(dnsName: server, srvRecord: XMPPSrvRecord(port: 5222, weight: 0, priority: 0, target: server, directTls: false));
                    }
                }
            }
        }
    }
    
    public static func preprocessConnectionDetails(string: String?) -> (String, Int?)? {
        guard let tmp = string else {
            return nil;
        }
        guard tmp.last != "]" else {
            return (tmp, nil);
        }
        guard let idx = tmp.lastIndex(of: ":") else {
            return (tmp, nil);
        }
        return (String(tmp[tmp.startIndex..<idx]), Int(tmp[tmp.index(after: idx)..<tmp.endIndex]));
    }
    
    func connect(dnsName: String, srvRecord: XMPPSrvRecord) {
        guard state == .connecting else {
            logger.log("connect(dns) - stopping connetion as state is not connecting \(self.state)");
            return;
        }
        logger.debug("\(self.context) - got dns record to connect to: \(srvRecord)");
        queue.async {
            self.server = dnsName;
            self.currentConnectionDetails = srvRecord;
            self.connect(addr: srvRecord.target, port: srvRecord.port, ssl: srvRecord.directTls);
        }
    }
    
    fileprivate func connect(addr:String, port:Int, ssl:Bool) -> Void {
        logger.debug("connecting to: \(addr):\(port)");
        guard state == .connecting else {
            logger.log("connect(addr) - stopping connetion as state is not connecting \(self.state)");
            return;
        }
        
        if (inStream != nil) {
            logger.error("inStream not null during reconnection! \(self.inStream as Any)");
            inStream = nil;
        }
        if (outStream != nil) {
            logger.error("outStream not null during reconnection! \(self.outStream as Any)");
            outStream = nil;
        }
        
        Stream.getStreamsToHost(withName: addr, port: port, inputStream: &inStream, outputStream: &outStream);
        
        self.inStream!.delegate = self
        self.outStream!.delegate = self
                
        self.inStream!.schedule(in: RunLoop.main, forMode: RunLoop.Mode.default)
        self.outStream!.schedule(in: RunLoop.main, forMode: RunLoop.Mode.default)
                
        if (ssl) {
            configureTLS(directTls: true);
        } else {
            self.inStream!.open();
            self.outStream!.open();
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
    
    func stop(completionHandler: (()->Void)? = nil) {
        queue.async {
        switch self.state {
        case .disconnected, .disconnecting:
            self.logger.debug("\(self.context) - not connected or already disconnecting");
            completionHandler?();
            return;
        case .connected:
            self.state = State.disconnecting;
            self.logger.debug("\(self.context) - closing XMPP stream");
            self.sessionLogic?.onStreamClose {
                self.queue.async {
                    self.send(data: "</stream:stream>") {
                        self.closeSocket(newState: State.disconnected);
                        completionHandler?();
                    }
                }
            }
        case .connecting:
            self.state = State.disconnecting;
            self.logger.debug("\(self.context) - closing TCP connection");
            self.closeSocket(newState: State.disconnected);
            completionHandler?();
        }
        }
    }
    
    func forceStop(completionHandler: (()->Void)? = nil) {
        closeSocket(newState: State.disconnected);
        completionHandler?();
    }
    
    func configureTLS(directTls: Bool = false) {
        self.logger.debug("\(self.context) - configuring TLS");

        guard let inStream = self.inStream, let outStream = self.outStream else {
            return;
        }
        inStream.delegate = self
        outStream.delegate = self

        let domain = self.context.userBareJid.domain;
        
        sslCertificateValidated = nil;
        let settings:NSDictionary = NSDictionary(objects: [StreamSocketSecurityLevel.negotiatedSSL, 
                                                           domain, kCFBooleanFalse as Any], forKeys: [kCFStreamSSLLevel as NSString,
                kCFStreamSSLPeerName as NSString,
                kCFStreamSSLValidatesCertificateChain as NSString])
        let started = CFReadStreamSetProperty(inStream as CFReadStream, CFStreamPropertyKey(rawValue: kCFStreamPropertySSLSettings), settings as CFTypeRef)
        if (!started) {
            self.logger.debug("\(self.context) - could not start STARTTLS");
        }
        CFWriteStreamSetProperty(outStream as CFWriteStream, CFStreamPropertyKey(rawValue: kCFStreamPropertySSLSettings), settings as CFTypeRef);
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, OSXApplicationExtension 10.13, OSX 10.13, *) {
            let sslContext: SSLContext = outStream.property(forKey: Stream.PropertyKey(rawValue: kCFStreamPropertySSLContext as String)) as! SSLContext;
            SSLSetALPNProtocols(sslContext, ["xmpp-client"] as CFArray)
        } else {
            // Fallback on earlier versions
        };

        inStream.open();
        outStream.open();
        
        inStream.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default);
        outStream.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default);
            
        self.isTLSActive = true;
    }
    
    open func restartStream() {
        queue.async {
            self.parser = XMLParser(delegate: self.parserDelegate!);
            self.logger.debug("starting new parser \(self.parser!)");
            self.sessionLogic?.startStream();
        }
    }
    
    func proceedTLS() {
        configureTLS();
        restartStream();
    }
    
    func proceedZlib() {
        zlib = Zlib(compressionLevel: .default, flush: .sync);
        restartStream();
    }
    
    override open func process(element packet: Element) {
        super.process(element: packet);
        logger.debug("\(self.context) - received stanza: \(packet)")
        if packet.name == "error" && packet.xmlns == "http://etherx.jabber.org/streams" {
            sessionLogic?.onStreamError(packet);
        } else if packet.name == "proceed" && packet.xmlns == "urn:ietf:params:xml:ns:xmpp-tls" {
            proceedTLS();
        } else if packet.name == "compressed" && packet.xmlns == "http://jabber.org/protocol/compress" {
            proceedZlib();
        } else {
            process(stanza: Stanza.from(element: packet));
        }
    }
    
    override open func onError(msg: String?) {
        self.logger.error("\(msg as Any)");
        closeSocket(newState: State.disconnected);
    }
    
    override open func onStreamTerminate() {
        self.logger.debug("onStreamTerminate called... state: \(self.state)");
        sessionLogic?.onStreamTerminate();
        switch state {
        case .disconnecting, .connecting:
            closeSocket(newState: State.disconnected);
        // connecting is also set in case of see other host
        case .connected:
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
    open func reconnect() {
        queue.sync {
            self.logger.debug("closing socket before reconnecting using see-other-host!")
            self.state = .disconnecting;
            DispatchQueue.main.async {
                self.connectionTimer?.invalidate();
                self.connectionTimer = nil;
            }
            self.closeSocket(newState: nil);
            self.state = .disconnected;
            self.sessionObject.clear();
        }
        queue.async {
            self.logger.debug("reconnecting to new host");
            self.start();
        }
    }
    
    /**
     This method will process any stanza received from XMPP server.
     */
    func process(stanza: Stanza) {
        sessionLogic?.receivedIncomingStanza(stanza);
    }
    
    /**
     This method will process any stanza before it will be sent to XMPP server.
     */
    func send(stanza:Stanza) {
        sessionLogic?.sendingOutgoingStanza(stanza);
        queue.async {
            self.sendSync(stanza.element.stringValue)
            if let logger = self.streamLogger {
                logger.outgoing(element: stanza.element);
            }
        }
    }
    
    open func keepAlive() {
        self.send(data: " ");
    }
    
    /**
     Methods prepares data to be sent using `dispatch_async()` to send data using other thread.
     */
    open func send(data:String, completionHandler: (()->Void)? = nil) {
        queue.async {
            self.sendSync(data, completionHandler: completionHandler);
            if let logger = self.streamLogger {
                logger.outgoing(data);
            }
        }
    }
    
    /**
     Method responsible for actual process of sending data.
     */
    fileprivate func sendSync(_ data:String, completionHandler: (()->Void)? = nil) {
        self.logger.debug("\(self.context) - sending stanza: \(data)");
        let buf = data.data(using: String.Encoding.utf8)!;
        if zlib != nil {
            let outBuf = zlib!.compress(data: buf);
            outStreamBuffer?.append(data: outBuf, completionHandler: completionHandler);
            outStreamBuffer?.writeData(to: self.outStream);
        } else {
            outStreamBuffer?.append(data: buf, completionHandler: completionHandler);
            outStreamBuffer?.writeData(to: self.outStream);
        }
    }
    
    @objc private func connectionTimedOut() {
        queue.async {
            self.logger.debug("\(self.context) - connection timed out at: \(self.state)");
            guard self.state == .connecting else {
                return;
            }
            self.logger.debug("\(self.context) - establishing connection to:\(self.server ?? "unknown", privacy: .auto(mask: .hash)) timed out!");
            if let domain = self.server, let lastConnectionDetails = self.currentConnectionDetails {
                self.dnsResolver.markAsInvalid(for: domain, record: lastConnectionDetails, for: 15 * 60.0);
            }
            self.onStreamTerminate();
        }
    }
    
    open func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.errorOccurred:
            // may happen if cannot connect to server or if connection was broken
            self.logger.debug("stream event: ErrorOccurred: \(aStream.streamError as Any)");
            if (aStream == self.inStream) {
                // this is intentional - we need to execute onStreamTerminate()
                // on main queue, but after all task are executed by our serial queueła
                queue.async { [weak self] in
                    if let state = self?.state, state == .connecting, let domain = self?.server, let lastConnectionDetails = self?.currentConnectionDetails {
                        self?.dnsResolver.markAsInvalid(for: domain, record: lastConnectionDetails, for: 15 * 60.0);
                    }
                    self?.onStreamTerminate();
                }
            }
        case Stream.Event.openCompleted:
            if (aStream == self.inStream) {
                state = State.connected;
                self.logger.debug("setsockopt!");
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
                    self.logger.debug("failed to set SO_KEEPALIVE");
                }
                value = 1;
                if setsockopt(socket, IPPROTO_TCP, TCP_NODELAY, &value, size) != 0 {
                    self.logger.debug("failed to set TCP_NODELAY");
                }

                var tv = timeval();
                tv.tv_sec = 0;
                tv.tv_usec = 0;
                if setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.stride)) != 0 {
                    self.logger.debug("failed to set SO_RCVTIMEO");
                }
                self.logger.debug("setsockopt done");
                
                // moved here?
                restartStream();
                
                self.logger.debug("inStream.hasBytesAvailable: \(self.inStream?.hasBytesAvailable as Any)");
            }
            self.logger.debug("stream event: OpenCompleted");
        case Stream.Event.hasBytesAvailable:
//            self.logger.debug("stream event: HasBytesAvailable");
            if aStream == self.inStream {
                queue.async { [weak self] in
                    guard let that = self else {
                        return;
                    }
                    guard let inStream = that.inStream else {
                        return;
                    }
                    
                    var buffer = [UInt8](repeating: 0, count: 2048);
                    while inStream.hasBytesAvailable {
                        let read = inStream.read(&buffer, maxLength: buffer.count)
                        guard read > 0 else {
                            return;
                        }
                        
                        let data = Data(bytes: &buffer, count: read);
                        if let zlib = that.zlib {
                            let decompressedData = zlib.decompress(data: data);
                            that.parseXml(data: decompressedData);
                        } else {
                            that.parseXml(data: data);
                        }
                    }
                }
            }
        case Stream.Event.hasSpaceAvailable:
//            self.logger.debug("stream event: HasSpaceAvailable");
            if sslCertificateValidated == nil {
                let trustVal = self.inStream?.property(forKey: Stream.PropertyKey(rawValue: kCFStreamPropertySSLPeerTrust as String));
                guard trustVal != nil else {
                    self.closeSocket(newState: .disconnected);
                    return;
                }
                
                let trust: SecTrust = trustVal as! SecTrust;
                
                switch context.connectionConfiguration.sslCertificateValidation {
                case .default:
                    let policy = SecPolicyCreateSSL(false, context.userBareJid.domain as CFString?);
                    var secTrustResultType = SecTrustResultType.invalid;
                    SecTrustSetPolicies(trust, policy);
                    SecTrustEvaluate(trust, &secTrustResultType);
                                        
                    sslCertificateValidated = (secTrustResultType == SecTrustResultType.proceed || secTrustResultType == SecTrustResultType.unspecified);
                case .fingerprint(let fingerprint):
                    sslCertificateValidated = SslCertificateValidator.validateSslCertificate(domain: context.userBareJid.domain, fingerprint: fingerprint, trust: trust);
                case .customValidator(let validator):
                    sslCertificateValidated = validator(trust);
                }

                if !sslCertificateValidated! {
                    self.logger.debug("SSL certificate validation failed");
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
            self.logger.debug("stream event: EndEncountered");
            queue.async {
                self.closeSocket(newState: State.disconnected);
            }
        default:
            self.logger.debug("stream event: \(aStream)");
        }
    }
    
    fileprivate func parseXml(data: Data, tryNo: Int = 0) {
        do {
            try self.parser?.parse(data: data);
        } catch XmlParserError.xmlDeclarationInside(let errorCode, let position) {
            self.parser = XMLParser(delegate: self.parserDelegate!);
            self.logger.debug("got XML declaration within XML, restarting XML parser...");
            let nextTry = tryNo + 1;
            guard tryNo < 4 else {
                self.onError(msg: "XML stream parsing error, code: \(errorCode)");
                return;
            }
            self.parseXml(data: data[position..<data.count], tryNo: nextTry);
        } catch XmlParserError.unknown(let errorCode) {
            self.onError(msg: "XML stream parsing error, code: \(errorCode)");
        } catch {
            self.onError(msg: "XML stream parsing error");
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
    }

    fileprivate func closeStreams() {
        let inStream = self.inStream;
        let outStream = self.outStream;
        self.inStream = nil;
        self.outStream = nil;
        self.outStreamBuffer = nil;
        inStream?.close();
        outStream?.close();
        inStream?.remove(from: RunLoop.current, forMode: RunLoop.Mode.default);
        outStream?.remove(from: RunLoop.current, forMode: RunLoop.Mode.default);
        sslCertificateValidated = false;
    }
    
    /// Event fired when client establishes TCP connection to XMPP server.
    open class ConnectedEvent: Event {
        
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
    open class DisconnectedEvent: Event {
        
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = DisconnectedEvent();
        
        public let type = "connectorDisconnected";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        public let connectionDetails: XMPPSrvRecord?;
        /// If is `true` then XMPP client was properly closed, in other case it may be broken
        public let clean:Bool;
        
        init() {
            sessionObject = nil;
            connectionDetails = nil;
            clean = false;
        }
        
        public init(sessionObject: SessionObject, connectionDetails: XMPPSrvRecord?, clean: Bool) {
            self.sessionObject = sessionObject;
            self.connectionDetails = connectionDetails;
            self.clean = clean;
        }
        
    }
    
    /// Event fired if SSL certificate validation fails
    open class CertificateErrorEvent: Event {
        
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = CertificateErrorEvent();
        
        public let type = "certificateError";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Instance of SecTrust - contains data related to certificate
        public let trust: SecTrust!;
        
        init() {
            sessionObject = nil;
            trust = nil;
        }
        
        init(sessionObject: SessionObject, trust: SecTrust) {
            self.sessionObject = sessionObject;
            self.trust = trust;
        }
    }
    
    class WriteBuffer {
        
        var queue = Queue<Entry>();
        var position = 0;
        
        func append(data: Data, completionHandler: (()->Void)? = nil) {
            queue.offer(Entry(data: data, completionHandler: completionHandler));
        }
        
        func writeData(to outputStream: OutputStream?) {
            guard outputStream != nil && outputStream!.hasSpaceAvailable else {
                return;
            }
            guard let entry = queue.peek() else {
                return;
            }
            let remainingLength = entry.data.count - position;
            
            let sent = entry.data.withUnsafeBytes { (ptr) -> Int in
                return outputStream!.write(ptr.baseAddress!.assumingMemoryBound(to: UInt8.self) + position, maxLength: remainingLength);
            }
            
            if sent < 0 {
                return;
            }
            position += sent;
            if position == entry.data.count {
                position = 0;
                _ = queue.poll();
                entry.completionHandler?();
            }
        }
        
        struct Entry {
            let data: Data;
            let completionHandler: (()->Void)?;
        }
    }
}
