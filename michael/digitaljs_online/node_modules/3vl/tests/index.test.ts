
import { Vector3vl, Mem3vl } from '../src/index';
import * as _ from 'lodash';
import * as jsc from 'jsverify';

const replicate = (n, g) => jsc.tuple(Array(n).fill(g))

const myarray = <A>(arb : jsc.ArbitraryLike<A>) => jsc.bless({
    generator: jsc.generator.bless((size : number) =>
        jsc.generator.tuple(Array(jsc.random(0, size)).fill(arb.generator))(size)),
    shrink: jsc.shrink.array(arb.shrink),
    show: a => jsc.show.array(arb.show, a)
});

const myarrays = <A>(n : number, arb : jsc.ArbitraryLike<A>) => jsc.bless({
    generator: jsc.generator.bless((size : number) =>
        jsc.generator.tuple(Array(n).fill(jsc.generator.tuple(Array(jsc.random(0, size)).fill(arb.generator))))(size)),
    shrink: jsc.shrink.tuple(Array(n).fill(jsc.shrink.array(arb.shrink))), // TODO breaks same size invariant
    show: a => jsc.show.tuple(Array(n).fill(b => jsc.show.array(arb.show, b)), a)
});

const myrandarrays = <A>(arb : jsc.ArbitraryLike<A>) => jsc.bless({
    generator: jsc.generator.bless((size : number) =>
        jsc.generator.array(jsc.generator.tuple(Array(jsc.random(0, size)).fill(arb.generator)))(size)),
    shrink: jsc.shrink.array(jsc.shrink.array(arb.shrink)), // TODO breaks same size invariant
    show: a => jsc.show.array(b => jsc.show.array(arb.show, b), a)
});

const trit = jsc.elements([-1, 0, 1]);
const array3vl = myarray(trit);
const arrays3vl = n => myarrays(n, trit);
const vector3vl = array3vl.smap(a => Vector3vl.fromArray(a), v => v.toArray());
const vectors3vl = n => arrays3vl(n).smap(x => x.map(a => Vector3vl.fromArray(a)), x => x.map(v => v.toArray()));
const binarytxt = jsc.array(jsc.elements(['0', '1', 'x'])).smap(a => a.join(''), s => s.split(''))
const octaltxt = myarray(jsc.elements(['x'].concat(Array.from(Array(8), (a, i) => i.toString()))))
    .smap(a => a.join(''), s => s.split(''))
const hextxt = myarray(jsc.elements(['x'].concat(Array.from(Array(16), (a, i) => i.toString(16)))))
    .smap(a => a.join(''), s => s.split(''))
const randarrays3vl = myrandarrays(trit);
const randvectors3vl = randarrays3vl.smap(x => x.map(a => Vector3vl.fromArray(a)), x => x.map(v => v.toArray()));
const mem3vl = randvectors3vl.smap(a => Mem3vl.fromData(a), m => m.toArray());

describe('relation to arrays', () => {
    jsc.property('fromArray.toArray', array3vl, a =>
        _.isEqual(a, Vector3vl.fromArray(a).toArray()));

    jsc.property('toArray.fromArray', vector3vl, v => 
        v.eq(Vector3vl.fromArray(v.toArray())));

    jsc.property('get', vector3vl, v => 
        _.isEqual(v.toArray(), Array.from(Array(v.bits), (x, k) => v.get(k))));
});

describe('parsing and printing', () => {
    jsc.property('rev binary', vector3vl, v =>
        v.eq(Vector3vl.fromBin(v.toBin())));

    jsc.property('binary', binarytxt, s =>
        s === Vector3vl.fromBin(s).toBin());

    jsc.property('octal', octaltxt, s =>
        s === Vector3vl.fromOct(s).toOct());

    jsc.property('hexadecimal', hextxt, s =>
        s === Vector3vl.fromHex(s).toHex());
    
    jsc.property('binary bits', binarytxt, s =>
        s.length === Vector3vl.fromBin(s).bits);

    jsc.property('octal bits', octaltxt, s =>
        3 * s.length === Vector3vl.fromOct(s).bits);

    jsc.property('hexadecimal bits', hextxt, s =>
        4 * s.length === Vector3vl.fromHex(s).bits);
    
    const ex = s => s == '' ? '0' : s[0] == 'x' ? 'x' : '0';

    jsc.property('binary sized', binarytxt, jsc.nat(100), (s, n) =>
        ex(s).repeat(n).concat(s).slice(-n).slice(0, n) === Vector3vl.fromBin(s, n).toBin());
    
    jsc.property('octal sized', octaltxt, jsc.nat(100), (s, n) =>
        ex(s).repeat(n).concat(s).slice(-n).slice(0, n) === Vector3vl.fromOct(s, 3*n).toOct());
    
    jsc.property('hexadecimal sized', hextxt, jsc.nat(100), (s, n) =>
        ex(s).repeat(n).concat(s).slice(-n).slice(0, n) === Vector3vl.fromHex(s, 4*n).toHex());
    
    jsc.property('binary sized bits', binarytxt, jsc.nat(100), (s, n) =>
        n === Vector3vl.fromBin(s, n).bits);

    jsc.property('octal sized bits', octaltxt, jsc.nat(100), (s, n) =>
        n === Vector3vl.fromOct(s, n).bits);

    jsc.property('hexadecimal sized bits', hextxt, jsc.nat(100), (s, n) =>
        n === Vector3vl.fromHex(s, n).bits);
    
});

