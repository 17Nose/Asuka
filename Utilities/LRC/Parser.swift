import Foundation

// MARK: - 数据模型

/// 歌词行（增强版：支持逐字时间）
struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval         // 行开始时间（秒）
    let text: String               // 纯文本（去除时间标签）
    let words: [WordTiming]        // 逐字时间信息
    let translation: String?       // 对应翻译行

    static func == (lhs: LyricLine, rhs: LyricLine) -> Bool {
        lhs.time == rhs.time && lhs.text == rhs.text
    }
}

/// 逐字时间信息（KRC 格式）
struct WordTiming: Identifiable, Equatable {
    let id = UUID()
    let text: String               // 单个字/词
    let startTime: TimeInterval    // 相对行开始的时间偏移（秒）
    let duration: TimeInterval     // 持续时间（秒）

    static func == (lhs: WordTiming, rhs: WordTiming) -> Bool {
        lhs.startTime == rhs.startTime && lhs.text == rhs.text
    }
}

/// 歌词元数据
struct LyricsMetadata {
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var author: String = ""       // 歌词作者
    var offset: TimeInterval = 0  // 整体偏移（毫秒 → 秒）
    var length: TimeInterval = 0  // 歌曲总时长
}

/// 用于 UI 显示的歌词行
struct DisplayLyricLine: Identifiable {
    let id = UUID()
    let text: String
    let words: [WordTiming]
    let translation: String?
    let isCurrent: Bool
    let isPast: Bool
}

// MARK: - LRC 歌词解析器（增强版）

struct LRCParser {

    // MARK: - 主解析方法

    /// 解析 LRC / KRC 内容，返回带逐字时间信息的歌词行
    static func parse(_ content: String) -> (lines: [LyricLine], metadata: LyricsMetadata) {
        var lines: [LyricLine] = []
        var metadata = LyricsMetadata()
        let rawLines = content.components(separatedBy: .newlines)

        // 第一遍：提取元数据
        for rawLine in rawLines {
            parseMetadataLine(rawLine, into: &metadata)
        }

        // 第二遍：解析每行歌词
        for rawLine in rawLines {
            if let line = parseLyricLine(rawLine) {
                lines.append(line)
            }
        }

        // 排序
        lines.sort { $0.time < $1.time }

        // 应用整体偏移
        if metadata.offset != 0 {
            lines = lines.map { LyricLine(
                time: max(0, $0.time + metadata.offset),
                text: $0.text,
                words: $0.words,
                translation: $0.translation
            )}
        }

        return (lines, metadata)
    }

