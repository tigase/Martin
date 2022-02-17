//
// Jingle.swift
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

public class Jingle {
    
    public static var supportCryptoAttribute = false;
    
    public class Content {
        
        public let creator: Creator;
        public let name: String;
        public let senders: Senders?;
        public let description: JingleDescription?;
        public let transports: [JingleTransport];
        
        public required convenience init?(from el: Element, knownDescriptions: [JingleDescription.Type], knownTransports: [JingleTransport.Type]) {
            guard el.name == "content", let name = el.getAttribute("name"), let creator = Creator(rawValue: el.getAttribute("creator") ?? "") else {
                return nil;
            }
            
            var senders: Senders? = nil;
            if let sendersStr = el.getAttribute("senders") {
                senders = Senders(rawValue: sendersStr);
            }
            
            let descEl = el.findChild(name: "description");
            let description = descEl == nil ? nil : knownDescriptions.map({ (desc) -> JingleDescription? in
                return desc.init(from: descEl!);
            }).filter({ desc -> Bool in return desc != nil}).map({ desc -> JingleDescription in return desc! }).first;
            
            let foundTransports = el.mapChildren(transform: { (child) -> JingleTransport? in
                let transports = knownTransports.map({ (type) -> JingleTransport? in
                    let transport = type.init(from: child);
                    return transport;
                });
                return transports.filter({ transport -> Bool in return transport != nil }).map({ transport -> JingleTransport in return transport!}).first;
            });
            
            self.init(name: name, creator: creator, senders: senders, description: description, transports: foundTransports);
        }
        
        public init(name: String, creator: Creator, senders: Senders?, description: JingleDescription?, transports: [JingleTransport]) {
            self.name = name;
            self.creator = creator;
            self.senders = senders;
            self.description = description;
            self.transports = transports;
        }
        
        public func with(senders: Senders?) -> Content {
            return Content(name: name, creator: creator, senders: senders, description: description, transports: transports);
        }
        
        public func toElement() -> Element {
            let el = Element(name: "content");
            el.setAttribute("creator", value: creator.rawValue);
            el.setAttribute("name", value: name);
            if let senders = self.senders {
                el.setAttribute("senders", value: senders.rawValue);
            }
            
            if description != nil {
                el.addChild(description!.toElement());
            }
            transports.forEach { (transport) in
                el.addChild(transport.toElement());
            }
            
            return el;
        }
        
        public enum Creator: String {
            case initiator
            case responder
        }
        
        public enum Senders: String {
            case none
            case initiator
            case responder
            case both
        }
        
    }
}

public protocol JingleDescription {
    
    var media: String { get };
    
    init?(from el: Element);
    
    func toElement() -> Element;
    
}

public protocol JingleTransport {
    
    var xmlns: String { get }
    
    init?(from el: Element);
    
    func toElement() -> Element;
    
}

extension Jingle {
    
    public enum Action: String {
        case contentAccept = "content-accept"
        case contentAdd = "content-add"
        case contentModify = "content-modify"
        case contentRemove = "content-remove"
        case contentReject = "content-reject"
        case descriptionInfo = "description-info"
        case securityInfo = "security-info"
        case sessionAccept = "session-accept"
        case sessionInfo = "session-info"
        case sessionInitiate = "session-initiate"
        case sessionTerminate = "session-terminate"
        case transportAccept = "transport-accept"
        case transportInfo = "transport-info"
        case transportReject = "transport-reject"
        case transportReplace = "transport-replace"
    }
    
}

extension Jingle {
    
    public enum ContentAction {
        case add
        case accept
        case remove
        case modify
        
        public static func from(_ action: Action) -> ContentAction? {
            switch action {
            case .contentAdd:
                return .add;
            case .contentAccept:
                return .accept;
            case .contentModify:
                return .modify;
            case .contentRemove:
                return .remove;
            default:
                return nil;
            }
        }
        
