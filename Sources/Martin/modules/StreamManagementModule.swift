//
// StreamManagementModule.swift
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
import TigaseLogging

extension XmppModuleIdentifier {
    public static var streamManagement: XmppModuleIdentifier<StreamManagementModule> {
        return StreamManagementModule.IDENTIFIER;
    }
}

extension StreamFeatures.StreamFeature {
    public static let sm = StreamFeatures.StreamFeature(name: "sm", xmlns: StreamManagementModule.SM_XMLNS);
}

extension Sasl2InlineStageFeatures.Feature {
    public static let sm3 = Sasl2InlineStageFeatures.Feature(name: "sm", xmlns: "urn:xmpp:sm:3");
}

extension Bind2InlineStageFeatures.Feature {
    public static let sm3 = Bind2InlineStageFeatures.Feature(var: "urn:xmpp:sm:3");
}

/**
 Module implements support for [XEP-0198: Stream Management]
 
 [XEP-0198: Stream Management]: http://xmpp.org/extensions/xep-0198.html
 */
open class StreamManagementModule: XmppModuleBase, XmppModule, Resetable, Sasl2InlineProtocol, @unchecked Sendable {
    
    /// Namespace used by stream management
    static let SM_XMLNS = "urn:xmpp:sm:3";
    
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = SM_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<StreamManagementModule>();
    
    private let logger = Logger(subsystem: "TigaseSwift", category: "StreamManagementModule")
    
    public let features = [String]();
        
    /// Holds queue with stanzas sent but not acked
    private var outgoingQueue = Queue<Item>();
    
    private var lock = UnfairLock();
    private var ackH = AckHolder();

    private var ackEnabled: Bool = false;
    private var resumptionId: String? = nil;
    private var _resumptionLocation: ConnectorEndpoint? = nil;
    private var _resumptionTime: TimeInterval?;
    private var ackTask: Task<Void,Error>?;

    public var isEnabled: Bool {
        get {
            lock.with {
                return ackEnabled;
            }
        }
    }
    
    private var _wasResumed: Bool = false;
    public var wasResumed: Bool {
        get {
            lock.with {
                return _wasResumed;
            }
        }
    }
    
    private var _shouldEnable: Mode;
    open var shouldEnable: Mode {
        get {
            lock.with {
                return _shouldEnable;
            }
        }
        set {
            lock.with {
                _shouldEnable = newValue;
            }
        }
    }
    
    private var lastRequestTimestamp = Date();
    private var lastSentH = UInt32(0);
    
    /// Is stream resumption enabled?
    open var isResumptionEnabled: Bool {
        return lock.with {
            resumptionId != nil
        }
    }
    
    /// Address to use when resuming stream
    open var resumptionLocation: ConnectorEndpoint? {
        return lock.with {
            _resumptionLocation;
        }
    }
    /// Maximal resumption timeout to use
    public let maxResumptionTimeout: Int?;
    
    /// Negotiated resumption timeout
    open var resumptionTime: TimeInterval? {
        return lock.with { _resumptionTime };
    }
    
    open private(set) var isAvailable: Bool = false;
    
    public let ackDelay: TimeInterval;
    private let semaphore = Blocker();
    
    open override var context: Context? {
        didSet {
            store(context?.module(.streamFeatures).$streamFeatures.map({ $0.contains(.sm) }).assign(to: \.isAvailable, on: self));
        }
    }
    
    public init(mode: Mode, maxResumptionTimeout: Int? = nil, ackDelay: TimeInterval = 0.1) {
        self._shouldEnable = mode;
        self.maxResumptionTimeout = maxResumptionTimeout;
        self.ackDelay = ackDelay;
    }
    
    open func process(streamFeatures: StreamFeatures) async throws {
        guard streamFeatures.contains(.sm) else {
            return;
        }
        
        do {
            guard !isEnabled else {
                return;
            }

            guard !isResumptionEnabled else {
                try await resume();
                return;
            }
            
            guard context?.boundJid != nil else {
                return;
            }
            
            switch shouldEnable {
            case .none:
                break;
            case .ack:
                try await enable(resumption: false);
            case .resumption:
                try await enable(resumption: true);
            }
        } catch {
            context?.reset(scopes: [.session]);
            throw error;
        }
    }
    
