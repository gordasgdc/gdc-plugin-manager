(function(){
var burger=document.querySelector('.burger'),nav=document.getElementById('nav');
if(burger&&nav){burger.addEventListener('click',function(){var o=nav.classList.toggle('open');burger.setAttribute('aria-expanded',o?'true':'false')});
nav.addEventListener('click',function(e){if(e.target.tagName==='A'){nav.classList.remove('open');burger.setAttribute('aria-expanded','false')}});
document.addEventListener('keydown',function(e){if(e.key==='Escape'&&nav.classList.contains('open')){nav.classList.remove('open');burger.setAttribute('aria-expanded','false');burger.focus()}})}
var lb=document.getElementById('lb');
if(lb&&typeof lb.showModal==='function'){
var img=lb.querySelector('img'),cap=lb.querySelector('p');
document.addEventListener('click',function(e){
 var a=e.target.closest&&e.target.closest('a.open');
 if(a){e.preventDefault();img.src=a.getAttribute('data-full');img.alt=a.getAttribute('data-title')||'';cap.textContent=a.getAttribute('data-title')||'';lb.showModal();return}
 if(e.target===lb||(e.target.closest&&e.target.closest('.lbx'))){lb.close()}});
lb.addEventListener('close',function(){img.removeAttribute('src')})}
document.addEventListener('click',function(e){
 var b=e.target.closest&&e.target.closest('button.copy');if(!b)return;
 var t=b.getAttribute('data-copy'),old=b.textContent;
 function done(){b.textContent=b.getAttribute('data-done');setTimeout(function(){b.textContent=old},1800)}
 if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(t).then(done,function(){})}
 else{var s=b.previousElementSibling;if(s){var r=document.createRange();r.selectNodeContents(s);var g=getSelection();g.removeAllRanges();g.addRange(r)}}});
})();
