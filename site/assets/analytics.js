/* regatta.tech analytics: Umami Cloud, EU data region (Daniela, 25 Nov 2026).
   Cookieless. Nothing is stored on the visitor's device. Events carry no personal data.

   OFF until set up: nothing loads while WEBSITE_ID is the placeholder below. To turn it on, paste the
   website id from Umami (Settings -> Websites -> Edit -> Website ID, a UUID) into WEBSITE_ID, and check
   that HOST matches the script URL in Umami's "Tracking code" for this website.
   Also not loaded: off regatta.tech (local copies, previews), and when the browser sends
   Do Not Track or Global Privacy Control.

   Events (names are fixed; the dashboard groups by them):
     pageviews and referrers, UTM tags included   automatic (Umami); /thanks/ = request sent (goal)
     request-access-sent        /thanks/ reached
     request-access-hero        click: hero "Request access" button          (data-ev in the page)
     request-access-form        click: form "Request access" button          (data-ev in the page)
     open-app {place}           click: "Open Regatta" link, place nav/footer (data-ev in the page)
     chart-switch {view}        click: section 2 chart switch, view all/marker
     contact-section-seen       the form section (#s6) comes into view, once per page view
     app-demo-seen              the app demo (#rgdemo) comes into view, once per page view
   Clicks are sent with umami.track from one listener, not with data-umami-event: Umami's own link
   handling re-navigates same-page links (#s6), which would break the smooth scroll to the form. */
(function(){
 var WEBSITE_ID='UMAMI_WEBSITE_ID_TODO';
 var HOST='https://eu.umami.is';
 var SITE='regatta.tech';

 if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(WEBSITE_ID)) return;
 if(location.hostname!==SITE) return;
 var n=navigator;
 if(n.doNotTrack==='1'||n.doNotTrack==='yes'||window.doNotTrack==='1'||n.globalPrivacyControl===true) return;

 /* events that happen before the Umami script has loaded wait here */
 var queue=[];
 function track(name,data){ var u=window.umami; if(u&&u.track) u.track(name,data); else queue.push([name,data]); }

 var s=document.createElement('script');
 s.defer=true; s.src=HOST+'/script.js';
 s.setAttribute('data-website-id',WEBSITE_ID);
 s.setAttribute('data-domains',SITE);
 s.setAttribute('data-do-not-track','true');
 s.onload=function(){ var u=window.umami; if(!u||!u.track) return; while(queue.length){ var e=queue.shift(); u.track(e[0],e[1]); } };
 document.head.appendChild(s);

 /* goal: the form was sent */
 if(location.pathname==='/thanks/') track('request-access-sent');

 /* clicks on elements marked data-ev="<event>" (optional data-ev-place / data-ev-view) */
 document.addEventListener('click',function(e){
  var el=e.target&&e.target.closest&&e.target.closest('[data-ev]'); if(!el) return;
  var d={}, has=false;
  ['place','view'].forEach(function(k){ var v=el.getAttribute('data-ev-'+k); if(v){ d[k]=v; has=true; } });
  track(el.getAttribute('data-ev'),has?d:undefined);
 },true);

 /* sections seen: once per page view */
 function seen(id,name,ratio){
  var el=document.getElementById(id); if(!el||!('IntersectionObserver' in window)) return;
  var io=new IntersectionObserver(function(es){ es.forEach(function(x){ if(x.isIntersecting){ io.disconnect(); track(name); } }); },{threshold:ratio});
  io.observe(el);
 }
 function start(){ seen('s6','contact-section-seen',.25); seen('rgdemo','app-demo-seen',.5); }
 if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',start); else start();
})();
