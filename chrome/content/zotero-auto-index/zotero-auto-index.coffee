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
    Zotero.Fulltext.indexFile = ((original) ->
      return (file, mimeType, charset, itemID, complete, isCacheFile) ->
        Zotero.debug("[auto-index] #{file.path}: #{!!Zotero.AutoIndex.idle}")
        return unless Zotero.AutoIndex.idle
        return original.apply(this, arguments)
      )(Zotero.Fulltext.indexFile)

    @idleService.addIdleObserver(@idleObserver, Zotero.Prefs.get('auto-index.delay'))
    Zotero.Prefs.prefBranch.addObserver('', @prefChanged, false)

    return

  prefChanged: observe: (subject, topic, data) ->
    Zotero.debug("[auto-index]: options #{data} changed, enabled: #{Zotero.Prefs.get('auto-index.reindexOnPrefChange')}")
    if (data == 'fulltext.textMaxLength' || data == 'fulltext.pdfMaxPages') && Zotero.Prefs.get('auto-index.reindexOnPrefChange')
      Zotero.Fulltext.clearIndex(true)
    return

# Initialize the utility
window.addEventListener("load", ((e) ->
  Zotero.AutoIndex.init()
  return
), false)
