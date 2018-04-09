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

class JerkException < Exception; end

class AirException < Exception; end

class VersionException < Exception; end

def handle(context)
  if context.data.not_nil!["text"].as_s.strip == "version"
    raise VersionException.new
  end

  now = Time.now
  username = context.data.not_nil!["user_name"].as_s.strip

  Warscribe::USER_TIMEOUT[username]?.try do |previous_submission_time|
    submitting_too_fast = previous_submission_time - now < 1.minutes
    raise JerkException.new if submitting_too_fast
  end
  Warscribe::USER_TIMEOUT[username] = now

  result = Warscribe::AIRTABLE.table("Wars").create(Airtable::Record.new({
    "Submitter"     => username,
    "Date Added"    => Time.now.to_s(Time::Format::ISO_8601_DATE_TIME.pattern).strip,
    "First Option"  => context.data.not_nil!["text"].as_s.split("vs")[0].strip,
    "Second Option" => context.data.not_nil!["text"].as_s.split("vs")[1].strip,
  }))

  if result.is_a? Airtable::Error
    raise AirException.new
  end

  context << "thanks for making #holywars a better place. now get back to fighting!"
  context << "\n"
rescue JerkException
  context << "stop being a jerk. chill"
rescue AirException
  context << "something's wrong in the air"
rescue VersionException
  context << Warscribe::VERSION
rescue
  context << "something didn't work... probably PEBCAK"
end

server.listen
