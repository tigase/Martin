//
// XMPPClient.swift
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
 This is main class for use as XMPP client.
 
 `login()` and `disconnect()` methods as many other works asynchronously.
 
 Changes of state or informations about receiving XML packets are
 provided using events.
 
 To create basic client you need to:
 1. create instance of this class
 2. register used XmppModules in `modulesManager`
 3. use `connectionConfiguration` to set credentials for XMPP account.
 
 # Example usage
 ```
 let userJid = BareJID("user@domain.com");
 let password = "Pa$$w0rd";
 let client = XMPPClient();
 
 // register modules
 client.modulesManager.register(AuthModule());
 client.modulesManager.register(StreamFeaturesModule());
 client.modulesManager.register(SaslModule());
 client.modulesManager.register(ResourceBinderModule());
 client.modulesManager.register(SessionEstablishmentModule());
 client.modulesManager.register(DiscoveryModule());
 client.modulesManager.register(SoftwareVersionModule());
 client.modulesManager.register(PingModule());
 client.modulesManager.register(RosterModule());
 client.modulesManager.register(PresenceModule());
 client.modulesManager.register(MessageModule());
 
 // configure connection
 client.connectionConfiguration.setUserJID(userJid);
 client.connectionConfiguration.setUserPassword(password);
 
 // create and register event handler
 class EventBusHandler: EventHandler {
    init() {
    }
 
    func handle(event: Event) {
        print("event bus handler got event = ", event);
        switch event {
        case is SessionEstablishmentModule.SessionEstablishmentSuccessEvent:
            print("successfully connected to server and authenticated!");
        case is RosterModule.ItemUpdatedEvent:
            print("roster item updated");
        case is PresenceModule.ContactPresenceChanged:
            print("received presence change event");
        case is MessageModule.ChatCreatedEvent:
            print("chat was created");
        case is MessageModule.MessageReceivedEvent:
            print("received message");
        default:
            // here will enter other events if this handler will be registered for any other events
            break;
        }
    }
 }

 let eventHandler = EventBusHandler();
 client.context.eventBus.register(eventHandler, for: SessionEstablishmentModule.SessionEstablishmentSuccessEvent.TYPE, RosterModule.ItemUpdatedEvent.TYPE, PresenceModule.ContactPresenceChanged.TYPE, MessageModule.MessageReceivedEvent.TYPE, MessageModule.ChatCreatedEvent.TYPE);
 
 // start XMPP connection to server
 client.login();
 
 // disconnect from server closing XMPP connection
 client.disconnect();
 ```
 
 */
open class XMPPClient: Context, EventHandler {
    
    private let logger = Logger(subsystem: "TigaseSwift", category: "XMPPClient");
    public var context:Context {
        return self;
    }
    var connector: Connector? {
        return sessionLogic?.connector;
    }
    private var sessionLogic:XmppSessionLogic? {
        willSet {
            sessionLogic?.streamLogger = nil;
        }
        didSet {
            sessionLogic?.streamLogger = streamLogger;
        }
    }
    private let responseManager:ResponseManager;
    
    fileprivate var keepaliveTimer: Timer?;
    open var keepaliveTimeout: TimeInterval = (3 * 60) - 5;
    
    open weak var streamLogger: StreamLogger? {
        didSet {
            sessionLogic?.streamLogger = streamLogger;
        }
    }
    
    open private(set) var state:SocketConnector.State = .disconnected;

    private var stateSubscription: Cancellable?;
    
    /// Internal processing queue
    fileprivate let dispatcher: QueueDispatcher;
    
    public convenience init() {
        self.init(eventBus: nil);
    }
    
    public init(eventBus: EventBus?) {
        dispatcher = QueueDispatcher(label: "xmpp_queue")
        responseManager = ResponseManager();
        super.init(eventBus: eventBus ?? EventBus(), modulesManager: XmppModulesManager());
        self.eventBus.register(handler: self, for: SocketConnector.DisconnectedEvent.TYPE);
    }
    
    deinit {
        stateSubscription?.cancel();
        eventBus.unregister(handler: self, for: SocketConnector.DisconnectedEvent.TYPE);
    }
    
