Zotero.AutoIndex =
  idleService: Components.classes["@mozilla.org/widget/idleservice;1"].getService(Components.interfaces.nsIIdleService)
  idleObserver: observe: (subject, topic, data) ->
    switch topic
      when 'idle'
        Zotero.debug("[auto-index]: idle")
        Zotero.AutoIndex.idle = true
        Zotero.Fulltext.rebuildIndex(true)

      when 'back', 'active'
        Zotero.debug("[auto-index]: busy")
        Zotero.AutoIndex.idle = false
    return

  init: ->
    return if @initialized
    @initialized = true

    Zotero.Fulltext.indexFile = ((original) ->
      return (file, mimeType, charset, itemID, complete, isCacheFile) ->
        Zotero.debug("[auto-index] #{file.path}: #{!!Zotero.AutoIndex.idle}")
        return unless Zotero.AutoIndex.idle
        return original.apply(this, arguments)
      )(Zotero.Fulltext.indexFile)

    @idleService.addIdleObserver(@idleObserver, Zotero.Prefs.get('auto-index.delay'))

    Zotero.Prefs.registerObserver('fulltext.textMaxLength', @clearIndex)
    Zotero.Prefs.registerObserver('fulltext.pdfMaxPages', @clearIndex)

  clearIndex: ->
    Zotero.Fulltext.clearIndex(true) if Zotero.Prefs.get('auto-index.reindexOnPrefChange')

window.addEventListener('load', (load = (event) ->
  window.removeEventListener('load', load, false) #remove listener, no longer needed
  Zotero.AutoIndex.init()
  return
), false)
