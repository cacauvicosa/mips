
function zip(f : (x : number, y : number) => number, a : Uint32Array, b : Uint32Array) {
    return a.map((x, i) => f(x, b[i]));
}

function zip4(
        f : (x : number, y : number, z : number, q : number) => number, 
        a : Uint32Array, b : Uint32Array, c : Uint32Array, d : Uint32Array) {
    return a.map((x, i) => f(x, b[i], c[i], d[i]));
}

function bitfold(f : (x : number, y : number) => number, a : Uint32Array, lastmask : number, neutral : number) {
    if (a.length == 0) return (neutral == 1) ? 1 : 0;
    let acc = a[a.length-1];
    if (neutral == 1) acc |= ~lastmask;
    else acc &= lastmask;
    for (let i = 0; i < a.length-1; i++) acc = f(acc, a[i]);
    acc = f(acc, acc >>> 16);
    acc = f(acc, acc >>> 8);
    acc = f(acc, acc >>> 4);
    acc = f(acc, acc >>> 2);
    acc = f(acc, acc >>> 1);
    return acc & 1;
}

function wordnum(n : number) {
    return n >> 5;
}

function bitnum(n : number) {
    return n & 0x1f;
}

function fillRest(m : number, k : number, words : number, 
                  avec : Uint32Array, bvec : Uint32Array) {
    const last_x = m > 0 && !(avec[k] & (1 << (m-1)))
                         &&  (bvec[k] & (1 << (m-1)));
    if (last_x && bitnum(m)) bvec[k] |= (-1) << m;
    if (last_x && k + 1 < words) {
        bvec.fill(-1, k + 1);
    }
}

function makeMap(bits : number, depth : number) {
    const ret = {};
    function g(what : string, val : number) {
        ret[what] = val;
        if (what.length * bits >= depth)
            return;
        for (let i = 0; i < (1 << bits); i += 1)
            g(what + i.toString(1 << bits), (val << bits) | i | (i << 16));
        g(what + 'x', (val << bits) | ((1 << bits) - 1));
    }
    g("", 0);
    Object.seal(ret);
    return ret;
}

const fromBinMap = makeMap(1, 8);
const fromOctMap = makeMap(3, 3);
const fromHexMap = makeMap(4, 8);

function toHexInternal(start : number, bits : number, avec : Uint32Array, bvec : Uint32Array) {
    // copy-paste'y code for performance
    const out = [];
    let bit = 0, k = start;
    while (bit < bits) {
        const a = '00000000' + avec[k].toString(16);
        const x = avec[k] ^ bvec[k];
        k++;
        for (let b = 0; b < 8 && bit < bits; b++, bit += 4) {
            if (x & (0xf << 4 * b)) out.push('x');
            else out.push(a[a.length - 1 - b]);
        }
    }
    return out.reverse().join('');
}

function toBinInternal(start : number, bits : number, avec : Uint32Array, bvec : Uint32Array) {
    // copy-paste'y code for performance
    const out = [];
    let bit = 0, k = start;
    while (bit < bits) {
        const a = '00000000000000000000000000000000' 
                + avec[k].toString(2);
        const x = avec[k] ^ bvec[k];
        k++;
        for (let b = 0; b < 32 && bit < bits; b++, bit++) {
            if (x & (1 << b)) out.push('x');
            else out.push(a[a.length - 1 - b]);
        }
    }
    return out.reverse().join('');
}

function fromHexInternal(data : string, start : number, nbits : number, avec : Uint32Array, bvec : Uint32Array) {
    // copy-paste'y code for performance
    const skip = 4;
    const words = (nbits + 31) >>> 5;
    let m = 0, k = -1 + start;
    for (let i = data.length; i > 0; ) {
        const frag = data.slice(Math.max(0, i-2), i);
        i -= frag.length;
        const v = fromHexMap[frag];
        if (bitnum(m) == 0)
            k++;
        const mask = (1 << skip * frag.length) - 1;
        avec[k] |= ((v >>> 16) & mask) << m;
        bvec[k] |= (v & mask) << m;
        m += skip * frag.length;
    }
    if (m < nbits) fillRest(m, k, words, avec, bvec);
}

function fromBinInternal(data : string, start: number, nbits : number, avec : Uint32Array, bvec : Uint32Array) {
    // copy-paste'y code for performance
    const skip = 1;
    const words = (nbits + 31) >>> 5;
    let m = 0, k = -1 + start;
    for (let i = data.length; i > 0; ) {
        const frag = data.slice(Math.max(0, i-8), i);
        i -= frag.length;
        const v = fromBinMap[frag];
        if (bitnum(m) == 0)
            k++;
        const mask = (1 << skip * frag.length) - 1;
        avec[k] |= ((v >>> 16) & mask) << m;
        bvec[k] |= (v & mask) << m;
        m += skip * frag.length;
    }
    if (m < nbits) fillRest(m, k, words, avec, bvec);
}

