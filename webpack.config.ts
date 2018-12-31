// tslint:disable:no-console

// const replace = require('replace')

import * as webpack from 'webpack'
import * as path from 'path'

import CircularDependencyPlugin = require('circular-dependency-plugin')
// import AfterBuildPlugin = require('./zotero-webpack/plugin/after-build')

import 'zotero-plugin/make-dirs'
import 'zotero-plugin/copy-assets'
import 'zotero-plugin/rdf'
import 'zotero-plugin/version'

const config = {
  mode: 'development',
  devtool: false,
  optimization: {
    flagIncludedChunks: true,
    occurrenceOrder: false,
    usedExports: true,
    minimize: false,
    concatenateModules: false,
    noEmitOnErrors: true,
    namedModules: true,
    namedChunks: true,
    // runtimeChunk: false,
  },

  resolve: {
    extensions: ['.ts', '.js'],
  },

  node: { fs: 'empty' },

  resolveLoader: {
    alias: {
      'pegjs-loader': path.join(__dirname, './zotero-webpack/loader/pegjs.ts'),
      'json-loader': path.join(__dirname, './zotero-webpack/loader/json.ts'),
      'wrap-loader': 'zotero-plugin/loader/wrap',
    },
  },
  module: {
    rules: [
      { test: /\.json$/, use: [ 'json-loader' ] },
      { test: /\.ts$/, exclude: [ /node_modules/ ], use: [ 'wrap-loader', 'ts-loader' ] },
    ],
  },

  plugins: [
    new CircularDependencyPlugin({ failOnError: true }),
  ],

  context: path.resolve(__dirname, './content'),

  entry: {
    AutoIndex: './zotero-auto-index.ts',
  },

  output: {
    globalObject: 'Zotero',
    path: path.resolve(__dirname, './build/content'),
    filename: '[name].js',
    jsonpFunction: 'WebPackedAutoIndex',
    devtoolLineToLine: true,
    pathinfo: true,
    library: 'Zotero.[name]',
    libraryTarget: 'assign',
  },
}

export default config
