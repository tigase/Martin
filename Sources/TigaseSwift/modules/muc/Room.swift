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

/**
 Class represents MUC room locally and supports `ChatProtocol`
 */
open class Room: ChatProtocol, ContextAware {

    fileprivate static let stampFormatter = ({()-> DateFormatter in
        var f = DateFormatter();
        f.locale = Locale(identifier: "en_US_POSIX");
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ";
        f.timeZone = TimeZone(secondsFromGMT: 0);
        return f;
    })();
    
    // common variables
    /// JID of MUC room
    fileprivate var _jid: JID;
    open var jid: JID {
        get {
            var result: JID! = nil;
            Room.queue.sync {
                result = self._jid;
            }
            return result;
        }
        set {
            Room.queue.async(flags: .barrier, execute: {
                self._jid = newValue;
            }) 
        }
    }
    public let allowFullJid: Bool = false;
    
    // specific variables
    open var context: Context!;
    
    fileprivate var _lastMessageDate: Date? = nil;
    /// Timestamp of last received message
    open var lastMessageDate: Date? {
        get {
            var result: Date? = nil;
            Room.queue.sync {
                result = self._lastMessageDate;
            }
            return result;
        }
        set {
            guard newValue != nil else {
                return;
            }
            Room.queue.async(flags: .barrier, execute: {
                if self._lastMessageDate == nil || self._lastMessageDate!.compare(newValue!) == ComparisonResult.orderedAscending {
                    self._lastMessageDate = newValue;
                }
            }) 
        }
    }
    
    fileprivate let _nickname: String;
    /// Nickname in room
    open var nickname: String {
        return _nickname;
    }
    
    fileprivate var _password: String?;
    /// Room password
    open var password: String? {
        get {
            var result: String? = nil;
            Room.queue.sync {
                result = self._password;
            }
            return result;
        }
        set {
            Room.queue.async(flags: .barrier, execute: {
                self._password = newValue;
            }) 
        }
    }
    
    fileprivate var _presences = [String: MucOccupant]();
    /// Room occupants
    open var presences: [String: MucOccupant] {
        var result: [String: MucOccupant]!;
        Room.queue.sync {
            result = self._presences;
        }
        return result;
    }
    /// BareJID of MUC room
    open var roomJid: BareJID {
        get {
            return jid.bareJid;
        }
    }
    
    var _state: State = .not_joined {
        didSet {
            if _state == .not_joined {
                let occupants = self.presences.values;
                for occupant in occupants {
                    self.remove(occupant: occupant);
                    // should we fire this event?
                    // context.eventBus.fire(OccupantLeavedEvent(sessionObject: context.sessionObject, ))
                }
            }
            if _state == .joined, let tmp = onRoomJoined {
                onRoomJoined = nil;
                tmp(self);
            }
        }
    }
    /// State of room
    open var state: State {
        return _state;
    }
    
    open var onRoomCreated: ((Room)->Void)? = nil;
    open var onRoomJoined: ((Room)->Void)? = nil;
    
    fileprivate static let queue = DispatchQueue(label: "room_queue", attributes: DispatchQueue.Attributes.concurrent);
    
    fileprivate var _tempOccupants = [String:MucOccupant]();
    /// Temporary occupants
    open var tempOccupants: [String:MucOccupant] {
        var result: [String: MucOccupant]!;
        Room.queue.sync {
            result = self._tempOccupants;
        }
        return result;
    }
    
    public init(context: Context, roomJid: BareJID, nickname: String) {
        self.context = context;
        self._nickname = nickname;
        self._jid = JID(roomJid);
    }
    
    /// Rejoin this room
    open func rejoin(skipHistoryFetch: Bool = false) -> Presence {
        let presence = Presence();
        presence.to = JID(roomJid, resource: nickname);
        let x = Element(name: "x", xmlns: "http://jabber.org/protocol/muc");
        presence.addChild(x);
        if password != nil {
            x.addChild(Element(name: "password", cdata: password!));
        }
        
            
        if lastMessageDate != nil {
            if skipHistoryFetch {
                let history = Element(name: "history");
                history.setAttribute("maxchars", value: "0");
                history.setAttribute("maxstanzas", value: "0");
                x.addChild(history);
            } else {
                let history = Element(name: "history");
                history.setAttribute("since", value: Room.stampFormatter.string(from: lastMessageDate!));
                x.addChild(history);
            }
        }
        
        _state = .requested;
        context.writer.write(presence);
        
        return presence;
    }
    
    /**
     Send message to room
     - parameter body: text to send
     - parameter additionalElement: additional elements to add to message
     */
    open func sendMessage(_ body: String?, url: String? = nil, additionalElements: [Element]? = nil) {
        let msg = createMessage(body);
        if url != nil {
            msg.oob = url;
        }
        if additionalElements != nil {
            for elem in additionalElements! {
                msg.addChild(elem);
            }
        }
        context.writer.write(msg);
    }
    
    /**
     Prepare message for sending to room
     - parameter body: text to send
     - returns: newly create message
     */
    open func createMessage(_ body: String?) -> Message {
        let msg = Message();
        msg.to = jid;
        msg.type = StanzaType.groupchat;
        msg.body = body;
        return msg;
    }
    
    open func createPrivateMessage(_ body: String?, recipientNickname: String) -> Message {
        let msg = Message();
        msg.to = JID(roomJid, resource: recipientNickname);
        msg.type = StanzaType.chat;
        msg.body = body;
        msg.addChild(Element(name: "x", xmlns: "http://jabber.org/protocol/muc#user"));
        return msg;
    }
    
