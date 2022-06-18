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
 Implementation of a C2S XMPP connector based on Streams and Secure Transport API (working but deprecated)
 */
open class SocketConnector : XMPPConnectorBase, Connector, NetworkDelegate {
        
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
    /**
     Stores information about SSL certificate validation and can
     have following values:
     - false - when validation failed or SSL layer was not established
     - true - when certificate passed validation
     - nil - awaiting for SSL certificate validation
     */
    private var sslCertificateValidated: Bool? = false;
    
    /// Internal processing queue
    private let queue = DispatchQueue(label: "xmpp_socket_queue");
    
    private let userJid: BareJID;
    private var server: String {
        return userJid.domain;
    }
    public private(set) var currentEndpoint: ConnectorEndpoint?;
//    private(set) var currentConnectionDetails: XMPPSrvRecord? {
//        didSet {
//            context?.currentConnectionDetails = self.currentConnectionDetails;
//        }
//    }
    
    private var connectionTimer: Foundation.Timer?;
        
    private var stateSubscription: Cancellable?;
    private let options: Options;
    private let networkStack = NetworkStack();
    private var connectorStreamDelegate: ConnectionStreamDelegate!;
    
    required public init(context: Context) {
        self.userJid = context.connectionConfiguration.userJid;
        self.options = context.connectionConfiguration.connectorOptions as! Options;
        
        super.init(context: context);
        
        availableFeatures.insert(.TLS);
        availableFeatures.insert(.ZLIB);
        
        networkStack.delegate = self;
        
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
                if let timeout: Double = that.options.conntectionTimeout {
                    that.logger.debug("\(that.userJid) - scheduling timer for: \(timeout)");
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
            let timeout: Double? = self.options.conntectionTimeout;
            state = .connecting;
            //            if let srvRecord = self.sessionLogic?.serverToConnectDetails() {
            //                self.connect(dnsName: srvRecord.target, srvRecord: srvRecord);
            //                return;
            //            } else {
            if let endpoint = endpoint as? SocketConnector.Endpoint {
                self.connect(endpoint: endpoint);
            } else if let details = self.options.connectionDetails {
                self.connect(endpoint: details);
            } else {
                self.logger.debug("\(self.userJid) - connecting to server: \(self.server)");
                self.options.dnsResolver.resolve(domain: server, for: self.userJid) { result in
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
                            self.connect(endpoint: SocketConnector.Endpoint(proto: record.directTls ? .XMPPS : .XMPP, host: record.target, port: record.port));
                        } else {
                            self.connect(endpoint: SocketConnector.Endpoint(proto: .XMPP, host: self.server, port: 5222));
                        }
                    case .failure(_):
                        self.connect(endpoint: SocketConnector.Endpoint(proto: .XMPP, host: self.server, port: 5222));
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
        guard let endpoint = self.currentEndpoint as? SocketConnector.Endpoint, let (host, port) = SocketConnector.preprocessConnectionDetails(string: location) else {
            return nil;
        }
        return SocketConnector.Endpoint(proto: endpoint.proto, host: host, port: port ?? endpoint.port);
    }
    
    public func prepareEndpoint(withSeeOtherHost seeOtherHost: String?) -> ConnectorEndpoint? {
        guard let endpoint = self.currentEndpoint as? SocketConnector.Endpoint, let (host, port) = SocketConnector.preprocessConnectionDetails(string: seeOtherHost) else {
            return nil;
        }
        return SocketConnector.Endpoint(proto: endpoint.proto, host: host, port: port ?? endpoint.port);
    }
    
    /**
     Should always be called from local dispatch queue!
     */
    private func connect(endpoint: SocketConnector.Endpoint) -> Void {
        logger.debug("connecting to: \(endpoint)");
        guard state == .connecting else {
            logger.log("connect(addr) - stopping connetion as state is not connecting \(self.state)");
            return;
        }
        
        self.currentEndpoint = endpoint;
        
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
            self.serialize(.stanza(Stanza(elem: Element(name: "starttls", xmlns: "urn:ietf:params:xml:ns:xmpp-tls"))), completion: .none);
        case .ZLIB:
            self.serialize(.stanza(Stanza(elem: Element(name: "compress", xmlns: "http://jabber.org/protocol/compress", children: [Element(name: "method", cdata: "zlib")]))), completion: .none);
        default:
            break;
        }
    }
        
    public func stop(force: Bool) -> Future<Void,Never> {
        return Future({ promise in
            self.queue.async {
                guard !force else {
                    self.closeSocket(newState: State.disconnected(.none));
                    promise(.success(Void()));
                    return;
                }
                switch self.state {
                case .disconnected(_), .disconnecting:
                    self.logger.debug("\(self.userJid) - not connected or already disconnecting");
                    promise(.success(Void()));
                    return;
                case .connected:
                    self.state = State.disconnecting;
                    self.logger.debug("\(self.userJid) - closing XMPP stream");
                    
        //            self.streamEvents.send(.streamClose())
                    // TODO: I'm not sure about that!!
                    self.queue.async {
                        self.sendSync("</stream:stream>", completion: .written({ result in
                            self.closeSocket(newState: State.disconnected(.none));
                            promise(.success(Void()));
                        }));
                    }
                case .connecting:
                    self.state = State.disconnecting;
                    self.logger.debug("\(self.userJid) - closing TCP connection");
                    self.closeSocket(newState: State.disconnected(.timeout));
                    promise(.success(Void()));
                }
            }
        })
    }
    
    /**
     Should always be called from local dispatch queue!
     */
    private func configureTLS(directTls: Bool = false) {
        if let provider = self.options.networkProcessorProviders.first(where: { $0.providedFeatures.contains(.TLS) }) {
            let tlsProcessor = provider.supply();
            if let sslProcessor = tlsProcessor as? SSLNetworkProcessor {
                self.sslCertificateValidated = true;
                sslProcessor.setALPNProtocols(["xmpp-client"]);
                sslProcessor.serverName = self.server;
                sslProcessor.certificateValidation = options.sslCertificateValidation;
                sslProcessor.certificateValidationFailed = { [weak self] trust in
                    if let trust = trust {
                        self?.closeSocket(newState: .disconnected(.sslCertError(trust)));
                    } else {
                        _ = self?.stop(force: true);
                    }
                    return;
                }
            }
            self.networkStack.addProcessor(tlsProcessor);
            self.activeFeatures.insert(.TLS);
            self.inStream!.open();
            self.outStream!.open();
            return;
        }
        
        self.logger.debug("\(self.userJid) - configuring TLS");

        guard let inStream = self.inStream, let outStream = self.outStream else {
            return;
        }
        inStream.delegate = self.connectorStreamDelegate
        outStream.delegate = self.connectorStreamDelegate

        let domain = self.userJid.domain;
        
        sslCertificateValidated = nil;
        let settings:NSDictionary = NSDictionary(objects: [StreamSocketSecurityLevel.negotiatedSSL, 
                                                           domain, kCFBooleanFalse as Any], forKeys: [kCFStreamSSLLevel as NSString,
                kCFStreamSSLPeerName as NSString,
                kCFStreamSSLValidatesCertificateChain as NSString])
        let started = CFReadStreamSetProperty(inStream as CFReadStream, CFStreamPropertyKey(rawValue: kCFStreamPropertySSLSettings), settings as CFTypeRef)
        if (!started) {
            self.logger.debug("\(self.userJid) - could not start STARTTLS");
        }
        CFWriteStreamSetProperty(outStream as CFWriteStream, CFStreamPropertyKey(rawValue: kCFStreamPropertySSLSettings), settings as CFTypeRef);
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, OSXApplicationExtension 10.13, OSX 10.13, *) {
            let sslContext: Foundation.SSLContext = outStream.property(forKey: Stream.PropertyKey(rawValue: kCFStreamPropertySSLContext as String)) as! Foundation.SSLContext;
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
        if let provider = self.options.networkProcessorProviders.first(where: { $0.providedFeatures.contains(.ZLIB) }) {
            self.networkStack.addProcessor(provider.supply());
        } else {
            self.networkStack.addProcessor(ZLIBProcessor());
        }
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
            sendSync("</stream:stream>",  completion: .none);
            closeSocket(newState: State.disconnected(reason == .xmlError ? .xmlError(nil) : .none));
        default:
            streamEvents.send(event);
        }
    }
    
