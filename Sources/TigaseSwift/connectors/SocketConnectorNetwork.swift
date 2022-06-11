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

/**
 Implementation of a C2S XMPP connector based on the `Network.framework` (requires custom SSL/TLS implementation)
 */
open class SocketConnectorNetwork: XMPPConnectorBase, Connector, NetworkDelegate {
    
    public class var supportedProtocols: [ConnectorProtocol] {
        return [ConnectorProtocol.XMPP, ConnectorProtocol.XMPPS];
    }
    
    /// Internal processing queue
    private let queue: QueueDispatcher = QueueDispatcher(label: "xmpp_socket_queue");
    
    private let userJid: BareJID;
    private var server: String {
        return userJid.domain;
    }
    public private(set) var currentEndpoint: ConnectorEndpoint?;
    
    private let options: Options;
    private let networkStack = SocketConnector.NetworkStack();

    private var connection: NWConnection?;
    
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
            self.serialize(.stanza(Stanza(elem: Element(name: "starttls", xmlns: "urn:ietf:params:xml:ns:xmpp-tls"))), completion: .none);
        case .ZLIB:
            self.serialize(.stanza(Stanza(elem: Element(name: "compress", xmlns: "http://jabber.org/protocol/compress", children: [Element(name: "method", cdata: "zlib")]))), completion: .none);
        default:
            break;
        }
    }
    
    public func start(endpoint: ConnectorEndpoint?) {
        queue.sync {
            guard state == .disconnected() else {
                logger.log("start() - stopping connetion as state is not connecting \(self.state)");
                return;
            }
            
            let start = Date();
            let timeout: Double? = self.options.connectionTimeout;
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
    
    /**
     Should always be called from local dispatch queue!
     */
    private func connect(endpoint: SocketConnectorNetwork.Endpoint) -> Void {
        logger.debug("connecting to: \(endpoint)");
        guard state == .connecting else {
            logger.log("connect(addr) - stopping connetion as state is not connecting \(self.state)");
            return;
        }
        
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
        let parameters = NWParameters(tls: nil, tcp: tcpOptions);
        parameters.serviceClass = .responsiveData;
        if options.enableTcpFastOpen {
            parameters.allowFastOpen = true;
        }
        connection = NWConnection(host: .name(endpoint.host, nil), port: .init(integerLiteral: UInt16(endpoint.port)), using: parameters);
        
        if endpoint.proto == .XMPPS {
            self.initTLSStack();
        }
                        
        let conn = connection;
        connection?.stateUpdateHandler = { [weak self] state in
            guard let that = self else {
                return;
            }
            that.logger.debug("\(that.userJid) - changed state to: \(state) for endpoint: \(that.connection?.currentPath?.localEndpoint)")
            switch state {
            case .ready:
                that.state = .connected;
                that.initiateParser();
                that.scheduleRead();
                if !that.options.enableTcpFastOpen {
                    that.restartStream();
                }
            case .preparing:
                that.state = .connecting;
            case .cancelled, .setup:
                if let currConn = that.connection, conn === currConn {
                    that.state = .disconnected();
                }
            case .failed(_):
                that.connection?.cancel();
                that.logger.debug("\(that.userJid) - establishing connection to:\(that.server, privacy: .auto(mask: .hash)) timed out!");
                if let lastConnectionDetails = that.currentEndpoint as? SocketConnectorNetwork.Endpoint {
                    that.options.dnsResolver.markAsInvalid(for: that.server, host: lastConnectionDetails.host, port: lastConnectionDetails.port, for: 15 * 60.0);
                }
                that.state = .disconnected(.timeout);
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
        
        connection?.viabilityUpdateHandler = { viable in
            print("connectivity is \(viable ? "UP" : "DOWN")")
        }
        
        connection?.pathUpdateHandler = { path in
            print("better path found " + path.debugDescription)
        }
        
        if options.enableTcpFastOpen {
            self.streamEvents.send(.streamStart);
        } else {
            connection?.start(queue: self.queue.queue);
        }
    }
    
    private func scheduleRead() {
        self.connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096 * 2, completion: { data, context, complete, error in
            if let data = data {
                self.networkStack.read(data: data);
                self.scheduleRead();
            }
        })
    }
    
    public func stop(force: Bool) -> Future<Void, Never> {
        return Future({ promise in
            guard !force else {
                self.connection?.forceCancel();
                promise(.success(Void()));
                return;
            }
            switch self.state {
            case .disconnected(_), .disconnecting:
                self.logger.debug("\(self.userJid) - not connected or already disconnecting");
                promise(.success(Void()));
                return;
            case .connected:
                self.state = .disconnecting;
                self.logger.debug("\(self.userJid) - closing XMPP stream");
                
    //            self.streamEvents.send(.streamClose())
                // TODO: I'm not sure about that!!
                self.queue.async {
                    self.sendSync("</stream:stream>", completion: .written({ result in
                        self.connection?.cancel();
                        promise(.success(Void()));
                    }));
                }
            case .connecting:
                self.state = .disconnecting;
                self.logger.debug("\(self.userJid) - closing TCP connection");
                self.state = .disconnected(.timeout);
                self.connection?.cancel();
                promise(.success(Void()));
            }
        })
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
                state = .disconnected(.streamError(packet.element));
            } else if packet.name == "proceed" && packet.xmlns == "urn:ietf:params:xml:ns:xmpp-tls" {
                proceedTLS();
            } else if packet.name == "compressed" && packet.xmlns == "http://jabber.org/protocol/compress" {
                proceedZlib();
            } else {
                streamEvents.send(event);
            }
        case .streamClose(let reason):
            if (state != .disconnected()) {
                state = .disconnecting;
            }
            sendSync("</stream:stream>",  completion: .written({ _ in
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
            self.sendSync(stanza.element.stringValue, completion: completion);
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
                    connection.start(queue: self.queue.queue);
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
        self.connection?.send(content: data, completion: completion.sendCompletion)
    }

    public struct Endpoint: ConnectorEndpoint, CustomStringConvertible {
        
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

        public var networkProcessorProviders: [NetworkProcessorProvider] = []
        
        public init() {}
        
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
