/* regatta.tech shared behaviour: section reveals.
   The hidden start state (classes js-anim and js-hero on <html>) is set by a tiny inline script in each
   page's <head>, before first paint, only when motion is allowed. Without JavaScript nothing is hidden.
   Regatta.reveals(order) reveals each .rv-z section (and each .rv-sub block) once, when it comes into view;
   order(section) sets the stagger (--rv-d) of the section's items. */
(function(){
 var root=document.documentElement;
 window.Regatta=window.Regatta||{};
 window.Regatta.reveals=function(order){
  var secs=[].slice.call(document.querySelectorAll('.rv-z,.rv-sub')), io=null, boot=true;
  function on(){ return root.classList.contains('js-anim'); }
  function reveal(sec,now){
   if(sec.classList.contains('rv-in')) return;
   if(order&&sec.classList.contains('rv-z')) order(sec);
   if(now) sec.classList.add('rv-now');
   sec.classList.add('rv-in');
   if(io) io.unobserve(sec);
   try{ sec.dispatchEvent(new CustomEvent('rv:in',{detail:{now:!!now}})); }catch(e){}
  }
  /* in view, or already above it */
  function sweep(){ secs.forEach(function(sec){ if(sec.getBoundingClientRect().top<innerHeight) reveal(sec,true); }); }
  /* reload mid-page or restored scroll: whatever is on screen during start-up shows at once */
  sweep();
  if(on()&&('IntersectionObserver' in window)){
   /* starts when the block is clearly in view: about a quarter of it above the lowest 20% of the screen */
   io=new IntersectionObserver(function(es){ es.forEach(function(e){ if(e.isIntersecting&&(e.intersectionRatio>=.25||e.intersectionRect.height>=innerHeight*.25)) reveal(e.target,boot); }); },{threshold:[0,.1,.25,.5,.75,1],rootMargin:'0px 0px -20% 0px'});
   secs.forEach(function(sec){ if(!sec.classList.contains('rv-in')) io.observe(sec); });
  }
  function onBootScroll(){ if(boot&&on()) sweep(); }
  window.addEventListener('scroll',onBootScroll,{passive:true});
  /* at the very bottom of the page, whatever is on screen plays */
  window.addEventListener('scroll',function(){ if(on()&&!boot&&scrollY+innerHeight>=document.documentElement.scrollHeight-2) secs.forEach(function(sec){ var r=sec.getBoundingClientRect(); if(r.top<innerHeight&&r.bottom>0) reveal(sec,false); }); },{passive:true});
  function endBoot(){ if(!boot) return; boot=false; window.removeEventListener('scroll',onBootScroll); }
  ['wheel','touchstart','keydown','pointerdown'].forEach(function(t){ window.addEventListener(t,endBoot,{passive:true,once:true}); });
  setTimeout(endBoot,900);
  /* jumps (buttons, the arrow, links to an id): the target is ready when you land */
  function jumpTo(el){ var sec=el&&el.closest('.rv-z'); if(!sec) return; reveal(sec,true); [].forEach.call(sec.querySelectorAll('.rv-sub'),function(x){ reveal(x,true); }); }
  document.addEventListener('click',function(e){ var a=e.target.closest&&e.target.closest('[data-go],a[href^="#"]'); if(!a) return; var id=a.getAttribute('data-go')||(a.getAttribute('href')||'').slice(1); jumpTo(id&&document.getElementById(id)); },true);
  window.addEventListener('hashchange',function(){ jumpTo(document.getElementById(location.hash.slice(1))); });
  window.__rvok=true;
 };
})();
