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
import Combine

/**
 Class responsible for connecting to XMPP server, sending and receiving data.
 */
open class SocketConnector : XMPPConnectorBase, Connector {
        
    public typealias State = ConnectorState
        
    public class var supportedProtocols: [ConnectorProtocol] {
        return [ConnectorProtocol.XMPP, ConnectorProtocol.XMPPS];
    }
    
    private var inStream: InputStream?
    private var outStream: OutputStream? {
        didSet {
            if outStream != nil && oldValue == nil {
                outStreamBuffer = WriteBuffer();
            }
        }
    }
    private var outStreamBuffer: WriteBuffer?;
    private let dnsResolver: DNSSrvResolver;
    private var zlib: Zlib?;
    /**
     Stores information about SSL certificate validation and can
     have following values:
     - false - when validation failed or SSL layer was not established
     - true - when certificate passed validation
     - nil - awaiting for SSL certificate validation
     */
    private var sslCertificateValidated: Bool? = false;
    
    /// Internal processing queue
    private let queue: QueueDispatcher = QueueDispatcher(label: "xmpp_socket_queue");
    
    private var server: String?;
    public private(set) var currentEndpoint: ConnectorEndpoint?;
//    private(set) var currentConnectionDetails: XMPPSrvRecord? {
//        didSet {
//            context?.currentConnectionDetails = self.currentConnectionDetails;
//        }
//    }
    
    private var connectionTimer: Foundation.Timer?;
        
    private var stateSubscription: Cancellable?;
    private let connectionConfiguration: ConnectionConfiguration;
    private let eventBus: EventBus;
    private let networkStack = NetworkStack();
    private var connectorStreamDelegate: ConnectionStreamDelegate!;
    
