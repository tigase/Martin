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
public protocol RoomWithPushSupportProtocol: RoomProtocol {
}

extension RoomWithPushSupportProtocol {
    
    public func checkTigasePushNotificationRegistrationStatus() async throws -> Bool {
        guard let regModule = context?.modulesManager.module(.inBandRegistration) else {
            throw XMPPError(condition: .remote_server_timeout);
        };
        
        let formResult = try await regModule.retrieveRegistrationForm(from: self.jid.jid());
        guard formResult.type == .dataForm, let field: DataForm.Field.Boolean = formResult.form.field(for: "{http://tigase.org/protocol/muc}offline")else {
            throw XMPPError(condition: .feature_not_implemented);
        }
        
        return field.value();
    }
    
    public func registerForTigasePushNotification(_ value: Bool) async throws {
        guard let regModule = context?.modulesManager.module(.inBandRegistration) else {
            throw XMPPError(condition: .remote_server_timeout);
        };
        
        let formResult = try await regModule.retrieveRegistrationForm(from: self.jid.jid());
        guard formResult.type == .dataForm, let valueField: DataForm.Field.Boolean = formResult.form.field(for: "{http://tigase.org/protocol/muc}offline"), let nicknameField: DataForm.Field.TextSingle = formResult.form.field(for: "muc#register_roomnick")  else {
            throw XMPPError(condition: .feature_not_implemented);
        }
        
        if valueField.currentValue == value {
            return;
        }
        
        if value {
            valueField.currentValue = value;
            nicknameField.currentValue = self.nickname;
            _ = try await regModule.submitRegistrationForm(to: JID(self.jid), form: formResult.form);
        } else {
            _ = try await regModule.unregister(from: JID(self.jid));
        }
    }
}

extension RoomWithPushSupportProtocol {

    public func checkTigasePushNotificationRegistrationStatus(completionHandler: @escaping (Result<Bool,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await checkTigasePushNotificationRegistrationStatus()));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }

    public func registerForTigasePushNotification(_ value: Bool, completionHandler: @escaping (Result<Bool,XMPPError>)->Void) {
        Task {
            do {
                try await registerForTigasePushNotification(value)
                completionHandler(.success(value));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
}
