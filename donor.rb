require 'redditkit'

module DogeSansa
    class Donor
    attr_accessor :comment, :link, :time, :permalink, :from, :to, :amount

        def initialize(comment, link)
            @comment = comment
            @link = link
            @time = comment.created_at
            @permalink = "http://www.reddit.com/comments/#{link.id}/dogesansa/#{comment.id}"

            m = /(\/u\/\S+)\s->\s(\/u\/\S+)\s*Ð(\S+)/.match(comment.body)
            @from = m[1].to_s
            @to = m[2].to_s
            @amount = m[3].to_f
        end
    end
end