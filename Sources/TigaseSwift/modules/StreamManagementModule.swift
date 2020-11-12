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

/**
 Module implements support for [XEP-0198: Stream Management]
 
 [XEP-0198: Stream Management]: http://xmpp.org/extensions/xep-0198.html
 */
open class StreamManagementModule: XmppModuleBase, XmppModule, XmppStanzaFilter, EventHandler {
    
    /// Namespace used by stream management
    static let SM_XMLNS = "urn:xmpp:sm:3";
    
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = SM_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<StreamManagementModule>();
    
    private let logger = Logger(subsystem: "TigaseSwift", category: "StreamManagementModule")
    
    public let criteria = Criteria.xmlns(SM_XMLNS);
    
    public let features = [String]();
    
    open override weak var context: Context? {
        didSet {
            if let oldValue = oldValue {
                oldValue.eventBus.unregister(handler: self, for: SessionObject.ClearedEvent.TYPE);
            }
            if let context = context {
                context.eventBus.register(handler: self, for: SessionObject.ClearedEvent.TYPE);
            }
        }
    }
    
    /// Holds queue with stanzas sent but not acked
    fileprivate var outgoingQueue = Queue<Stanza>();
    
    // TODO: should this stay here or be moved to sessionObject as in Jaxmpp?
    fileprivate var ackH = AckHolder();

    fileprivate var _ackEnabled: Bool = false;
    /// Is ACK enabled?
    open var ackEnabled: Bool {
        return _ackEnabled;
    }
    
    fileprivate var lastRequestTimestamp = Date();
    fileprivate var lastSentH = UInt32(0);
    
    /// Is stream resumption enabled?
    open var resumptionEnabled: Bool {
        return resumptionId != nil
    }
    
    fileprivate var resumptionId: String? = nil;
    
    fileprivate var _resumptionLocation: XMPPSrvRecord? = nil;
    /// Address to use when resuming stream
    open var resumptionLocation: XMPPSrvRecord? {
        return _resumptionLocation;
    }
    /// Maximal resumption timeout to use
    open var maxResumptionTimeout: Int?;
    
    fileprivate var _resumptionTime: TimeInterval?;
    /// Negotiated resumption timeout
    open var resumptionTime: TimeInterval? {
        return _resumptionTime;
    }
    
    public override init() {
    }
    
    /**
     Method tries to enable Stream Management
     - parameter resumption: should resumption be enabled
     - parameter maxResumptionTimeout: maximal resumption timeout to use
     */
    open func enable(resumption: Bool = true, maxResumptionTimeout: Int? = nil) {
        guard !(ackEnabled || resumptionEnabled) else {
            return;
        }
        
        logger.debug("enabling StreamManagament with resume=\(resumption)");
        let enable = Stanza(name: "enable", xmlns: StreamManagementModule.SM_XMLNS);
        if resumption {
            enable.setAttribute("resume", value: "true");
            let timeout = maxResumptionTimeout ?? self.maxResumptionTimeout;
            if timeout != nil {
                enable.setAttribute("max", value: String(timeout!));
            }
        }
        
        write(enable);
    }
    
    /**
     Method hadles events received from `EventBus`
     */
    open func handle(event: Event) {
        switch event {
        case let e as SessionObject.ClearedEvent:
            for scope in e.scopes {
                switch scope {
                case .stream:
                    _ackEnabled = false;
                case .session:
                    reset();
                default:
                    break;
                }
            }
        default:
            break;
        }
    }
    
    /**
     Check if Stream Management is supported on server
     - returns: true - if is supported
     */
    open func isAvailable() -> Bool {
        return context?.module(.streamFeatures).streamFeatures?.findChild(name: "sm", xmlns: StreamManagementModule.SM_XMLNS) != nil;
    }
    
    open func process(stanza: Stanza) throws {
        // all requests should be processed already
        throw ErrorCondition.undefined_condition;
    }
    
