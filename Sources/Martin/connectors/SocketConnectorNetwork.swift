//
// SocketConnectorNetwork.swift
//
// TigaseSwift
// Copyright (C) 2020 "Tigase, Inc." <office@tigase.com>
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
import Combine
import Network
import CryptoKit

/**
 Implementation of a C2S XMPP connector based on the `Network.framework` (requires custom SSL/TLS implementation)
 */
open class SocketConnectorNetwork: XMPPConnectorBase, Connector, NetworkDelegate {
    
    public class var supportedProtocols: [ConnectorProtocol] {
        return [ConnectorProtocol.XMPP, ConnectorProtocol.XMPPS];
    }
    
    public var supportedChannelBindings: [ChannelBinding] {
        guard let sslProcessor: SSLNetworkProcessor = networkStack.processor() else {
            return [];
        }
        return sslProcessor.supportedChannelBindings;
    }
    
    /// Internal processing queue
    private let queue = DispatchQueue(label: "xmpp_socket_queue");
    
    private let userJid: BareJID;
    private var server: String {
        return userJid.domain;
    }
    public private(set) var currentEndpoint: ConnectorEndpoint?;
    
    private let options: Options;
    private let networkStack = SocketConnector.NetworkStack();

    private var connection: NWConnection? {
        willSet {
            if connection !== newValue {
                connection?.stateUpdateHandler = nil;
                connection?.viabilityUpdateHandler = nil;
                connection?.pathUpdateHandler = nil;
                networkStack.reset();
                activeFeatures.removeAll();
                switch connection?.state {
                case .ready, .setup, .waiting, .preparing:
                    connection?.cancel();
                default:
                    break;
                }
            }
        }
        didSet {
            if let conn = connection, oldValue !== conn {
                conn.stateUpdateHandler = { [weak self, weak conn] state in
                    guard let that = self, let conn else {
                        return;
                    }
                    let isCurrent = conn === that.connection;
                    that.logger.debug("\(that.userJid) - changed state to: \(state) for endpoint: \(that.connection?.endpoint) current connection = \(isCurrent)")
                    that.logger.debug("original endpoint: \(conn.endpoint), current endpoint: \(that.connection?.endpoint)")
                    guard isCurrent else {
                        that.logger.debug("\(that.userJid) - skipping processing state change")
                        return
                    }
                    that.logger.debug("\(that.userJid) - processing state change")
                    switch state {
                    case .ready:
                        that.state = .connected;
                        that.initiateParser();
                        that.scheduleRead(connection: conn);
                        if !that.options.enableTcpFastOpen {
                            that.restartStream();
                        }
                    case .preparing:
                        that.state = .connecting;
                    case .cancelled, .setup:
                        that.state = .disconnected();
                        that.connection = nil;
                    case .failed(_):
                        that.logger.debug("\(that.userJid) - establishing connection to:\(that.server, privacy: .auto(mask: .hash)) timed out!");
                        if let lastConnectionDetails = that.currentEndpoint as? SocketConnectorNetwork.Endpoint {
                            that.options.dnsResolver.markAsInvalid(for: that.server, host: lastConnectionDetails.host, port: lastConnectionDetails.port, for: 15 * 60.0);
                        }
                        that.state = .disconnected(.timeout);
                        that.connection = nil;
                    case .waiting(_):
                        that.logger.debug("\(that.userJid) - no route to connect to:\(that.server, privacy: .auto(mask: .hash))!");
                        if let lastConnectionDetails = that.currentEndpoint as? SocketConnectorNetwork.Endpoint {
                            that.options.dnsResolver.markAsInvalid(for: that.server, host: lastConnectionDetails.host, port: lastConnectionDetails.port, for: 15 * 60.0);
                        }
                        that.state = .disconnected(.noRouteToServer);
                    default:
                        break;
                    }
                }
                
                conn.viabilityUpdateHandler = { [weak self] viable in
                    self?.logger.debug("connectivity is \(viable ? "UP" : "DOWN")")
                }
                
                conn.pathUpdateHandler = { [weak self] path in
                    self?.logger.debug("better path found \(path.debugDescription)")
                }
            }
        }
    }
    