    /**
     Send invitation
     - parameter invitee: user to invite
     - parameter reason: invitation reason
     */
    open func invite(_ invitee: JID, reason: String?) {
        let message = self.createInvitation(invitee, reason: reason);
        
        context.writer.write(message);
    }
    
    /**
     Create invitation
     - parameter invitee: user to invite
     - parameter reason: invitation reason
     - returns: newly create message
     */
    open func createInvitation(_ invitee: JID, reason: String?) -> Message {
        let message = Message();
        message.to = JID(self.roomJid);
        
        let x = Element(name: "x", xmlns: "http://jabber.org/protocol/muc#user");
        let invite = Element(name: "invite");
        invite.setAttribute("to", value: invitee.stringValue);
        if (reason != nil) {
            invite.addChild(Element(name: "reason", cdata: reason!));
        }
        x.addChild(invite);
        message.addChild(x);

        return message;
    }
    
    /**
     Send direct invitation
     - parameter invitee: user to invite
     - parameter reason: invitation reason
     - parameter threadId: thread id to use in invitation message
     */
    open func inviteDirectly(_ invitee: JID, reason: String?, threadId: String?) {
        let message = createDirectInvitation(invitee, reason: reason, threadId: threadId);
        context.writer.write(message);
    }
    
    /**
     Create direct invitation
     - parameter invitee: user to invite
     - parameter reason: invitation reason
     - parameter threadId: thread id to use in invitation message
     - returns: newly created invitation message
     */
    open func createDirectInvitation(_ invitee: JID, reason: String?, threadId: String?) -> Message {
        let message = Message();
        message.to = invitee;
        
        let x = Element(name: "x", xmlns: "jabber:x:conference");
        x.setAttribute("jid", value: roomJid.stringValue);
        
        x.setAttribute("password", value: password);
        x.setAttribute("reason", value: reason);
        
        if threadId != nil {
            x.setAttribute("thread", value: threadId);
            x.setAttribute("continue", value: "true");
        }
        
        return message;
    }
    
    open func add(occupant: MucOccupant) {
        Room.queue.async(flags: .barrier, execute: {
            self._presences[occupant.nickname] = occupant;
        }) 
    }
    
    open func remove(occupant: MucOccupant) {
        Room.queue.async(flags: .barrier, execute: {
            self._presences.removeValue(forKey: occupant.nickname);
        }) 
    }
    
    open func addTemp(nickname: String, occupant: MucOccupant) {
        Room.queue.async(flags: .barrier, execute: {
            self._tempOccupants[nickname] = occupant;
        }) 
    }
    
    open func removeTemp(nickname: String) -> MucOccupant? {
        var result: MucOccupant?;
        Room.queue.sync(flags: .barrier, execute: {
            result = self._tempOccupants.removeValue(forKey: nickname);
        }) 
        return result;
    }
    
    open func checkTigasePushNotificationRegistrationStatus(completionHandler: @escaping (Result<Bool,XMPPError>)->Void) {
        guard let regModule = context?.modulesManager.module(.inBandRegistration) else {
            completionHandler(.failure(.undefined_condition));
            return;
        };
        
        regModule.retrieveRegistrationForm(from: self.jid, completionHandler: { result in
            switch result {
            case .success(let formResult):
                if formResult.type == .dataForm, let field: BooleanField = formResult.form.getField(named: "{http://tigase.org/protocol/muc}offline") {
                    completionHandler(.success(field.value));
                } else {
                    completionHandler(.failure(.undefined_condition));
                }
            case .failure(let error):
                completionHandler(.failure(error));
            }
        });
    }
    
    open func registerForTigasePushNotification(_ value: Bool, completionHandler: @escaping (Result<Bool,XMPPError>)->Void) {
        guard let regModule = context?.modulesManager.module(.inBandRegistration) else {
            completionHandler(.failure(.undefined_condition));
            return;
        };
        
        regModule.retrieveRegistrationForm(from: self.jid, completionHandler: { result in
            switch result {
            case .success(let formResult):
                if formResult.type == .dataForm, let valueField: BooleanField = formResult.form.getField(named: "{http://tigase.org/protocol/muc}offline"), let nicknameField: TextSingleField = formResult.form.getField(named: "muc#register_roomnick") {
                    if valueField.value == value {
                        completionHandler(.success(value));
                    } else {
                        if value {
                            valueField.value = value;
                            nicknameField.value = self.nickname;
                            regModule.submitRegistrationForm(to: self.jid, form: formResult.form, completionHandler: { result in
                                switch result {
                                case .success(_):
                                    completionHandler(.success(value));
                                case .failure(let error):
                                    completionHandler(.failure(error));
                                }
                            })
                        } else {
                            regModule.unregister(from: self.jid, completionHander: { result in
                                switch result {
                                case .success(_):
                                    completionHandler(.success(value));
                                case .failure(let error):
                                    completionHandler(.failure(error));
                                }
                            });
                        }
                    }
                } else {
                    completionHandler(.failure(.undefined_condition));
                }
            case .failure(let error):
                completionHandler(.failure(error));
            }
        })
    }
    
    /**
     Possible states of room:
     - joined: you are joined to room
     - not_joined: you are not joined and join is not it progress
     - requested: you are not joined but already requested join
     */
    public enum State {
        case joined
        case not_joined
        case requested
        case destroyed
    }
}
