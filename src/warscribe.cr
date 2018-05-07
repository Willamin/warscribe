require "stout"
require "json"
require "airtable"
require "warsplitter"

class War
  property username : String = ""

  def initialize; end
end

module Warscribe
  extend self
  VERSION      = {{ `shards version #{__DIR__}`.chomp.stringify }}
  USER_TIMEOUT = Hash(String, Time).new
  AIRTABLE     = Airtable::Base.new(
    api_key: ENV["AIRTABLE_API_KEY"],
    base: ENV["AIRTABLE_BASE_ID"]
  )

  def routes(server)
    server.post("/write") do |context|
      case text = context.params["text"].to_s.strip
      when "version"
        version(context)
      when "todayswar"
        # todayswar(context)
        Slack.response(context, "this feature isn't finished.", true)
      else
        savewar(text, context)
      end
    rescue e
      Slack.response(context, "something didn't work... probably PEBCAK\n #{e.backtrace}")
    end
  end

  def version(context)
    Slack.response(context, Warscribe::VERSION, true)
  end

  def todayswar(context)
    war = War.new
    war.first_option = "option A"
    war.second_option = "option B"
    war.context = "context"
    war.username = "someone"

    welcome_message = String.build do |s|
      s.puts "Hello and Good Morning Everybody!"
      s.puts "Today's war will be fought between:"
      s.puts "*#{war.first_option}*"
      s.puts "and"
      s.puts "*#{war.second_option}*"
      unless war.context.blank?
        s.puts "in the context of"
        s.puts "*#{war.context}*"
      end
      s.puts "Today's war is brought to you by the letter *#{war.username[0].upcase}*, as in `#{war.username}`."
    end

    Slack.response(context, welcome_message, false)
  end

  def savewar(text : String, context : Stout::Context)
    now = Time.now
    username = context.params["user_name"].to_s.strip

    Warscribe::USER_TIMEOUT[username]?.try do |previous_submission_time|
      submitting_too_fast = (now - previous_submission_time) < 1.minutes

      if submitting_too_fast
        Slack.response(context, "stop being a jerk. chill")
        return
      end
    end

    begin
      war = War.new(text)
    rescue ex : Warsplitter::WarCrime
      Slack.response(context, ex.to_s)
      return
    end

    result = Warscribe::AIRTABLE.table("Wars").create(Airtable::Record.new({
      "Submitter"     => username,
      "Date Added"    => Time.now.to_s(Time::Format::ISO_8601_DATE_TIME.pattern).strip,
      "First Option"  => war.first_option,
      "Second Option" => war.second_option,
      "Context"       => war.context,
    }))

    if result.is_a? Airtable::Error
      Slack.response(context, "something's wrong in the air")
      return
    end

    Warscribe::USER_TIMEOUT[username] = now
    Slack.response(context, "thanks for making <#C9P3GNQ66|holywars> a better place. now get back to fighting!", false)
  end

  module Slack
    extend self

    def response(context, message, ephemeral = true)
      response_type = "in_channel"
      response_type = "ephemeral" if ephemeral

      context << <<-JSON
    {
      "response_type": "#{response_type}",
      "text": "#{message}",
    }
    JSON
      context.response.content_type = "application/json"
    end
  end
end

server = Stout::Server.new(reveal_errors: true)
Warscribe.routes(server)
server.listen
