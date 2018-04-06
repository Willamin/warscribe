require "stout"
require "./warscribe/*"

module Warscribe
  VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}
end

server = Stout::Server.new
server.default_route = "/"
Listener.routes(server)
server.listen