    required public init(context: Context) {
        self.connectionConfiguration = context.connectionConfiguration;
        self.dnsResolver = connectionConfiguration.dnsResolver ?? XMPPDNSSrvResolver();
        self.eventBus = context.eventBus;
        
        super.init(context: context);
        
        availableFeatures.insert(.TLS);
        availableFeatures.insert(.ZLIB);
        networkStack.delegate = RootNetworkDelegate(connector: self);
        
        connectorStreamDelegate = ConnectionStreamDelegate(connector: self);
        
        self.stateSubscription = $state.sink(receiveValue: { [weak self] newState in
            guard let that = self else {
                return;
            }
            let oldState = that.state;
            
            that.queue.sync {
            switch newState {
            case .disconnected:
                if oldState != .disconnected() {
                    DispatchQueue.main.async {
                        that.connectionTimer?.invalidate();
                        that.connectionTimer = nil;
                    }
                }
            case .connected:
                if oldState == .connecting {
                    DispatchQueue.main.async {
                        that.connectionTimer?.invalidate();
                        that.connectionTimer = nil;
                    }
                }
            case .connecting:
                if let timeout: Double = that.context?.connectionConfiguration.conntectionTimeout {
                    that.logger.debug("\(that.connectionConfiguration.userJid) - scheduling timer for: \(timeout)");
                    DispatchQueue.main.async {
                        that.connectionTimer = Foundation.Timer.scheduledTimer(timeInterval: timeout, target: that, selector: #selector(that.connectionTimedOut), userInfo: nil, repeats: false)
                    }
                }
            default:
                break;
            }
            }
        })
    }
    
    deinit {
        self.queue.sync {
            if let inStream = self.inStream {
                inStream.close();
                inStream.remove(from: .main, forMode: .default);
            }
            if let outStream = self.outStream {
                outStream.close();
                outStream.remove(from: .main, forMode: .default);
            }
            stateSubscription?.cancel();
        }
    }
    
    /**
     Method used by `XMPPClient` to start process of establishing connection to XMPP server.
     
     - parameter endpoint: used internally to force connection to particular XMPP server (ie. one of many in cluster)
     */
    open func start(endpoint: ConnectorEndpoint? = nil) {
        queue.sync {
            guard state == .disconnected() else {
                logger.log("start() - stopping connetion as state is not connecting \(self.state)");
                return;
            }
            
            let start = Date();
            let timeout: Double? = self.connectionConfiguration.conntectionTimeout;
            state = .connecting;
            self.server = connectionConfiguration.userJid.domain;
            //            if let srvRecord = self.sessionLogic?.serverToConnectDetails() {
            //                self.connect(dnsName: srvRecord.target, srvRecord: srvRecord);
            //                return;
            //            } else {
            if let endpoint = endpoint as? SocketConnectorEndpoint {
                self.connect(endpoint: endpoint);
            } else if let details = self.connectionConfiguration.connectionDetails as? SocketConnectorEndpoint {
                self.connect(endpoint: details);
            } else {
                let server = self.connectionConfiguration.userJid.domain;
                self.logger.debug("\(self.connectionConfiguration.userJid) - connecting to server: \(server)");
                self.dnsResolver.resolve(domain: server, for: self.connectionConfiguration.userJid) { result in
                    if timeout != nil {
                        // if timeout was set, do not try to connect after timeout was fired!
                        // another event will take care of that
                        guard Date().timeIntervalSince(start) < timeout! else {
                            return;
                        }
                    }
                    switch result {
                    case .success(let dnsResult):
                        if let record = dnsResult.record() {
                            self.connect(endpoint: SocketConnectorEndpoint(proto: record.directTls ? .XMPPS : .XMPP, host: record.target, port: record.port));
                        } else {
                            self.connect(endpoint: SocketConnectorEndpoint(proto: .XMPP, host: server, port: 5222));
                        }
                    case .failure(_):
                        self.connect(endpoint: SocketConnectorEndpoint(proto: .XMPP, host: server, port: 5222));
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
    
    public func prepareEndpoint(withResumptionLocation location: String?) -> ConnectorEndpoint? {
        guard let endpoint = self.currentEndpoint as? SocketConnectorEndpoint, let (host, port) = SocketConnector.preprocessConnectionDetails(string: location) else {
            return nil;
        }
        return SocketConnectorEndpoint(proto: endpoint.proto, host: host, port: port ?? endpoint.port);
    }
    
    public func prepareEndpoint(withSeeOtherHost seeOtherHost: String?) -> ConnectorEndpoint? {
        guard let endpoint = self.currentEndpoint as? SocketConnectorEndpoint, let (host, port) = SocketConnector.preprocessConnectionDetails(string: seeOtherHost) else {
            return nil;
        }
        return SocketConnectorEndpoint(proto: endpoint.proto, host: host, port: port ?? endpoint.port);
    }
    
//    private func connect(endpoint: SocketConnectorEndpoint) {
//        queue.sync {
//            guard state == .connecting else {
//                logger.log("connect(dns) - stopping connetion as state is not connecting \(self.state)");
//                return;
//            }
//
//            logger.debug("\(self.connectionConfiguration.userJid) - got dns record to connect to: \(srvRecord)");
//
//            self.server = dnsName;
//            self.currentConnectionDetails = srvRecord;
//            self.connect(addr: srvRecord.target, port: srvRecord.port, ssl: srvRecord.directTls);
//        }
//    }
    
    /**
     Should always be called from local dispatch queue!
     */
    private func connect(endpoint: SocketConnectorEndpoint) -> Void {
        logger.debug("connecting to: \(endpoint)");
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
        
        Stream.getStreamsToHost(withName: endpoint.host, port: endpoint.port, inputStream: &inStream, outputStream: &outStream);
        
        self.inStream!.delegate = self.connectorStreamDelegate
        self.outStream!.delegate = self.connectorStreamDelegate
                
        self.inStream!.schedule(in: RunLoop.main, forMode: RunLoop.Mode.default)
        self.outStream!.schedule(in: RunLoop.main, forMode: RunLoop.Mode.default)
                
        if (endpoint.proto == .XMPPS) {
            configureTLS(directTls: true);
        } else {
            let inStream = self.inStream;
            logger.debug("opening stream: \(inStream) in state: \(self.state) for \(self.server)");
            self.inStream!.open();
            self.outStream!.open();
        }
     
        initiateParser();
    }
    
    public func activate(feature: ConnectorFeature) {
        switch feature {
        case .TLS:
            self.serialize(.stanza(Stanza(elem: Element(name: "starttls", xmlns: "urn:ietf:params:xml:ns:xmpp-tls"))));
        default:
            self.serialize(.stanza(Stanza(elem: Element(name: "compressed", xmlns: "http://jabber.org/protocol/compress", children: [Element(name: "method", cdata: "zlib")]))));
        }
    }
        
    public func stop(force: Bool, completionHandler: (()->Void)? = nil) {
        guard !force else {
            queue.async {
                self.closeSocket(newState: State.disconnected(.none));
                completionHandler?();
            }
            return;
        }
        queue.async {
        switch self.state {
        case .disconnected(_), .disconnecting:
            self.logger.debug("\(self.connectionConfiguration.userJid) - not connected or already disconnecting");
            completionHandler?();
            return;
        case .connected:
            self.state = State.disconnecting;
            self.logger.debug("\(self.connectionConfiguration.userJid) - closing XMPP stream");
            
//            self.streamEvents.send(.streamClose())
            // TODO: I'm not sure about that!!
            self.queue.async {
                self.sendSync("</stream:stream>") {
                    self.closeSocket(newState: State.disconnected(.none));
                    completionHandler?();
                }
            }
        case .connecting:
            self.state = State.disconnecting;
            self.logger.debug("\(self.connectionConfiguration.userJid) - closing TCP connection");
            self.closeSocket(newState: State.disconnected(.timeout));
            completionHandler?();
        }
        }
    }
    
    /**
     Should always be called from local dispatch queue!
     */
    private func configureTLS(directTls: Bool = false) {
        self.logger.debug("\(self.connectionConfiguration.userJid) - configuring TLS");

        guard let inStream = self.inStream, let outStream = self.outStream else {
            return;
        }
        inStream.delegate = self.connectorStreamDelegate
        outStream.delegate = self.connectorStreamDelegate

        let domain = self.connectionConfiguration.userJid.domain;
        
        sslCertificateValidated = nil;
        let settings:NSDictionary = NSDictionary(objects: [StreamSocketSecurityLevel.negotiatedSSL, 
                                                           domain, kCFBooleanFalse as Any], forKeys: [kCFStreamSSLLevel as NSString,
                kCFStreamSSLPeerName as NSString,
                kCFStreamSSLValidatesCertificateChain as NSString])
        let started = CFReadStreamSetProperty(inStream as CFReadStream, CFStreamPropertyKey(rawValue: kCFStreamPropertySSLSettings), settings as CFTypeRef)
        if (!started) {
            self.logger.debug("\(self.connectionConfiguration.userJid) - could not start STARTTLS");
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
            
        self.activeFeatures.insert(.TLS);
    }
    
    open func restartStream() {
        queue.async {
            self.initiateParser();
            self.streamEvents.send(.streamStart);
        }
    }
    
    private func proceedTLS() {
        self.configureTLS();
        self.restartStream();
    }
    
    private func proceedZlib() {
        self.zlib = Zlib(compressionLevel: .default, flush: .sync);
        self.activeFeatures.insert(.ZLIB);
        self.restartStream();
    }
    
    public override func parsed(_ event: StreamEvent) {
        super.parsed(event);
        switch event {
        case .stanza(let packet):
            if packet.name == "error" && packet.xmlns == "http://etherx.jabber.org/streams" {
                state = .disconnected(.streamError(packet.element));
            } else if packet.name == "proceed" && packet.xmlns == "urn:ietf:params:xml:ns:xmpp-tls" {
                proceedTLS();
            } else if packet.name == "compressed" && packet.xmlns == "http://jabber.org/protocol/compress" {
                proceedZlib();
            } else {
                streamEvents.send(event);
            }
        case .streamClose(let reason):
            state = State.disconnecting;
            sendSync("</stream:stream>");
            closeSocket(newState: State.disconnected(reason == .xmlError ? .xmlError(nil) : .none));
        default:
            streamEvents.send(event);
        }
    }
    
    public override func serialize(_ event: StreamEvent) {
        super.serialize(event);
        switch event {
        case .stanza(let stanza):
            if let data = stanza.element.stringValue.data(using: .utf8) {
                networkStack.send(data: data);
            }
        case .streamClose:
            if let data = "<stream:stream/>".data(using: .utf8) {
                networkStack.send(data: data);
            }
        case .streamOpen(let attributes):
            let attributesString = attributes.map({ "\($0.key)='\($0.value)' "}).joined();
            let openString = "<stream:stream \(attributesString) version='1.0' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>";
            print("send: \(openString)")
            if let data = openString.data(using: .utf8) {
                networkStack.send(data: data);
            }
        default:
            break;
        }
    }
    
    public func send(_ data: StreamEvent, completionHandler: (() -> Void)?) {
        queue.async {
            guard self.state == .connected else {
                return;
            }
            self.serialize(data);
        }
    }
    
//    // TODO: who is calling this?? should be local queue
//    override open func onError(msg: String?) {
//        self.logger.error("\(msg as Any)");
//        closeSocket(newState: State.disconnected(.xmlError(msg)));
//    }
//
//    // TODO: who is calling this?? should be local queue
//    override open func onStreamTerminate(reason: State.DisconnectionReason) {
//        self.logger.debug("onStreamTerminate called... state: \(self.state)");
//        self.streamEvents.send(.streamTerminate)
//        switch state {
//        case .disconnecting, .connecting:
//            closeSocket(newState: State.disconnected(reason));
//        // connecting is also set in case of see other host
//        case .connected:
//            //-- probably from other socket, ie due to restart!
//            let inStreamState = inStream?.streamStatus;
//            if inStreamState == nil || inStreamState == .error || inStreamState == .closed {
//                closeSocket(newState: State.disconnected(reason))
//            } else {
//                state = State.disconnecting;
//                sendSync("</stream:stream>");
//                closeSocket(newState: State.disconnected(reason));
//            }
//        default:
//            break;
//        }
//    }
       
//    open func send(_ data: StreamData, completionHandler: (()->Void)?) {
//        queue.async {
//            guard self.state == .connected else {
//                return;
//            }
//
//            switch data {
//            case .stanza(let stanza):
//                self.sendSync(stanza.element.stringValue, completionHandler: completionHandler);
//            case .string(let data):
//                self.sendSync(data, completionHandler: completionHandler);
//            }
//        }
//    }
//
//    open func keepAlive() {
//        self.send(.string(" "));
//    }
        
    /**
     Method responsible for actual process of sending data.
     */
    private func sendSync(_ data:String, completionHandler: (()->Void)? = nil) {
        self.logger.debug("\(self.connectionConfiguration.userJid) - sending stanza: \(data)");
        let buf = data.data(using: String.Encoding.utf8)!;
        self.networkStack.send(data: buf);
        completionHandler?();
//        if zlib != nil {
//            let outBuf = zlib!.compress(data: buf);
//            outStreamBuffer?.append(data: outBuf, completionHandler: completionHandler);
//            outStreamBuffer?.writeData(to: self.outStream);
//        } else {
//            outStreamBuffer?.append(data: buf, completionHandler: completionHandler);
//            outStreamBuffer?.writeData(to: self.outStream);
//        }
    }
    
    private func read(data: Data) {
        super.read(data: data);
    }
    
    private func write(data: Data) {
        outStreamBuffer?.append(data: data, completionHandler: nil);
        outStreamBuffer?.writeData(to: self.outStream);
    }
    
    @objc private func connectionTimedOut() {
        queue.async {
            self.logger.debug("\(self.connectionConfiguration.userJid) - connection timed out at: \(self.state)");
            guard self.state == .connecting else {
                return;
            }
            self.logger.debug("\(self.connectionConfiguration.userJid) - establishing connection to:\(self.server ?? "unknown", privacy: .auto(mask: .hash)) timed out!");
            if let domain = self.server, let lastConnectionDetails = self.currentEndpoint as? SocketConnectorEndpoint {
                self.dnsResolver.markAsInvalid(for: domain, host: lastConnectionDetails.host, port: lastConnectionDetails.port, for: 15 * 60.0);
            }
            self.closeSocket(newState: State.disconnected(.timeout));
        }
    }
    
    private func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        print("processing stream event: \(eventCode.rawValue)");
        queue.async {
            switch eventCode {
            case Stream.Event.errorOccurred:
                // may happen if cannot connect to server or if connection was broken
                self.logger.debug("stream event: ErrorOccurred: \(aStream.streamError as Any)");
                if (aStream == self.inStream) {
                    // this is intentional - we need to execute onStreamTerminate()
                    // on main queue, but after all task are executed by our serial queue
                    if self.state == .connecting, let domain = self.server, let lastConnectionDetails = self.currentEndpoint as? SocketConnectorEndpoint {
                        self.dnsResolver.markAsInvalid(for: domain, host: lastConnectionDetails.host, port: lastConnectionDetails.port, for: 15 * 60.0);
                    }
                    self.closeSocket(newState: State.disconnected(.timeout));
                }
            case Stream.Event.openCompleted:
                if (aStream == self.inStream) {
                    self.state = State.connected;
                    self.logger.debug("setsockopt!");
                    let socketData:Data = CFReadStreamCopyProperty(self.inStream! as CFReadStream, CFStreamPropertyKey.socketNativeHandle) as! Data;
                    var socket:CFSocketNativeHandle = 0;
                    (socketData as NSData).getBytes(&socket, length: MemoryLayout.size(ofValue: socket));
                    var value:Int = 0;
                    let size = UInt32(MemoryLayout.size(ofValue: value));
            
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
                    self.restartStream();
                
                    self.logger.debug("inStream.hasBytesAvailable: \(self.inStream?.hasBytesAvailable as Any)");
                }
                self.logger.debug("stream event: OpenCompleted");
            case Stream.Event.hasBytesAvailable:
                self.logger.debug("stream event: HasBytesAvailable");
                if aStream == self.inStream, let inStream = self.inStream {
                    var buffer = [UInt8](repeating: 0, count: 2048);
                    while inStream.hasBytesAvailable {
                        let read = inStream.read(&buffer, maxLength: buffer.count)
                        guard read > 0 else {
                            return;
                        }
                        
                        let data = Data(bytes: &buffer, count: read);
                        self.networkStack.receive(data: data);
//                        if let zlib = self.zlib {
//                            let decompressedData = zlib.decompress(data: data);
//                            self.parseXml(data: decompressedData);
//                        } else {
//                            self.parseXml(data: data);
//                        }
                    }
                }
            case Stream.Event.hasSpaceAvailable:
                self.logger.debug("stream event: HasSpaceAvailable");
                if self.sslCertificateValidated == nil {
                    let trustVal = self.inStream?.property(forKey: Stream.PropertyKey(rawValue: kCFStreamPropertySSLPeerTrust as String));
                    guard trustVal != nil else {
                        self.closeSocket(newState: .disconnected(.none));
                        return;
                    }
                
                    let trust: SecTrust = trustVal as! SecTrust;
                    switch self.connectionConfiguration.sslCertificateValidation {
                    case .default:
                        let policy = SecPolicyCreateSSL(false, self.connectionConfiguration.userJid.domain as CFString?);
                        var secTrustResultType = SecTrustResultType.invalid;
                        SecTrustSetPolicies(trust, policy);
                        SecTrustEvaluate(trust, &secTrustResultType);
                                        
                        self.sslCertificateValidated = (secTrustResultType == SecTrustResultType.proceed || secTrustResultType == SecTrustResultType.unspecified);
                    case .fingerprint(let fingerprint):
                        self.sslCertificateValidated = SslCertificateValidator.validateSslCertificate(domain: self.connectionConfiguration.userJid.domain, fingerprint: fingerprint, trust: trust);
                    case .customValidator(let validator):
                        self.sslCertificateValidated = validator(trust);
                    }

                    if !self.sslCertificateValidated! {
                        self.logger.debug("SSL certificate validation failed");
                        if let context = self.context {
                            self.eventBus.fire(CertificateErrorEvent(context: context, trust: trust));
                        }
                        self.closeSocket(newState: .disconnected(.sslCertError(trust)));
                        return;
                    }
                }
                if aStream == self.outStream {
                    self.outStreamBuffer?.writeData(to: self.outStream);
                }
            case Stream.Event.endEncountered:
                self.logger.debug("stream event: EndEncountered");
                if aStream == self.outStream || aStream == self.inStream {
                    self.closeSocket(newState: State.disconnected(.none));
                }
            default:
                self.logger.debug("stream event: \(aStream)");
            }
        }
    }
        
    /**
     Internal method used to properly close TCP connection and set state if needed
     */
    private func closeSocket(newState: State?) {
        closeStreams();
        networkStack.reset();
        if newState != nil {
            state = newState!;
        }
    }

    private func closeStreams() {
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
    @available(*, deprecated, message: "Watch state instead")
    open class ConnectedEvent: AbstractEvent {
        
        /// identified of event which should be used during registration of `EventHandler`
        public static let TYPE = ConnectedEvent();
                
        init() {
            super.init(type: "connectorConnected");
        }
        
        public init(context: Context) {
            super.init(type: "connectorConnected", context: context);
        }
        
    }
    
    /// Event fired when TCP connection to XMPP server is closed or is broken.
    @available(*, deprecated, message: "Watch state instead")
    open class DisconnectedEvent: AbstractEvent {
        
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = DisconnectedEvent();
        
        public let connectionDetails: XMPPSrvRecord?;
        /// If is `true` then XMPP client was properly closed, in other case it may be broken
        public let clean:Bool;
        
        init() {
            connectionDetails = nil;
            clean = false;
            super.init(type: "connectorDisconnected");
        }
        
        public init(context: Context, connectionDetails: XMPPSrvRecord?, clean: Bool) {
            self.connectionDetails = connectionDetails;
            self.clean = clean;
            super.init(type: "connectorDisconnected", context: context);
        }
        
    }
    
    /// Event fired if SSL certificate validation fails
    @available(*, deprecated, message: "Watch state of .sslCertError")
    open class CertificateErrorEvent: AbstractEvent {
        
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = CertificateErrorEvent();
        
        /// Instance of SecTrust - contains data related to certificate
        public let trust: SecTrust!;
        
        init() {
            trust = nil;
            super.init(type: "certificateError");
        }
        
        init(context: Context, trust: SecTrust) {
            self.trust = trust;
            super.init(type: "certificateError", context: context);
        }
    }
    
    class WriteBuffer {
        
        var queue = Queue<Entry>();
        var position = 0;
        
        func append(data: Data, completionHandler: (()->Void)? = nil) {
            queue.offer(Entry(data: data, completionHandler: completionHandler));
        }
        
        func clear() {
            queue.clear();
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
    
    class ConnectionStreamDelegate: NSObject, StreamDelegate {
        weak var connector: SocketConnector?;
        
        init(connector: SocketConnector) {
            self.connector = connector;
        }
        
        func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
            connector?.stream(aStream, handle: eventCode);
        }
    }
    
    class NetworkStack: NetworkDelegate {
        private var processors: [NetworkProcessor] = [];
        private var delegates: [InternalNetworkDelegate] = [];
        
        fileprivate var delegate: NetworkDelegate?;
        
        init() {
        }
        
        func reset() {
            self.delegates.removeAll();
            self.processors.removeAll();
        }
        
        func addProcessor(_ processor: NetworkProcessor) {
            guard let delegate = self.delegate else {
                return;
            }
            let upstream = NetworkEventHandler(handler: delegate.receive(data:));
            if let previous = self.processors.last {
                previous.delegate?.upstream = NetworkEventHandler(handler: processor.receive(data:));
                let downstream = NetworkEventHandler(handler: previous.send(data:));
                let delegate = InternalNetworkDelegate(upstream: upstream, downstream: downstream);
                self.delegates.append(delegate);
                processor.delegate = delegate;
            } else {
                let downstream = NetworkEventHandler(handler: delegate.send(data:));
                let delegate = InternalNetworkDelegate(upstream: upstream, downstream: downstream);
                self.delegates.append(delegate);
                processor.delegate = delegate;
            }
            processors.append(processor);
        }
        
        func send(data: Data) {
            if let processor = processors.last {
                processor.send(data: data);
            } else {
                delegate?.send(data: data);
            }
        }
        
        func receive(data: Data) {
            if let processor = processors.first {
                processor.receive(data: data);
            } else {
                delegate?.receive(data: data);
            }
        }
    }
        
    public class NetworkProcessor: NetworkDelegate {
        
        fileprivate weak var delegate: InternalNetworkDelegate?;

        public func receive(data: Data) {
            delegate?.receive(data: data);
        }
        
        public func send(data: Data) {
            delegate?.send(data: data);
        }
        
    }
    
    final class NetworkEventHandler {
        
        let handler: (Data)->Void;
        
        init(handler: @escaping (Data)->Void) {
            self.handler = handler;
        }
        
        func handle(data: Data) {
            handler(data);
        }
    }
    
    final class InternalNetworkDelegate: NetworkDelegate {
        var upstream: NetworkEventHandler;
        var downstream: NetworkEventHandler;
        
        init(upstream: NetworkEventHandler, downstream: NetworkEventHandler) {
            self.upstream = upstream;
            self.downstream = downstream;
        }
        
        func receive(data: Data) {
            upstream.handle(data: data);
        }
        
        func send(data: Data) {
            downstream.handle(data: data);
        }
    }
    
    final class RootNetworkDelegate: NetworkDelegate {
        
        private weak var connector: SocketConnector?;
        
        init(connector: SocketConnector) {
            self.connector = connector;
        }
        
        func receive(data: Data) {
            connector?.read(data: data);
        }
        
        func send(data: Data) {
            connector?.write(data: data);
        }
    }
    
    public struct SocketConnectorEndpoint: ConnectorEndpoint, CustomStringConvertible {
        
        public let proto: ConnectorProtocol;
        public let host: String;
        public let port: Int;
        
        public var description: String {
            return "\(proto.rawValue):\(host):\(port)";
        }
        
        init(proto: ConnectorProtocol, host: String, port: Int) {
            self.proto = proto;
            self.host = host;
            self.port = port;
        }
        
    }
}

public protocol NetworkDelegate: class {
    
    func receive(data: Data);
    
    func send(data: Data);
    
}
