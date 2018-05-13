//
// InBandRegistrationModule.swift
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
 Module provides support for [XEP-0077: In-Band Registration]
 
 For easier usage we suggest to use convenience function `connectAndRegister(..)`
 
 [XEP-0077: In-Band Registration]: http://xmpp.org/extensions/xep-0077.html
 */
open class InBandRegistrationModule: AbstractIQModule, ContextAware {
    /// ID of module for lookup in `XmppModulesManager`
    open static let ID = "InBandRegistrationModule";
    
    open let id = ID;
    
    open var context: Context!;
    open let features = [String]();
    open let criteria = Criteria.empty();
    
    public init() {
        
    }
    
    open func processGet(stanza: Stanza) throws {
        throw ErrorCondition.not_allowed;
    }
    
    open func processSet(stanza: Stanza) throws {
        throw ErrorCondition.not_allowed;
    }
    
    /** 
     Sends registration request
     - parameter jid: destination JID for registration - useful for registration in transports
     - parameter username: username to register
     - parameter password: password for username
     - parameter email: email for registration
     - parameter callback: called on registration response
     */
    open func register(_ jid: JID? = nil, username: String?, password: String?, email: String?, callback: @escaping (Stanza?)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = jid ?? JID(ResourceBinderModule.getBindedJid(context.sessionObject)?.domain ?? context.sessionObject.domainName!);
        
        let query = Element(name: "query", xmlns: "jabber:iq:register");
        if username != nil && !username!.isEmpty {
            query.addChild(Element(name: "username", cdata: username!));
        }
        if password != nil && !password!.isEmpty {
            query.addChild(Element(name: "password", cdata: password!));
        }
        if email != nil && !email!.isEmpty {
            query.addChild(Element(name: "email", cdata: email!));
        }
        iq.addChild(query);
        
        context.writer?.write(iq, callback: callback);
    }
    
    /**
     Retrieves registration form and call provided callback
     - parameter from: destination JID for registration - useful for registration in transports
     - parameter onSuccess: called when form is retrieved. First parameter determine if server supports registration using Data Forms and second parameter provides list of fields to pass.
     - parameter onError: called when server returned error
     */
    open func retrieveRegistrationForm(from jid: JID? = nil, onSuccess: @escaping (Bool, JabberDataElement)->Void, onError: @escaping (ErrorCondition?, String?)->Void) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = jid ?? JID(ResourceBinderModule.getBindedJid(context.sessionObject)?.domain ?? context.sessionObject.domainName!);
    
        let query = Element(name: "query", xmlns: "jabber:iq:register");
        
