declare const Zotero: any
declare const Components: any

export const AutoIndex = Zotero.AutoIndex = Zotero.AutoIndex || new class { // tslint:disable-line:variable-name
  public idle = false

  private idleService = Components.classes['@mozilla.org/widget/idleservice;1'].getService(Components.interfaces.nsIIdleService)
  private initialized = false

  constructor() {
    window.addEventListener('load', _event => {
      this.init()
    }, false)
  }

  public observe(subject, topic, _data) {
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

    this.idleService.addIdleObserver(this, Zotero.Prefs.get('auto-index.delay'))

    Zotero.Prefs.registerObserver('fulltext.textMaxLength', this.clearIndex.bind(this))
    Zotero.Prefs.registerObserver('fulltext.pdfMaxPages', this.clearIndex.bind(this))
  }

  private clearIndex() {
    if (Zotero.Prefs.get('auto-index.reindexOnPrefChange')) Zotero.Fulltext.clearIndex(true)
  }
}
