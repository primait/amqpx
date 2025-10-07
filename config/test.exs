import Config

config :logger, :console,
  format: "[$level] $message $metadata\n",
  metadata: [:error, :error_message]

config :logger, level: :error

config :amqpx,
  amqp_connection: [
    username: "amqpx",
    password: "amqpx",
    host: "rabbit",
    virtual_host: "/",
    heartbeat: 30,
    connection_timeout: 10_000,
    obfuscate_password: false
  ]

config :amqpx,
  amqp_connection_two: [
    name: ConnectionTwo,
    username: "amqpx",
    password: "amqpx",
    host: "rabbit_two",
    virtual_host: "/two",
    heartbeat: 30,
    connection_timeout: 10_000,
    obfuscate_password: false
  ]

config :amqpx,
  consumers: [
    %{
      handler_module: Amqpx.Test.Support.Consumer1
    },
    %{
      handler_module: Amqpx.Test.Support.Consumer2
    },
    %{
      handler_module: Amqpx.Test.Support.Consumer3,
      backoff: 10_000
    },
    %{
      handler_module: Amqpx.Test.Support.HandleRejectionConsumer,
      backoff: 10
    },
    %{
      handler_module: Amqpx.Test.Support.NoRequeueConsumer,
      backoff: 10,
      requeue_on_reject: false
    },
    %{
      handler_module: Amqpx.Test.Support.ConsumerConnectionTwo,
      connection_name: ConnectionTwo
    }
  ]

config :amqpx, Amqpx.Test.Support.Consumer1, %{
  queue: "test1",
  exchanges: [
    %{name: "topic1", type: :topic, routing_keys: ["amqpx.test1"], opts: [durable: true]}
  ],
  opts: [
    durable: true,
    arguments: [
      {"x-dead-letter-routing-key", :longstr, "test1_errored"},
      {"x-dead-letter-exchange", :longstr, "test1_errored_exchange"}
    ]
  ]
}

config :amqpx, Amqpx.Test.Support.Consumer2, %{
  queue: "test2",
  exchanges: [
    %{name: "topic2", type: :topic, routing_keys: ["amqpx.test2"]}
  ],
  opts: [
    durable: true,
    arguments: [
      {"x-dead-letter-exchange", :longstr, "test2_errored_exchange"}
    ]
  ]
}

config :amqpx, Amqpx.Test.Support.Consumer3, %{
  queue: "test3",
  exchanges: [
    %{name: "topic3", type: :fanout, opts: [durable: true]}
  ]
}

config :amqpx, Amqpx.Test.Support.HandleRejectionConsumer, %{
  queue: "test-rejection",
  exchanges: [
    %{
      name: "topic-rejection",
      type: :topic,
      routing_keys: ["amqpx.test-rejection"],
      opts: [redelivered: true]
    }
  ]
}

config :amqpx, Amqpx.Test.Support.NoRequeueConsumer, %{
  queue: "test-no-requeue",
  exchanges: [
    %{
      name: "topic-no-requeue",
      type: :topic,
      routing_keys: ["amqpx.test-no-requeue"]
    }
  ]
}

config :amqpx, Amqpx.Test.Support.ConsumerConnectionTwo, %{
  queue: "connection-two",
  exchanges: [
    %{name: "connection-two", type: :topic, routing_keys: ["amqpx.test_connection_two"]}
  ]
}

config :amqpx, :producer, %{
  publish_timeout: 5_000,
  publisher_confirms: false,
  exchanges: [
    %{
      name: "test_exchange",
      type: :topic,
      opts: [durable: true]
    }
  ]
}

config :amqpx, :producer2, %{
  name: :producer2,
  publish_timeout: 5_000,
  publisher_confirms: true,
  exchanges: [
    %{
      name: "test_exchange_2",
      type: :topic,
      opts: [durable: true]
    }
  ]
}

config :amqpx, :producer_connection_two, %{
  name: :producer_connection_two,
  connection_name: ConnectionTwo,
  publish_timeout: 5_000,
  publisher_confirms: true,
  exchanges: [
    %{
      name: "test_exchange_connection_two",
      type: :topic,
      opts: [durable: true]
    }
  ]
}

config :amqpx, :producer_with_retry_on_publish_error, %{
  name: :producer_with_retry_on_publish_error,
  publish_timeout: 5_000,
  publisher_confirms: true,
  exchanges: [
    %{
      name: "test_exchange_with_retry",
      type: :topic,
      opts: [durable: true]
    }
  ],
  publish_retry_options: [
    max_retries: 5,
    retry_policy: [
      :on_publish_error
    ]
  ]
}

config :amqpx, :producer_with_retry_on_publish_rejected, %{
  name: :producer_with_retry_on_publish_rejected,
  publish_timeout: 5_000,
  publisher_confirms: true,
  exchanges: [
    %{
      name: "test_exchange_with_retry",
      type: :topic,
      opts: [durable: true]
    }
  ],
  publish_retry_options: [
    max_retries: 5,
    retry_policy: [
      :on_publish_rejected
    ]
  ]
}

config :amqpx, :producer_with_retry_on_confirm_delivery_timeout, %{
  name: :producer_with_retry_on_confirm_delivery_timeout,
  publish_timeout: 5_000,
  publisher_confirms: true,
  exchanges: [
    %{
      name: "test_exchange_with_retry",
      type: :topic,
      opts: [durable: true]
    }
  ],
  publish_retry_options: [
    max_retries: 5,
    retry_policy: [
      :on_confirm_timeout
    ]
  ]
}

config :amqpx, :producer_with_retry_on_confirm_delivery_timeout_and_on_publish_error, %{
  name: :producer_with_retry_on_confirm_delivery_timeout_and_on_publish_error,
  publish_timeout: 5_000,
  publisher_confirms: true,
  exchanges: [
    %{
      name: "test_exchange_with_retry",
      type: :topic,
      opts: [durable: true]
    }
  ],
  publish_retry_options: [
    max_retries: 5,
    retry_policy: [
      :on_confirm_timeout,
      :on_publish_error
    ]
  ]
}

config :amqpx, :producer_with_jittered_backoff, %{
  name: :producer_with_jittered_backoff,
  publish_timeout: 5_000,
  publisher_confirms: true,
  exchanges: [
    %{
      name: "test_exchange_with_retry",
      type: :topic,
      opts: [durable: true]
    }
  ],
  publish_retry_options: [
    max_retries: 3,
    retry_policy: [
      :on_publish_error
    ],
    backoff: [
      base_ms: 10,
      max_ms: 10_000
    ]
  ]
}

config :amqpx,
  rabbit_manager_url: %{
    rabbit: "rabbit:15672",
    rabbit_two: "rabbit_two:15672"
  }

config :opentelemetry,
  traces_exporter: :none

config :opentelemetry, :processors, [
  {:otel_simple_processor, %{}}
]