    public required init(context: Context) {
        self.userJid = context.connectionConfiguration.userJid;
        self.options = context.connectionConfiguration.connectorOptions as! Options;

        super.init(context: context);
        
        for provider in options.networkProcessorProviders {
            for feature in provider.providedFeatures {
                self.availableFeatures.insert(feature)
            }
        }

        availableFeatures.insert(.ZLIB);
        
        networkStack.delegate = self;
    }
    
    public func prepareEndpoint(withResumptionLocation location: String?) -> ConnectorEndpoint? {
        guard let endpoint = self.currentEndpoint as? SocketConnectorNetwork.Endpoint, let (host, port) = SocketConnector.preprocessConnectionDetails(string: location) else {
            return nil;
        }
        return SocketConnectorNetwork.Endpoint(proto: endpoint.proto, host: host, port: port ?? endpoint.port);
    }
    
    public func prepareEndpoint(withSeeOtherHost seeOtherHost: String?) -> ConnectorEndpoint? {
        guard let endpoint = self.currentEndpoint as? SocketConnectorNetwork.Endpoint, let (host, port) = SocketConnector.preprocessConnectionDetails(string: seeOtherHost) else {
            return nil;
        }
        return SocketConnectorNetwork.Endpoint(proto: endpoint.proto, host: host, port: port ?? endpoint.port);
    }
    
    public func activate(feature: ConnectorFeature) {
        switch feature {
        case .TLS:
            self.serialize(.stanza(Stanza(element: Element(name: "starttls", xmlns: "urn:ietf:params:xml:ns:xmpp-tls"))), completion: .none);
        case .ZLIB:
            self.serialize(.stanza(Stanza(element: Element(name: "compress", xmlns: "http://jabber.org/protocol/compress", children: [Element(name: "method", cdata: "zlib")]))), completion: .none);
        default:
            break;
        }
    }
    
    public func reset() {
        queue.async {
            self.connection = nil;
        }
    }
    
    public func start(endpoint: ConnectorEndpoint?) {
        queue.sync {
            guard state == .disconnected() else {
                logger.log("start() - stopping connetion as state is not connecting \(self.state)");
                return;
            }
            
            state = .connecting;
            //            if let srvRecord = self.sessionLogic?.serverToConnectDetails() {
            //                self.connect(dnsName: srvRecord.target, srvRecord: srvRecord);
            //                return;
            //            } else {
            if let endpoint = endpoint as? SocketConnectorNetwork.Endpoint {
                self.connect(endpoint: endpoint);
            } else if let details = self.options.connectionDetails {
                self.connect(endpoint: details);
            } else {
                self.logger.debug("\(self.userJid) - connecting to server: \(self.server)");
                self.options.dnsResolver.resolve(domain: server, for: self.userJid) { result in
                    self.queue.async {
                        switch result {
                        case .success(let dnsResult):
                            if let record = dnsResult.record() {
                                self.connect(endpoint: SocketConnectorNetwork.Endpoint(proto: record.directTls ? .XMPPS : .XMPP, host: record.target, port: record.port));
                            } else {
                                self.connect(endpoint: SocketConnectorNetwork.Endpoint(proto: .XMPP, host: self.server, port: 5222));
                            }
                        case .failure(_):
                            self.connect(endpoint: SocketConnectorNetwork.Endpoint(proto: .XMPP, host: self.server, port: 5222));
                        }
                    }
                }
            }
        }
    }
    