    /**
     Method filters incoming stanza to process StreamManagement stanzas.
     - parameter stanza: stanza to process
     */
    open func processIncoming(stanza: Stanza) -> Bool {
        guard ackEnabled else {
            guard stanza.xmlns == StreamManagementModule.SM_XMLNS else {
                return false;
            }
            
            switch stanza.name {
            case "resumed":
                processResumed(stanza);
            case "failed":
                processFailed(stanza);
            case "enabled":
                processEnabled(stanza);
            default:
                break;
            }
            return true;
        }
        
        guard stanza.xmlns == StreamManagementModule.SM_XMLNS else {
            ackH.incrementIncoming();
            if lastSentH + 5 <= ackH.incomingCounter {
                sendAck();
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
        //return false;
    }
    
    /**
     Method processes every outgoing stanza to queue sent
     stanza until they will be acked.
     - parameter stanza: stanza to process
     */
    open func processOutgoing(stanza: Stanza) {
        guard ackEnabled else {
            return;
        }
        
        if stanza.xmlns == StreamManagementModule.SM_XMLNS {
            switch stanza.name {
            case "a", "r":
                return;
            default:
                break;
            }
        }
        
        ackH.incrementOutgoing();
        outgoingQueue.offer(stanza);
        if (outgoingQueue.count > 3) {
            request();
        }
    }
    
    /// Send ACK request to server
    open func request() {
        guard lastRequestTimestamp.timeIntervalSinceNow < 1 else {
            return;
        }
        
        let r = Stanza(name: "r", xmlns: StreamManagementModule.SM_XMLNS);
        write(r);
        lastRequestTimestamp = Date();
    }
    
    /// Reset all internal variables
    open func reset() {
        _ackEnabled = false;
        resumptionId = nil
        _resumptionTime = nil;
        _resumptionLocation = nil;
        ackH.reset();
        outgoingQueue.clear();
    }
    
    /// Start stream resumption
    open func resume() {
        logger.debug("starting stream resumption");
        let resume = Stanza(name: "resume", xmlns: StreamManagementModule.SM_XMLNS);
        resume.setAttribute("h", value: String(ackH.incomingCounter));
        resume.setAttribute("previd", value: resumptionId);
        
        write(resume);
    }
    
    /// Send ACK to server
    open func sendAck() {
        guard let a = prepareAck() else {
            return;
        }
        write(a);
    }
    
    func prepareAck() -> Stanza? {
        guard lastSentH != ackH.incomingCounter else {
            return nil;
        }
        
        let value = ackH.incomingCounter;
        lastSentH = value;
        
        let a = Stanza(name: "a", xmlns: StreamManagementModule.SM_XMLNS);
        a.setAttribute("h", value: String(value));
        return a;
    }
    
    /// Process ACK from server
    func processAckAnswer(_ stanza: Stanza) {
        guard let attr = stanza.getAttribute("h") else {
            return;
        }
        let newH = UInt32(attr) ?? 0;
        _ackEnabled = true;
        let left = max(Int(ackH.outgoingCounter) - Int(newH), 0);
        ackH.outgoingCounter = newH;
        while left < outgoingQueue.count {
            _ = outgoingQueue.poll();
        }
    }
    
    /// Process ACK request from server
    func processAckRequest(_ stanza: Stanza) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let value = self.ackH.incomingCounter;
            self.lastSentH = value;
            
            let a = Stanza(name: "a", xmlns: StreamManagementModule.SM_XMLNS);
            a.setAttribute("h", value: String(value));
            self.write(a);
        }
    }
    
    func processFailed(_ stanza: Stanza) {
        reset();
        
        let errorCondition = stanza.errorCondition ?? ErrorCondition.unexpected_request;
        
        logger.debug("stream resumption failed");
        if let context = context {
            fire(FailedEvent(context: context, errorCondition: errorCondition));
        }
    }
    
    func processResumed(_ stanza: Stanza) {
        let newH = UInt32(stanza.getAttribute("h")!) ?? 0;
        _ackEnabled = true;
        let left = max(Int(ackH.outgoingCounter) - Int(newH), 0);
        while left < outgoingQueue.count {
            _ = outgoingQueue.poll();
        }
        ackH.outgoingCounter = newH;
        let oldOutgoingQueue = outgoingQueue;
        outgoingQueue = Queue<Stanza>();
        while let s = oldOutgoingQueue.poll() {
            write(s);
        }
        
        logger.debug("stream resumed");
        if let context = context {
            fire(ResumedEvent(context: context, newH: newH, resumeId: stanza.getAttribute("previd")));
        }
    }
    
