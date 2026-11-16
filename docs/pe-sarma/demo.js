(function(){
'use strict';
var $=function(i){return document.getElementById(i)};
var T=function(k){return window.I18N.t(k)};
var line=$('line'),cards=$('cards'),toast=$('toast'),q=$('q'),search=$('search'),pv=$('preview');
var nextShot=1,items=[],undo=[],uid=0,selected={},toastT=0,reduce=window.matchMedia&&matchMedia('(prefers-reduced-motion: reduce)').matches;
function fold(s){return String(s).normalize('NFD').replace(/[̀-ͯ]/g,'').replace(/[șş]/gi,'s').replace(/[țţ]/gi,'t').toLowerCase()}
function say(m){toast.textContent=m;toast.classList.add('show');clearTimeout(toastT);toastT=setTimeout(function(){toast.classList.remove('show')},2200)}
function esc(s){return String(s).replace(/[&<>"]/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]})}
function lineBtn(){var on=line.classList.contains('open');$('b-line').setAttribute('aria-pressed',on);$('b-line').textContent=T(on?'demo.hideLine':'demo.showLine')}
function setLine(on){line.classList.toggle('open',on);lineBtn();$('hint').style.opacity=on?0:1;if(!on)closeSearch()}
/* Synthetic windows drawn in HTML at 300 x 256 and scaled down to the card. Each one is a believable screenshot:
   the words are real, so the search finds them, and the preview shows the same window larger. */
function bars(){var h=[40,62,48,80,70,96,84],o='';h.forEach(function(v,i){o+='<i style="height:'+v+'%;opacity:'+(.45+i*.08)+'"></i>'});return o}
function sw(n){var L=T('swl')[n%6],m=n%6;
  var top='<div class="tb"><s></s><s></s><s></s><b>'+esc(L[0])+'</b></div>';
  if(m===0)return top+'<div class="bd d0"><div class="kp"><span><em>'+esc(L[1])+'</em><b>128k €</b></span><span><em>'+esc(L[2])+'</em><b>1 942</b></span><span><em>'+esc(L[3])+'</em><b>+12%</b></span></div><div class="ch">'+bars()+'</div></div>';
  if(m===1)return top+'<div class="bd d1"><pre><span class="k">struct</span> Line {\n  <span class="k">var</span> items: [Item]\n  <span class="k">var</span> sarma = <span class="s">"Pe sârmă"</span>\n  <span class="k">func</span> <span class="f">swing</span>() {\n    <span class="c">// clip + wire</span>\n    angle = <span class="n">1.6</span>\n  }\n}</pre></div>';
  if(m===2){var rows='';[[L[4],'12 000','11 480'],[L[5],'12 500','12 910'],[L[6],'13 200','13 050'],[L[7],'13 800','—']].forEach(function(r){rows+='<tr><td>'+esc(r[0])+'</td><td>'+r[1]+'</td><td>'+r[2]+'</td></tr>'});return top+'<div class="bd d2"><table><tr><th>'+esc(L[1])+'</th><th>'+esc(L[2])+'</th><th>'+esc(L[3])+'</th></tr>'+rows+'</table></div>'}
  if(m===3)return top+'<div class="bd d3"><p class="in">'+esc(L[1])+'</p><p class="out">'+esc(L[2])+'</p><p class="in">'+esc(L[3])+'</p></div>';
  if(m===4)return top+'<div class="bd d4"><div class="hr"></div><h4>'+esc(L[0])+'</h4><div class="ln"></div><div class="ln s"></div><span class="bt">'+esc(L[1])+'</span></div>';
  return top+'<div class="bd d5"><pre>$ swift build\nCompiling PeSarma…\n<span class="g">Build complete!</span> (4.3s)\n$ scripts/test-selection.sh\n<span class="g">80 checks passed</span>\n$ _</pre></div>'}
function shotFace(n){return '<span class="face shot"><span class="swin">'+sw(n)+'</span></span>'}
/* an item stores indexes, not words, so the language can change under it */
function content(it){
  if(it.kind==='shot')return {title:T('shots')[it.n],body:'',ocr:T('ocr')[it.n]};
  var n=it.welcome?T('welcome'):T('notes')[it.ni];return {title:n[0],body:n[1],ocr:''};
}
function render(){
  cards.innerHTML='';
  items.forEach(function(it,i){
    var c=content(it);
    var el=document.createElement('div');el.className='card'+(selected[it.id]?' sel':'');el.setAttribute('role','listitem');el.tabIndex=0;el.dataset.id=it.id;
    el.style.setProperty('--d',(-i*0.7)+'s');
    el.setAttribute('aria-label',T(it.kind==='shot'?'a.shot':'a.note')+c.title+(it.pinned?T('a.pinned'):'')+T('a.keys'));
    el.innerHTML='<span class="clip"></span>'+(it.pinned?'<span class="pin">'+esc(T('a.pin'))+'</span>':'')+
      (it.kind==='shot'?shotFace(it.n):'<span class="face nt"><b>'+esc(c.title)+'</b>'+esc(c.body)+'</span>')+
      '<span class="cap">'+esc(c.title)+'</span><button class="x" aria-label="'+esc(T('a.discard')+c.title)+'" tabindex="-1">×</button>';
    cards.appendChild(el);
  });
  applyFilter();
}
function applyFilter(){
  var words=fold(q.value).split(/\s+/).filter(Boolean);
  Array.prototype.forEach.call(cards.children,function(el){
    var c=content(find(el.dataset.id));var hay=fold(c.title+' '+c.body+' '+c.ocr);
    el.classList.toggle('hide',!words.every(function(w){return hay.indexOf(w)>-1}));
  });
}
function find(id){for(var i=0;i<items.length;i++)if(String(items[i].id)===String(id))return items[i]}
function add(it,silent){it.id=++uid;items.unshift(it);undo.push({type:'add',id:it.id});render();if(!silent){setLine(true);say(T(it.kind==='shot'?'t.shot':'t.note'))}}
function shot(){
  var f=$('flash');f.classList.remove('go');void f.offsetWidth;f.classList.add('go');
  add({kind:'shot',n:nextShot++});
}
function copyText(){add({kind:'note',ni:Math.floor(Math.random()*T('notes').length)})}
function remove(id,msg){var i=items.findIndex(function(x){return String(x.id)===String(id)});if(i<0)return;var it=items.splice(i,1)[0];undo.push({type:'del',it:it,i:i});delete selected[id];render();say(msg||T('t.discarded'))}
function undoLast(){var u=undo.pop();if(!u){say(T('t.nothing'));return}
  if(u.type==='add'){var i=items.findIndex(function(x){return x.id===u.id});if(i>-1)items.splice(i,1)}
  else if(u.type==='del'){items.splice(u.i,0,u.it)}
  else if(u.type==='pin'){var p=find(u.id);if(p)p.pinned=u.was}
  render();say(T('t.undone'))}
function copyItem(it){say(T('t.copied')+content(it).title)}
function openPreview(it){var c=content(it);$('pv-t').textContent=c.title;$('pv-b').innerHTML=(it.kind==='shot'?'<div class="pvwin"><span class="swin">'+sw(it.n)+'</span></div>':'')+'<p>'+esc(it.kind==='shot'?T('p.shot'):c.body)+'</p>';pv.classList.add('open');$('pv-x').focus()}
function closePreview(){pv.classList.remove('open')}
function openSearch(){setLine(true);search.classList.add('open');q.focus()}
function closeSearch(){search.classList.remove('open');q.value='';applyFilter()}
function togglePin(it){undo.push({type:'pin',id:it.id,was:!!it.pinned});it.pinned=!it.pinned;render();say(T(it.pinned?'t.pinned':'t.unpinned'))}

cards.addEventListener('click',function(e){
  var card=e.target.closest('.card');if(!card)return;var it=find(card.dataset.id);
  if(e.target.closest('.x')){remove(it.id);return}
  if(e.shiftKey){selected[it.id]=!selected[it.id];card.classList.toggle('sel');var n=Object.keys(selected).filter(function(k){return selected[k]}).length;say(n+T('t.selected'));return}
  copyItem(it)});
cards.addEventListener('dblclick',function(e){var card=e.target.closest('.card');if(card)openPreview(find(card.dataset.id))});
cards.addEventListener('contextmenu',function(e){var card=e.target.closest('.card');if(!card)return;e.preventDefault();togglePin(find(card.dataset.id))});
cards.addEventListener('keydown',function(e){
  var card=e.target.closest('.card');if(!card)return;var it=find(card.dataset.id);
  if(e.key==='Enter'){copyItem(it)} else if(e.key===' '){e.preventDefault();openPreview(it)}
  else if(e.key==='Delete'||e.key==='Backspace'){e.preventDefault();var nx=card.nextElementSibling||card.previousElementSibling;remove(it.id);if(nx){var t=cards.querySelector('[data-id="'+nx.dataset.id+'"]');t&&t.focus()}}
  else if(e.key==='p'||e.key==='P'){togglePin(it)}
  else if(e.key==='ArrowRight'&&card.nextElementSibling){card.nextElementSibling.focus()}
  else if(e.key==='ArrowLeft'&&card.previousElementSibling){card.previousElementSibling.focus()}});
/* drag to the folder (simulated with pointer events) */
var drag=null;
function overFolder(e){var r=$('folder').getBoundingClientRect();return e.clientX>r.left&&e.clientX<r.right&&e.clientY>r.top&&e.clientY<r.bottom}
cards.addEventListener('pointerdown',function(e){var card=e.target.closest('.card');if(!card||e.target.closest('.x')||e.button!==0)return;drag={id:card.dataset.id,x:e.clientX,y:e.clientY,ghost:null}});
window.addEventListener('pointermove',function(e){if(!drag)return;
  if(!drag.ghost&&Math.abs(e.clientY-drag.y)+Math.abs(e.clientX-drag.x)>14){var g=document.createElement('div');g.className='drag-ghost';document.body.appendChild(g);drag.ghost=g}
  if(drag.ghost){drag.ghost.style.left=(e.clientX-55)+'px';drag.ghost.style.top=(e.clientY-40)+'px';$('folder').classList.toggle('over',overFolder(e))}});
window.addEventListener('pointerup',function(e){if(!drag)return;var d=drag;drag=null;if(!d.ghost)return;d.ghost.remove();var f=$('folder');var over=overFolder(e);f.classList.remove('over');
  if(over){var it=find(d.id);remove(d.id,'“'+content(it).title+'” '+T('t.kept'))}else say(T('t.sentcopy'))});
$('b-line').onclick=function(){setLine(!line.classList.contains('open'))};
$('hot').onclick=function(){setLine(!line.classList.contains('open'))};
$('hot').addEventListener('mouseenter',function(){if(!reduce)setLine(true)});
$('b-shot').onclick=shot;$('b-copy').onclick=copyText;$('b-find').onclick=openSearch;$('b-undo').onclick=undoLast;
q.addEventListener('input',applyFilter);
q.addEventListener('keydown',function(e){if(e.key==='Escape'){closeSearch();$('b-find').focus()}else if(e.key==='Enter'){var vis=Array.prototype.filter.call(cards.children,function(c){return !c.classList.contains('hide')})[0];if(vis)say(T('t.newest')+': '+content(find(vis.dataset.id)).title)}});
$('pv-x').onclick=closePreview;
document.addEventListener('keydown',function(e){
  if(e.key==='Escape'&&pv.classList.contains('open')){closePreview();return}
  var inDemo=$('mac').contains(document.activeElement)||document.activeElement===document.body;
  if(e.ctrlKey&&e.altKey&&e.code==='KeyF'){e.preventDefault();openSearch()}
  else if(e.ctrlKey&&e.altKey&&e.code==='KeyT'){e.preventDefault();setLine(!line.classList.contains('open'))}
  else if((e.metaKey||e.ctrlKey)&&e.code==='KeyZ'&&inDemo&&document.activeElement!==q){e.preventDefault();undoLast()}});
function clock(){var d=new Date();$('clock').textContent=d.getHours()+':'+('0'+d.getMinutes()).slice(-2)}
clock();setInterval(clock,20000);
/* copy the Homebrew command (the pill in the first scene and the one in the install section) */
function bindCopy(btn,code){btn.onclick=function(){var txt=code.textContent;
  function done(){btn.textContent=T('d.copied');setTimeout(function(){btn.textContent=T('d.copy')},1500)}
  function sel(){var r=document.createRange();r.selectNodeContents(code);var s=getSelection();s.removeAllRanges();s.addRange(r);done()}
  if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(txt).then(done,sel)}else sel()}}
bindCopy($('brew-copy'),$('brew'));
bindCopy($('brew-up-copy'),$('brew-up'));
/* the app's update check opens the page with ?update=<version>: go to the Update section */
if(/[?&]update=/.test(location.search)&&$('update'))setTimeout(function(){$('update').scrollIntoView({behavior:'smooth',block:'start'})},400);
[].forEach.call(document.querySelectorAll('.brew-copy-btn'),function(b){bindCopy(b,b.parentNode.querySelector('code'))});
/* the short film, from the first scene */
(function(){var box=$('clipbox'),v=$('clipv'),opener=null;
  function open(){opener=document.activeElement;var l=window.I18N.lang;v.poster='media/poster-'+l+'.jpg';v.querySelector('source').src='media/pe-sarma-'+l+'.mp4';v.load();box.hidden=false;$('clip-x').focus();if(!reduce){var p=v.play();if(p&&p.catch)p.catch(function(){})}}
  function close(){v.pause();box.hidden=true;if(opener)opener.focus()}
  $('clip-open').onclick=open;$('clip-x').onclick=close;
  box.addEventListener('click',function(e){if(e.target===box)close()});
  box.addEventListener('keydown',function(e){if(e.key==='Escape'){e.stopPropagation();close()}else if(e.key==='Tab'){var f=[$('clip-x'),v],i=f.indexOf(document.activeElement);if(e.shiftKey&&i<=0){e.preventDefault();f[f.length-1].focus()}else if(!e.shiftKey&&i===f.length-1){e.preventDefault();f[0].focus()}}});
})();
add({kind:'note',welcome:true},true);
add({kind:'shot',n:0},true);
undo=[];

/* ?tour=1 plays the whole sequence by itself, with a visible pointer. The clip and the README animations are frames of it.
   It is deterministic: a 50 ms tick drives both the pointer and the actions, so a frame at time T is always the same. */
if(/[?&]tour=1/.test(location.search)){
  document.documentElement.classList.add('tour');if(/[?&]notoast=1/.test(location.search))document.documentElement.classList.add('notoast');
  var mac=$('mac'),cur=document.createElement('div');cur.id='cur';cur.innerHTML='<svg viewBox="0 0 24 24" width="34" height="34"><path d="M5 3l14 8-6 1.5L10 19z" fill="#fff" stroke="#111" stroke-width="1.4" stroke-linejoin="round"/></svg><i></i>';mac.appendChild(cur);
  var ghost=null;
  function at(sel,dx,dy){var r=(typeof sel==='string'?document.querySelector(sel):sel).getBoundingClientRect(),m=mac.getBoundingClientRect();return [r.left-m.left+r.width*(dx==null?.5:dx),r.top-m.top+r.height*(dy==null?.5:dy)]}
  var W=[ /* time (ms), target resolver */
    [0,function(){var m=mac.getBoundingClientRect();return [m.width*.72,m.height*.62]}],
    [500,function(){var m=mac.getBoundingClientRect();return [m.width*.5,16]}],
    [1100,function(){var m=mac.getBoundingClientRect();return [m.width*.5,14]}],
    [1700,function(){return at('#b-shot')}],[2500,function(){return at('#b-shot')}],
    [3500,function(){return at('#cards .card',.5,.45)}],[4100,function(){return at('#cards .card',.5,.45)}],
    [4700,function(){return at('#cards .card',.5,.45)}],[5900,function(){return at('#folder')}],[6100,function(){return at('#folder')}],
    [6800,function(){return at('#b-find')}],[7200,function(){return at('#b-find')}],
    [9800,function(){return at('#b-find',.5,-1.8)}],
    [10100,function(){return at('#b-undo')}],[10500,function(){return at('#b-undo')}],
    [11200,function(){return at('#b-undo',1.6,-2)}]];
  var pos=[0,0],tk=0;
  function target(i){return W[i][1]()}
  function place(t){
    var i=0;while(i<W.length-1&&W[i+1][0]<=t)i++;
    var a=target(i),b=i<W.length-1?target(i+1):a,span=i<W.length-1?W[i+1][0]-W[i][0]:1,k=i<W.length-1?Math.min(1,(t-W[i][0])/span):1;
    k=k<.5?2*k*k:1-Math.pow(-2*k+2,2)/2;
    pos=[a[0]+(b[0]-a[0])*k,a[1]+(b[1]-a[1])*k];cur.style.transform='translate('+pos[0]+'px,'+pos[1]+'px)';
    if(ghost){ghost.style.left=(pos[0]-55)+'px';ghost.style.top=(pos[1]-40)+'px'}}
  function click(){cur.classList.remove('click');void cur.offsetWidth;cur.classList.add('click')}
  var ev={1100:function(){setLine(true)},2500:function(){click();shot()},
    4100:function(){click();copyItem(items[0])},
    4700:function(){var g=document.createElement('div');g.className='drag-ghost tourghost';mac.appendChild(g);ghost=g;g.style.position='absolute';g.innerHTML='<span class="swin" style="transform:scale(.4)">'+sw(items[0].n)+'</span>'},
    5800:function(){$('folder').classList.add('over')},
    6100:function(){$('folder').classList.remove('over');if(ghost){ghost.remove();ghost=null}var it=items[0];remove(it.id,'“'+content(it).title+'” '+T('t.kept'))},
    7200:function(){click();openSearch()},
    9600:function(){closeSearch();q.value=''},
    10500:function(){click();undoLast()}};
  
  for(var ci=0;ci<8;ci++)(function(c){ev[7500+c*140]=function(){var w=T('tourq');if(c<w.length){q.value=w.slice(0,c+1);applyFilter()}}})(ci);
  setInterval(function(){tk+=50;var t=tk;place(t);Object.keys(ev).forEach(function(k){var kt=parseInt(k,10);if(kt>t-50&&kt<=t&&!ev['d'+k]){ev['d'+k]=1;ev[k]()}})},50);
}
window.I18N.listeners.push(function(){render();lineBtn()});
render();lineBtn();
/* the first scene: the line comes down by itself and a capture hangs, once */
if(!/[?&]tour=1/.test(location.search))setTimeout(function(){setLine(true);if(!reduce)setTimeout(function(){if(items.length<3)shot()},900)},700);
})();
