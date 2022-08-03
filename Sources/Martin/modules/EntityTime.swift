//
// EntityTime.swift
//
// TigaseSwift
// Copyright (C) 2018 "Tigase, Inc." <office@tigase.com>
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

open class EntityTimeModule: XmppModuleBase, AbstractIQModule {

    public static let XMLNS = "urn:xmpp:time";
    public static let ID = XMLNS;
    
    fileprivate static let stampFormatter = ({()-> DateFormatter in
        var f = DateFormatter();
        f.locale = Locale(identifier: "en_US_POSIX");
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ";
        f.timeZone = TimeZone(secondsFromGMT: 0);
        return f;
    })();
    
    public var id: String = ID;
    
    public let criteria = Criteria.name("iq").add(Criteria.name("time", xmlns: XMLNS));
    
    public let features: [String] = [XMLNS];

    public override init() {
        
    }

    public struct QueryResult {
        let timeZone: String?;
        let timestamp: Date?;
    }
        
    open func getEntityTime(from jid: JID, completionHandler: @escaping (Result<QueryResult,XMPPError>)->Void) {
        let iq = Iq();
        iq.to = jid;
        iq.type = StanzaType.get;
        
        iq.addChild(Element(name: "time", xmlns: EntityTimeModule.XMLNS));
        
        write(iq, completionHandler: { result in
            completionHandler(result.map { response in
                let timeEl = response.findChild(name: "time", xmlns: EntityTimeModule.XMLNS);
                var date: Date? = nil;
                if let utc = timeEl?.findChild(name: "utc")?.value {
                    date = EntityTimeModule.stampFormatter.date(from: utc);
                }
                return QueryResult(timeZone: timeEl?.findChild(name: "tzo")?.value, timestamp: date);
            })
        });
    }
    
    open func processGet(stanza: Stanza) throws {
        let iq = Iq();
        iq.type = StanzaType.result;
        iq.to = stanza.from;
        iq.from = stanza.to;
        iq.id = stanza.id;
        
        let timeEl = Element(name: "time", xmlns: EntityTimeModule.XMLNS);
        
        let minutesFromGMT = TimeZone.autoupdatingCurrent.secondsFromGMT() / 60;
        if minutesFromGMT == 0 {
            timeEl.addChild(Element(name: "tzo", cdata: "Z"));
        } else {
            let hours = abs(minutesFromGMT / 60);
            let minutes = abs(minutesFromGMT % 60);
            let tzo = (minutesFromGMT < 0 ? "-" : "+") + String(format: "%02d:%02d", hours, minutes);
            timeEl.addChild(Element(name: "tzo", cdata: tzo));
        }
        timeEl.addChild(Element(name: "utc", cdata: EntityTimeModule.stampFormatter.string(from: Date())));
        
        iq.addChild(timeEl);
        
        write(iq);
    }
    
    open func processSet(stanza: Stanza) throws {
        throw ErrorCondition.bad_request;
    }
    
}