/**
 * Type for initialization values.
 * * false, -1, '0' mean logical 0,
 * * 0, 'x' mean undefined value,
 * * true, 1, '1' mean logical 1.
 */
type InitType = 1 | 0 | -1 | boolean | '1' | '0' | 'x';

/** 
 * Three-value logic vectors.
 *
 * This is a data class -- its contents are not mutable. Operations on logic
 * vectors return a freshly allocated vector.
 *
 * The internal representation is two bit vectors: bit vector A and B.
 * The value at position _n_ is encoded by two bits, one at position _n_ in
 * bit vector A, the other at same position in bit vector B. The bit
 * combinations have the following meanings:
 *
 * * A: 0, B: 0 -- logical 0,
 * * A: 0, B: 1 -- undefined value, "x",
 * * A: 1, B: 1 -- logical 1.
 */
export class Vector3vl {

    /**
     * Number of bits in the vector.
     */
    private _bits : number;

    /**
     * Bit vector A.
     */
    private _avec : Uint32Array;

    /**
     * Bit vector B.
     */
    private _bvec : Uint32Array;

    /**
     * Private constructor for three-value logic vectors. 
     *
     * **Only for internal use.**
     *
     * @param bits Number of bits in the vector.
     * @param avec Bit vector A.
     * @param bvec Bit vector B.
     */
    private constructor(bits : number, avec : Uint32Array, bvec : Uint32Array) {
        this._bits = bits;
        this._avec = avec;
        this._bvec = bvec;
    }

    /**
     * Construct a vector with a constant value at each position.
     *
     * @param bits Number of bits in the vector.
     * @param init Initializer. Recognized values:
     * * false, -1, '0' for logical 0,
     * * 0, 'x' for undefined value,
     * * true, 1, '1' for logical 1.
     */
    static make(bits : number, init : InitType) {
        bits = bits | 0;
        let iva, ivb;
        switch(init) {
            case true: case '1': case 1: iva = ivb = ~0; break;
            case false: case '0': case -1: case undefined: iva = ivb = 0; break;
            case 'x': case 0: iva = 0; ivb = ~0; break;
            default: console.assert(false);
        }
        const words = (bits+31)/32 | 0;
        return new Vector3vl(bits,
            new Uint32Array(words).fill(iva),
            new Uint32Array(words).fill(ivb));
    }

    /** 
     * Construct a vector containing only zeros.
     *
     * @param bits Number of bits in the vector.
     */
    static zeros(bits : number) {
        return Vector3vl.make(bits, -1);
    }

    /** 
     * Construct a vector containing only ones.
     *
     * @param bits Number of bits in the vector.
     */
    static ones(bits : number) {
        return Vector3vl.make(bits, 1);
    }

    /** 
     * Construct a vector containing only undefined values.
     *
     * @param bits Number of bits in the vector.
     */
    static xes(bits : number) {
        return Vector3vl.make(bits, 0);
    }

    /**
     * An empty vector. 
     */
    static empty = Vector3vl.zeros(0);

    /**
     * A single one.
     */
    static one = Vector3vl.ones(1);

    /**
     * A single zero.
     */
    static zero = Vector3vl.zeros(1);

    /**
     * A single undefined value.
     */
    static x = Vector3vl.xes(1);

    /**
     * Construct a singleton vector containing _b_.
     */
    static fromBool(b : boolean) {
        return Vector3vl.make(1, b ? 1 : -1);
    }

    /**
     * Concatenate vectors into a single big vector.
     *
     * @param vs Vectors to concatenate.
     *           Arguments are ordered least significant bit first.
     */
    static concat(...vs : Vector3vl[]) {
        const sumbits = vs.reduce((y, x) => x.bits + y, 0);
        const words = (sumbits + 31) >>> 5;
        let bits = 0, idx = -1, avec = new Uint32Array(words), bvec = new Uint32Array(words);
        for (const v of vs) {
            v.normalize();
            if (bitnum(bits) == 0) {
                avec.set(v._avec, idx + 1);
                bvec.set(v._bvec, idx + 1);
                bits += v._bits;
                idx += (v._bits + 31) >>> 5;
            } else {
                for (const k in v._avec) {
                    avec[idx] |= v._avec[k] << bits;
                    bvec[idx] |= v._bvec[k] << bits;
                    idx++;
                    if (idx == words) break;
                    avec[idx] = v._avec[k] >>> -bits;
                    bvec[idx] = v._bvec[k] >>> -bits;
                }
                bits += v._bits;
                if (idx + 1 > (bits + 31) >>> 5) {
                    idx--;
                }
            }
        }
        return new Vector3vl(bits, avec, bvec);
    }

