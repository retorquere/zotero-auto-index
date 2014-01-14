Zotero.AutoIndex = {
  prefs: Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService).getBranch("extensions.zotero-auto-index."),

  expandWordList: function(words) {
    let expanded = {};

    // stash words in a dictiionary to make them unique
    for (var word of words) {
      expanded[word.loLowerCase()] = true;
      word = Zotero.Utilities.removeDiacritics(word, false).toLowerCase();
      if (word.match(/^[\x20-\x7f]+$/)) { expanded[word] = true; }
    }

    return Object.keys(expanded);
  },

  log: function(msg, e) {
    if (!Zotero.AutoIndex.prefs.getBoolPref('debug')) { return; }
    msg = '[indexing] ' + msg;
    if (e) {
      msg += "\nan error occurred: " + e.name + ": " + e.message + " \n(" + e.fileName + ", " + e.lineNumber + ")";
      if (e.stack) { msg += "\n" + e.stack; }
    }
    Zotero.debug(msg);
    console.log(msg);
  },

  init: function () {
    // monkey-patch Zotero.Sync.Storage.Mode to cause uploaded/downloaded files to be marked for re-indexing
    Zotero.Sync.Storage.Mode.prototype.uploadFile = (function (self, original) {
      return function (request) {
        let result = original.apply(this, arguments);
        self.reindexRequest(request);
        return result;
      }
    })(this, Zotero.Sync.Storage.Mode.prototype.uploadFile);

    Zotero.Sync.Storage.Mode.prototype.downloadFile = (function (self, original) {
      return function (request) {
        let result = original.apply(this, arguments);
        self.reindexRequest(request);
        return result;
      }
    })(this, Zotero.Sync.Storage.Mode.prototype.downloadFile);

    // monkey-patch Zotero.Sync.Runner.stop to kick off full re-indexing
    Zotero.Sync.Runner.stop = (function (self, original) {
      return function (request) {
        let result = original.apply(this, arguments);
        self.update(1);
        return result;
      }
    })(this, Zotero.Sync.Runner.stop);

    // force all-pages indexing -- the replacement semanticSplitter is fast enough to handle it
    Zotero.Fulltext.indexFile = (function (self, original) {
      return function (file, mimeType, charset, itemID, maxLength, isCacheFile) {
        Zotero.AutoIndex.log('indexFile(' + file.path + ',' + mimeType + ',' + charset + ',' + itemID + ',' + maxLength + ',' + isCacheFile + ')');
        try {
          return original.apply(this, [file, mimeType, charset, itemID, true, isCacheFile]);
        } catch (err) {
          Zotero.AutoIndex.log('indexFile failed: ', err);
        }
      }
    })(this, Zotero.Fulltext.indexFile);

    // monkey-patch indexWords to add ASCII alternatives
    Zotero.Fulltext.indexWords = (function (self, original) {
      return function (itemID, words) {
        return original.apply(this, [itemID, self.expandWordList(words)]);
      }
    })(this, Zotero.Fulltext.indexWords);

    if (Zotero.AutoIndex.prefs.getBoolPref('zotfile.enabled')) {
      Zotero.ZotFile.pdfAnnotations.getNoteContent = (function (self, original) {
        return function (annotations, item, att, method) {
          return original.apply(this, arguments) + '<!-- ' + JSON.stringify({zotfile: {}}) + ' -->';
        }
      })(this, Zotero.ZotFile.pdfAnnotations.getNoteContent);
    }

    let notifierID = Zotero.Notifier.registerObserver(Zotero.AutoIndex.notifierCallback, ['item']);
    // Unregister callback when the window closes (important to avoid a memory leak)
    window.addEventListener('unload', function(e) { Zotero.Notifier.unregisterObserver(notifierID); }, false);
  },

  zotFileUpdateAnnotations: function() {
    if (!Zotero.AutoIndex.prefs.getBoolPref('zotfile.enabled')) { return; }
    Zotero.AutoIndex.log('zotFileUpdateAnnotations started');

    let keep = {};
    let discard = [];
    var note;

    // generate new notes for existing note datemodified < attachment date?

    for (row of (Zotero.DB.query("SELECT itemID, sourceID, note FROM itemNotes JOIN items on items.itemID = itemNotes.itemID WHERE sourceItemID in (SELECT sourceItemID FROM itemNotes GROUP BY sourceItemID HAVING COUNT(sourceItemID) > 1)") || [])) {
      let metadata = row.note.match(/<!--(.*?)-->/);
      if (!metadata) { continue; }
      try {
        note = JSON.parse(metadata[1]);
      } catch (err) {
        continue;
      }
      Zotero.AutoIndex.log('note: ' + JSON.stringify(note));
      if (!note.zotfile) { continue; }
      note.itemID = row.itemID;
      note.modified = Zotero.Items.get(note.itemID).dateModified;
      note.attachment = row.sourceID;

      if (!keep[note.attachment]) {
        keep[note.attachment] = note;
      } else {
        if (keep[note.attachment].modified > note.modified) {
          discard.push(note.itemID);
        } else {
          discard.push(keep[note.attachment].itemID);
          keep[note.attachment] = note;
        }
      }
    }

    Zotero.AutoIndex.log('discarding extracted notes: ' + JSON.stringify(discard));
    if (discard.length > 0) { Zotero.Items.trash(discard); }

    Zotero.AutoIndex.log('zotFileUpdateAnnotations: updated');
  },

  reindexItem: function(item) {
    try {
      Zotero.AutoIndex.reindex(item.id);
    } catch (err) {
      Zotero.AutoIndex.log('reindex', err);
    }
  },

  reindexRequest: function(request) { Zotero.AutoIndex.reindexItem(Zotero.Sync.Storage.getItemFromRequestName(request.name)); },

  reindex: function(itemID) {
    Zotero.DB.query('DELETE FROM fulltextItemWords WHERE itemID = ?', [itemID]);
    Zotero.DB.query('DELETE FROM fulltextItems WHERE itemID = ?', [itemID]);
    Zotero.AutoIndex.log('Marked for re-indexing: ' + itemID);
  },

  notifierCallback: {
    notify: function(event, type, ids, extraData) {
      if (event == 'add' || event == 'modify') {
        let attachments = [];
        for (item of Zotero.Items.get(ids)) {
          Zotero.AutoIndex.reindexItem(item);
          if (item.isAttachment()) {attachments.push(item.id);}
        }

        if (Zotero.AutoIndex.prefs.getBoolPref('zotfile.enabled')) {
          Zotero.Zotfile.pdfAnnotations.getAnnotations(attachments);
        }

        Zotero.AutoIndex.update(1);
      }
    }
  },

  rebuildIndex: function(howmany) {
    Zotero.DB.beginTransaction();

    howmany = howmany || Zotero.AutoIndex.prefs.getIntPref('index.batch');
    // Get all attachments other than web links
    var sql = "SELECT itemID FROM itemAttachments WHERE linkMode!="
      + Zotero.Attachments.LINK_MODE_LINKED_URL;
    sql += " AND itemID NOT IN (SELECT itemID FROM fulltextItems "
        + "WHERE indexedChars IS NOT NULL OR indexedPages IS NOT NULL)";
    var items = Zotero.DB.columnQuery(sql);
    if (items && items.length > 0) {
      items = items.splice(0, howmany);
      Zotero.AutoIndex.log('rebuilding ' + items.length + items);
      Zotero.DB.query("DELETE FROM fulltextItemWords WHERE itemID IN (" + ['?' for (p of items)].join(',') + ")", items);
      Zotero.DB.query("DELETE FROM fulltextItems WHERE itemID IN (" + ['?' for (p of items)].join(',') + ")", items);
      Zotero.Fulltext.indexItems(items, false, true);
    }
    Zotero.DB.commitTransaction();
  },

  update: function(howmany) {
    Zotero.AutoIndex.log('updating');

    try {
      Zotero.AutoIndex.zotFileUpdateAnnotations(howmany);
    } catch (err) {
      Zotero.AutoIndex.log('update zotFileAnnotations', err);
    }

    try {
      Zotero.AutoIndex.rebuildIndex(howmany);
    } catch (err) {
      Zotero.AutoIndex.log('update index', err);
    }

    Zotero.AutoIndex.log('update done');
  }
};

// Initialize the utility
window.addEventListener('load', function(e) { Zotero.AutoIndex.init(); }, false);
