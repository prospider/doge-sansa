require 'redditkit'
require 'pstore'
require 'dogesansa/donor'

module DogeSansa
    class DSBot
        def initialize(username, password)
            @username = username
            @client = RedditKit::Client.new(username, password)
            @log = Logger.new(STDOUT)
            log.level = Logger::DEBUG

            raise Exception("Login failed") if not @client.signed_in?

            log.info("DOGESANSA BOT STARTING")
            log.info("Developed by /u/Rhodesig")

            # Set up our records for top donor and coins donated
            @pstore = PStore.new("dogesansa.pstore")
            @pstore.transaction(true) do
                @top = pstore['top']
                @total = pstore['total']
            end

            log.info("Loaded @top: to: #{@top.to} from: #{@top.from} amount: #{@top.amount}")
            log.info("Loaded @total: #{@total}")

            self.parse_bot_comments()
            self.orangered()
        end

        def orangered
            messages = self.check_messages()
            log.debug("Messages checked. #{messages.count} messages found.")

            messages.entries.each do |message|
                if message.body ~= /\+\/u\/dogesansa/ then
                    command = /\+\/u\/dogesansa\s+(\S+)/.match(message.body)[1]
                    command.downcase!

                    case command
                    when 'top'
                        log.debug("+top requested by #{message.author}")
                        self.reply(message, "#{@top.from} has donated the most dogecoins today with #{@top.amount} to #{@top.to}.")
                    when 'total'
                        log.debug("+total requested by #{message.author}")
                        self.reply(message, "A total of #{@total} dogecoins have been donated to. wow much generosity!")
                    end
                end
            end
        end

        def check_messages()
            messages = @client.messages(:category => unread)
        end

        def reply(comment, body)
            submit_comment(comment, body)
            log.debug("Replied to #{comment.author} with #{body}")
        end

        def parse_bot_comments()
            log.debug("Searching /u/dogetipbot for new comments to set the @top donor.")
            if defined?(@last_bot_check) then
                comments = RedditKit.user_content(BOT, :category => 'comments', :before => @last_bot_check)
            else
                comments = RedditKit.user_conten(BOT, :category => 'comments')
            end

            @last_bot_check = comments.first.full_name

            return if comments.empty?
            log.debug("Pending comments not empty.")

            # If we notice the day has changed, reset our stats
            now = Time.now()
            if  now.day > comments.entries[-1].created_at.day or
                now.month > comments.entries[-1].created_at.month or
                now.year > comments.entries[-1].created_at.year then
                    log.info("Day has changed. Resetting @top donor and @total.")
                    @top = nil
                    @total = 0.0
            end

            temp_biggest = 0
            temp_biggest = @top.amount unless @top.nil?
            temp_biggest_comment = nil

            comments.entries.each do |comment|
                m = /(\/u\/\S+)\s->\s(\/u\/\S+)\s*Ð(\S+)/.match(comment.body)
                if not m.nil? then
                    # Do some comment self-checks
                    if m[1].empty? and m[2].empty? then
                        log.debug("Invalid to/from. Skipping comment.")
                        next
                    end

                    if m[3].to_f == 0.0 then
                        log.debug("Empty/invalid amount. Skipping comment.")
                        next
                    end

                    @total += m[3].to_f

                    if m[3].to_f > temp_biggest then
                        log.debug("#{m[1].to_s} has donated more than @top with #{m[3].to_f}.")
                        temp_biggest = m[3].to_f
                        temp_biggest_comment = comment
                    end
            end

            @top = Donor.new(comment, @client.link(comment.link_id))
            log.debug("@top has been set to #{@top.from}")

            # Save our findings
            @pstore.transaction do
                @pstore['top'] = @top
                @pstore['total'] = @total
            end
        end