    /**
     * Construct a vector from an iterable.
     *
     * This function calls [[fromIteratorAnySkip]] or [[fromIteratorPow2]].
     *
     * @param iter Iterable returning initialization values, least to most
     *             significant. First _skip_ bits go to vector B, next
     *             _skip_ bits go to vector A.
     * @param skip Number of bits in a single iterator step. 1 to 16.
     * @param nbits Number of bits in the vector.
     */
    static fromIterator(iter : Iterable<number>, skip : number, nbits : number) {
        if ((skip & (skip - 1)) == 0)
            return Vector3vl.fromIteratorPow2(iter, skip, nbits);
        else return Vector3vl.fromIteratorAnySkip(iter, skip, nbits);
    }

    /**
     * Construct a vector from an iterable.
     *
     * This function is more generic, but slower, than [[fromIteratorPow2]].
     *
     * @param iter Iterable returning initialization values, least to most
     *             significant. First _skip_ bits go to vector B, next
     *             _skip_ bits go to vector A.
     * @param skip Number of bits in a single iterator step. 1 to 16.
     * @param nbits Number of bits in the vector.
     */
    static fromIteratorAnySkip(iter : Iterable<number>, skip : number, nbits : number) {
        const words = (nbits + 31) >>> 5;
        let m = 0, k = -1,
            avec = new Uint32Array(words),
            bvec = new Uint32Array(words);
        const mask = (1 << skip) - 1;
        for (const v of iter) {
            if (bitnum(m) == 0)
                k++;
            avec[k] |= ((v >>> skip) & mask) << m;
            bvec[k] |= (v & mask) << m;
            if (((mask << m) >>> m) != mask) {
                k++;
                avec[k] = ((v >>> skip) & mask) >>> -m;
                bvec[k] = (v & mask) >>> -m;
            }
            m += skip;
        }
        if (m < nbits) fillRest(m, k, words, avec, bvec);
        return new Vector3vl(nbits, avec, bvec);
    }

    /**
     * Construct a vector from an iterable.
     *
     * This function is limited to power of 2 _skip_ values.
     * For generic version, see [[fromIteratorAnySkip]].
     *
     * @param iter Iterable returning initialization values, least to most
     *             significant. First _skip_ bits go to vector B, next
     *             _skip_ bits go to vector A.
     * @param skip Number of bits in a single iterator step.
     *             Limited to powers of 2: 1, 2, 4, 8, 16.
     * @param nbits Number of bits in the vector.
     */
    static fromIteratorPow2(iter : Iterable<number>, skip : number, nbits : number) {
        const words = (nbits + 31) >>> 5;
        let m = 0, k = -1,
            avec = new Uint32Array(words),
            bvec = new Uint32Array(words);
        const mask = (1 << skip) - 1;
        for (const v of iter) {
            if (bitnum(m) == 0)
                k++;
            avec[k] |= ((v >>> skip) & mask) << m;
            bvec[k] |= (v & mask) << m;
            m += skip;
        }
        if (m < nbits) fillRest(m, k, words, avec, bvec);
        return new Vector3vl(nbits, avec, bvec);
    }

    /**
     * Construct a vector from an array of numbers.
     *
     * The following interpretation is used:
     * * -1 for logical 0,
     * * 0 for undefined value,
     * * 1 for logical 1.
     *
     * @param data Input array.
     */
    static fromArray(data : number[]) {
        // copy-paste'y code for performance
        const nbits = data.length;
        const skip = 1;
        const words = (nbits + 31) >>> 5;
        let m = 0, k = -1,
            avec = new Uint32Array(words),
            bvec = new Uint32Array(words);
        const mask = (1 << skip) - 1;
        for (const x of data) {
            const v = x + 1 + Number(x > 0);
            if (bitnum(m) == 0)
                k++;
            avec[k] |= ((v >>> skip) & mask) << m;
            bvec[k] |= (v & mask) << m;
            m += skip;
        }
        if (m < nbits) fillRest(m, k, words, avec, bvec);
        return new Vector3vl(nbits, avec, bvec);
    }

    /**
     * Construct a vector from a binary string.
     *
     * Three characters are accepted:
     * * '0' for logical 0,
     * * 'x' for undefined value,
     * * '1' for logical 1.
     *
     * If _nbits_ is given, _data_ is either truncated, or extended with
     * undefined values.
     *
     * @param data The binary string to be parsed.
     * @param nbits Number of bits in the vector. If omitted, the resulting
     *              vector has number of bits equal to the length of _data_.
     */
    static fromBin(data : string, nbits? : number) {
        if (nbits === undefined) nbits = data.length;
        const words = (nbits + 31) >>> 5;
        const avec = new Uint32Array(words),
              bvec = new Uint32Array(words);
        fromBinInternal(data, 0, nbits, avec, bvec);
        return new Vector3vl(nbits, avec, bvec);
    }