        var jingleAction: Jingle.Action {
            switch self {
            case .add:
                return .contentAdd;
            case .accept:
                return .contentAccept;
            case .modify:
                return .contentModify;
            case .remove:
                return .contentRemove;
            }
        }
    }
    
}

extension Jingle {
    public enum SessionInfo {
        case active
        case hold
        case unhold
        case mute(contentName: String?)
        case unmute(contentName: String?)
        case ringing
        
        public static let XMLNS = "urn:xmpp:jingle:apps:rtp:info:1";
        
        public static func from(element el: Element) -> SessionInfo? {
            guard XMLNS == el.xmlns else {
                return nil;
            }
            
            switch el.name {
            case "active":
                return .active;
            case "hold":
                return .hold;
            case "unhold":
                return .unhold;
            case "mute":
                return .mute(contentName: el.getAttribute("name"));
            case "unmute":
                return .unmute(contentName: el.getAttribute("name"));
            case "ringing":
                return ringing;
            default:
                return nil;
            }
        }
        
        public var name: String {
            switch self {
            case .active:
                return "active";
            case .hold:
                return "hold";
            case .unhold:
                return "unhold";
            case .mute(_):
                return "mute";
            case .unmute(_):
                return "unmute";
            case .ringing:
                return "ringing";
            }
        }
        
        public func element(creatorProvider: (String)->Jingle.Content.Creator) -> Element {
            let el = Element(name: self.name, xmlns: SessionInfo.XMLNS);
            switch self {
            case .mute(let cname):
                if let contentName = cname {
                    el.setAttribute("creator", value: creatorProvider(contentName).rawValue);
                    el.setAttribute("name", value: contentName);
                }
            case .unmute(let cname):
                if let contentName = cname {
                    el.setAttribute("creator", value: creatorProvider(contentName).rawValue);
                    el.setAttribute("name", value: contentName);
                }
            default:
                break
            }
            return el;
        }
    }
}

extension Jingle {
    public class Transport {
        
        public class ICEUDPTransport: JingleTransport {
            
            public static let XMLNS = "urn:xmpp:jingle:transports:ice-udp:1";
            
            public let xmlns = XMLNS;
            
            public let pwd: String?;
            public let ufrag: String?;
            public let candidates: [Candidate];
            public let fingerprint: Fingerprint?;
            
            public required convenience init?(from el: Element) {
                guard el.name == "transport" && el.xmlns == ICEUDPTransport.XMLNS else {
                    return nil;
                }
                let pwd = el.getAttribute("pwd");
                let ufrag = el.getAttribute("ufrag");
                
                self.init(pwd: pwd, ufrag: ufrag, candidates: el.mapChildren(transform: { (child) -> Candidate? in
                    return Candidate(from: child);
                }, filter: { el -> Bool in
                    return el.name == "candidate";
                }), fingerprint: Fingerprint(from: el.findChild(name: "fingerprint", xmlns: "urn:xmpp:jingle:apps:dtls:0")));
            }
            
            public init(pwd: String?, ufrag: String?, candidates: [Candidate], fingerprint: Fingerprint? = nil) {
                self.pwd = pwd;
                self.ufrag = ufrag;
                self.candidates = candidates;
                self.fingerprint = fingerprint;
            }
            
            public func toElement() -> Element {
                let el = Element(name: "transport", xmlns: ICEUDPTransport.XMLNS);
                if fingerprint != nil {
                    el.addChild(fingerprint!.toElement());
                }
                self.candidates.forEach { (candidate) in
                    el.addChild(candidate.toElement());
                }
                el.setAttribute("ufrag", value: self.ufrag);
                el.setAttribute("pwd", value: self.pwd);
                return el;
            }
            
            public class Fingerprint {
                public let hash: String;
                public let value: String;
                public let setup: Setup;
                
