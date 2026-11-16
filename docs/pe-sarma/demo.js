(function(){
'use strict';
var $=function(i){return document.getElementById(i)};
var T=function(k){return window.I18N.t(k)};
var line=$('line'),cards=$('cards'),toast=$('toast'),q=$('q'),search=$('search'),pv=$('preview');
var items=[],undo=[],uid=0,selected={},toastT=0,reduce=window.matchMedia&&matchMedia('(prefers-reduced-motion: reduce)').matches;
function fold(s){return String(s).normalize('NFD').replace(/[̀-ͯ]/g,'').replace(/[șş]/gi,'s').replace(/[țţ]/gi,'t').toLowerCase()}
function say(m){toast.textContent=m;toast.classList.add('show');clearTimeout(toastT);toastT=setTimeout(function(){toast.classList.remove('show')},2200)}
function esc(s){return String(s).replace(/[&<>"]/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]})}
function lineBtn(){var on=line.classList.contains('open');$('b-line').setAttribute('aria-pressed',on);$('b-line').textContent=T(on?'demo.hideLine':'demo.showLine')}
function setLine(on){line.classList.toggle('open',on);lineBtn();$('hint').style.opacity=on?0:1;if(!on)closeSearch()}
function shotFace(n){var w=['#E08E4A','#7b5ea7','#3b8c9e','#c0578a'][n%4];return '<span class="face shot"><span class="win"><i><s></s><s></s><s></s></i><span class="body"><u style="width:80%"></u><u style="width:55%"></u><span class="blk" style="background:linear-gradient(135deg,'+w+',#2b3038)"></span><u style="width:70%"></u></span></span></span>'}
/* an item stores indexes, not words, so the language can change under it */
function content(it){
  if(it.kind==='shot')return {title:T('shots')[it.n],body:'',ocr:T('ocr')};
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
  add({kind:'shot',n:Math.floor(Math.random()*T('shots').length)});
}
function copyText(){add({kind:'note',ni:Math.floor(Math.random()*T('notes').length)})}
function remove(id,msg){var i=items.findIndex(function(x){return String(x.id)===String(id)});if(i<0)return;var it=items.splice(i,1)[0];undo.push({type:'del',it:it,i:i});delete selected[id];render();say(msg||T('t.discarded'))}
function undoLast(){var u=undo.pop();if(!u){say(T('t.nothing'));return}
  if(u.type==='add'){var i=items.findIndex(function(x){return x.id===u.id});if(i>-1)items.splice(i,1)}
  else if(u.type==='del'){items.splice(u.i,0,u.it)}
  else if(u.type==='pin'){var p=find(u.id);if(p)p.pinned=u.was}
  render();say(T('t.undone'))}
function copyItem(it){say(T('t.copied')+content(it).title)}
function openPreview(it){var c=content(it);$('pv-t').textContent=c.title;$('pv-b').innerHTML='<p>'+esc(it.kind==='shot'?T('p.shot'):c.body)+'</p>';pv.classList.add('open');$('pv-x').focus()}
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
[].forEach.call(document.querySelectorAll('.brew-copy-btn'),function(b){bindCopy(b,b.parentNode.querySelector('code'))});
add({kind:'note',welcome:true},true);
add({kind:'shot',n:0},true);
undo=[];

/* ?tour=1 plays the whole sequence on its own; the README animations are frames of it */
if(/[?&]tour=1/.test(location.search)){
  var firstCard=function(){return items[0]};
  setTimeout(function(){setLine(true)},600);
  setTimeout(shot,1500);
  setTimeout(function(){copyItem(firstCard())},2800);
  setTimeout(function(){openSearch();q.value='sarma';applyFilter()},4000);
  setTimeout(function(){closeSearch()},5400);
  setTimeout(function(){remove(firstCard().id)},6000);
  setTimeout(undoLast,6900);
}
window.I18N.listeners.push(function(){render();lineBtn()});
render();lineBtn();
/* the first scene: the line comes down by itself and a capture hangs, once */
if(!/[?&]tour=1/.test(location.search))setTimeout(function(){setLine(true);if(!reduce)setTimeout(function(){if(items.length<3)shot()},900)},700);
})();
