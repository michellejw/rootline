import Foundation
import MycogridSolver

func pad(_ s: String, _ w: Int) -> String {
    s.count >= w ? s : s + String(repeating: " ", count: w - s.count)
}

func fail(_ msg: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((msg + "\n").utf8))
    exit(code)
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    fail("usage: mycogrid-validate <pool | file <path>>", code: 2)
}

switch args[1] {
case "pool":
    let reports = auditPool()
    print("\(pad("tier/grove", 22)) \(pad("verdict", 9)) \(pad("guesses", 8)) \(pad("match", 6)) \(pad("oracle", 7)) result")
    var anyFail = false
    for r in reports {
        if !r.passed { anyFail = true }
        print("\(pad(r.label, 22)) \(pad(r.verdict.rawValue, 9)) \(pad(String(r.guesses), 8)) \(pad(r.matchesStored ? "yes" : "no", 6)) \(pad(r.oracleOK ? "yes" : "no", 7)) \(r.passed ? "PASS" : "FAIL")")
    }
    exit(anyFail ? 1 : 0)

case "file":
    guard args.count >= 3 else { fail("usage: mycogrid-validate file <path>", code: 2) }
    let result: SolveResult
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: args[2]))
        result = solve(try loadClues(fromJSON: data))
    } catch {
        fail("error reading \(args[2]): \(error)", code: 2)
    }
    print("verdict: \(result.verdict.rawValue)")
    print("guesses: \(result.trace.guesses), maxDepth: \(result.trace.maxDepth)")
    if result.verdict == .multiple { print("NOT UNIQUE — two distinct loops exist") }
    exit(result.verdict == .unique ? 0 : 1)

default:
    fail("unknown command: \(args[1])", code: 2)
}
