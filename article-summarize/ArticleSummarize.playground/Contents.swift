//: Playground - noun: a place where people can play

import Cocoa

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

class ArticleSummarizer {

    private struct Sentence {
        var textRange: NSRange = NSRange(location: 0, length: 0)
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
        stopWords = ArticleSummarizer.loadStopWords(filename: "stop-words-english4")!
    }

    func summarize(text: String, numberOfSentences: Int) -> String {
        guard numberOfSentences > 0 else {
            return ""
        }

        var sentences: [Sentence] = []
        var sentence = Sentence()
        var wordFrequencies: [String: Int] = [:]

        tagger.string = text
        tagger.enumerateTags(in: text.nsrange,
                             scheme: .nameType,
                             options: options) { (tag, tokenRange, sentenceRange, _) in
                                // If we've switched to a new sentence then append the previous to the array
                                if sentence.textRange != sentenceRange {
                                    if sentence.textRange.length > 0 {
                                        sentence.index = sentences.count
                                        sentences.append(sentence)
                                    }
                                    sentence = Sentence()
                                    sentence.textRange = sentenceRange
                                }

                                // Convert to lowercase and if not a stopword the increase the word frequency.
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

        // Sort Sentences by ranking
        let sentencesByRanking = sentences.sorted { $0.ranking > $1.ranking }

        // Select the most important sentences
        let keySentences = sentencesByRanking.prefix(numberOfSentences).sorted { $0.index > $1.index }

        // Build Summary based on the most important sentences
        var summary = ""
        var firstSentence = true
        for sentence in keySentences {
            guard let text = text[sentence.textRange] else {
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
