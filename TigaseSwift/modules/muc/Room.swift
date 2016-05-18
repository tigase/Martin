//
// Room.swift
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

public class Room: ChatProtocol, ContextAware {

    private static let stampFormatter = ({()-> NSDateFormatter in
        var f = NSDateFormatter();
        f.locale = NSLocale(localeIdentifier: "en_US_POSIX");
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ";
        f.timeZone = NSTimeZone(forSecondsFromGMT: 0);
        return f;
    })();
    
    // common variables
    public var jid: JID;
    public let allowFullJid: Bool = false;
    
    // specific variables
    public var context: Context!;
    
    private var _lastMessageDate: NSDate? = nil;
    public var lastMessageDate: NSDate? {
        get {
            return _lastMessageDate;
        }
        set {
            guard newValue != nil else {
                return;
            }
            if _lastMessageDate == nil || _lastMessageDate!.compare(newValue!) == NSComparisonResult.OrderedAscending {
                _lastMessageDate = newValue;
            }
        }
    }
    
    private var _nickname: String;
    public var nickname: String {
        return _nickname;
    }
    
    public var password: String?;
    
    private var _presences = [String:Occupant]();
    public var presences: [String:Occupant] {
        return _presences;
    }
    
    public var roomJid: BareJID {
        get {
            return jid.bareJid;
        }
        set {
            jid = JID(newValue);
        }
    }
    
    var _state: State = .not_joined;
    public var state: State {
        return _state;
    }
    
    private var _tempOccupants = [String:Occupant]();
    public var tempOccupants: [String:Occupant] {
        return _tempOccupants;
    }
    
    public init(context: Context, roomJid: BareJID, nickname: String) {
        self.context = context;
        self.jid = JID(roomJid);
        self._nickname = nickname;
    }
    
    public func rejoin() -> Presence {
        let presence = Presence();
        presence.to = JID(roomJid, resource: nickname);
        let x = Element(name: "x", xmlns: "http://jabber.org/protocol/muc");
        presence.addChild(x);
        if password != nil {
            x.addChild(Element(name: "password", cdata: password!));
        }
        
        if lastMessageDate != nil {
            let history = Element(name: "history");
            history.setAttribute("since", value: Room.stampFormatter.stringFromDate(lastMessageDate!));
            x.addChild(history);
        }
        
        _state = .requested;
        context.writer?.write(presence);
        return presence;
    }
    
    public func sendMessage(body: String?, additionalElements: [Element]? = nil) {
        let msg = createMessage(body);
        if additionalElements != nil {
            for elem in additionalElements! {
                msg.addChild(elem);
            }
        }
        context.writer?.write(msg);
    }
    
    public func createMessage(body: String?) -> Message {
        var msg = Message();
        msg.to = jid;
        msg.type = StanzaType.groupchat;
        msg.body = body;
        return msg;
    }
    
    public func add(occupant: Occupant) {
        _presences[occupant.nickname!] = occupant;
    }
    
    public func remove(occupant: Occupant) {
        if let nickname = occupant.nickname {
            _presences.removeValueForKey(nickname);
        }
    }
    
    public func addTemp(nickname: String, occupant: Occupant) {
        _tempOccupants[nickname] = occupant;
    }
    
    public func removeTemp(nickname: String) -> Occupant? {
        return _tempOccupants.removeValueForKey(nickname);
    }
    
    public enum State {
        case joined
        case not_joined
        case requested
    }
}