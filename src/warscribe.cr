require "stout"
require "json"
require "airtable"

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

def handle(context)
  text = context.params["text"]?.try &.to_s.strip || ""

  if text == "version"
    context << Warscribe::VERSION
    return
  end

  now = Time.now
  username = context.params["user_name"]?.try &.to_s.strip || ""

  Warscribe::USER_TIMEOUT[username]?.try do |previous_submission_time|
    submitting_too_fast = previous_submission_time - now < 1.minutes
    if submitting_too_fast
      context << "stop being a jerk. chill"
      return
    end
  end
  Warscribe::USER_TIMEOUT[username] = now

  first = text.split("vs")[0]?.try &.strip || ""
  second_and_third = text.split("vs")[1]?.try &.strip || ""
  second = second_and_third.split(";")[0]?.try &.strip || ""
  third = second_and_third.split(";")[1]?.try &.strip || ""

  result = Warscribe::AIRTABLE.table("Wars").create(Airtable::Record.new({
    "Submitter"     => username,
    "Date Added"    => Time.now.to_s(Time::Format::ISO_8601_DATE_TIME.pattern).strip,
    "First Option"  => first,
    "Second Option" => second,
    "Context"       => third,
  }))

  if result.is_a? Airtable::Error
    context << "something's wrong in the air"
    return
  end

  context << "thanks for making #holywars a better place. now get back to fighting!"
rescue
  context << "something didn't work... probably PEBCAK"
end

server.listen
