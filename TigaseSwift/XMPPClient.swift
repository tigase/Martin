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

public class XMPPClient: Logger, EventHandler {
    
    public let sessionObject:SessionObject;
    public let connectionConfiguration:ConnectionConfiguration!;
    private var socketConnector:SocketConnector? {
        willSet {
            sessionLogic?.unbind();
        }
    }
    public let modulesManager:XmppModulesManager!;
    public let eventBus:EventBus = EventBus();
    public let context:Context!;
    private var sessionLogic:XmppSessionLogic?;
    private let responseManager:ResponseManager;
    
    public var state:SocketConnector.State {
        return sessionLogic?.state ?? socketConnector?.state ?? .disconnected;
    }
    
    public override init() {
        sessionObject = SessionObject(eventBus:self.eventBus);
        connectionConfiguration = ConnectionConfiguration(self.sessionObject);
        modulesManager = XmppModulesManager();
        context = Context(sessionObject: self.sessionObject, eventBus:eventBus, modulesManager: modulesManager);
        responseManager = ResponseManager(context: context);
        super.init()
        eventBus.register(self, events: SocketConnector.DisconnectedEvent.TYPE);
    }
    
    deinit {
        eventBus.unregister(self, events: SocketConnector.DisconnectedEvent.TYPE);
    }
    
    public func login() -> Void {
        guard state == SocketConnector.State.disconnected else {
            log("XMPP in state:", state, " - not starting connection");
            return;
        }
        log("starting connection......");
        socketConnector = SocketConnector(context: context);
        context.writer = SocketPacketWriter(connector: socketConnector!, responseManager: responseManager);
        sessionLogic = SocketSessionLogic(connector: socketConnector!, modulesManager: modulesManager, responseManager: responseManager, context: context);
        sessionLogic!.bind();
        modulesManager.initIfRequired();
        socketConnector?.start()
    }
    
    public func disconnect(force: Bool = false) -> Void {
        guard state == SocketConnector.State.connected || state == SocketConnector.State.connecting else {
            log("XMPP in state:", state, " - not stopping connection");
            return;
        }
        let oldSessionLogic = sessionLogic;
        sessionLogic = nil;
        if force {
            socketConnector?.forceStop();
        } else {
            socketConnector?.stop();
        }
        oldSessionLogic?.unbind();
        log("connection stopped......");
    }
    
    public func handleEvent(event: Event) {
        switch event {
        case let de as SocketConnector.DisconnectedEvent:
            if de.clean {
                context.sessionObject.clear();
            } else {
                context.sessionObject.clear(scopes: SessionObject.Scope.stream);
            }
        default:
            log("received unhandled event:", event);
        }
    }
    
    private class SocketPacketWriter: PacketWriter {
        
        let connector:SocketConnector;
        let responseManager:ResponseManager;
        
        init(connector:SocketConnector, responseManager:ResponseManager) {
            self.connector = connector;
            self.responseManager = responseManager;
        }
        
        override func write(stanza: Stanza, timeout: NSTimeInterval = 30, callback: (Stanza?) -> Void) {
            responseManager.registerResponseHandler(stanza, timeout: timeout, callback: callback);
            self.write(stanza);
        }
        
        override func write(stanza: Stanza, timeout: NSTimeInterval = 30, onSuccess: (Stanza) -> Void, onError: (Stanza,ErrorCondition?) -> Void, onTimeout: () -> Void) {
            responseManager.registerResponseHandler(stanza, timeout: timeout, onSuccess: onSuccess, onError: onError, onTimeout: onTimeout);
            self.write(stanza);
        }

        override func write(stanza: Stanza, timeout: NSTimeInterval = 30, callback: AsyncCallback) {
            responseManager.registerResponseHandler(stanza, timeout: timeout, callback: callback);
            self.write(stanza);
        }

        override func write(stanza: Stanza) {
            self.connector.send(stanza);
        }
        
    }
}