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
import Combine

extension XmppModuleIdentifier {
    public static var inBandRegistration: XmppModuleIdentifier<InBandRegistrationModule> {
        return InBandRegistrationModule.IDENTIFIER;
    }
}

extension StreamFeatures.StreamFeature {
    public static let ibr = StreamFeatures.StreamFeature(name: "register", xmlns: "http://jabber.org/features/iq-register");
    public static let ibrPreAuth = StreamFeatures.StreamFeature(name: "register", xmlns: "urn:xmpp:invite");
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
    
    open override var context: Context? {
        didSet {
            store(context?.module(.streamFeatures).$streamFeatures.map({ $0.contains(.ibr) }).assign(to: \.isRegistrationAvailable, on: self));
        }
    }
    
    public override init() {
        
    }
    
    open func processGet(stanza: Stanza) throws {
        throw XMPPError.not_allowed(nil);
    }
    
    open func processSet(stanza: Stanza) throws {
        throw XMPPError.not_allowed(nil);
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
        guard let context = context else {
            completionHandler(.failure(.undefined_condition));
            return;
        }
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = jid ?? JID(context.boundJid?.domain ?? context.userBareJid.domain);
    
        let query = Element(name: "query", xmlns: "jabber:iq:register");
        
        iq.addChild(query);
        write(iq, errorDecoder: XMPPError.from(stanza:), completionHandler: { result in
            completionHandler(result.map { response in
                if let query = response.firstChild(name: "query", xmlns: "jabber:iq:register"), let form = DataForm(element: query.firstChild(name: "x", xmlns: "jabber:x:data")) {
                    return FormResult(type: .dataForm, form: form, bob: query.compactMapChildren(BobData.init(from:)));
                } else {
                    let form = DataForm(type: .form);
                    if let query = response.firstChild(name: "query", xmlns: "jabber:iq:register") {
                        if let instructions = query.firstChild(name: "instructions")?.value {
                            form.instructions = [instructions];
                        }
                        if query.firstChild(name: "username") != nil {
                            form.add(field: .TextSingle(var: "username", required: true));
                        }
                        if query.firstChild(name: "password") != nil {
                            form.add(field: .TextPrivate(var: "password", required: true));
                        }
                        if query.firstChild(name: "email") != nil {
                            form.add(field: .TextSingle(var: "email", required: true));
                        }
                    }
                    return FormResult(type: .plain, form: form, bob: []);
                }
            });
        });
    }

    open func submitRegistrationForm(to jid: JID? = nil, form: DataForm, completionHandler: @escaping (Result<Iq,XMPPError>)->Void) {
        guard let context = context else {
            completionHandler(.failure(.undefined_condition));
            return;
        }
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = jid ?? JID(context.boundJid?.domain ?? context.userBareJid.domain);
        
        let query = Element(name: "query", xmlns: "jabber:iq:register");
        query.addChild(form.element(type: .submit, onlyModified: false));
        
        iq.addChild(query);
        write(iq, errorDecoder: XMPPError.from(stanza:), completionHandler: completionHandler);
    }

