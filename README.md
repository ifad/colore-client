# Colore::Client

A ruby client for the [Colore](http://github.com/ifad/colore) document storage
and conversion service. See the Colore documentation for a more detailed
description of what Colore does and its API methods.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'colore-client', github: 'ifad/colore-client'
```

And then execute:

```ruby
bundle
```


## Usage

```ruby
base_uri = 'http://localhost:9240/'
app = 'myapp'
client = Colore::Client.new base_uri: base_uri, app: app
client.ping or abort "No connection to Colore"

doc_id = client.generate_doc_id
file = File.new('foo.jpg')
content = f.read

# Store a file
conversion_callback = 'http:/localhost:10000/foo' # you should have a listener on this port
resp = client.create_document(
  doc_id:       doc_id,
  filename:     file.path,
  content:      content
  actions:      ['ocr'],
  callback_url: conversion_callback )
puts resp.path

# Convert a file on the fly
pdf = client.convert content: file.read, format: 'ocr'
File.open( 'foo.pdf', 'wb' ) { |f| f.write(pdf) }
```


## Available Methods

```ruby
client.create_document doc_id:, filename:, content:, title:, actions:[], callback_url
client.update_document doc_id:, version:, filename:, content:, title:, actions:[], callback_url:
client.request_new_format doc_id:, version:, filename:, format: callback_url:
client.delete_document doc_id:
client.delete_version doc_id:, version:
client.get_document doc_id:, version:, filename:
client.get_document_info doc_id:
client.convert content:, format:, language:
```

See the YARD doc for more details


## Logging

The client takes an optional Logger as an initialization parameter:

```ruby
client = Colore::Client.new base_uri: base_uri, app: app, logger: Logger.new(STDOUT)
```

This can also be set at any time:

```ruby
client.logger = Logger.new(STDERR)
