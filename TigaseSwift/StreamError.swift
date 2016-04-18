//
// StreamError.swift
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

public enum StreamError: String {
    case bad_format = "bad-format"
    case bad_namespace_prefix = "bad-namespace-prefix"
    case conflict
    case connection_timeout = "connection-timeout"
    case host_gone = "host-gone"
    case host_unknown = "host-unknown"
    case improper_addressing = "improper-addressing"
    case internal_server_error = "internal-server-error"
    case invalid_from = "invalid-from"
    case invalid_id = "invalid-id"
    case invalid_namespace = "invalid-namespace"
    case invalid_xml = "invalid-xml"
    case not_authorized = "not-authorized"
    case not_well_formed = "not-well-formed"
    case policy_violation = "policy-violation"
    case remote_connection_failed = "remote-connection-failed"
    case reset
    case resource_constraint = "resource-constraint"
    case restricted_xml = "restricted-xml"
    case see_other_host = "see-other-host"
    case system_shutdown = "system-shutdown"
    case undefined_condition = "undefined-condition"
    case unsupported_encoding = "unsupported-encoding"
    case unsupported_stanza_type = "unsupported-stanza-type"
    case unsupported_version = "unsupported-version"
}