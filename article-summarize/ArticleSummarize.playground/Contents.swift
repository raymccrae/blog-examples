//: Playground - noun: a place where people can play

import UIKit

extension String {
    var nsrange: NSRange {
        return NSRange(location: 0, length: self.utf16.count)
    }

    subscript(nsrange: NSRange) -> Substring? {
        guard let range = Range(nsrange, in: self) else {
            return nil
        }
        return self[range]
    }
}

extension NSRange {

    init(from: NSRange, to: NSRange) {
        let endPosition = to.location + to.length
        self.location = from.location

        if endPosition > from.location {
            self.length = endPosition - from.location
        } else {
            self.length = to.length
        }
    }

}

func wordFrequencies(_ words: [String], stopwords: Set<String> = Set()) -> [String: Int] {
    return words.reduce(into: [:], { (frequencies, word) in
        if !stopwords.contains(word) {
            frequencies[word, default: 0] += 1
        }
    })
}

class ArticleSummarizer {

    private struct Sentence {
        var text: Substring?
        var words: [String] = []
        var index: Int = 0
        var ranking: Int = 0
    }

    let stopWords: Set<String>
    let options: NSLinguisticTagger.Options
    let tagger: NSLinguisticTagger

    init() {
        options = [.omitWhitespace, .omitPunctuation, .joinNames]
        let schemes = NSLinguisticTagger.availableTagSchemes(forLanguage: "en")
        tagger = NSLinguisticTagger(tagSchemes: schemes, options: Int(options.rawValue))
        stopWords = ArticleSummarizer.loadStopWords(filename: "stop-words-english1")!
    }

    func sentences(from text: String) -> [Substring] {
        var result: [Substring] = []
        var sentenceRange = NSRange(location: 0, length: 0)
        tagger.string = text
        tagger.enumerateTags(in: text.nsrange,
                                       scheme: .nameTypeOrLexicalClass, options: options) { (tag, nsrange, _, _) in
//                                        print(tag)
                                        if tag == NSLinguisticTag.sentenceTerminator {
                                            sentenceRange = NSRange(from: sentenceRange, to: nsrange)
                                            if let sentence = text[sentenceRange] {
                                                result.append(sentence)
                                            }
                                            sentenceRange = NSRange(location: sentenceRange.location + sentenceRange.length, length: 0)
                                        }
        }

        sentenceRange = NSRange(from: sentenceRange, to: text.nsrange)
        if let sentence = text[sentenceRange] {
            result.append(sentence)
        }

        return result
    }

    func summarize(text: String, numberOfSentences: Int) -> String {
        guard numberOfSentences > 0 else {
            return ""
        }

        var sentences: [Sentence] = []
        var sentence = Sentence()
        var currentSentenceRange = NSRange(location: 0, length: 0)
        var wordFrequencies: [String: Int] = [:]

        tagger.string = text
        tagger.enumerateTags(in: text.nsrange,
                             scheme: .nameTypeOrLexicalClass,
                             options: options) { (tag, tokenRange, sentenceRange, _) in
                                guard let tag = tag else {
                                    return
                                }
//                                print("\(tag) - \(tokenRange) - \(sentenceRange)")

                                if currentSentenceRange != sentenceRange {
                                    if let sentenceText = text[currentSentenceRange] {
                                        sentence.text = sentenceText
                                    }
                                    sentence.index = sentences.count
                                    sentences.append(sentence)
                                    sentence = Sentence()
                                    currentSentenceRange = sentenceRange
                                }

                                if let word = text[tokenRange]?.lowercased() {
                                    if !stopWords.contains(word) {
                                        wordFrequencies[word, default: 0] += 1
                                        sentence.words.append(word)
                                    }
                                }

        }

        // Calculate Sentence Rankings
        for i in sentences.indices {
            sentences[i].ranking = sentences[i].words.reduce(0, { (rank, word) -> Int in
                rank + wordFrequencies[word, default: 0]
            })
        }

        let sentencesByRanking = sentences.sorted { $0.ranking > $1.ranking }
        let keySentences = sentencesByRanking.prefix(numberOfSentences).sorted { $0.index > $1.index }
        var summary = ""
        var firstSentence = true
        for sentence in keySentences {
            guard let text = sentence.text else {
                continue
            }

            if firstSentence {
                firstSentence = false
            } else {
                summary.append(" ")
            }

            summary.append(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return summary
    }

    static func loadTextFile(filename: String) -> String? {
        guard let path = Bundle.main.path(forResource: filename, ofType: "txt") else {
            return nil
        }
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            return content
        } catch {
            return nil
        }
    }

    private static func loadStopWords(filename: String) -> Set<String>? {
        guard let content = loadTextFile(filename: filename) else {
            return nil
        }

        let lines = content.components(separatedBy: .newlines)
        return Set<String>(lines)
    }

}

let article = ArticleSummarizer.loadTextFile(filename: "nasa_article")!
let summarizer = ArticleSummarizer()
let summary = summarizer.summarize(text: article, numberOfSentences: 3)
print(summary)
