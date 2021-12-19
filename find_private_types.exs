
defmodule FindPrivateTypes do
  @moduledoc ~S"""
  Used to find types in function specs which haven't
  been exported.

  Usage:
    iex> FindPrivateTypes.in_all_modules()
    ...
    Module: file
    [:posix_file_advise, :delete_option, :sendfile_option]
    ...

  Will search all Erlang kernel modules.
  """

  @doc ~S"""
  Processes all Erlang kernel modules and finds
  types referenced in function specs but not exported.
  The module name is only printed if it has types that
  fit this criteria along with the list of types that
  are not exported but are referenced.
  e.g.:
  ```
  Module: file
  [:posix_file_advise, :delete_option, :sendfile_option]
  ```
  """
  def in_all_modules() do
    modules = :code.all_available()

    # Only process kernel modules
    for {module, path, _loaded} <- modules,
        path
        |> to_string
        |> String.contains?("/kernel-")
    do
      case process_module(String.to_atom(to_string(module))) do
        {:ok, private_types} ->
          # Only print the module if there were private types
          if length(private_types) > 0 do
            IO.puts("")
            IO.puts("Module: #{module}")
            IO.inspect(private_types)
          end
        _ -> nil # ignore errors (these will only be doc not found errors)
      end
    end
  end

  @doc """
  For a module, gets the docs and finds private types.
  Returns:
    {:ok, [private_type]}
    {:error, error}
  """
  def process_module(module) when is_atom(module) do
    case Code.fetch_docs(module) do
      {:error, error} -> {:error, error}
      {:docs_v1, _, :erlang, _, _, _, entries} ->
        private_types = get_private_types(entries)
        {:ok, private_types}
    end
  end

  @doc """
  Process the entries (types and functions) for a module.
  First get all of the types, which will be the exported types.
  Then get all the user types referenced in the functions.
  Return the user types minus the exported types.
  """
  def get_private_types(entries) do
    exported_types =
      for {{:type, type, _ary}, _file, _sig_text, _doc, _sig} <- entries do
        type
      end

    user_types =
      for {{:function, _function, _ary}, _file, _sig_text, _doc, %{signature: [sig | _]}} <- entries,
        reduce: []
      do
        user_types ->
          # IO.puts("Function: #{function}/#{ary}")
          user_types ++ find_user_types(sig)
      end
      |> Enum.uniq()

    # IO.puts("Types referenced in function specs:")
    # IO.inspect(user_types)
    # IO.puts("Types exported by module:")
    # IO.inspect(exported_types)
    _private_types = user_types -- exported_types
    # IO.puts("Types referenced, but not exported:")
    # IO.inspect(private_types)
  end

  @doc """
  Looks through the function signature `sig` and returns any user types.

  There are two places where a user type can occur:
    The return type
    Constraints on the function parameters
  Additionally there are two types of functions:
    :bounded_fun which lists constraints for parameters
      and contains a :fun
    :fun which doesn't list constraints for parameters
  So the structure is either:
    :bounded_fun
      :fun
        :product (which are the parameters)
        result
      :constraints
  or:
    :fun
      :product (which are the parameters)
      result
  """
  def find_user_types(sig) when is_tuple(sig) do
    {function, constraints} =
      case sig do
        {
          :attribute, _, :spec, {
            _ary, [{:type, _, :bounded_fun, [function, constraints | _]} | _]
          }
        } -> {function, constraints}
        {
          :attribute, _, :spec, {
            _ary, [function | _]
          }
        } -> {function, []}
      end

    # Extract the result spec from the function
    {:type, _, :fun, [
      {:type, _, :product, _params}, result | _]} = function

    # Recursively extract user types from the result spec
    user_types = nested_user_types(result)

    # Recursively extract user types from the constraints
    for {:type, _, :constraint, [_is_subtype, [_var, constraint]]} <- constraints,
      reduce: user_types
    do
      user_types ->
        user_types ++ nested_user_types(constraint)
    end
  end

  @doc """
  A type can have subtypes. For example a union consists of subtypes.
  Recurse through the type, collating any user_types.
  """
  def nested_user_types(type) when is_tuple(type) do
    case type do
      {:user_type, _, user_type, _} ->
        [user_type] # what we are after
      {:var, _, _} ->
        [] # var is a parameter name not a type
      {:atom, _, _atom} ->
        [] # Not a user type
      {:ann_type, _, [_var, nested_type]} ->
        nested_user_types(nested_type)
      {:remote_type, _, _module_type} ->
        [] # Ignore, as it references a type in other module
      {:type, _, :map, :any} ->
        [] # not a user type
      {:type, _, _, nested_types} ->
        for nested_type <- nested_types, reduce: [] do
          user_types ->
            user_types ++ nested_user_types(nested_type)
        end
      {:op, _, _op, _val} ->
        [] # ignore
      {:integer, _, _val} ->
        [] # ignore
    end
  end

end

# FindPrivateTypes.process_module(:file)
FindPrivateTypes.in_all_modules()
