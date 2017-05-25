defmodule Mix.Tasks.Talon.Gen.Resource do
  @moduledoc """
  Generate the Talon Resource files

  Creates the resource files needed to manage a schema with Talon.

      mix talon.gen.resource User

  Creates the following files:

  * web/layout/talon/admin_lte/user_view.ex
  * lib/my_app/talon/user.ex

  ## Options

  * --theme=custom_theme -- create the layout file for a custom theme
  * --all-themes -- create the layout for all configured themes
  * --no-boilerplate -- don't include the boilerplate comments
  * --dry-run -- print what will be done, but don't create any files
  """
  use Mix.Task

  import Mix.Talon
  # import Mix.Generator

  @default_theme "admin_lte"

  # list all supported boolean options
  @boolean_options ~w(all_themes verbose boilerplate dry_run)a

  # complete list of supported options
  @switches [
    theme: :string
  ] ++ Enum.map(@boolean_options, &({&1, :boolean}))


  @doc """
  The entry point of the mix task.
  """
  @spec run(List.t) :: any
  def run(args) do
    {opts, parsed, _unknown} = OptionParser.parse(args, switches: @switches)

    # TODO: Add args verification
    # verify_args!(parsed, unknown)
    opts
    |> parse_options(parsed)
    |> do_config
    |> do_run
  end

  defp do_run(config) do
    log config, inspect(config), label: "config"
    config
    |> create_resource_file
    |> create_view
    |> print_instructions
  end

  def create_resource_file(config) do
    binding = Kernel.binding() ++ [base: config[:base], boilerplate: config.boilerplate, resource: config.resource]
    name = String.downcase config.resource
    unless config.dry_run do
      copy_from paths(),
        "priv/templates/talon.gen.resource", "", binding, [
          {:eex, "resource.ex", Path.join(lib_path(), "talon/#{name}.ex")}
        ], config
    end
    config
  end

  def create_view(config) do
    name = String.downcase config.resource
    unless config.dry_run do
      Enum.each config.themes, fn theme ->
        binding = Kernel.binding() ++ [base: config[:base], resource: config.resource, theme_module: Inflex.camelize(theme), theme_name: theme]
        copy_from paths(),
          "priv/templates/talon.gen.resource", "", binding, [
            {:eex, "view.ex", Path.join([web_path(), "views", "talon",theme, "#{name}_view.ex"])}
          ], config
      end
    end
    config
  end

  def print_instructions(config) do
    Mix.shell.info """

      Remember to update your config file with the resource module
        config :talon, :modules, [
          ...
          #{config.base}.Talon.#{config.resource}
        ]
      """
    config
  end


  defp do_config({bin_opts, _opts, parsed} = args) do
    binding =
      Mix.Project.config
      |> Keyword.fetch!(:app)
      |> Atom.to_string
      |> Mix.Phoenix.inflect

    resource =
      case parsed do
        [resource] ->
          resource
        other ->
          Mix.raise "Invalid arguments #{inspect other}"
      end

    %{
      themes: get_themes(args),
      verbose: bin_opts[:verbose],
      resource: resource,
      dry_run: bin_opts[:dry_run],
      package_path: get_package_path(),
      binding: binding,
      boilerplate: bin_opts[:boilerplate] || Application.get_env(:talon, :boilerplate, true),
      base: bin_opts[:module] || binding[:base],
    }
  end

  defp get_themes({opts, bin_opts, _parsed}) do
    cond do
      bin_opts[:all_themes] -> all_themes()
      opts[:theme] -> [opts[:theme]]
      all = all_themes() -> Enum.take(all, 1)
    end
  end

  defp all_themes do
    Application.get_env :talon, :themes, [@default_theme]
  end

  defp parse_options([], parsed) do
    {[], [], parsed}
  end
  defp parse_options(opts, parsed) do
    bin_opts = Enum.filter(opts, fn {k,_v} -> k in @boolean_options end)
    {bin_opts, opts -- bin_opts, parsed}
  end

  defp lib_path do
    Path.join("lib", to_string(Mix.Phoenix.otp_app()))
  end

  defp web_path do
    path1 = Path.join ["lib", to_string(Mix.Phoenix.otp_app()), "web"]
    path2 = "web"
    cond do
      File.exists? path1 -> path1
      File.exists? path2 -> path2
      true ->
        raise "Could not find web path '#{path1}'. Please use --web-path option to specify"
    end
  end

  defp paths do
    [".", :talon]
  end
end