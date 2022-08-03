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
import zlib

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
        
        /// version of ZLib library
        fileprivate static var version = zlibVersion();
        /// instance of `z_stream` structure
        fileprivate var stream = z_stream();
        
    }

    /**
     Class used to compress data using ZLib. 
     
     Result may be later decompress by `Inflater`
     */
    open class Deflater: Base {
        
        /**
         Creates instance of `Deflater`
         - paramter level: sets compression level
         */
        public init(level: Compression = .default) {
            super.init();
            _ = deflateInit_(&stream, CInt(level.rawValue), Base.version, CInt(MemoryLayout<z_stream>.size));
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
        public func compress(bytes: UnsafePointer<UInt8>, length: Int, flush: Flush = .partial) -> [UInt8] {
            let bytes = bytes
            var result = [UInt8]();
            stream.avail_in = CUnsignedInt(length);
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: bytes);
            
            var out = [UInt8](repeating: 0, count: length + (length / 100) + 13);
            repeat {
                stream.avail_out = CUnsignedInt(out.count);
                out.withUnsafeMutableBytes { ptr in
                    stream.next_out = ptr.baseAddress!.assumingMemoryBound(to: UInt8.self) + 0;
                }
                
                _ = deflate(&stream, CInt(flush.rawValue));
                let outCount = out.count - Int(stream.avail_out);
                if outCount > 0 {
                    result += Array(out[0...outCount-1]);
                }
            } while stream.avail_out == 0
            // we should check if stream.avail_in is 0!
            return result;
        }
        
        /**
         Method compresses data passed and returns array with compressed data
         - parameter data: instance of Data to compress
         - parameter flush: type of flush
         - returns: compressed data as array of bytes (may not contain all data depending on `flush` parameter)
         */
        public func compress(data tmp: Data, flush: Flush = .partial) -> Data {
            var t = tmp;
            return t.withUnsafeMutableBytes { [count = t.count] (bytes) -> Data in
                var result = Data();
                stream.avail_in = CUnsignedInt(count);
                stream.next_in = bytes.baseAddress!.assumingMemoryBound(to: Bytef.self);

                var out = [UInt8](repeating: 0, count: count + (count / 100) + 13);
                repeat {
                    stream.avail_out = CUnsignedInt(out.count);
                    out.withUnsafeMutableBytes { ptr in
                        stream.next_out = ptr.baseAddress!.assumingMemoryBound(to: UInt8.self) + 0;
                    }
                    
                    _ = deflate(&stream, CInt(flush.rawValue));
                    let outCount = out.count - Int(stream.avail_out);
                    if outCount > 0 {
                        result.append(&out, count: outCount);
                    }
                } while stream.avail_out == 0
                
                return result;
            }
        }
    }

    /**
     Class used to decompress data which was compressed using ZLib. 
     
     Data could be compressed using `Deflater`
     */
    open class Inflater: Base {
        
        /// Creates instance of `Inflater`
        public override init() {
            super.init();
            _ = inflateInit_(&stream, Base.version, CInt(MemoryLayout<z_stream>.size));
        }
        
        /**
         Method decompresses passed data and returns array with decompressed data
         - parameter bytes: pointer to data to decompress
         - parameter length: number of data to process
         - parameter flush: type of flush
         - returns: decompressed data as array of bytes
         */
        public func decompress(bytes:UnsafePointer<UInt8>, length: Int, flush: Flush = .partial) -> [UInt8] {
            let bytes = bytes
            var result = [UInt8]();
            stream.avail_in = CUnsignedInt(length);
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: bytes);
            
            var out = [UInt8](repeating: 0, count: 50);
            repeat {
                stream.avail_out = CUnsignedInt(out.count);
                out.withUnsafeMutableBytes { ptr in
                    stream.next_out = ptr.baseAddress!.assumingMemoryBound(to: UInt8.self) + 0;
                }
                
                _ = inflate(&stream, CInt(flush.rawValue));
                let outCount = out.count - Int(stream.avail_out);
                if outCount > 0 {
                    result += Array(out[0...outCount-1]);
                }
            } while stream.avail_out == 0
            // we should check if stream.avail_in is 0!
            return result;
        }
        
        /**
         Method decompresses passed data and returns array with decompressed data
         - parameter data: instance of Data to decompress
         - parameter flush: type of flush
         - returns: decompressed data as array of bytes
         */
        public func decompress(data: Data, flush: Flush = .partial) -> Data {
            var t = data;
            return t.withUnsafeMutableBytes { [count = t.count] (bytes) -> Data in
                var result = Data();
                stream.avail_in = CUnsignedInt(count);
                stream.next_in = bytes.baseAddress!.assumingMemoryBound(to: Bytef.self);
            
                var out = [UInt8](repeating: 0, count: 50);
                repeat {
                    stream.avail_out = CUnsignedInt(out.count);
                    out.withUnsafeMutableBytes { ptr in
                        stream.next_out = ptr.baseAddress!.assumingMemoryBound(to: UInt8.self) + 0;
                    }
                
                    _ = inflate(&stream, CInt(flush.rawValue));
                    let outCount = out.count - Int(stream.avail_out);
                    if outCount > 0 {
                        result.append(&out, count: outCount);
                    }
                } while stream.avail_out == 0
                // we should check if stream.avail_in is 0!
                return result;
            }
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
    open func compress(bytes: UnsafePointer<UInt8>, length: Int) -> [UInt8] {
        return deflater.compress(bytes: bytes, length: length, flush: flush);
    }

    /**
     Method compresses data
     - parameter data: instance of Data
     - returns: compressed data as Data
     */
    open func compress(data: Data) -> Data {
        return deflater.compress(data: data, flush: flush);
    }
    
    /**
     Method decompresses data
     - parameter bytes: pointer to data
     - parameter length: number of data to process
     - returns: decompressed data as array of bytes
     */
    open func decompress(bytes: UnsafePointer<UInt8>, length: Int) -> [UInt8] {
        return inflater.decompress(bytes: bytes, length: length, flush: flush);
    }

    /**
     Method decompresses data
     - parameter data: instance of Data
     - parameter length: number of data to process
     - returns: decompressed data as Data
     */
    open func decompress(data: Data) -> Data {
        return inflater.decompress(data: data, flush: flush);
    }

}
