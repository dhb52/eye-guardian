import Testing

func check(_ description: String, _ condition: @autoclosure () -> Bool,
           sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(condition(), Comment(rawValue: description), sourceLocation: sourceLocation)
}
