require "stout"
require "json"

module Warscribe
  VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}
  class_property recent_data : JSON::Any?
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
  context << "thanks for making #holywars a better place"
  context << "\n"
  Warscribe.recent_data = context.data
end

server.listen
