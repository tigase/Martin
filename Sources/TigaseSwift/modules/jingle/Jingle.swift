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

public protocol CustomElementConvertible {
    
    func element() -> Element
    
}

public class Jingle {
    
    public static var supportCryptoAttribute = false;
    
    public struct Bundle: CustomElementConvertible, Sendable {
        
        public let names: [String];
        
        public init?(_ names: [String]?) {
            guard let names = names else {
                return nil;
            }
            self.names = names;
        }
        
        public init(_ names: [String]) {
            self.names = names;
        }
        
        public init?(jingle: Element) {
            guard let names = jingle.firstChild(name: "group", xmlns: "urn:xmpp:jingle:apps:grouping:0")?.filterChildren(name: "content").compactMap({ $0.attribute("name" )}) else {
                return nil;
            }
            self.names = names;
        }
        
        public func element() -> Element {
            return Element(name: "group", xmlns: "urn:xmpp:jingle:apps:grouping:0", {
                Attribute("semantics", value: "BUNDLE")
                for name in names {
                    Element(name: "content", attributes: ["name": name])
                }
            });
        }
        
    }
    
    public class Content: CustomElementConvertible, @unchecked Sendable {
        
        public let creator: Creator;
        public let name: String;
        public let senders: Senders?;
        public let description: JingleDescription?;
        public let transports: [JingleTransport];
        
