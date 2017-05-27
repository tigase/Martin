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

/**
 Module implements support for [XEP-0198: Stream Management]
 
 [XEP-0198: Stream Management]: http://xmpp.org/extensions/xep-0198.html
 */
open class StreamManagementModule: Logger, XmppModule, ContextAware, XmppStanzaFilter, EventHandler {
    
    /// Namespace used by stream management
    static let SM_XMLNS = "urn:xmpp:sm:3";
    
    /// ID of module for lookup in `XmppModulesManager`
    open static let ID = SM_XMLNS;
    
    open let id = SM_XMLNS;
    
    open let criteria = Criteria.xmlns(SM_XMLNS);
    
    open let features = [String]();
    
    open var context: Context! {
        didSet {
            if oldValue != nil {
                oldValue.eventBus.unregister(handler: self, for: SessionObject.ClearedEvent.TYPE);
            }
            if context != nil {
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
    
    fileprivate var _resumptionLocation: String? = nil;
    /// Address to use when resuming stream
    open var resumptionLocation: String? {
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
        super.init();
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
        
        log("enabling StreamManagament with resume=", resumption);
        let enable = Stanza(name: "enable", xmlns: StreamManagementModule.SM_XMLNS);
        if resumption {
            enable.setAttribute("resume", value: "true");
            let timeout = maxResumptionTimeout ?? self.maxResumptionTimeout;
            if timeout != nil {
                enable.setAttribute("max", value: String(timeout!));
            }
        }
        
        context.writer?.write(enable);
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
        return StreamFeaturesModule.getStreamFeatures(context.sessionObject)?.findChild(name: "sm", xmlns: StreamManagementModule.SM_XMLNS) != nil;
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
        context.writer?.write(r);
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
        log("starting stream resumption");
        let resume = Stanza(name: "resume", xmlns: StreamManagementModule.SM_XMLNS);
        resume.setAttribute("h", value: String(ackH.incomingCounter));
        resume.setAttribute("previd", value: resumptionId);
        
        context.writer?.write(resume);
    }
    
    /// Send ACK to server
    open func sendAck() {
        guard let a = prepareAck() else {
            return;
        }
        context.writer?.write(a);
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
        let newH = UInt32(stanza.getAttribute("h")!) ?? 0;
        _ackEnabled = true;
        let left = max(Int(ackH.outgoingCounter) - Int(newH), 0);
        ackH.outgoingCounter = newH;
        while left < outgoingQueue.count {
            _ = outgoingQueue.poll();
        }
    }
    
    /// Process ACK request from server
    func processAckRequest(_ stanza: Stanza) {
        let value = ackH.incomingCounter;
        lastSentH = value;

        let a = Stanza(name: "a", xmlns: StreamManagementModule.SM_XMLNS);
        a.setAttribute("h", value: String(value));
        context.writer?.write(a);
    }
    
    func processFailed(_ stanza: Stanza) {
        reset();
        
        let errorCondition = stanza.errorCondition ?? ErrorCondition.unexpected_request;
        
        log("stream resumption failed");
        context.eventBus.fire(FailedEvent(sessionObject: context.sessionObject, errorCondition: errorCondition));
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
            context.writer?.write(s);
        }
        
        log("stream resumed");
        context.eventBus.fire(ResumedEvent(sessionObject: context.sessionObject, newH: newH, resumeId: stanza.getAttribute("previd")));
    }
    
    func processEnabled(_ stanza: Stanza) {
        let id = stanza.getAttribute("id");
        let r = stanza.getAttribute("resume");
        let mx = stanza.getAttribute("max");
        let resume = r == "true" || r == "1";
        _resumptionLocation = stanza.getAttribute("location");
        
        resumptionId = id;
        _ackEnabled = true;
        if mx != nil {
            _resumptionTime = Double(mx!);
        }
        
        log("stream management enabled");
        context.eventBus.fire(EnabledEvent(sessionObject: context.sessionObject, resume: resume, resumeId: id));
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
    open class EnabledEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = EnabledEvent();
        
        open let type = "StreamManagementEnabledEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject:SessionObject!;
        /// Is resumption enabled?
        open let resume: Bool;
        /// ID of stream for resumption
        open let resumeId:String?;
        
        init() {
            sessionObject = nil;
            resume = false;
            resumeId = nil
        }
        
        init(sessionObject: SessionObject, resume: Bool, resumeId: String?) {
            self.sessionObject = sessionObject;
            self.resume = resume;
            self.resumeId = resumeId;
        }
        
    }
    
    /// Event fired when Stream Management fails
    open class FailedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = FailedEvent();
        
        open let type = "StreamManagementFailedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject:SessionObject!;
        /// Received error condition
        open let errorCondition:ErrorCondition!;
        
        init() {
            sessionObject = nil;
            errorCondition = nil
        }
        
        init(sessionObject: SessionObject, errorCondition: ErrorCondition) {
            self.sessionObject = sessionObject;
            self.errorCondition = errorCondition;
        }
        
    }
    
    open class ResumedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = ResumedEvent();
        
        open let type = "StreamManagementResumedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject:SessionObject!;
        /// Value of H attribute
        open let newH: UInt32?;
        /// ID of resumed stream
        open let resumeId:String?;
        
        init() {
            sessionObject = nil;
            newH = nil;
            resumeId = nil
        }
        
        init(sessionObject: SessionObject, newH: UInt32, resumeId: String?) {
            self.sessionObject = sessionObject;
            self.newH = newH;
            self.resumeId = resumeId;
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
        if tail == nil {
            return nil;
        } else {
            let temp = tail!;
            tail = temp.prev;
            if tail == nil {
                head = nil;
            }
            self._count -= 1;
            return temp.value;
        }
    }
}

