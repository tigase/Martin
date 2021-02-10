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
    private let eventBus: EventBus;
    private let networkStack = SocketConnector.NetworkStack();

    private var connection: NWConnection?;
    
    public required init(context: Context) {
        self.userJid = context.connectionConfiguration.userJid;
        self.options = context.connectionConfiguration.connectorOptions as! Options;
        self.eventBus = context.eventBus;

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
            let timeout: Double? = self.options.conntectionTimeout;
            state = .connecting;
            //            if let srvRecord = self.sessionLogic?.serverToConnectDetails() {
            //                self.connect(dnsName: srvRecord.target, srvRecord: srvRecord);
            //                return;
            //            } else {
            if let endpoint = endpoint as? SocketConnectorNetwork.Endpoint {
                self.connect(endpoint: endpoint);
            } else if let details = self.options.connectionDetails as? SocketConnectorNetwork.Endpoint {
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
        
        connection = NWConnection(host: .name(endpoint.host, nil), port: .init(integerLiteral: UInt16(endpoint.port)), using: NWParameters(tls: nil));
        
        if endpoint.proto == .XMPPS {
            guard let tlsProcessor = options.networkProcessorProviders.first(where: { $0.providedFeatures.contains(.TLS) })?.supply() else {
                self.state = .disconnected(.none);
                return;
            }
            
            networkStack.addProcessor(tlsProcessor);
            activeFeatures.insert(.TLS);
        }
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.state = .connected;
                self?.initiateParser();
                self?.scheduleRead();
                self?.restartStream();
            case .preparing:
                self?.state = .connecting;
            case .cancelled, .setup:
                self?.state = .disconnected();
            case .failed(_):
                self?.state = .disconnected(.timeout);
            case .waiting(_):
                break;
            default:
                break;
            }
        }
        
        connection?.start(queue: self.queue.queue);
    }
    
    private func scheduleRead() {
        self.connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096, completion: { data, context, complete, error in
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
    
    private func proceedTLS() {
        guard let tlsProcessor = options.networkProcessorProviders.first(where: { $0.providedFeatures.contains(.TLS) })?.supply() else {
            self.state = .disconnected(.none);
            return;
        }
        
        networkStack.addProcessor(tlsProcessor);
        activeFeatures.insert(.TLS);

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
            state = .disconnecting;
            sendSync("</stream:stream>",  completion: .written({ _ in
                self.connection?.cancel();
                self.networkStack.reset();
                self.state = .disconnected(reason == .xmlError ? .xmlError(nil) : .none);
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
        
        init(proto: ConnectorProtocol, host: String, port: Int) {
            self.proto = proto;
            self.host = host;
            self.port = port;
        }
        
    }
    
    public struct Options: ConnectorOptions {
        
        public var connector: Connector.Type {
            return SocketConnectorNetwork.self;
        }
        
//        public var sslCertificateValidation: SSLCertificateValidation = .default;
        public var connectionDetails: SocketConnectorNetwork.Endpoint?;
        public var lastConnectionDetails: XMPPSrvRecord?;
        public var conntectionTimeout: Double?;
        public var dnsResolver: DNSSrvResolver = XMPPDNSSrvResolver();

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