    /**
     * Construct a vector from an octal number.
     *
     * Characters '0' to '7' and 'x' are accepted. The character 'x'
     * means three undefined bits.
     *
     * If _nbits_ is given, _data_ is either truncated, or extended with
     * undefined values.
     *
     * @param data The octal string to be parsed.
     * @param nbits Number of bits in the vector. If omitted, the resulting
     *              vector has number of bits equal to the length of _data_
     *              times three.
     */
    static fromOct(data : string, nbits? : number) {
        // copy-paste'y code for performance
        const skip = 3;
        if (nbits === undefined) nbits = data.length * skip;
        const words = (nbits + 31) >>> 5;
        let m = 0, k = -1,
            avec = new Uint32Array(words),
            bvec = new Uint32Array(words);
        const mask = (1 << skip) - 1;
        for (let i = data.length - 1; i >= 0; i--) {
            const v = fromOctMap[data[i]];
            if (bitnum(m) == 0)
                k++;
            avec[k] |= ((v >>> 16) & mask) << m;
            bvec[k] |= (v & mask) << m;
            if (((mask << m) >>> m) != mask) {
                k++;
                avec[k] = ((v >>> 16) & mask) >>> -m;
                bvec[k] = (v & mask) >>> -m;
            }
            m += skip;
        }
        if (m < nbits) fillRest(m, k, words, avec, bvec);
        return new Vector3vl(nbits, avec, bvec);
    }

    /**
     * Construct a vector from a hexadecimal number.
     *
     * Characters '0' to '9', 'a' to 'f' and 'x' are accepted. The character
     * 'x' means three undefined bits.
     *
     * If _nbits_ is given, _data_ is either truncated, or extended with
     * undefined values.
     *
     * @param data The hexadecimal string to be parsed.
     * @param nbits Number of bits in the vector. If omitted, the resulting
     *              vector has number of bits equal to the length of _data_
     *              times four.
     */
    static fromHex(data : string, nbits? : number) {
        if (nbits === undefined) nbits = data.length * 4;
        const words = (nbits + 31) >>> 5;
        const avec = new Uint32Array(words),
              bvec = new Uint32Array(words);
        fromHexInternal(data, 0, nbits, avec, bvec);
        return new Vector3vl(nbits, avec, bvec);
    }

    /**
     * Number of bits in the vector.
     */
    get bits() : number {
        return this._bits;
    }

    /**
     * Most significant bit in the vector. Returns -1, 0 or 1.
     */
    get msb() : number {
        return this.get(this._bits - 1);
    }

    /**
     * Least significant bit in the vector. Returns -1, 0 or 1.
     */
    get lsb() : number {
        return this.get(0);
    }

    /**
     * Gets _n_th value in the vector. Returns -1, 0 or 1.
     */
    get(n : number) {
        const bn = bitnum(n);
        const wn = wordnum(n);
        const a = (this._avec[wn] >>> bn) & 1;
        const b = (this._bvec[wn] >>> bn) & 1;
        return a + b - 1;
    }

    /**
     * Tests if the vector is all ones.
     */
    get isHigh() : boolean {
        if (this._bits == 0) return true;
        const lastmask = this._lastmask;
        const vechigh = (vec : Uint32Array) =>
            vec.slice(0, vec.length-1).every(x => ~x == 0) && (vec[vec.length-1] & lastmask) == lastmask;
        return vechigh(this._avec) && vechigh(this._bvec);
    }
    
    /**
     * Tests if the vector is all zeros.
     */
    get isLow() : boolean {
        if (this._bits == 0) return true;
        const lastmask = this._lastmask;
        const veclow = (vec : Uint32Array) =>
            vec.slice(0, vec.length-1).every(x => x == 0) && (vec[vec.length-1] & lastmask) == 0;
        return veclow(this._avec) && veclow(this._bvec);
    }

    /**
     * Tests if there is any defined bit in the vector.
     */
    get isDefined() : boolean {
        if (this._bits == 0) return false;
        const dvec = zip((a, b) => a ^ b, this._avec, this._bvec);
        dvec[dvec.length-1] |= ~this._lastmask;
        return !dvec.every(x => ~x == 0);
    }

    /**
     * Tests if every bit in the vector is defined.
     */
    get isFullyDefined() : boolean {
        if (this._bits == 0) return true;
        const dvec = zip((a, b) => a ^ b, this._avec, this._bvec);
        dvec[dvec.length-1] &= this._lastmask;
        return !dvec.some(x => Boolean(x));
    }