    /**
     Method tries to enable Stream Management
     - parameter resumption: should resumption be enabled
     - parameter maxResumptionTimeout: maximal resumption timeout to use
     */
    open func enable(resumption: Bool = true, maxResumptionTimeout: Int? = nil) async throws {
        guard !(ackEnabled || isResumptionEnabled) else {
            throw XMPPError(condition: .unexpected_request);
        }
        
        logger.debug("enabling StreamManagament with resume=\(resumption)");
        let enable = Stanza(name: "enable", xmlns: StreamManagementModule.SM_XMLNS, {
            if resumption {
                Attribute("resume", value: "true")
                if let timeout = maxResumptionTimeout ?? self.maxResumptionTimeout {
                    Attribute("max", value: String(timeout));
                }
            }
        });
        
        let response = try await write(stanza: enable, for: .init(names: ["enabled","failed"], xmlns: StreamManagementModule.SM_XMLNS));
        defer {
            semaphore.release();
        }
        switch response.name {
        case "enabled":
            processEnabled(response);
        default:
            try processFailed(response);
        }
    }
    
    open func reset(scopes: Set<ResetableScope>) {
        lock.with {
            ackTask?.cancel();
            ackTask = nil

            if scopes.contains(.stream) {
                ackEnabled = false;
                semaphore.release();
            }
            if scopes.contains(.session) {
                _wasResumed = false;
                ackEnabled = false;
                resumptionId = nil
                _resumptionTime = nil;
                _resumptionLocation = nil;
                ackH.reset();
                let oldOutgoingQueue = outgoingQueue;
                outgoingQueue = Queue<Item>();
                while let item = oldOutgoingQueue.poll() {
                    item.continuation?.resume(throwing: XMPPError(condition: .service_unavailable));
                }
            }
        }
    }
    
    /**
     Method filters incoming stanza to process StreamManagement stanzas.
     - parameter stanza: stanza to process
     */
    open func processIncoming(stanza: Stanza) -> Bool {
        semaphore.waitIfRequired(stanza: stanza);
        
        guard lock.with({ ackEnabled }) else {
            switch stanza.name {
            case "enabled", "failed", "resumed":
                semaphore.startBlocking(items: []);
            default:
                break;
            }
            return false;
        }
        
        guard stanza.xmlns == StreamManagementModule.SM_XMLNS else {
            guard isStanza(stanza) else {
                return false;
            }
            lock.with {
                ackH.incrementIncoming();
            }
           
            if ackTask == nil {
                ackTask = Task {
                    try await Task.sleep(nanoseconds: UInt64(ackDelay * 1000_000_000));
                    self.lock.with {
                        ackTask = nil;
                    }
                    _sendAck(force: true)
                }
            }
            return false;
        }
        
        switch stanza.name {
        case "a":
            processAckAnswer(stanza);
            return true;
        case "r":
            processAckRequest(stanza);
            return true;
        default:
            return false;
        }
    }
    
    /**
     Method processes every outgoing stanza to queue sent
     stanza until they will be acked.
     - parameter stanza: stanza to process
     */
    open func processOutgoing(stanza: Stanza) -> (Bool,Task<Void,Error>?) {
        guard lock.with({ ackEnabled }) else {
            return (false, nil);
        }
        
        guard isStanza(stanza) else {
            return (false, nil);
        }
        
        if let message = stanza as? Message, message.id != nil {
            return (true, Task {
                try await withUnsafeThrowingContinuation({ continuation in
                    _ = self.queueOutgoing(stanza: message, continuation: continuation);
                })
            })
        } else {
            return (self.queueOutgoing(stanza: stanza, continuation: nil), nil)
        }
    }
    
    private struct Item {
        let stanza: Stanza;
        let continuation: UnsafeContinuation<Void,Error>?;
    }
    
    private func queueOutgoing(stanza: Stanza, continuation: UnsafeContinuation<Void,Error>?) -> Bool {
        return lock.with {
            ackH.incrementOutgoing();
            outgoingQueue.offer(.init(stanza: stanza, continuation: continuation));
            if continuation != nil {
                lastRequestTimestamp = Date();
                return true;
            }
            if lastRequestTimestamp.timeIntervalSinceNow >= 1 && outgoingQueue.count > 3 {
                lastRequestTimestamp = Date();
                return true;
            }
            return false;
        }
    }
    
    open func isStanza(_ stanza: Stanza) -> Bool {
        switch stanza.name {
        case "iq", "message", "presence":
            return true;
        default:
            return false;
        }
    }
    
    /// Send ACK request to server
    open func request() {
        lock.with {
            lastRequestTimestamp = Date();
        }
        let r = Stanza(name: "r", xmlns: StreamManagementModule.SM_XMLNS);
        write(stanza: r);
    }
        
