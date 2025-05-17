extension WindowTransition: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case value
        case a
        case b
        case behavior
        case breakpoints
    }

    private enum CaseType: String, Codable {
        case absolute
        case moveToScreen
        case snapToGrid
        case moveLeft
        case moveRight
        case moveUp
        case moveDown
        case resizeLeft
        case resizeRight
        case resizeTop
        case resizeBottom
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
            case .absolute(let value):
                try container.encode(CaseType.absolute, forKey: .type)
                try container.encode(value, forKey: .value)
            case .moveToScreen(let a, let b):
                try container.encode(CaseType.moveToScreen, forKey: .type)
                try container.encode(a, forKey: .a)
                try container.encode(b, forKey: .b)
            case .snapToGrid(let behavior, let breakpoints):
                try container.encode(CaseType.snapToGrid, forKey: .type)
                try container.encode(behavior, forKey: .behavior)
                try container.encode(breakpoints, forKey: .breakpoints)
            case .moveLeft(let breakpoints):
                try container.encode(CaseType.moveLeft, forKey: .type)
                try container.encode(breakpoints, forKey: .breakpoints)
            case .moveRight(let breakpoints):
                try container.encode(CaseType.moveRight, forKey: .type)
                try container.encode(breakpoints, forKey: .breakpoints)
            case .moveUp(let breakpoints):
                try container.encode(CaseType.moveUp, forKey: .type)
                try container.encode(breakpoints, forKey: .breakpoints)
            case .moveDown(let breakpoints):
                try container.encode(CaseType.moveDown, forKey: .type)
                try container.encode(breakpoints, forKey: .breakpoints)
            case .resizeLeft(let behavior, let breakpoints):
                try container.encode(CaseType.resizeLeft, forKey: .type)
                try container.encode(behavior, forKey: .behavior)
                try container.encode(breakpoints, forKey: .breakpoints)
            case .resizeRight(let behavior, let breakpoints):
                try container.encode(CaseType.resizeRight, forKey: .type)
                try container.encode(behavior, forKey: .behavior)
                try container.encode(breakpoints, forKey: .breakpoints)
            case .resizeTop(let behavior, let breakpoints):
                try container.encode(CaseType.resizeTop, forKey: .type)
                try container.encode(behavior, forKey: .behavior)
                try container.encode(breakpoints, forKey: .breakpoints)
            case .resizeBottom(let behavior, let breakpoints):
                try container.encode(CaseType.resizeBottom, forKey: .type)
                try container.encode(behavior, forKey: .behavior)
                try container.encode(breakpoints, forKey: .breakpoints)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(CaseType.self, forKey: .type)
        switch type {
            case .absolute:
                let value = try container.decode(WindowCoordinates.self, forKey: .value)
                self = .absolute(value)
            case .moveToScreen:
                let a = try container.decode(UInt16.self, forKey: .a)
                let b = try container.decode(UInt16.self, forKey: .b)
                self = .moveToScreen(a, b)
            case .snapToGrid:
                let behavior = try container.decode(ResizeBehavior.self, forKey: .behavior)
                let breakpoints = try container.decode(WindowTransitionBreakpoints.self, forKey: .breakpoints)
                self = .snapToGrid(behavior, breakpoints)
            case .moveLeft:
                let breakpoints = try container.decode(WindowTransitionBreakpoints.self, forKey: .breakpoints)
                self = .moveLeft(breakpoints)
            case .moveRight:
                let breakpoints = try container.decode(WindowTransitionBreakpoints.self, forKey: .breakpoints)
                self = .moveRight(breakpoints)
            case .moveUp:
                let breakpoints = try container.decode(WindowTransitionBreakpoints.self, forKey: .breakpoints)
                self = .moveUp(breakpoints)
            case .moveDown:
                let breakpoints = try container.decode(WindowTransitionBreakpoints.self, forKey: .breakpoints)
                self = .moveDown(breakpoints)
            case .resizeLeft:
                let behavior = try container.decode(ResizeBehavior.self, forKey: .behavior)
                let breakpoints = try container.decode(WindowTransitionBreakpoints.self, forKey: .breakpoints)
                self = .resizeLeft(behavior, breakpoints)
            case .resizeRight:
                let behavior = try container.decode(ResizeBehavior.self, forKey: .behavior)
                let breakpoints = try container.decode(WindowTransitionBreakpoints.self, forKey: .breakpoints)
                self = .resizeRight(behavior, breakpoints)
            case .resizeTop:
                let behavior = try container.decode(ResizeBehavior.self, forKey: .behavior)
                let breakpoints = try container.decode(WindowTransitionBreakpoints.self, forKey: .breakpoints)
                self = .resizeTop(behavior, breakpoints)
            case .resizeBottom:
                let behavior = try container.decode(ResizeBehavior.self, forKey: .behavior)
                let breakpoints = try container.decode(WindowTransitionBreakpoints.self, forKey: .breakpoints)
                self = .resizeBottom(behavior, breakpoints)
        }
    }
}