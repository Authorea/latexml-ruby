# LaTeXML-Ruby

[![Build Status](https://secure.travis-ci.org/Authorea/latexml-ruby.png?branch=master)](https://travis-ci.org/Authorea/latexml-ruby)
[![license](http://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/authorea/LaTeXML-Ruby/master/LICENSE)
[![Gem Version](https://badge.fury.io/rb/latexml-ruby.svg)](https://badge.fury.io/rb/latexml-ruby)

A Ruby wrapper for the [LaTeXML](http://dlmf.nist.gov/LaTeXML/) LaTeX to XML/HTML/ePub converter.

Includes support for daemonized conversion runs, for additional performance, via the [latexmls](https://github.com/dginev/LaTeXML-Plugin-latexmls) socket server.

## Why LaTeXML?

You may be familiar with other LaTeX conversion tools such as Pandoc or tex4ht. LaTeXML attempts to be a complete TeX interpreter, and covers a vastly larger range of the TeX/LaTeX ecosystem than Pandoc. At the same time it allows for just-in-time binding of structural and semantic macros, which allows it to create higher quality HTML5 than tex4ht, and makes bridging the impedance mismatch between PDF and HTML an achievable goal.

We use LaTeXML extensively at Authorea (http://www.authorea.com) for enabling [Power latex editing](https://www.authorea.com/28015) for our authors.

## Installation

Install the stand-alone LaTeXML application using [your preferred method](dlmf.nist.gov/LaTeXML/get.html)

Add this line to your application's Gemfile:

```ruby
gem 'latexml-ruby'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install latexml-ruby

### Caveat

The current default setup of the wrapper options uses some advanced LaTeX packages, for which you also need a working LaTeX installation on the machine, as LaTeXML resorts to the native LaTeX definitions. It's usually best to install ```texlive```, or a similar comprehensive TeX distro. For a minimal setup set of options, see the [basic test setup](https://github.com/Authorea/latexml-ruby/blob/master/test/basics_test.rb#L5)

## Usage

A hello world conversion job looks like:

```ruby
require 'latexml'

@latexml = LaTeXML.new

response = @latexml.convert(literal: "hello world")

result = response[:result]
messages = response[:messages]
status_code = response[:status_code]

```

You can find more information on the LaTeXML message codes in [the official manual](http://dlmf.nist.gov/LaTeXML/manual/errorcodes/index.html).Status codes range from 0 (OK), 1 (warning), 2 (error) to 3 (fatal error).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Authorea/latexml-ruby.

The 0.0.1 release of the wrapper brings support for easy conversion of latex fragments, which only scratches the surface of LaTeXML's versatile conversion use cases. If you are interested in a different workflow that is not yet supported, we will be very happy to hear from you.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

