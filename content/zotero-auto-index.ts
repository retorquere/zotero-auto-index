declare const Zotero: any
declare const Components: any

const marker = 'AutoIndexMonkeyPatched'

function patch(object, method, patcher) {
  if (object[method][marker]) return
  object[method] = patcher(object[method])
  object[method][marker] = true
}

export let AutoIndex = Zotero.AutoIndex || new class { // tslint:disable-line:variable-name
  public idle: boolean = false

  private idleService = Components.classes['@mozilla.org/widget/idleservice;1'].getService(Components.interfaces.nsIIdleService)
  private initialized: boolean = false

  constructor() {
    window.addEventListener('load', event => {
      this.init()
    }, false)
  }

  public observe(subject, topic, data) {
    switch (topic) {
      case 'idle':
        Zotero.debug('[auto-index]: idle')
        this.idle = true
        Zotero.Fulltext.rebuildIndex(true)
        break

      case 'back':
      case 'active':
        Zotero.debug('[auto-index]: busy')
        this.idle = false
        break
    }
  }

  private init() {
    if (this.initialized) return
    this.initialized = true

    patch(Zotero.Fulltext, 'indexFile', original => function(file, mimeType, charset, itemID, complete, isCacheFile) {
      Zotero.debug(`[auto-index] ${file.path}: ${!!Zotero.AutoIndex.idle}`)
      if (Zotero.AutoIndex.idle) original.apply(this, arguments)
    })

    this.idleService.addIdleObserver(this, Zotero.Prefs.get('auto-index.delay'))

    Zotero.Prefs.registerObserver('fulltext.textMaxLength', this.clearIndex.bind(this))
    Zotero.Prefs.registerObserver('fulltext.pdfMaxPages', this.clearIndex.bind(this))
  }

  private clearIndex() {
    if (Zotero.Prefs.get('auto-index.reindexOnPrefChange')) Zotero.Fulltext.clearIndex(true)
  }
}