    func processEnabled(_ stanza: Stanza) {
        let id = stanza.getAttribute("id");
        let r = stanza.getAttribute("resume");
        let mx = stanza.getAttribute("max");
        let resume = r == "true" || r == "1";
        if let location = SocketConnector.preprocessConnectionDetails(string: stanza.getAttribute("location")), let details: XMPPSrvRecord = self.context?.currentConnectionDetails {
            _resumptionLocation = XMPPSrvRecord(port: location.1 ?? details.port, weight: 1, priority: 1, target: location.0, directTls: details.directTls)
        } else {
            _resumptionLocation = nil;
        }
        
        resumptionId = id;
        _ackEnabled = true;
        if mx != nil {
            _resumptionTime = Double(mx!);
        }
        
        logger.debug("stream management enabled");
        if let context = context {
            context.eventBus.fire(EnabledEvent(context: context, resume: resume, resumeId: id));
        }
    }
    
    /// Internal class for holding incoming and outgoing counters
    class AckHolder {
        
        var incomingCounter:UInt32 = 0;
        var outgoingCounter:UInt32 = 0;
        
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
    
    /// Event fired when Stream Management is enabled
    open class EnabledEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = EnabledEvent();
        
        /// Is resumption enabled?
        public let resume: Bool;
        /// ID of stream for resumption
        public let resumeId:String?;
        
        init() {
            resume = false;
            resumeId = nil
            super.init(type: "StreamManagementEnabledEvent")
        }
        
        init(context: Context, resume: Bool, resumeId: String?) {
            self.resume = resume;
            self.resumeId = resumeId;
            super.init(type: "StreamManagementEnabledEvent", context: context);
        }
        
    }
    
    /// Event fired when Stream Management fails
    open class FailedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = FailedEvent();
        
        /// Received error condition
        public let errorCondition:ErrorCondition!;
        
        init() {
            errorCondition = nil
            super.init(type: "StreamManagementFailedEvent");
        }
        
        init(context: Context, errorCondition: ErrorCondition) {
            self.errorCondition = errorCondition;
            super.init(type: "StreamManagementFailedEvent", context: context);
        }
        
    }
    
    open class ResumedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ResumedEvent();
        
        /// Value of H attribute
        public let newH: UInt32?;
        /// ID of resumed stream
        public let resumeId:String?;
        
        init() {
            newH = nil;
            resumeId = nil
            super.init(type: "StreamManagementResumedEvent")
        }
        
        init(context: Context, newH: UInt32, resumeId: String?) {
            self.newH = newH;
            self.resumeId = resumeId;
            super.init(type: "StreamManagementResumedEvent", context: context);
        }
        
    }

}

/// Internal implementation of class for holding items in queue
class QueueNode<T> {
    
    let value: T;
    var prev: QueueNode<T>? = nil;
    var next: QueueNode<T>? = nil;
    
    init(value: T) {
        self.value = value;
    }
    
}

/// Internal implementation of queue for holding items
class Queue<T> {

    fileprivate var _count: Int = 0;
    fileprivate var head: QueueNode<T>? = nil;
    fileprivate var tail: QueueNode<T>? = nil;
    
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
        let node = QueueNode<T>(value: value);
        if head == nil {
            self.head = node;
            self.tail = node;
        } else {
            node.next = self.head;
            self.head!.prev = node;
            self.head = node;
        }
        self._count += 1;
    }
    
    open func peek() -> T? {
        if tail == nil {
            return nil
        }
        return tail?.value;
    }
    
    open func poll() -> T? {
        guard let temp = tail else {
            return nil;
        }
        
        tail = temp.prev;
        tail?.next = nil;
        temp.prev = nil;
        
        if tail == nil {
            head = nil;
        }
        
        self._count -= 1;
        return temp.value;

//        if tail == nil {
//            return nil;
//        } else {
//            let temp = tail!;
//            tail = temp.prev;
//            if tail == nil {
//                head = nil;
//            }
//            self._count -= 1;
//            return temp.value;
//        }
    }
}

