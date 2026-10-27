// Optional UI smoke test: (cd /tmp/jd && npm i jsdom@24) then NODE_PATH=/tmp/jd/node_modules node selftest-dom.js
const {JSDOM}=require('jsdom');const fs=require('fs');
const html=fs.readFileSync('/workspace/mathebase-mvp/index.html','utf8');
const dom=new JSDOM(html,{runScripts:'outside-only',url:'http://127.0.0.1:8765/'});const w=dom.window;
let posts=[];w.fetch=(u,o)=>{posts.push([u,o.body]);return Promise.resolve({ok:true,json:()=>Promise.resolve({ok:true})});};w.scrollTo=()=>{};w.alert=()=>{};w.confirm=()=>true;
w.eval(html.slice(html.indexOf('<script>')+8,html.lastIndexOf('</script>')));
const d=w.document,$=id=>d.getElementById(id);
// link via Papa
$('btnPapaFromStart').click();for(const k of [2,4,6,8])[...$('pinPad').children].find(b=>b.textContent==String(k)).click();
const cards=d.querySelectorAll('#papaProfiles .card');cards[1].querySelector('.pkit').value='matthias';cards[1].querySelector('.psave').click();$('btnPapaDone').click();
d.querySelectorAll('.profile-btn')[1].click();
async function play(nWrong){$('btnStartRound').click();for(let i=0;i<5;i++){const it=w.MB_TEST.round().items[i];$('exAnswer').value=String(i<nWrong?it.answer+1:it.answer);$('btnCheck').click();$('btnNext').click();}await new Promise(r=>setTimeout(r,50));console.log('end:',$('endKueche').textContent);$('btnToHub').click();}
(async()=>{await play(1);await play(0);console.log('posts',posts.length,posts[0]);console.log($('hubWeek').textContent);
 $('btnPapaFromHub').click();for(const k of [2,4,6,8])[...$('pinPad').children].find(b=>b.textContent==String(k)).click();$('btnExport').click();console.log($('exportBox').textContent.slice(0,600));})();
