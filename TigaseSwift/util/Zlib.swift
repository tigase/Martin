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

/**
 Wrapper/Helper class for easier usage of ZLib for compression/decompression
 */
public class Zlib {

    /**
     Compression levels:
     - No: no compression
     - BestSpeed: optimized for best compression speed
     - BestCompression: optimized for best compression level
     - Default: default value provided by ZLib
     */
    public enum Compression: Int {
        case No = 0;
        case BestSpeed = 1;
        case BestCompression = 9;
        case Default = -1;
    }
    
    /**
     Codes returned by ZLib
     */
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
    
    /**
     Types of flush:
     - No: flush is not done
     - Partial: some data may be flushed
     - Sync: all data needs to be flushed
     - Full: all data is flushed
     - Finish: data is flushed and buffers are cleared
     - Block: data are flushed in blocks
     - Trees
     */
    public enum Flush: Int {
        case No = 0;
        case Partial = 1;
        case Sync = 2;
        case Full = 3;
        case Finish = 4;
        case Block = 5;
        case Trees = 6;
    }
    
    /**
     This is base class for `Deflater` and `Inflater` which implements 
     common methods and data structures
     
     Class for internal use.
     */
    public class Base {
    
        /// returns version of ZLib library
        @_silgen_name("zlibVersion") private static func zlibVersion() -> COpaquePointer;
        
        /// version of ZLib library
        private static var version = Base.zlibVersion();
        /// instance of `z_stream` structure
        private var stream = z_stream();
        
        /**
         Structure which defines z_stream structure used by ZLib library
         */
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

    /**
     Class used to compress data using ZLib. 
     
     Result may be later decompress by `Inflater`
     */
    public class Deflater: Base {
        
        @_silgen_name("deflateInit_") private func deflateInit_(stream : UnsafeMutablePointer<Void>, level : CInt, version : COpaquePointer, stream_size : CInt) -> CInt
        @_silgen_name("deflate") private func deflate(stream : UnsafeMutablePointer<Void>, flush : CInt) -> CInt
        @_silgen_name("deflateEnd") private func deflateEnd(strean : UnsafeMutablePointer<Void>) -> CInt
        
        /**
         Creates instance of `Deflater`
         - paramter level: sets compression level
         */
        public init(level: Compression = .Default) {
            super.init();
            deflateInit_(&stream, level: CInt(level.rawValue), version: Base.version, stream_size: CInt(sizeof(z_stream)));
        }
        
        deinit {
            deflateEnd(&stream);
        }

        /**
         Method compresses data passed and returns array with compressed data
         - parameter bytes: pointer to data to compress
         - parameter length: number of dat to process
         - parameter flush: type of flush
         - returns: compressed data as array of bytes (may not contain all data depending on `flush` parameter)
         */
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

    /**
     Class used to decompress data which was compressed using ZLib. 
     
     Data could be compressed using `Deflater`
     */
    public class Inflater: Base {
        
        @_silgen_name("inflateInit_") private func inflateInit_(stream : UnsafeMutablePointer<Void>, version : COpaquePointer, stream_size : CInt) -> CInt
        @_silgen_name("inflate") private func inflate(stream : UnsafeMutablePointer<Void>, flush : CInt) -> CInt
        @_silgen_name("inflateEnd") private func inflateEnd(stream : UnsafeMutablePointer<Void>) -> CInt
        
        /// Creates instance of `Inflater`
        public override init() {
            super.init();
            inflateInit_(&stream, version: Base.version, stream_size: CInt(sizeof(z_stream)));
        }
        
        /**
         Method decompresses passed data and returns array with decompressed data
         - parameter bytes: pointer to data to decompress
         - parameter length: number of data to process
         - parameter flush: type of flush
         - returns: decompressed data as array of bytes
         */
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
    
    /**
     Creates instance of ZLib which allows for compression and decompression
     - parameter compressionLevel: level of compression
     - parameter flush: type of flush used during compression and decompression
     */
    public init(compressionLevel level: Compression, flush: Flush = .Partial) {
        self.deflater = Deflater(level: level);
        self.inflater = Inflater();
        self.flush = flush;
    }
    
    /**
     Method compresses data
     - parameter bytes: pointer to data
     - parameter length: number of data to process
     - returns: compressed data as array of bytes
     */
    public func compress(bytes: UnsafePointer<UInt8>, length: Int) -> [UInt8] {
        return deflater.compress(bytes, length: length, flush: flush);
    }
    
    /**
     Method decompresses data
     - parameter bytes: pointer to data
     - parameter length: number of data to process
     - returns: decompressed data as array of bytes
     */
    public func decompress(bytes: UnsafePointer<UInt8>, length: Int) -> [UInt8] {
        return inflater.decompress(bytes, length: length, flush: flush);
    }

}