    /**
     Should always be called from local dispatch queue!
     */
    private func connect(endpoint: SocketConnectorNetwork.Endpoint) -> Void {
        logger.debug("connecting to: \(endpoint)");
        guard state == .connecting else {
            logger.log("connect(addr) - stopping connetion as state is not connecting \(self.state)");
            return;
        }
        
        assert(connection == nil, "connection was not closed properly!");
        
        self.currentEndpoint = endpoint;
        
        let tcpOptions = NWProtocolTCP.Options();
        tcpOptions.noDelay = options.tcpNoDelay;
        tcpOptions.disableAckStretching = options.tcpDisableAckStretching;
        if options.enableTcpFastOpen {
            tcpOptions.enableFastOpen = true;
        }
        if let timeout = options.connectionTimeout {
            tcpOptions.connectionTimeout = Int(timeout);
        }
        logger.debug("default tcp keepalive settings idle: \(tcpOptions.keepaliveIdle), count: \(tcpOptions.keepaliveCount), interval: \(tcpOptions.keepaliveInterval), enabled: \(tcpOptions.enableKeepalive)")
        tcpOptions.keepaliveIdle = options.tcpKeepalive.idle;
        tcpOptions.keepaliveCount = options.tcpKeepalive.count;
        tcpOptions.keepaliveInterval = options.tcpKeepalive.interval;
        tcpOptions.enableKeepalive = options.tcpKeepalive.enable;
        logger.debug("set tcp keepalive settings idle: \(tcpOptions.keepaliveIdle), count: \(tcpOptions.keepaliveCount), interval: \(tcpOptions.keepaliveInterval), enabled: \(tcpOptions.enableKeepalive)")
        let parameters = NWParameters(tls: nil, tcp: tcpOptions);
        parameters.serviceClass = .responsiveData;
        if options.enableTcpFastOpen {
            parameters.allowFastOpen = true;
        }
        connection = NWConnection(host: .name(endpoint.host, nil), port: .init(integerLiteral: UInt16(endpoint.port)), using: parameters);
        // FIXME: reconnect happens before connection is actually closed!!
        networkStack.reset();
        activeFeatures.removeAll();
        if endpoint.proto == .XMPPS {
            self.initTLSStack();
        }
        
        
        if options.enableTcpFastOpen {
            self.streamEvents.send(.streamStart);
        } else {
            connection?.start(queue: self.queue);
        }
    }
    