    /// 从文件路径解析
    static func parse(filePath: String) -> (lines: [LyricLine], metadata: LyricsMetadata)? {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            // 尝试其他编码
            if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
               let gbkContent = String(data: data, encoding: .gb_18030_2000) {
                return parse(gbkContent)
            }
            return nil
        }
        return parse(content)
    }

    // MARK: - 元数据解析

    private static func parseMetadataLine(_ raw: String, into meta: inout LyricsMetadata) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // 匹配 [ti:xxx], [ar:xxx] 等元数据标签
        let metaPattern = "\\[(ti|ar|al|au|by|offset|length):\\s*(.+?)\\]"
        guard let regex = try? NSRegularExpression(pattern: metaPattern, options: [.caseInsensitive]) else { return }

        guard let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let tagRange = Range(match.range(at: 1), in: trimmed),
              let valueRange = Range(match.range(at: 2), in: trimmed) else { return }

        let tag = trimmed[tagRange].lowercased()
        let value = String(trimmed[valueRange])

        switch tag {
        case "ti": meta.title = value
        case "ar": meta.artist = value
        case "al": meta.album = value
        case "au": meta.author = value
        case "by": meta.author = value
        case "offset":
            meta.offset = TimeInterval(Int(value) ?? 0) / 1000.0
        case "length":
            meta.length = parseMetaDuration(value)
        default: break
        }
    }

    /// 解析时长格式 "mm:ss" 或纯秒数
    private static func parseMetaDuration(_ value: String) -> TimeInterval {
        let parts = value.components(separatedBy: ":")
        if parts.count == 2,
           let min = Double(parts[0]),
           let sec = Double(parts[1]) {
            return min * 60 + sec
        }
        return TimeInterval(Int(value) ?? 0) / 1000.0
    }

    // MARK: - 歌词行解析

    private static func parseLyricLine(_ raw: String) -> LyricLine? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 跳过纯元数据行
        if trimmed.hasPrefix("[ti:") || trimmed.hasPrefix("[ar:") ||
           trimmed.hasPrefix("[al:") || trimmed.hasPrefix("[au:") ||
           trimmed.hasPrefix("[by:") || trimmed.hasPrefix("[offset:") ||
           trimmed.hasPrefix("[length:") {
            return nil
        }

        // 匹配时间标签 [mm:ss.xx]
        let timePattern = "\\[(\\d{1,2}):(\\d{2})(?:\\.(\\d{1,3}))?\\]"
        guard let timeRegex = try? NSRegularExpression(pattern: timePattern) else { return nil }

        let timeMatches = timeRegex.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
        guard !timeMatches.isEmpty else { return nil }

        // 提取时间戳
        var timestamps: [TimeInterval] = []
        for match in timeMatches {
            guard let minRange = Range(match.range(at: 1), in: trimmed),
                  let secRange = Range(match.range(at: 2), in: trimmed) else { continue }

            let min = Double(trimmed[minRange]) ?? 0
            let sec = Double(trimmed[secRange]) ?? 0
            var ms: Double = 0

            if match.range(at: 3).location != NSNotFound,
               let msRange = Range(match.range(at: 3), in: trimmed) {
                let msStr = trimmed[msRange]
                ms = Double(msStr) ?? 0
                if msStr.count == 2 { ms /= 100 }
                else if msStr.count == 3 { ms /= 1000 }
            }

            timestamps.append(min * 60 + sec + ms)
        }

        // 提取文本（去除所有时间标签）
        var text = trimmed
        for match in timeMatches.reversed() {
            if let range = Range(match.range, in: text) {
                text.removeSubrange(range)
            }
        }

        // 解析逐字标签 <start,duration>字
        let (plainText, wordTimings) = parseWordTimings(from: text,
                                                         lineStartTime: timestamps.first ?? 0)

        // 跳过纯空行
        guard !plainText.isEmpty else { return nil }

        // 取第一个时间戳作为行的开始时间
        return LyricLine(
            time: timestamps.first ?? 0,
            text: plainText,
            words: wordTimings,
            translation: nil
        )
    }

    // MARK: - 逐字时间解析（KRC 格式）

    /// 解析 KRC 逐字标签 <start_ms,duration_ms>文字
    static func parseWordTimings(from rawText: String, lineStartTime: TimeInterval) -> (plainText: String, timings: [WordTiming]) {
        var plainText = ""
        var timings: [WordTiming] = []

        // KRC 逐字格式: <1234,500>字
        // start_ms: 相对行开始的偏移（毫秒）
        // duration_ms: 该字持续时间（毫秒）
        let wordPattern = "<(\\d+),(\\d+)>"
        guard let regex = try? NSRegularExpression(pattern: wordPattern) else {
            return (rawText.trimmingCharacters(in: .whitespaces), [])
        }

        let nsText = rawText as NSString
        var lastEnd = 0
        var charIndex = 0

        let matches = regex.matches(in: rawText, range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            // 把标签之前的纯文本提取出来
            let prefixRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
            let prefix = nsText.substring(with: prefixRange).trimmingCharacters(in: .whitespaces)

            // 提取标签参数
            let startRange = match.range(at: 1)
            let durRange = match.range(at: 2)
            let startMs = Double(nsText.substring(with: startRange)) ?? 0
            let durMs = Double(nsText.substring(with: durRange)) ?? 0

            // 提取标签后的第一个字符
            let afterTag = match.range.location + match.range.length
            let charString: String
            if afterTag < nsText.length {
                let nextChar = nsText.substring(with: NSRange(location: afterTag, length: 1))
                charString = nextChar
            } else {
                charString = ""
            }

            // 把前缀加入纯文本
            if !prefix.isEmpty {
                plainText += prefix
                // 前缀中的每个字符给近似时间（按比例分配）
                for ch in prefix {
                    timings.append(WordTiming(
                        text: String(ch),
                        startTime: startMs / 1000.0,
                        duration: durMs / 1000.0
                    ))
                }
            }

            // 当前字
            if !charString.isEmpty {
                plainText += charString
                timings.append(WordTiming(
                    text: charString,
                    startTime: startMs / 1000.0,
                    duration: durMs / 1000.0
                ))
            }

            lastEnd = afterTag + (charString.isEmpty ? 0 : 1)
            charIndex += 1
        }

        // 最后一段纯文本
        if lastEnd < nsText.length {
            let suffix = nsText.substring(with: NSRange(location: lastEnd, length: nsText.length - lastEnd))
                .trimmingCharacters(in: .whitespaces)
            plainText += suffix
            for ch in suffix {
                timings.append(WordTiming(
                    text: String(ch),
                    startTime: 0,
                    duration: 0.3  // 默认持续时间
                ))
            }
        }

        if plainText.isEmpty {
            plainText = rawText.trimmingCharacters(in: .whitespaces)
        }

        return (plainText.trimmingCharacters(in: .whitespaces), timings)
    }

    // MARK: - 翻译歌词合并

    /// 将主歌词和翻译歌词合并到同一行
    static func mergeTranslation(mainLines: [LyricLine], translationContent: String) -> [LyricLine] {
        let (transLines, _) = parse(translationContent)
        var merged = mainLines

        for (i, mainLine) in merged.enumerated() {
            // 找时间匹配的翻译行（容差 0.2 秒）
            if let match = transLines.first(where: { abs($0.time - mainLine.time) < 0.2 }) {
                merged[i] = LyricLine(
                    time: mainLine.time,
                    text: mainLine.text,
                    words: mainLine.words,
                    translation: match.text
                )
            }
        }

        return merged
    }

    // MARK: - 查找当前播放位置

    /// 根据当前播放时间找到对应的歌词行索引
    static func findCurrentLineIndex(lines: [LyricLine], currentTime: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        var result: Int? = nil
        for (index, line) in lines.enumerated() {
            if line.time <= currentTime {
                result = index
            } else {
                break
            }
        }
        return result
    }

    /// 找到当前逐字索引
    static func findCurrentWordIndex(words: [WordTiming], lineElapsed: TimeInterval) -> Int? {
        guard !words.isEmpty else { return nil }
        var result: Int? = nil
        for (index, word) in words.enumerated() {
            if word.startTime <= lineElapsed {
                result = index
            } else {
                break
            }
        }
        return result
    }

    // MARK: - 生成显示用数据

    /// 获取用于 UI 显示的歌词行列表（带空行填充使当前行居中）
    static func displayLines(
        lines: [LyricLine],
        currentIndex: Int?,
        currentTime: TimeInterval = 0,
        paddingLines: Int = 5
    ) -> [DisplayLyricLine] {
        var display: [DisplayLyricLine] = []
        guard !lines.isEmpty else { return [] }

        for _ in 0..<paddingLines {
            display.append(DisplayLyricLine(text: "", words: [], translation: nil, isCurrent: false, isPast: true))
        }

        let activeIdx = currentIndex ?? -1
        for (index, line) in lines.enumerated() {
            let isCurrent = index == activeIdx
            let elapsed = isCurrent ? currentTime - line.time : 0

            display.append(DisplayLyricLine(
                text: line.text,
                words: elapsed > 0 ? line.words : line.words,
                translation: line.translation,
                isCurrent: isCurrent,
                isPast: index < activeIdx
            ))
        }

        for _ in 0..<paddingLines {
            display.append(DisplayLyricLine(text: "", words: [], translation: nil, isCurrent: false, isPast: false))
        }

        return display
    }

    /// 格式化时间标签
    static func formatTimestamp(_ time: TimeInterval) -> String {
        let min = Int(time) / 60
        let sec = Int(time) % 60
        let ms = Int((time - Double(Int(time))) * 100)
        return String(format: "[%02d:%02d.%02d]", min, sec, ms)
    }

    /// 生成 LRC 内容（用于保存）
    static func generateLRC(lines: [LyricLine], metadata: LyricsMetadata? = nil) -> String {
        var result = ""

        if let meta = metadata {
            if !meta.title.isEmpty { result += "[ti:\(meta.title)]\n" }
            if !meta.artist.isEmpty { result += "[ar:\(meta.artist)]\n" }
            if !meta.album.isEmpty { result += "[al:\(meta.album)]\n" }
            if !meta.author.isEmpty { result += "[by:\(meta.author)]\n" }
            if meta.offset != 0 { result += "[offset:\(Int(meta.offset * 1000))]\n" }
        }

        for line in lines {
            result += "\(formatTimestamp(line.time))\(line.text)\n"
        }

        return result
    }
}

// MARK: - GB18030 编码扩展

extension String.Encoding {
    static let gb_18030_2000 = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        )
    )
}