                public convenience init?(from elem: Element?) {
                    guard let el = elem else {
                        return nil;
                    }
                    guard let hash = el.getAttribute("hash"), let value = el.value, let setup = Setup(rawValue: el.getAttribute("setup") ?? "") else {
                        return nil;
                    }
                    self.init(hash: hash, value: value, setup: setup);
                }
                
                public init(hash: String, value: String, setup: Setup) {
                    self.hash = hash;
                    self.value = value;
                    self.setup = setup;
                }
                
                public func toElement() -> Element {
                    let fingerprintEl = Element(name: "fingerprint", cdata: value, xmlns: "urn:xmpp:jingle:apps:dtls:0");
                    fingerprintEl.setAttribute("hash", value: hash);
                    fingerprintEl.setAttribute("setup", value: setup.rawValue);
                    return fingerprintEl;
                }
                
                public enum Setup: String {
                    case actpass
                    case active
                    case passive
                }
            }
            
            public class Candidate {
                public let component: UInt8;
                public let foundation: UInt;
                public let generation: UInt8;
                public let id: String;
                public let ip: String;
                public let network: UInt8;
                public let port: UInt16;
                public let priority: UInt;
                public let protocolType: ProtocolType;
                public let relAddr: String?;
                public let relPort: UInt16?;
                public let type: CandidateType?;
                public let tcpType: String?;
                
                public convenience init?(from el: Element) {
                    let generation = UInt8(el.getAttribute("generation") ?? "") ?? 0;
                    // workaround for Movim!
                    let id = el.getAttribute("id") ?? UUID().uuidString;
                    
                    guard el.name == "candidate", let foundation = UInt(el.getAttribute("foundation") ?? ""), let component = UInt8(el.getAttribute("component") ?? ""), let ip = el.getAttribute("ip"), let port = UInt16(el.getAttribute("port") ?? ""), let priority = UInt(el.getAttribute("priority") ?? "0"), let proto = ProtocolType(rawValue: el.getAttribute("protocol") ?? "") else {
                        return nil;
                    }
                    
                    let type = CandidateType(rawValue: el.getAttribute("type") ?? "");
                    self.init(component: component, foundation: foundation, generation: generation, id: id, ip: ip, network: 0, port: port, priority: priority, protocolType: proto, type: type, tcpType: el.getAttribute("tcptype"));
                }
                
                public init(component: UInt8, foundation: UInt, generation: UInt8, id: String, ip: String, network: UInt8 = 0, port: UInt16, priority: UInt, protocolType: ProtocolType, relAddr: String? = nil, relPort: UInt16? = nil, type: CandidateType?, tcpType: String?) {
                    self.component = component;
                    self.foundation = foundation;
                    self.generation = generation;
                    self.id = id;
                    self.ip = ip;
                    self.network = network;
                    self.port = port;
                    self.priority = priority;
                    self.protocolType = protocolType;
                    self.relAddr = relAddr;
                    self.relPort = relPort;
                    self.type = type;
                    self.tcpType = tcpType;
                }
                
                public func toElement() -> Element {
                    let el = Element(name: "candidate");
                    
                    el.setAttribute("component", value: String(component));
                    el.setAttribute("foundation", value: String(foundation));
                    el.setAttribute("generation", value: String(generation));
                    el.setAttribute("id", value: id);
                    el.setAttribute("ip", value: ip);
                    el.setAttribute("network", value: String(network));
                    el.setAttribute("port", value: String(port));
                    el.setAttribute("protocol", value: protocolType.rawValue);
                    el.setAttribute("priority", value: String(priority));
                    if relAddr != nil {
                        el.setAttribute("rel-addr", value: relAddr);
                    }
                    if relPort != nil {
                        el.setAttribute("rel-port", value: String(relPort!));
                    }
                    el.setAttribute("type", value: type?.rawValue);
                    el.setAttribute("tcptype", value: tcpType);
                    return el;
                }
                
                public enum ProtocolType: String {
                    case udp
                    case tcp
                }
                
