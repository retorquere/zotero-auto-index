require 'rake'
require 'shellwords'
require 'nokogiri'
require 'openssl'
require 'net/http'
require 'json'
require 'fileutils'
require 'time'
require 'date'
require 'pp'
require 'zip'
require 'tempfile'
require 'rubygems/package'
require 'zlib'
require 'open3'
require 'yaml'
require 'rake/loaders/makefile'
require 'rake/clean'
require 'net/http/post/multipart'
require 'rake/xpi'
require 'rake/xpi/publish/github'

Dir['**/*.js'].reject{|f| f =~ /^(node_modules|www)\//}.each{|f| CLEAN.include(f)}
CLEAN.include('tmp/**/*')
CLEAN.include('.depend.mf')
CLEAN.include('*.xpi')
CLEAN.include('*.log')
CLEAN.include('*.cache')
CLEAN.include('*.debug')
