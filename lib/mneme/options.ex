defmodule Mneme.Options do
  @moduledoc false

  options = [
    action: [
      type: {:in, [:prompt, :accept, :reject]},
      default: :prompt,
      doc:
        "Controls how to update auto-assertions. Can be `:accept` or `:reject`, " <>
          "which will update or fail without prompting, or `:prompt`."
    ],
    prompter: [
      type: :atom,
      default: Mneme.Prompter.Terminal,
      doc:
        "Module implementing the `Mneme.Prompter` behaviour that will be used if " <>
          "a prompt is required"
    ]
  ]

  @options_schema NimbleOptions.new!(options)

  @test_attr :mneme
  @describe_attr :mneme_describe
  @module_attr :mneme_module

  @doc """
  Register ExUnit attributes for controlling Mneme behavior.
  """
  defmacro register_attributes do
    quote do
      ExUnit.Case.register_attribute(
        __MODULE__,
        unquote(@test_attr),
        accumulate: true
      )

      ExUnit.Case.register_describe_attribute(
        __MODULE__,
        unquote(@describe_attr),
        accumulate: true
      )

      ExUnit.Case.register_module_attribute(
        __MODULE__,
        unquote(@module_attr),
        accumulate: true
      )
    end
  end

  @doc """
  Returns documentation for Mneme options.
  """
  def docs do
    NimbleOptions.docs(@options_schema)
  end

  @doc """
  Fetch all valid Mneme options from the current test tags and environment.
  """
  def options(test_tags) do
    opts =
      test_tags
      |> collect_attributes()
      |> Enum.map(fn {k, [v | _]} -> {k, v} end)
      |> Keyword.new()

    opts
    |> validate_opts(test_tags)
    |> Map.new()
  end

  defp validate_opts(opts, test_tags) do
    case NimbleOptions.validate(opts, @options_schema) do
      {:ok, opts} ->
        opts

      {:error, %{key: key_or_keys} = error} ->
        %{file: file, line: line, module: module} = test_tags
        stacktrace_info = [file: file, line: line, module: module]

        IO.warn("[Mneme] " <> Exception.message(error), stacktrace_info)

        opts
        |> without_opts(key_or_keys)
        |> validate_opts(test_tags)
    end
  end

  defp without_opts(opts, key_or_keys), do: Keyword.drop(opts, List.wrap(key_or_keys))

  @doc """
  Collect all registered Mneme attributes from the given tags, in order of precedence.

  ## Examples

      iex> collect_attributes(%{})
      %{}

      iex> collect_attributes(%{registered: %{}})
      %{}

      iex> collect_attributes(%{
      ...>   registered: %{
      ...>     mneme: [[bar: 2], [bar: 1]]
      ...>   }
      ...> })
      %{bar: [2, 1]}

      iex> collect_attributes(%{
      ...>   registered: %{
      ...>      mneme_module: [[foo: 1]],
      ...>      mneme_describe: [[bar: 2], [foo: 2, bar: 1]],
      ...>      mneme: [[bar: 3, baz: 1]]
      ...>   }
      ...> })
      %{foo: [2, 1], bar: [3, 2, 1], baz: [1]}
  """
  def collect_attributes(%{registered: %{} = attrs}) do
    %{}
    |> collect_attributes(Map.get(attrs, @test_attr, []))
    |> collect_attributes(Map.get(attrs, @describe_attr, []))
    |> collect_attributes(Map.get(attrs, @module_attr, []))
  end

  def collect_attributes(_), do: %{}

  defp collect_attributes(acc, lower_priority) do
    new =
      for kw <- lower_priority,
          {k, v} <- kw,
          reduce: %{} do
        acc -> Map.update(acc, k, [v], &[v | &1])
      end
      |> Enum.map(fn {k, vs} -> {k, Enum.reverse(vs)} end)
      |> Map.new()

    Map.merge(acc, new, fn _, vs1, vs2 -> vs1 ++ vs2 end)
  end
end
