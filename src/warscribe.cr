require "stout"
require "json"
require "airtable"

module Warscribe
  VERSION  = {{ `shards version #{__DIR__}`.chomp.stringify }}
  AIRTABLE = Airtable::Base.new(
    api_key: ENV["AIRTABLE_API_KEY"],
    base: ENV["AIRTABLE_BASE_ID"]
  )
end

server = Stout::Server.new(reveal_errors: true)
server.post("/write", &->handle(Stout::Context))

def handle(context)
  result = Warscribe::AIRTABLE.table("Wars").create(Airtable::Record.new({
    "Submitter"     => context.data.not_nil!["user_name"].as_s.strip,
    "Date Added"    => Time.now.to_s(Time::Format::ISO_8601_DATE_TIME.pattern).strip,
    "First Option"  => context.data.not_nil!["text"].as_s.split("vs")[0].strip,
    "Second Option" => context.data.not_nil!["text"].as_s.split("vs")[1].strip,
  }))

  if result.is_a? Airtable::Error
    raise result.message
  end

  context << "thanks for making #holywars a better place. now get back to fighting!"
  context << "\n"
rescue
  context << "that's invalid data, stupid"
end

server.listen
