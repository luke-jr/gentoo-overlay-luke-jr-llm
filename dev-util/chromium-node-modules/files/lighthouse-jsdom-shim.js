// Minimal stand-in for jsdom 12, enough for Lighthouse's
// build/build-report-components.js: parse templates.html with parse5 5.x (the
// parser jsdom 12 uses) and expose the few DOM APIs that script reads.
'use strict';

const parse5 = require('parse5');

const HTML_NS = 'http://www.w3.org/1999/xhtml';
const wrappers = new WeakMap();

class Node {
  constructor(raw) {
    this._raw = raw;
  }
  get parentNode() {
    return this._raw.parentNode ? wrap(this._raw.parentNode) : null;
  }
  get parentElement() {
    const p = this.parentNode;
    return p instanceof Element ? p : null;
  }
  get childNodes() {
    return (this._raw.childNodes || []).map(wrap);
  }
  get children() {
    return this.childNodes.filter(n => n instanceof Element);
  }
  get textContent() {
    if (this._raw.nodeName === '#text') return this._raw.value;
    if (this._raw.nodeName === '#comment') return this._raw.data;
    return this.childNodes.filter(n => !(n instanceof Comment)).map(n => n.textContent).join('');
  }
  set textContent(value) {
    for (const c of this._raw.childNodes) c.parentNode = null;
    this._raw.childNodes = [];
    if (value) append(this._raw, {nodeName: '#text', value: String(value), parentNode: null});
  }
  append(...nodes) {
    for (const n of nodes) {
      append(this._raw, typeof n === 'string' ? {nodeName: '#text', value: n, parentNode: null} : n._raw);
    }
  }
}
Node.ELEMENT_NODE = 1;
Node.TEXT_NODE = 3;
Node.COMMENT_NODE = 8;
Node.DOCUMENT_NODE = 9;
Node.DOCUMENT_FRAGMENT_NODE = 11;

class Element extends Node {
  get nodeType() {
    return Node.ELEMENT_NODE;
  }
  get namespaceURI() {
    return this._raw.namespaceURI;
  }
  get localName() {
    return this._raw.tagName;
  }
  get tagName() {
    return this._raw.namespaceURI === HTML_NS ? this._raw.tagName.toUpperCase() : this._raw.tagName;
  }
  get id() {
    return this.getAttribute('id') || '';
  }
  set id(value) {
    this.setAttribute('id', value);
  }
  get classList() {
    const el = this;
    return {toString: () => el.getAttribute('class') || ''};
  }
  get content() {
    return this._raw.content ? wrap(this._raw.content) : undefined;
  }
  getAttributeNames() {
    return this._raw.attrs.map(a => a.prefix ? `${a.prefix}:${a.name}` : a.name);
  }
  getAttribute(name) {
    const attr = this._raw.attrs.find(a => (a.prefix ? `${a.prefix}:${a.name}` : a.name) === name);
    return attr ? attr.value : null;
  }
  setAttribute(name, value) {
    const attr = this._raw.attrs.find(a => a.name === name);
    if (attr) attr.value = String(value);
    else this._raw.attrs.push({name, value: String(value)});
  }
}

class Text extends Node {
  get nodeType() {
    return Node.TEXT_NODE;
  }
}

class Comment extends Node {
  get nodeType() {
    return Node.COMMENT_NODE;
  }
}

class DocumentFragment extends Node {
  get nodeType() {
    return Node.DOCUMENT_FRAGMENT_NODE;
  }
}

class Document extends Node {
  get nodeType() {
    return Node.DOCUMENT_NODE;
  }
  createElement(tagName) {
    const raw = {nodeName: tagName, tagName, attrs: [], namespaceURI: HTML_NS, childNodes: [], parentNode: null};
    if (tagName === 'template') {
      raw.content = {nodeName: '#document-fragment', childNodes: []};
    }
    return wrap(raw);
  }
  // Only plain tag-name selectors are needed. Like the DOM, this doesn't look
  // into template contents.
  querySelectorAll(tagName) {
    const out = [];
    const walk = raw => {
      for (const c of raw.childNodes || []) {
        if (c.tagName === tagName) out.push(wrap(c));
        walk(c);
      }
    };
    walk(this._raw);
    return out;
  }
}

function append(parentRaw, childRaw) {
  if (childRaw.parentNode) {
    const siblings = childRaw.parentNode.childNodes;
    siblings.splice(siblings.indexOf(childRaw), 1);
  }
  parentRaw.childNodes.push(childRaw);
  childRaw.parentNode = parentRaw;
}

function wrap(raw) {
  let w = wrappers.get(raw);
  if (!w) {
    if (raw.nodeName === '#text') w = new Text(raw);
    else if (raw.nodeName === '#comment') w = new Comment(raw);
    else if (raw.nodeName === '#document') w = new Document(raw);
    else if (raw.nodeName === '#document-fragment') w = new DocumentFragment(raw);
    else if (raw.nodeName === '#documentType') w = new Node(raw);
    else w = new Element(raw);
    wrappers.set(raw, w);
  }
  return w;
}

class JSDOM {
  constructor(html) {
    const document = wrap(parse5.parse(html));
    this.window = {document, Node, Element, Text, Comment, DocumentFragment};
  }
}

module.exports = {JSDOM};
