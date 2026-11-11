defmodule Sportipedia.Catalog.Athlete.Position.Validators.UniqueSlugByEquipment do
  @moduledoc """
  Validates the 'unique-slug-by-equipment' rule: A position's canonical slug is its raw slug, namespaced by the slug of its referenced equipment when bound and bare otherwise — `<equipment-slug>/<position-slug>` for a bound position, `<position-slug>` for an unbound one. No two positions in the catalog may share the same slug. Because equipment slugs are themselves unique across all equipment (the `unique-equipment-slug` invariant on apparatus and instrument), the equipment segment of the namespaced form is distinct per piece of equipment, so it is the `<position-slug>` that must not repeat for two positions bound to the same equipment.

  The rule is asked of the raw slug, so the check is the invariant's own
  reduction: a live row with the same raw slug **inside the same equipment
  namespace**. That namespace is the *effective* one, resolved before the lookup:
  a reference the command carries wins; on an edit whose patch carries neither
  reference the **stored binding** decides; a create that binds nothing is
  unbound. Reading it off the command alone would check a patch that renames the
  slug in the bare namespace while the row actually lands in its stored
  equipment's — a false acceptance the unique index then turns into a projection
  failure, and a false rejection when the bare slug is taken by an unbound
  position. Namespace equality is enough either way: equipment slugs are globally
  unique, so two positions in one namespace derive the same slug, and a
  bound and an unbound position can never derive it (the namespaced form carries
  a `/`).

  The rule is also asked of a **reference-only move**: a patch that carries a
  new equipment reference and no slug moves the stored raw slug into that
  namespace, so `validate_namespace_move/2` re-checks the stored slug in the
  patch's effective namespace before dispatch — the invariant is re-validated
  after the change, and a collision answers 422, never a projection failure.
  """
  use Vex.Validator

  alias Sportipedia.Catalog.Athlete.Position.PositionInternal
  alias Sportipedia.Support.Validators.UuidValidator

  @doc """
  Validates the given slug value.
  """
  # `term()`, not `String.t()`: the value reaches here straight off the request.
  # The slug field is required, so this pair carries no skip option and a blank
  # value does arrive — `presence` is the rule that speaks for it, and a lookup
  # would raise on it.
  @spec validate(term(), map()) :: :ok | {:error, :slug_exists}
  def validate(slug, context) do
    if non_blank_slug?(slug) do
      check_slug_in_effective_namespace(slug, context)
    else
      :ok
    end
  end

  @doc """
  Validates a reference-only namespace move: a patch that carries an equipment
  reference and no slug still moves the position's **stored** raw slug into the
  patch's namespace, so that slug must be re-checked there before dispatch.
  Without this, the accepted patch ends in the projector colliding with the
  `slug` unique index — a 500 where the client's 422 belongs.

  It abstains when the patch carries no reference (its `allow_nil: true` pair
  never runs), and when the patch carries a slug — then `validate/2` on the
  slug field is the rule that speaks, over the very same effective namespace.
  """
  @spec validate_namespace_move(term(), map()) :: :ok | {:error, :slug_exists}
  def validate_namespace_move(_reference, context) do
    case Map.get(context, :slug) do
      nil ->
        # The subject is read through the constituent's own internal API — the
        # accessor `position-exists` uses; this rule adds no new port. A
        # malformed or unknown address abstains: `position-exists` gives that
        # verdict, and `position_by_id/1` would raise on the malformed one.
        with id when not is_nil(id) <- Map.get(context, :id),
             true <- UuidValidator.valid_uuid?(id),
             stored when not is_nil(stored) <- PositionInternal.position_by_id(id),
             true <- non_blank_slug?(stored.raw_slug) do
          check_slug_in_effective_namespace(stored.raw_slug, context)
        else
          _ -> :ok
        end

      _supplied_slug ->
        :ok
    end
  end

  defp non_blank_slug?(slug), do: is_binary(slug) and slug != ""

  # The check both entry points share: the slug lands in the effective
  # namespace, and any row already holding it there that is not the subject
  # itself violates the invariant.
  defp check_slug_in_effective_namespace(slug, context) do
    with true <- namespace_addressable?(context),
         {:ok, apparatus_id, instrument_id} <- effective_namespace(context),
         position when not is_nil(position) <-
           PositionInternal.position_by_slug_and_equipment(slug, apparatus_id, instrument_id),
         false <- owns_value?(position, context) do
      {:error, :slug_exists}
    else
      _ -> :ok
    end
  end

  # A reference that cannot name an equipment row addresses no namespace, and it
  # is `equipment-exists` that rejects it; this rule abstains rather than cast a
  # value the reference column could not hold.
  defp namespace_addressable?(context) do
    Enum.all?(equipment_references(context), fn reference ->
      is_nil(reference) or UuidValidator.valid_uuid?(reference)
    end)
  end

  # The namespace the raw slug will land in. Resolution in order: a reference the
  # command carries wins — a patch that re-supplies one is checked like a new
  # binding, and when both are carried `at-most-one-equipment` is the rule that
  # rejects, so looking the pair up is harmless. With neither carried, the stored
  # binding decides.
  defp effective_namespace(context) do
    case equipment_references(context) do
      [nil, nil] -> stored_namespace(context)
      [apparatus_id, instrument_id] -> {:ok, apparatus_id, instrument_id}
    end
  end

  # The stored binding is read through the constituent's own internal API — the
  # accessor `position-exists` uses, for a question this rule may not answer
  # without it. `at-most-one-equipment` guarantees the stored row carries at most
  # one reference, and the lookup orders apparatus over instrument.
  defp stored_namespace(context) do
    case Map.get(context, :id) do
      nil ->
        {:ok, nil, nil}

      id ->
        # A malformed address is `position-exists`' verdict, and `position_by_id/1`
        # would raise on it: abstain, and ask nothing of the store.
        if UuidValidator.valid_uuid?(id) do
          case PositionInternal.position_by_id(id) do
            # No row answers the address. On the create path this is the normal
            # state — `catalog_position/1` mints the id before dispatch — so nothing
            # is bound yet and the bare namespace is the effective one: abstaining
            # here would let a duplicate unbound slug through validation into a
            # projection the unique index then refuses. An edit of an address that
            # is not in the catalog takes the same branch, and `position-exists`
            # answers `:not_found`, which `Sportipedia.Support.ErrorClassifier`
            # makes the whole command's verdict — what this rule adds cannot muddy
            # the classification. Pinned both ways in the operation tests.
            nil ->
              {:ok, nil, nil}

            row ->
              {:ok, row.apparatusId, row.instrumentId}
          end
        else
          :abstain
        end
    end
  end

  # The position that already owns the value passes: that is the edit case, where
  # the same raw slug is re-supplied for the position that carries it — including
  # through the stored binding, where the row found is the addressed row itself.
  defp owns_value?(position, context) do
    Map.get(context, :id) == position.id
  end

  defp equipment_references(context) do
    [Map.get(context, :apparatusId), Map.get(context, :instrumentId)]
  end
end
