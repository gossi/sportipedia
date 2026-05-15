defmodule TypedStructOpenApi do
  @moduledoc """
  A TypedStruct plugin that automatically derives an OpenApiSpex-compatible
  schema from your structs, such as commands in commanded

  ## Usage

  Add the plugin to your `typedstruct` block:

      defmodule MyApp.Commands.CreateOrder do
        use TypedStruct

        typedstruct do
          plugin TypedStructOpenApi,
            description: "Create a new order",
            example: %{order_id: "abc-123", customer_id: "cust-456"}

          field :order_id, String.t(), enforce: true,
            doc: "UUID of the order"
          field :customer_id, String.t(), enforce: true,
            doc: "UUID of the customer placing the order"
          field :total_amount, non_neg_integer(), enforce: true,
            doc: "Total amount in cents"
          field :note, String.t(),
            doc: "Optional note attached to the order"
        end
      end

  This generates:

    - `MyApp.Commands.CreateOrder.schema/0` — returns an `%OpenApiSpex.Schema{}`
    - `MyApp.Commands.CreateOrder.__api_schema__/0` — alias for the above
    - The module gets `@behaviour OpenApiSpex.Schema` so it can be referenced
      directly in controller operation specs.

  ## Field options

  In addition to the standard TypedStruct `field` options, the plugin
  recognises:

    - `:doc` — maps to the `description` of the property in the schema.
      Falls back to the field name if omitted.
    - `:example` — inline example value for the property.
    - `:format` — OpenAPI format string, e.g. `"uuid"`, `"date-time"`.
    - `:enum` — list of allowed values, e.g. `["pending", "shipped"]`.

  ## Plugin options (on the `plugin` line)

    - `:description` — description of the whole schema object.
    - `:example` — map used as the schema-level example.
    - `:title` — defaults to the last segment of the module name.
  """

  use TypedStruct.Plugin

  # -------------------------------------------------------------------------
  # TypedStruct.Plugin callbacks
  # -------------------------------------------------------------------------

  @impl true
  @spec init(keyword()) :: Macro.t()
  defmacro init(opts) do
    quote do
      # Stash plugin options so `after_definition/1` can read them.
      Module.put_attribute(__MODULE__, :__oapi_plugin_opts__, unquote(opts))
      # Accumulator for per-field metadata collected by `field/3`.
      Module.register_attribute(__MODULE__, :__oapi_fields__, accumulate: true)
    end
  end

  @impl true
  @spec field(atom(), Macro.t(), keyword(), Macro.Env.t()) :: Macro.t()
  def field(name, type, opts, _env) do
    # Normalise the Elixir type AST into an OpenAPI type + extras.
    oapi_type = type_to_oapi(type)

    field_meta = %{
      name: name,
      oapi_type: oapi_type,
      doc: Keyword.get(opts, :doc, to_string(name)),
      example: Keyword.get(opts, :example),
      format: Keyword.get(opts, :format),
      enum: Keyword.get(opts, :enum)
    }

    quote do
      Module.put_attribute(__MODULE__, :__oapi_fields__, unquote(Macro.escape(field_meta)))
    end
  end

  @impl true
  @spec after_definition(keyword()) :: Macro.t()
  def after_definition(_opts) do
    quote unquote: false do
      # Retrieve accumulated data at compile time.
      plugin_opts = Module.get_attribute(__MODULE__, :__oapi_plugin_opts__) || []
      raw_fields = Module.get_attribute(__MODULE__, :__oapi_fields__) || []

      # TypedStruct accumulates fields in reverse order.
      fields = Enum.reverse(raw_fields)

      title =
        Keyword.get_lazy(plugin_opts, :title, fn ->
          __MODULE__
          |> Module.split()
          |> List.last()
        end)

      description = Keyword.get(plugin_opts, :description, title)
      schema_example = Keyword.get(plugin_opts, :example)
      required_fields = Module.get_attribute(__MODULE__, :enforce_keys)

      properties =
        Map.new(fields, fn field ->
          prop = %OpenApiSpex.Schema{
            type: field.oapi_type.type,
            description: field.doc
          }

          prop =
            if field.oapi_type[:items],
              do: Map.put(prop, :items, field.oapi_type.items),
              else: prop

          prop =
            if field.format || field.oapi_type[:format],
              do: Map.put(prop, :format, field.format || field.oapi_type[:format]),
              else: prop

          prop =
            if field.example,
              do: Map.put(prop, :example, field.example),
              else: prop

          prop =
            if field.enum,
              do: Map.put(prop, :enum, field.enum),
              else: prop

          {field.name, prop}
        end)

      # %OpenApiSpex.Schema{
      #   title: title,
      #   description: description,
      #   type: :object,
      #   properties: properties,
      #   required: required_fields,
      #   example: schema_example,
      #   "x-struct": __MODULE__
      # }

      schema_struct = %OpenApiSpex.Schema{
        title: title,
        description: description,
        type: :object,
        properties: properties,
        required: required_fields,
        example: schema_example,
        "x-struct": __MODULE__
      }

      # Freeze into module attributes so the functions below are pure.
      Module.put_attribute(__MODULE__, :__oapi_schema__, schema_struct)

      # Clean up temporary attributes.
      Module.delete_attribute(__MODULE__, :__oapi_plugin_opts__)
      Module.delete_attribute(__MODULE__, :__oapi_fields__)

      # -----------------------------------------------------------------------
      # Public API generated on every command module
      # -----------------------------------------------------------------------

      @behaviour OpenApiSpex.Schema

      @doc "Returns the OpenApiSpex schema derived from this command's TypedStruct definition."
      @spec schema() :: OpenApiSpex.Schema.t()
      def schema, do: @__oapi_schema__

      @doc "Alias for `schema/0`."
      @spec __api_schema__() :: OpenApiSpex.Schema.t()
      def __api_schema__, do: schema()
    end
  end

  # -------------------------------------------------------------------------
  # Type mapping — Elixir typespec AST → OpenAPI type descriptor
  # -------------------------------------------------------------------------

  # Helpers called at macro expansion time (compile time of the command module).

  defp type_to_oapi({:., _, [{:__aliases__, _, [:String]}, :t]}),
    do: %{type: :string}

  defp type_to_oapi({:., _, [{:__aliases__, _, [:DateTime]}, :t]}),
    do: %{type: :string, format: "date-time"}

  defp type_to_oapi({:., _, [{:__aliases__, _, [:Date]}, :t]}),
    do: %{type: :string, format: "date"}

  defp type_to_oapi({:., _, [{:__aliases__, _, [:NaiveDateTime]}, :t]}),
    do: %{type: :string, format: "date-time"}

  defp type_to_oapi({:., _, [{:__aliases__, _, [:Decimal]}, :t]}),
    do: %{type: :number}

  defp type_to_oapi(:integer), do: %{type: :integer}
  defp type_to_oapi(:non_neg_integer), do: %{type: :integer}
  defp type_to_oapi(:pos_integer), do: %{type: :integer}
  defp type_to_oapi(:float), do: %{type: :number}
  defp type_to_oapi(:boolean), do: %{type: :boolean}
  defp type_to_oapi(:atom), do: %{type: :string}
  defp type_to_oapi(:any), do: %{type: :object}
  defp type_to_oapi(:term), do: %{type: :object}
  defp type_to_oapi(:map), do: %{type: :object}
  defp type_to_oapi(:String), do: %{type: :string}

  # list(inner_type)
  defp type_to_oapi({:list, _, [inner]}),
    do: %{type: :array, items: %OpenApiSpex.Schema{type: elem(type_to_oapi(inner), 1)}}

  # [inner_type]  — shorthand list syntax in typespecs
  defp type_to_oapi([inner]),
    do: %{type: :array, items: %OpenApiSpex.Schema{type: elem(type_to_oapi(inner), 1)}}

  # nil-union:  SomeType.t() | nil  →  unwrap the non-nil side
  defp type_to_oapi({:|, _, [inner, nil]}), do: type_to_oapi(inner)
  defp type_to_oapi({:|, _, [nil, inner]}), do: type_to_oapi(inner)

  # unwrap internal structure
  defp type_to_oapi({inner, [line: _, column: _], _}), do: type_to_oapi(inner)

  # Fallback — unknown / complex type → treat as plain object
  defp type_to_oapi(_), do: %{type: :object}
end
