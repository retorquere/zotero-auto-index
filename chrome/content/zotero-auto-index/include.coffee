# Only create main object once
unless Zotero.AutoIndex
  loader = Components.classes["@mozilla.org/moz/jssubscript-loader;1"].getService(Components.interfaces.mozIJSSubScriptLoader)
  loader.loadSubScript "chrome://zotero-auto-index/content/zotero-auto-index.js"
