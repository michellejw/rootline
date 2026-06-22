import Foundation
import MycogridSolver

func fail(_ msg: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((msg + "\n").utf8))
    exit(code)
}

// Parse --seed <int> --count <int> [--tier <name>] --out <path>
var seed: UInt64?
var count: Int?
var tier: String?
var out: String?

var i = 1
let argv = CommandLine.arguments
while i < argv.count {
    switch argv[i] {
    case "--seed":  i += 1; seed = i < argv.count ? UInt64(argv[i]) : nil
    case "--count": i += 1; count = i < argv.count ? Int(argv[i]) : nil
    case "--tier":  i += 1; tier = i < argv.count ? argv[i] : nil
    case "--out":   i += 1; out = i < argv.count ? argv[i] : nil
    default: fail("unknown argument: \(argv[i])", code: 2)
    }
    i += 1
}

guard let seed, let count, let out else {
    fail("usage: mycogrid-generate --seed <int> --count <int> [--tier <name>] --out <path>", code: 2)
}

let options = GenerateOptions(tierNames: tier.map { [$0] }, count: count, seed: seed)
do {
    let data = try generateBundleData(options) { line in
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }
    try data.write(to: URL(fileURLWithPath: out))
    print("wrote \(data.count) bytes to \(out)")
} catch let GenerateError.unknownTier(name) {
    fail("unknown tier: \(name) (valid: sprout, mycelium, ancient, oldGrowth)", code: 2)
} catch {
    fail("error: \(error)", code: 1)
}