    /// Start stream resumption
    open func resume() async throws {
        logger.debug("starting stream resumption");
        let resume = Stanza(name: "resume", xmlns: StreamManagementModule.SM_XMLNS);
        lock.with {
            resume.attribute("h", newValue: String(ackH.incomingCounter));
            resume.attribute("previd", newValue: resumptionId);
        }
        
        let response = try await write(stanza: resume, for: .init(names: ["resumed","failed"], xmlns: StreamManagementModule.SM_XMLNS));
        
        defer {
            semaphore.release();
        }
        switch response.name {
        case "resumed":
            processResumed(response);
        default:
            try processFailed(response);
        }
    }
    
    /// Send ACK to server
    open func sendAck() {
        _sendAck(force: false);
    }
    
    public func featureFor(stage: Sasl2InlineOfferStage) -> Element? {
        switch stage {
        case .afterSasl(let features):
            guard isResumptionEnabled && features.contains(.sm3) else {
                return nil;
            }
            semaphore.startBlocking(items: [.init(xmlns: Sasl2Module.SASL2_XMLNS)])
            return lock.with {
                return Element(name: "resume", xmlns: StreamManagementModule.SM_XMLNS, {
                    Attribute("h", value: String(ackH.incomingCounter))
                    Attribute("previd", value: resumptionId)
                });
            }
        case .afterBind(let features):
            guard shouldEnable != .none && features.contains(.sm3) else {
                return nil;
            }
            semaphore.startBlocking(items: [.init(xmlns: Sasl2Module.SASL2_XMLNS)])
            return Element(name: "enable", xmlns: StreamManagementModule.SM_XMLNS, {
                if shouldEnable == .resumption {
                    Attribute("resume", value: shouldEnable == .resumption ? "true" : nil)
                    if let timeout = maxResumptionTimeout ?? self.maxResumptionTimeout {
                        Attribute("max", value: String(timeout));
                    }
                }
            });
        }
    }

    private class Blocker {
        private var lock = UnfairLock();
        private var blocked: Bool = false;
        private let semaphore = DispatchSemaphore(value: 0);
        private var blockUnless: BlockUnless?;
        
        func waitIfRequired(stanza: Stanza) {
            guard lock.with({
                guard let blockUnless = self.blockUnless, blockUnless.shouldBlock(stanza: stanza) else {
                    return false;
                }
                self.blocked = true;
                return true;
            }) else {
                return;
            }
            semaphore.wait();
        }
        
        func startBlocking(items: [BlockUnlessItem]) {
            lock.with({
                self.blockUnless = BlockUnless(items: items);
            })
        }
        
        func release() {
            guard lock.with({
                self.blockUnless = nil;
                guard blocked else {
                    return false;
                }
                blocked = false;
                return true;
            }) else {
                return;
            }
            semaphore.signal();
        }
        
    }
    
    private struct BlockUnless {
        let items: [BlockUnlessItem];
        
        func shouldBlock(stanza: Stanza) -> Bool {
            for item in items {
                if item.matches(stanza: stanza) {
                    return false;
                }
            }
            return true;
        }
    }
    
    private struct BlockUnlessItem {
        let name: String?;
        let xmlns: String?;
        
        init(name: String? = nil, xmlns: String? = nil) {
            self.name = name
            self.xmlns = xmlns
        }
        
        func matches(stanza: Stanza) -> Bool {
            if let name = name {
                return stanza.name == name && (xmlns == nil || stanza.xmlns == xmlns);
            } else {
                return stanza.xmlns == xmlns;
            }
        }
    }
    
    public func process(result: Element, for stage: Sasl2InlineResultStage) {
        switch stage {
        case .afterSasl:
            guard let response = result.firstChild(xmlns: StreamManagementModule.SM_XMLNS) else {
                return;
            }
            switch response.name {
            case "resumed":
                processResumed(Stanza(element: response));
                semaphore.release();
            case "failed":
                context?.reset(scopes: [.session]);
            default:
                break;
            }
        case .afterBind:
            defer {
                semaphore.release();
            }
            guard let enabled = result.firstChild(name: "enabled", xmlns: StreamManagementModule.SM_XMLNS) else {
                reset(scopes: [.stream,.session]);
                return;
            }
            processEnabled(Stanza(element: enabled));
        }
    }
    
    private func _sendAck(force: Bool) {
        guard let a = prepareAck(force: false) else {
            return;
        }
        write(stanza: a);
    }
    
    // call only from internal queue
    private func prepareAck(force: Bool) -> Stanza? {
        lock.with {
            guard force || lastSentH != ackH.incomingCounter else {
                return nil;
            }
        
            let value = ackH.incomingCounter;
            lastSentH = value;
        
            let a = Stanza(name: "a", xmlns: StreamManagementModule.SM_XMLNS);
            a.attribute("h", newValue: String(value));
            return a;
        }
    }
    