    /**
     Method initiates modules if needed and starts process of connecting to XMPP server.
     */
    open func login(lastSeeOtherHost: XMPPSrvRecord? = nil) -> Void {
        guard state == SocketConnector.State.disconnected else {
            logger.debug("XMPP in state: \(self.state), - not starting connection");
            return;
        }
        logger.debug("starting connection......");
        dispatcher.sync {
            let socketConnector = SocketConnector(context: context);
            let sessionLogic: XmppSessionLogic = SocketSessionLogic(connector: socketConnector, responseManager: responseManager, context: context, queueDispatcher: dispatcher, seeOtherHost: lastSeeOtherHost);
            context.writer = SocketPacketWriter(sessionLogic: sessionLogic, responseManager: responseManager, queueDispatcher: dispatcher);
            self.sessionLogic = sessionLogic;
            sessionLogic.bind();
            sessionLogic.statePublisher.sink(receiveValue: { [weak self] newState in
                self?.state = newState;
            });
            
            keepaliveTimer?.cancel();
            if keepaliveTimeout > 0 {
                keepaliveTimer = Timer(delayInSeconds: keepaliveTimeout, repeats: true, callback: { self.keepalive() });
            } else {
                keepaliveTimer = nil;
            }
            sessionLogic.start();
        }
    }

    /**
     Method closes connection to server.
     
     - parameter force: If passed XMPP connection will be closed by closing only TCP connection which makes it possible to use [XEP-0198: Stream Management - Resumption] if available and was enabled.
     
     [XEP-0198: Stream Management - Resumption]: http://xmpp.org/extensions/xep-0198.html#resumption
     */
    open func disconnect(_ force: Bool = false, completionHandler: (()->Void)? = nil) -> Void {
        guard state == SocketConnector.State.connected || state == SocketConnector.State.connecting else {
            logger.debug("XMPP in state: \(self.state), - not stopping connection");
            return;
        }
        
        sessionLogic?.stop(force: force, completionHandler: completionHandler);
    }
    
    /**
     Sends whitespace to XMPP server to keep connection alive
     */
    open func keepalive() {
        guard state == .connected else {
            return;
        }
        sessionLogic?.keepalive();
    }
    
    /**
     Handles events fired by other classes used by this connection.
     */
    open func handle(event: Event) {
        switch event {
        case let de as SocketConnector.DisconnectedEvent:
            keepaliveTimer?.cancel();
            keepaliveTimer = nil;
            modulesManager.reset(scope: de.clean ? .session : .stream);
            if de.clean {
                context.sessionObject.clear();
            } else {
                context.sessionObject.clear(scopes: SessionObject.Scope.stream);
            }
            sessionLogic?.unbind();
            dispatcher.sync {
                stateSubscription?.cancel();
                stateSubscription = nil;
                self.state = .disconnected;
                sessionLogic = nil;
            }
            logger.debug("connection stopped......");
        default:
            logger.error("received unhandled event: \(event)");
        }
    }
    
    /**
     Implementation of `PacketWriter` protocol passed to `Context` instance
     */
    private class SocketPacketWriter: PacketWriter {
        
        let sessionLogic: XmppSessionLogic;
        let responseManager: ResponseManager;
        let dispatcher: QueueDispatcher;
        
        init(sessionLogic: XmppSessionLogic, responseManager: ResponseManager, queueDispatcher: QueueDispatcher) {
            self.sessionLogic = sessionLogic;
            self.responseManager = responseManager;
            self.dispatcher = queueDispatcher;
        }
          
        func write<Failure: Error>(_ iq: Iq, timeout: TimeInterval, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: ((Result<Iq, Failure>) -> Void)?) {
            responseManager.registerResponseHandler(for: iq, timeout: timeout, errorDecoder: errorDecoder, completionHandler: completionHandler);
            self.write(stanza: iq);
        }
        
        func write(_ stanza: Stanza, writeCompleted: ((Result<Void, XMPPError>) -> Void)?) {
            write(stanza: stanza);
            if writeCompleted != nil {
                dispatcher.async {
                    writeCompleted?(.success(Void()));
                }
            }
        }
        
        private func write(stanza: Stanza) {
            if stanza.name == "iq" && stanza.id == nil {
                stanza.id = UUID().uuidString;
            }
            dispatcher.async {
                self.sessionLogic.sendingOutgoingStanza(stanza);
            }
        }
    }
}
