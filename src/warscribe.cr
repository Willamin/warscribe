require "stout"

module Warscribe
  VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}
end

server = Stout::Server.new(reveal_errors: true)
server.get("/read", &->handle(Stout::Context))
server.post("/write", &->handle_post(Stout::Context))

def handle(context)
  context << "Hello world"
end

def handle_post(context)
  context << "you posted"
  context << "\n"
  context << context.data.inspect
end

server.listen
