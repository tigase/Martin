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
open class Zlib {

    /**
     Compression levels:
     - No: no compression
     - BestSpeed: optimized for best compression speed
     - BestCompression: optimized for best compression level
     - Default: default value provided by ZLib
     */
    public enum Compression: Int {
        case no = 0;
        case bestSpeed = 1;
        case bestCompression = 9;
        case `default` = -1;
    }
    
    /**
     Codes returned by ZLib
     */
    public enum ReturnCode: Int {
        case ok = 0;
        case streamEnd = 1;
        case needDict = 2;
        case errNo = -1;
        case streamError = -2;
        case dataError = -3;
        case memError = -4;
        case bufError = -5;
        case versionError = -6;
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
        case no = 0;
        case partial = 1;
        case sync = 2;
        case full = 3;
        case finish = 4;
        case block = 5;
        case trees = 6;
    }
    
    /**
     This is base class for `Deflater` and `Inflater` which implements 
     common methods and data structures
     
     Class for internal use.
     */
    open class Base {
    
        /// returns version of ZLib library
        @_silgen_name("zlibVersion") fileprivate static func zlibVersion() -> OpaquePointer;
        
        /// version of ZLib library
        fileprivate static var version = Base.zlibVersion();
        /// instance of `z_stream` structure
        fileprivate var stream = z_stream();
        
        /**
         Structure which defines z_stream structure used by ZLib library
         */
        struct z_stream {
            fileprivate var next_in: UnsafePointer<UInt8>? = nil;    /* next input byte */
            fileprivate var avail_in: CUnsignedInt = 0;             /* number of bytes available at next_in */
            fileprivate var total_in: CUnsignedLong = 0;            /* total number of input bytes read so far */
            
            fileprivate var next_out: UnsafePointer<UInt8>? = nil;   /* next output byte should be put there */
            fileprivate var avail_out: CUnsignedInt = 0;            /* remaining free space at next_out */
            fileprivate var total_out: CUnsignedLong = 0;           /* total number of bytes output so far */
            
            fileprivate var msg: UnsafePointer<UInt8>? = nil;        /* last error message, NULL if no error */
            fileprivate var state: OpaquePointer? = nil;            /* not visible by applications */
            
            fileprivate var zalloc: OpaquePointer? = nil;           /* used to allocate the internal state */
            fileprivate var zfree: OpaquePointer? = nil;            /* used to free the internal state */
            fileprivate var opaque: OpaquePointer? = nil;           /* private data object passed to zalloc and zfree */
            
            fileprivate var data_type: CInt = 0;                    /* best guess about the data type: binary or text */
            fileprivate var adler: CUnsignedLong = 0;               /* adler32 value of the uncompressed data */
            fileprivate var reserved: CUnsignedLong = 0;            /* reserved for future use */
        }
        
    }

    /**
     Class used to compress data using ZLib. 
     
     Result may be later decompress by `Inflater`
     */
    open class Deflater: Base {
        
        @_silgen_name("deflateInit_") fileprivate func deflateInit_(_ stream : UnsafeMutableRawPointer, level : CInt, version : OpaquePointer, stream_size : CInt) -> CInt
        @_silgen_name("deflate") fileprivate func deflate(_ stream : UnsafeMutableRawPointer, flush : CInt) -> CInt
        @_silgen_name("deflateEnd") fileprivate func deflateEnd(_ strean : UnsafeMutableRawPointer) -> CInt
        
        /**
         Creates instance of `Deflater`
         - paramter level: sets compression level
         */
        public init(level: Compression = .default) {
            super.init();
            _ = deflateInit_(&stream, level: CInt(level.rawValue), version: Base.version, stream_size: CInt(MemoryLayout<z_stream>.size));
        }
        
        deinit {
            _ = deflateEnd(&stream);
        }

        /**
         Method compresses data passed and returns array with compressed data
         - parameter bytes: pointer to data to compress
         - parameter length: number of dat to process
         - parameter flush: type of flush
         - returns: compressed data as array of bytes (may not contain all data depending on `flush` parameter)
         */
        public func compress(_ bytes: UnsafePointer<UInt8>, length: Int, flush: Flush = .partial) -> [UInt8] {
            let bytes = bytes
            var result = [UInt8]();
            stream.avail_in = CUnsignedInt(length);
            stream.next_in = bytes;
            
            var out = [UInt8](repeating: 0, count: length + (length / 100) + 13);
            repeat {
                stream.avail_out = CUnsignedInt(out.count);
                stream.next_out = &out + 0;
                
                _ = deflate(&stream, flush: CInt(flush.rawValue));
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
    open class Inflater: Base {
        
        @_silgen_name("inflateInit_") fileprivate func inflateInit_(_ stream : UnsafeMutableRawPointer, version : OpaquePointer, stream_size : CInt) -> CInt
        @_silgen_name("inflate") fileprivate func inflate(_ stream : UnsafeMutableRawPointer, flush : CInt) -> CInt
        @_silgen_name("inflateEnd") fileprivate func inflateEnd(_ stream : UnsafeMutableRawPointer) -> CInt
        
        /// Creates instance of `Inflater`
        public override init() {
            super.init();
            _ = inflateInit_(&stream, version: Base.version, stream_size: CInt(MemoryLayout<z_stream>.size));
        }
        
        /**
         Method decompresses passed data and returns array with decompressed data
         - parameter bytes: pointer to data to decompress
         - parameter length: number of data to process
         - parameter flush: type of flush
         - returns: decompressed data as array of bytes
         */
        public func decompress(_ bytes:UnsafePointer<UInt8>, length: Int, flush: Flush = .partial) -> [UInt8] {
            let bytes = bytes
            var result = [UInt8]();
            stream.avail_in = CUnsignedInt(length);
            stream.next_in = bytes;
            
            var out = [UInt8](repeating: 0, count: 50);
            repeat {
                stream.avail_out = CUnsignedInt(out.count);
                stream.next_out = &out + 0;
                
                _ = inflate(&stream, flush: CInt(flush.rawValue));
                let outCount = out.count - Int(stream.avail_out);
                if outCount > 0 {
                    result += Array(out[0...outCount-1]);
                }
            } while stream.avail_out == 0
            // we should check if stream.avail_in is 0!
            return result;
        }
        
    }
    
    fileprivate let inflater: Inflater;
    fileprivate let deflater: Deflater;
    fileprivate let flush: Flush;
    
    /**
     Creates instance of ZLib which allows for compression and decompression
     - parameter compressionLevel: level of compression
     - parameter flush: type of flush used during compression and decompression
     */
    public init(compressionLevel level: Compression, flush: Flush = .partial) {
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
    open func compress(_ bytes: UnsafePointer<UInt8>, length: Int) -> [UInt8] {
        return deflater.compress(bytes, length: length, flush: flush);
    }
    
    /**
     Method decompresses data
     - parameter bytes: pointer to data
     - parameter length: number of data to process
     - returns: decompressed data as array of bytes
     */
    open func decompress(_ bytes: UnsafePointer<UInt8>, length: Int) -> [UInt8] {
        return inflater.decompress(bytes, length: length, flush: flush);
    }

}
