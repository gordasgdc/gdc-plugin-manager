(function(){
var nav=document.getElementById('nav'),bt=document.querySelector('.burger');
if(bt)bt.addEventListener('click',function(){var o=nav.classList.toggle('open');bt.setAttribute('aria-expanded',o)});
nav.addEventListener('click',function(e){if(e.target.tagName==='A'){nav.classList.remove('open');bt.setAttribute('aria-expanded','false')}});
var links=[].slice.call(nav.querySelectorAll('a[href^="#"]'));
function sw(){var h=location.hash||'';document.querySelectorAll('.sw a').forEach(function(a){a.href=a.getAttribute('href').split('#')[0]+h})}
var secs=links.map(function(a){return document.querySelector(a.getAttribute('href'))}).filter(Boolean);
if('IntersectionObserver' in window){var io=new IntersectionObserver(function(es){es.forEach(function(e){if(e.isIntersecting){var id=e.target.id;links.forEach(function(a){a.classList.toggle('on',a.getAttribute('href')==='#'+id)});
 document.querySelectorAll('.sw a').forEach(function(a){a.href=a.getAttribute('href').split('#')[0]+'#'+id})}})},{rootMargin:'-30% 0px -60% 0px'});secs.forEach(function(s){io.observe(s)})}
window.addEventListener('hashchange',sw);sw();
var lb=document.getElementById('lb'),li=lb.querySelector('img'),lp=lb.querySelector('p');
document.querySelectorAll('img.zoomable').forEach(function(im){im.tabIndex=0;im.setAttribute('role','button');
 function open(){li.src=im.dataset.full||im.src;li.alt=im.alt;lp.textContent=(im.closest('figure')||{}).innerText||'';if(lb.showModal)lb.showModal();else lb.setAttribute('open','')}
 im.addEventListener('click',open);im.addEventListener('keydown',function(e){if(e.key==='Enter'||e.key===' '){e.preventDefault();open()}})});
lb.addEventListener('click',function(e){if(e.target===lb||e.target.classList.contains('lbx'))lb.close()});
})();
