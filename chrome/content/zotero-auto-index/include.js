// Only create main object once
if (!Zotero.AutoIndex) {
	let loader = Components.classes["@mozilla.org/moz/jssubscript-loader;1"].getService(Components.interfaces.mozIJSSubScriptLoader);
	loader.loadSubScript("chrome://zotero-auto-index/content/fulltext.js");
	loader.loadSubScript("chrome://zotero-auto-index/content/zotero-auto-index.js");
}
