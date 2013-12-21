DogeSansa
==========

doge-sansa is a Reddit bot written in Ruby that will generate statistics about /u/dogetipbot for those who ask. Tested on Ruby 1.9

## Dependencies
* RubyGems

* RedditKit

`gem install redditkit`

## How to use

    cd doge-sansa
    ruby dogesansa.rb <username> <password>
    
doge-sansa uses `pstore` to store some values if the bot crashes, so use `_resetpstore.rb <username> <password>` to initialize or reset it.
