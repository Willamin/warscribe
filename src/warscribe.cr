require "stout"
require "json"
require "airtable"
require "warsplitter"

module Warscribe
  VERSION  = {{ `shards version #{__DIR__}`.chomp.stringify }}
  AIRTABLE = Airtable::Base.new(
    api_key: ENV["AIRTABLE_API_KEY"],
    base: ENV["AIRTABLE_BASE_ID"]
  )

  USER_TIMEOUT = Hash(String, Time).new
end

server = Stout::Server.new(reveal_errors: true)
server.post("/write", &->handle(Stout::Context))

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

def handle(context)
  text = context.params["text"]?.try &.to_s.strip || ""

  if text == "version"
    context << Warscribe::VERSION
    return
  end

  now = Time.now
  username = context.params["user_name"]?.try &.to_s.strip || ""

  Warscribe::USER_TIMEOUT[username]?.try do |previous_submission_time|
    submitting_too_fast = (now - previous_submission_time) < 1.minutes

    if submitting_too_fast
      response(context, "stop being a jerk. chill")
      return
    end
  end
  Warscribe::USER_TIMEOUT[username] = now

  begin
    war = War.new(text)
  rescue ex : Warsplitter::WarCrime
    response(context, ex.to_s)
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
    response(context, "something's wrong in the air")
    return
  end

  response(context, "thanks for making <#C9P3GNQ66|holywars> a better place. now get back to fighting!", false)
rescue
  response(context, "something didn't work... probably PEBCAK")
end

server.listen