        public required convenience init?(from el: Element, knownDescriptions: [JingleDescription.Type], knownTransports: [JingleTransport.Type]) {
            guard el.name == "content", let name = el.attribute("name"), let creator = Creator(rawValue: el.attribute("creator") ?? "") else {
                return nil;
            }
            
            var senders: Senders? = nil;
            if let sendersStr = el.attribute("senders") {
                senders = Senders(rawValue: sendersStr);
            }
            
            let descEl = el.firstChild(name: "description");
            let description = descEl == nil ? nil : knownDescriptions.map({ (desc) -> JingleDescription? in
                return desc.init(from: descEl!);
            }).filter({ desc -> Bool in return desc != nil}).map({ desc -> JingleDescription in return desc! }).first;
            
            let foundTransports = el.compactMapChildren({ child -> JingleTransport? in
                let transports = knownTransports.compactMap({ $0.init(from: child) });
                return transports.first;
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
        
        public func element() -> Element {
            return Element(name: "content", {
                Attribute("creator", value: creator.rawValue)
                Attribute("name", value: name)
                Attribute("senders", value: senders?.rawValue)
                description?.element()
                for transport in transports {
                    transport.element();
                }
            });
        }
        
        public enum Creator: String, Sendable {
            case initiator
            case responder
        }
        
        public enum Senders: String, Sendable {
            case none
            case initiator
            case responder
            case both
        }
        
    }
}

public protocol JingleDescription: CustomElementConvertible, Sendable {
    
    var media: String { get };
    
    init?(from el: Element);
    
}

public protocol JingleTransport: CustomElementConvertible, Sendable {
    
    var xmlns: String { get }
    
    init?(from el: Element);
    
}

extension Jingle {
    
    public enum Action: String, Sendable {
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
    
    public enum ContentAction: Sendable {
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
    public enum SessionInfo: Sendable {
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
                return .mute(contentName: el.attribute("name"));
            case "unmute":
                return .unmute(contentName: el.attribute("name"));
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
                    el.attribute("creator", newValue: creatorProvider(contentName).rawValue);
                    el.attribute("name", newValue: contentName);
                }
            case .unmute(let cname):
                if let contentName = cname {
                    el.attribute("creator", newValue: creatorProvider(contentName).rawValue);
                    el.attribute("name", newValue: contentName);
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
        
        public class ICEUDPTransport: JingleTransport, @unchecked Sendable {
            
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
                let pwd = el.attribute("pwd");
                let ufrag = el.attribute("ufrag");
                
                self.init(pwd: pwd, ufrag: ufrag, candidates: el.filterChildren(name: "candidate").compactMap(Candidate.init(from:)), fingerprint: Fingerprint(from: el.firstChild(name: "fingerprint", xmlns: "urn:xmpp:jingle:apps:dtls:0")));
            }
            
            public init(pwd: String?, ufrag: String?, candidates: [Candidate], fingerprint: Fingerprint? = nil) {
                self.pwd = pwd;
                self.ufrag = ufrag;
                self.candidates = candidates;
                self.fingerprint = fingerprint;
            }
            
            public func element() -> Element {
                return Element(name: "transport", xmlns: ICEUDPTransport.XMLNS, {
                    Attribute("ufrag", value: self.ufrag)
                    Attribute("pwd", value: self.pwd)
                    fingerprint?.element()
                    for candidate in candidates {
                        candidate.element();
                    }
                });
            }
            
            public class Fingerprint: CustomElementConvertible, @unchecked Sendable {
                public let hash: String;
                public let value: String;
                public let setup: Setup;
                
                public convenience init?(from elem: Element?) {
                    guard let el = elem else {
                        return nil;
                    }
                    guard let hash = el.attribute("hash"), let value = el.value, let setup = Setup(rawValue: el.attribute("setup") ?? "") else {
                        return nil;
                    }
                    self.init(hash: hash, value: value, setup: setup);
                }
                
                public init(hash: String, value: String, setup: Setup) {
                    self.hash = hash;
                    self.value = value;
                    self.setup = setup;
                }
                
                public func element() -> Element {
                    return Element(name: "fingerprint", xmlns: "urn:xmpp:jingle:apps:dtls:0", cdata: value, {
                        Attribute("hash", value: hash)
                        Attribute("setup", value: setup.rawValue)
                    })
                }
                
                public enum Setup: String {
                    case actpass
                    case active
                    case passive
                }
            }
            
            public class Candidate: CustomElementConvertible, @unchecked Sendable {
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
                    let generation = UInt8(el.attribute("generation") ?? "") ?? 0;
                    // workaround for Movim!
                    let id = el.attribute("id") ?? UUID().uuidString;
                    
                    guard el.name == "candidate", let foundation = UInt(el.attribute("foundation") ?? ""), let component = UInt8(el.attribute("component") ?? ""), let ip = el.attribute("ip"), let port = UInt16(el.attribute("port") ?? ""), let priority = UInt(el.attribute("priority") ?? "0"), let proto = ProtocolType(rawValue: el.attribute("protocol") ?? "") else {
                        return nil;
                    }
                    
                    let type = CandidateType(rawValue: el.attribute("type") ?? "");
                    self.init(component: component, foundation: foundation, generation: generation, id: id, ip: ip, network: 0, port: port, priority: priority, protocolType: proto, type: type, tcpType: el.attribute("tcptype"));
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
                
                public func element() -> Element {
                    return Element(name: "candidate", {
                        Attribute("component", value: String(component))
                        Attribute("foundation", value: String(foundation))
                        Attribute("generation", value: String(generation))
                        Attribute("id", value: id)
                        Attribute("ip", value: ip)
                        Attribute("network", value: String(network))
                        Attribute("port", value: String(port))
                        Attribute("protocol", value: protocolType.rawValue)
                        Attribute("priority", value: String(priority))
                        Attribute("rel-addr", value: relAddr);
                        if let relPort = relPort {
                            Attribute("rel-port", value: String(relPort));
                        }
                        Attribute("type", value: type?.rawValue)
                        Attribute("tcptype", value: tcpType);
                    });
                }
                
                public enum ProtocolType: String, Sendable {
                    case udp
                    case tcp
                }
                
                public enum CandidateType: String, Sendable {
                    case host
                    case prflx
                    case relay
                    case srflx
                }
            }
            
        }
        
        public class RawUDPTransport: JingleTransport, @unchecked Sendable {
            
            public static let XMLNS = "urn:xmpp:jingle:transports:raw-udp:1";
            
            public let xmlns = XMLNS;
            
            public let candidates: [Candidate];
            
            public required convenience init?(from el: Element) {
                guard el.name == "transport" && el.xmlns == RawUDPTransport.XMLNS else {
                    return nil;
                }
                
                self.init(candidates: el.compactMapChildren(Candidate.init(from:)));
            }
            
            public init(candidates: [Candidate]) {
                self.candidates = candidates;
            }
            
            public func element() -> Element {
                return Element(name: "transport", xmlns: RawUDPTransport.XMLNS, children: candidates.map({ $0.element() }))
            }
            
            public class Candidate: @unchecked Sendable {
                public let component: UInt8;
                public let generation: UInt8;
                public let id: String;
                public let ip: String;
                public let port: UInt16;
                public let type: CandidateType?;
                
                public convenience init?(from el: Element) {
                    guard el.name == "candidate", let component = UInt8(el.attribute("component") ?? ""), let generation = UInt8(el.attribute("generation") ?? ""), let id = el.attribute("id"), let ip = el.attribute("ip"), let port = UInt16(el.attribute("port") ?? "") else {
                        return nil;
                    }
                    
                    let type = CandidateType(rawValue: el.attribute("type") ?? "");
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
                
                public func element() -> Element {
                    let el = Element(name: "candidate");
                    
                    el.attribute("component", newValue: String(component));
                    el.attribute("generation", newValue: String(generation));
                    el.attribute("id", newValue: id);
                    el.attribute("ip", newValue: ip);
                    el.attribute("port", newValue: String(port));
                    el.attribute("type", newValue: type?.rawValue);
                    
                    return el;
                }
                
                public enum CandidateType: String, Sendable {
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
        public class Description: JingleDescription, @unchecked Sendable {
            
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
                guard let media = el.attribute("media") else {
                    return nil;
                }
                
                let payloads = el.compactMapChildren(Payload.init(from:));
                let encryption: [Encryption] = Jingle.supportCryptoAttribute ? (el.firstChild(name: "encryption")?.compactMapChildren(Encryption.init(from:)) ?? []) : [];
                
                let ssrcs = el.compactMapChildren(SSRC.init(from:));
                let ssrcGroups = el.compactMapChildren(SSRCGroup.init(from:));
                let hdrExts = el.compactMapChildren(HdrExt.init(from:));
                
                self.init(media: media, ssrc: el.attribute("ssrc"), payloads: payloads, bandwidth: el.firstChild(name: "bandwidth")?.attribute("type"), encryption: encryption, rtcpMux: el.firstChild(name: "rtcp-mux") != nil, ssrcs: ssrcs, ssrcGroups: ssrcGroups, hdrExts: hdrExts);
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
            
            public func element() -> Element {
                return Element(name: "description", xmlns: "urn:xmpp:jingle:apps:rtp:1", {
                    Attribute("media", value: media)
                    Attribute("ssrc", value: ssrc)
                    payloads.map({ $0.element() })
                    if Jingle.supportCryptoAttribute && !encryption.isEmpty {
                        Element(name: "encryption", {
                            encryption.map({ $0.element() })
                        })
                    }
                    ssrcGroups.map({ $0.element() })
                    ssrcs.map({ $0.element() })
                    if let bandwidth = bandwidth {
                        Element(name: "bandwidth", attributes: ["type": bandwidth])
                    }
                    if rtcpMux {
                        Element(name: "rtcp-mux")
                    }
                    hdrExts.map({ $0.element() })
                });
            }
            
            public class Payload: CustomElementConvertible, @unchecked Sendable {
                public let id: UInt8;
                public let channels: Int;
                public let clockrate: UInt?;
                public let maxptime: UInt?;
                public let name: String?;
                public let ptime: UInt?;
                
                public let parameters: [Parameter]?;
                public let rtcpFeedbacks: [RtcpFeedback]?;
                
                public convenience init?(from el: Element) {
                    guard el.name == "payload-type", let idStr = el.attribute("id"), let id = UInt8(idStr) else {
                        return nil;
                    }
                    let parameters = el.compactMapChildren(Parameter.init(from:));
                    let rtcpFb = el.compactMapChildren(RtcpFeedback.init(from:));
                    let channels = Int(el.attribute("channels") ?? "") ?? 1;
                    self.init(id: id, name: el.attribute("name"), clockrate: UInt(el.attribute("clockrate") ?? ""), channels: channels, ptime: UInt(el.attribute("ptime") ?? ""), maxptime: UInt(el.attribute("maxptime") ?? ""), parameters: parameters, rtcpFeedbacks: rtcpFb);
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
                
                public func element() -> Element {
                    return Element(name: "payload-type", {
                        Attribute("id", value: String(id))
                        if channels != 1 {
                            Attribute("channels", value: String(channels))
                        }
                        Attribute("name", value: name)
                        if let clockrate = self.clockrate {
                           Attribute("clockrate", value: String(clockrate));
                        }
                        
                        if let ptime = self.ptime {
                            Attribute("ptime", value: String(ptime));
                        }
                        if let maxptime = self.maxptime {
                            Attribute("maxptime", value: String(maxptime));
                        }
                        parameters?.map({ $0.element() })
                        rtcpFeedbacks?.map({
                            let rtcpFbEl = $0.element();
                            rtcpFbEl.attribute("id", newValue: String(id));
                            return rtcpFbEl;
                        })
                    });
                }
                
                public class Parameter: CustomElementConvertible, @unchecked Sendable {
                    
                    public let name: String;
                    public let value: String;
                    
                    public convenience init?(from el: Element) {
                        guard el.name == "parameter" &&  (el.xmlns == "urn:xmpp:jingle:apps:rtp:1" || el.xmlns == nil), let name = el.attribute("name"), let value = el.attribute("value") else {
                            return nil;
                        }
                        self.init(name: name, value: value);
                    }
                    
                    public init(name: String, value: String) {
                        self.name = name;
                        self.value = value;
                    }
                    
                    public func element() -> Element {
                        return Element(name: "parameter", attributes: ["name": name, "value": value, "xmlns": "urn:xmpp:jingle:apps:rtp:1"]);
                    }
                }
                
                public class RtcpFeedback: CustomElementConvertible, @unchecked Sendable {
                    
                    public let type: String;
                    public let subtype: String?;
                    
                    public convenience init?(from el: Element) {
                        guard el.name == "rtcp-fb" && el.xmlns == "urn:xmpp:jingle:apps:rtp:rtcp-fb:0", let type = el.attribute("type") else {
                            return nil;
                        }
                        self.init(type: type, subtype: el.attribute("subtype"));
                    }
                    
                    public init(type: String, subtype: String? = nil) {
                        self.type = type;
                        self.subtype = subtype;
                    }
                    
                    public func element() -> Element {
                        let el = Element(name: "rtcp-fb", xmlns: "urn:xmpp:jingle:apps:rtp:rtcp-fb:0");
                        el.attribute("type", newValue: type);
                        el.attribute("subtype", newValue: subtype);
                        return el;
                    }
                }
            }
            
            public class Encryption: CustomElementConvertible, @unchecked Sendable {
                
                public let cryptoSuite: String;
                public let keyParams: String;
                public let sessionParams: String?;
                public let tag: String;
                
                public convenience init?(from el: Element) {
                    guard let cryptoSuite = el.attribute("crypto-suite"), let keyParams = el.attribute("key-params"), let tag = el.attribute("tag") else {
                        return nil;
                    }
                    
                    self.init(cryptoSuite: cryptoSuite, keyParams: keyParams, tag: tag, sessionParams: el.attribute("session-params"));
                }
                
                public init(cryptoSuite: String, keyParams: String, tag: String, sessionParams: String? = nil) {
                    self.cryptoSuite = cryptoSuite;
                    self.keyParams = keyParams;
                    self.sessionParams = sessionParams;
                    self.tag = tag;
                }
                
                public func element() -> Element {
                    let el = Element(name: "crypto");
                    el.attribute("crypto-suite", newValue: cryptoSuite);
                    el.attribute("key-params", newValue: keyParams);
                    el.attribute("session-params", newValue: sessionParams);
                    el.attribute("tag", newValue: tag);
                    return el;
                }
                
            }
            
            public class HdrExt: CustomElementConvertible, @unchecked Sendable {

                public let id: String;
                public let uri: String;
                public let senders: Senders;
                
                public convenience init?(from el: Element) {
                    guard el.name == "rtp-hdrext" && el.xmlns == "urn:xmpp:jingle:apps:rtp:rtp-hdrext:0", let id = el.attribute("id"), let uri = el.attribute("uri") else {
                        return nil;
                    }
                    let senders = Senders(rawValue: el.attribute("senders") ?? "") ?? .both;
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
                
                public func element() -> Element {
                    let el = Element(name: "rtp-hdrext", xmlns: "urn:xmpp:jingle:apps:rtp:rtp-hdrext:0");
                    el.attribute("id", newValue: id);
                    el.attribute("uri", newValue: uri);
                    switch senders {
                    case .both:
                        break;
                    case .initiator:
                        el.attribute("senders", newValue: "initiator");
                    case .responder:
                        el.attribute("senders", newValue: "responder");
                    }
                    return el;
                }
            }
            
            public enum Senders: String, Sendable {
                case initiator
                case responder
                case both
            }
            
            public class SSRCGroup: CustomElementConvertible, @unchecked Sendable {
                public let semantics: String;
                public let sources: [String];
                
                public convenience init?(from el: Element) {
                    guard el.name == "ssrc-group", el.xmlns == "urn:xmpp:jingle:apps:rtp:ssma:0", let semantics = el.attribute("semantics") else {
                        return nil;
                    }
                    
                    let sources = el.filterChildren(name: "source").compactMap({ $0.attribute("ssrc") });
                    guard !sources.isEmpty else {
                        return nil;
                    }
                    self.init(semantics: semantics, sources: sources);
                }
                
                public init(semantics: String, sources: [String]) {
                    self.semantics = semantics;
                    self.sources = sources;
                }
                
                public func element() -> Element {
                    return Element(name: "ssrc-group", xmlns: "urn:xmpp:jingle:apps:rtp:ssma:0", {
                        Attribute("semantics", value: semantics)
                        for source in sources {
                            Element(name: "source", {
                                Attribute("ssrc", value: source)
                            })
                        }
                    });
                }
            }
            
            public class SSRC: CustomElementConvertible, @unchecked Sendable {
                
                public let ssrc: String;
                public let parameters: [Parameter];
                
                public init?(from el: Element) {
                    guard el.name == "source" && el.xmlns == "urn:xmpp:jingle:apps:rtp:ssma:0", let ssrc = el.attribute("ssrc") ?? el.attribute("id") else {
                        return nil;
                    }
                    self.ssrc = ssrc;
                    self.parameters = el.filterChildren(name: "parameter").compactMap({ p -> Parameter? in
                        guard let key = p.attribute("name") else {
                            return nil;
                        }
                        return Parameter(key: key, value: p.attribute("value"));
                    });
                }
                
                public init(ssrc: String, parameters: [Parameter]) {
                    self.ssrc = ssrc;
                    self.parameters = parameters;
                }
                
                public func element() -> Element {
                    return Element(name: "source", xmlns: "urn:xmpp:jingle:apps:rtp:ssma:0", {
                        Attribute("ssrc", value: ssrc)
                        Attribute("id", value: ssrc)
                        parameters.map({ $0.element() })
                    });
                }
                
                public class Parameter: CustomElementConvertible, @unchecked Sendable {
                    
                    public let key: String;
                    public let value: String?;
                    
                    public init(key: String, value: String?) {
                        self.key = key;
                        self.value = value;
                    }
                    
                    public func element() -> Element {
                        return Element(name: "parameter", {
                            Attribute("name", value: key)
                            Attribute("value", value: value);
                        });
                    }
                    
                }
            }
            
        }
    }
}
