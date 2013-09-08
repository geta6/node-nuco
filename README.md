nodectlが肥大化したのでnewしました。

# nuco

light weight process manager for node.

![](http://gyazo.com/02baa24605e6b9a2bb7b2a619fd7ae77.png)

# Install

```
npm i nuco
```

# Interface

## CLI

```

Usage: nuco [options] <file>

Options:

  -h, --help          output usage information
  -V, --version       output the version number
  -b, --bar           show bar
  -e, --env [string]  set NODE_ENV
  -p, --port [int]    set PORT
  -f, --forks [int]   concurrent process
  -c, --color         colorize log
  -w, --watch         watch code change
  -a, --asset [path]  asset path

```

## Module

```js

var nuco = require('nuco');

nuco('./app.js', {
  bar: yes,
  env: 'development',
  port: 3000,
  forks: 'auto',
  color: yes,
  watch: yes,
  asset: 'assets'
});

```

key     | value type |
--------|------------|---
`bar`   | Boolean    | show bar
`env`   | String     | set NODE_ENV
`port`  | Number     | set PORT
`forks` | Number     | concurrent process
`color` | Boolean    | colorize log
`watch` | Boolean    | watch code change
`asset` | String     | asset path

* `options.watch` ignore directory named `public`
* `options.watch` ignore directory named `options.asset` if `options.asset`
* `options.asset` build assets to `public` from `options.asset`

## method

### `nuco.isnuco()` | `nuco.isNuco()`

process nucoed or not

## nucoed twice?

↓ occurs probrem.

```sh
% echo "
var nuco = require('nuco');

nuco('./app.js', {
  bar: yes,
  env: 'development',
  port: 3000,
  forks: 'auto',
  color: yes,
  watch: yes,
  asset: yes
});" > app.js
% nuco -wbc app.js
```

↓ok.

```
% echo "
var nuco = require('nuco');

if (nuco.isnuco()) {
  require('./app.js');
} else {
  nuco('./app.js', {
    bar: yes,
    env: 'development',
    port: 3000,
    forks: 'auto',
    color: yes,
    watch: yes,
    asset: yes
  });
}" > app.js
% nuco -wbc app.js
```
