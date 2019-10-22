[
  locals_without_parens: [
    # plug
    plug: :*,
    parse: :*,
    serialize: :*,
    value: :*,
    match: :*,

    # ecto
    has_one: :*,
    has_many: :*,
    many_to_many: :*,
    embeds_one: :*,
    embeds_many: :*,
    belongs_to: :*,
    add: :*,
    from: :*,
    create: :*,
    drop: :*,
    modify: :*,
    rename: :*,
    table: :*,
    drop_if_exists: :*,

    # ecto migrations
    remove: 1,
    add: :*,
    execute: 1,
    create: 1,
    index: :*,

    # phoenix
    transport: :*,
    socket: :*,
    pipe_through: :*,
    forward: :*,
    options: :*,
    defenum: :*,
    get: :*,
    post: :*,
    delete: :*,
    patch: :*,
    head: :*,

    # absinthe
    field: :*,
    resolve: :*,
    arg: :*,
    list_of: :*,
    middleware: :*,
    resolve_type: :*,
    interface: :*,
    description: :*,

    # crash
    subscribe: 1,
    handle: 2,
    ignore: 1,
    assert_graphql_error: :*,

    # posextional
    row: 1,
    import_fields_from: 1,
    guesser: 1,
    empty: 1,
    fixed_value: 1,
    name: 1,
    progressive_number: :*,
    upgrade_to: 2
  ],
  line_length: 120
]
