Zotero.AutoIndex =
  idleService: Components.classes["@mozilla.org/widget/idleservice;1"].getService(Components.interfaces.nsIIdleService)
  idleObserver: observe: (subject, topic, data) ->
    switch topic
      when 'idle'
        Zotero.debug("[auto-index]: idle")
        Zotero.AutoIndex.idle = true
        Zotero.AutoIndex.update()

      when 'back'
        Zotero.debug("[auto-index]: busy")
        Zotero.AutoIndex.idle = false
    return

  init: ->
    nids = []
    nids.push(Zotero.Notifier.registerObserver(@itemChanged, ['item']))
    window.addEventListener('unload', ((e) -> Zotero.Notifier.unregisterObserver(id) for id in nids), false)

    @idleService.addIdleObserver(@idleObserver, Zotero.Prefs.get('auto-index.delay'))

    Zotero.Prefs.prefBranch.addObserver('', @prefChanged, false)

    Zotero.Fulltext.indexItems = ((original) ->
      return (items, complete, ignoreErrors) ->
        return unless Zotero.AutoIndex.idle
        return original.apply(this, arguments)
      )(Zotero.Fulltext.indexItems)

    return

  prefChanged: observe: (subject, topic, data) ->
    Zotero.debug("[auto-index]: options #{data} changed, enabled: #{Zotero.Prefs.get('auto-index.reindexOnPrefChange')}")
    if (data == 'fulltext.textMaxLength' || data == 'fulltext.pdfMaxPages') && Zotero.Prefs.get('auto-index.reindexOnPrefChange')
      Zotero.debug("[auto-index]: indexing options changes, re-indexing all!")
      Zotero.DB.query("DELETE FROM fulltextItemWords")
      Zotero.DB.query("DELETE FROM fulltextItems")
    return

  itemChanged: notify: (event, type, ids, extraData) ->
    return unless event == 'add' || event == 'modify'
    return if ids.length == 0

    ids = ('' + id for id in ids).join(',')
    Zotero.debug("[auto-index]: marking #{ids}")
    Zotero.DB.query("DELETE FROM fulltextItemWords WHERE itemID in (#{ids})")
    Zotero.DB.query("DELETE FROM fulltextItems WHERE itemID in (#{ids})")
    return

  update: ->
    return unless @idle

    Zotero.DB.beginTransaction()

    # Get all attachments other than web links
    items = Zotero.DB.columnQuery("SELECT itemID
                                   FROM itemAttachments
                                   WHERE linkMode <> ?
                                    AND (mimeType in ('application/xhtml+xml', 'application/xml', 'application/x-javascript') OR mimeType like 'text/%')
                                    AND itemID NOT IN ( SELECT itemID FROM fulltextItems WHERE indexedChars IS NOT NULL OR indexedPages IS NOT NULL)
                                  ", [Zotero.Attachments.LINK_MODE_LINKED_URL])

    for item in items
      break unless @idle
      Zotero.debug("[auto-index]: re-indexing #{item}")
      Zotero.DB.query('DELETE FROM fulltextItemWords WHERE itemID = ?', [item])
      Zotero.DB.query('DELETE FROM fulltextItems WHERE itemID = ?', [item])
      Zotero.Fulltext.indexItems([item], false, true)

    Zotero.DB.commitTransaction()

    return

# Initialize the utility
window.addEventListener("load", ((e) ->
  Zotero.AutoIndex.init()
  return
), false)
