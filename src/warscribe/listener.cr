class Listener
  def self.routes(server)
    server.get("/", :root, &->render(Stout::Context))
  end

  def self.render(context)
    context << "hello world"
  end
end
