import Darwin

public enum ProcessStartTimestamp {
    public static func read(pid: Int) -> UInt64? {
        guard let nativePID = pid_t(exactly: pid), nativePID > 0 else { return nil }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(nativePID, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return UInt64(info.pbi_start_tvsec) * 1_000_000 + UInt64(info.pbi_start_tvusec)
    }
}
