/* eslint-disable no-var */
'use strict'

const chai = require('chai')
const chaiXml = require('chai-xml')
const expect = require('chai').expect
const fs = require('fs-extra')
const glob = require('glob')
const xmldoc = require('xmldoc')
const assert = require('yeoman-assert')

// this is not equivalent to using a real xml parser
describe('file system checks', function () {
  describe('markup files are well-formed', function () {
    chai.use(chaiXml)
    it('*.html is xhtml', function (done) {
      glob('**/*.html', { ignore: 'node_modules/**' }, function (err, files) {
        if (err) throw err
        // console.log(files)
        files.forEach(function (html) {
          const xhtml = fs.readFileSync(html, 'utf8')
          const hParsed = new xmldoc.XmlDocument(xhtml).toString()
          expect(hParsed).xml.to.be.valid()
        })
      })
      done()
    })

    it('*.xml', function (done) {
      glob('**/*.xml', { ignore: 'node_modules/**' }, function (err, files) {
        if (err) throw err
        // console.log(files)
        files.forEach(function (xmls) {
          const xml = fs.readFileSync(xmls, 'utf8')
          const xParsed = new xmldoc.XmlDocument(xml).toString()
          expect(xParsed).xml.to.be.valid()
        })
      })
      done()
    })

    it('*.xconf', function (done) {
      glob('**/*.xconf', { ignore: 'node_modules/**' }, function (err, files) {
        if (err) throw err
        // console.log(files)
        files.forEach(function (xconfs) {
          const xconf = fs.readFileSync(xconfs, 'utf8')
          const cParsed = new xmldoc.XmlDocument(xconf).toString()
          expect(cParsed).xml.to.be.valid()
        })
      })
      done()
    })
    it('*.odd', function (done) {
      this.slow(1000)
      glob('**/*.odd', { ignore: 'node_modules/**' }, function (err, files) {
        if (err) throw err
        // console.log(files)
        files.forEach(function (odds) {
          const odd = fs.readFileSync(odds, 'utf8')
          const xParsed = new xmldoc.XmlDocument(odd).toString()
          expect(xParsed).xml.to.be.valid()
        })
      })
      done()
    })
  })

  describe('Consistent data in aux files', function () {

    it('Readme should have latest meta-data', function (done) {
      const pkg = fs.readFileSync('package.json', 'utf8')
      const parsed = JSON.parse(pkg)

      if (fs.existsSync('README.md')) {
        assert.fileContent('README.md', '# ' + parsed.name)
        assert.fileContent('README.md', parsed.version)
        assert.fileContent('README.md', parsed.description)
      } else { this.skip() }
      done()
    })
  })
})
