//
// Zlib.swift
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

public class Zlib {

    public enum Compression: Int {
        case No = 0;
        case BestSpeed = 1;
        case BestCompression = 9;
        case Default = -1;
    }
    
    public enum ReturnCode: Int {
        case Ok = 0;
        case StreamEnd = 1;
        case NeedDict = 2;
        case ErrNo = -1;
        case StreamError = -2;
        case DataError = -3;
        case MemError = -4;
        case BufError = -5;
        case VersionError = -6;
    }
    
    public enum Flush: Int {
        case No = 0;
        case Partial = 1;
        case Sync = 2;
        case Full = 3;
        case Finish = 4;
        case Block = 5;
        case Trees = 6;
    }
    
    public class Base {
    
        @_silgen_name("zlibVersion") private static func zlibVersion() -> COpaquePointer;
        
        private static var version = Base.zlibVersion();
        private var stream = z_stream();
        
        struct z_stream {
            private var next_in: UnsafePointer<UInt8> = nil;    /* next input byte */
            private var avail_in: CUnsignedInt = 0;             /* number of bytes available at next_in */
            private var total_in: CUnsignedLong = 0;            /* total number of input bytes read so far */
            
            private var next_out: UnsafePointer<UInt8> = nil;   /* next output byte should be put there */
            private var avail_out: CUnsignedInt = 0;            /* remaining free space at next_out */
            private var total_out: CUnsignedLong = 0;           /* total number of bytes output so far */
            
            private var msg: UnsafePointer<UInt8> = nil;        /* last error message, NULL if no error */
            private var state: COpaquePointer = nil;            /* not visible by applications */
            
            private var zalloc: COpaquePointer = nil;           /* used to allocate the internal state */
            private var zfree: COpaquePointer = nil;            /* used to free the internal state */
            private var opaque: COpaquePointer = nil;           /* private data object passed to zalloc and zfree */
            
            private var data_type: CInt = 0;                    /* best guess about the data type: binary or text */
            private var adler: CUnsignedLong = 0;               /* adler32 value of the uncompressed data */
            private var reserved: CUnsignedLong = 0;            /* reserved for future use */
        }
        
    }

    public class Deflater: Base {
        
        @_silgen_name("deflateInit_") private func deflateInit_(stream : UnsafeMutablePointer<Void>, level : CInt, version : COpaquePointer, stream_size : CInt) -> CInt
        @_silgen_name("deflate") private func deflate(stream : UnsafeMutablePointer<Void>, flush : CInt) -> CInt
        @_silgen_name("deflateEnd") private func deflateEnd(strean : UnsafeMutablePointer<Void>) -> CInt
        
        public init(level: Compression = .Default) {
            super.init();
            deflateInit_(&stream, level: CInt(level.rawValue), version: Base.version, stream_size: CInt(sizeof(z_stream)));
        }
        
        deinit {
            deflateEnd(&stream);
        }

        public func compress(var bytes: UnsafePointer<UInt8>, length: Int, flush: Flush = .Partial) -> [UInt8] {
            var result = [UInt8]();
            stream.avail_in = CUnsignedInt(length);
            stream.next_in = bytes;
            
            var out = [UInt8](count: length + (length / 100) + 13, repeatedValue: 0);
            repeat {
                stream.avail_out = CUnsignedInt(out.count);
                stream.next_out = &out + 0;
                
                deflate(&stream, flush: CInt(flush.rawValue));
                let outCount = out.count - Int(stream.avail_out);
                if outCount > 0 {
                    result += Array(out[0...outCount-1]);
                }
            } while stream.avail_out == 0
            // we should check if stream.avail_in is 0!
            return result;
        }
    }

    public class Inflater: Base {
        
        @_silgen_name("inflateInit_") private func inflateInit_(stream : UnsafeMutablePointer<Void>, version : COpaquePointer, stream_size : CInt) -> CInt
        @_silgen_name("inflate") private func inflate(stream : UnsafeMutablePointer<Void>, flush : CInt) -> CInt
        @_silgen_name("inflateEnd") private func inflateEnd(stream : UnsafeMutablePointer<Void>) -> CInt
        
        public override init() {
            super.init();
            inflateInit_(&stream, version: Base.version, stream_size: CInt(sizeof(z_stream)));
        }
        
        public func decompress(var bytes:UnsafePointer<UInt8>, length: Int, flush: Flush = .Partial) -> [UInt8] {
            var result = [UInt8]();
            stream.avail_in = CUnsignedInt(length);
            stream.next_in = bytes;
            
            var out = [UInt8](count: 50, repeatedValue: 0);
            repeat {
                stream.avail_out = CUnsignedInt(out.count);
                stream.next_out = &out + 0;
                
                inflate(&stream, flush: CInt(flush.rawValue));
                let outCount = out.count - Int(stream.avail_out);
                if outCount > 0 {
                    result += Array(out[0...outCount-1]);
                }
            } while stream.avail_out == 0
            // we should check if stream.avail_in is 0!
            return result;
        }
        
    }
    
    private let inflater: Inflater;
    private let deflater: Deflater;
    private let flush: Flush;
    
    public init(compressionLevel level: Compression, flush: Flush = .Partial) {
        self.deflater = Deflater(level: level);
        self.inflater = Inflater();
        self.flush = flush;
    }
    
    public func compress(bytes: UnsafePointer<UInt8>, length: Int) -> [UInt8] {
        return deflater.compress(bytes, length: length, flush: flush);
    }
    
    public func decompress(bytes: UnsafePointer<UInt8>, length: Int) -> [UInt8] {
        return inflater.decompress(bytes, length: length, flush: flush);
    }

}