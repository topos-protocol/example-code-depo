require "./*"

module HardhatSpecs
  def self.run(path)
    output = `npx hardhat test #{path}`

    puts output
    Result.from(output)
  end

  class Result
    property output : String
    property passing : Int32
    property failing : Int32

    def self.from(output)
      passing = parse_passing(output)
      failing = parse_failing(output)

      new(output, passing, failing)
    end

    def self.parse_passing(output)
      (output =~ /^\s*(\d+) passing/m) ? $1.to_i : 0
    end

    def self.parse_failing(output)
      (output =~ /^\s*(\d+) failing/m) ? $1.to_i : 0
    end

    def initialize(output, passing, failing)
      @output = output
      @passing = passing
      @failing = failing
    end
  end
end