describe('constant vectors', () => {
    jsc.property('0', jsc.nat(1000), n =>
        _.isEqual(Array(n).fill(-1), Vector3vl.zeros(n).toArray()));
    jsc.property('x', jsc.nat(1000), n =>
        _.isEqual(Array(n).fill(0), Vector3vl.xes(n).toArray()));
    jsc.property('1', jsc.nat(1000), n =>
        _.isEqual(Array(n).fill(1), Vector3vl.ones(n).toArray()));
});

describe('predicates', () => {
    jsc.property('isLow', vector3vl, v =>
        v.isLow == v.toArray().every(x => x == -1));
    
    jsc.property('isHigh', vector3vl, v =>
        v.isHigh == v.toArray().every(x => x == 1));
    
    jsc.property('isDefined', vector3vl, v =>
        v.isDefined == v.toArray().some(x => x != 0));
    
    jsc.property('isFullyDefined', vector3vl, v =>
        v.isFullyDefined == v.toArray().every(x => x != 0));
});

describe('not properties', () => {
    jsc.property('~~a == a', vector3vl, v =>
        v.eq(v.not().not()));
    
    jsc.property('~(a | b) == ~a & ~b', vectors3vl(2), ([v, w]) =>
        v.or(w).not().eq(v.not().and(w.not())));
    
    jsc.property('~(a & b) == ~a | ~b', vectors3vl(2), ([v, w]) =>
        v.and(w).not().eq(v.not().or(w.not())));
    
    jsc.property('~(a ^ b) == ~a ^ b', vectors3vl(2), ([v, w]) =>
        v.xor(w).not().eq(v.not().xor(w)));
});

describe('or properties', () => {
    jsc.property('a | a == a', vector3vl, v =>
        v.eq(v.or(v)));

    jsc.property('a | 0 == a', vector3vl, v =>
        v.eq(v.or(Vector3vl.zeros(v.bits))));

    jsc.property('0 | a == a', vector3vl, v =>
        v.eq(Vector3vl.zeros(v.bits).or(v)));

    jsc.property('a | 1 == 1', vector3vl, v =>
        Vector3vl.ones(v.bits).eq(v.or(Vector3vl.ones(v.bits))));

    jsc.property('1 | a == 1', vector3vl, v =>
        Vector3vl.ones(v.bits).eq(Vector3vl.ones(v.bits).or(v)));

    jsc.property('a | b == b | a', vectors3vl(2), ([v, w]) =>
        v.or(w).eq(w.or(v)));

    jsc.property('(a | b) | c == a | (b | c)', vectors3vl(3), ([v, w, x]) =>
        v.or(w).or(x).eq(v.or(w.or(x))));
});

describe('and properties', () => {
    jsc.property('a & a == a', vector3vl, v =>
        v.eq(v.and(v)));

    jsc.property('a & 0 == 0', vector3vl, v =>
        Vector3vl.zeros(v.bits).eq(v.and(Vector3vl.zeros(v.bits))));

    jsc.property('0 & a == 0', vector3vl, v =>
        Vector3vl.zeros(v.bits).eq(Vector3vl.zeros(v.bits).and(v)));

    jsc.property('x & 1 == a', vector3vl, v =>
        v.eq(v.and(Vector3vl.ones(v.bits))));

    jsc.property('1 & a == a', vector3vl, v =>
        v.eq(Vector3vl.ones(v.bits).and(v)));

    jsc.property('a & b == b & a', vectors3vl(2), ([v, w]) =>
        v.and(w).eq(w.and(v)));

    jsc.property('(a & b) & c == a & (b & c)', vectors3vl(3), ([v, w, x]) =>
        v.and(w).and(x).eq(v.and(w.and(x))));
});