    public override func serialize(_ event: StreamEvent, completion: WriteCompletion) {
        super.serialize(event, completion: .none);
        switch event {
        case .stanza(let stanza):
            sendSync(stanza.element.description, completion: completion);
        case .streamClose:
            sendSync("<stream:stream/>", completion: completion);
        case .streamOpen(let attributes):
            let attributesString = attributes.map({ "\($0.key)='\($0.value)' "}).joined();
            let openString = "<stream:stream \(attributesString) version='1.0' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>";
            sendSync(openString, completion: completion);
        default:
            break;
        }
    }
    
    public func send(_ data: StreamEvent, completion: WriteCompletion) {
        queue.async {
            guard self.state == .connected else {
                return;
            }
            self.serialize(data, completion: completion);
        }
    }
    
    /**
     Method responsible for actual process of sending data.
     */
    private func sendSync(_ data:String, completion: WriteCompletion) {
        self.logger.debug("\(self.userJid) - sending stanza: \(data)");
        let buf = data.data(using: String.Encoding.utf8)!;
        self.networkStack.write(data: buf, completion: completion);
    }
    
    public func read(data: Data) {
        super.read(data: data);
    }
        
    public func write(data: Data, completion: WriteCompletion) {
        outStreamBuffer?.append(data: data, completion: completion);
        outStreamBuffer?.writeData(to: self.outStream);
    }
    
