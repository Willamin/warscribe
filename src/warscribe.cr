require "stout"
require "json"

module Warscribe
  VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}
  class_property recent_data : Hash(Symbol, String)?
end

server = Stout::Server.new(reveal_errors: true)
server.get("/read", &->handle(Stout::Context))
server.post("/write", &->handle_post(Stout::Context))

Warscribe.recent_data = nil

def handle(context)
  if Warscribe.recent_data
    context << Warscribe.recent_data.inspect
  else
    context << "nothing's been posted"
  end
end

def handle_post(context)
  Warscribe.recent_data = {
    :user_name => context.data.not_nil!["user_name"].as_s,
    :time      => Time.now.to_s,
    :text      => context.data.not_nil!["text"].as_s,
  }

  context << "thanks for making #holywars a better place. now get back to fighting!"
  context << "\n"
rescue
  context << "that's invalid data, stupid"
end

server.listen
