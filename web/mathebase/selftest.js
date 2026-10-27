// node selftest.js — tests engine extracted from index.html (no browser needed)
const fs=require('fs'),assert=require('assert');
const html=fs.readFileSync(__dirname+'/index.html','utf8');
const src=html.slice(html.indexOf('/*ENGINE-START*/'),html.indexOf('/*ENGINE-END*/'));
const m={exports:{}};new Function('module',src+';module.exports=ENGINE;')(m);const E=m.exports;
// 1) K2 lock: 5000 rounds, only +/−, ≤20, integer answers
for(let i=0;i<1000;i++){const p={klasse:2,weakTopics:{}};for(const e of E.makeRound(p,{prozent:true})){assert(E.validK2(e),'K2 violation: '+e.prompt+' = '+e.answer);assert(Number.isInteger(e.answer));assert(e.topic&&e.prompt&&e.difficulty);}}
// 2) K5: no % unless unlocked, integer non-negative answers
let pct=0;for(let i=0;i<1000;i++){for(const e of E.makeRound({klasse:4,weakTopics:{}},{prozent:false})){assert(!/%/.test(e.prompt));assert(Number.isInteger(e.answer)&&e.answer>=0,e.prompt);}
 for(const e of E.makeRound({klasse:4,weakTopics:{}},{prozent:true}))if(e.topic==='prozent'){pct++;assert(Number.isInteger(e.answer));}}
assert(pct>0,'prozent never appears when unlocked');
// 3) Adaptive bias: inject wrongs on 'halbieren' (K2) and 'division' (K5)
function share(klasse,topic){const p={klasse,weakTopics:{},topicStats:{},mistakes:[]};const it={topic,prompt:'x',answer:1};
 const base=n=>{let c=0,t=0;for(let i=0;i<n;i++)for(const e of E.makeRound(p,{}))(t++,e.topic===topic&&c++);return c/t;};
 const before=base(400);for(let i=0;i<3;i++)E.record(p,it,0,false,'2026-10-25');const after=base(400);
 for(let i=0;i<15;i++)E.record(p,it,1,true);const decayed=base(400);return {before,after,decayed,w:p.weakTopics[topic]};}
for(const [k,t] of [[2,'ergaenzen'],[4,'division']]){const r=share(k,t);console.log('K'+k,t,JSON.stringify(r));assert(r.after>0.5&&r.after>2.5*r.before,'no bias');assert(r.decayed<r.after*0.5&&r.w===undefined,'no decay');}
// 4) v4 difficulty: K2 often >20 / ZR100, several topics; K5 mult/div/large add; weak topics not baby-easy
let big=0,tot=0;const k2t=new Set(),k5t=new Set();let k5big=0,k5hard=0,k5n=0,minD=9;
for(let i=0;i<2000;i++){for(const e of E.makeRound({klasse:2,weakTopics:{}},{})){tot++;k2t.add(e.topic);if(e.answer>20||(e.prompt.match(/\d+/g)||[]).some(x=>+x>20))big++;}
 for(const e of E.makeRound({klasse:4,weakTopics:{}},{})){k5n++;k5t.add(e.topic);if(e.answer>=300)k5big++;if(/^[6-9] · [6-9] = \?$/.test(e.prompt)||/__/.test(e.prompt))k5hard++;}
 for(const e of E.makeRound({klasse:2,weakTopics:{plus:5}},{}))if(e.fromWeak)minD=Math.min(minD,e.difficulty);}
console.log('K2 >20 share',(big/tot).toFixed(2),'topics',[...k2t].join(','));console.log('K5 >=300 share',(k5big/k5n).toFixed(2),'hard',(k5hard/k5n).toFixed(2),'topics',[...k5t].join(','));
assert(big/tot>0.6,'K2 too easy');assert(k2t.size>=8,'K2 variety');assert(k2t.has('einmaleins2')&&k2t.has('sachaufgabe2'));
for(const t of ['einmaleins','division','zr1000plus','halbschriftlich','sachaufgabe'])assert(k5t.has(t),t);assert(!k5t.has('prozent'));
assert(k5big/k5n>0.15&&k5hard/k5n>0.05);assert(minD>=2,'weak topic baby-easy');
// prompt shape variety K2
const shapes=new Set();for(let i=0;i<500;i++)for(const e of E.makeRound({klasse:2,weakTopics:{}},{}))shapes.add(e.prompt.replace(/\d+/g,'N').replace(/(Lena|Ben|Mia|Tom|Emil|Noah|Ida|Paul)/,'X'));
console.log('K2 prompt shapes',shapes.size);assert(shapes.size>=15);
console.log('SELFTEST OK');