    /**
     * Bitwise AND of two vectors.
     *
     * The vectors need to be the same bit length.
     *
     * @param v The other vector.
     */
    and(v : Vector3vl) {
        console.assert(v._bits == this._bits);
        return new Vector3vl(this._bits,
            zip((a, b) => a & b, v._avec, this._avec),
            zip((a, b) => a & b, v._bvec, this._bvec));
    }

    /**
     * Bitwise OR of two vectors.
     *
     * The vectors need to be the same bit length.
     *
     * @param v The other vector.
     */
    or(v : Vector3vl) {
        console.assert(v._bits == this._bits);
        return new Vector3vl(this._bits,
            zip((a, b) => a | b, v._avec, this._avec),
            zip((a, b) => a | b, v._bvec, this._bvec));
    }

    /**
     * Bitwise XOR of two vectors.
     *
     * The vectors need to be the same bit length.
     *
     * @param v The other vector.
     */
    xor(v : Vector3vl) {
        console.assert(v._bits == this._bits);
        return new Vector3vl(this._bits,
            zip4((a1, a2, b1, b2) => (a1 | b1) & (a2 ^ b2),
                 v._avec, v._bvec, this._avec, this._bvec),
            zip4((a1, a2, b1, b2) => (a1 & b1) ^ (a2 | b2),
                 v._avec, v._bvec, this._avec, this._bvec));
    }

    /**
     * Bitwise NAND of two vectors.
     *
     * The vectors need to be the same bit length.
     *
     * @param v The other vector.
     */
    nand(v : Vector3vl) {
        console.assert(v._bits == this._bits);
        return new Vector3vl(this._bits,
            zip((a, b) => ~(a & b), v._bvec, this._bvec),
            zip((a, b) => ~(a & b), v._avec, this._avec));
    }

    /**
     * Bitwise NOR of two vectors.
     *
     * The vectors need to be the same bit length.
     *
     * @param v The other vector.
     */
    nor(v : Vector3vl) {
        console.assert(v._bits == this._bits);
        return new Vector3vl(this._bits,
            zip((a, b) => ~(a | b), v._bvec, this._bvec),
            zip((a, b) => ~(a | b), v._avec, this._avec));
    }

    /**
     * Bitwise XNOR of two vectors.
     *
     * The vectors need to be the same bit length.
     *
     * @param v The other vector.
     */
    xnor(v : Vector3vl) {
        console.assert(v._bits == this._bits);
        return new Vector3vl(this._bits,
            zip4((a1, a2, b1, b2) => ~((a1 & b1) ^ (a2 | b2)),
                 v._avec, v._bvec, this._avec, this._bvec),
            zip4((a1, a2, b1, b2) => ~((a1 | b1) & (a2 ^ b2)),
                 v._avec, v._bvec, this._avec, this._bvec));
    }

    /**
     * Bitwise NOT of a vector. */
    not() {
        return new Vector3vl(this._bits,
            this._bvec.map(a => ~a),
            this._avec.map(a => ~a));
    }

    /**
     * Return a vector with 1 on locations with x, the rest with 0.
     */
    xmask() {
        const v = zip((a, b) => a ^ b, this._avec, this._bvec);
        return new Vector3vl(this._bits, v, v);
    }

    /**
     * Reducing AND of a vector.
     *
     * ANDs all bits of the vector together, producing a single bit.
     *
     * @returns Singleton vector.
     */
    reduceAnd() {
        return new Vector3vl(1, 
            Uint32Array.of(bitfold((a, b) => a & b, this._avec, this._lastmask, 1)),
            Uint32Array.of(bitfold((a, b) => a & b, this._bvec, this._lastmask, 1)));
    }
    
    /**
     * Reducing OR of a vector.
     *
     * ORs all bits of the vector together, producing a single bit.
     *
     * @returns Singleton vector.
     */
    reduceOr() {
        return new Vector3vl(1, 
            Uint32Array.of(bitfold((a, b) => a | b, this._avec, this._lastmask, 0)),
            Uint32Array.of(bitfold((a, b) => a | b, this._bvec, this._lastmask, 0)));
    }
    
    /**
     * Reducing NAND of a vector.
     *
     * NANDs all bits of the vector together, producing a single bit.
     *
     * @returns Singleton vector.
     */
    reduceNand() {
        return new Vector3vl(1, 
            Uint32Array.of(~bitfold((a, b) => a & b, this._bvec, this._lastmask, 1)),
            Uint32Array.of(~bitfold((a, b) => a & b, this._avec, this._lastmask, 1)));
    }
    
