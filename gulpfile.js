/**
 * an example gulpfile to make ant-less existdb package builds a reality
 */
const { src, dest, watch, series, parallel } = require('gulp')
const { createClient } = require('@existdb/gulp-exist')
const rename = require('gulp-rename')
const zip = require("gulp-zip")
const replace = require('@existdb/gulp-replace-tmpl')
const del = require('delete')

// read metadata from package.json and .existdb.json
const { version, license } = require('./package.json')
const { package, servers } = require('./.existdb.json')

// .tmpl replacements to include 
// first value wins
const replacements = [package, {version, license}]

const serverInfo = servers.localhost
const { port, hostname } = new URL(serverInfo.server)
const connectionOptions = {
    basic_auth: {
        user: serverInfo.user, 
        pass: serverInfo.password
    },
    host: hostname,
    port,
    secure: false
}
const existClient = createClient(connectionOptions);

const static = [
    "content/*",
    "test/xqs/*"
]

// construct the current xar name from available data
const packageName = () => `target/${package.target}-${version}.xar`

/**
 * helper function that uploads and installs a built XAR
 */
function installXar (packageName, packageUri) {
    return src(packageName)
        .pipe(existClient.install({ packageUri }))
}

/**
 * Use the `delete` module directly, instead of using gulp-rimraf
 */
function cleanLibrary (cb) {
    del(['build'], cb);
}
exports['clean:library'] = cleanLibrary

/**
 * Use the `delete` module directly, instead of using gulp-rimraf
 */
function cleanAll (cb) {
    del(['build'], cb);
}
exports['clean:all'] = cleanAll

exports.clean = cleanAll

/**
 * replace placeholders 
 * in src/*.xml.tmpl and 
 * output to build/*.xml
 */
function templates() {
    return src('*.tmpl')
        .pipe(replace(replacements, { unprefixed: true }))
        .pipe(rename(path => { path.extname = "" }))
        .pipe(dest('build/'))
}

exports.templates = templates

function watchTemplates () {
    watch('*.tmpl', series(templates))
}
exports["watch:tmpl"] = watchTemplates

/**
 * copy XMLs and XQueries to 'build'
 */
function copyStatic () {
    return src(static, {base: '.'}).pipe(dest('build'))
}
exports.copy = copyStatic

function watchStatic () {
    watch(static, series(copyStatic));
}
exports["watch:static"] = watchStatic

/**
 * since this is a pure library package uploading
 * the library itself will not update the compiled
 * version in the cache.
 * This is why the xar will be installed instead
 */
function watchBuild () {
    watch('build/**/*', series(xar, installLibraryXar))
}

/**
 * create XAR package in repo root
 */
function xar () {
    return src('build/**/*', {base: 'build'})
        .pipe(zip(packageName()))
        .pipe(dest('.'))
}

/**
 * upload and install the latest built XAR
 */
function installLibraryXar () {
    return installXar(packageName(), package.namespace)
}

// composed tasks
const packageLibrary = series(
    templates,
    copyStatic,
    xar
)

exports.build = series(cleanLibrary, packageLibrary)
exports["build:all"] = series(
    cleanAll,
    packageLibrary
)

exports.install = series(cleanLibrary, packageLibrary, installLibraryXar)
exports["install:all"] = series(
    cleanAll,
    packageLibrary, installLibraryXar
)

const watchAll = parallel(
    watchStatic,
    watchTemplates,
    watchBuild
)
exports.watch = watchAll

// main task for day to day development
// package and install library
// still watch all and install on change 
exports.default = series(
    cleanAll, 
    packageLibrary, installLibraryXar,
    watchAll
)