    /**
     Unregisters currently connected and authenticated user
     - parameter callback: called when user is unregistrated
     */
    open func unregister(from: JID? = nil, completionHandler: @escaping (Result<Iq,XMPPError>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = from;
        
        let query = Element(name: "query", xmlns: "jabber:iq:register");
        query.addChild(Element(name: "remove"));
        iq.addChild(query);
        
        write(iq, errorDecoder: XMPPError.from(stanza:), completionHandler: completionHandler);
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
    
    public private(set) var isRegistrationAvailable = false;
    
    open class AccountRegistrationTask {
        
        private var cancellables: Set<AnyCancellable> = [];
        
        public private(set) var client: XMPPClient! {
            willSet {
                for cancellable in cancellables {
                    cancellable.cancel();
                }
                cancellables.removeAll();
                if let client = self.client {
                    _ = client.disconnect();
                }
            }
            didSet {
                if let client = client {
                    client.$state.sink(receiveValue: { [weak self] state in
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
                    }).store(in: &cancellables);
                    client.module(.streamFeatures).$streamFeatures.sink(receiveValue: { [weak self] features in self?.streamFeaturesReceived(streamFeatures: features) }).store(in: &cancellables);
                }
            }
        };
        var inBandRegistrationModule: InBandRegistrationModule!;
        var onForm: ((DataForm, [BobData], AccountRegistrationTask)->Void)?;
        var completionHandler: ((RegistrationResult)->Void)?;
        var onCertificateValidationError: ((SslCertificateInfo, @escaping ()->Void)->Void)?;
        
        var usesDataForm = false;
        var formToSubmit: DataForm?;
        var serverAvailable: Bool = false;
        
        var acceptedCertificate: SslCertificateInfo? = nil;
        
        public init(client: XMPPClient? = nil, domainName: String, preauth: String? = nil, onForm: @escaping (DataForm, [BobData], InBandRegistrationModule.AccountRegistrationTask)->Void, sslCertificateValidator: ((SecTrust)->Bool)? = nil, onCertificateValidationError: ((SslCertificateInfo, @escaping ()->Void)->Void)? = nil, completionHandler: @escaping (RegistrationResult)->Void) {
            let localClient = client ?? XMPPClient();
            _ = localClient.modulesManager.register(StreamFeaturesModule());
            self.setClient(client: localClient);
            self.onForm = onForm;
            self.completionHandler = completionHandler;
            
            self.inBandRegistrationModule = self.client!.modulesManager.register(InBandRegistrationModule());
            self.preauthToken = preauth;
            
            self.client?.connectionConfiguration.userJid = BareJID(domainName);
            self.client.connectionConfiguration.modifyConnectorOptions(type: SocketConnector.Options.self, { options in
                options.sslCertificateValidation = sslCertificateValidator == nil ? .default : .customValidator(sslCertificateValidator!);
            });
            self.onCertificateValidationError = onCertificateValidationError;
            self.client?.login();
        }
        
        deinit {
            for cancellable in cancellables {
                cancellable.cancel();
            }
        }
        
        open func submit(form: DataForm) {
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
                let username = form.value(for: "username", type: String.self);
                let password = form.value(for: "password", type: String.self);
                let email = form.value(for: "email", type: String.self);
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
            _ = self.client?.disconnect();
            self.finish();
        }
        
        private func streamFeaturesReceived(streamFeatures: StreamFeatures) {
            serverAvailable = true;
            // check registration possibility
            guard isStreamReady(streamFeatures: streamFeatures) else {
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
            if let onError = self.onCertificateValidationError {
                let certData = SslCertificateInfo(trust: trust);
                self.serverAvailable = true;
                onError(certData, {() -> Void in
                    self.client.connectionConfiguration.modifyConnectorOptions(type: SocketConnector.Options.self, { options in
                        options.sslCertificateValidation = .fingerprint(certData.details.fingerprintSha1);
                    })
                    self.acceptedCertificate = certData;
                    self.serverAvailable = false;
                    self.client.login();
                });
            }
        }
                
        private func startIBR() {
            inBandRegistrationModule.retrieveRegistrationForm(completionHandler: { result in
                switch result {
                case .success(let formResult):
                    self.usesDataForm = formResult.type == .dataForm;
                    if self.formToSubmit == nil {
                        self.onForm?(formResult.form, formResult.bob, self);
                    } else {
                        let oldFields = self.formToSubmit?.fields ?? [];
                        var sameForm = !oldFields.isEmpty;
                        var labelsChanged = false;
                        for oldField in oldFields  {
                            if let newField = formResult.form.field(for: oldField.var) {
                                if oldField.type != newField.type {
                                    sameForm = false;
                                } else {
                                    labelsChanged = labelsChanged || newField.label != oldField.label;
                                }
                            } else {
                                sameForm = false;
                            }
                        }
                    
                        if let submitForm = self.formToSubmit {
                            formResult.form.copyValues(from: submitForm)
                        }

                        DispatchQueue.global().async {
                            if (!sameForm) || labelsChanged {
                                self.onForm?(formResult.form, formResult.bob, self);
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
        
        fileprivate func isStreamReady(streamFeatures: StreamFeatures) -> Bool {
            guard !streamFeatures.isNone else {
                return false;
            }
            guard (client.connector?.activeFeatures.contains(.TLS) ?? false) || client.connectionConfiguration.disableTLS || streamFeatures.contains(.startTLS) else {
                return false;
            }

            guard (client.connector?.activeFeatures.contains(.ZLIB) ?? false) || client.connectionConfiguration.disableCompression || streamFeatures.contains(.compressionZLIB) else {
                return false;
            }
            
            let preauthSupported: Bool = streamFeatures.contains(.ibrPreAuth);
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
        let form: DataForm;
        let bob: [BobData];
    }

    public typealias RetrieveFormResult<Failure: Error> = Result<FormResult, Failure>
}


// async-await support
extension InBandRegistrationModule {

    open func register(_ jid: JID? = nil, username: String?, password: String?, email: String?, errorDecoder: @escaping PacketErrorDecoder<Error> = XMPPError.from(stanza:)) async throws -> Iq {
        return try await withUnsafeThrowingContinuation { continuation in
            register(jid, username: username, password: password, email: email, errorDecoder: errorDecoder, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }

    open func retrieveRegistrationForm(from jid: JID? = nil) async throws -> FormResult {
        return try await withUnsafeThrowingContinuation { continuation in
            retrieveRegistrationForm(from: jid, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }

    open func submitRegistrationForm(to jid: JID? = nil, form: DataForm) async throws -> Iq {
        return try await withUnsafeThrowingContinuation { continuation in
            submitRegistrationForm(to: jid, form: form, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }

    open func unregister(from: JID? = nil) async throws -> Iq {
        return try await withUnsafeThrowingContinuation { continuation in
            unregister(from: from, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }

    open func changePassword(for serviceJid: JID? = nil, newPassword: String, errorDecoder: @escaping PacketErrorDecoder<Error> = XMPPError.from(stanza:)) async throws -> Iq {
        return try await withUnsafeThrowingContinuation { continuation in
            changePassword(for: serviceJid, newPassword: newPassword, errorDecoder: errorDecoder, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }

    @discardableResult
    open func submitPreAuth(token: String) async throws -> Iq {
        let iq = Iq();
        iq.type = .set;
        let domain: String = context!.userBareJid.domain
        iq.to = JID(domain);
        iq.addChild(Element(name: "preauth", attributes: ["token": token, "xmlns": "urn:xmpp:pars:0"]));
        return try await self.write(iq: iq);
    }

    open class AccountRegistrationAsyncTask {

        private let client: XMPPClient;
        var inBandRegistrationModule: InBandRegistrationModule!;
        open var preauthToken: String?;
        var usesDataForm = false;

        public init(client: XMPPClient = XMPPClient(), domainName: String, preauth: String? = nil) {
            _ = client.modulesManager.register(StreamFeaturesModule());
            self.client = client;

            self.inBandRegistrationModule = client.modulesManager.register(InBandRegistrationModule());
            self.preauthToken = preauth;

            self.client.connectionConfiguration.userJid = BareJID(domainName);
        }

        private func ensureConnected() async throws {
            if !client.isConnected {
                try await client.loginAndWait();
                if let token = preauthToken {
                    try await inBandRegistrationModule.submitPreAuth(token: token);
                }

            }
        }

        open func retrieveForm() async throws -> InBandRegistrationModule.FormResult {
            try await ensureConnected();
            let result = try await inBandRegistrationModule.retrieveRegistrationForm();
            usesDataForm = result.type == .dataForm;
            return result;
        }

        open func submit(form: DataForm) async throws -> Iq {
            try await ensureConnected();
            if usesDataForm {
                return try await inBandRegistrationModule.submitRegistrationForm(form: form)
            } else {
                let username = form.value(for: "username", type: String.self);
                let password = form.value(for: "password", type: String.self);
                let email = form.value(for: "email", type: String.self);
                return try await inBandRegistrationModule.register(username: username, password: password, email: email);
            }
        }

        open func cancel() async throws {
            try await self.client.disconnect();
        }

    }
}
