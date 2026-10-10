import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public enum PortProbe {
    /// Zaman aşımlı, bloklamayan POSIX connect.
    public static func isOpen(host: String = "127.0.0.1", port: UInt16, timeout: TimeInterval = 0.6) -> Bool {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        #if canImport(Glibc)
        hints.ai_socktype = Int32(SOCK_STREAM.rawValue)
        #else
        hints.ai_socktype = SOCK_STREAM
        #endif
        var res: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, String(port), &hints, &res) == 0, let first = res else { return false }
        defer { freeaddrinfo(res) }

        var cur: UnsafeMutablePointer<addrinfo>? = first
        while let ai = cur {
            if connectOnce(ai.pointee, timeout: timeout) { return true }
            cur = ai.pointee.ai_next
        }
        return false
    }

    private static func connectOnce(_ ai: addrinfo, timeout: TimeInterval) -> Bool {
        let fd = socket(ai.ai_family, ai.ai_socktype, ai.ai_protocol)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        let flags = fcntl(fd, F_GETFL, 0)
        guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0 else { return false }

        let rc = connect(fd, ai.ai_addr, ai.ai_addrlen)
        if rc == 0 { return true }
        guard errno == EINPROGRESS else { return false }

        var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        let ms = Int32(max(1, min(timeout, 60) * 1000))
        var pr: Int32
        repeat {
            pr = poll(&pfd, 1, ms)
        } while pr < 0 && errno == EINTR
        guard pr > 0 else { return false }

        var soError: Int32 = 0
        var len = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(fd, SOL_SOCKET, SO_ERROR, &soError, &len) == 0 else { return false }
        return soError == 0
    }
}