describe('xor properties', () => {
    jsc.property('a ^ 0 == a', vector3vl, v =>
        v.xor(Vector3vl.zeros(v.bits)).eq(v));

    jsc.property('0 ^ a == a', vector3vl, v =>
        Vector3vl.zeros(v.bits).xor(v).eq(v));

    jsc.property('a ^ 1 == ~a', vector3vl, v =>
        v.xor(Vector3vl.ones(v.bits)).eq(v.not()));

    jsc.property('1 ^ a == ~a', vector3vl, v =>
        Vector3vl.ones(v.bits).xor(v).eq(v.not()));

    jsc.property('a ^ b == b ^ a', vectors3vl(2), ([v, w]) =>
        v.xor(w).eq(w.xor(v)));

    jsc.property('(a ^ b) ^ c == a ^ (b ^ c)', vectors3vl(3), ([v, w, x]) =>
        v.xor(w).xor(x).eq(v.xor(w.xor(x))));
});

describe('negated ops', () => {
    jsc.property('a ~| b == ~(a | b)', vectors3vl(2), ([v, w]) =>
        v.nor(w).eq(v.or(w).not()));
    
    jsc.property('a ~& b == ~(a & b)', vectors3vl(2), ([v, w]) =>
        v.nand(w).eq(v.and(w).not()));
    
    jsc.property('a ~^ b == ~(a ^ b)', vectors3vl(2), ([v, w]) =>
        v.xnor(w).eq(v.xor(w).not()));
});

describe('reducing ops', () => {
    jsc.property('&a', vector3vl, v =>
        v.reduceAnd().eq(v.toArray().map(x => Vector3vl.make(1, x)).reduce((a, b) => a.and(b), Vector3vl.one)));
    
    jsc.property('|a', vector3vl, v =>
        v.reduceOr().eq(v.toArray().map(x => Vector3vl.make(1, x)).reduce((a, b) => a.or(b), Vector3vl.zero)));
    
    jsc.property('^a', vector3vl, v =>
        v.reduceXor().eq(v.toArray().map(x => Vector3vl.make(1, x)).reduce((a, b) => a.xor(b), Vector3vl.zero)));
    
    jsc.property('~&a', vector3vl, v =>
        v.reduceNand().eq(v.toArray().map(x => Vector3vl.make(1, x)).reduce((a, b) => a.and(b), Vector3vl.one).not()));
    
    jsc.property('~|a', vector3vl, v =>
        v.reduceNor().eq(v.toArray().map(x => Vector3vl.make(1, x)).reduce((a, b) => a.or(b), Vector3vl.zero).not()));
    
    jsc.property('~^a', vector3vl, v =>
        v.reduceXnor().eq(v.toArray().map(x => Vector3vl.make(1, x)).reduce((a, b) => a.xor(b), Vector3vl.zero).not()));
});

describe('concat', () => {
    jsc.property('(a ++ b) ++ c == a ++ (b ++ c)', replicate(3, vector3vl), ([v, w, x]) =>
        v.concat(w).concat(x).eq(v.concat(w.concat(x))));

    jsc.property('(a ++ b) ++ c == a ++ b ++ c', replicate(3, vector3vl), ([v, w, x]) =>
        v.concat(w).concat(x).eq(Vector3vl.concat(v, w, x)));

    jsc.property('a ++ null == a', vector3vl, v =>
        v.concat(Vector3vl.zeros(0)).eq(v));

    jsc.property('null ++ a == a', vector3vl, v =>
        Vector3vl.zeros(0).concat(v).eq(v));
});

describe('slice', () => {
    jsc.property('a.slice() == a', vector3vl, v =>
        v.slice().eq(v));

    jsc.property('a.slice(a.bits) == null', vector3vl, v =>
        v.slice(v.bits).eq(Vector3vl.zeros(0)));

    jsc.property('a.slice(0, 0) == null', vector3vl, v =>
        v.slice(0, 0).eq(Vector3vl.zeros(0)));

    jsc.property('a.slice(0, n) ++ a.slice(n) == a', vector3vl, jsc.nat(10), (v, n) =>
        v.slice(0, n).concat(v.slice(n)).eq(v));
});

describe('xmask', () => {
    jsc.property('a | a.xmask() fully defined', vector3vl, v =>
        v.xmask().or(v).isFullyDefined);
    jsc.property('a & ~a.xmask() fully defined', vector3vl, v =>
        v.xmask().not().and(v).isFullyDefined);
    jsc.property('a ^ a.xmask() == a', vector3vl, v =>
        v.xmask().xor(v).eq(v));
});

describe('memory json', () => {
    jsc.property('m.toJSON().fromJSON() == m', mem3vl, (m) => m.eq(Mem3vl.fromJSON(m.bits, m.toJSON())));
    jsc.property('m.toArray().fromData() == m', mem3vl, (m) => m.eq(Mem3vl.fromData(m.toArray())));
});

