# markdown

[![License][license-img]][license-url]
[![GitHub release][release-img]][release-url]
![exist-db CI](https://github.com/eXist-db/exist-markdown/workflows/exist-db%20CI/badge.svg)

<img src="icon.png" align="left" width="25%"/>

Markdown Parser in XQuery

Based on regular expressions and fast enough for rendering small to mid-sized documents.

The parser extends the [original markdown][2] proposal with fenced code 
blocks and tables. These are additional features found in [Github flavored markdown][1].

[1]: https://help.github.com/articles/github-flavored-markdown
[2]: http://daringfireball.net/projects/markdown/syntax

## Requirements

*   [exist-db](https://exist-db.org/exist/apps/homepage/index.html) version: `5.x` or greater

*   [node](https://nodejs.org) version: `12.x` \(for building from source\)

## Installation

1.  Install the Markdown package from eXist's package repository via the [dashboard](http://localhost:8080/exist/apps/dashboard/index.html), or download  the `markdown-1.0.0.xar` file from GitHub [releases](https://github.com/eXist-db/exist-markdown/releases) page.

2.  Open the [dashboard](http://localhost:8080/exist/apps/dashboard/index.html) of your eXist-db instance and click on `package manager`.

    1.  Click on the `add package` symbol in the upper left corner and select the `.xar` file you just downloaded.

3.  You have successfully installed markdown into exist.

### Building from source

1.  Download, fork or clone this GitHub repository
2.  Calling `npm start` in your CLI will install required dependencies from npm and create a `.xar`:
 
```bash   
cd exist-markdown
npm start
```

To install it, follow the instructions [above](#installation).



## Running Tests

This app uses [mochajs](https://mochajs.org) as a test-runner. To run the tests type:

```bash
npm test
```

This will automatically build and install the library into your local eXist, assuming it can be reached on `http://localhost:8080/exist`. If this is not the case, edit `.existdb.json` and change the properties for the `localhost` server to match your setup.

To run tests locally your app needs to be installed in a running exist-db instance at the default port `8080` and with the default dba user `admin` with the default empty password.

A quick way to set this up for docker users is to simply issue:

```bash
docker create --name exist-ci -p 8080:8080 existdb/existdb:latest
docker cp ./markdown-*.xar exist-ci:exist/autodeploy
docker start exist-ci && sleep 30
npm test
```

## Contributing

You can take a look at the [Contribution guidelines for this project](.github/CONTRIBUTING.md)

## License

GNU-LGPL © [The eXist-db Authors](https://github.com/eXist-db/exist-markdown)

[license-img]: https://img.shields.io/badge/license-LGPL%20v3-blue.svg
[license-url]: https://www.gnu.org/licenses/lgpl-3.0
[release-img]: https://img.shields.io/badge/release-1.0.0-green.svg
[release-url]: https://github.com/eXist-db/exist-markdown/releases/latest
