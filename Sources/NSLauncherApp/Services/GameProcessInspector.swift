// GameProcessInspector.swift
//
// Finds game processes already running under Wine.
//
// Two callers need this. The launch preflight refuses to start a second copy into a prefix that
// already has one — a Wine prefix is single-tenant, and a second client attaching to the running
// wineserver deadlocks in the loader instead of failing. `WineService` uses it afterwards to tell
// "Wine's wrapper exited non-zero but the game is up" from a real failure.
//
// Matching covers both spellings of the executable. A direct launch hands Wine the POSIX path, but
// the steam.exe parent path — the default for Genshin, see `WineService` — hands it the Windows
// `Z:\…` form, and the command line shows whichever one Wine was given. Matching only the POSIX
// form made this return nothing for every launch that went through steam.exe, which is nearly all
// of them.
//
// Reads the process table directly with `libproc`/`sysctl` rather than shelling out to `/bin/ps`:
// this runs on every launch and every non-zero Wine exit, and a subprocess per check is pure
// overhead an in-process syscall does not have.

import Darwin
import Foundation

enum GameProcessInspector {
    /// Returns PIDs running the given executable, matched by either path spelling.
    static func runningProcessIDs(forExecutable executablePath: URL) async -> Set<Int32> {
        let needles = [executablePath.path, windowsPath(for: executablePath)]
        return Set(allPIDs().filter { pid in
            guard let commandLine = commandLine(forPID: pid) else { return false }
            return needles.contains { commandLine.contains($0) }
        })
    }

    /// Converts a macOS absolute path into the `Z:` drive path Wine presents to Windows programs.
    static func windowsPath(for url: URL) -> String {
        "Z:" + url.path.replacingOccurrences(of: "/", with: "\\")
    }

    /// Every PID currently on the system, via `proc_listpids` — the same source `ps` reads.
    static func allPIDs() -> [Int32] {
        let bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bufferSize > 0 else { return [] }

        // `proc_listpids` reports the buffer size to allocate, but the process table can grow
        // between that call and the next, so the second call's actual count (not the first call's
        // size) is what bounds the result — same race `ps` itself has to tolerate.
        var pids = [Int32](repeating: 0, count: Int(bufferSize) / MemoryLayout<Int32>.size)
        let actualSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, bufferSize)
        guard actualSize > 0 else { return [] }

        let count = Int(actualSize) / MemoryLayout<Int32>.size
        // PID 0 pads unused slots when the table shrank between the two calls above.
        return pids.prefix(count).filter { $0 > 0 }
    }

    /// The full command line (executable plus arguments) for one PID, matching what `ps`'s
    /// `command=` column shows — or nil for a PID this process cannot read (exited between
    /// `allPIDs()` and here, owned by another user, or a kernel task with no argument vector).
    static func commandLine(forPID pid: Int32) -> String? {
        guard let buffer = procArgs2Buffer(forPID: pid) else { return nil }
        return buffer.withUnsafeBytes { raw -> String? in
            guard let argc = argumentCount(in: raw) else { return nil }
            var offset = argvStartOffset(in: raw)
            var arguments: [String] = []
            arguments.reserveCapacity(Int(argc))
            for _ in 0..<argc {
                let start = offset
                while offset < raw.count, raw[offset] != 0 { offset += 1 }
                guard offset > start else { break }
                arguments.append(String(decoding: raw[start..<offset], as: UTF8.self))
                offset += 1
            }
            return arguments.joined(separator: " ")
        }
    }

    /// The current working directory of a PID, via `libproc`'s `PROC_PIDVNODEPATHINFO` — or nil for
    /// one this process cannot inspect.
    ///
    /// `WINEPREFIX` itself is NOT readable this way: `sysctl(KERN_PROCARGS2)` only returns another
    /// process's environment strings on older macOS — confirmed empirically against this SDK
    /// (macOS 26): a same-UID child process's `envp` comes back empty to everyone but itself, argv
    /// still included. Wine's own service processes (`winedevice.exe`, `services.exe`,
    /// `plugplay.exe`) run with their POSIX current directory set to the Windows one Wine gave them
    /// — normally `<prefix>/drive_c/windows/system32` — so cwd is the next-best per-prefix signal
    /// actually available without root.
    static func currentWorkingDirectory(forPID pid: Int32) -> String? {
        var info = proc_vnodepathinfo()
        let size = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, Int32(MemoryLayout<proc_vnodepathinfo>.stride))
        guard size > 0 else { return nil }
        return withUnsafeBytes(of: info.pvi_cdir.vip_path) { raw -> String? in
            guard let base = raw.baseAddress else { return nil }
            let path = String(cString: base.assumingMemoryBound(to: CChar.self))
            return path.isEmpty ? nil : path
        }
    }

    /// Raw `KERN_PROCARGS2` bytes for a PID, or nil for one this process cannot read.
    private static func procArgs2Buffer(forPID pid: Int32) -> [UInt8]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 4 else { return nil }

        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }
        return buffer
    }

    /// The leading `argc` `KERN_PROCARGS2` carries, or nil for an empty/malformed buffer.
    private static func argumentCount(in raw: UnsafeRawBufferPointer) -> Int32? {
        guard raw.count >= 4 else { return nil }
        let argc = raw.load(fromByteOffset: 0, as: Int32.self)
        return argc > 0 ? argc : nil
    }

    /// `KERN_PROCARGS2` follows the leading argc with the process's saved executable path as one
    /// NUL-terminated string, then NUL padding up to the start of `argv[0]`. See `<sys/sysctl.h>`
    /// and `ps`'s own source for this exact shape — there is no higher-level API for it.
    private static func argvStartOffset(in raw: UnsafeRawBufferPointer) -> Int {
        var offset = 4
        while offset < raw.count, raw[offset] != 0 { offset += 1 }
        while offset < raw.count, raw[offset] == 0 { offset += 1 }
        return offset
    }
}