                public enum CandidateType: String {
                    case host
                    case prflx
                    case relay
                    case srflx
                }
            }
            
        }
        
        public class RawUDPTransport: JingleTransport {
            
            public static let XMLNS = "urn:xmpp:jingle:transports:raw-udp:1";
            
            public let xmlns = XMLNS;
            
            public let candidates: [Candidate];
            
            public required convenience init?(from el: Element) {
                guard el.name == "transport" && el.xmlns == RawUDPTransport.XMLNS else {
                    return nil;
                }
                
                self.init(candidates: el.mapChildren(transform: { (child) -> Candidate? in
                    return Candidate(from: child);
                }));
            }
            
            public init(candidates: [Candidate]) {
                self.candidates = candidates;
            }
            
            public func toElement() -> Element {
                let el = Element(name: "transport", xmlns: RawUDPTransport.XMLNS);
                self.candidates.forEach { (candidate) in
                    el.addChild(candidate.toElement());
                }
                return el;
            }
            
            public class Candidate {
                public let component: UInt8;
                public let generation: UInt8;
                public let id: String;
                public let ip: String;
                public let port: UInt16;
                public let type: CandidateType?;
                
                public convenience init?(from el: Element) {
                    guard el.name == "candidate", let component = UInt8(el.getAttribute("component") ?? ""), let generation = UInt8(el.getAttribute("generation") ?? ""), let id = el.getAttribute("id"), let ip = el.getAttribute("ip"), let port = UInt16(el.getAttribute("port") ?? "") else {
                        return nil;
                    }
                    
                    let type = CandidateType(rawValue: el.getAttribute("type") ?? "");
                    self.init(component: component, generation: generation, id: id, ip: ip, port: port, type: type);
                }
                
                public init(component: UInt8, generation: UInt8, id: String, ip: String, port: UInt16, type: CandidateType?) {
                    self.component = component;
                    self.generation = generation;
                    self.id = id;
                    self.ip = ip;
                    self.port = port;
                    self.type = type;
                }
                
                public func toElement() -> Element {
                    let el = Element(name: "candidate");
                    
                    el.setAttribute("component", value: String(component));
                    el.setAttribute("generation", value: String(generation));
                    el.setAttribute("id", value: id);
                    el.setAttribute("ip", value: ip);
                    el.setAttribute("port", value: String(port));
                    el.setAttribute("type", value: type?.rawValue);
                    
                    return el;
                }
                
                public enum CandidateType: String {
                    case host
                    case prflx
                    case relay
                    case srflx
                }
            }
            
        }
    }
}

extension Jingle {
    public class RTP {
        public class Description: JingleDescription {
            
            public let media: String;
            public let ssrc: String?;
            
            public let payloads: [Payload];
            public let bandwidth: String?;
            public let rtcpMux: Bool;
            public let encryption: [Encryption];
            public let ssrcs: [SSRC];
            public let ssrcGroups: [SSRCGroup];
            public let hdrExts: [HdrExt];
            
            public required convenience init?(from el: Element) {
                guard el.name == "description" && el.xmlns == "urn:xmpp:jingle:apps:rtp:1" else {
                    return nil;
                }
                guard let media = el.getAttribute("media") else {
                    return nil;
                }
                
                let payloads = el.mapChildren(transform: { e1 in return Payload(from: e1) });
                let encryption: [Encryption] = Jingle.supportCryptoAttribute ? (el.findChild(name: "encryption")?.mapChildren(transform: { e1 in return Encryption(from: e1) }) ?? []) : [];
                
                let ssrcs = el.mapChildren(transform: { (source) -> SSRC? in
                    return SSRC(from: source);
                });
                let ssrcGroups = el.mapChildren(transform: { (group) -> SSRCGroup? in
                    return SSRCGroup(from: group);
                });
                let hdrExts = el.mapChildren(transform: { HdrExt(from: $0 )});
                
                self.init(media: media, ssrc: el.getAttribute("ssrc"), payloads: payloads, bandwidth: el.findChild(name: "bandwidth")?.getAttribute("type"), encryption: encryption, rtcpMux: el.findChild(name: "rtcp-mux") != nil, ssrcs: ssrcs, ssrcGroups: ssrcGroups, hdrExts: hdrExts);
            }
            
