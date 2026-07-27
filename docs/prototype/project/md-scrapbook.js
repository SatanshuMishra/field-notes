/* MarkdownScrapbook — a live-WYSIWYG markdown editor + freeform photo "scrapbook" layer.
   Framework-agnostic. Mounts imperatively into a container element.
   Used by the Field Notes capture prototypes; each option instantiates it with a theme config. */

if (typeof window === 'undefined' || !window.MarkdownScrapbook) {

var __uid = 0;
var clamp = (v, a, b) => Math.min(b, Math.max(a, v));

class MarkdownScrapbook {
  constructor(root, opts = {}) {
    this.root = root;
    this.o = Object.assign({
      lined: false,
      ink: '#4a3b2e',
      accent: '#c76a54',
      paper: '#fbf3e4',
      muted: '#a08a70',
      font: "'Newsreader', Georgia, serif",
      photoStyle: 'tape',       // 'tape' | 'polaroid' | 'plain'
      placeholder: 'Start writing…  Try “# ”, “- ”, “1. ” or “> ”',
      seed: null,               // {blocks:[{type,text}], photos:[{x,y,w,rot,cap}]}
      onChange: null,
    }, opts);
    this.id = 'ms' + (++__uid);
    this.zTop = 10;
    this._build();
  }

  _build() {
    const o = this.o;
    const r = this.root;
    r.innerHTML = '';
    r.style.position = 'relative';
    r.style.overflow = 'hidden';
    r.dataset.msid = this.id;

    this._injectStyle();

    // scroll host
    const scroll = document.createElement('div');
    scroll.className = 'ms-scroll';
    scroll.style.cssText = 'position:absolute;inset:0;overflow-y:auto;overflow-x:hidden;';
    r.appendChild(scroll);
    this.scroll = scroll;

    // page (writing surface)
    const page = document.createElement('div');
    page.className = 'ms-page';
    page.style.background = o.paper;
    if (o.lined) {
      page.style.backgroundImage =
        'repeating-linear-gradient(transparent,transparent 37px,' + this._alpha(o.ink, .13) + ' 37px,' + this._alpha(o.ink, .13) + ' 38px)';
      page.style.backgroundPosition = '0 ' + (o.linedTop || 46) + 'px';
    }
    scroll.appendChild(page);
    this.page = page;

    // photo layer (over text; only photos catch pointer)
    const layer = document.createElement('div');
    layer.className = 'ms-layer';
    layer.style.cssText = 'position:absolute;inset:0;pointer-events:none;';
    page.appendChild(layer);
    this.layer = layer;

    // editor
    const ed = document.createElement('div');
    ed.className = 'ms-editor';
    ed.contentEditable = 'true';
    ed.spellcheck = false;
    ed.style.fontFamily = o.font;
    ed.style.color = o.ink;
    page.appendChild(ed);
    this.editor = ed;

    // placeholder
    const ph = document.createElement('div');
    ph.className = 'ms-ph';
    ph.textContent = o.placeholder;
    ph.style.color = this._alpha(o.ink, .34);
    ph.style.fontFamily = o.font;
    page.appendChild(ph);
    this.phEl = ph;

    // floating inline toolbar
    const tb = document.createElement('div');
    tb.className = 'ms-tb';
    tb.innerHTML =
      '<button data-cmd="bold" title="Bold (⌘B)" style="font-weight:800">B</button>' +
      '<button data-cmd="italic" title="Italic (⌘I)" style="font-style:italic">I</button>' +
      '<button data-cmd="under" title="Underline" style="text-decoration:underline">U</button>' +
      '<button data-cmd="code" title="Mono">&lt;&gt;</button>' +
      '<button data-cmd="hilite" title="Highlight">◆</button>';
    r.appendChild(tb);
    this.tb = tb;

    this._wire();
    this._seed();
    this._refreshPh();
  }

  _injectStyle() {
    const o = this.o;
    const sel = '[data-msid="' + this.id + '"]';
    if (document.getElementById(this.id + '-style')) return;
    const s = document.createElement('style');
    s.id = this.id + '-style';
    s.textContent = `
${sel} .ms-page{position:relative;min-height:100%;padding:44px 54px 120px;}
${sel} .ms-editor{position:relative;z-index:2;outline:none;font-size:19px;line-height:38px;min-height:60px;}
${sel} .ms-editor *{outline:none;}
${sel} .ms-ph{position:absolute;top:44px;left:54px;z-index:1;font-size:19px;line-height:38px;pointer-events:none;font-style:italic;}
${sel} .ms-editor>div{margin:0;min-height:38px;}
${sel} .ms-editor [data-type=h1]{font-weight:600;font-size:34px;line-height:44px;letter-spacing:-.01em;margin:8px 0 2px;}
${sel} .ms-editor [data-type=h2]{font-weight:600;font-size:26px;line-height:38px;margin:6px 0 0;}
${sel} .ms-editor [data-type=h3]{font-weight:600;font-size:21px;line-height:34px;color:${this._alpha(o.ink,.82)};}
${sel} .ms-editor [data-type=quote]{padding-left:20px;border-left:3px solid ${o.accent};color:${this._alpha(o.ink,.72)};font-style:italic;margin:6px 0;}
${sel} .ms-editor [data-type=bullet]{padding-left:30px;position:relative;}
${sel} .ms-editor [data-type=bullet]::before{content:'';position:absolute;left:10px;top:16px;width:7px;height:7px;border-radius:50%;background:${o.accent};}
${sel} .ms-editor [data-type=number]{padding-left:34px;position:relative;}
${sel} .ms-editor [data-type=number]::before{content:attr(data-num) '.';position:absolute;left:4px;top:0;font-weight:600;color:${o.accent};min-width:24px;text-align:right;}
${sel} .ms-editor [data-type=todo]{padding-left:34px;position:relative;}
${sel} .ms-editor [data-type=todo]::before{content:'';position:absolute;left:8px;top:9px;width:18px;height:18px;border-radius:5px;border:2px solid ${this._alpha(o.ink,.4)};background:transparent;cursor:pointer;}
${sel} .ms-editor [data-type=todo][data-done="1"]::before{background:${o.accent};border-color:${o.accent};}
${sel} .ms-editor [data-type=todo][data-done="1"]::after{content:'✓';position:absolute;left:11px;top:6px;font-size:13px;font-weight:800;color:#fff;pointer-events:none;}
${sel} .ms-editor [data-type=todo][data-done="1"]{color:${this._alpha(o.ink,.42)};text-decoration:line-through;}
${sel} .ms-editor [data-type=divider]{height:0;border:none;border-top:2px dotted ${this._alpha(o.ink,.34)};margin:20px 0;padding:0;pointer-events:none;}
${sel} .ms-editor code, ${sel} .ms-editor .ms-code{font-family:ui-monospace,Menlo,monospace;font-size:.86em;background:${this._alpha(o.ink,.08)};border:1px solid ${this._alpha(o.ink,.12)};border-radius:5px;padding:1px 5px;}
${sel} .ms-editor mark{background:${this._alpha(o.accent,.28)};color:inherit;border-radius:3px;padding:0 2px;}
${sel} .ms-tb{position:absolute;z-index:60;display:none;gap:2px;padding:5px;background:#2a241d;border-radius:11px;box-shadow:0 10px 26px -8px rgba(0,0,0,.55);transform:translate(-50%,-118%);}
${sel} .ms-tb button{all:unset;cursor:pointer;color:#f3e9d8;width:30px;height:30px;display:flex;align-items:center;justify-content:center;font-size:14px;border-radius:7px;font-family:${o.font};}
${sel} .ms-tb button:hover{background:rgba(255,255,255,.14);}
${sel} .ms-photo{position:absolute;pointer-events:auto;cursor:grab;touch-action:none;user-select:none;}
${sel} .ms-photo.sel{cursor:grabbing;}
${sel} .ms-fill{width:100%;height:100%;background-image:repeating-linear-gradient(135deg,${this._alpha(o.ink,.10)} 0 11px,${this._alpha(o.ink,.04)} 11px 22px);background-color:${this._alpha(o.accent,.10)};display:flex;align-items:center;justify-content:center;}
${sel} .ms-fill span{font:600 10px 'Instrument Sans',sans-serif;letter-spacing:.14em;text-transform:uppercase;color:${this._alpha(o.ink,.34)};}
${sel} .ms-handle{position:absolute;background:#fff;border:2px solid ${o.accent};box-shadow:0 2px 6px rgba(0,0,0,.3);display:none;}
${sel} .ms-photo.sel .ms-handle{display:block;}
${sel} .ms-rot{width:16px;height:16px;border-radius:50%;left:50%;top:-34px;transform:translateX(-50%);cursor:grab;}
${sel} .ms-rot::after{content:'';position:absolute;left:50%;top:16px;width:2px;height:18px;background:${o.accent};transform:translateX(-50%);}
${sel} .ms-res{width:15px;height:15px;border-radius:4px;right:-9px;bottom:-9px;cursor:nwse-resize;}
${sel} .ms-del{position:absolute;right:-11px;top:-11px;width:24px;height:24px;border-radius:50%;background:#2a241d;color:#fff;border:none;cursor:pointer;display:none;align-items:center;justify-content:center;font-size:15px;line-height:1;z-index:3;}
${sel} .ms-photo.sel .ms-del{display:flex;}
${sel} .ms-cap{font:500 13px 'Caveat',cursive;color:${this._alpha(o.ink,.7)};text-align:center;padding:4px 6px 2px;outline:none;min-height:20px;}
${sel} .ms-scroll::-webkit-scrollbar{width:9px;}
${sel} .ms-scroll::-webkit-scrollbar-thumb{background:${this._alpha(o.ink,.22)};border-radius:6px;border:2px solid transparent;background-clip:padding-box;}
`;
    document.head.appendChild(s);
  }

  /* ---------------- markdown editing ---------------- */
  _wire() {
    const ed = this.editor;
    ed.addEventListener('input', () => { this._transform(); this._renumber(); this._refreshPh(); this._emit(); });
    ed.addEventListener('keydown', e => this._keydown(e));
    ed.addEventListener('click', e => this._edClick(e));
    document.addEventListener('selectionchange', () => this._selChange());
    this.tb.addEventListener('mousedown', e => { e.preventDefault(); });
    this.tb.addEventListener('click', e => {
      const b = e.target.closest('button'); if (!b) return; this._cmd(b.dataset.cmd);
    });
  }

  _blocks() { return [...this.editor.children].filter(n => n.nodeType === 1); }

  _curBlock() {
    const sel = getSelection();
    if (!sel.rangeCount) return null;
    let n = sel.anchorNode;
    if (n === this.editor) return this.editor.children[Math.min(sel.anchorOffset, this.editor.children.length - 1)] || null;
    while (n && n.parentNode !== this.editor) n = n.parentNode;
    return (n && n.nodeType === 1) ? n : null;
  }

  _mkBlock(type, html) {
    const d = document.createElement('div');
    d.dataset.type = type || 'p';
    d.innerHTML = (html && html.trim() !== '') ? html : '<br>';
    return d;
  }

  _caretTo(el, atStart) {
    const r = document.createRange(), sel = getSelection();
    r.selectNodeContents(el); r.collapse(!!atStart);
    sel.removeAllRanges(); sel.addRange(r);
  }

  _caretOffset0(b) {
    const sel = getSelection();
    if (!sel.rangeCount || !sel.isCollapsed) return false;
    const r = sel.getRangeAt(0).cloneRange();
    r.selectNodeContents(b); r.setEnd(sel.anchorNode, sel.anchorOffset);
    return r.toString().length === 0;
  }

  _transform() {
    const b = this._curBlock();
    if (!b || (b.dataset.type && b.dataset.type !== 'p')) return;
    const txt = b.textContent;
    const m = txt.match(/^(#{1,3}|-|\*|\+|>|\d+\.|\[\]|\[ \]|---|\*\*\*)\s$/) ||
              txt.match(/^(#{1,3}|-|\*|\+|>|\d+\.|\[\]|\[ \])\s/);
    if (!m) return;
    const tok = m[1];
    let type = 'p';
    if (tok === '#') type = 'h1';
    else if (tok === '##') type = 'h2';
    else if (tok === '###') type = 'h3';
    else if (tok === '-' || tok === '*' || tok === '+') type = 'bullet';
    else if (tok === '>') type = 'quote';
    else if (/^\d+\.$/.test(tok)) type = 'number';
    else if (tok === '[]' || tok === '[ ]') type = 'todo';
    else if (tok === '---' || tok === '***') type = 'divider';
    const rest = txt.slice(m[0].length);
    if (type === 'divider') {
      b.dataset.type = 'divider'; b.contentEditable = 'false'; b.innerHTML = '';
      const nb = this._mkBlock('p', ''); b.after(nb); this._caretTo(nb, true); return;
    }
    b.dataset.type = type;
    b.innerHTML = rest && rest.length ? rest : '<br>';
    this._caretTo(b, true);
  }

  _keydown(e) {
    if ((e.metaKey || e.ctrlKey) && !e.shiftKey) {
      const k = e.key.toLowerCase();
      if (k === 'b') { e.preventDefault(); this._cmd('bold'); return; }
      if (k === 'i') { e.preventDefault(); this._cmd('italic'); return; }
      if (k === 'u') { e.preventDefault(); this._cmd('under'); return; }
    }
    if (e.key === 'Enter' && !e.shiftKey) {
      const b = this._curBlock(); if (!b) return;
      const t = b.dataset.type || 'p';
      const listy = (t === 'bullet' || t === 'number' || t === 'todo');
      if (listy && b.textContent.trim() === '') {
        e.preventDefault(); b.dataset.type = 'p'; b.removeAttribute('data-done'); this._renumber(); return;
      }
      e.preventDefault();
      this._splitBlock(b, listy ? t : 'p');
      this._renumber(); this._refreshPh(); this._emit();
      return;
    }
    if (e.key === 'Backspace') {
      const b = this._curBlock();
      if (b && (b.dataset.type && b.dataset.type !== 'p') && this._caretOffset0(b)) {
        e.preventDefault(); b.dataset.type = 'p'; b.removeAttribute('data-done'); this._renumber(); this._emit(); return;
      }
    }
  }

  _splitBlock(b, newType) {
    const sel = getSelection(); const r = sel.getRangeAt(0);
    const tail = document.createRange();
    tail.setStart(r.endContainer, r.endOffset);
    tail.setEndAfter(b.lastChild || b);
    const frag = tail.extractContents();
    const nb = this._mkBlock(newType, '');
    nb.innerHTML = '';
    nb.appendChild(frag);
    if (!nb.textContent.trim()) nb.innerHTML = '<br>';
    if (!b.textContent.trim()) b.innerHTML = '<br>';
    b.after(nb);
    this._caretTo(nb, true);
  }

  _renumber() {
    let n = 0;
    for (const b of this._blocks()) {
      if (b.dataset.type === 'number') { n += 1; b.dataset.num = n; }
      else n = 0;
    }
  }

  _edClick(e) {
    const b = e.target.closest('[data-type=todo]');
    if (b) {
      const rect = b.getBoundingClientRect();
      if (e.clientX - rect.left < 30) {
        b.dataset.done = b.dataset.done === '1' ? '0' : '1';
        this._emit();
      }
    }
  }

  /* ---------------- inline formatting ---------------- */
  _selChange() {
    const sel = getSelection();
    if (!sel.rangeCount || sel.isCollapsed || !this.editor.contains(sel.anchorNode)) { this.tb.style.display = 'none'; return; }
    const rect = sel.getRangeAt(0).getBoundingClientRect();
    const rootRect = this.root.getBoundingClientRect();
    if (!rect.width) { this.tb.style.display = 'none'; return; }
    this.tb.style.display = 'flex';
    this.tb.style.left = (rect.left - rootRect.left + rect.width / 2) + 'px';
    this.tb.style.top = (rect.top - rootRect.top) + 'px';
  }

  _cmd(cmd) {
    this.editor.focus();
    if (cmd === 'bold') document.execCommand('bold');
    else if (cmd === 'italic') document.execCommand('italic');
    else if (cmd === 'under') document.execCommand('underline');
    else if (cmd === 'hilite') this._wrapSel('mark');
    else if (cmd === 'code') this._wrapSel('code');
    this._emit();
  }

  _wrapSel(tag) {
    const sel = getSelection();
    if (!sel.rangeCount || sel.isCollapsed) return;
    const r = sel.getRangeAt(0);
    // toggle off if already fully wrapped
    const anc = sel.anchorNode.parentElement;
    if (anc && anc.tagName && anc.tagName.toLowerCase() === tag) {
      const parent = anc.parentNode;
      while (anc.firstChild) parent.insertBefore(anc.firstChild, anc);
      parent.removeChild(anc); return;
    }
    const el = document.createElement(tag);
    try { el.appendChild(r.extractContents()); r.insertNode(el); } catch (_) {}
    sel.removeAllRanges();
  }

  _refreshPh() {
    const empty = this.editor.textContent.trim() === '' && this.layer.children.length === 0;
    this.phEl.style.display = empty ? 'block' : 'none';
  }

  _emit() { if (this.o.onChange) this.o.onChange(); }

  /* ---------------- photos ---------------- */
  addPhoto(opt = {}) {
    const st = {
      x: opt.x != null ? opt.x : (this.scroll.clientWidth / 2 - 105 + (Math.random() * 40 - 20)),
      y: opt.y != null ? opt.y : (this.scroll.scrollTop + 90 + Math.random() * 60),
      w: opt.w || 210,
      h: opt.h || 168,
      rot: opt.rot != null ? opt.rot : (Math.random() * 8 - 4),
      cap: opt.cap || '',
    };
    const el = document.createElement('div');
    el.className = 'ms-photo';
    el.style.left = st.x + 'px';
    el.style.top = st.y + 'px';
    el.style.width = st.w + 'px';
    el.style.zIndex = (++this.zTop);
    el._st = st;
    el.appendChild(this._photoInner(st));
    el.insertAdjacentHTML('beforeend',
      '<div class="ms-handle ms-rot"></div><div class="ms-handle ms-res"></div>' +
      '<button class="ms-del" title="Remove">×</button>');
    this.layer.appendChild(el);
    this._applyPhoto(el);
    this._wirePhoto(el);
    this._select(el);
    this._refreshPh(); this._emit();
    return el;
  }

  _photoInner(st) {
    const style = this.o.photoStyle;
    const wrap = document.createElement('div');
    wrap.className = 'ms-frame';
    if (style === 'tape') {
      wrap.style.cssText = 'width:100%;height:100%;background:#fff;padding:8px;box-shadow:0 12px 26px -10px rgba(40,30,18,.55);position:relative;';
      wrap.innerHTML =
        '<div class="ms-tapepiece" style="position:absolute;top:-11px;left:16px;width:56px;height:22px;background:' + this._alpha('#d9c9a6', .82) + ';transform:rotate(-8deg);box-shadow:0 1px 3px rgba(0,0,0,.14)"></div>' +
        '<div class="ms-tapepiece" style="position:absolute;top:-9px;right:18px;width:52px;height:22px;background:' + this._alpha('#d9c9a6', .82) + ';transform:rotate(7deg);box-shadow:0 1px 3px rgba(0,0,0,.14)"></div>';
      const fill = document.createElement('div');
      fill.style.cssText = 'width:100%;height:calc(100% - 0px);';
      fill.innerHTML = '<div class="ms-fill" style="height:100%"><span>photo</span></div>';
      wrap.appendChild(fill);
    } else if (style === 'polaroid') {
      wrap.style.cssText = 'width:100%;height:100%;background:#fffdf8;padding:9px 9px 6px;box-shadow:0 14px 30px -12px rgba(40,30,18,.5);border-radius:2px;display:flex;flex-direction:column;';
      const fill = document.createElement('div');
      fill.style.cssText = 'flex:1;min-height:0;';
      fill.innerHTML = '<div class="ms-fill" style="height:100%"><span>photo</span></div>';
      const cap = document.createElement('div');
      cap.className = 'ms-cap'; cap.contentEditable = 'true'; cap.textContent = st.cap || '';
      cap.dataset.ph = 'caption…';
      wrap.appendChild(fill); wrap.appendChild(cap);
    } else {
      wrap.style.cssText = 'width:100%;height:100%;border-radius:12px;overflow:hidden;border:1px solid ' + this._alpha(this.o.ink, .18) + ';box-shadow:0 12px 26px -12px rgba(40,30,18,.45);';
      wrap.innerHTML = '<div class="ms-fill" style="height:100%"><span>photo</span></div>';
    }
    return wrap;
  }

  _applyPhoto(el) {
    const st = el._st;
    el.style.left = st.x + 'px';
    el.style.top = st.y + 'px';
    el.style.width = st.w + 'px';
    el.style.height = st.h + 'px';
    el.style.transform = 'rotate(' + st.rot + 'deg)';
  }

  _select(el) {
    this.layer.querySelectorAll('.ms-photo.sel').forEach(p => p.classList.remove('sel'));
    if (el) { el.classList.add('sel'); el.style.zIndex = (++this.zTop); }
  }

  _wirePhoto(el) {
    const st = el._st;
    const self = this;
    el.querySelector('.ms-del').addEventListener('pointerdown', e => { e.stopPropagation(); });
    el.querySelector('.ms-del').addEventListener('click', e => {
      e.stopPropagation(); el.remove(); self._refreshPh(); self._emit();
    });
    // caption editing shouldn't drag
    const cap = el.querySelector('.ms-cap');
    if (cap) cap.addEventListener('pointerdown', e => e.stopPropagation());

    const rot = el.querySelector('.ms-rot');
    const res = el.querySelector('.ms-res');

    el.addEventListener('pointerdown', e => {
      if (e.target === rot || e.target === res) return;
      e.preventDefault(); self._select(el);
      const sx = e.clientX, sy = e.clientY, ox = st.x, oy = st.y;
      const sc = self._scale();
      const move = ev => { st.x = ox + (ev.clientX - sx) / sc; st.y = oy + (ev.clientY - sy) / sc; self._applyPhoto(el); };
      const up = () => { document.removeEventListener('pointermove', move); document.removeEventListener('pointerup', up); self._emit(); };
      document.addEventListener('pointermove', move); document.addEventListener('pointerup', up);
    });

    rot.addEventListener('pointerdown', e => {
      e.preventDefault(); e.stopPropagation(); self._select(el);
      const rect = el.getBoundingClientRect();
      const cx = rect.left + rect.width / 2, cy = rect.top + rect.height / 2;
      const move = ev => {
        const a = Math.atan2(ev.clientY - cy, ev.clientX - cx) * 180 / Math.PI + 90;
        st.rot = Math.round(a); self._applyPhoto(el);
      };
      const up = () => { document.removeEventListener('pointermove', move); document.removeEventListener('pointerup', up); self._emit(); };
      document.addEventListener('pointermove', move); document.addEventListener('pointerup', up);
    });

    res.addEventListener('pointerdown', e => {
      e.preventDefault(); e.stopPropagation(); self._select(el);
      const sx = e.clientX, ow = st.w, oh = st.h, ratio = oh / ow, sc = self._scale();
      const move = ev => {
        const nw = clamp(ow + (ev.clientX - sx) / sc, 90, 620);
        st.w = nw; st.h = nw * ratio; self._applyPhoto(el);
      };
      const up = () => { document.removeEventListener('pointermove', move); document.removeEventListener('pointerup', up); self._emit(); };
      document.addEventListener('pointermove', move); document.addEventListener('pointerup', up);
    });
  }

  _scale() {
    // account for CSS transform:scale on any ancestor (device frames)
    const r = this.root.getBoundingClientRect();
    return (r.width / this.root.offsetWidth) || 1;
  }

  getText() { return this.editor.innerText.replace(/\n{3,}/g, '\n\n').trim(); }
  getHTML() { return this.editor.innerHTML; }
  photoCount() { return this.layer.children.length; }
  isEmpty() { return this.getText() === '' && this.photoCount() === 0; }

  _seed() {
    const s = this.o.seed;
    this.editor.innerHTML = '';
    if (s && s.html != null && s.html !== '') {
      this.editor.innerHTML = s.html;
      this._renumber();
      if (s.photos) requestAnimationFrame(() => { s.photos.forEach(p => this.addPhoto(p)); this._select(null); this._refreshPh(); });
      return;
    }
    if (s && s.blocks && s.blocks.length) {
      for (const b of s.blocks) {
        const el = this._mkBlock(b.type, b.text || '');
        if (b.done) el.dataset.done = '1';
        this.editor.appendChild(el);
      }
    } else {
      this.editor.appendChild(this._mkBlock('p', ''));
    }
    this._renumber();
    if (s && s.photos) {
      // defer so layout is ready for width math
      requestAnimationFrame(() => { s.photos.forEach(p => this.addPhoto(p)); this._select(null); this._refreshPh(); });
    }
  }

  clearSelection() { this._select(null); }

  destroy() {
    const st = document.getElementById(this.id + '-style');
    if (st) st.remove();
  }

  _alpha(hex, a) {
    const h = hex.replace('#', '');
    const n = h.length === 3 ? h.split('').map(c => c + c).join('') : h;
    const r = parseInt(n.slice(0, 2), 16), g = parseInt(n.slice(2, 4), 16), b = parseInt(n.slice(4, 6), 16);
    return 'rgba(' + r + ',' + g + ',' + b + ',' + a + ')';
  }
}

if (typeof window !== 'undefined') window.MarkdownScrapbook = MarkdownScrapbook;

}
