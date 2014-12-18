Zotero.AutoIndex =
  prefs: Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService).getBranch("extensions.zotero-auto-index.")
  PrefObserver:
    register: ->
      
      # First we'll need the preference services to look for preferences.
      prefService = Components.classes["@mozilla.org/preferences-service;1"].getService(Components.interfaces.nsIPrefService)
      
      # For this.branch we ask for the preferences for extensions.myextension. and children
      @branch = prefService.getBranch("extensions.zotero-auto-index.")
      
      # Finally add the observer.
      @branch.addObserver "", this, false
      return

    unregister: ->
      @branch.removeObserver "", this
      return

    observe: (aSubject, aTopic, aData) ->

  
  # aSubject is the nsIPrefBranch we're observing (after appropriate QI)
  # aData is the name of the pref that's been changed (relative to aSubject)
  
  # re-jigger auto-export here
  expandWordList: (words) ->
    expanded = {}
    
    # stash words in a dictiionary to make them unique
    #
    for word in words
      expanded[word.toLowerCase()] = true
      word = Zotero.Utilities.removeDiacritics(word, false).toLowerCase()
      expanded[word] = true  if word.match(/^[\x20-\x7f]+$/)
    return Object.keys(expanded)

  openPreferenceWindow: (paneID, action) ->
    io =
      pane: paneID
      action: action

    window.openDialog "chrome://zotero-auto-index/content/options.xul", "zotero-auto-index-options", (if "chrome,titlebar,toolbar,centerscreen" + Zotero.Prefs.get("browser.preferences.instantApply", true) then "dialog=no" else "modal"), io
    return

  log: (msg, e) ->
    return  unless Zotero.AutoIndex.prefs.getBoolPref("debug")
    msg = "[indexing] " + msg
    if e
      msg += "\nan error occurred: " + e.name + ": " + e.message + " \n(" + e.fileName + ", " + e.lineNumber + ")"
      msg += "\n" + e.stack  if e.stack
    Zotero.debug msg
    console.log msg
    return

  init: ->
    @PrefObserver.register()
    
    # monkey-patch Zotero.Sync.Storage.Mode to cause uploaded/downloaded files to be marked for re-indexing
    Zotero.Sync.Storage.Mode::uploadFile = ((self, original) ->
      (request) ->
        result = original.apply(this, arguments)
        self.reindexRequest request
        result
    )(this, Zotero.Sync.Storage.Mode::uploadFile)
    Zotero.Sync.Storage.Mode::downloadFile = ((self, original) ->
      (request) ->
        result = original.apply(this, arguments)
        self.reindexRequest request
        result
    )(this, Zotero.Sync.Storage.Mode::downloadFile)
    
    # monkey-patch Zotero.Sync.Runner.stop to kick off full re-indexing
    Zotero.Sync.Runner.stop = ((self, original) ->
      (request) ->
        result = original.apply(this, arguments)
        self.update 1
        result
    )(this, Zotero.Sync.Runner.stop)
    
    # force all-pages indexing -- the replacement semanticSplitter is fast enough to handle it
    Zotero.Fulltext.indexFile = ((self, original) ->
      (file, mimeType, charset, itemID, complete, isCacheFile) ->
        try
          return original.apply(this, [
            file
            mimeType
            charset
            itemID
            true
            isCacheFile
          ])
        catch err
          Zotero.AutoIndex.log "indexFile failed: ", err
        return
    )(this, Zotero.Fulltext.indexFile)
    
    # monkey-patch indexWords to add ASCII alternatives
    Zotero.Fulltext.indexWords = ((self, original) ->
      (itemID, words) ->
        try
          Zotero.AutoIndex.log "indexWords started"
          return original.apply(this, [
            itemID
            self.expandWordList(words)
          ])
        finally
          Zotero.AutoIndex.log "indexWords done"
        return
    )(this, Zotero.Fulltext.indexWords)
    if Zotero.ZotFile
      Zotero.ZotFile.pdfAnnotations.getNoteContent = ((self, original) ->
        (annotations, item, att, method) ->
          original.apply(this, arguments) + "<!-- " + JSON.stringify(zotfile: {}) + " -->"
      )(this, Zotero.ZotFile.pdfAnnotations.getNoteContent)
    notifierID = Zotero.Notifier.registerObserver(Zotero.AutoIndex.notifierCallback, ["item"])
    
    # Unregister callback when the window closes (important to avoid a memory leak)
    window.addEventListener "unload", ((e) ->
      Zotero.Notifier.unregisterObserver notifierID
      return
    ), false
    return

  zotFileUpdateAnnotations: ->
    return  unless Zotero.ZotFile
    Zotero.AutoIndex.log "zotFileUpdateAnnotations started"
    keep = {}
    discard = []
    note = undefined
    
    # generate new notes for existing note datemodified < attachment date?
    
    for row in (Zotero.DB.query("SELECT itemID, sourceID, note FROM itemNotes JOIN items on items.itemID = itemNotes.itemID WHERE sourceItemID in (SELECT sourceItemID FROM itemNotes GROUP BY sourceItemID HAVING COUNT(sourceItemID) > 1)") or [])
      metadata = row.note.match(/<!--(.*?)-->/)
      continue  unless metadata
      try
        note = JSON.parse(metadata[1])
      catch err
        continue
      Zotero.AutoIndex.log "note: " + JSON.stringify(note)
      continue  unless note.zotfile
      note.itemID = row.itemID
      note.modified = Zotero.Items.get(note.itemID).dateModified
      note.attachment = row.sourceID
      unless keep[note.attachment]
        keep[note.attachment] = note
      else
        if keep[note.attachment].modified > note.modified
          discard.push note.itemID
        else
          discard.push keep[note.attachment].itemID
          keep[note.attachment] = note
    Zotero.AutoIndex.log "discarding extracted notes: " + JSON.stringify(discard)
    Zotero.Items.trash discard  if discard.length > 0
    Zotero.AutoIndex.log "zotFileUpdateAnnotations: updated"
    return

  reindexItem: (item) ->
    try
      Zotero.AutoIndex.reindex item.id
    catch err
      Zotero.AutoIndex.log "reindex", err
    return

  reindexRequest: (request) ->
    Zotero.AutoIndex.reindexItem Zotero.Sync.Storage.getItemFromRequestName(request.name)
    return

  reindex: (itemID) ->
    Zotero.DB.query "DELETE FROM fulltextItemWords WHERE itemID = ?", [itemID]
    Zotero.DB.query "DELETE FROM fulltextItems WHERE itemID = ?", [itemID]
    Zotero.AutoIndex.log "Marked for re-indexing: " + itemID
    return

  notifierCallback:
    notify: (event, type, ids, extraData) ->
      if event is "add" or event is "modify"
        attachments = []
        
        for item in Zotero.Items.get(ids)
          Zotero.AutoIndex.reindexItem item
          attachments.push item.id  if item.isAttachment()
        Zotero.ZotFile.pdfAnnotations.getAnnotations attachments  if Zotero.ZotFile
        Zotero.AutoIndex.update 1
      return

  rebuildIndex: (howmany) ->
    
    # TODO: kick off using setTimeout, check whether this timeout was actually the source (approximation for "user
    # busy")
    Zotero.DB.beginTransaction()
    howmany = howmany or Zotero.AutoIndex.prefs.getIntPref("index.batch")
    
    # Get all attachments other than web links
    sql = "SELECT itemID FROM itemAttachments WHERE linkMode!=" + Zotero.Attachments.LINK_MODE_LINKED_URL
    sql += " AND itemID NOT IN (SELECT itemID FROM fulltextItems " + "WHERE indexedChars IS NOT NULL OR indexedPages IS NOT NULL)"
    items = Zotero.DB.columnQuery(sql)
    if items and items.length > 0
      items = items.splice(0, howmany)
      Zotero.AutoIndex.log "rebuilding " + items.length + items
      
      Zotero.DB.query("DELETE FROM fulltextItemWords WHERE itemID IN (#{('?' for p in items).join(',')})", items)
      Zotero.DB.query("DELETE FROM fulltextItems WHERE itemID IN (#{('?' for p in items).join(',')})", items)
      Zotero.Fulltext.indexItems items, false, true
    Zotero.DB.commitTransaction()
    return

  update: (howmany) ->
    Zotero.AutoIndex.log "updating"
    try
      Zotero.AutoIndex.zotFileUpdateAnnotations howmany
    catch err
      Zotero.AutoIndex.log "update zotFileAnnotations", err
    try
      Zotero.AutoIndex.rebuildIndex howmany
    catch err
      Zotero.AutoIndex.log "update index", err
    Zotero.AutoIndex.log "update done"
    return


# Initialize the utility
window.addEventListener "load", ((e) ->
  Zotero.AutoIndex.init()
  return
), false