    /**
     * Reducing NOR of a vector.
     *
     * NORs all bits of the vector together, producing a single bit.
     *
     * @returns Singleton vector.
     */
    reduceNor() {
        return new Vector3vl(1, 
            Uint32Array.of(~bitfold((a, b) => a | b, this._bvec, this._lastmask, 0)),
            Uint32Array.of(~bitfold((a, b) => a | b, this._avec, this._lastmask, 0)));
    }
    
    /**
     * Reducing XOR of a vector.
     *
     * XORs all bits of the vector together, producing a single bit.
     *
     * @returns Singleton vector.
     */
    reduceXor() {
        const xes = zip((a, b) => ~a & b, this._avec, this._bvec);
        const has_x = bitfold((a, b) => a | b, xes, this._lastmask, 0);
        const v = bitfold((a, b) => a ^ b, this._avec, this._lastmask, 0);
        return new Vector3vl(1, Uint32Array.of(v & ~has_x), Uint32Array.of(v | has_x));
    }
    
    /**
     * Reducing XNOR of a vector.
     *
     * XNORs all bits of the vector together, producing a single bit.
     *
     * @return Singleton vector.
     */
    reduceXnor() {
        return this.reduceXor().not();
    }

    /**
     * Concatenates vectors, including this one, into a single vector.
     *
     * @param vs The other vectors.
     */
    concat(...vs : Vector3vl[]) {
        return Vector3vl.concat(this, ...vs);
    }

    /**
     * Return a subvector.
     *
     * Uses same conventions as the slice function for JS arrays.
     *
     * @param start Number of the first bit to include in the result.
     *              If omitted, first bit of the vector is used.
     * @param end Number of the last bit to include in the result, plus one.
     *            If omitted, last bit of the vector is used.
     */ 
    slice(start? : number, end? : number) {
        if (start === undefined) start = 0;
        if (end === undefined) end = this._bits;
        if (end > this.bits) end = this.bits;
        if (start > end) end = start;
        if (bitnum(start) == 0) {
            const avec = this._avec.slice(start >>> 5, (end + 31) >>> 5);
            const bvec = this._bvec.slice(start >>> 5, (end + 31) >>> 5);
            return new Vector3vl(end - start, avec, bvec);
        } else {
            const words = (end - start + 31) >>> 5;
            const avec = new Uint32Array(words), bvec = new Uint32Array(words);
            let k = 0;
            avec[k] = this._avec[start >> 5] >>> start;
            bvec[k] = this._bvec[start >> 5] >>> start;
            for (let idx = (start >> 5) + 1; idx <= (end >>> 5); idx++) {
                avec[k] |= this._avec[idx] << -start;
                bvec[k] |= this._bvec[idx] << -start;
                k++;
                if (k == words) break;
                avec[k] = this._avec[idx] >>> start;
                bvec[k] = this._bvec[idx] >>> start;
            }
            return new Vector3vl(end - start, avec, bvec);
        }
    }

    /**
     * Returns an iterator describing the vector.
     * 
     * In each returned value, first _skip_ bits come from the vector B,
     * the next _skip_ bits come from the vector A.
     *
     * This function calls [[toIteratorAnySkip]] or [[toIteratorPow2]].
     *
     * @param skip Number of bits in a single iterator step. 1 to 16.
     */
    toIterator(skip : number) {
        if ((skip & (skip - 1)) == 0) return this.toIteratorPow2(skip);
        else return this.toIteratorAnySkip(skip);
    }

    /**
     * Returns an iterator describing the vector.
     *
     * In each returned value, first _skip_ bits come from the vector B,
     * the next _skip_ bits come from the vector A.
     *
     * @param skip Number of bits in a single iterator step. 1 to 16.
     */ 
    *toIteratorAnySkip(skip : number) {
        this.normalize();
        const sm = (1 << skip) - 1;
        let bit = 0, k = 0, m = sm, out = [];
        while (bit < this._bits) {
            let a = (this._avec[k] & m) >>> bit;
            let b = (this._bvec[k] & m) >>> bit;
            if ((m >>> bit) != sm && k + 1 != this._avec.length) {
                const m1 = sm >> -bit;
                a |= (this._avec[k + 1] & m1) << -bit;
                b |= (this._bvec[k + 1] & m1) << -bit;
            }
            yield (a << skip) | b;
            m <<= skip;
            bit += skip;
            if (m == 0) {
                k++;
                m = (sm << bit);
            }
        }
    }

    /**
     * Returns an iterator describing the vector.
     *
     * In each returned value, first _skip_ bits come from the vector B,
     * the next _skip_ bits come from the vector A.
     *
     * @param skip Number of bits in a single iterator step. 1, 2, 4, 8 or 16.
     */ 
    *toIteratorPow2(skip : number) {
        this.normalize();
        const sm = (1 << skip) - 1;
        let bit = 0, k = 0, m = sm, out = [];
        while (bit < this._bits) {
            const a = (this._avec[k] & m) >>> bit;
            const b = (this._bvec[k] & m) >>> bit;
            yield (a << skip) | b;
            m <<= skip;
            bit += skip;
            if (m == 0) {
                k++;
                m = sm;
            }
        }
    }

