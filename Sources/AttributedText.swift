/**
 *  Atributika
 *
 *  Copyright (c) 2017 Pavel Sharanda. Licensed under the MIT license, as follows:
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in all
 *  copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *  SOFTWARE.
 */

import Foundation

public enum DetectionType {
    case tag(Tag)
    case hashtag(String, String)
    case mention(String, URL)
    case regex(String)
    case phoneNumber(String)
    case link(URL)
    case textCheckingType(String, NSTextCheckingResult.CheckingType)
    case range
}

public struct Detection {
    public let type: DetectionType
    public let style: Style
    public let range: Range<String.Index>
    public let level: Int
    
    public init(type: DetectionType, style: Style, range: Range<String.Index>, level: Int) {
        self.type = type
        self.style = style
        self.range = range
        self.level = level
    }
}

public protocol AttributedTextProtocol {
    var string: String {get}
    var detections: [Detection] {get}
    var baseStyle: Style {get}
}

extension AttributedTextProtocol {
    
    fileprivate func makeAttributedString(getAttributes: (Style)-> [AttributedStringKey: Any]) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: string, attributes: getAttributes(baseStyle))
        
        let sortedDetections = detections.sorted {
            $0.level < $1.level
        }
        
        for d in sortedDetections {
            let attrs = getAttributes(d.style)
            if attrs.count > 0 {
                attributedString.addAttributes(attrs, range: NSRange(d.range, in: string))
            }
        }
        
        return attributedString
    }
}

public final class AttributedText: AttributedTextProtocol {

    public let string: String
    public let detections: [Detection]
    public let baseStyle: Style
    
    public init(string: String, detections: [Detection], baseStyle: Style) {
        self.string = string
        self.detections = detections
        self.baseStyle = baseStyle
    }

    public lazy private(set) var attributedString: NSAttributedString  = {
        makeAttributedString { $0.attributes }
    }()

    public lazy private(set) var disabledAttributedString: NSAttributedString  = {
        makeAttributedString { $0.disabledAttributes }
    }()
}

extension AttributedTextProtocol {
    
    public func style(hashtagStyle: Style, mentionStyle: Style, linkStyle: Style) -> AttributedText {
        let (_, tagsInfo) = string.detectTags(transformers:  [TagTransformer.brTransformer])
        var ds: [Detection] = []
        tagsInfo.forEach { t in
            if t.tag.name != "a" { return }
            guard let href = t.tag.attributes["href"],
                  let urlString = href.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
            let detectionText = String(string[t.range])
            if let url = URL(string: urlString),
               let eleClass = t.tag.attributes["class"],
               eleClass == "former" {
                let lowerBound = string.index(t.range.lowerBound, offsetBy: -1)
                ds.append(Detection(type: .mention(detectionText, url), style: mentionStyle, range: lowerBound..<t.range.upperBound, level: t.level))
            } else if urlString.starts(with: "/q/") {
                let lowerBound = string.index(t.range.lowerBound, offsetBy: -1)
                let upperBound = string.index(t.range.upperBound, offsetBy: 1)
                ds.append(Detection(type: .hashtag(detectionText, urlString), style: hashtagStyle, range: lowerBound..<upperBound, level: t.level))
            } else if let url = URL(string: urlString) {
                ds.append(Detection(type: .link(url), style: linkStyle, range: t.range, level: t.level))
            }
        }
        return AttributedText(string: string, detections: ds, baseStyle: baseStyle).styleLinks(linkStyle)
    }
    
    /// style the whole string
    public func styleAll(_ style: Style) -> AttributedText {
        return AttributedText(string: string, detections: detections, baseStyle: baseStyle.merged(with: style))
    }
    
    public func style(regex: String, options: NSRegularExpression.Options = [], style: Style) -> AttributedText {
        let ranges = string.detect(regex: regex, options: options)
        let ds = ranges.map { Detection(type: .regex(regex), style: style, range: $0, level: Int.max) }
        return AttributedText(string: string, detections: detections + ds, baseStyle: baseStyle)
    }
    
