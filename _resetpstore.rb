# This file will reset your pstore so that it has a default amount
require 'redditkit'
require './donor'
require 'pstore'

raise "Not enough arguments." unless ARGV.length == 2

client = RedditKit::Client.new(ARGV[0], ARGV[1])
cm = client.user_content('dogetipbot', :category => "comments", :limit => 1).first
x = DogeSansa::Donor.new(cm, client.link(cm.link_id))
y = 0.0

pstore = PStore.new("dogesansa.pstore")
pstore.transaction do
    pstore['top'] = x
    pstore['total'] = y
end

puts "Done! PStore has been reset."