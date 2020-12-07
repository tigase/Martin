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
open class InBandRegistrationModule: XmppModuleBase, AbstractIQModule {
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "InBandRegistrationModule";
    public static let IDENTIFIER = XmppModuleIdentifier<InBandRegistrationModule>();
    
    public let features = [String]();
    public let criteria = Criteria.empty();
    
    public override init() {
        
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
    open func register(_ jid: JID? = nil, username: String?, password: String?, email: String?, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        register(jid, username: username, password: password, email: email, errorDecoder: XMPPError.from(stanza:), completionHandler: { result in
            completionHandler(result.map { _ in Void() });
        })
    }
    
    open func register<Failure: Error>(_ jid: JID? = nil, username: String?, password: String?, email: String?, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) {
        guard let context = context else {
            completionHandler(.failure(errorDecoder(nil) as! Failure));
            return;
        }
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = jid ?? JID((context.boundJid?.bareJid ?? context.userBareJid)?.domain);
        
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
        
        write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
    /**
     Retrieves registration form and call provided callback
     - parameter from: destination JID for registration - useful for registration in transports
     - parameter completionHandler: called when result is available
     */
    open func retrieveRegistrationForm(from jid: JID? = nil, completionHandler: @escaping (RetrieveFormResult<XMPPError>)->Void) {
        retrieveRegistrationForm(from: jid, errorDecoder: XMPPError.from(stanza:), completionHandler: completionHandler);
    }
    
    open func retrieveRegistrationForm<Failure: Error>(from jid: JID? = nil, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (RetrieveFormResult<Failure>)->Void) {
        guard let context = context else {
            completionHandler(.failure(errorDecoder(nil) as! Failure));
            return;
        }
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = jid ?? JID(context.boundJid?.domain ?? context.userBareJid.domain);
    
        let query = Element(name: "query", xmlns: "jabber:iq:register");
        
        iq.addChild(query);
        write(iq, errorDecoder: errorDecoder, completionHandler: { result in
            completionHandler(result.map { response in
                if let query = response.findChild(name: "query", xmlns: "jabber:iq:register"), let form = JabberDataElement(from: query.findChild(name: "x", xmlns: "jabber:x:data")) {
                    return FormResult(type: .dataForm, form: form, bob: query.mapChildren(transform: BobData.init(from: )));
                } else {
                    let form = JabberDataElement(type: .form);
                    if let query = response.findChild(name: "query", xmlns: "jabber:iq:register") {
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
                    return FormResult(type: .plain, form: form, bob: []);
                }
            });
        });
    }

    open func submitRegistrationForm(to jid: JID? = nil, form: JabberDataElement, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        submitRegistrationForm(to: jid, form: form, errorDecoder: XMPPError.from(stanza:), completionHandler: { result in
            completionHandler(result.map({ _ in Void() }));
        })
    }
    
    open func submitRegistrationForm<Failure: Error>(to jid: JID? = nil, form: JabberDataElement, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) {
        guard let context = context else {
            completionHandler(.failure(errorDecoder(nil) as! Failure));
            return;
        }
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = jid ?? JID(context.boundJid?.domain ?? context.userBareJid.domain);
        
        let query = Element(name: "query", xmlns: "jabber:iq:register");
        query.addChild(form.submitableElement(type: .submit));
        
        iq.addChild(query);
        write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
    /**
     Unregisters currently connected and authenticated user
     - parameter callback: called when user is unregistrated
     */
    open func unregister<Failure: Error>(from: JID? = nil, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) {
        guard let context = context else {
            completionHandler(.failure(errorDecoder(nil) as! Failure));
            return;
        }
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = from ?? context.boundJid;
        
        let query = Element(name: "query", xmlns: "jabber:iq:register");
        query.addChild(Element(name: "remove"));
        iq.addChild(query);
        
        write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
    open func unregister(from: JID? = nil, completionHander: @escaping (Result<Void,XMPPError>)->Void) {
        unregister(from: from, errorDecoder: XMPPError.from(stanza:), completionHandler: { result in
            completionHander(result.map { _ in Void() });
        })
    }
    
    open func changePassword(for serviceJid: JID? = nil, newPassword: String, completionHandler: @escaping (Result<String, XMPPError>)->Void) {
        changePassword(for: serviceJid, newPassword: newPassword, errorDecoder: XMPPError.from(stanza: ), completionHandler: { result in
            completionHandler(result.map { _ in newPassword});
        });
    }
    
    open func changePassword<Failure: Error>(for serviceJid: JID? = nil, newPassword: String, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) {
        guard let context = context, let username = context.userBareJid.localPart else {
            return;
        }
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = serviceJid ?? context.boundJid;
        
        let query = Element(name: "query", xmlns: "jabber:iq:register");
        query.addChild(Element(name: "username", cdata: username));
        query.addChild(Element(name: "password", cdata: newPassword));
        iq.addChild(query);
        
        write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
    /**
     Check if server supports in-band registration
     - returns: true - if in-band registration is supported
     */
    open func isRegistrationAvailable() -> Bool {
        let featuresElement = context?.module(.streamFeatures).streamFeatures;
        return InBandRegistrationModule.isRegistrationAvailable(featuresElement);
    }
    
    public static func isRegistrationAvailable(_ featuresElement: Element?) -> Bool {
        return featuresElement?.findChild(name: "register", xmlns: "http://jabber.org/features/iq-register") != nil;
    }
    
    open class AccountRegistrationTask {
        
        private var cancellables: [Cancellable] = [];
        
        public private(set) var client: XMPPClient! {
            willSet {
                for cancellable in cancellables {
                    cancellable.cancel();
                }
                cancellables.removeAll();
                if let client = self.client {
                    client.disconnect();
                }
            }
            didSet {
                if let client = client {
                    cancellables.append(client.$state.sink(receiveValue: { [weak self] state in
                        switch state {
                        case .disconnected(let reason):
                            switch reason {
                            case .sslCertError(let trust):
                                self?.serverSSLCertValidationFailed(trust);
                            default:
                                break;
                            }
                            self?.serverDisconnected();
                        default:
                            break;
                        }
                    }));
                    cancellables.append(client.module(.streamFeatures).$streamFeatures.compactMap({ $0 }).sink(receiveValue: { [weak self] _ in self?.streamFeaturesReceived() }));
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
        
        deinit {
            for cancellable in cancellables {
                cancellable.cancel();
            }
        }
        
        open func submit(form: JabberDataElement) {
            formToSubmit = form;
            guard (client?.state ?? .disconnected()) != .disconnected() else {
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
                    case .failure(let error):
                        self.onErrorFn(error);
                    }
                });
            } else {
                let username = (form.getField(named: "username") as? TextSingleField)?.value;
                let password = (form.getField(named: "password") as? TextPrivateField)?.value;
                let email = (form.getField(named: "email") as? TextSingleField)?.value;
                inBandRegistrationModule.register(username: username, password: password, email: email, completionHandler: { result in
                    switch result {
                    case .success(_):
                        let callback = self.completionHandler;
                        self.finish();
                        if let completionHandler = callback {
                            completionHandler(.success);
                        }
                    case .failure(let error):
                        self.onErrorFn(error);
                    }
                })
            }
        }
        
        open func cancel() {
            self.client?.disconnect();
            self.finish();
        }
        
        private func streamFeaturesReceived() {
            serverAvailable = true;
            // check registration possibility
            guard isStreamReady() else {
                return;
            }
            startIBR();
        }
        
        private func serverDisconnected() {
            self.preauthDone = false;
            if !serverAvailable {
                onErrorFn(.service_unavailable("Could not connect to the server"));
            }
        }
        
        private func serverSSLCertValidationFailed(_ trust: SecTrust) {
            if self.onCertificateValidationError != nil {
                let certData = SslCertificateInfo(trust: trust);
                self.serverAvailable = true;
                self.onCertificateValidationError!(certData, {() -> Void in
                    self.client.connectionConfiguration.sslCertificateValidation = .fingerprint(certData.details.fingerprintSha1);
                    self.acceptedCertificate = certData;
                    self.serverAvailable = false;
                    self.client.login();
                });
            }
        }
                
        private func startIBR() {
            let featuresElement = StreamFeaturesModule.getStreamFeatures(client.sessionObject);
            guard InBandRegistrationModule.isRegistrationAvailable(featuresElement) else {
                onErrorFn(.feature_not_implemented);
                return;
            }
            
            inBandRegistrationModule.retrieveRegistrationForm(completionHandler: { result in
                switch result {
                case .success(let formResult):
                    self.usesDataForm = formResult.type == .dataForm;
                    if self.formToSubmit == nil {
                        self.onForm?(formResult.form, formResult.bob, self);
                    } else {
                        var sameForm = true;
                        var labelsChanged = false;
                        formResult.form.fieldNames.forEach({(name) in
                            let newField = formResult.form.getField(named: name);
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
                                self.onForm?(formResult.form, formResult.bob, self);
                            } else if (labelsChanged) {
                                self.onForm?(self.formToSubmit!, formResult.bob, self);
                            } else {
                                self.submit(form: self.formToSubmit!);
                            }
                            self.formToSubmit = nil;
                        }
                    }
                case .failure(let error):
                    self.onErrorFn(error);
                }
            });
        }
        
        public func getAcceptedCertificate() -> SslCertificateInfo? {
            return acceptedCertificate;
        }
        
        fileprivate func setClient(client: XMPPClient) {
            self.client = client;
        }
        
        fileprivate func onErrorFn(_ error: XMPPError) {
            guard let callback = self.completionHandler else {
                return;
            }
            completionHandler = nil;
            callback(.failure(error));
            self.finish();
        }
                
        open var preauthToken: String?;
        private var preauthDone = false;
        
        fileprivate func isStreamReady() -> Bool {
            guard let featuresElement = client.module(.streamFeatures).streamFeatures else {
                return false;
            }
            guard (client.connector?.isTLSActive ?? false) || client.connectionConfiguration.disableTLS || ((featuresElement.findChild(name: "starttls", xmlns: "urn:ietf:params:xml:ns:xmpp-tls")) == nil) else {
                return false;
            }

            guard (client.connector?.isCompressionActive ?? false) || client.connectionConfiguration.disableCompression || ((featuresElement.getChildren(name: "compression", xmlns: "http://jabber.org/features/compress").firstIndex(where: {(e) in e.findChild(name: "method")?.value == "zlib" })) == nil) else {
                return false;
            }

            let preauthSupported: Bool = client.context.module(.streamFeatures).streamFeatures?.findChild(name: "register", xmlns: "urn:xmpp:invite") != nil;
            if preauthSupported && !preauthDone, let preauth: String = preauthToken {
                let iq = Iq();
                iq.type = .set;
                let domain: String = client.context.userBareJid.domain
                iq.to = JID(domain);
                iq.addChild(Element(name: "preauth", attributes: ["token": preauth, "xmlns": "urn:xmpp:pars:0"]));
                client.context.writer.write(iq, completionHandler: { result in
                    switch result {
                    case .success(_):
                        self.preauthDone = true;
                        self.startIBR();
                    case .failure(let error):
                        self.onErrorFn(error);
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
            case failure(XMPPError)
        }
        
    }
    
    public enum FormType {
        case plain
        case dataForm
    }
    
    public struct FormResult {
        let type: FormType;
        let form: JabberDataElement;
        let bob: [BobData];
    }
    public typealias RetrieveFormResult<Failure: Error> = Result<FormResult, Failure>
}
