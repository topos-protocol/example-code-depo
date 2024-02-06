class ExampleFile
  @lines = [] of String
  @path : String

  def initialize(@path)
    @lines = File.read(@path).lines
  end

  def [](pos)
    @lines[pos]
  end

  def at(pos)
    self[pos - 1]
  end

  def between(range)
    adjusted_range = (range.begin - 1)..(range.end - 1)
    @lines[adjusted_range].join("\n")
  end
end
