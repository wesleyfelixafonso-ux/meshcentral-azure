/* theme.js: camada de interface por cima do MeshCentral (carregado via domains."".customFiles).
   - Tema: escuro por padrão, claro opcional, usando a preferência do próprio MeshCentral.
   - Painel: barra superior (ao vivo, busca por máquina ou pessoa com Ctrl K, sol/lua), saudação com
     contadores, botão Atualizar, menu lateral recolhível e seletor de tela no acesso remoto.
   - Login: cartão com botão "Entrar com Google".
   Tudo é aditivo e protegido por try/catch: se algo do MeshCentral mudar, a página segue funcionando. */
(function () {
  'use strict';
  var ICON = {
    sun: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>',
    moon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></svg>',
    search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>',
    lock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>',
    panel: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3.5" width="18" height="17" rx="2.5"/><path d="M9 3.5v17"/><path d="m13.5 9.5 2.5 2.5-2.5 2.5"/></svg>',
    remote: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/><path d="m10 8 4 2-4 2z" fill="currentColor"/></svg>',
    google: '<svg viewBox="0 0 48 48"><path fill="#EA4335" d="M24 9.5c3.5 0 6.6 1.2 9.1 3.6l6.8-6.8C35.8 2.4 30.3 0 24 0 14.6 0 6.6 5.4 2.6 13.3l7.9 6.2C12.4 13.6 17.7 9.5 24 9.5z"/><path fill="#4285F4" d="M46.1 24.5c0-1.6-.1-3.1-.4-4.5H24v9h12.4c-.5 2.9-2.2 5.4-4.6 7l7.4 5.8c4.3-4 6.9-9.9 6.9-17.3z"/><path fill="#FBBC05" d="M10.5 28.6c-.5-1.5-.8-3-.8-4.6s.3-3.1.8-4.6l-7.9-6.2C.9 16.5 0 20.1 0 24s.9 7.5 2.6 10.8l7.9-6.2z"/><path fill="#34A853" d="M24 48c6.5 0 11.9-2.1 15.8-5.8l-7.4-5.8c-2.1 1.4-4.8 2.3-8.4 2.3-6.3 0-11.6-4.1-13.5-9.7l-7.9 6.2C6.6 42.6 14.6 48 24 48z"/></svg>'
  };
  function $(id) { return document.getElementById(id); }
  function el(tag, attrs, html) { var e = document.createElement(tag); for (var k in (attrs || {})) e.setAttribute(k, attrs[k]); if (html != null) e.innerHTML = html; return e; }
  function safe(fn) { try { fn(); } catch (e) { if (window.console) console.warn('rt-theme:', e); } }

  // ── Tema ──────────────────────────────────────────────────────────────────────
  var isPanel = function () { return typeof setNightMode === 'function' && typeof putstore === 'function'; };
  function pref() { try { return localStorage.getItem('nightMode'); } catch (e) { return null; } }
  function isDark() { return pref() !== '2'; }   // padrão: escuro
  function applyLoginTheme() {
    var h = document.documentElement;
    h.classList.toggle('rt-dark', isDark());
    h.classList.toggle('rt-light', !isDark());
  }
  // No painel quem manda é o data-bs-theme do MeshCentral (também muda pelo menu dele):
  // a classe rt-dark/rt-light acompanha, senão os tokens do outro modo vencem.
  function syncPanelClass() {
    var dark = document.documentElement.getAttribute('data-bs-theme') !== 'light';
    document.documentElement.classList.toggle('rt-dark', dark);
    document.documentElement.classList.toggle('rt-light', !dark);
    document.querySelectorAll('.rt-theme-toggle').forEach(paintToggle);
  }
  var observing = false;
  function observeTheme() {
    if (observing || !window.MutationObserver) return;
    observing = true;
    new MutationObserver(syncPanelClass).observe(document.documentElement, { attributes: true, attributeFilter: ['data-bs-theme'] });
  }
  function setTheme(dark) {
    if (isPanel()) { putstore('nightMode', dark ? '1' : '2'); setNightMode(); syncPanelClass(); }
    else { try { localStorage.setItem('nightMode', dark ? '1' : '2'); } catch (e) { } applyLoginTheme(); }
    document.querySelectorAll('.rt-theme-toggle').forEach(paintToggle);
  }
  function paintToggle(b) {
    var dark = isDark();
    b.innerHTML = dark ? ICON.sun : ICON.moon;
    b.title = dark ? 'Mudar para o modo claro' : 'Mudar para o modo escuro';
    b.setAttribute('aria-label', b.title);
  }
  function themeToggle() {
    var b = el('button', { type: 'button', class: 'rt-iconbtn rt-theme-toggle' });
    paintToggle(b);
    b.addEventListener('click', function () { setTheme(!isDark()); });
    return b;
  }
  function initPanelTheme() {
    var p = pref();
    if (p === null || p === '0') { putstore('nightMode', '1'); }   // 1º acesso ou "padrão do navegador": escuro
    setNightMode();
    syncPanelClass();
    observeTheme();
  }

  // ── Login ─────────────────────────────────────────────────────────────────────
  function buildLogin() {
    var cell = $('logincell'), panel = $('loginpanel');
    if (!cell || !panel || $('rtLoginCard')) return !!$('rtLoginCard');
    document.documentElement.classList.add('rt-login');
    applyLoginTheme();
    var card = el('div', { id: 'rtLoginCard', class: 'rt-login-card' });
    var band = el('div', { class: 'rt-login-band' });
    var pic = $('loginPicture');
    if (pic) band.appendChild(pic);
    band.appendChild(el('div', { class: 'rt-login-badge', 'aria-hidden': 'true' }, ICON.remote));
    var body = el('div', { class: 'rt-login-body' });
    body.appendChild(el('div', { class: 'rt-eyebrow' }, 'Acesso · Remoto'));
    body.appendChild(el('h1', { class: 'rt-login-title' }, 'Entrar no Acesso Remoto'));
    body.appendChild(el('p', { class: 'rt-login-sub' }, 'Use sua conta corporativa Google.'));
    card.appendChild(band);
    card.appendChild(body);
    cell.insertBefore(card, cell.firstChild);
    body.appendChild(panel);
    // demais painéis do login2 (2FA, troca de senha...) entram no mesmo cartão
    Array.prototype.slice.call(cell.children).forEach(function (c) { if (c !== card && /panel$/.test(c.id || '')) card.appendChild(c); });
    var g = $('auth-google');
    if (g) { g.classList.add('rt-sso'); g.innerHTML = ICON.google + '<span>Entrar com Google</span>'; g.setAttribute('aria-label', 'Entrar com Google'); }
    body.appendChild(el('div', { class: 'rt-login-foot' }, ICON.lock + '<span>Acesso restrito à equipe de TI. Sessões são registradas.</span>'));
    var t = themeToggle(); t.classList.add('rt-login-toggle'); document.body.appendChild(t);
    return true;
  }

  // ── Painel: barra superior ──────────────────────────────────────────────────────
  function liveState() {
    var on = (typeof meshserver !== 'undefined' && meshserver && meshserver.State === 2);
    return on;
  }
  function buildTopbar() {
    var right = document.querySelector('#masthead .masthead-right'), left = document.querySelector('#masthead .masthead-left');
    if (!right || !left || $('rtTopTools')) return !!$('rtTopTools');
    var chip = el('span', { id: 'rtLive', class: 'rt-chip rt-live-chip' }, '<i class="rt-dot"></i><span>conectando</span>');
    left.appendChild(chip);
    var tools = el('div', { id: 'rtTopTools', class: 'rt-top-tools' });
    var search = el('label', { class: 'rt-search', title: 'Busca pelo nome da máquina ou pelo usuário logado nela' },
      ICON.search + '<input id="rtSearch" type="search" autocomplete="off" spellcheck="false" placeholder="Buscar máquina ou pessoa…" aria-label="Buscar máquina ou pessoa">' +
      '<span class="rt-kbd" aria-hidden="true"><kbd>Ctrl</kbd><kbd>K</kbd></span>');
    tools.appendChild(search);
    tools.appendChild(themeToggle());
    var menu = right.querySelector('.user-menu-container') || right.firstChild;
    right.insertBefore(tools, menu);

    var inp = $('rtSearch');
    inp.addEventListener('focus', function () { if (typeof onSearchFocus === 'function') onSearchFocus(1); });
    inp.addEventListener('blur', function () { if (typeof onSearchFocus === 'function') onSearchFocus(0); });
    inp.addEventListener('input', function () {
      var v = inp.value.trim(), si = $('SearchInput');
      if (!si) return;
      if (typeof go === 'function' && $('p1') && $('p1').style.display === 'none') go(1);
      // nome da máquina OU usuário logado (filtro nativo: "u:"). A vírgula é o "ou" do filtro em
      // qualquer idioma; a palavra "or" é traduzida pelo MeshCentral (em pt-BR vira "o") e não funciona.
      si.value = v ? (/[:,]/.test(v) ? v : v + ',u:' + v) : '';
      si.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true }));
    });
    inp.addEventListener('keydown', function (e) { if (e.key === 'Escape') { inp.value = ''; inp.dispatchEvent(new Event('input')); inp.blur(); } });
    document.addEventListener('keydown', function (e) {
      if ((e.ctrlKey || e.metaKey) && (e.key === 'k' || e.key === 'K')) { e.preventDefault(); e.stopPropagation(); inp.focus(); inp.select(); }
    }, true);
    return true;
  }
  function paintLive() {
    var c = $('rtLive'); if (!c) return;
    var on = liveState();
    c.classList.toggle('ok', on);
    c.querySelector('.rt-dot').className = 'rt-dot ' + (on ? 'ok' : 'warn');
    c.querySelector('span').textContent = on ? 'ao vivo' : 'reconectando';
  }

  // ── Painel: saudação com contadores ─────────────────────────────────────────────
  function firstName() {
    var u = (typeof userinfo !== 'undefined' && userinfo) ? (userinfo.realname || userinfo.name || '') : '';
    u = String(u).split('@')[0].trim().split(/[\s._-]+/)[0] || '';
    return u ? u.charAt(0).toUpperCase() + u.slice(1) : '';
  }
  function greeting() { var h = new Date().getHours(); return h < 12 ? 'Bom dia' : (h < 18 ? 'Boa tarde' : 'Boa noite'); }
  function buildHero() {
    var p1 = $('p1');
    if (!p1 || $('rtHero')) return !!$('rtHero');
    var hero = el('section', { id: 'rtHero', 'aria-label': 'Resumo' },
      '<h1 id="rtHeroTitle"></h1><p>Acesse e dê suporte às máquinas, direto do navegador.</p>' +
      '<div class="rt-chips"><span class="rt-chip" id="rtOnline"><i class="rt-dot ok"></i><b>0</b> online</span>' +
      '<span class="rt-chip" id="rtTotal"><i class="rt-dot primary"></i><b>0</b> dispositivos</span>' +
      '<span class="rt-chip" id="rtOffline"><i class="rt-dot"></i><b>0</b> offline</span>' +
      '<span class="rt-chip" id="rtGroups"><b>0</b> grupos</span></div>');
    p1.insertBefore(hero, p1.firstChild);
    return true;
  }
  function paintHero() {
    if (!$('rtHero')) return;
    var n = firstName();
    $('rtHeroTitle').textContent = greeting() + (n ? ', ' + n + '.' : '.');
    var list = (typeof nodes !== 'undefined' && nodes) ? nodes : [];
    var online = 0; for (var i = 0; i < list.length; i++) { if (list[i] && (list[i].conn & 1)) online++; }
    var groups = (typeof meshes !== 'undefined' && meshes) ? Object.keys(meshes).length : 0;
    $('rtOnline').querySelector('b').textContent = online;
    $('rtTotal').querySelector('b').textContent = list.length;
    $('rtOffline').querySelector('b').textContent = list.length - online;
    $('rtGroups').querySelector('b').textContent = groups;
    $('rtTotal').lastChild.textContent = list.length === 1 ? ' dispositivo' : ' dispositivos';
    $('rtGroups').lastChild.textContent = groups === 1 ? ' grupo' : ' grupos';
  }

  // ── Painel: botão Atualizar ─────────────────────────────────────────────────────
  function buildRefresh() {
    var bar = $('devListToolbar');
    if (!bar || $('rtRefreshButton')) return !!bar;
    var b = el('button', { id: 'rtRefreshButton', type: 'button', class: 'btn btn-secondary btn-sm me-1', title: 'Atualizar a lista de dispositivos' },
      '<span class="rt-refresh-icon" aria-hidden="true">&#x21BB;</span> Atualizar');
    b.addEventListener('click', function () {
      if (typeof meshserver === 'undefined' || !meshserver) return;
      b.disabled = true; b.classList.add('rt-girando');
      try {
        var skip = (typeof devicePagingState !== 'undefined' && devicePagingState) ? devicePagingState.skip : 0;
        meshserver.send({ action: 'meshes' });
        meshserver.send({ action: 'nodes', skip: skip });
      } catch (e) { }
      setTimeout(function () { b.disabled = false; b.classList.remove('rt-girando'); }, 1200);
    });
    bar.insertBefore(b, bar.firstChild);
    return true;
  }

  // ── Acesso remoto: escolher a tela ──────────────────────────────────────────────
  // O agente informa as telas como { 65535: "All Displays", 1: "Display 1", 2: "Display 2" }.
  // Com mais de um monitor, a conexão abre na tela escolhida da última vez naquela máquina
  // (padrão: Tela 1) e a barra do acesso remoto ganha "Tela 1 · Tela 2 · Todas".
  var ALL_DISPLAYS = 65535;
  var dispSession = null;   // desktop.m da conexão atual
  var dispCur = null;       // tela pedida nesta conexão (o agente não reenvia a lista ao trocar)
  var dispResend = null;    // reenvio único logo após conectar (o agente às vezes ignora o 1º pedido)
  function dispKey() { return (typeof currentNode !== 'undefined' && currentNode && currentNode._id) ? 'rtTela:' + currentNode._id : null; }
  function dispPref() { try { var k = dispKey(); return k ? localStorage.getItem(k) : null; } catch (e) { return null; } }
  function dispSave(v) { try { var k = dispKey(); if (k) localStorage.setItem(k, String(v)); } catch (e) { } }
  function dispScreens(displays) {
    return Object.keys(displays || {}).map(Number).filter(function (k) { return k !== ALL_DISPLAYS; }).sort(function (a, b) { return a - b; });
  }
  function renderDisplays(displays, sel) {
    var anchor = $('deskstatus'), host = $('rtDisplays');
    if (!host) {
      if (!anchor) return;
      host = el('div', { id: 'rtDisplays', class: 'rt-displays', role: 'group', 'aria-label': 'Escolher a tela' });
      anchor.parentNode.insertBefore(host, anchor);
      host.addEventListener('click', function (e) {
        var b = e.target.closest('button[data-tela]');
        if (b && typeof deskSetDisplay === 'function') deskSetDisplay(parseInt(b.getAttribute('data-tela'), 10));
      });
    }
    var telas = dispScreens(displays);
    if (telas.length < 2) { host.style.display = 'none'; host.innerHTML = ''; return; }
    var html = '<span class="rt-displays-label">Tela</span>';
    telas.forEach(function (k) { html += '<button type="button" data-tela="' + k + '" title="Ver só a tela ' + k + '">' + k + '</button>'; });
    if (ALL_DISPLAYS in displays) html += '<button type="button" data-tela="' + ALL_DISPLAYS + '" title="Ver todas as telas juntas">Todas</button>';
    host.innerHTML = html;
    host.style.display = '';
    markDisplay(sel);
  }
  function markDisplay(sel) {
    var host = $('rtDisplays'); if (!host) return;
    host.querySelectorAll('button[data-tela]').forEach(function (b) { b.setAttribute('aria-pressed', String(parseInt(b.getAttribute('data-tela'), 10) === sel)); });
  }
  function onDisplays(sender, displays, sel) {
    var telas = dispScreens(displays);
    var d = (typeof desktop !== 'undefined') ? desktop : null;
    var pronta = !(d && d.m === sender && d.State !== 3);   // antes de conectar, o agente ignora a troca
    if (sender && sender !== dispSession && pronta && telas.length) {   // 1ª lista de telas desta conexão
      dispSession = sender; dispCur = sel; dispResend = null;
      if (telas.length > 1) {
        var p = parseInt(dispPref(), 10);
        if (!(p in displays)) p = telas[0];
        if (p !== sel && typeof deskSetDisplay === 'function') {
          deskSetDisplay(p);
          dispResend = { m: sender, v: p, em: Date.now() + 2500 };
        }
      }
    }
    var mostrar = (sender === dispSession && dispCur != null && dispCur in displays) ? dispCur : sel;
    renderDisplays(displays, mostrar);
  }
  function hookDisplays() {
    if (typeof window.deskDisplayInfo === 'function' && !window.deskDisplayInfo.rtHook) {
      var origInfo = window.deskDisplayInfo;
      var info = function (sender, displays, sel) {
        var r = origInfo.apply(this, arguments);
        safe(function () { onDisplays(sender, displays, sel); });
        return r;
      };
      info.rtHook = true; window.deskDisplayInfo = info;
    }
    if (typeof window.deskSetDisplay === 'function' && !window.deskSetDisplay.rtHook) {
      var origSet = window.deskSetDisplay;
      var set = function (v) {
        var r = origSet.apply(this, arguments);
        safe(function () {
          var n = parseInt(v, 10);
          if (typeof desktop !== 'undefined' && desktop && desktop.m === dispSession) dispCur = n;
          dispSave(n); markDisplay(n);
        });
        return r;
      };
      set.rtHook = true; window.deskSetDisplay = set;
    }
  }
  function watchDesktop() {
    // Na 1ª conexão a lista de telas chega antes de o MeshCentral ligar o onDisplayinfo,
    // então a sessão é acompanhada aqui também.
    var d = (typeof desktop !== 'undefined') ? desktop : null;
    if (d && d.m && d.m.displays && d.m !== dispSession && d.State === 3) onDisplays(d.m, d.m.displays, d.m.selectedDisplay);
    var r = dispResend;
    if (r && d && d.m === r.m && d.State === 3 && Date.now() >= r.em) {
      dispResend = null;
      if (dispCur === r.v && typeof deskSetDisplay === 'function') deskSetDisplay(r.v);
    }
    var host = $('rtDisplays');
    if (host && (!d || !d.m)) host.style.display = 'none';   // desconectou
    fitDesktop();
  }
  // Altura da área do desktop = espaço que sobra até o rodapé (vai para --rt-desk-h no CSS).
  var deskH = null;
  function fitDesktop() {
    var area = $('deskarea3x'), card = $('p11');
    if (!area || !card || card.style.display === 'none' || !area.offsetParent || document.body.classList.contains('fulldesk')) return;
    var foot = $('deskarea4'), rodape = $('footer'), cs = getComputedStyle(card);
    // o rodapé é fixo (offsetParent nulo): o limite é o topo dele na tela
    var rr = rodape ? rodape.getBoundingClientRect() : null;
    var limite = (rr && rr.height > 0 && rr.top < window.innerHeight) ? rr.top : window.innerHeight;
    var abaixo = (foot ? foot.offsetHeight : 0) + parseFloat(cs.paddingBottom || 0) + parseFloat(cs.borderBottomWidth || 0) + 12;
    var h = Math.max(240, Math.floor(limite - area.getBoundingClientRect().top - abaixo));
    if (h !== deskH) {
      deskH = h;
      document.documentElement.style.setProperty('--rt-desk-h', h + 'px');
      if (typeof deskAdjust === 'function') try { deskAdjust(); } catch (e) { }
    }
  }

  // ── Painel: barra lateral (recolhível, com nomes) e Meu Servidor ───────────────
  var NAV = { LeftMenuMyDevices: 'Dispositivos', LeftMenuMyAccount: 'Minha conta', LeftMenuMyEvents: 'Eventos',
    LeftMenuMyFiles: 'Arquivos', LeftMenuMyUsers: 'Usuários', LeftMenuMyServer: 'Servidor' };
  function navAberta() { try { return localStorage.getItem('rtNavAberta') !== '0'; } catch (e) { return true; } }   // padrão: aberta
  function setNav(aberta, salvar) {
    document.documentElement.classList.toggle('rt-nav-aberta', aberta);
    var b = $('rtNavToggle');
    if (b) {
      b.setAttribute('aria-expanded', String(aberta));
      b.title = aberta ? 'Recolher menu' : 'Expandir menu';
      b.querySelector('span').textContent = aberta ? 'Recolher' : 'Expandir';
    }
    if (salvar) { try { localStorage.setItem('rtNavAberta', aberta ? '1' : '0'); } catch (e) { } }
    // o MeshCentral recalcula larguras (lista, desktop) no resize
    setTimeout(function () { try { window.dispatchEvent(new Event('resize')); } catch (e) { } deskH = null; }, 230);
  }
  function buildNav() {
    var bar = $('page_leftbar');
    if (!bar || $('rtNavToggle')) return;
    var head = el('div', { class: 'rt-nav-head' });
    var b = el('button', { id: 'rtNavToggle', type: 'button', 'aria-controls': 'page_leftbar' }, ICON.panel + '<span></span>');
    b.addEventListener('click', function () { setNav(!document.documentElement.classList.contains('rt-nav-aberta'), true); });
    head.appendChild(b);
    var spacer = bar.firstElementChild;
    if (spacer && spacer.tagName === 'DIV' && !spacer.className) spacer.style.display = 'none';
    bar.insertBefore(head, bar.firstChild);
    setNav(navAberta(), false);
  }
  // Nas páginas de um dispositivo (Área de Trabalho, Terminal...) o MeshCentral não marca nenhum
  // item da barra lateral: deduz a seção pela página atual (mesma regra do go() dele).
  function syncNavSel() {
    var links = document.querySelectorAll('#page_leftbar .nav-link'), nativo = false;
    links.forEach(function (a) { if (/\blbbuttonsel2?\b/.test(a.className)) nativo = true; });
    var v = (typeof xxcurrentView !== 'undefined') ? xxcurrentView : -1, id = null;
    if (!nativo) {
      if (v === 1 || (v >= 9 && v < 20)) id = 'LeftMenuMyDevices';
      else if (v === 2 || (v >= 20 && v < 30)) id = 'LeftMenuMyAccount';
      else if (v === 3 || (v >= 30 && v < 40)) id = 'LeftMenuMyEvents';
      else if (v === 4 || (v >= 40 && v < 50)) id = 'LeftMenuMyUsers';
      else if (v === 5 || (v >= 50 && v < 60)) id = 'LeftMenuMyFiles';
      else if (v === 6 || (v >= 60 && v < 70) || v === 115) id = 'LeftMenuMyServer';
    }
    links.forEach(function (a) { a.classList.toggle('rt-nav-sel', a.id === id); });
  }
  function decoratePanel() {
    Object.keys(NAV).forEach(function (id) {
      var a = $(id);
      if (a && !a.getAttribute('data-rt-label')) { a.title = NAV[id]; a.setAttribute('aria-label', NAV[id]); a.setAttribute('data-rt-label', NAV[id]); }
    });
    buildNav();
    var t = $('p6title');
    if (t && !t.querySelector('.rt-tile')) t.appendChild(el('div', { class: 'rt-tile rt-tile-lg', 'aria-hidden': 'true' }));
  }

  // ── Inicialização ───────────────────────────────────────────────────────────────
  if (!isPanel()) applyLoginTheme();   // evita "piscar" claro antes do cartão montar
  if (navAberta()) document.documentElement.classList.add('rt-nav-aberta');   // evita o menu "pular" ao carregar
  var tries = 0, done = { login: false, panel: false };
  var t = setInterval(function () {
    tries++;
    safe(function () {
      if ($('logincell') && !done.login) done.login = buildLogin();
      if (isPanel() && $('masthead') && !done.panel) {
        initPanelTheme();
        var ok = buildTopbar(); buildHero(); buildRefresh(); hookDisplays(); decoratePanel();
        done.panel = ok;
      }
    });
    if ((done.login || done.panel) || tries > 60) {
      clearInterval(t);
      if (done.panel) {
        setInterval(function () { safe(function () { buildHero(); buildRefresh(); hookDisplays(); decoratePanel(); paintHero(); paintLive(); }); }, 2000);
        setInterval(function () { safe(watchDesktop); safe(syncNavSel); }, 400);
        window.addEventListener('resize', function () { deskH = null; safe(fitDesktop); });
        safe(function () { paintHero(); paintLive(); });
      }
    }
  }, 200);
})();