            public init(media: String, ssrc: String? = nil, payloads: [Payload], bandwidth: String? = nil, encryption: [Encryption] = [], rtcpMux: Bool = false, ssrcs: [SSRC], ssrcGroups: [SSRCGroup], hdrExts: [HdrExt]) {
                self.media = media;
                self.ssrc = ssrc;
                self.payloads = payloads;
                self.bandwidth = bandwidth;
                self.encryption = encryption;
                self.rtcpMux = rtcpMux;
                self.ssrcs = ssrcs;
                self.ssrcGroups = ssrcGroups;
                self.hdrExts = hdrExts;
            }
            
            public func toElement() -> Element {
                let el = Element(name: "description", xmlns: "urn:xmpp:jingle:apps:rtp:1");
                el.setAttribute("media", value: media);
                el.setAttribute("ssrc", value: ssrc);
                
                payloads.forEach { (payload) in
                    el.addChild(payload.toElement());
                }
                
                if Jingle.supportCryptoAttribute && !encryption.isEmpty {
                    let encEl = Element(name: "encryption")
                    encryption.forEach { enc in
                        encEl.addChild(enc.toElement());
                    }
                    el.addChild(encEl);
                }
                ssrcGroups.forEach { (group) in
                    el.addChild(group.toElement());
                }
                ssrcs.forEach({ (ssrc) in
                    el.addChild(ssrc.toElement());
                })
                if bandwidth != nil {
                    el.addChild(Element(name: "bandwidth", attributes: ["type": bandwidth!]));
                }
                if rtcpMux {
                    el.addChild(Element(name: "rtcp-mux"));
                }
                hdrExts.forEach({
                    el.addChild($0.toElement());
                })
                return el;
            }
            
            public class Payload {
                public let id: UInt8;
                public let channels: Int;
                public let clockrate: UInt?;
                public let maxptime: UInt?;
                public let name: String?;
                public let ptime: UInt?;
                
                public let parameters: [Parameter]?;
                public let rtcpFeedbacks: [RtcpFeedback]?;
                
                public convenience init?(from el: Element) {
                    guard el.name == "payload-type", let idStr = el.getAttribute("id"), let id = UInt8(idStr) else {
                        return nil;
                    }
                    let parameters = el.mapChildren(transform: { (el) -> Parameter? in
                        return Parameter(from: el);
                    });
                    let rtcpFb = el.mapChildren(transform: { (el) -> RtcpFeedback? in
                        return RtcpFeedback(from: el);
                    });
                    let channels = Int(el.getAttribute("channels") ?? "") ?? 1;
                    self.init(id: id, name: el.getAttribute("name"), clockrate: UInt(el.getAttribute("clockrate") ?? ""), channels: channels, ptime: UInt(el.getAttribute("ptime") ?? ""), maxptime: UInt(el.getAttribute("maxptime") ?? ""), parameters: parameters, rtcpFeedbacks: rtcpFb);
                }
                
                public init(id: UInt8, name: String? = nil, clockrate: UInt? = nil, channels: Int = 1, ptime: UInt? = nil, maxptime: UInt? = nil, parameters: [Parameter]?, rtcpFeedbacks: [RtcpFeedback]?) {
                    self.id = id;
                    self.name = name;
                    self.clockrate = clockrate;
                    self.channels = channels;
                    self.ptime = ptime;
                    self.maxptime = maxptime;
                    self.parameters = parameters;
                    self.rtcpFeedbacks = rtcpFeedbacks;
                }
                