    public func style(textCheckingTypes: NSTextCheckingResult.CheckingType, style: Style) -> AttributedText {
        let ranges = string.detect(textCheckingTypes: textCheckingTypes)
        let ds = ranges.map { Detection(type: .textCheckingType(String(string[$0]), textCheckingTypes), style: style, range: $0, level: Int.max) }
        return AttributedText(string: string, detections: detections + ds, baseStyle: baseStyle)
    }
    
    public func stylePhoneNumbers(_ style: Style) -> AttributedText {
        let ranges = string.detect(textCheckingTypes: [.phoneNumber])
        let ds = ranges.map { Detection(type: .phoneNumber(String(string[$0])), style: style, range: $0, level: Int.max) }
        return AttributedText(string: string, detections: detections + ds, baseStyle: baseStyle)
    }
    
    public func style(range: Range<String.Index>, style: Style) -> AttributedText {
        let d = Detection(type: .range, style: style, range: range, level: Int.max)
        return AttributedText(string: string, detections: detections + [d], baseStyle: baseStyle)
    }
    
    private func styleLinks(_ style: Style) -> AttributedText {
        let ranges = string.detect(textCheckingTypes: [.link])
        
        #if swift(>=4.1)
        let ds = ranges.compactMap { range in
            URL(string: String(string[range])).map { Detection(type: .link($0), style: style, range: range, level: Int.max) }
        }
        #else
        let ds = ranges.flatMap { range in
            URL(string: String(string[range])).map { Detection(type: .link($0), style: style, range: range) }
        }
        #endif
        
        return AttributedText(string: string, detections: detections + ds, baseStyle: baseStyle)
    }
}

extension String: AttributedTextProtocol {
    
    public var string: String {
        return self
    }
    
    public var detections: [Detection] {
        return []
    }
    
    public var baseStyle: Style {
        return Style()
    }
    
    public func style(tags: [Style], transformers: [TagTransformer] = [TagTransformer.brTransformer], tuner: (Style, Tag) -> Style = { s, _ in return  s}) -> AttributedText {
        let (string, tagsInfo) = detectTags(transformers: transformers)
        var ds: [Detection] = []
        
        tagsInfo.forEach { t in
            
            if let style = (tags.first { style in style.name.lowercased() == t.tag.name.lowercased() }) {
                ds.append(Detection(type: .tag(t.tag), style: tuner(style, t.tag), range: t.range, level: t.level))
            } else {
                ds.append(Detection(type: .tag(t.tag), style: Style(), range: t.range, level: t.level))
            }
        }
        return AttributedText(string: string, detections: ds, baseStyle: baseStyle)
    }
    
    public func style(tags: Style..., transformers: [TagTransformer] = [TagTransformer.brTransformer], tuner: (Style, Tag) -> Style = { s, _ in return  s}) -> AttributedText {
        return style(tags: tags, transformers: transformers, tuner: tuner)
    }

    public var attributedString: NSAttributedString {
        return makeAttributedString { $0.attributes }
    }

    public var disabledAttributedString: NSAttributedString {
        return makeAttributedString { $0.disabledAttributes }
    }
}

extension NSAttributedString: AttributedTextProtocol {
    
    public var detections: [Detection] {
        
        var ds: [Detection] = []
        
        enumerateAttributes(in: NSMakeRange(0, length), options: []) { (attributes, range, _) in
            if let range = Range(range, in: self.string) {
                ds.append(Detection(type: .range, style: Style("", attributes), range: range, level: Int.max))
            }
        }
        
        return ds
    }
    
    public var baseStyle: Style {
        return Style()
    }

    public var attributedString: NSAttributedString {
        return makeAttributedString { $0.attributes }
    }

    public var disabledAttributedString: NSAttributedString {
        return makeAttributedString { $0.disabledAttributes }
    }
}
