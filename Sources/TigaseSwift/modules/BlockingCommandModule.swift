//
// BlockingCommandModule.swift
//
// TigaseSwift
// Copyright (C) 2019 "Tigase, Inc." <office@tigase.com>
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
    public static var blockingCommand: XmppModuleIdentifier<BlockingCommandModule> {
        return BlockingCommandModule.IDENTIFIER;
    }
}

open class BlockingCommandModule: XmppModuleBase, XmppModule, Resetable {
    
    public enum Cause: String {
        case spam = "urn:xmpp:reporting:spam"
        case abuse = "urn:xmpp:reporting:abuse"
    }
    
    public static let BC_XMLNS = "urn:xmpp:blocking";
    public static let REPORTING_XMLNS = "urn:xmpp:reporting:1"
    /// ID of module to lookup for in `XmppModulesManager`
    public static let ID = BC_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<BlockingCommandModule>();
    
    public let criteria = Criteria.name("iq", types: [.set]).add(Criteria.or(Criteria.name("block", xmlns: BlockingCommandModule.BC_XMLNS), Criteria.name("unblock", xmlns: BlockingCommandModule.BC_XMLNS)));
    
    public let features = [String]();
    
    private var discoModule: DiscoveryModule!;
    
    open override weak var context: Context? {
        didSet {
            if let context = context {
                discoModule = context.module(.disco);
                discoModule.$serverDiscoResult.filter({ $0.features.contains(BlockingCommandModule.BC_XMLNS) }).sink(receiveValue: { [weak self] _ in
                    guard let that = self else {
                        return;
                    }
                    Task {
                        try await that.retrieveBlockedJids();
                    }
                }).store(in: self);
            }
        }
    }
    
    open var isAvailable: Bool {
        return discoModule.serverDiscoResult.features.contains(BlockingCommandModule.BC_XMLNS);
    }
    open var isReportingSupported: Bool {
        return discoModule.serverDiscoResult.features.contains(BlockingCommandModule.REPORTING_XMLNS);
    }
    
    @Published
    open fileprivate(set) var blockedJids: [JID]?
    
    open var automaticallyRetrieve: Bool = true;
    
    public override init() {
    }
            
    open func reset(scopes: Set<ResetableScope>) {
        if scopes.contains(.session) {
            blockedJids = nil;
        }
    }
        
    open func process(stanza: Stanza) throws {
        guard let actionEl = stanza.firstChild(xmlns: BlockingCommandModule.BC_XMLNS) else {
            throw XMPPError(condition: .feature_not_implemented);
        }
        
        switch actionEl.name {
        case "block":
            if var blocked = self.blockedJids {
                let newJids = actionEl.filterChildren(name: "item").compactMap({ JID($0.attribute("jid")) }).filter({ jid in !blocked.contains(jid) });
                guard !newJids.isEmpty else {
                    return;
                }
                blocked.append(contentsOf: newJids);
                self.blockedJids = blocked;
            }
        case "unblock":
            if let blocked = self.blockedJids {
                let newJids = actionEl.filterChildren(name: "item").compactMap({ JID($0.attribute("jid")) }).filter({ jid in blocked.contains(jid) });
                guard !newJids.isEmpty else {
                    return;
                }
                self.blockedJids = blocked.filter({ jid in !newJids.contains(jid)});
            }
        default:
            throw XMPPError(condition: .feature_not_implemented);
        }
    }
    
    public struct Report {
        public struct ReportedStanza {
            let id: String;
            let by: JID;
        }

        public let cause: Cause
        public let text: String?
        public let stanzas: [ReportedStanza]

        public init(cause: Cause, text: String? = nil, stanzas: [ReportedStanza] = []) {
            self.cause = cause;
            self.text = text;
            self.stanzas = stanzas;
        }
    }
    
    open func block(jid: JID, report: Report? = nil) async throws {
        let iq = Iq(type: .set, {
            Element(name: "block", xmlns: BlockingCommandModule.BC_XMLNS, {
                Element(name: "item", {
                    Attribute("jid", value: jid.description)
                    if let report = report {
                        Element(name: "report", xmlns: BlockingCommandModule.REPORTING_XMLNS, {
                            Attribute("reason", value: report.cause.rawValue)
                            for stanza in report.stanzas {
                                Element(name: "stanza-id", attributes: ["by": stanza.by.description, "id": stanza.id])
                            }
                            if let text = report.text {
                                Element(name: "text", cdata: text)
                            }
                        })
                    }
                })
            })
        });
        try await write(iq: iq);
    }
        
    /**
     Block communication with jid
     - paramater jid: jid to block
     */
    open func block(jids: [JID]) async throws {
        let iq = Iq(type: .set, {
            Element(name: "block", xmlns: BlockingCommandModule.BC_XMLNS, {
                for jid in jids {
                    Element(name: "item", {
                        Attribute("jid", value: jid.description)
                    })
                }
            })
        })
        try await write(iq: iq);
    }
    
    open func unblock(jid: JID) async throws {
        try await unblock(jids: [jid]);
    }
    
    /**
     Unblock communication with jid
     - paramater jid: to unblock
     */
    open func unblock(jids: [JID]) async throws {
        let iq = Iq(type: .set, {
            Element(name: "unblock", xmlns: BlockingCommandModule.BC_XMLNS, {
                for jid in jids {
                    Element(name: "item", {
                        Attribute("jid", value: jid.description)
                    })
                }
            })
        })
        try await write(iq: iq);
    }
        
    open func retrieveBlockedJids() async throws -> [JID] {
        guard let blockedJids = self.blockedJids else {
            let iq = Iq(type: .get, {
                Element(name: "blocklist", xmlns: BlockingCommandModule.BC_XMLNS)
            })
            
            let response = try await write(iq: iq);
            let blockedJids = response.firstChild(name: "blocklist", xmlns: BlockingCommandModule.BC_XMLNS)?.children.compactMap({ JID($0.attribute("jid")) }) ?? [];
            self.blockedJids = blockedJids;
            return blockedJids;
        }
        return blockedJids;
    }
 
}

// async-await support
extension BlockingCommandModule {
    
    open func block(jid: JID, report: Report? = nil, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await block(jid: jid, report: report)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }

    
    open func block(jids: [JID], completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await block(jids: jids)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    open func unblock(jids: [JID], completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await unblock(jids: jids)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    open func retrieveBlockedJids(completionHandler: ((Result<[JID],XMPPError>)->Void)?) {
        Task {
            do {
                completionHandler?(.success(try await retrieveBlockedJids()))
            } catch {
                completionHandler?(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
}
