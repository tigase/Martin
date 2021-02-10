//
// XMPPConnectorBase.swift
//
// TigaseSwift
// Copyright (C) 2020 "Tigase, Inc." <office@tigase.com>
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

open class XMPPConnectorBase: ConnectorBase, XMPPParserDelegateDelegate {
    
    private var parserDelegate: XMPPParserDelegate?
    private var parser: XMLParser?

    public required init(context: Context) {
        super.init(context: context);
    }
    
    public func read(data: Data, tryNo: Int = 0) {
        do {
            print("received: \(String(data: data, encoding: .utf8))")
            try self.parser?.parse(data: data);
        } catch XmlParserError.xmlDeclarationInside(let errorCode, let position) {
            self.initiateParser();
            self.logger.debug("got XML declaration within XML, restarting XML parser...");
            let nextTry = tryNo + 1;
            guard tryNo < 4 else {
                self.logger.debug("XML stream parsing error, code: \(errorCode)");
                parsed(.streamTerminate);
                return;
            }
            let subrange = data[data.startIndex.advanced(by: position)..<data.endIndex];
            self.read(data: subrange, tryNo: nextTry);
        } catch XmlParserError.unknown(let errorCode) {
            self.logger.error("XML stream parsing error, code: \(errorCode)");
            self.parsed(.streamTerminate)
        } catch {
            self.logger.error("XML stream parsing error");
            self.parsed(.streamTerminate)
        }
    }
    
    public func initiateParser() {
        parserDelegate = XMPPParserDelegate();
        parserDelegate!.delegate = self;
        parser = XMLParser(delegate: parserDelegate!);
    }
    
    public func parsed(parserEvent event: XMPPParserEvent) {
        parsed(event.streamEvent);
    }
    
    public func parsed(_ event: StreamEvent) {
        streamLogger?.incoming(event);
    }
    
    public func serialize(_ event: StreamEvent, completion: WriteCompletion) {
        streamLogger?.outgoing(event);
    }
    
}

extension XMPPParserEvent {
    
    var streamEvent: StreamEvent {
        switch self {
        case .element(let element):
            return .stanza(Stanza.from(element: element));
        case .streamOpened(let attributes):
            return .streamOpen(attributes: attributes);
        case .streamClosed:
            return .streamClose();
        case .error:
            return .streamClose(reason: .xmlError);
        }
    }
    
}
