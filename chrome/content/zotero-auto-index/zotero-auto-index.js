Zotero.AutoIndex = {
  init: function () {
    // monkey-patch Zotero.Sync.Storage.Mode
    Zotero.Sync.Storage.Mode.prototype.uploadFile = (function (self, original) {
      return function (request) {
        var result = original.apply(this, arguments);
        self.reindex(Zotero.Sync.Storage.getItemFromRequestName(request.name));
        return result;
      }
    })(this, Zotero.Sync.Storage.Mode.prototype.uploadFile);

    Zotero.Sync.Storage.Mode.prototype.downloadFile = (function (self, original) {
      return function (request) {
        var result = original.apply(this, arguments);
        self.reindex(Zotero.Sync.Storage.getItemFromRequestName(request.name));
        return result;
      }
    })(this, Zotero.Sync.Storage.Mode.prototype.downloadFile);

    var notifierID = Zotero.Notifier.registerObserver(this.notifierCallback, ['item']);
    // Unregister callback when the window closes (important to avoid a memory leak)
    window.addEventListener('unload', function(e) {
      Zotero.Notifier.unregisterObserver(notifierID);
    }, false);
  },
  
  reindex: function(item) {
    Zotero.DB.query('DELETE FROM fulltextItemWords WHERE itemID = ?', [item.id]);
    Zotero.DB.query('DELETE FROM fulltextItems WHERE itemID = ?', [item.id]);
    Zotero.Fulltext.rebuildIndex(false);
  },

  notifierCallback: {
    notify: function(event, type, ids, extraData) {
      if (event == 'add' || event == 'modify') {
        for (item for Zotero.Items.get(ids)) {
          this.reindex(item);
        }
      }
    }
  }
};

// Initialize the utility
window.addEventListener('load', function(e) { Zotero.AutoIndex.init(); }, false);
