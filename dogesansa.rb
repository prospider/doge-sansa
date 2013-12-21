require 'redditkit'
require 'pstore'
require 'logger'
require './donor'

module DogeSansa
    class DSBot
        def initialize(username, password)
            @username = username
            @client = RedditKit::Client.new(username, password)
            @log = Logger.new('dsbot.log', 10, 1024000)
            @log.level = Logger::DEBUG
            @today = Time.now.day

            @log.debug("Your supplied username: #{ARGV[0]} and password: #{ARGV[1]}")

            raise "Login failed" if not @client.signed_in?

            @log.info("DOGESANSA BOT STARTING")
            @log.info("Developed by /u/Rhodesig")

            p "DOGESANSA BOT STARTING"
            p "Developed by /u/Rhodesig"

            # Set up our records for top donor and coins donated
            @pstore = PStore.new("dogesansa.pstore")
            @pstore.transaction(true) do
                @top = @pstore['top']
                @total = @pstore['total']
                @last_messages_check = @pstore['last_messages_check']
                @last_bot_check = @pstore['last_bot_check']
            end

            @log.info("Loaded @top: to: #{@top.to} from: #{@top.from} amount: #{@top.amount}")
            @log.info("Loaded @total: #{@total}")
        end

        def main()
            begin
                while true
                    @log.debug("Ph'nglui mglw'nafh Cthulhu R'lyeh wgah-nagl ftaghn")
                    self.parse_bot_comments()
                    self.orangered()

                    sleep(30)
                end
            rescue SystemExit, Interrupt
                # Close cleanly
                @pstore.transaction do
                    @pstore['top'] = @top
                    @pstore['total'] = @total
                    @pstore['last_messages_check'] = @last_messages_check
                    @pstore['last_bot_check'] = @last_bot_check
                end

                @log.warn("System interrupt detected. All values saved to pstore.")
                @log.info("DOGESANSA BOT stopped at #{Time.now}.")
            end
        end

        def orangered
            messages = self.check_messages()
            @log.info("Messages checked. #{messages.count} messages found.")

            return if messages.empty?

            @last_messages_check = messages.first.full_name

            @pstore.transaction do
                @pstore['last_messages_check'] = @last_messages_check
            end

            messages.entries.each do |message|
                if message.body =~ /\+\/u\/dogesansa/ then
                    command = /\+\/u\/dogesansa\s+(.+)/.match(message.body)[1]
                    command.downcase!

                    case @today.to_s[-1]
                    when "1"
                        suffix = "st"
                    when "2"
                        suffix = "nd"
                    when "3"
                        suffix = "rd"
                    else
                        suffix = "th"
                    end

                    case command
                    when /^(all)/
                        @log.debug("+all requested by #{message.author}")
                        body = "Top shibe: #{@top.from} with #{@top.amount}. "
                        body = body + " All coins donated today: #{@total}."
                        body = body + "^[[help](http://www.reddit.com/r/dogesansa)]"
                        self.reply(message, body)
                    when /^(top|most)/
                        @log.debug("+top requested by #{message.author}")
                        body = "Most generous shibe for the #{@today.to_s + suffix} is "
                        body = body + "#{@top.from} with #{@top.amount} DOGE to #{@top.to}."
                        body = body + "^[[permalink](#{@top.permalink})] "
                        body = body + "^[[help](http://www.reddit.com/r/dogesansa)]"
                        self.reply(message, body)
                    when /^(total)/
                        @log.debug("+total requested by #{message.author}")
                        body = "#{@total} DOGE donated for the #{@today.to_s + suffix}. wow much generosity!"
                        body = body + "^[[help](http://www.reddit.com/r/dogesansa)]"
                        self.reply(message, body)
                    end
                end
            end
        end

        def check_messages()
            if defined?(@last_messages_check) then
                messages = @client.messages(:category => "inbox", :before => @last_messages_check)
            else
                messages = @client.messages(:category => "inbox", :limit => 25)
            end
        end

        def reply(comment, body)
            @client.submit_comment(comment, body)
            @log.info("Replied to #{comment.author} with #{body}")
            sleep(5)
        end

        def parse_bot_comments()
            @log.info("Searching /u/dogetipbot for new comments to set the @top donor.")
            if defined?(@last_bot_check) then
                comments = RedditKit.user_content('dogetipbot', :category => 'comments', :before => @last_bot_check)
            else
                comments = RedditKit.user_content('dogetipbot', :category => 'comments', :limit => 25)
            end

            return if comments.empty?

            @last_bot_check = comments.first.full_name
            @log.debug("Set the @last_bot_check to #{@last_bot_check}.")

            @pstore.transaction do
                @pstore['last_bot_check'] = @last_bot_check
            end

            @log.debug("#{comments.count} new comments found.")

            # If we notice the day has changed, reset our stats
            if not @today == comments.first.created_at.day then
                    @log.info("Day has changed. Resetting @top donor and @total.")
                    @top = nil
                    @total = 0.0
                    @today = Time.now.day
            end

            temp_biggest = 0
            temp_biggest = @top.amount unless @top.nil?
            temp_biggest_comment = nil

            comments.entries.each do |comment|
                m = /(\/u\/\S+)\s\^-&gt;\s\^(\/u\/\S+)\s__\^[^\x00-\x7F](\S+)/.match(comment.body)
                if not m.nil? then
                    # Do some comment self-checks
                    if m[1].empty? and m[2].empty? then
                        @log.debug("Invalid to/from. Skipping comment.")
                        next
                    end

                    if m[3].to_f == 0.0 then
                        @log.debug("Empty/invalid amount. Skipping comment.")
                        next
                    end

                    @total += m[3].to_f

                    if m[3].to_f > temp_biggest then
                        @log.debug("#{m[1].to_s} has donated more than @top with #{m[3].to_f}.")
                        temp_biggest = m[3].to_f
                        temp_biggest_comment = comment
                    end
                end
            end

            if not temp_biggest_comment.nil? then
                @top = Donor.new(temp_biggest_comment, @client.link(temp_biggest_comment.link_id))
                @log.info("@top has been set to #{@top.from} with #{@top.amount} dogecoins.")
                self.notify_newest_top_donor(temp_biggest_comment)
            end

            # Save our findings
            @pstore.transaction do
                @pstore['top'] = @top
                @pstore['total'] = @total
            end
        end

        def notify_newest_top_donor(comment)
            # Get the parent comment
            parent = @client.comment(comment.attributes[:parent_id])

            body = "Wow new top tipper for today, much rich! #{@top.from} is the new top tipper with #{@top.amount}."
            body = body + "^[[help](http://www.reddit.com/r/dogesansa)]"

            reply(comment, body)
        end
    end
end

raise "Not enough arguments." unless ARGV.length == 2

sansabot = DogeSansa::DSBot.new(ARGV[0], ARGV[1])
sansabot.main()
