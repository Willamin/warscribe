require "stout"

module Warscribe
  VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}
end

server = Stout::Server.new
server.default_route = "/"
server.get("/", &->render(Stout::Context))
server.listen

def render(context)
  context << "Hello world"
end