    private func scheduleRead(connection conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096 * 2, completion: { [weak self] data, context, complete, error in
            guard let self, conn === self.connection else {
                return;
            }
            let state = conn.state;
            self.logger.debug("\(self.userJid), read data: \(data), complete: \(complete), error: \(error), \(state)")
            if let data = data {
                self.networkStack.read(data: data);
            }
            if complete {
                self.logger.debug("connection closed by the server")
                assert(conn === self.connection)
                conn.cancel();
            } else {
                self.scheduleRead(connection: conn);
            }
        })
    }
    
    public func stop(force: Bool, completionHandler: @escaping ()->Void) {
        queue.async {
            guard !force else {
                self.connection?.forceCancel();
                completionHandler();
                return;
            }
            switch self.state {
            case .disconnected(_), .disconnecting:
                self.logger.debug("\(self.userJid) - not connected or already disconnecting");
                completionHandler();
                return;
            case .connected:
                self.state = .disconnecting;
                self.logger.debug("\(self.userJid) - closing XMPP stream");
                
                //            self.streamEvents.send(.streamClose())
                // TODO: I'm not sure about that!!
                self.queue.async {
                    self.sendSync("</stream:stream>", completion: .written({ result in
                        self.connection?.cancel();
                        completionHandler();
                    }));
                }
            case .connecting:
                self.state = .disconnecting;
                self.logger.debug("\(self.userJid) - closing TCP connection");
                self.state = .disconnected(.timeout);
                self.connection?.cancel();
                completionHandler();
            }
        }
    }
    
    public func restartStream() {
        queue.async {
            self.initiateParser();
            self.streamEvents.send(.streamStart);
        }
    }
    
    private func initTLSStack() {
        guard let tlsProcessor = options.networkProcessorProviders.first(where: { $0.providedFeatures.contains(.TLS) })?.supply() else {
            self.state = .disconnected(.none);
            _ = self.stop(force: true);
            return;
        }
        if let sslProcessor = tlsProcessor as? SSLNetworkProcessor {
            sslProcessor.setALPNProtocols(["xmpp-client"]);
            sslProcessor.serverName = self.server;
            sslProcessor.certificateValidation = options.sslCertificateValidation;
            sslProcessor.certificateValidationFailed = { [weak self] trust in
                self?.networkStack.reset();
                if let trust = trust {
                    self?.state = .disconnected(.sslCertError(trust));
                } else {
                    self?.state = .disconnected(.none);
                }
                self?.connection?.cancel();

                return;
            }
        }
        networkStack.addProcessor(tlsProcessor);
        activeFeatures.insert(.TLS);
    }
    
    private func proceedTLS() {
        self.initTLSStack();
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
                self.reset();
                state = .disconnected(.streamError(packet.element));
            } else if packet.name == "proceed" && packet.xmlns == "urn:ietf:params:xml:ns:xmpp-tls" {
                proceedTLS();
            } else if packet.name == "compressed" && packet.xmlns == "http://jabber.org/protocol/compress" {
                proceedZlib();
            } else {
                streamEvents.send(event);
            }
        case .streamClose(let reason):
            guard state != .disconnected() else {
                return;
            }
            let conn = self.connection;
            sendSync("</stream:stream>",  completion: .written({ _ in
                assert(conn === self.connection)
                self.networkStack.reset();
                self.state = .disconnected(reason == .xmlError ? .xmlError(nil) : .none);
                self.connection?.cancel();
            }));
        default:
            streamEvents.send(event);
        }
    }
    
    private func sendSync(_ data:String, completion: WriteCompletion) {
        self.logger.debug("\(self.userJid) - sending stanza: \(data)");
        let buf = data.data(using: String.Encoding.utf8)!;
        self.networkStack.write(data: buf, completion: completion);
    }
    
    public override func serialize(_ event: StreamEvent, completion: WriteCompletion) {
        super.serialize(event, completion: completion);
        switch event {
        case .stanza(let stanza):
            self.sendSync(stanza.element.description, completion: completion);
        case .streamClose:
            self.sendSync("<stream:stream/>", completion: completion);
        case .streamOpen(let attributes):
            let attributesString = attributes.map({ "\($0.key)='\($0.value)' "}).joined();
            let openString = "<stream:stream \(attributesString) version='1.0' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>";
            self.sendSync(openString, completion: completion);
        default:
            break;
        }
    }
    
    public func send(_ data: StreamEvent, completion: WriteCompletion) {
        queue.async {
            guard self.state == .connected else {
                if self.options.enableTcpFastOpen, let connection = self.connection, connection.state == .setup {
                    self.serialize(data, completion: completion);
                    self.logger.debug("starting NWConnection...");
                    connection.start(queue: self.queue);
                }
                return;
            }
            self.serialize(data, completion: completion);
        }
    }
    
    public func read(data: Data) {
        super.read(data: data);
    }
    
    public func write(data: Data, completion: WriteCompletion) {
        let state = self.connection?.state;
        switch (state) {
        case .failed(_), .cancelled:
            completion.completed(result: .failure(NetworkError.connectionFailed))
        default:
            self.connection?.send(content: data, completion: completion.sendCompletion)
        }
    }

    public func channelBindingData(type: ChannelBinding) throws -> Data {
        guard let processor: SSLNetworkProcessor = networkStack.processor() else {
            throw XMPPError(condition: .feature_not_implemented);
        }
        return try processor.channelBindingData(type: type);
    }
    
    public struct Endpoint: ConnectorEndpoint, CustomStringConvertible, Equatable {
        
        public let proto: ConnectorProtocol;
        public let host: String;
        public let port: Int;
        
        public var description: String {
            return "\(proto.rawValue):\(host):\(port)";
        }
        
        public init(proto: ConnectorProtocol, host: String, port: Int) {
            self.proto = proto;
            self.host = host;
            self.port = port;
        }
        
    }
    
    public struct Options: ConnectorOptions {
        
        public var connector: Connector.Type {
            return SocketConnectorNetwork.self;
        }
        
        public var sslCertificateValidation: SSLCertificateValidation = .default;
        public var connectionDetails: SocketConnectorNetwork.Endpoint?;
        public var lastConnectionDetails: XMPPSrvRecord?;
        public var connectionTimeout: Double?;
        public var dnsResolver: DNSSrvResolver = XMPPDNSSrvResolver(directTlsEnabled: true);
        public var enableTcpFastOpen: Bool = true;
        public var tcpNoDelay: Bool = true;
        public var tcpDisableAckStretching: Bool = true;
        public var tcpKeepalive: TcpKeepalive = TcpKeepalive();

        public var networkProcessorProviders: [NetworkProcessorProvider] = []
        
        public init() {}
        
        public struct TcpKeepalive {
            public var enable: Bool = true;
            public var idle: Int = 60;
            public var count: Int = 3;
            public var interval: Int = 90;
        }
    }
}

extension WriteCompletion {
    
    public var sendCompletion: NWConnection.SendCompletion {
        switch self {
        case .none:
            return .idempotent;
        case .written(let callback):
            return .contentProcessed({ error in
                guard let err = error else {
                    callback(.success(Void()));
                    return;
                }
                callback(.failure(err));
            })
        }
    }
    
}