    /// Process ACK from server
    private func processAckAnswer(_ stanza: Stanza) {
        guard let attr = stanza.attribute("h") else {
            return;
        }
        let newH = UInt32(attr) ?? 0;
        lock.with {
            ackEnabled = true;
            let left = max(Int(ackH.outgoingCounter) - Int(newH), 0);
            ackH.outgoingCounter = newH;
            while left < outgoingQueue.count {
                outgoingQueue.poll()?.continuation?.resume();
            }
        }
    }
    
    /// Process ACK request from server
    private func processAckRequest(_ stanza: Stanza) {
        Task {
            try await Task.sleep(nanoseconds: 100_000_000)
            guard let a = self.prepareAck(force: true) else {
                return;
            }
            try await self.write(stanza: a);
        }
    }
    
    private func processFailed(_ stanza: Stanza) throws {
        reset(scopes: [.stream,.session]);
        
        logger.debug("stream resumption failed");
        
        throw XMPPError(condition: stanza.firstChild(xmlns: "urn:ietf:params:xml:ns:xmpp-stanzas").map({ ErrorCondition.init(rawValue: $0.name) ?? .undefined_condition }) ?? .undefined_condition);
    }
    
    private func processResumed(_ stanza: Stanza) {
        let newH = UInt32(stanza.attribute("h")!) ?? 0;
        let oldOutgoingQueue: Queue<Item> = lock.with {
            ackEnabled = true;
            _wasResumed = true;
            let left = max(Int(ackH.outgoingCounter) - Int(newH), 0);
            while left < outgoingQueue.count {
                outgoingQueue.poll()?.continuation?.resume();
            }
            ackH.outgoingCounter = newH;
            defer {
                outgoingQueue = Queue<Item>();
            }
            return outgoingQueue;
        }
        while let item = oldOutgoingQueue.poll() {
            write(stanza: item.stanza);
        }
        
        logger.debug("stream resumed");
    }
    
    private func processEnabled(_ stanza: Stanza) {
        let id = stanza.attribute("id");
        let _ = stanza.attribute("resume");
        let max = stanza.attribute("max");
        //let resume = (r == "true" || r == "1") && id != nil;
        lock.with {
            _resumptionLocation = (self.context as? XMPPClient)?.connector?.prepareEndpoint(withResumptionLocation: stanza.attribute("location"))
            
            resumptionId = id;
            ackEnabled = true;
            if let max = max {
                _resumptionTime = Double(max);
            }
        }
        
        logger.debug("stream management enabled");
    }
    
    /// Internal class for holding incoming and outgoing counters
    class AckHolder {
        
        var incomingCounter: UInt32 = 0;
        var outgoingCounter: UInt32 = 0;
        
        func reset() {
            incomingCounter = 0;
            outgoingCounter = 0;
        }
        
        func incrementOutgoing() {
            outgoingCounter += 1;
        }
        
        func incrementIncoming() {
            incomingCounter += 1;
        }
        
    }
    
    public enum Mode {
        case none
        case ack
        case resumption
    }

}


/// Internal implementation of queue for holding items
public class Queue<T> {
    
    private class Node {
        
        let value: T;
        weak var prev: Node? = nil;
        var next: Node? = nil;
        
        init(value: T) {
            self.value = value;
        }
        
    }
    
    private var _count: Int = 0;
    private var head: Node? = nil;
    private var tail: Node? = nil;
    
    public var isEmpty: Bool {
        return head == nil;
    }
    
    open var count: Int {
        return _count;
    }
    
    public init() {
    }
    
    open func clear() {
        head = nil;
        tail = nil;
        _count = 0;
    }
    
    open func offer(_ value: T) {
        let newNode = Node(value: value);
        if let tailNode = tail {
            newNode.prev = tailNode;
            tailNode.next = newNode;
        } else {
            head = newNode;
        }
        
        tail = newNode;
        self._count += 1;
    }
    
    open func peek() -> T? {
        return head?.value;
    }
    
    open func poll() -> T? {
        defer {
            head = head?.next;
            if head == nil {
                tail = nil;
            }
            _count -= 1;
        }
        
        return head?.value;
    }
}

// async-await support
extension StreamManagementModule {
    
    public func enable(resumption: Bool = true, maxResumptionTimeout: Int? = nil, completionHandler: ( (Result<String?,XMPPError>)->Void)?) {
        Task {
            do {
                try await enable(resumption: resumption, maxResumptionTimeout: maxResumptionTimeout);
                completionHandler?(.success(self.resumptionId))
            } catch {
                completionHandler?(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func resume(completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                try await resume();
                completionHandler(.success(Void()))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }

}