    /** Returns an array representation of the vector.
     *
     * The resulting array contains values -1, 0, 1.
     */
    toArray() {
        // copy-paste'y code for performance
        this.normalize();
        const skip = 1;
        const sm = (1 << skip) - 1;
        let bit = 0, k = 0, m = sm, out = [];
        while (bit < this._bits) {
            const a = (this._avec[k] & m) >>> bit;
            const b = (this._bvec[k] & m) >>> bit;
            const v = (a << skip) | b;
            out.push(v - 1 - Number(v > 1));
            m <<= skip;
            bit += skip;
            if (m == 0) {
                k++;
                m = sm;
            }
        }
        return out;
    }

    /** Returns a binary representation of the vector.
     *
     * Three characters are used:
     * * '0' for logical 0,
     * * 'x' for undefined value,
     * * '1' for logical 1.
     */
    toBin() {
        return toBinInternal(0, this._bits, this._avec, this._bvec);
    }

    /** Returns an octal representation of the vector.
     *
     * Returned characters can be '0' to '7' and 'x'. An 'x' value is returned
     * if any of the three bits is undefined.
     */
    toOct() {
        // copy-paste'y code for performance
        this.normalize();
        const skip = 3;
        const sm = (1 << skip) - 1;
        let bit = 0, k = 0, m = sm, out = [];
        while (bit < this._bits) {
            let a = (this._avec[k] & m) >>> bit;
            let b = (this._bvec[k] & m) >>> bit;
            if ((m >>> bit) != sm && k + 1 != this._avec.length) {
                const m1 = sm >> -bit;
                a |= (this._avec[k + 1] & m1) << -bit;
                b |= (this._bvec[k + 1] & m1) << -bit;
            }
            const v = (a << skip) | b;
            if (0x7 & v & ~(v >> 3)) out.push('x');
            else out.push((v >> 3).toString());
            m <<= skip;
            bit += skip;
            if (m == 0) {
                k++;
                m = (sm << bit);
            }
        }
        return out.reverse().join('');
    }
    
    /** Returns an hexadecimal representation of the vector.
     *
     * Returned characters can be '0' to '9', 'a' to 'f' and 'x'. An 'x' value
     * is returned if any of the four bits is undefined.
     */
    toHex() {
        return toHexInternal(0, this._bits, this._avec, this._bvec);
    }

    /** Returns a string describing the vector. */
    toString() {
        return "Vector3vl " + this.toBin();
    }

    /** Compares two vectors for equality. */
    eq(v : Vector3vl) {
        if (v._bits != this._bits) return false;
        this.normalize();
        v.normalize();
        for (const i in this._avec) {
            if (this._avec[i] != v._avec[i]) return false;
            if (this._bvec[i] != v._bvec[i]) return false;
        }
        return true;
    }

    /** Normalize the vector.
     * 
     * Because of the representation used, if _bits_ is not a multiple
     * of 32, some internal bits do not contribute to the vector value,
     * and for performance reasons can get arbitrary values in the course
     * of computations. This procedure clears these bits.
     * For internal use.
     */
    normalize() {
        const lastmask = this._lastmask;
        this._avec[this._avec.length - 1] &= lastmask;
        this._bvec[this._bvec.length - 1] &= lastmask;
    }

    /** Mask for unused bits.
     *
     * For internal use.
     */
    private get _lastmask() {
        return (~0) >>> -this.bits;
    }
};

