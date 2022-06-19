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
                store(discoModule.$serverDiscoResult.filter({ $0.features.contains(BlockingCommandModule.BC_XMLNS) }).sink(receiveValue: { [weak self] _ in self?.retrieveBlockedJids(completionHandler: nil)}));
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
            throw XMPPError.feature_not_implemented;
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
            throw XMPPError.feature_not_implemented;
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
    
    open func block(jid: JID, report: Report? = nil, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        let block = Element(name: "block", xmlns: BlockingCommandModule.BC_XMLNS);
        let item =  Element(name: "item", attributes: ["jid": jid.description]);
        if let report = report {
            let reportEl = Element(name: "report", xmlns: BlockingCommandModule.REPORTING_XMLNS);
            reportEl.attribute("reason", newValue: report.cause.rawValue)
            for stanza in report.stanzas {
                reportEl.addChild(Element(name: "stanza-id", attributes: ["by": stanza.by.description, "id": stanza.id]));
            }
            if let text = report.text {
                reportEl.addChild(Element(name: "text", cdata: text));
            }
            item.addChild(reportEl);
        }
        block.addChild(item);
        iq.addChild(block);
        write(iq, completionHandler: { result in
            completionHandler(result.map({ _ in Void() }));
        })
    }
    
    /**
     Block communication with jid
     - paramater jid: jid to block
     */
    open func block(jids: [JID], completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        guard !jids.isEmpty else {
            completionHandler(.success(Void()));
            return;
        }
        
        let iq = Iq();
        iq.type = StanzaType.set;
        let block = Element(name: "block", xmlns: BlockingCommandModule.BC_XMLNS, children: jids.map({ jid in Element(name: "item", attributes: ["jid": jid.description])}));
        iq.addChild(block);
        write(iq, completionHandler: { result in
            completionHandler(result.map({ _ in Void() }));
        })
    }
    
    open func unblock(jid: JID, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        unblock(jids: [jid], completionHandler: completionHandler);
    }
    
    /**
     Unblock communication with jid
     - paramater jid: to unblock
     */
    open func unblock(jids: [JID], completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        guard !jids.isEmpty else {
            completionHandler(.success(Void()));
            return;
        }
        
        let iq = Iq();
        iq.type = StanzaType.set;
        let unblock = Element(name: "unblock", xmlns: BlockingCommandModule.BC_XMLNS, children: jids.map({ jid in Element(name: "item", attributes: ["jid": jid.description])}));
        iq.addChild(unblock);
        write(iq, completionHandler: { result in
            completionHandler(result.map({ _ in Void() }));
        })
    }
    
    open func retrieveBlockedJids(completionHandler: ((Result<[JID],XMPPError>)->Void)?) {
        guard let blockedJids = self.blockedJids else {
            let iq = Iq();
            iq.type = StanzaType.get;
            let list = Element(name: "blocklist", xmlns: BlockingCommandModule.BC_XMLNS);
            iq.addChild(list);

            write(iq, completionHandler: { result in
                switch result {
                case .success(let iq):
                    let blockedJids = iq.firstChild(name: "blocklist", xmlns: BlockingCommandModule.BC_XMLNS)?.children.compactMap({ JID($0.attribute("jid")) }) ?? [];
                    self.blockedJids = blockedJids;
                    completionHandler?(.success(blockedJids));
                case .failure(let error):
                    completionHandler?(.failure(error));
                }
            })
            return;
        }
        completionHandler?(.success(blockedJids));
    }
 
}