    @objc private func connectionTimedOut() {
        queue.async {
            self.logger.debug("\(self.userJid) - connection timed out at: \(self.state)");
            guard self.state == .connecting else {
                return;
            }
            self.logger.debug("\(self.userJid) - establishing connection to:\(self.server, privacy: .auto(mask: .hash)) timed out!");
            if let lastConnectionDetails = self.currentEndpoint as? SocketConnector.Endpoint {
                self.options.dnsResolver.markAsInvalid(for: self.server, host: lastConnectionDetails.host, port: lastConnectionDetails.port, for: 15 * 60.0);
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
                    if self.state == .connecting, let lastConnectionDetails = self.currentEndpoint as? SocketConnector.Endpoint {
                        self.options.dnsResolver.markAsInvalid(for: self.server, host: lastConnectionDetails.host, port: lastConnectionDetails.port, for: 15 * 60.0);
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
                        self.networkStack.read(data: data);
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
                    switch self.options.sslCertificateValidation {
                    case .default:
                        let policy = SecPolicyCreateSSL(false, self.userJid.domain as CFString?);
                        var secTrustResultType = SecTrustResultType.invalid;
                        SecTrustSetPolicies(trust, policy);
                        SecTrustEvaluate(trust, &secTrustResultType);
                                        
                        self.sslCertificateValidated = (secTrustResultType == SecTrustResultType.proceed || secTrustResultType == SecTrustResultType.unspecified);
                    case .fingerprint(let fingerprint):
                        self.sslCertificateValidated = SslCertificateValidator.validateSslCertificate(domain: self.server, fingerprint: fingerprint, trust: trust);
                    case .customValidator(let validator):
                        self.sslCertificateValidated = validator(trust);
                    }

                    if !self.sslCertificateValidated! {
                        self.logger.debug("SSL certificate validation failed");
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
    
    class WriteBuffer {
        
        var queue = Queue<Entry>();
        var position = 0;
        
        func append(data: Data, completion: WriteCompletion) {
            queue.offer(Entry(data: data, completion: completion));
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
                entry.completion.completed(result: .success(Void()));
            }
        }
        
        struct Entry {
            let data: Data;
            let completion: WriteCompletion;
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
    
}

extension SocketConnector {
    public struct Endpoint: ConnectorEndpoint, CustomStringConvertible {
        
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

extension SocketConnector {
    
    public struct Options: ConnectorOptions {
        
        public var connector: Connector.Type {
            return SocketConnector.self;
        }
        
        public var sslCertificateValidation: SSLCertificateValidation = .default;
        public var connectionDetails: SocketConnector.Endpoint?;
        public var lastConnectionDetails: XMPPSrvRecord?;
        public var conntectionTimeout: Double?;
        public var dnsResolver: DNSSrvResolver = XMPPDNSSrvResolver(directTlsEnabled: true);

        public var networkProcessorProviders: [NetworkProcessorProvider] = []
        
        public init() {}
        
    }
}

public protocol NetworkProcessorProvider {

    var providedFeatures: [ConnectorFeature] { get }
    
    func supply() -> SocketConnector.NetworkProcessor;
    
}

public enum WriteCompletion {
    case none
    case written((Result<Void,Error>)->Void)
    
    public func completed(result: Result<Void,Error>) {
        switch self {
        case .none:
            break;
        case .written(let callback):
            callback(result);
        }
    }
}
