defmodule Mix.Tasks.Package do
  use Mix.Task

  @shortdoc "Packages our release for distribution"
  def run(_) do
    cmd("mix", ["release"])
    cmd("rm", ["-rf", "package"])
    cmd("mkdir", ["package"])
    cmd("cp", ["-r", "_build/dev/rel/blockchain_node", "package/"])
    cmd("tar", ["-czf", "package/blockchain_node.tgz", "-C", "package/blockchain_node", "."])
  end

  defp cmd(name, args \\ []) do
    {response, _code} = System.cmd(name, args)
    if response !== "", do: IO.puts(response)
  end
end