                public func toElement() -> Element {
                    let el = Element(name: "payload-type");
                    
                    el.setAttribute("id", value: String(id));
                    if channels != 1 {
                        el.setAttribute("channels", value: String(channels));
                    }
                    
                    el.setAttribute("name", value: name);
                    
                    if let clockrate = self.clockrate {
                        el.setAttribute("clockrate", value: String(clockrate));
                    }
                    
                    if let ptime = self.ptime {
                        el.setAttribute("ptime", value: String(ptime));
                    }
                    if let maxptime = self.maxptime {
                        el.setAttribute("maxptime", value: String(maxptime));
                    }
                    
                    parameters?.forEach { param in
                        el.addChild(param.toElement());
                    }
                    rtcpFeedbacks?.forEach({ (rtcpFb) in
                        let rtcpFbEl = rtcpFb.toElement();
                        // workaround for Movim!
                        rtcpFbEl.setAttribute("id", value: String(id));
                        el.addChild(rtcpFbEl);
                    })
                    
                    return el;
                }
                
                public class Parameter {
                    
                    public let name: String;
                    public let value: String;
                    
                    public convenience init?(from el: Element) {
                        guard el.name == "parameter" &&  (el.xmlns == "urn:xmpp:jingle:apps:rtp:1" || el.xmlns == nil), let name = el.getAttribute("name"), let value = el.getAttribute("value") else {
                            return nil;
                        }
                        self.init(name: name, value: value);
                    }
                    
                    public init(name: String, value: String) {
                        self.name = name;
                        self.value = value;
                    }
                    
                    public func toElement() -> Element {
                        return Element(name: "parameter", attributes: ["name": name, "value": value, "xmlns": "urn:xmpp:jingle:apps:rtp:1"]);
                    }
                }
                
                public class RtcpFeedback {
                    
                    public let type: String;
                    public let subtype: String?;
                    
                    public convenience init?(from el: Element) {
                        guard el.name == "rtcp-fb" && el.xmlns == "urn:xmpp:jingle:apps:rtp:rtcp-fb:0", let type = el.getAttribute("type") else {
                            return nil;
                        }
                        self.init(type: type, subtype: el.getAttribute("subtype"));
                    }
                    
                    public init(type: String, subtype: String? = nil) {
                        self.type = type;
                        self.subtype = subtype;
                    }
                    
                    public func toElement() -> Element {
                        let el = Element(name: "rtcp-fb", xmlns: "urn:xmpp:jingle:apps:rtp:rtcp-fb:0");
                        el.setAttribute("type", value: type);
                        el.setAttribute("subtype", value: subtype);
                        return el;
                    }
                }
            }
            
            public class Encryption {
                
                public let cryptoSuite: String;
                public let keyParams: String;
                public let sessionParams: String?;
                public let tag: String;
                
                public convenience init?(from el: Element) {
                    guard let cryptoSuite = el.getAttribute("crypto-suite"), let keyParams = el.getAttribute("key-params"), let tag = el.getAttribute("tag") else {
                        return nil;
                    }
                    
                    self.init(cryptoSuite: cryptoSuite, keyParams: keyParams, tag: tag, sessionParams: el.getAttribute("session-params"));
                }
                
                public init(cryptoSuite: String, keyParams: String, tag: String, sessionParams: String? = nil) {
                    self.cryptoSuite = cryptoSuite;
                    self.keyParams = keyParams;
                    self.sessionParams = sessionParams;
                    self.tag = tag;
                }
                
                public func toElement() -> Element {
                    let el = Element(name: "crypto");
                    el.setAttribute("crypto-suite", value: cryptoSuite);
                    el.setAttribute("key-params", value: keyParams);
                    el.setAttribute("session-params", value: sessionParams);
                    el.setAttribute("tag", value: tag);
                    return el;
                }
                
            }
            
            public class HdrExt {

                public let id: String;
                public let uri: String;
                public let senders: Senders;
                
