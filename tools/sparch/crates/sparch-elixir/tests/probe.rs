//! Grammar probe: learns the exact node kinds the presence and placement
//! port depends on, mirroring the FE workspace's round-trip-probe method.
//! Run with `cargo test -p sparch-elixir -- --nocapture probe` to inspect.

use sparch_elixir::elixir::ElixirFile;

#[test]
fn probe_dump_read_model_shape() {
    let src = r#"
defmodule Sportipedia.Catalog.Equipment.Widget.WidgetReadModel do
  @moduledoc """
  Represents a widget in the equipment.
  """
  use TypedEctoSchema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @schema_prefix "catalog"

  typed_schema "widgets" do
    field :title, :string
    field :weight, :float
    field :slug, :string

    timestamps()
  end

  @doc """
  Validates and prepares the widget read model for insertion.
  """
  def insert_changeset(read_model, attrs) do
    read_model
    |> cast(attrs, [:id, :title, :weight, :slug])
    |> validate_required([:title])
    |> unique_constraint(:slug, name: :widget_slug_index)
  end
end
"#;
    let file = ElixirFile::parse(src);
    assert!(file.parsed(), "probe source must parse");
    let dump = file.dump();
    // ERROR nodes anywhere would mean the grammar cannot see this shape.
    assert!(
        !dump.contains("ERROR"),
        "grammar probe found ERROR nodes:\n{dump}"
    );
    println!("{dump}");
}

#[test]
fn probe_dump_guard_and_binding_operator_kinds() {
    let src = r#"
defmodule M do
  def apply(%__MODULE__{} = aggregate, %WidgetCreated{} = event) when aggregate != nil do
    aggregate
  end

  def apply(%__MODULE__{} = _aggregate, %WidgetArchived{} = _event) do
    nil
  end
end
"#;
    let file = ElixirFile::parse(src);
    assert!(file.parsed(), "probe source must parse");
    let dump = file.dump();
    assert!(!dump.contains("ERROR"), "{dump}");

    // the presence question the aggregate blueprint asks: which event
    // struct does each `apply/2` clause match, guards and bindings included
    assert!(file.has_def_head_arg("apply", 2, "WidgetCreated{}"));
    assert!(file.has_def_head_arg("apply", 2, "WidgetArchived{}"));
    assert!(!file.has_def_head_arg("apply", 2, "WidgetNoted{}"));
    // `Source.render_arg` keeps the `%` on the `__MODULE__` struct — it is
    // not an `__aliases__` node — while aliased patterns render `Event{}`
    assert!(file.has_def_head_arg("apply", 2, "%__MODULE__{}"));
    // `Merge.after_def(:apply, 2)` sees the guarded clause too
    assert!(file.insert_offset_after_def("apply", 2).is_some());
    // arity 2 with the binding in the head
    assert!(file.has_def("apply", 2));
}
