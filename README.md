zotero-auto-index
=================

Automatically keeps your attachments indexed.

This plugin replaces the standard Zotero tokenizer with one that is several orders of magnitude faster (a 13MB PDF that
Zotero had been plodding away on for 15 minutes when with no end in sight now indexes in under a minute), plus it adds
ascii-ized search words in the index in addition to the words found in the PDF.

## Zotfile integration

If Zotfile is installed, auto-index will scan changed attachments and re-extract annotations from them during the update
cycle. It will not kick off an initial scan -- if you want everything extracted, you'll have to do a one-time
select-all + extract manually

IMPORTANT
=========

Despite the replacement tokenizer, unless you have indexed your collection before installing this plugin, anything that
touches any of your attachments (including sync) will cause **all** unindexed attachments to be indexed. This will
probably take a very long time, and Zotero/Firefox will freeze entirely while it is running. This is normal. Go grab a
cup of coffee, read that article you have been putting off, and sit it out. After this initial spike, indexing should be
painless and automatic. Batches are currently limited to 50 attachments to not freeze Firefox for too long; you can kick
off a new batch by choosing the 'Refresh full-text index' option from the gear menu. *In principle* this does the same
as the "rebuild index" option from the Zotero preferences menu, except that that rebuild does everything in one fell
swoop, and my (too large) collection causes Firefox to die during the rebuild. The 'Refresh' option can be triggered
multiple times, and won't do anything once your entire collection is indexed.