                public convenience init?(from el: Element) {
                    guard el.name == "rtp-hdrext" && el.xmlns == "urn:xmpp:jingle:apps:rtp:rtp-hdrext:0", let id = el.getAttribute("id"), let uri = el.getAttribute("uri") else {
                        return nil;
                    }
                    let senders = Senders(rawValue: el.getAttribute("senders") ?? "") ?? .both;
                    guard senders == .both else {
                        return nil;
                    }
                    self.init(id: id, uri: uri, senders: senders);
                }
                
                public init(id: String, uri: String, senders: Senders) {
                    self.id = id;
                    self.uri = uri;
                    self.senders = senders;
                }
                
                public func toElement() -> Element {
                    let el = Element(name: "rtp-hdrext", xmlns: "urn:xmpp:jingle:apps:rtp:rtp-hdrext:0");
                    el.setAttribute("id", value: id);
                    el.setAttribute("uri", value: uri);
                    switch senders {
                    case .both:
                        break;
                    case .initiator:
                        el.setAttribute("senders", value: "initiator");
                    case .responder:
                        el.setAttribute("senders", value: "responder");
                    }
                    return el;
                }
            }
            
            public enum Senders: String {
                case initiator
                case responder
                case both
            }
            
            public class SSRCGroup {
                public let semantics: String;
                public let sources: [String];
                
                public convenience init?(from el: Element) {
                    guard el.name == "ssrc-group", el.xmlns == "urn:xmpp:jingle:apps:rtp:ssma:0", let semantics = el.getAttribute("semantics") else {
                        return nil;
                    }
                    
                    let sources = el.mapChildren(transform: { (s) -> String? in
                        return s.name == "source" ? s.getAttribute("ssrc") : nil;
                    });
                    guard !sources.isEmpty else {
                        return nil;
                    }
                    self.init(semantics: semantics, sources: sources);
                }
                
                public init(semantics: String, sources: [String]) {
                    self.semantics = semantics;
                    self.sources = sources;
                }
                
                public func toElement() -> Element {
                    let el = Element(name: "ssrc-group", xmlns: "urn:xmpp:jingle:apps:rtp:ssma:0");
                    el.setAttribute("semantics", value: semantics);
                    sources.forEach { (source) in
                        let sel = Element(name: "source");
                        sel.setAttribute("ssrc", value: source);
                        el.addChild(sel);
                    }
                    return el;
                }
            }
            
            public class SSRC {
                
                public let ssrc: String;
                public let parameters: [Parameter];
                
                public init?(from el: Element) {
                    guard el.name == "source" && el.xmlns == "urn:xmpp:jingle:apps:rtp:ssma:0", let ssrc = el.getAttribute("ssrc") ?? el.getAttribute("id") else {
                        return nil;
                    }
                    self.ssrc = ssrc;
                    self.parameters = el.mapChildren(transform: { (p) -> Parameter? in
                        guard p.name == "parameter", let key = p.getAttribute("name") else {
                            return nil;
                        }
                        return Parameter(key: key, value: p.getAttribute("value"));
                    });
                }
                
                public init(ssrc: String, parameters: [Parameter]) {
                    self.ssrc = ssrc;
                    self.parameters = parameters;
                }
                
                public func toElement() -> Element {
                    let el = Element(name: "source", xmlns: "urn:xmpp:jingle:apps:rtp:ssma:0");
                    el.setAttribute("ssrc", value: ssrc);
                    el.setAttribute("id", value: ssrc);
                    parameters.forEach { (param) in
                        let p = Element(name: "parameter");
                        p.setAttribute("name", value: param.key);
                        if param.value != nil {
                            p.setAttribute("value", value: param.value);
                        }
                        el.addChild(p);
                    }
                    return el;
                }
                
                public class Parameter {
                    
                    public let key: String;
                    public let value: String?;
                    
                    public init(key: String, value: String?) {
                        self.key = key;
                        self.value = value;
                    }
                    
                }
            }
            
        }
    }
}