        iq.addChild(query);
        context.writer?.write(iq, callback: {(response) in
            let type = response?.type ?? .error;
            switch type {
            case .result:
                if let form = JabberDataElement(from: response?.findChild(name: "query", xmlns: "jabber:iq:register")?.findChild(name: "x", xmlns: "jabber:x:data")) {
                    onSuccess(true, form);
                } else {
                    let form = JabberDataElement(type: .form);
                    if let query = response?.findChild(name: "query", xmlns: "jabber:iq:register") {
                        if let instructions = query.findChild(name: "instructions")?.value {
                            form.instructions = [instructions];
                        }
                        if query.findChild(name: "username") != nil {
                            form.addField(TextSingleField(name: "username", required: true));
                        }
                        if query.findChild(name: "password") != nil {
                            form.addField(TextPrivateField(name: "password", required: true));
                        }
                        if query.findChild(name: "email") != nil {
                            form.addField(TextSingleField(name: "email", required: true));
                        }
                    }
                    onSuccess(false, form);
                }
            default:
                onError(response?.errorCondition, response?.findChild(name: "error")?.findChild(name: "text")?.value);
            }
        });
    }
    
    open func submitRegistrationForm(to jid: JID? = nil, form: JabberDataElement, onSuccess: @escaping ()->Void, onError: @escaping (ErrorCondition?, String?)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = jid ?? JID(ResourceBinderModule.getBindedJid(context.sessionObject)?.domain ?? context.sessionObject.domainName!);
        
        let query = Element(name: "query", xmlns: "jabber:iq:register");
        query.addChild(form.submitableElement(type: .submit));
        
        iq.addChild(query);
        context.writer?.write(iq, callback: {(response) in
            let type = response?.type ?? .error;
            switch type {
            case .result:
                onSuccess();
            default:
                onError(response?.errorCondition, response?.findChild(name: "error")?.findChild(name: "text")?.value);
            }
        });
    }
    
    /**
     Unregisters currently connected and authenticated user
     - parameter callback: called when user is unregistrated
     */
    open func unregister(_ callback: @escaping (Stanza?)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = ResourceBinderModule.getBindedJid(context.sessionObject);
        
        let query = Element(name: "query", xmlns: "jabber:iq:register");
        query.addChild(Element(name: "remove"));
        iq.addChild(query);
        
        context.writer?.write(iq, callback: callback);
    }
    
    /**
     Check if server supports in-band registration
     - returns: true - if in-band registration is supported
     */
    open func isRegistrationAvailable() -> Bool {
        let featuresElement = StreamFeaturesModule.getStreamFeatures(context.sessionObject);
        return InBandRegistrationModule.isRegistrationAvailable(featuresElement);
    }
    
    open static func isRegistrationAvailable(_ featuresElement: Element?) -> Bool {
        return featuresElement?.findChild(name: "register", xmlns: "http://jabber.org/features/iq-register") != nil;
    }
    
    /**
     Convenience function for registration process.
     
     This function may use passed not authorized instance of `XMPPClient` 
     or will create new one if nil is passed.
     
     Function will return immediately, however registration process will 
     finish when one of callbacks is called.
     
     - parameter client: instance of XMPPClient to use
     - parameter userJid: user jid to register
     - parameter password: password
     - parameter email: email
     - parameter onSuccess: called after sucessful registration
     - parameter onError: called on error or due to timeout
     */
    public static func connectAndRegister(client: XMPPClient! = nil, userJid: BareJID, password: String?, email: String?, onSuccess: @escaping ()->Void, onError: @escaping (ErrorCondition?)->Void) -> XMPPClient {
        var client = client
        if client == nil {
            client = XMPPClient();
        }
        
        _ = client?.modulesManager.register(StreamFeaturesModule());
        _ = client!.modulesManager.register(InBandRegistrationModule());
        
        client?.connectionConfiguration.setDomain(client!.sessionObject.domainName ?? userJid.domain);
        
        let handler = RegistrationEventHandlerOld(client: client!);
        handler.userJid = userJid;
        handler.password = password;
        handler.email = email;
        handler.onSuccess = onSuccess;
        handler.onError = onError;
        
        client?.login();
        
        return client!;
    }
    
    class RegistrationEventHandlerOld: EventHandler {
        
        var client: XMPPClient! {
            willSet {
                if newValue == nil {
                    let curr = self.client;
                    self.unregisterEvents(curr!);
                    DispatchQueue.main.async {
                        curr?.disconnect();
                    }
                }
            }
        }
        var context: Context! {
            return client.context;
        }
        var userJid: BareJID!;
        var password: String?;
        var email: String?;
        var onSuccess: (() -> Void)?;
        var onError: ((ErrorCondition?) -> Void)?;
        
        init(client: XMPPClient) {
            self.client = client;
            registerEvents(client);
        }
        
        func registerEvents(_ client: XMPPClient) {
            client.eventBus.register(handler: self, for: StreamFeaturesReceivedEvent.TYPE, SocketConnector.DisconnectedEvent.TYPE);
        }
        
        func unregisterEvents(_ client: XMPPClient) {
            client.eventBus.unregister(handler: self, for: StreamFeaturesReceivedEvent.TYPE, SocketConnector.DisconnectedEvent.TYPE);
        }
        
        public func handle(event: Event) {
            switch event {
            case is StreamFeaturesReceivedEvent:
                // check registration possibility
                let startTlsActive = context.sessionObject.getProperty(SessionObject.STARTTLS_ACTIVE, defValue: false);
                let compressionActive = context.sessionObject.getProperty(SessionObject.COMPRESSION_ACTIVE, defValue: false);
                let featuresElement = StreamFeaturesModule.getStreamFeatures(context.sessionObject);
                
                guard startTlsActive || context.sessionObject.getProperty(SessionObject.STARTTLS_DISLABLED, defValue: false) || ((featuresElement?.findChild(name: "starttls", xmlns: "urn:ietf:params:xml:ns:xmpp-tls")) == nil) else {
                    return;
                }
                
                guard compressionActive || context.sessionObject.getProperty(SessionObject.COMPRESSION_DISABLED, defValue: false) || ((featuresElement?.getChildren(name: "compression", xmlns: "http://jabber.org/features/compress").index(where: {(e) in e.findChild(name: "method")?.value == "zlib" })) == nil) else {
                    return;
                }
                
                guard InBandRegistrationModule.isRegistrationAvailable(featuresElement) else {
                    self.onSuccess = nil;
                    self.client = nil;
                    self.onError?(ErrorCondition.feature_not_implemented);
                    return;
                }
                
                let regModule: InBandRegistrationModule = context.modulesManager.getModule(InBandRegistrationModule.ID)!;
                regModule.register(username: userJid.localPart, password: password, email: email, callback: { (stanza) in
                    var errorCondition:ErrorCondition?;
                    if let type = stanza?.type {
                        switch type {
                        case .result:
                            self.onError = nil;
                            self.client = nil;
                            self.onSuccess?();
                            return;
                        default:
                            if let name = stanza!.element.findChild(name: "error")?.firstChild()?.name {
                                errorCondition = ErrorCondition(rawValue: name);
                            }
                        }
                    }
                    self.onSuccess = nil;
                    self.client = nil;
                    self.onError?(errorCondition);
                });
            case is SocketConnector.DisconnectedEvent:
                onSuccess = nil;
                self.client = nil;
                onError?(ErrorCondition.service_unavailable);
            default:
                break;
            }
        }
        
    }
    
    open class AccountRegistrationTask: EventHandler {
        
        var client: XMPPClient! {
            willSet {
                if newValue == nil && self.client != nil {
                    let curr = self.client;
                    client.eventBus.unregister(handler: self, for: StreamFeaturesReceivedEvent.TYPE, SocketConnector.DisconnectedEvent.TYPE, SocketConnector.CertificateErrorEvent.TYPE);
                    DispatchQueue.main.async {
                        curr?.disconnect();
                    }
                }
            }
            didSet {
                if client != nil {
                    client.eventBus.register(handler: self, for: StreamFeaturesReceivedEvent.TYPE, SocketConnector.DisconnectedEvent.TYPE, SocketConnector.CertificateErrorEvent.TYPE);
                }
            }
        };
        var inBandRegistrationModule: InBandRegistrationModule!;
        var onForm: ((JabberDataElement, AccountRegistrationTask)->Void)?;
        var onSuccess: (()->Void)?;
        var onError: ((ErrorCondition?, String?)->Void)?;
        var onCertificateValidationError: ((SslCertificateInfo, @escaping ()->Void)->Void)?;
        
        var usesDataForm = false;
        var formToSubmit: JabberDataElement?;
        var serverAvailable: Bool = false;
        
        var acceptedCertificate: SslCertificateInfo? = nil;
        
        public init(client: XMPPClient? = nil, domainName: String, onForm: @escaping (JabberDataElement, InBandRegistrationModule.AccountRegistrationTask)->Void, onSuccess: @escaping ()->Void, onError: @escaping (ErrorCondition?, String?)->Void, sslCertificateValidator: ((SessionObject,SecTrust)->Bool)? = nil, onCertificateValidationError: ((SslCertificateInfo, @escaping ()->Void)->Void)? = nil) {
            self.setClient(client: client ?? XMPPClient());
            self.onForm = onForm;
            self.onSuccess = onSuccess;
            self.onError = onError;
            
            _ = self.client?.modulesManager.register(StreamFeaturesModule());
            self.inBandRegistrationModule = self.client!.modulesManager.register(InBandRegistrationModule());
            
            self.client?.connectionConfiguration.setDomain(self.client!.sessionObject.domainName ?? domainName);
            self.client?.sessionObject.setUserProperty(SocketConnector.SSL_CERTIFICATE_VALIDATOR, value: sslCertificateValidator);
            self.onCertificateValidationError = onCertificateValidationError;
            self.client?.login();
        }
        
        open func submit(form: JabberDataElement) {
            formToSubmit = form;
            guard (client?.state ?? .disconnected) != .disconnected else {
                client?.login();
                return;
            }
            if (usesDataForm) {
                inBandRegistrationModule.submitRegistrationForm(form: form, onSuccess: {
                    let callback = self.onSuccess!;
                    self.finish();
                    callback();
                }, onError: self.onErrorFn);
            } else {
                let username = (form.getField(named: "username") as? TextSingleField)?.value;
                let password = (form.getField(named: "password") as? TextPrivateField)?.value;
                let email = (form.getField(named: "email") as? TextSingleField)?.value;
                inBandRegistrationModule.register(username: username, password: password, email: email, callback: { (response) in
                    let type = response?.type ?? .error;
                    switch (type) {
                    case .result:
                        let callback = self.onSuccess!;
                        self.finish();
                        callback();
                    default:
                        self.onErrorFn(errorCondition: response?.errorCondition, message: response?.findChild(name: "error")?.findChild(name: "text")?.value);
                    }
                })
            }
        }
        
        open func cancel() {
            self.client?.disconnect();
            self.finish();
        }
        
        public func handle(event: Event) {
            switch event {
            case let e as SocketConnector.CertificateErrorEvent:
                if self.onCertificateValidationError != nil {
                    let certData = SslCertificateInfo(trust: e.trust!);
                    self.serverAvailable = true;
                    self.onCertificateValidationError!(certData, {() -> Void in
                        SslCertificateValidator.setAcceptedSslCertificate(self.client.sessionObject, fingerprint: certData.details.fingerprintSha1);
                        self.acceptedCertificate = certData;
                        self.serverAvailable = false;
                        self.client.login();
                    });
                }

            case is StreamFeaturesReceivedEvent:
                serverAvailable = true;
                // check registration possibility
                guard isStreamReady() else {
                    return;
                }
                let featuresElement = StreamFeaturesModule.getStreamFeatures(client.sessionObject);
                guard InBandRegistrationModule.isRegistrationAvailable(featuresElement) else {
                    onErrorFn(errorCondition: ErrorCondition.feature_not_implemented, message: nil);
                    return;
                }
                
                inBandRegistrationModule.retrieveRegistrationForm(onSuccess: {(usesDataForm, serverForm) in
                    self.usesDataForm = usesDataForm;
                    let form = serverForm;
                    if self.formToSubmit == nil {
                        self.onForm?(form, self);
                    } else {
                        var sameForm = true;
                        var labelsChanged = false;
                        form.fieldNames.forEach({(name) in
                            let newField = form.getField(named: name);
                            let oldField = self.formToSubmit!.getField(named: name);
                            if newField != nil && oldField != nil {
                                labelsChanged = newField?.label != oldField?.label;
                                if labelsChanged {
                                    oldField?.label = newField?.label;
                                    oldField?.element.removeChildren(where: { (el) -> Bool in
                                        el.name == "value";
                                    })
                                }
                            } else {
                                sameForm = false;
                            }
                        });
                        DispatchQueue.global().async {
                            if (!sameForm) {
                                self.onForm?(form, self);
                            } else if (labelsChanged) {
                                self.onForm?(self.formToSubmit!, self);
                            } else {
                                self.submit(form: self.formToSubmit!);
                            }
                            self.formToSubmit = nil;
                        }
                    }
                }, onError: self.onErrorFn);
            case is SocketConnector.DisconnectedEvent:
                if !serverAvailable {
                    onErrorFn(errorCondition: ErrorCondition.service_unavailable, message: nil);
                }
            default:
                break;
            }
        }
        
        public func getAcceptedCertificate() -> SslCertificateInfo? {
            return acceptedCertificate;
        }
        
        fileprivate func setClient(client: XMPPClient) {
            self.client = client;
        }
        
        fileprivate func onErrorFn(errorCondition: ErrorCondition?, message: String?) -> Void {
            let callback = self.onError
            if (callback != nil) {
                callback!(errorCondition, message);
            } else {
                self.finish();
            }
        }
        
        fileprivate func isStreamReady() -> Bool {
            let startTlsActive = client.sessionObject.getProperty(SessionObject.STARTTLS_ACTIVE, defValue: false);
            let compressionActive = client.sessionObject.getProperty(SessionObject.COMPRESSION_ACTIVE, defValue: false);
            let featuresElement = StreamFeaturesModule.getStreamFeatures(client.sessionObject);
            
            guard startTlsActive || client.sessionObject.getProperty(SessionObject.STARTTLS_DISLABLED, defValue: false) || ((featuresElement?.findChild(name: "starttls", xmlns: "urn:ietf:params:xml:ns:xmpp-tls")) == nil) else {
                return false;
            }
            
            guard compressionActive || client.sessionObject.getProperty(SessionObject.COMPRESSION_DISABLED, defValue: false) || ((featuresElement?.getChildren(name: "compression", xmlns: "http://jabber.org/features/compress").index(where: {(e) in e.findChild(name: "method")?.value == "zlib" })) == nil) else {
                return false;
            }
            return true;
        }
        
        fileprivate func finish() {
            client = nil;
            inBandRegistrationModule = nil;
            onForm = nil;
            onSuccess = nil;
            onError = nil;
        }
        
    }
    
}
