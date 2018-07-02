require "stout"
require "json"
require "airtable"
require "warsplitter"
require "failure"

# reopened from warsplitter
class War
  property username : String = ""

  def initialize; end

  def format_for_slack
    String.build do |s|
      s.puts "Hello and Good Morning Everybody!"
      s.puts "Today's war will be fought between:"
      s.puts "*#{first_option}*"
      s.puts "and"
      s.puts "*#{second_option}*"
      unless context.blank?
        s.puts "in the context of"
        s.puts "*#{context}*"
      end
      if username.size > 0
        s.puts "Today's war is brought to you by the letter *#{username[0].upcase}*, as in `#{username}`."
      end
    end
  end
end

module Warscribe
  extend self
  VERSION      = {{ `shards version #{__DIR__}`.chomp.stringify }}
  USER_TIMEOUT = Hash(String, Time).new
  AIRTABLE     = setup_airtable

  def setup_airtable
    api_key = ENV["AIRTABLE_API_KEY"]?
    base = ENV["AIRTABLE_BASE_ID"]?

    if api_key.nil? || base.nil?
      return nil
    end

    Airtable::Base.new(
      api_key: api_key,
      base: base
    )
  end

  def routes(server)
    server.post("/write") do |context|
      case text = (context.params["text"]? || "").to_s.strip
      when "version"
        version(context)
      when "todayswar"
        # todayswar(context)
        Slack.response(context, "this feature isn't finished.", true)
      when .starts_with?("wardeclaration")
        wardeclaration(text, context)
      else
        savewar(text, context)
      end
    rescue e
      Slack.response(context, "something didn't work... probably PEBCAK\n")
      STDERR.puts(e.backtrace.join("\n"))
    end
  end

  def version(context)
    Slack.response(context, Warscribe::VERSION, true)
  end

  def wardeclaration(text, context)
    # I'm too lazy to put in proper limits/auth restrictions,
    #   so _for now_ it'll just be me :D
    unless (context.params["user_name"]? || "willamin") == "willamin"
      Slack.response(context, "this feature isn't finished.", true)
    end

    username = text.split(" ")[1]
    text = text.split(" ")[2..-1].join(" ")

    war = War.new(text)
    war.username = username
    Slack.response(context, war.format_for_slack)
  rescue ex : Warsplitter::WarCrime
    Slack.response(context, ex.to_s)
    return
  end

  def todayswar(context)
    war = War.new
    war.first_option = ""
    war.second_option = ""
    war.context = ""
    war.username = ""

    Slack.response(context, war.format_for_slack, false)
  end

  def savewar(text : String, context : Stout::Context)
    now = Time.now
    username = context.params["user_name"]?.try(&.to_s.strip).fail { raise "Missing user_name" } || ""

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

    airtable_record = Airtable::Record.new({
      "Submitter"     => username,
      "Date Added"    => Time::Format.new("%FT%X%z").format(now).strip,
      "First Option"  => war.first_option,
      "Second Option" => war.second_option,
      "Context"       => war.context,
    })

    Warscribe::AIRTABLE
      .attempt do |airtable|
        result = airtable.table("Wars").create(airtable_record)

        if result.is_a? Airtable::Error
          Slack.response(context, "something's wrong in the air")
          return
        end
      end
      .fail do
        Slack.response(context, "airtable not found")
        STDERR.puts("Airtable API keys not provided. Here's what would've been written:")
        p(airtable_record)
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
