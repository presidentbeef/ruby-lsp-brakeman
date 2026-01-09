# Brakeman for Ruby LSP

This library enables running [Brakeman](https://brakemanscanner.org/) via [Ruby LSP](https://shopify.github.io/ruby-lsp/).

The library is in early but working stages.

## Installation

Add `ruby-lsp-brakeman` to your `Gemfile`:

```ruby
gem 'ruby-lsp-brakeman', require: false
```

Bundle install and restart the Ruby LSP server/extension to enable.

## In Action

Initialization output should look like this:

 <img width="765" alt="Starting Brakeman in Ruby LSP/VS Code" src="https://github.com/user-attachments/assets/2cfbd42f-dfef-4488-b5b8-b5b8ce3da3cd" />

Display of inline warnings on hover:

 <img width="551" alt="Display of Brakeman warning" src="https://github.com/user-attachments/assets/8708d0d5-0cac-4e7a-8416-1a94a91b54a5" />

Display after clicking "View Problem":

 <img width="566" alt="Display of Brakeman warning" src="https://github.com/user-attachments/assets/5d0f071e-9854-4253-97dd-3a20db6a1081" />

Warnings are listed as "problems" in VS Code's panel:

 <img width="710" alt="Listing of Brakeman warnings" src="https://github.com/user-attachments/assets/c7128ec1-0778-41e5-ae1a-12c96363ce50" />

When files are saved, Brakeman will rescan the files and update any impacted warnings.
Note that scans are asynchronous and only one scan will run at a time. If multiple files are changed while a scan is running, they will be queued and then rescanned all together when the current scan finishes.

 <img width="1159" alt="Queuing, scanning, reported changes" src="https://github.com/user-attachments/assets/5898495d-0ffb-4a15-860a-f45d1ea1ad58" />

## Editors

* VSCode - Should work out of the box
* Zed - Works when [Ruby LSP is configured to run](https://zed.dev/docs/languages/ruby#setting-up-ruby-lsp)
* Helix - Current *not* working

(Feel free to test and extend this list!)

## Limitations

* Column numbers are not available right now, so the entire line is always reported
* Brakeman's rescanning capabilities are currently being overhauled. They work but may be a little slow (but still faster than a full scan)
* Large applications may require way too much memory for incremental scans to be useful
* Warnings may not clear if Ruby LSP crashes
* VS Code does not seem to support `CodeDescription` which can link to more information
* Not many tests yet, so buyer beware

## License

The gem is available as open source under the terms of the MIT License.
