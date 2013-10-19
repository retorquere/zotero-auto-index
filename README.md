zotero-auto-index
=================

Automatically keeps your attachments indexed.

This plugin replaces the standard Zotero tokenizer with one that is several orders of magnitude faster (a 13MB PDF that
Zotero had been plodding away on for 15 minutes when with no end in sight now indexes in under a minute), plus it adds
ascii-ized search words in the index in addition to the words found in the PDF.

IMPORTANT
=========

Despite the replacement tokenizer, unless you have indexed your collection before installing this plugin, anything that touches any of your attachments
(including sync) will cause **all** unindexed attachments to be indexed. This will probably take a very long time, and
Zotero/Firefox will freeze entirely while it is running. This is normal. Go grab a cup of coffee, read that article you
have been putting off, and sit it out. After this initial spike, indexing should be painless and automatic.

