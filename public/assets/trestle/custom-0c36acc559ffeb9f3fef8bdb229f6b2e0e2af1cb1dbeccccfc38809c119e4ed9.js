(function(global, factory) {
  typeof exports === "object" && typeof module !== "undefined" ? factory(exports) : typeof define === "function" && define.amd ? define([ "exports" ], factory) : (global = typeof globalThis !== "undefined" ? globalThis : global || self, 
  factory(global.ActiveStorage = {}));
})(this, (function(exports) {
  "use strict";
  var sparkMd5 = {
    exports: {}
  };
  (function(module, exports) {
    (function(factory) {
      {
        module.exports = factory();
      }
    })((function(undefined$1) {
      var hex_chr = [ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f" ];
      function md5cycle(x, k) {
        var a = x[0], b = x[1], c = x[2], d = x[3];
        a += (b & c | ~b & d) + k[0] - 680876936 | 0;
        a = (a << 7 | a >>> 25) + b | 0;
        d += (a & b | ~a & c) + k[1] - 389564586 | 0;
        d = (d << 12 | d >>> 20) + a | 0;
        c += (d & a | ~d & b) + k[2] + 606105819 | 0;
        c = (c << 17 | c >>> 15) + d | 0;
        b += (c & d | ~c & a) + k[3] - 1044525330 | 0;
        b = (b << 22 | b >>> 10) + c | 0;
        a += (b & c | ~b & d) + k[4] - 176418897 | 0;
        a = (a << 7 | a >>> 25) + b | 0;
        d += (a & b | ~a & c) + k[5] + 1200080426 | 0;
        d = (d << 12 | d >>> 20) + a | 0;
        c += (d & a | ~d & b) + k[6] - 1473231341 | 0;
        c = (c << 17 | c >>> 15) + d | 0;
        b += (c & d | ~c & a) + k[7] - 45705983 | 0;
        b = (b << 22 | b >>> 10) + c | 0;
        a += (b & c | ~b & d) + k[8] + 1770035416 | 0;
        a = (a << 7 | a >>> 25) + b | 0;
        d += (a & b | ~a & c) + k[9] - 1958414417 | 0;
        d = (d << 12 | d >>> 20) + a | 0;
        c += (d & a | ~d & b) + k[10] - 42063 | 0;
        c = (c << 17 | c >>> 15) + d | 0;
        b += (c & d | ~c & a) + k[11] - 1990404162 | 0;
        b = (b << 22 | b >>> 10) + c | 0;
        a += (b & c | ~b & d) + k[12] + 1804603682 | 0;
        a = (a << 7 | a >>> 25) + b | 0;
        d += (a & b | ~a & c) + k[13] - 40341101 | 0;
        d = (d << 12 | d >>> 20) + a | 0;
        c += (d & a | ~d & b) + k[14] - 1502002290 | 0;
        c = (c << 17 | c >>> 15) + d | 0;
        b += (c & d | ~c & a) + k[15] + 1236535329 | 0;
        b = (b << 22 | b >>> 10) + c | 0;
        a += (b & d | c & ~d) + k[1] - 165796510 | 0;
        a = (a << 5 | a >>> 27) + b | 0;
        d += (a & c | b & ~c) + k[6] - 1069501632 | 0;
        d = (d << 9 | d >>> 23) + a | 0;
        c += (d & b | a & ~b) + k[11] + 643717713 | 0;
        c = (c << 14 | c >>> 18) + d | 0;
        b += (c & a | d & ~a) + k[0] - 373897302 | 0;
        b = (b << 20 | b >>> 12) + c | 0;
        a += (b & d | c & ~d) + k[5] - 701558691 | 0;
        a = (a << 5 | a >>> 27) + b | 0;
        d += (a & c | b & ~c) + k[10] + 38016083 | 0;
        d = (d << 9 | d >>> 23) + a | 0;
        c += (d & b | a & ~b) + k[15] - 660478335 | 0;
        c = (c << 14 | c >>> 18) + d | 0;
        b += (c & a | d & ~a) + k[4] - 405537848 | 0;
        b = (b << 20 | b >>> 12) + c | 0;
        a += (b & d | c & ~d) + k[9] + 568446438 | 0;
        a = (a << 5 | a >>> 27) + b | 0;
        d += (a & c | b & ~c) + k[14] - 1019803690 | 0;
        d = (d << 9 | d >>> 23) + a | 0;
        c += (d & b | a & ~b) + k[3] - 187363961 | 0;
        c = (c << 14 | c >>> 18) + d | 0;
        b += (c & a | d & ~a) + k[8] + 1163531501 | 0;
        b = (b << 20 | b >>> 12) + c | 0;
        a += (b & d | c & ~d) + k[13] - 1444681467 | 0;
        a = (a << 5 | a >>> 27) + b | 0;
        d += (a & c | b & ~c) + k[2] - 51403784 | 0;
        d = (d << 9 | d >>> 23) + a | 0;
        c += (d & b | a & ~b) + k[7] + 1735328473 | 0;
        c = (c << 14 | c >>> 18) + d | 0;
        b += (c & a | d & ~a) + k[12] - 1926607734 | 0;
        b = (b << 20 | b >>> 12) + c | 0;
        a += (b ^ c ^ d) + k[5] - 378558 | 0;
        a = (a << 4 | a >>> 28) + b | 0;
        d += (a ^ b ^ c) + k[8] - 2022574463 | 0;
        d = (d << 11 | d >>> 21) + a | 0;
        c += (d ^ a ^ b) + k[11] + 1839030562 | 0;
        c = (c << 16 | c >>> 16) + d | 0;
        b += (c ^ d ^ a) + k[14] - 35309556 | 0;
        b = (b << 23 | b >>> 9) + c | 0;
        a += (b ^ c ^ d) + k[1] - 1530992060 | 0;
        a = (a << 4 | a >>> 28) + b | 0;
        d += (a ^ b ^ c) + k[4] + 1272893353 | 0;
        d = (d << 11 | d >>> 21) + a | 0;
        c += (d ^ a ^ b) + k[7] - 155497632 | 0;
        c = (c << 16 | c >>> 16) + d | 0;
        b += (c ^ d ^ a) + k[10] - 1094730640 | 0;
        b = (b << 23 | b >>> 9) + c | 0;
        a += (b ^ c ^ d) + k[13] + 681279174 | 0;
        a = (a << 4 | a >>> 28) + b | 0;
        d += (a ^ b ^ c) + k[0] - 358537222 | 0;
        d = (d << 11 | d >>> 21) + a | 0;
        c += (d ^ a ^ b) + k[3] - 722521979 | 0;
        c = (c << 16 | c >>> 16) + d | 0;
        b += (c ^ d ^ a) + k[6] + 76029189 | 0;
        b = (b << 23 | b >>> 9) + c | 0;
        a += (b ^ c ^ d) + k[9] - 640364487 | 0;
        a = (a << 4 | a >>> 28) + b | 0;
        d += (a ^ b ^ c) + k[12] - 421815835 | 0;
        d = (d << 11 | d >>> 21) + a | 0;
        c += (d ^ a ^ b) + k[15] + 530742520 | 0;
        c = (c << 16 | c >>> 16) + d | 0;
        b += (c ^ d ^ a) + k[2] - 995338651 | 0;
        b = (b << 23 | b >>> 9) + c | 0;
        a += (c ^ (b | ~d)) + k[0] - 198630844 | 0;
        a = (a << 6 | a >>> 26) + b | 0;
        d += (b ^ (a | ~c)) + k[7] + 1126891415 | 0;
        d = (d << 10 | d >>> 22) + a | 0;
        c += (a ^ (d | ~b)) + k[14] - 1416354905 | 0;
        c = (c << 15 | c >>> 17) + d | 0;
        b += (d ^ (c | ~a)) + k[5] - 57434055 | 0;
        b = (b << 21 | b >>> 11) + c | 0;
        a += (c ^ (b | ~d)) + k[12] + 1700485571 | 0;
        a = (a << 6 | a >>> 26) + b | 0;
        d += (b ^ (a | ~c)) + k[3] - 1894986606 | 0;
        d = (d << 10 | d >>> 22) + a | 0;
        c += (a ^ (d | ~b)) + k[10] - 1051523 | 0;
        c = (c << 15 | c >>> 17) + d | 0;
        b += (d ^ (c | ~a)) + k[1] - 2054922799 | 0;
        b = (b << 21 | b >>> 11) + c | 0;
        a += (c ^ (b | ~d)) + k[8] + 1873313359 | 0;
        a = (a << 6 | a >>> 26) + b | 0;
        d += (b ^ (a | ~c)) + k[15] - 30611744 | 0;
        d = (d << 10 | d >>> 22) + a | 0;
        c += (a ^ (d | ~b)) + k[6] - 1560198380 | 0;
        c = (c << 15 | c >>> 17) + d | 0;
        b += (d ^ (c | ~a)) + k[13] + 1309151649 | 0;
        b = (b << 21 | b >>> 11) + c | 0;
        a += (c ^ (b | ~d)) + k[4] - 145523070 | 0;
        a = (a << 6 | a >>> 26) + b | 0;
        d += (b ^ (a | ~c)) + k[11] - 1120210379 | 0;
        d = (d << 10 | d >>> 22) + a | 0;
        c += (a ^ (d | ~b)) + k[2] + 718787259 | 0;
        c = (c << 15 | c >>> 17) + d | 0;
        b += (d ^ (c | ~a)) + k[9] - 343485551 | 0;
        b = (b << 21 | b >>> 11) + c | 0;
        x[0] = a + x[0] | 0;
        x[1] = b + x[1] | 0;
        x[2] = c + x[2] | 0;
        x[3] = d + x[3] | 0;
      }
      function md5blk(s) {
        var md5blks = [], i;
        for (i = 0; i < 64; i += 4) {
          md5blks[i >> 2] = s.charCodeAt(i) + (s.charCodeAt(i + 1) << 8) + (s.charCodeAt(i + 2) << 16) + (s.charCodeAt(i + 3) << 24);
        }
        return md5blks;
      }
      function md5blk_array(a) {
        var md5blks = [], i;
        for (i = 0; i < 64; i += 4) {
          md5blks[i >> 2] = a[i] + (a[i + 1] << 8) + (a[i + 2] << 16) + (a[i + 3] << 24);
        }
        return md5blks;
      }
      function md51(s) {
        var n = s.length, state = [ 1732584193, -271733879, -1732584194, 271733878 ], i, length, tail, tmp, lo, hi;
        for (i = 64; i <= n; i += 64) {
          md5cycle(state, md5blk(s.substring(i - 64, i)));
        }
        s = s.substring(i - 64);
        length = s.length;
        tail = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ];
        for (i = 0; i < length; i += 1) {
          tail[i >> 2] |= s.charCodeAt(i) << (i % 4 << 3);
        }
        tail[i >> 2] |= 128 << (i % 4 << 3);
        if (i > 55) {
          md5cycle(state, tail);
          for (i = 0; i < 16; i += 1) {
            tail[i] = 0;
          }
        }
        tmp = n * 8;
        tmp = tmp.toString(16).match(/(.*?)(.{0,8})$/);
        lo = parseInt(tmp[2], 16);
        hi = parseInt(tmp[1], 16) || 0;
        tail[14] = lo;
        tail[15] = hi;
        md5cycle(state, tail);
        return state;
      }
      function md51_array(a) {
        var n = a.length, state = [ 1732584193, -271733879, -1732584194, 271733878 ], i, length, tail, tmp, lo, hi;
        for (i = 64; i <= n; i += 64) {
          md5cycle(state, md5blk_array(a.subarray(i - 64, i)));
        }
        a = i - 64 < n ? a.subarray(i - 64) : new Uint8Array(0);
        length = a.length;
        tail = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ];
        for (i = 0; i < length; i += 1) {
          tail[i >> 2] |= a[i] << (i % 4 << 3);
        }
        tail[i >> 2] |= 128 << (i % 4 << 3);
        if (i > 55) {
          md5cycle(state, tail);
          for (i = 0; i < 16; i += 1) {
            tail[i] = 0;
          }
        }
        tmp = n * 8;
        tmp = tmp.toString(16).match(/(.*?)(.{0,8})$/);
        lo = parseInt(tmp[2], 16);
        hi = parseInt(tmp[1], 16) || 0;
        tail[14] = lo;
        tail[15] = hi;
        md5cycle(state, tail);
        return state;
      }
      function rhex(n) {
        var s = "", j;
        for (j = 0; j < 4; j += 1) {
          s += hex_chr[n >> j * 8 + 4 & 15] + hex_chr[n >> j * 8 & 15];
        }
        return s;
      }
      function hex(x) {
        var i;
        for (i = 0; i < x.length; i += 1) {
          x[i] = rhex(x[i]);
        }
        return x.join("");
      }
      if (hex(md51("hello")) !== "5d41402abc4b2a76b9719d911017c592") ;
      if (typeof ArrayBuffer !== "undefined" && !ArrayBuffer.prototype.slice) {
        (function() {
          function clamp(val, length) {
            val = val | 0 || 0;
            if (val < 0) {
              return Math.max(val + length, 0);
            }
            return Math.min(val, length);
          }
          ArrayBuffer.prototype.slice = function(from, to) {
            var length = this.byteLength, begin = clamp(from, length), end = length, num, target, targetArray, sourceArray;
            if (to !== undefined$1) {
              end = clamp(to, length);
            }
            if (begin > end) {
              return new ArrayBuffer(0);
            }
            num = end - begin;
            target = new ArrayBuffer(num);
            targetArray = new Uint8Array(target);
            sourceArray = new Uint8Array(this, begin, num);
            targetArray.set(sourceArray);
            return target;
          };
        })();
      }
      function toUtf8(str) {
        if (/[\u0080-\uFFFF]/.test(str)) {
          str = unescape(encodeURIComponent(str));
        }
        return str;
      }
      function utf8Str2ArrayBuffer(str, returnUInt8Array) {
        var length = str.length, buff = new ArrayBuffer(length), arr = new Uint8Array(buff), i;
        for (i = 0; i < length; i += 1) {
          arr[i] = str.charCodeAt(i);
        }
        return returnUInt8Array ? arr : buff;
      }
      function arrayBuffer2Utf8Str(buff) {
        return String.fromCharCode.apply(null, new Uint8Array(buff));
      }
      function concatenateArrayBuffers(first, second, returnUInt8Array) {
        var result = new Uint8Array(first.byteLength + second.byteLength);
        result.set(new Uint8Array(first));
        result.set(new Uint8Array(second), first.byteLength);
        return returnUInt8Array ? result : result.buffer;
      }
      function hexToBinaryString(hex) {
        var bytes = [], length = hex.length, x;
        for (x = 0; x < length - 1; x += 2) {
          bytes.push(parseInt(hex.substr(x, 2), 16));
        }
        return String.fromCharCode.apply(String, bytes);
      }
      function SparkMD5() {
        this.reset();
      }
      SparkMD5.prototype.append = function(str) {
        this.appendBinary(toUtf8(str));
        return this;
      };
      SparkMD5.prototype.appendBinary = function(contents) {
        this._buff += contents;
        this._length += contents.length;
        var length = this._buff.length, i;
        for (i = 64; i <= length; i += 64) {
          md5cycle(this._hash, md5blk(this._buff.substring(i - 64, i)));
        }
        this._buff = this._buff.substring(i - 64);
        return this;
      };
      SparkMD5.prototype.end = function(raw) {
        var buff = this._buff, length = buff.length, i, tail = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ], ret;
        for (i = 0; i < length; i += 1) {
          tail[i >> 2] |= buff.charCodeAt(i) << (i % 4 << 3);
        }
        this._finish(tail, length);
        ret = hex(this._hash);
        if (raw) {
          ret = hexToBinaryString(ret);
        }
        this.reset();
        return ret;
      };
      SparkMD5.prototype.reset = function() {
        this._buff = "";
        this._length = 0;
        this._hash = [ 1732584193, -271733879, -1732584194, 271733878 ];
        return this;
      };
      SparkMD5.prototype.getState = function() {
        return {
          buff: this._buff,
          length: this._length,
          hash: this._hash.slice()
        };
      };
      SparkMD5.prototype.setState = function(state) {
        this._buff = state.buff;
        this._length = state.length;
        this._hash = state.hash;
        return this;
      };
      SparkMD5.prototype.destroy = function() {
        delete this._hash;
        delete this._buff;
        delete this._length;
      };
      SparkMD5.prototype._finish = function(tail, length) {
        var i = length, tmp, lo, hi;
        tail[i >> 2] |= 128 << (i % 4 << 3);
        if (i > 55) {
          md5cycle(this._hash, tail);
          for (i = 0; i < 16; i += 1) {
            tail[i] = 0;
          }
        }
        tmp = this._length * 8;
        tmp = tmp.toString(16).match(/(.*?)(.{0,8})$/);
        lo = parseInt(tmp[2], 16);
        hi = parseInt(tmp[1], 16) || 0;
        tail[14] = lo;
        tail[15] = hi;
        md5cycle(this._hash, tail);
      };
      SparkMD5.hash = function(str, raw) {
        return SparkMD5.hashBinary(toUtf8(str), raw);
      };
      SparkMD5.hashBinary = function(content, raw) {
        var hash = md51(content), ret = hex(hash);
        return raw ? hexToBinaryString(ret) : ret;
      };
      SparkMD5.ArrayBuffer = function() {
        this.reset();
      };
      SparkMD5.ArrayBuffer.prototype.append = function(arr) {
        var buff = concatenateArrayBuffers(this._buff.buffer, arr, true), length = buff.length, i;
        this._length += arr.byteLength;
        for (i = 64; i <= length; i += 64) {
          md5cycle(this._hash, md5blk_array(buff.subarray(i - 64, i)));
        }
        this._buff = i - 64 < length ? new Uint8Array(buff.buffer.slice(i - 64)) : new Uint8Array(0);
        return this;
      };
      SparkMD5.ArrayBuffer.prototype.end = function(raw) {
        var buff = this._buff, length = buff.length, tail = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ], i, ret;
        for (i = 0; i < length; i += 1) {
          tail[i >> 2] |= buff[i] << (i % 4 << 3);
        }
        this._finish(tail, length);
        ret = hex(this._hash);
        if (raw) {
          ret = hexToBinaryString(ret);
        }
        this.reset();
        return ret;
      };
      SparkMD5.ArrayBuffer.prototype.reset = function() {
        this._buff = new Uint8Array(0);
        this._length = 0;
        this._hash = [ 1732584193, -271733879, -1732584194, 271733878 ];
        return this;
      };
      SparkMD5.ArrayBuffer.prototype.getState = function() {
        var state = SparkMD5.prototype.getState.call(this);
        state.buff = arrayBuffer2Utf8Str(state.buff);
        return state;
      };
      SparkMD5.ArrayBuffer.prototype.setState = function(state) {
        state.buff = utf8Str2ArrayBuffer(state.buff, true);
        return SparkMD5.prototype.setState.call(this, state);
      };
      SparkMD5.ArrayBuffer.prototype.destroy = SparkMD5.prototype.destroy;
      SparkMD5.ArrayBuffer.prototype._finish = SparkMD5.prototype._finish;
      SparkMD5.ArrayBuffer.hash = function(arr, raw) {
        var hash = md51_array(new Uint8Array(arr)), ret = hex(hash);
        return raw ? hexToBinaryString(ret) : ret;
      };
      return SparkMD5;
    }));
  })(sparkMd5);
  var SparkMD5 = sparkMd5.exports;
  const fileSlice = File.prototype.slice || File.prototype.mozSlice || File.prototype.webkitSlice;
  class FileChecksum {
    static create(file, callback) {
      const instance = new FileChecksum(file);
      instance.create(callback);
    }
    constructor(file) {
      this.file = file;
      this.chunkSize = 2097152;
      this.chunkCount = Math.ceil(this.file.size / this.chunkSize);
      this.chunkIndex = 0;
    }
    create(callback) {
      this.callback = callback;
      this.md5Buffer = new SparkMD5.ArrayBuffer;
      this.fileReader = new FileReader;
      this.fileReader.addEventListener("load", (event => this.fileReaderDidLoad(event)));
      this.fileReader.addEventListener("error", (event => this.fileReaderDidError(event)));
      this.readNextChunk();
    }
    fileReaderDidLoad(event) {
      this.md5Buffer.append(event.target.result);
      if (!this.readNextChunk()) {
        const binaryDigest = this.md5Buffer.end(true);
        const base64digest = btoa(binaryDigest);
        this.callback(null, base64digest);
      }
    }
    fileReaderDidError(event) {
      this.callback(`Error reading ${this.file.name}`);
    }
    readNextChunk() {
      if (this.chunkIndex < this.chunkCount || this.chunkIndex == 0 && this.chunkCount == 0) {
        const start = this.chunkIndex * this.chunkSize;
        const end = Math.min(start + this.chunkSize, this.file.size);
        const bytes = fileSlice.call(this.file, start, end);
        this.fileReader.readAsArrayBuffer(bytes);
        this.chunkIndex++;
        return true;
      } else {
        return false;
      }
    }
  }
  function getMetaValue(name) {
    const element = findElement(document.head, `meta[name="${name}"]`);
    if (element) {
      return element.getAttribute("content");
    }
  }
  function findElements(root, selector) {
    if (typeof root == "string") {
      selector = root;
      root = document;
    }
    const elements = root.querySelectorAll(selector);
    return toArray(elements);
  }
  function findElement(root, selector) {
    if (typeof root == "string") {
      selector = root;
      root = document;
    }
    return root.querySelector(selector);
  }
  function dispatchEvent(element, type, eventInit = {}) {
    const {disabled: disabled} = element;
    const {bubbles: bubbles, cancelable: cancelable, detail: detail} = eventInit;
    const event = document.createEvent("Event");
    event.initEvent(type, bubbles || true, cancelable || true);
    event.detail = detail || {};
    try {
      element.disabled = false;
      element.dispatchEvent(event);
    } finally {
      element.disabled = disabled;
    }
    return event;
  }
  function toArray(value) {
    if (Array.isArray(value)) {
      return value;
    } else if (Array.from) {
      return Array.from(value);
    } else {
      return [].slice.call(value);
    }
  }
  class BlobRecord {
    constructor(file, checksum, url, customHeaders = {}) {
      this.file = file;
      this.attributes = {
        filename: file.name,
        content_type: file.type || "application/octet-stream",
        byte_size: file.size,
        checksum: checksum
      };
      this.xhr = new XMLHttpRequest;
      this.xhr.open("POST", url, true);
      this.xhr.responseType = "json";
      this.xhr.setRequestHeader("Content-Type", "application/json");
      this.xhr.setRequestHeader("Accept", "application/json");
      this.xhr.setRequestHeader("X-Requested-With", "XMLHttpRequest");
      Object.keys(customHeaders).forEach((headerKey => {
        this.xhr.setRequestHeader(headerKey, customHeaders[headerKey]);
      }));
      const csrfToken = getMetaValue("csrf-token");
      if (csrfToken != undefined) {
        this.xhr.setRequestHeader("X-CSRF-Token", csrfToken);
      }
      this.xhr.addEventListener("load", (event => this.requestDidLoad(event)));
      this.xhr.addEventListener("error", (event => this.requestDidError(event)));
    }
    get status() {
      return this.xhr.status;
    }
    get response() {
      const {responseType: responseType, response: response} = this.xhr;
      if (responseType == "json") {
        return response;
      } else {
        return JSON.parse(response);
      }
    }
    create(callback) {
      this.callback = callback;
      this.xhr.send(JSON.stringify({
        blob: this.attributes
      }));
    }
    requestDidLoad(event) {
      if (this.status >= 200 && this.status < 300) {
        const {response: response} = this;
        const {direct_upload: direct_upload} = response;
        delete response.direct_upload;
        this.attributes = response;
        this.directUploadData = direct_upload;
        this.callback(null, this.toJSON());
      } else {
        this.requestDidError(event);
      }
    }
    requestDidError(event) {
      this.callback(`Error creating Blob for "${this.file.name}". Status: ${this.status}`);
    }
    toJSON() {
      const result = {};
      for (const key in this.attributes) {
        result[key] = this.attributes[key];
      }
      return result;
    }
  }
  class BlobUpload {
    constructor(blob) {
      this.blob = blob;
      this.file = blob.file;
      const {url: url, headers: headers} = blob.directUploadData;
      this.xhr = new XMLHttpRequest;
      this.xhr.open("PUT", url, true);
      this.xhr.responseType = "text";
      for (const key in headers) {
        this.xhr.setRequestHeader(key, headers[key]);
      }
      this.xhr.addEventListener("load", (event => this.requestDidLoad(event)));
      this.xhr.addEventListener("error", (event => this.requestDidError(event)));
    }
    create(callback) {
      this.callback = callback;
      this.xhr.send(this.file.slice());
    }
    requestDidLoad(event) {
      const {status: status, response: response} = this.xhr;
      if (status >= 200 && status < 300) {
        this.callback(null, response);
      } else {
        this.requestDidError(event);
      }
    }
    requestDidError(event) {
      this.callback(`Error storing "${this.file.name}". Status: ${this.xhr.status}`);
    }
  }
  let id = 0;
  class DirectUpload {
    constructor(file, url, delegate, customHeaders = {}) {
      this.id = ++id;
      this.file = file;
      this.url = url;
      this.delegate = delegate;
      this.customHeaders = customHeaders;
    }
    create(callback) {
      FileChecksum.create(this.file, ((error, checksum) => {
        if (error) {
          callback(error);
          return;
        }
        const blob = new BlobRecord(this.file, checksum, this.url, this.customHeaders);
        notify(this.delegate, "directUploadWillCreateBlobWithXHR", blob.xhr);
        blob.create((error => {
          if (error) {
            callback(error);
          } else {
            const upload = new BlobUpload(blob);
            notify(this.delegate, "directUploadWillStoreFileWithXHR", upload.xhr);
            upload.create((error => {
              if (error) {
                callback(error);
              } else {
                callback(null, blob.toJSON());
              }
            }));
          }
        }));
      }));
    }
  }
  function notify(object, methodName, ...messages) {
    if (object && typeof object[methodName] == "function") {
      return object[methodName](...messages);
    }
  }
  class DirectUploadController {
    constructor(input, file) {
      this.input = input;
      this.file = file;
      this.directUpload = new DirectUpload(this.file, this.url, this);
      this.dispatch("initialize");
    }
    start(callback) {
      const hiddenInput = document.createElement("input");
      hiddenInput.type = "hidden";
      hiddenInput.name = this.input.name;
      this.input.insertAdjacentElement("beforebegin", hiddenInput);
      this.dispatch("start");
      this.directUpload.create(((error, attributes) => {
        if (error) {
          hiddenInput.parentNode.removeChild(hiddenInput);
          this.dispatchError(error);
        } else {
          hiddenInput.value = attributes.signed_id;
        }
        this.dispatch("end");
        callback(error);
      }));
    }
    uploadRequestDidProgress(event) {
      const progress = event.loaded / event.total * 100;
      if (progress) {
        this.dispatch("progress", {
          progress: progress
        });
      }
    }
    get url() {
      return this.input.getAttribute("data-direct-upload-url");
    }
    dispatch(name, detail = {}) {
      detail.file = this.file;
      detail.id = this.directUpload.id;
      return dispatchEvent(this.input, `direct-upload:${name}`, {
        detail: detail
      });
    }
    dispatchError(error) {
      const event = this.dispatch("error", {
        error: error
      });
      if (!event.defaultPrevented) {
        alert(error);
      }
    }
    directUploadWillCreateBlobWithXHR(xhr) {
      this.dispatch("before-blob-request", {
        xhr: xhr
      });
    }
    directUploadWillStoreFileWithXHR(xhr) {
      this.dispatch("before-storage-request", {
        xhr: xhr
      });
      xhr.upload.addEventListener("progress", (event => this.uploadRequestDidProgress(event)));
    }
  }
  const inputSelector = "input[type=file][data-direct-upload-url]:not([disabled])";
  class DirectUploadsController {
    constructor(form) {
      this.form = form;
      this.inputs = findElements(form, inputSelector).filter((input => input.files.length));
    }
    start(callback) {
      const controllers = this.createDirectUploadControllers();
      const startNextController = () => {
        const controller = controllers.shift();
        if (controller) {
          controller.start((error => {
            if (error) {
              callback(error);
              this.dispatch("end");
            } else {
              startNextController();
            }
          }));
        } else {
          callback();
          this.dispatch("end");
        }
      };
      this.dispatch("start");
      startNextController();
    }
    createDirectUploadControllers() {
      const controllers = [];
      this.inputs.forEach((input => {
        toArray(input.files).forEach((file => {
          const controller = new DirectUploadController(input, file);
          controllers.push(controller);
        }));
      }));
      return controllers;
    }
    dispatch(name, detail = {}) {
      return dispatchEvent(this.form, `direct-uploads:${name}`, {
        detail: detail
      });
    }
  }
  const processingAttribute = "data-direct-uploads-processing";
  const submitButtonsByForm = new WeakMap;
  let started = false;
  function start() {
    if (!started) {
      started = true;
      document.addEventListener("click", didClick, true);
      document.addEventListener("submit", didSubmitForm, true);
      document.addEventListener("ajax:before", didSubmitRemoteElement);
    }
  }
  function didClick(event) {
    const button = event.target.closest("button, input");
    if (button && button.type === "submit" && button.form) {
      submitButtonsByForm.set(button.form, button);
    }
  }
  function didSubmitForm(event) {
    handleFormSubmissionEvent(event);
  }
  function didSubmitRemoteElement(event) {
    if (event.target.tagName == "FORM") {
      handleFormSubmissionEvent(event);
    }
  }
  function handleFormSubmissionEvent(event) {
    const form = event.target;
    if (form.hasAttribute(processingAttribute)) {
      event.preventDefault();
      return;
    }
    const controller = new DirectUploadsController(form);
    const {inputs: inputs} = controller;
    if (inputs.length) {
      event.preventDefault();
      form.setAttribute(processingAttribute, "");
      inputs.forEach(disable);
      controller.start((error => {
        form.removeAttribute(processingAttribute);
        if (error) {
          inputs.forEach(enable);
        } else {
          submitForm(form);
        }
      }));
    }
  }
  function submitForm(form) {
    let button = submitButtonsByForm.get(form) || findElement(form, "input[type=submit], button[type=submit]");
    if (button) {
      const {disabled: disabled} = button;
      button.disabled = false;
      button.focus();
      button.click();
      button.disabled = disabled;
    } else {
      button = document.createElement("input");
      button.type = "submit";
      button.style.display = "none";
      form.appendChild(button);
      button.click();
      form.removeChild(button);
    }
    submitButtonsByForm.delete(form);
  }
  function disable(input) {
    input.disabled = true;
  }
  function enable(input) {
    input.disabled = false;
  }
  function autostart() {
    if (window.ActiveStorage) {
      start();
    }
  }
  setTimeout(autostart, 1);
  exports.DirectUpload = DirectUpload;
  exports.DirectUploadController = DirectUploadController;
  exports.DirectUploadsController = DirectUploadsController;
  exports.start = start;
  Object.defineProperty(exports, "__esModule", {
    value: true
  });
}));
(function() {
  const BUILDER_SELECTOR = "[data-content-article-block-builder]";
  const builderInstances = new WeakMap();

  function initBuilders() {
    document.querySelectorAll(BUILDER_SELECTOR).forEach(container => {
      if (!builderInstances.has(container)) {
        builderInstances.set(container, new ContentArticleBlockBuilder(container));
      }
    });
  }

  document.addEventListener("DOMContentLoaded", initBuilders);
  document.addEventListener("turbolinks:load", initBuilders);
  document.addEventListener("turbo:load", initBuilders);

  document.addEventListener("direct-upload:success", event => {
    const input = event.target;
    const container = input.closest(BUILDER_SELECTOR);
    if (!container) return;
    const builder = builderInstances.get(container);
    if (builder) {
      builder.handleDirectUploadSuccess(input, event.detail);
    }
  });

  class ContentArticleBlockBuilder {
    constructor(container) {
      this.container = container;
      this.blockList = container.querySelector(".builder-block-list");
      this.templateSelect = container.querySelector(".builder-template-select");
      this.addButton = container.querySelector(".builder-add-block");
      const form = container.closest("form");
      this.hiddenField = form ? form.querySelector(".content-article-body-blocks-json") : null;
      this.directUploadUrl = container.dataset.directUploadUrl;
      this.templates = this.safeParse(container.dataset.blockTemplates);
      this.categories = this.safeParse(container.dataset.buttonCategories);
      this.blocks = this.safeParse(container.dataset.initialBlocks);

      this.productsByCategoryUrl = container.dataset.productsByCategoryUrl;
      this.productsCache = new Map();

      if (this.addButton) {
        this.addButton.addEventListener("click", () => {
          const templateValue = this.templateSelect ? this.templateSelect.value : null;
          this.addBlock(templateValue);
        });
      }

      this.renderBlocks();
      this.attachSubmitSync();
    }

    safeParse(value) {
      if (!value) {
        return [];
      }
      try {
        return JSON.parse(value);
      } catch (_error) {
        return [];
      }
    }

    addBlock(templateId) {
      if (!templateId && this.templates.length > 0) {
        templateId = this.templates[0].id;
      }
      const template = this.templates.find(t => t.id === templateId);
      if (!template) return;

      const block = this.createBlockFromTemplate(template.id);
      this.blocks.push(block);
      this.renderBlocks();
    }

    createBlockFromTemplate(templateId, existing = {}) {
      const template = this.templates.find(t => t.id === templateId) || this.templates[0];
      if (!template) return null;

      return {
        type: template.id,
        content: existing.content || "",
        button_text: existing.button_text || "",
        button_category_id: existing.button_category_id || null,
        slider_enabled: template.slider_enabled,
        button_enabled: template.button_enabled,
        slider_category_id: existing.slider_category_id || null,
        slider_product_skus: Array.isArray(existing.slider_product_skus) ? existing.slider_product_skus : [],      
        images: template.image_slots.map(slot => {
          const matched = (existing.images || []).find(image => image.slot === slot.name);
          return {
            slot: slot.name,
            label: slot.label,
            signed_id: matched ? matched.signed_id : null,
            url: matched ? matched.url : null,
            filename: matched ? matched.filename : null
          };
        })
      };
    }

    renderBlocks() {
      if (!this.blockList) return;
      this.blockList.innerHTML = "";
      this.blocks.forEach((block, index) => {
        const blockEl = this.buildBlockElement(block, index);
        this.blockList.appendChild(blockEl);
      });
      this.syncHiddenField();
    }

    buildBlockElement(block, index) {
      const blockWrapper = document.createElement("div");
      blockWrapper.className = "content-article-block-card";
      blockWrapper.dataset.blockIndex = index;

      const header = this.buildBlockHeader(block, index);
      blockWrapper.appendChild(header);

      const contentField = this.buildContentField(block, index);
      blockWrapper.appendChild(contentField);

      if (block.button_enabled) {
        const buttonSettings = this.buildButtonSettings(block, index);
        blockWrapper.appendChild(buttonSettings);
      }

      const imageFields = this.buildImageFields(block, index);
      blockWrapper.appendChild(imageFields);

      if (block.slider_enabled) {
        const sliderSettings = this.buildSliderSettings(block, index);
        blockWrapper.appendChild(sliderSettings);
      } else {
        const sliderNote = document.createElement("p");
        sliderNote.className = "block-slider-note";
        sliderNote.textContent = "Этот блок не отображает слайдер товаров.";
        blockWrapper.appendChild(sliderNote);
      }

      return blockWrapper;
    }

    async fetchProductsByCategory(categoryId) {
      if (!categoryId || !this.productsByCategoryUrl) return [];
      if (this.productsCache.has(categoryId)) return this.productsCache.get(categoryId);
    
      const url = new URL(this.productsByCategoryUrl, window.location.origin);
      url.searchParams.set("category_id", categoryId);
    
      const resp = await fetch(url.toString(), { headers: { "Accept": "application/json" } });
      if (!resp.ok) return [];
    
      const data = await resp.json();
    
      // поддержка двух форматов:
      // 1) массив [{sku,name}]
      // 2) объект {results:[{id,text,sku,name}]}
      let rawItems = [];
      if (Array.isArray(data)) {
        rawItems = data;
      } else if (data && Array.isArray(data.results)) {
        rawItems = data.results;
      }
    
      // нормализуем к виду {sku,name}
      const products = rawItems
        .map(item => {
          const sku = item.sku || item.id || item.value;
          let name = item.name || item.text || item.label;
    
          // если text = "Name (SKU)" — можно убрать хвост, чтобы фильтр по имени работал чище
          if (name && typeof name === "string") {
            name = name.replace(/\s*\(\s*[\w-]+\s*\)\s*$/, "");
          }
    
          return sku ? { sku: String(sku), name: String(name || sku) } : null;
        })
        .filter(Boolean);
    
      this.productsCache.set(categoryId, products);
      return products;
    }
    
    buildSliderSettings(block, index) {
      const container = document.createElement("div");
      container.className = "block-slider-settings";
      container.style.marginTop = "12px";
      container.style.padding = "12px";
      container.style.border = "1px solid #e5e5e5";
      container.style.borderRadius = "6px";
      container.style.background = "#fafafa";
    
      const title = document.createElement("strong");
      title.textContent = "Настройки слайдера товаров";
      container.appendChild(title);
    
      // --- CATEGORY SELECT ---
      const categoryWrap = document.createElement("div");
      categoryWrap.className = "block-field";
      categoryWrap.style.marginTop = "10px";
    
      const categoryLabel = document.createElement("label");
      categoryLabel.textContent = "Категория товаров";
      categoryWrap.appendChild(categoryLabel);
    
      const categorySelect = document.createElement("select");
      categorySelect.className = "form-control";
      categorySelect.style.maxWidth = "420px";
    
      const emptyOption = document.createElement("option");
      emptyOption.value = "";
      emptyOption.textContent = "Выберите категорию";
      categorySelect.appendChild(emptyOption);
    
      // используем this.categories (у тебя там top_level категории)
      this.categories.forEach(ctg => {
        const opt = document.createElement("option");
        opt.value = ctg.ikea_id;
        opt.textContent = ctg.name;
        if (String(block.slider_category_id || "") === String(ctg.ikea_id)) {
          opt.selected = true;
        }
        categorySelect.appendChild(opt);
      });
    
      categoryWrap.appendChild(categorySelect);
      container.appendChild(categoryWrap);
    
      // --- PRODUCTS SEARCH + LIST ---
      const productsWrap = document.createElement("div");
      productsWrap.className = "block-field";
      productsWrap.style.marginTop = "12px";
    
      const productsLabel = document.createElement("label");
      productsLabel.textContent = "Товары в слайдере";
      productsWrap.appendChild(productsLabel);
    
      const hint = document.createElement("div");
      hint.className = "text-muted";
      hint.style.fontSize = "12px";
      hint.style.marginBottom = "6px";
      hint.textContent = "Сначала выберите категорию, затем начните вводить название или SKU и добавляйте товары.";
      productsWrap.appendChild(hint);
    
      const searchInput = document.createElement("input");
      searchInput.type = "text";
      searchInput.placeholder = "Поиск товара (название или SKU)...";
      searchInput.className = "form-control";
      searchInput.style.maxWidth = "520px";
      productsWrap.appendChild(searchInput);
    
      const dropdown = document.createElement("div");
      dropdown.className = "block-products-dropdown";
      dropdown.style.position = "relative";
      dropdown.style.maxWidth = "520px";
    
      const list = document.createElement("div");
      list.className = "block-products-dropdown-list";
      list.style.border = "1px solid #ddd";
      list.style.borderTop = "none";
      list.style.background = "#fff";
      list.style.maxHeight = "240px";
      list.style.overflow = "auto";
      list.style.display = "none";
      list.style.zIndex = "10";
    
      dropdown.appendChild(list);
      productsWrap.appendChild(dropdown);
    
      const selectedWrap = document.createElement("div");
      selectedWrap.className = "block-products-selected";
      selectedWrap.style.display = "flex";
      selectedWrap.style.flexWrap = "wrap";
      selectedWrap.style.gap = "6px";
      selectedWrap.style.marginTop = "10px";
      productsWrap.appendChild(selectedWrap);
    
      container.appendChild(productsWrap);
    
      // локальное состояние
      let currentProducts = [];
      const selectedSkus = new Set(Array.isArray(block.slider_product_skus) ? block.slider_product_skus : []);
    
      const renderSelected = () => {
        selectedWrap.innerHTML = "";
        if (selectedSkus.size === 0) {
          const empty = document.createElement("div");
          empty.className = "text-muted";
          empty.style.fontSize = "12px";
          empty.textContent = "Товары не выбраны";
          selectedWrap.appendChild(empty);
          return;
        }
    
        selectedSkus.forEach(sku => {
          const chip = document.createElement("span");
          chip.style.display = "inline-flex";
          chip.style.alignItems = "center";
          chip.style.gap = "6px";
          chip.style.padding = "6px 10px";
          chip.style.borderRadius = "14px";
          chip.style.border = "1px solid #ddd";
          chip.style.background = "#fff";
          chip.style.fontSize = "12px";
    
          const product = currentProducts.find(p => String(p.sku) === String(sku));
          const label = document.createElement("span");
          label.textContent = product ? `${product.name} (${product.sku})` : String(sku);
          chip.appendChild(label);
    
          const removeBtn = document.createElement("button");
          removeBtn.type = "button";
          removeBtn.textContent = "×";
          removeBtn.style.border = "none";
          removeBtn.style.background = "transparent";
          removeBtn.style.cursor = "pointer";
          removeBtn.style.fontSize = "16px";
          removeBtn.style.lineHeight = "1";
          removeBtn.addEventListener("click", () => {
            selectedSkus.delete(sku);
            this.blocks[index].slider_product_skus = Array.from(selectedSkus);
            this.syncHiddenField();
            renderSelected();
          });
    
          chip.appendChild(removeBtn);
          selectedWrap.appendChild(chip);
        });
      };
    
      const closeList = () => { list.style.display = "none"; };
      const openList = () => { if (list.childElementCount > 0) list.style.display = "block"; };
    
      const renderList = (items) => {
        list.innerHTML = "";
        if (!items || items.length === 0) {
          const empty = document.createElement("div");
          empty.style.padding = "10px";
          empty.className = "text-muted";
          empty.style.fontSize = "12px";
          empty.textContent = "Ничего не найдено";
          list.appendChild(empty);
          return;
        }
    
        items.forEach(item => {
          const row = document.createElement("div");
          row.style.padding = "10px";
          row.style.cursor = "pointer";
          row.style.borderBottom = "1px solid #f0f0f0";
          row.textContent = `${item.name} (${item.sku})`;
    
          if (selectedSkus.has(item.sku)) {
            row.style.opacity = "0.5";
          }
    
          row.addEventListener("click", () => {
            if (selectedSkus.has(item.sku)) return;
            selectedSkus.add(item.sku);
    
            this.blocks[index].slider_product_skus = Array.from(selectedSkus);
            this.syncHiddenField();
            renderSelected();
    
            searchInput.value = "";
            closeList();
          });
    
          list.appendChild(row);
        });
      };
    
      const applyFilter = () => {
        const q = (searchInput.value || "").trim().toLowerCase();
        if (!q) {
          closeList();
          return;
        }
        const filtered = currentProducts
          .filter(p => String(p.name || "").toLowerCase().includes(q) || String(p.sku || "").toLowerCase().includes(q))
          .slice(0, 50);
    
        renderList(filtered);
        openList();
      };
    
      // события поиска
      searchInput.addEventListener("input", applyFilter);
      searchInput.addEventListener("focus", applyFilter);
      document.addEventListener("click", (e) => {
        if (!container.contains(e.target)) closeList();
      });
    
      // подгружаем товары при выборе категории
      const loadCategory = async (categoryId) => {
        // фиксируем в блок
        this.blocks[index].slider_category_id = categoryId || null;
    
        // при смене категории логично сбросить выбранные товары
        selectedSkus.clear();
        this.blocks[index].slider_product_skus = [];
        this.syncHiddenField();
    
        currentProducts = [];
        renderSelected();
    
        searchInput.value = "";
        closeList();
    
        if (!categoryId) return;
    
        const products = await this.fetchProductsByCategory(categoryId);
        currentProducts = Array.isArray(products) ? products : [];
        renderSelected(); // теперь чипы будут показывать name (если вдруг что-то восстановится)
      };
    
      categorySelect.addEventListener("change", async (e) => {
        await loadCategory(e.target.value);
      });
    
      // initial load если категория уже была сохранена
      (async () => {
        const initialCategory = block.slider_category_id;
        if (initialCategory) {
          // важно: НЕ сбрасываем выбранное при первом рендере
          const products = await this.fetchProductsByCategory(initialCategory);
          currentProducts = Array.isArray(products) ? products : [];
          renderSelected();
        } else {
          renderSelected();
        }
      })();
    
      return container;
    }    

    buildBlockHeader(block, index) {
      const header = document.createElement("div");
      header.className = "block-card-header";

      const title = document.createElement("strong");
      title.textContent = `Блок ${index + 1}`;
      header.appendChild(title);

      const select = document.createElement("select");
      select.className = "block-card-template-select";
      this.templates.forEach(template => {
        const option = document.createElement("option");
        option.value = template.id;
        option.textContent = template.label;
        if (template.id === block.type) {
          option.selected = true;
        }
        select.appendChild(option);
      });
      select.addEventListener("change", event => {
        this.changeBlockTemplate(index, event.target.value);
      });
      header.appendChild(select);

      const moveControls = document.createElement("div");
      moveControls.className = "block-move-controls";

      const upButton = document.createElement("button");
      upButton.type = "button";
      upButton.className = "block-move-button";
      upButton.textContent = "↑";
      upButton.title = "Переместить вверх";
      upButton.addEventListener("click", () => this.moveBlock(index, -1));
      moveControls.appendChild(upButton);

      const downButton = document.createElement("button");
      downButton.type = "button";
      downButton.className = "block-move-button";
      downButton.textContent = "↓";
      downButton.title = "Переместить вниз";
      downButton.addEventListener("click", () => this.moveBlock(index, 1));
      moveControls.appendChild(downButton);

      header.appendChild(moveControls);

      const removeButton = document.createElement("button");
      removeButton.type = "button";
      removeButton.className = "block-card-remove";
      removeButton.textContent = "Удалить";
      removeButton.addEventListener("click", () => this.removeBlock(index));
      header.appendChild(removeButton);

      return header;
    }

    buildContentField(block, index) {
      const container = document.createElement("div");
      container.className = "block-content-field";

      const label = document.createElement("label");
      label.textContent = "Контент блока";
      container.appendChild(label);

      const textarea = document.createElement("textarea");
      textarea.className = "content-article-block-content";
      textarea.value = block.content || "";
      textarea.addEventListener("input", () => {
        this.updateBlockContent(index, textarea.value);
      });
      textarea.placeholder = "Введите текст блока";
      container.appendChild(textarea);

      return container;
    }

    buildButtonSettings(block, index) {
      const container = document.createElement("div");
      container.className = "block-button-settings";

      const textWrapper = document.createElement("div");
      textWrapper.className = "block-field";
      const textLabel = document.createElement("label");
      textLabel.textContent = "Текст кнопки";
      textWrapper.appendChild(textLabel);

      const textInput = document.createElement("input");
      textInput.type = "text";
      textInput.value = block.button_text || "";
      textInput.placeholder = "Например, Подробнее";
      textInput.addEventListener("input", event => {
        this.blocks[index].button_text = event.target.value;
        this.syncHiddenField();
      });
      textWrapper.appendChild(textInput);
      container.appendChild(textWrapper);

      const selectWrapper = document.createElement("div");
      selectWrapper.className = "block-field";
      const selectLabel = document.createElement("label");
      selectLabel.textContent = "Категория";
      selectWrapper.appendChild(selectLabel);

      const select = document.createElement("select");
      const emptyOption = document.createElement("option");
      emptyOption.value = "";
      emptyOption.textContent = "Категория не выбрана";
      select.appendChild(emptyOption);
      this.categories.forEach(category => {
        const option = document.createElement("option");
        option.value = category.ikea_id;
        option.textContent = category.name;
        if (category.ikea_id === block.button_category_id) {
          option.selected = true;
        }
        select.appendChild(option);
      });
      select.addEventListener("change", event => {
        this.blocks[index].button_category_id = event.target.value || null;
        this.syncHiddenField();
      });
      selectWrapper.appendChild(select);
      container.appendChild(selectWrapper);

      return container;
    }

    pullSignedIdsFromForm() {
      // пробегаем по всем карточкам блоков в DOM
      const cards = this.container.querySelectorAll(".content-article-block-card");
    
      cards.forEach(card => {
        const blockIndex = Number(card.dataset.blockIndex);
        if (Number.isNaN(blockIndex)) return;
    
        // все file inputs (по слотам)
        const fileInputs = card.querySelectorAll("input[type='file'][data-block-image-slot]");
    
        fileInputs.forEach(fileInput => {
          const slot = fileInput.dataset.blockImageSlot;
          if (!slot) return;
    
          // ActiveStorage создаёт hidden с тем же name, что и у file input
          // либо рядом, либо внутри поля
          let hidden =
            card.querySelector(`input[type="hidden"][name="${fileInput.name}"]`) ||
            (fileInput.nextElementSibling?.type === "hidden" ? fileInput.nextElementSibling : null);
    
          if (!hidden || !hidden.value) return;
    
          // НЕ ререндерим блоки на сабмите — просто обновляем данные
          const block = this.blocks[blockIndex];
          if (!block) return;
    
          block.images = (block.images || []).map(img => {
            if (img.slot === slot) {
              return { ...img, signed_id: hidden.value };
            }
            return img;
          });
        });
      });
    }

    buildImageFields(block, index) {
      const container = document.createElement("div");
      container.className = "block-image-grid";

      block.images.forEach(image => {
        const field = document.createElement("div");
        field.className = "block-image-field";

      const template = this.templates.find(t => t.id === block.type);
      const slotInfo =
        template && Array.isArray(template.image_slots)
          ? template.image_slots.find(slot => slot.name === image.slot)
          : null;
      const label = document.createElement("label");
      label.textContent = (slotInfo && slotInfo.label) || image.slot;
        field.appendChild(label);

        const previewContainer = document.createElement("div");
        previewContainer.className = "block-image-preview-container";
        previewContainer.dataset.slot = image.slot;
        previewContainer.style.marginBottom = "10px";
        
        // CURRENT preview (gray)
        const currentPreview = document.createElement("div");
        currentPreview.className = "block-image-preview-current";
        currentPreview.style.marginBottom = "10px";
        currentPreview.style.padding = "10px";
        currentPreview.style.background = "#f8f9fa";
        currentPreview.style.borderRadius = "4px";
        
        const currentImg = document.createElement("img");
        currentImg.className = "block-image-preview-current-img";
        currentImg.style.maxWidth = "400px";
        currentImg.style.maxHeight = "300px";
        currentImg.style.display = "block";
        currentImg.style.margin = "0 auto";
        currentImg.style.border = "1px solid #ddd";
        currentImg.style.borderRadius = "4px";
        
        const currentCaption = document.createElement("p");
        currentCaption.textContent = "Текущее изображение";
        currentCaption.style.textAlign = "center";
        currentCaption.style.marginTop = "10px";
        currentCaption.style.color = "#666";
        currentCaption.style.fontSize = "12px";
        
        currentPreview.appendChild(currentImg);
        currentPreview.appendChild(currentCaption);
        
        // NEW preview (green, hidden by default)
        const newPreview = document.createElement("div");
        newPreview.className = "block-image-preview-new";
        newPreview.style.display = "none";
        newPreview.style.marginBottom = "10px";
        newPreview.style.padding = "10px";
        newPreview.style.background = "#e8f5e9";
        newPreview.style.borderRadius = "4px";
        
        const newImg = document.createElement("img");
        newImg.className = "block-image-preview-new-img";
        newImg.style.maxWidth = "400px";
        newImg.style.maxHeight = "300px";
        newImg.style.display = "block";
        newImg.style.margin = "0 auto";
        newImg.style.border = "1px solid #4caf50";
        newImg.style.borderRadius = "4px";
        
        const newCaption = document.createElement("p");
        newCaption.textContent = "Предпросмотр нового изображения";
        newCaption.style.textAlign = "center";
        newCaption.style.marginTop = "10px";
        newCaption.style.color = "#2e7d32";
        newCaption.style.fontSize = "12px";
        newCaption.style.fontWeight = "bold";
        
        newPreview.appendChild(newImg);
        newPreview.appendChild(newCaption);
        
        // Fill CURRENT if present, else show placeholder
        const persistedUrl = (!image.url && image.signed_id) ? this.blobRedirectUrl(image) : null;

        if (image.url || persistedUrl) {
          currentImg.src = image.url || persistedUrl;
          currentPreview.style.display = "block";
        } else {
          currentPreview.style.display = "block";
          currentImg.remove();
          const placeholder = document.createElement("span");
          placeholder.textContent = "Нет изображения";
          placeholder.className = "text-muted";
          currentPreview.insertBefore(placeholder, currentCaption);
          currentCaption.textContent = "Текущее изображение отсутствует";
        }
        
        previewContainer.appendChild(currentPreview);
        previewContainer.appendChild(newPreview);
        field.appendChild(previewContainer);

        const fileInput = document.createElement("input");
        fileInput.name = `content_article[body_block_images_uploads][${index}][${image.slot}]`;
        fileInput.type = "file";
        fileInput.accept = "image/*";
        fileInput.dataset.blockImageSlot = image.slot;
        fileInput.dataset.blockIndex = index;
        if (this.directUploadUrl) {
          fileInput.dataset.directUploadUrl = this.directUploadUrl;
        }
        field.appendChild(fileInput);

        // Instant preview on file select (before direct upload success)
        fileInput.addEventListener("change", (e) => {
          const file = e.target.files && e.target.files[0];
          const container = field.querySelector(".block-image-preview-container");
          if (!container) return;

          const curr = container.querySelector(".block-image-preview-current");
          const next = container.querySelector(".block-image-preview-new");
          const nextImg = container.querySelector(".block-image-preview-new-img");

          if (!file) {
            // no file selected -> revert to current
            if (next) next.style.display = "none";
            if (curr) curr.style.display = "block";
            return;
          }

          // show new preview and hide current
          if (curr) curr.style.display = "none";
          if (next) next.style.display = "block";

          // preview via object URL (fast) + revoke later
          const objectUrl = URL.createObjectURL(file);
          if (nextImg) nextImg.src = objectUrl;

          // avoid memory leak
          if (nextImg) {
            nextImg.onload = () => {
              try { URL.revokeObjectURL(objectUrl); } catch (_) {}
            };
          }
        });

        const actions = document.createElement("div");
        actions.className = "block-image-actions";
        const clearButton = document.createElement("button");
        clearButton.type = "button";
        clearButton.textContent = "Удалить изображение";
        clearButton.addEventListener("click", () => this.clearImage(index, image.slot));
        actions.appendChild(clearButton);
        field.appendChild(actions);

        container.appendChild(field);
      });

      return container;
    }

    changeBlockTemplate(index, templateId) {
      const existing = this.blocks[index];
      const nextBlock = this.createBlockFromTemplate(templateId, existing);
      if (!nextBlock) return;
      this.blocks[index] = nextBlock;
      this.renderBlocks();
    }

    updateBlockContent(index, value) {
      this.blocks[index].content = value;
      this.syncHiddenField();
    }

    removeBlock(index) {
      this.blocks.splice(index, 1);
      this.renderBlocks();
    }

    moveBlock(index, direction) {
      const newIndex = index + direction;
      if (newIndex < 0 || newIndex >= this.blocks.length) return;
      const [block] = this.blocks.splice(index, 1);
      this.blocks.splice(newIndex, 0, block);
      this.renderBlocks();
    }

    clearImage(blockIndex, slot) {
      const block = this.blocks[blockIndex];
      block.images = block.images.map(image => {
        if (image.slot === slot) {
          return { ...image, signed_id: null, url: null };
        }
        return image;
      });
      this.renderBlocks();
    }

    setImageValue(blockIndex, slot, signedId, previewUrl, filename) {
      const block = this.blocks[blockIndex];
      block.images = block.images.map(image => {
        if (image.slot === slot) {
          return { ...image, signed_id: signedId, url: previewUrl || image.url, filename: filename || image.filename };
        }
        return image;
      });
      this.renderBlocks();
    }

    handleDirectUploadSuccess(input, detail) {
      const blockEl = input.closest(".content-article-block-card");
      const slot = input.dataset.blockImageSlot;
      if (!blockEl || !slot) return;
    
      const blockIndex = Number(blockEl.dataset.blockIndex);
      if (Number.isNaN(blockIndex)) return;
    
      const uploadId = detail?.id;
    
      // 1) сначала пробуем достать signed_id напрямую из detail (на случай если версия rails его кладёт)

      const hidden = input
        .closest(".block-image-field")
        ?.querySelector(`input[type="hidden"][name="${input.name}"]`);

      let signedId = detail?.signed_id || detail?.signedId || hidden?.value;
    
      // 2) если нет — ищем hidden, который ActiveStorage добавляет при direct upload
      if (!signedId) {
        // чаще всего hidden выглядит как:
        // <input type="hidden" value="SIGNED_ID" data-direct-upload-id="...">
        const field = input.closest(".block-image-field");
    
        let hiddenInput = null;
    
        if (uploadId && field) {
          hiddenInput = field.querySelector(`input[type="hidden"][data-direct-upload-id="${uploadId}"]`);
        }
    
        // fallback: иногда hidden просто рядом
        if (!hiddenInput && input.nextElementSibling && input.nextElementSibling.type === "hidden") {
          hiddenInput = input.nextElementSibling;
        }
    
        // fallback: любой hidden внутри поля
        if (!hiddenInput && field) {
          hiddenInput = field.querySelector(`input[type="hidden"][data-direct-upload-id]`) || field.querySelector(`input[type="hidden"]`);
        }
    
        signedId = hiddenInput ? hiddenInput.value : null;
      }
    
      if (!signedId) {
        // чтобы не гадать — можно временно включить лог
        console.warn("No signed_id found for direct upload", { detail, input });
        return;
      }
    
      const file = detail?.file || input.files?.[0];
      const previewUrl = file ? URL.createObjectURL(file) : null;
      const filename = file ? file.name : null;
      
      this.setImageValue(blockIndex, slot, signedId, previewUrl, filename);
    
      // очищаем input чтобы не было повторной отправки
      input.value = "";
    }

    serializeBlocks() {
      return this.blocks.map((block, index) => ({
        type: block.type,
        content: block.content,
        button_text: block.button_text,
        button_category_id: block.button_category_id || null,
    
        slider_enabled: block.slider_enabled,
        button_enabled: block.button_enabled,
    
        // NEW:
        slider_category_id: block.slider_category_id || null,
        slider_product_skus: Array.isArray(block.slider_product_skus) ? block.slider_product_skus : [],
    
        images: block.images.map(image => ({
          slot: image.slot,
          signed_id: image.signed_id,
          filename: image.filename || null
        })),
        position: index
      }));
    }    

    syncHiddenField() {
      if (!this.hiddenField) return;
      this.hiddenField.value = JSON.stringify(this.serializeBlocks());
    }

    attachSubmitSync() {
      const form = this.container.closest("form");
      if (!form) return;
    
      // привязываем один раз на форму
      if (form.dataset.blocksSyncBound === "1") return;
      form.dataset.blocksSyncBound = "1";
    
      form.addEventListener("submit", () => {
        this.pullSignedIdsFromForm();
        this.syncHiddenField();
      });
    }

    blobRedirectUrl(image) {
      if (!image?.signed_id) return null;
      const filename = image.filename || "image";
      return `/rails/active_storage/blobs/redirect/${encodeURIComponent(image.signed_id)}/${encodeURIComponent(filename)}`;
    }
  }
})();
// This file may be used for providing additional customizations to the Trestle
// admin. It will be automatically included within all admin pages.
//
// For organizational purposes, you may wish to define your customizations
// within individual partials and `require` them here.
//
//  e.g. //= require "trestle/custom/my_custom_js"


;
