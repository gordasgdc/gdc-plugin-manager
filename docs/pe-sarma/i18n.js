(function(){
'use strict';
var D={};
D.ro={
'clip.btn':'Pe sârmă în acțiune','clip.title':'Pe sârmă în acțiune','clip.close':'Închide','clip.note':'Simulare a aplicației, cu date sintetice: firul coboară, o captură se agață, o copiezi, o tragi într-un folder, cauți și anulezi. Cursorul este vizibil.',
'tourq':'venit',
'meta.title':'Pe sârmă — capturile și ce copiezi, pe un fir sub bara de meniu',
'meta.desc':'Pe sârmă: aplicație gratuită pentru macOS. Capturile de ecran și tot ce copiezi se agață pe un fir sub bara de meniu, le cauți după conținut și le folosești cu gesturi directe.',
'nav.label':'Secțiuni','nav.demo':'Demonstrație','nav.gestures':'Gesturi','nav.download':'Descărcare','nav.source':'Sursa','lang.label':'Limba',
'hero.h1':'<em>Pe sârmă</em>: capturile și ce copiezi, la un gest distanță.',
'hero.p':'Fiecare captură de ecran și tot ce copiezi se agață pe un fir chiar sub bara de meniu. Le cauți după conținut și le folosești cu gesturi directe. Gratuită, cu sursă deschisă, pentru Mac.',
'cta.brew':'Instalare cu Homebrew','cta.download':'Descarcă pentru Mac','cta.source':'Codul sursă',
'hero.note':'Versiunea 1.1.1 · macOS 14 sau mai nou · Apple Silicon și Intel · semnată și notarizată de Apple',
'demo.title':'Demonstrație în browser','demo.sub':'Nu este aplicația reală: doar simulează ce face. Aplicația se instalează pe Mac.',
'mb.file':'Fișier','mb.edit':'Editare','mb.window':'Fereastră',
'demo.hot':'Arată sau ascunde firul (ține cursorul în mijlocul barei de meniu)',
'demo.hint':'Ține cursorul în mijlocul barei de meniu pentru a coborî firul, sau apasă „Arată firul”.',
'demo.lineRegion':'Firul cu elementele agățate','demo.searchLabel':'Caută pe fir','demo.searchPh':'Caută pe fir…  (încearcă „sarma”)',
'demo.folder':'Folder „Proiecte”','demo.close':'Închide','demo.shot':'Fă o captură','demo.copy':'Copiază text','demo.find':'Caută','demo.undo':'Anulează',
'demo.showLine':'Arată firul','demo.hideLine':'Ascunde firul',
'demo.note':'Doar în demonstrație: captura este o ilustrație generată, „clipboardul” este simulat, iar tragerea într-un folder și previzualizarea sunt imitate. În aplicație, tot ce se întâmplă rămâne pe Mac-ul tău.',
't.shot':'Captura s-a agățat pe fir','t.note':'Textul s-a agățat ca notă','t.copied':'Copiat: ','t.discarded':'Aruncat. Anulează cu ⌘Z sau „Anulează”.','t.undone':'Anulat','t.nothing':'Nimic de anulat',
't.selected':' selectate','t.pinned':'Fixat pe fir','t.unpinned':'Desprins','t.kept':'s-a păstrat în folderul Proiecte și a plecat de pe fir','t.sentcopy':'Trimis ca o copie; rămâne pe fir','t.newest':'Copiat cel mai nou rezultat',
'a.shot':'Captură: ','a.note':'Notă: ','a.pinned':' (fixată)','a.keys':'. Enter copiază, Delete aruncă, P fixează, Spațiu previzualizează.','a.discard':'Aruncă ','a.pin':'fixat',
'p.shot':'Previzualizare rapidă a capturii. În demonstrație, captura este o fereastră sintetică, nu un ecran real.',
'shots':['Raport vânzări T3', 'Line.swift', 'Buget 2026', 'Conversație proiect', 'Macheta paginii', 'Terminal'],'ocr':['Raport vânzări T3 Venit 128k Comenzi 1942 Creștere', 'Line.swift struct Line sarma swing', 'Buget 2026 Lună Plan Real Ian Feb Mar', 'Conversație proiect Sârma Ai trimis fișierele Da sunt pe fir', 'Macheta paginii Cabana din Bucegi Rezervă acum', 'Terminal swift build Build complete'],'swl':[['Vânzări T3', 'Venit', 'Comenzi', 'Creștere'], ['Line.swift'], ['Buget 2026', 'Lună', 'Plan', 'Real', 'Ian', 'Feb', 'Mar', 'Apr'], ['Proiect Sârma', 'Ai trimis fișierele?', 'Da, sunt pe fir.', 'Perfect, mulțumesc!'], ['Cabana din Bucegi', 'Rezervă acum'], ['Terminal']],
'notes':[['Idei pentru sâmbătă','Piața de dimineață, cafea la Șarpele Roșu, apoi o plimbare prin Parcul Carol.'],['Listă de cumpărături','Roșii, usturoi, țuică de prune, pâine caldă, sarmale pentru duminică.'],['Adresă','Strada Sârmei nr. 12, ap. 3, București. Interfon 03.'],['Cod ciudat','const sarma = rosii.map(x => x.frunza);'],['Rețetă','Foi de varză, carne tocată, orez, ceapă, boia dulce, o lingură de pastă de roșii.']],
'welcome':['Bun venit','Aceasta este o notă. Fă clic pentru a o copia, dublu clic pentru previzualizare, clic dreapta pentru a o fixa.'],
'g.h2':'Un gest pentru fiecare lucru',
'g1.k':'Clic','g1.v':'Copiază. O notă se copiază cu textul formatat.','g2.k':'Apăsare lungă','g2.v':'Deschide în Adnotare. O notă se deschide pentru editare.','g3.k':'Dublu clic','g3.v':'Deschide în Previzualizare. Un link se deschide în browser.',
'g4.k':'Tragere într-o aplicație','g4.v':'Trimite o copie; rămâne pe fir.','g5.k':'Tragere într-un folder','g5.v':'O păstrezi acolo; pleacă de pe fir.',
'g6.k':'Shift-clic','g6.v':'Selectezi mai multe; meniul, <kbd>⌘</kbd><kbd>C</kbd>, <kbd>⌫</kbd> și tragerea acționează asupra tuturor.',
'g7.k':'pe fir','g7.v':'Anulează ce ai făcut: aruncare, fixare, salvare pe Desktop.','g8.k':'Clic dreapta','g8.v':'Partajează, fixează pe fir, ține în fața ferestrelor, arată în Finder.',
'g9.v':'Arată sau ascunde firul (se poate schimba).','g10.v':'Caută pe fir (se poate schimba).',
'w.h2':'Ce face',
'w1':'<b>Capturi și înregistrări de ecran</b> apar pe fir în clipa în care le faci, fără miniatura plutitoare și fără să se adune pe Desktop.',
'w2':'<b>Ce copiezi</b>: imagini, text și linkuri, cu opțiuni separate. Textul devine notă, linkul își arată site-ul.',
'w3':'<b>Căutare în conținut</b>: textul din capturi este citit local, pe Mac, iar căutarea ignoră diacriticele („sarma” găsește „sârmă”).',
'w4':'<b>Privat</b>: nu se păstrează nimic din câmpurile de parolă, din ce marchează ca privat un manager de parole sau din alt dispozitiv. Fără cont, fără rețea, fără statistici.',
'w.note':'Dacă îi lași aplicației gestionarea capturilor, ea schimbă setările de captură din macOS (locația, miniatura plutitoare, destinația) și le pune la loc când o dezactivezi sau o închizi.',
'd.h2':'Descărcare și instalare',
'f.price.k':'Preț','f.price.v':'Gratuită, pentru toată lumea','f.sys.k':'Sistem','f.sys.v':'macOS 14 Sonoma sau mai nou','f.cpu.k':'Procesor','f.cpu.v':'Apple Silicon și Intel','f.lang.k':'Limbi','f.lang.v':'Română, spaniolă, engleză (după limba din macOS; o schimbi din meniul aplicației: Limbă)',
'f.perm.k':'Permisiuni','f.perm.v':'Acces la folderul cu capturi (Desktop, Documente sau Descărcări, dacă îl alegi tu)','f.lic.k':'Licență','f.lic.v':'MIT pentru cod',
'd.opt1':'Opțiunea 1: imaginea disc','d.dmg':'Descarcă imaginea disc (.dmg)','d.all':'Toate versiunile','d.dmgnote':'Deschide imaginea disc și trage aplicația în Aplicații. Suma SHA-256 este în notele versiunii.',
'd.opt2':'Opțiunea 2: Homebrew','d.copy':'Copiază','d.copied':'Copiat','d.brewnote':'Instalează aceeași aplicație, din același DMG notarizat din GitHub Releases.',
'c.h2':'Credite','c.edition':'Pe sârmă — ediția în limba română, publicată și întreținută de Cristi Gordaș.',
'c.based':'Aplicația este bazată pe <a href="https://github.com/alejandrobujan/tendedero">Tendedero</a>, creat de Alejandro Buján, și folosește același cod sub licența MIT. Numele, pictograma și materialele acestei pagini sunt proprii acestei ediții.',
'foot.text':'Platformă administrată de dezvoltatori independenți. Aplicația este oferită „așa cum este”, fără garanții. Proiect gratuit.','foot.terms':'Termeni','foot.priv':'Confidențialitate','foot.src':'Cod sursă','foot.lic':'Licență MIT (Tendedero)'
};
D.es={
'clip.btn':'Pe sârmă en acción','clip.title':'Pe sârmă en acción','clip.close':'Cerrar','clip.note':'Simulación de la app, con datos sintéticos: el hilo baja, una captura se cuelga, la copias, la arrastras a una carpeta, buscas y deshaces. El cursor es visible.',
'tourq':'ingresos',
'meta.title':'Pe sârmă — tus capturas y lo que copias, en un hilo bajo la barra de menús',
'meta.desc':'Pe sârmă: app gratuita para macOS. Tus capturas de pantalla y todo lo que copias cuelgan de un hilo bajo la barra de menús; las buscas por contenido y las usas con gestos directos.',
'nav.label':'Secciones','nav.demo':'Demostración','nav.gestures':'Gestos','nav.download':'Descarga','nav.source':'Código','lang.label':'Idioma',
'hero.h1':'<em>Pe sârmă</em>: tus capturas y lo que copias, a un gesto de distancia.',
'hero.p':'Cada captura de pantalla y todo lo que copias cuelga de un hilo justo bajo la barra de menús. Las buscas por contenido y las usas con gestos directos. Gratuita y de código abierto, para Mac.',
'cta.brew':'Instalar con Homebrew','cta.download':'Descargar para Mac','cta.source':'Código fuente',
'hero.note':'Versión 1.1.1 · macOS 14 o posterior · Apple Silicon e Intel · firmada y notarizada por Apple',
'demo.title':'Demostración en el navegador','demo.sub':'No es la app real: solo simula lo que hace. La app se instala en el Mac.',
'mb.file':'Archivo','mb.edit':'Edición','mb.window':'Ventana',
'demo.hot':'Mostrar u ocultar el hilo (mantén el cursor en el centro de la barra de menús)',
'demo.hint':'Mantén el cursor en el centro de la barra de menús para bajar el hilo, o pulsa «Mostrar el hilo».',
'demo.lineRegion':'La hilo con los elementos colgados','demo.searchLabel':'Buscar en el hilo','demo.searchPh':'Buscar en el hilo…  (prueba «cafe»)',
'demo.folder':'Carpeta «Proyectos»','demo.close':'Cerrar','demo.shot':'Hacer una captura','demo.copy':'Copiar texto','demo.find':'Buscar','demo.undo':'Deshacer',
'demo.showLine':'Mostrar el hilo','demo.hideLine':'Ocultar el hilo',
'demo.note':'Solo en la demostración: la captura es una ilustración generada, el «portapapeles» es simulado y el arrastre a una carpeta y la vista previa son imitaciones. En la app, todo lo que ocurre se queda en tu Mac.',
't.shot':'La captura quedó colgada en el hilo','t.note':'El texto quedó colgado como nota','t.copied':'Copiado: ','t.discarded':'Descartado. Deshaz con ⌘Z o «Deshacer».','t.undone':'Deshecho','t.nothing':'Nada que deshacer',
't.selected':' seleccionados','t.pinned':'Fijado en el hilo','t.unpinned':'Soltado','t.kept':'se guardó en la carpeta Proyectos y salió del hilo','t.sentcopy':'Enviada una copia; sigue en el hilo','t.newest':'Copiado el resultado más reciente',
'a.shot':'Captura: ','a.note':'Nota: ','a.pinned':' (fijada)','a.keys':'. Intro copia, Supr descarta, P fija, Espacio previsualiza.','a.discard':'Descartar ','a.pin':'fijado',
'p.shot':'Vista rápida de la captura. En la demo, la captura es una ventana sintética, no una pantalla real.',
'shots':['Informe de ventas T3', 'Line.swift', 'Presupuesto 2026', 'Conversación del proyecto', 'Maqueta de la página', 'Terminal'],'ocr':['Informe de ventas T3 Ingresos 128k Pedidos 1942 Crecimiento', 'Line.swift struct Line sarma swing', 'Presupuesto 2026 Mes Plan Real Ene Feb Mar', 'Conversación del proyecto Sârma Enviaste los archivos Sí están en el hilo', 'Maqueta de la página Cabaña en la sierra Reserva ahora', 'Terminal swift build Build complete'],'swl':[['Ventas T3', 'Ingresos', 'Pedidos', 'Crecimiento'], ['Line.swift'], ['Presupuesto 2026', 'Mes', 'Plan', 'Real', 'Ene', 'Feb', 'Mar', 'Abr'], ['Proyecto Sârma', '¿Enviaste los archivos?', 'Sí, están en el hilo.', '¡Perfecto, gracias!'], ['Cabaña en la sierra', 'Reserva ahora'], ['Terminal']],
'notes':[['Ideas para el sábado','Mercado por la mañana, café con Ana en la plaza y paseo por el parque.'],['Lista de la compra','Tomates, ajo, pan recién hecho, aceite de oliva y café para el domingo.'],['Dirección','Calle del Alambre 12, 3.º B, Madrid. Portero automático 03.'],['Código raro','const cafe = tomates.map(x => x.hoja);'],['Receta','Hojas de col, carne picada, arroz, cebolla, pimentón dulce y una cucharada de tomate.']],
'welcome':['Bienvenido','Esto es una nota. Haz clic para copiarla, doble clic para previsualizarla y clic derecho para fijarla.'],
'g.h2':'Un gesto para cada cosa',
'g1.k':'Clic','g1.v':'Copia. Una nota se copia con su texto con formato.','g2.k':'Pulsación larga','g2.v':'Abre en Marcado. Una nota se abre para editarla.','g3.k':'Doble clic','g3.v':'Abre en Vista previa. Un enlace se abre en el navegador.',
'g4.k':'Arrastrar a una app','g4.v':'Envía una copia; sigue en el hilo.','g5.k':'Arrastrar a una carpeta','g5.v':'Se queda allí; sale del hilo.',
'g6.k':'Mayús-clic','g6.v':'Seleccionas varias; el menú, <kbd>⌘</kbd><kbd>C</kbd>, <kbd>⌫</kbd> y el arrastre actúan sobre todas.',
'g7.k':'en el hilo','g7.v':'Deshace lo último: descartar, fijar, guardar en el Escritorio.','g8.k':'Clic derecho','g8.v':'Compartir, fijar en el hilo, mantener delante de las ventanas, mostrar en Finder.',
'g9.v':'Muestra u oculta el hilo (se puede cambiar).','g10.v':'Busca en el hilo (se puede cambiar).',
'w.h2':'Qué hace',
'w1':'<b>Capturas y grabaciones de pantalla</b> cuelgan en el momento en que las haces, sin la miniatura flotante y sin acumularse en el Escritorio.',
'w2':'<b>Lo que copias</b>: imágenes, texto y enlaces, con opciones separadas. El texto se convierte en nota y el enlace muestra su sitio.',
'w3':'<b>Búsqueda por contenido</b>: el texto de las capturas se lee en local, en tu Mac, y la búsqueda ignora los acentos («cafe» encuentra «café»).',
'w4':'<b>Privado</b>: no se guarda nada de los campos de contraseña, de lo que un gestor de contraseñas marca como privado ni de otro dispositivo. Sin cuenta, sin red, sin analíticas.',
'w.note':'Si dejas que la app gestione tus capturas, cambia los ajustes de captura de macOS (ubicación, miniatura flotante, destino) y los restaura al desactivarla o cerrarla.',
'd.h2':'Descarga e instalación',
'f.price.k':'Precio','f.price.v':'Gratuita, para todo el mundo','f.sys.k':'Sistema','f.sys.v':'macOS 14 Sonoma o posterior','f.cpu.k':'Procesador','f.cpu.v':'Apple Silicon e Intel','f.lang.k':'Idiomas','f.lang.v':'Rumano, español e inglés (según el idioma de macOS; se cambia desde el menú de la app: Idioma)',
'f.perm.k':'Permisos','f.perm.v':'Acceso a la carpeta de capturas (Escritorio, Documentos o Descargas, si la eliges tú)','f.lic.k':'Licencia','f.lic.v':'MIT para el código',
'd.opt1':'Opción 1: imagen de disco','d.dmg':'Descargar la imagen de disco (.dmg)','d.all':'Todas las versiones','d.dmgnote':'Abre la imagen de disco y arrastra la app a Aplicaciones. La suma SHA-256 está en las notas de la versión.',
'd.opt2':'Opción 2: Homebrew','d.copy':'Copiar','d.copied':'Copiado','d.brewnote':'Instala la misma app, desde el mismo DMG notarizado de GitHub Releases.',
'c.h2':'Créditos','c.edition':'Pe sârmă — la edición en rumano, publicada y mantenida por Cristi Gordaș.',
'c.based':'La app está basada en <a href="https://github.com/alejandrobujan/tendedero">Tendedero</a>, creada por Alejandro Buján, y usa el mismo código bajo licencia MIT. El nombre, el icono y los materiales de esta página son propios de esta edición.',
'foot.text':'Plataforma administrada por desarrolladores independientes. La app se ofrece «tal cual», sin garantías. Proyecto gratuito.','foot.terms':'Términos','foot.priv':'Privacidad','foot.src':'Código fuente','foot.lic':'Licencia MIT (Tendedero)'
};
D.en={
'clip.btn':'Pe sârmă in action','clip.title':'Pe sârmă in action','clip.close':'Close','clip.note':'A simulation of the app, with synthetic data: the line comes down, a screenshot hangs, you copy it, drag it to a folder, search and undo. The pointer is visible.',
'tourq':'revenue',
'meta.title':'Pe sârmă — your screenshots and copies on a line under the menu bar',
'meta.desc':'Pe sârmă: a free macOS app. Your screenshots and everything you copy hang on a line under the menu bar; find them by content and use them with direct gestures.',
'nav.label':'Sections','nav.demo':'Demo','nav.gestures':'Gestures','nav.download':'Download','nav.source':'Source','lang.label':'Language',
'hero.h1':'<em>Pe sârmă</em>: your screenshots and copies, one gesture away.',
'hero.p':'Every screenshot and everything you copy hangs on a line just under the menu bar. Find them by content and use them with direct gestures. Free and open source, for Mac.',
'cta.brew':'Install with Homebrew','cta.download':'Download for Mac','cta.source':'Source code',
'hero.note':'Version 1.1.1 · macOS 14 or later · Apple silicon and Intel · signed and notarized by Apple',
'demo.title':'Demo in the browser','demo.sub':'This is not the real app: it only simulates what it does. The app installs on your Mac.',
'mb.file':'File','mb.edit':'Edit','mb.window':'Window',
'demo.hot':'Show or hide the line (rest the pointer in the middle of the menu bar)',
'demo.hint':'Rest the pointer in the middle of the menu bar to bring the line down, or press “Show line”.',
'demo.lineRegion':'The line with the hanging items','demo.searchLabel':'Search the line','demo.searchPh':'Search the line…  (try “cafe”)',
'demo.folder':'“Projects” folder','demo.close':'Close','demo.shot':'Take a screenshot','demo.copy':'Copy text','demo.find':'Search','demo.undo':'Undo',
'demo.showLine':'Show line','demo.hideLine':'Hide line',
'demo.note':'Demo only: the screenshot is a generated illustration, the “clipboard” is simulated, and dragging to a folder and the preview are imitated. In the app, everything that happens stays on your Mac.',
't.shot':'The screenshot is hanging on the line','t.note':'The text is hanging as a note','t.copied':'Copied: ','t.discarded':'Discarded. Undo with ⌘Z or “Undo”.','t.undone':'Undone','t.nothing':'Nothing to undo',
't.selected':' selected','t.pinned':'Pinned to the line','t.unpinned':'Unpinned','t.kept':'was kept in the Projects folder and left the line','t.sentcopy':'Sent a copy; it stays on the line','t.newest':'Copied the newest match',
'a.shot':'Screenshot: ','a.note':'Note: ','a.pinned':' (pinned)','a.keys':'. Enter copies, Delete discards, P pins, Space previews.','a.discard':'Discard ','a.pin':'pinned',
'p.shot':'Quick look at the screenshot. In the demo, the screenshot is a synthetic window, not a real screen.',
'shots':['Q3 sales report', 'Line.swift', '2026 budget', 'Project chat', 'Page mockup', 'Terminal'],'ocr':['Q3 sales report Revenue 128k Orders 1942 Growth', 'Line.swift struct Line sarma swing', '2026 budget Month Plan Actual Jan Feb Mar', 'Project chat Sârma Did you send the files Yes they are on the line', 'Page mockup Mountain cabin Book now', 'Terminal swift build Build complete'],'swl':[['Q3 sales', 'Revenue', 'Orders', 'Growth'], ['Line.swift'], ['2026 budget', 'Month', 'Plan', 'Actual', 'Jan', 'Feb', 'Mar', 'Apr'], ['Sârma project', 'Did you send the files?', 'Yes, they are on the line.', 'Perfect, thanks!'], ['Mountain cabin', 'Book now'], ['Terminal']],
'notes':[['Ideas for Saturday','Morning market, coffee at the café with Ana, then a walk in the park.'],['Shopping list','Tomatoes, garlic, fresh bread, olive oil and café au lait for Sunday.'],['Address','12 Wire Street, flat 3, London. Door entry 03.'],['Odd code','const cafe = tomatoes.map(x => x.leaf);'],['Recipe','Cabbage leaves, minced meat, rice, onion, sweet paprika and a spoon of tomato paste.']],
'welcome':['Welcome','This is a note. Click to copy it, double-click to preview it, right-click to pin it.'],
'g.h2':'A gesture for everything',
'g1.k':'Click','g1.v':'Copy it. A note copies its text, styled as it was.','g2.k':'Press and hold','g2.v':'Open it in Markup. A note opens to edit.','g3.k':'Double click','g3.v':'Open it in Preview. A link opens in your browser.',
'g4.k':'Drag into an app','g4.v':'Send a copy. It stays on the line.','g5.k':'Drag into a folder','g5.v':'Keep it there. It leaves the line.',
'g6.k':'Shift-click','g6.v':'Select several. Their menu, <kbd>⌘</kbd><kbd>C</kbd>, <kbd>⌫</kbd> and a drag act on them all.',
'g7.k':'on the line','g7.v':'Undo what you just did: let go, pin or save to the Desktop.','g8.k':'Right click','g8.v':'Share, pin to the line, hold in front of your windows, show in Finder.',
'g9.v':'Show or hide the line (can be changed).','g10.v':'Search the line (can be changed).',
'w.h2':'What it does',
'w1':'<b>Screenshots and screen recordings</b> hang the instant you take them, with no floating thumbnail and no pile-up on the Desktop.',
'w2':'<b>What you copy</b>: images, text and links, with separate switches. Text becomes a note; a link shows its site.',
'w3':'<b>Search by content</b>: the text in screenshots is read locally, on your Mac, and search ignores accents (“cafe” finds “café”).',
'w4':'<b>Private</b>: nothing is kept from password fields, from what a password manager marks as private, or from another device. No account, no network, no analytics.',
'w.note':'If you let the app handle your screenshots, it changes the macOS screenshot settings (location, floating thumbnail, destination) and puts them back when you turn it off or quit.',
'd.h2':'Download and install',
'f.price.k':'Price','f.price.v':'Free, for everyone','f.sys.k':'System','f.sys.v':'macOS 14 Sonoma or later','f.cpu.k':'Processor','f.cpu.v':'Apple silicon and Intel','f.lang.k':'Languages','f.lang.v':'Romanian, Spanish and English (follows your macOS language; change it from the app menu: Language)',
'f.perm.k':'Permissions','f.perm.v':'Access to the screenshots folder (Desktop, Documents or Downloads, if you choose it)','f.lic.k':'License','f.lic.v':'MIT for the code',
'd.opt1':'Option 1: disk image','d.dmg':'Download the disk image (.dmg)','d.all':'All versions','d.dmgnote':'Open the disk image and drag the app to Applications. The SHA-256 sum is in the release notes.',
'd.opt2':'Option 2: Homebrew','d.copy':'Copy','d.copied':'Copied','d.brewnote':'Installs the same app, from the same notarized DMG on GitHub Releases.',
'c.h2':'Credits','c.edition':'Pe sârmă — the Romanian-language edition, published and maintained by Cristi Gordaș.',
'c.based':'The app is based on <a href="https://github.com/alejandrobujan/tendedero">Tendedero</a>, created by Alejandro Buján, and uses the same code under the MIT license. The name, icon and materials of this page are specific to this edition.',
'foot.text':'Platform run by independent developers. The app is provided “as is”, without warranties. Free project.','foot.terms':'Terms','foot.priv':'Privacy','foot.src':'Source code','foot.lic':'MIT license (Tendedero)'
};
var codes=['ro','es','en'];
function pick(){
  var p=new URLSearchParams(location.search).get('lang');if(codes.indexOf(p)>-1)return p;
  try{var s=localStorage.getItem('pesarma-lang');if(codes.indexOf(s)>-1)return s}catch(e){}
  var nl=(navigator.languages||[navigator.language||'ro']);
  for(var i=0;i<nl.length;i++){var c=String(nl[i]).slice(0,2).toLowerCase();if(codes.indexOf(c)>-1)return c}
  return 'ro';
}
var I={lang:'ro',D:D,codes:codes,listeners:[],
 t:function(k){var v=D[I.lang][k];return v===undefined?D.ro[k]:v},
 set:function(l){
  if(codes.indexOf(l)<0)l='ro';I.lang=l;document.documentElement.lang=l;
  try{localStorage.setItem('pesarma-lang',l)}catch(e){}
  document.title=I.t('meta.title');
  var md=document.querySelector('meta[name=description]');if(md)md.setAttribute('content',I.t('meta.desc'));
  [].forEach.call(document.querySelectorAll('[data-i]'),function(e){e.textContent=I.t(e.getAttribute('data-i'))});
  [].forEach.call(document.querySelectorAll('[data-ih]'),function(e){e.innerHTML=I.t(e.getAttribute('data-ih'))});
  [].forEach.call(document.querySelectorAll('[data-ial]'),function(e){e.setAttribute('aria-label',I.t(e.getAttribute('data-ial')))});
  [].forEach.call(document.querySelectorAll('[data-iph]'),function(e){e.setAttribute('placeholder',I.t(e.getAttribute('data-iph')))});
  [].forEach.call(document.querySelectorAll('[data-lang]'),function(b){b.setAttribute('aria-pressed',b.getAttribute('data-lang')===l)});
  try{var u=new URL(location.href);if(u.searchParams.get('lang')!==l){u.searchParams.set('lang',l);history.replaceState(null,'',u)}}catch(e){}
  I.listeners.forEach(function(f){f(l)});
 }};
window.I18N=I;
document.addEventListener('DOMContentLoaded',function(){
  [].forEach.call(document.querySelectorAll('[data-lang]'),function(b){b.addEventListener('click',function(){I.set(b.getAttribute('data-lang'))})});
  I.set(pick());
});
})();
