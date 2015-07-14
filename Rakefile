require 'rake'
require 'os'
require 'rake/clean'
require 'shellwords'
require 'nokogiri'
require 'openssl'
require 'net/http'
require 'json'
require 'fileutils'
require 'typhoeus'
require 'time'
require 'date'
require 'pp'
require 'zip'
require 'tempfile'
require 'rubygems/package'
require 'zlib'
require 'open3'
require 'yaml'
require 'washbullet'
require 'rake/loaders/makefile'
require 'selenium-webdriver'
require 'rchardet'
require 'csv'
require 'base64'

ZIPFILES = (Dir['{defaults,chrome,resource}/**/*.{coffee,pegjs}'].collect{|src|
  tgt = src.sub(/\.[^\.]+$/, '.js')
  tgt = [tgt, src.sub(/\.[^\.]+$/, '.js.map')] if File.extname(src) == '.coffee'
  tgt
}.flatten + Dir['chrome/**/*.xul'] + Dir['chrome/{skin,locale}/**/*.*'] + Dir['resource/translators/*.yml'].collect{|tr|
  root = File.dirname(tr)
  stem = File.basename(tr, File.extname(tr))
  %w{header.js js json}.collect{|ext| "#{root}/#{stem}.#{ext}" }
}.flatten + [
  'chrome.manifest',
  'install.rdf',
]).sort.uniq

CLEAN.include('{resource,chrome,defaults}/**/*.js')
CLEAN.include('chrome/content/zotero-better-bibtex/release.js')
CLEAN.include('tmp/**/*')
CLEAN.include('resource/translators/*.json')
CLEAN.include('resource/*/*.js.map')
CLEAN.include('.depend.mf')
CLEAN.include('resource/translators/latex_unicode_mapping.coffee')
CLEAN.include('*.xpi')
CLEAN.include('*.log')
CLEAN.include('*.cache')
CLEAN.include('*.debug')
CLEAN.include('*.dbg')

FileUtils.mkdir_p 'tmp'

class String
  def shellescape
    Shellwords.escape(self)
  end
end

require 'zotplus-rakehelper'

file 'chrome/content/zotero-better-bibtex/release.js' => 'install.rdf' do |t|
  open(t.name, 'w') {|f| f.write("
      Zotero.AutoIndex.release = #{RELEASE.to_json};
    ")
  }
end