export class Mem3vl {
    private _bits : number;
    private _size : number;
    private _wpc : number;
    private _avec : Uint32Array;
    private _bvec : Uint32Array;
    constructor(bits : number, size : number, val? : number) {
        if (val === undefined) val = 0;
        this._bits = bits | 0;
        this._size = size | 0;
        this._wpc = (bits+31)/32 | 0;
        this._avec = new Uint32Array(size * this._wpc).fill(val > 0 ? ~0 : 0);
        this._bvec = new Uint32Array(size * this._wpc).fill(val >= 0 ? ~0 : 0);
        if (this._size) this.set(this._size - 1, this.get(this._size - 1)); // TODO faster
    }
    static fromData(data : Vector3vl[]) {
        if (data.length == 0) return new Mem3vl(0, 0);
        const ret = new Mem3vl(data[0].bits, data.length);
        for (const i in data) {
            data[i].normalize();
            console.assert(data[i].bits == ret._bits);
            for (let j = 0; j < ret._wpc; j++) {
                const idx = Number(i)*ret._wpc + j;
                ret._avec[idx] = (data[i] as any)._avec[j];
                ret._bvec[idx] = (data[i] as any)._bvec[j];
            }
        }
        return ret;
    }
    get bits() {
        return this._bits;
    }
    get words() {
        return this._size;
    }
    get(i : number) : Vector3vl {
        const idx = this._wpc * i;
        return new (Vector3vl as any)(this._bits,
            this._avec.slice(idx, idx+this._wpc),
            this._bvec.slice(idx, idx+this._wpc));
    }
    set(i : number, v : Vector3vl) {
        console.assert(v.bits == this._bits);
        v.normalize();
        for (let j = 0; j < this._wpc; j++) {
            this._avec[i*this._wpc+j] = (v as any)._avec[j];
            this._bvec[i*this._wpc+j] = (v as any)._bvec[j];
        }
    }
    toJSON() {
        const rep : (number | string)[] = [];
        let hexbuf : string[] = [];
        let rleval : string, rlecnt : number = 0;
        const hexflush = () => {
            if (hexbuf.length == 0) return;
            if (hexbuf.reduce((a, b) => a + b.length, 0) == this._bits) { // to avoid confusion
                const last = hexbuf.pop();
                if (hexbuf.length > 0)
                    rep.push(hexbuf.join(''));
                rep.push(last);
            } else {
                rep.push(hexbuf.join(''));
            }
            hexbuf = [];
        };
        const rleflush = () => {
            if (rlecnt == 0) return;
            else if (rlecnt == 1) {
                if (rleval.length == this._bits) {
                    hexflush();
                    rep.push(rleval);
                } else hexbuf.push(rleval);
            } else {
                hexflush();
                rep.push(rlecnt);
                rep.push(rleval);
            }
            rleval = undefined;
            rlecnt = 0;
        };
        const rlepush = (v) => {
            if (rleval == v) rlecnt++;
            else {
                rleflush();
                rleval = v;
                rlecnt = 1;
            }
        };
        for (let i = 0; i < this._size; i++) {
            const check = () => {
                for (let j = 0; j < this._wpc; j++) {
                    const xx = this._avec[i*this._wpc + j] ^ this._bvec[i*this._wpc + j];
                    for (let k = 0; k < 4; k++) {
                        const m = 0xff << (k*16);
                        const xm = xx & m;
                        if (xm != m || xm != 0) return false;
                    }
                }
                return true;
            }
            if (this._bits > 0 && check()) {
                rlepush(toHexInternal(i*this._wpc, this._bits, this._avec, this._bvec));
            } else {
                rlepush(toBinInternal(i*this._wpc, this._bits, this._avec, this._bvec));
            }
        }
        rleflush();
        hexflush();
        return rep;
    }
    static fromJSON(bits, rep) {
        const hexlen = Math.ceil(bits/4);
        let size = 0;
        const xsize = (x : string) => {
            if (x.length == bits || x.length == hexlen) return 1;
            else return x.length/hexlen;
        }
        for (let i = 0; i < rep.length; i++) {
            if (typeof rep[i] === "string") {
                size += xsize(rep[i]);
            } else if (typeof rep[i] === "number") {
                size += rep[i] * xsize(rep[i+1]);
                i++;
            }
        }
        const ret = new Mem3vl(bits, size, -1);
        let w = 0;
        const decode = (x : string) => {
            if (x.length == bits) {
                fromBinInternal(x, w, bits, ret._avec, ret._bvec);
                w += ret._wpc;
            } else if (x.length == hexlen) {
                fromHexInternal(x, w, bits, ret._avec, ret._bvec);
                w += ret._wpc;
            } else {
                for (let i = 0; i < x.length / hexlen; i++) {
                    fromHexInternal(x.slice(i*hexlen, (i+1)*hexlen), w, bits, ret._avec, ret._bvec);
                    w += ret._wpc;
                }
            }
        };
        for (let i = 0; i < rep.length; i++) {
            if (typeof rep[i] === "string") decode(rep[i]);
            else if (typeof rep[i] === "number") {
                for (const j of Array(rep[i]).keys())
                    decode(rep[i+1]);
                i++;
            }
        }
        return ret;
    }
    toArray() {
        return Array(this._size).fill(0).map((a,i) => this.get(i));
    }
    toHex() {
        // TODO faster
        return this.toArray().map(x => x.toHex());
    }
    eq(m : Mem3vl) {
        if (m._bits != this._bits || m._size != this._size)
            return false;
        // TODO faster
        for (let i = 0; i < this._size; i++)
            if (!m.get(i).eq(this.get(i))) return false;
        return true;
    }
};


