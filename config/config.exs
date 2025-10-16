import Config

config :logger, :console, metadata: [:error, :error_message]

import_config "#{Mix.env()}.exs"
