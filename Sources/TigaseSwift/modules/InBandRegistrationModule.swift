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

extension XmppModuleIdentifier {
    public static var inBandRegistration: XmppModuleIdentifier<InBandRegistrationModule> {
        return InBandRegistrationModule.IDENTIFIER;
    }
}

/**
 Module provides support for [XEP-0077: In-Band Registration]
 
 For easier usage we suggest to use convenience function `connectAndRegister(..)`
 
 [XEP-0077: In-Band Registration]: http://xmpp.org/extensions/xep-0077.html
 */
open class InBandRegistrationModule: AbstractIQModule, ContextAware {
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "InBandRegistrationModule";
    public static let IDENTIFIER = XmppModuleIdentifier<InBandRegistrationModule>();
    
    open var context: Context!;
    public let features = [String]();
    public let criteria = Criteria.empty();
    
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
        iq.to = jid ?? JID(ResourceBinderModule.getBindedJid(context.sessionObject)?.domain ?? context.userBareJid.domain);
        
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
        self.retrieveRegistrationForm(from: jid, completionHandler: { result in
            switch result {
            case .success(let type, let form, _):
                onSuccess(type == .plain, form);
            case .failure(let errorCondition, let errorText):
                onError(errorCondition, errorText);
            }
        })
    }
    
    open func retrieveRegistrationForm(from jid: JID? = nil, completionHandler: @escaping (RetrieveFormResult)->Void) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = jid ?? JID(ResourceBinderModule.getBindedJid(context.sessionObject)?.domain ?? context.userBareJid.domain);
    
        let query = Element(name: "query", xmlns: "jabber:iq:register");
        
        iq.addChild(query);
        context.writer?.write(iq, callback: {(response) in
            let type = response?.type ?? .error;
            switch type {
            case .result:
                if let query = response?.findChild(name: "query", xmlns: "jabber:iq:register"), let form = JabberDataElement(from: query.findChild(name: "x", xmlns: "jabber:x:data")) {
                    completionHandler(.success(type: .dataForm, form: form, bob: query.mapChildren(transform: BobData.init(from: ))));
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
                    completionHandler(.success(type: .plain, form: form, bob: []));
                }
            default:
                completionHandler(.failure(errorCondition: response?.errorCondition ?? ErrorCondition.remote_server_timeout, errorText: response?.findChild(name: "error")?.findChild(name: "text")?.value));
            }
        });
    }
    
    open func submitRegistrationForm(to jid: JID? = nil, form: JabberDataElement, onSuccess: @escaping ()->Void, onError: @escaping (ErrorCondition?, String?)->Void) {
        submitRegistrationForm(to: jid, form: form, completionHandler: { result in
            switch result {
            case .success(_):
                onSuccess();
            case .failure(let errorCondition, let errorText):
                onError(errorCondition, errorText);
            }
        })
    }
    
    open func submitRegistrationForm(to jid: JID? = nil, form: JabberDataElement, completionHandler: @escaping (AsyncResult<String>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = jid ?? JID(ResourceBinderModule.getBindedJid(context.sessionObject)?.domain ?? context.userBareJid.domain);
        
        let query = Element(name: "query", xmlns: "jabber:iq:register");
        query.addChild(form.submitableElement(type: .submit));
        
        iq.addChild(query);
        context.writer?.write(iq, callback: {(response) in
            let type = response?.type ?? .error;
            switch type {
            case .result:
                completionHandler(.success(response: ""));
            default:
                completionHandler(.failure(errorCondition: response?.errorCondition ?? ErrorCondition.remote_server_timeout, response: response?.findChild(name: "error")?.findChild(name: "text")?.value ?? nil));
            }
        });
    }
    
    /**
     Unregisters currently connected and authenticated user
     - parameter callback: called when user is unregistrated
     */
    open func unregister(from: JID? = nil, _ callback: @escaping (Stanza?)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = from ?? ResourceBinderModule.getBindedJid(context.sessionObject);
        
        let query = Element(name: "query", xmlns: "jabber:iq:register");
        query.addChild(Element(name: "remove"));
        iq.addChild(query);
        
        context.writer?.write(iq, callback: callback);
    }
    
    open func unregister(from: JID? = nil, onSuccess: @escaping ()->Void, onError: @escaping (ErrorCondition?,String?)->Void) {
        unregister(from: from) { (response) in
            let type = response?.type ?? .error;
            switch type {
            case .result:
                onSuccess();
            default:
                onError(response?.errorCondition, response?.findChild(name: "error")?.findChild(name: "text")?.value);
            }
        }
    }
    
    open func changePassword(for serviceJid: JID? = nil, newPassword: String, completionHandler: @escaping (Result<String, ErrorCondition>)->Void) {
        changePassword(for: serviceJid, newPassword: newPassword, callback: { (response) in
            let type = response?.type ?? .error;
            switch type {
            case .result:
                completionHandler(.success(newPassword));
            default:
                completionHandler(.failure(response?.errorCondition ?? ErrorCondition.remote_server_timeout));
            }
        });
    }
    
    open func changePassword(for serviceJid: JID? = nil, newPassword: String, callback: @escaping (Stanza?)->Void) {
        guard let username = self.context.userBareJid.localPart else {
            return;
        }
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = serviceJid ?? ResourceBinderModule.getBindedJid(context.sessionObject);
        
        let query = Element(name: "query", xmlns: "jabber:iq:register");
        query.addChild(Element(name: "username", cdata: username));
        query.addChild(Element(name: "password", cdata: newPassword));
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
    
    public static func isRegistrationAvailable(_ featuresElement: Element?) -> Bool {
        return featuresElement?.findChild(name: "register", xmlns: "http://jabber.org/features/iq-register") != nil;
    }
    
    open class AccountRegistrationTask: EventHandler {
        
        public private(set) var client: XMPPClient! {
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
        var onForm: ((JabberDataElement, [BobData], AccountRegistrationTask)->Void)?;
        var completionHandler: ((RegistrationResult)->Void)?;
        var onCertificateValidationError: ((SslCertificateInfo, @escaping ()->Void)->Void)?;
        
        var usesDataForm = false;
        var formToSubmit: JabberDataElement?;
        var serverAvailable: Bool = false;
        
        var acceptedCertificate: SslCertificateInfo? = nil;
        
        public init(client: XMPPClient? = nil, domainName: String, preauth: String? = nil, onForm: @escaping (JabberDataElement, [BobData], InBandRegistrationModule.AccountRegistrationTask)->Void, sslCertificateValidator: ((SecTrust)->Bool)? = nil, onCertificateValidationError: ((SslCertificateInfo, @escaping ()->Void)->Void)? = nil, completionHandler: @escaping (RegistrationResult)->Void) {
            self.setClient(client: client ?? XMPPClient());
            self.onForm = onForm;
            self.completionHandler = completionHandler;
            
            _ = self.client?.modulesManager.register(StreamFeaturesModule());
            self.inBandRegistrationModule = self.client!.modulesManager.register(InBandRegistrationModule());
            self.preauthToken = preauth;
            
            self.client?.connectionConfiguration.userJid = BareJID(domainName);
            self.client.connectionConfiguration.sslCertificateValidation = sslCertificateValidator == nil ? .default : .customValidator(sslCertificateValidator!);
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
                inBandRegistrationModule.submitRegistrationForm(form: form, completionHandler: { result in
                    switch result {
                    case .success(_):
                        let callback = self.completionHandler;
                        self.finish();
                        if let completionHandler = callback {
                            completionHandler(.success);
                        }
                    case .failure(let errorCondition, let response):
                        self.onErrorFn(errorCondition: errorCondition, message: response);
                    }
                });
            } else {
                let username = (form.getField(named: "username") as? TextSingleField)?.value;
                let password = (form.getField(named: "password") as? TextPrivateField)?.value;
                let email = (form.getField(named: "email") as? TextSingleField)?.value;
                inBandRegistrationModule.register(username: username, password: password, email: email, callback: { (response) in
                    let type = response?.type ?? .error;
                    switch (type) {
                    case .result:
                        let callback = self.completionHandler;
                        self.finish();
                        if let completionHandler = callback {
                            completionHandler(.success);
                        }
                    default:
                        self.onErrorFn(errorCondition: response?.errorCondition ?? ErrorCondition.remote_server_timeout, message: response?.findChild(name: "error")?.findChild(name: "text")?.value);
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
                        self.client.connectionConfiguration.sslCertificateValidation = .fingerprint(certData.details.fingerprintSha1);
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
                startIBR();
            case is SocketConnector.DisconnectedEvent:
                self.preauthDone = false;
                if !serverAvailable {
                    onErrorFn(errorCondition: ErrorCondition.service_unavailable, message: nil);
                }
            default:
                break;
            }
        }
        
        private func startIBR() {
            let featuresElement = StreamFeaturesModule.getStreamFeatures(client.sessionObject);
            guard InBandRegistrationModule.isRegistrationAvailable(featuresElement) else {
                onErrorFn(errorCondition: ErrorCondition.feature_not_implemented, message: nil);
                return;
            }
            
            inBandRegistrationModule.retrieveRegistrationForm(completionHandler: { result in
                switch result {
                case .success(let type, let form, let bob):
                    self.usesDataForm = type == .dataForm;
                    if self.formToSubmit == nil {
                        self.onForm?(form, bob, self);
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
                                self.onForm?(form, bob, self);
                            } else if (labelsChanged) {
                                self.onForm?(self.formToSubmit!, bob, self);
                            } else {
                                self.submit(form: self.formToSubmit!);
                            }
                            self.formToSubmit = nil;
                        }
                    }
                case .failure(let errorCondition, let errorText):
                    self.onErrorFn(errorCondition: errorCondition, message: errorText);
                }
            });
        }
        
        public func getAcceptedCertificate() -> SslCertificateInfo? {
            return acceptedCertificate;
        }
        
        fileprivate func setClient(client: XMPPClient) {
            self.client = client;
        }
        
        fileprivate func onErrorFn(errorCondition: ErrorCondition, message: String?) -> Void {
            let callback = self.completionHandler;
            if (callback != nil) {
                callback!(.failure(errorCondition: errorCondition, errorText: message));
            } else {
                self.finish();
            }
        }
        
        open var preauthToken: String?;
        private var preauthDone = false;
        
        fileprivate func isStreamReady() -> Bool {
            let featuresElement = StreamFeaturesModule.getStreamFeatures(client.sessionObject);
            
            guard (client.socketConnector?.isTLSActive ?? false) || client.connectionConfiguration.disableTLS || ((featuresElement?.findChild(name: "starttls", xmlns: "urn:ietf:params:xml:ns:xmpp-tls")) == nil) else {
                return false;
            }
            
            guard (client.socketConnector?.isCompressionActive ?? false) || client.connectionConfiguration.disableCompression || ((featuresElement?.getChildren(name: "compression", xmlns: "http://jabber.org/features/compress").firstIndex(where: {(e) in e.findChild(name: "method")?.value == "zlib" })) == nil) else {
                return false;
            }
            
            let preauthSupported: Bool = client.context.module(.streamFeatures).streamFeatures?.findChild(name: "register", xmlns: "urn:xmpp:invite") != nil;
            if preauthSupported && !preauthDone, let preauth: String = preauthToken {
                let iq = Iq();
                iq.type = .set;
                let domain: String = client.context.userBareJid.domain
                iq.to = JID(domain);
                iq.addChild(Element(name: "preauth", attributes: ["token": preauth, "xmlns": "urn:xmpp:pars:0"]));
                client.context.writer?.write(iq, callback: { result in
                    if result?.type ?? .error == .result {
                        self.preauthDone = true;
                        self.startIBR();
                    } else {
                        let error: ErrorCondition = result?.errorCondition ?? ErrorCondition.remote_server_timeout;
                        self.onErrorFn(errorCondition: error, message: result?.errorText ?? (error == ErrorCondition.item_not_found ? "The provided token is invalid or expired" : nil));
                    }
                })
                return false;
            }
            return true;
        }
        
        fileprivate func finish() {
            client = nil;
            inBandRegistrationModule = nil;
            onForm = nil;
            completionHandler = nil;
        }
        
        public enum RegistrationResult {
            case success
            case failure(errorCondition: ErrorCondition, errorText: String?)
        }
        
    }
    
    public enum FormType {
        case plain
        case dataForm
    }
    
    public enum RetrieveFormResult {
        case success(type: FormType, form: JabberDataElement, bob: [BobData])
        case failure(errorCondition: ErrorCondition, errorText: String?)
    }
    
}
